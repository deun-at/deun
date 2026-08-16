import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';
import '../../../main.dart';
import 'group_member_model.dart';
import 'member_removal.dart';
import 'payback_request.dart';

class GroupRepository {
  /// Set once `pay_back_exact` is confirmed missing (PGRST202/42883) so that
  /// `payBackAll` — which fans payBack out once per shared group in parallel —
  /// pays the round-trip cost of probing for the RPC once per app session
  /// instead of once per group.
  static bool _payBackExactMissing = false;

  /// The PostgREST `or` predicate behind the **active** group tab. The tabs
  /// filter inside the query, so they cannot call [isSettled] — building this
  /// from [kSettledEpsilon] is what keeps the server-side filter from drifting
  /// away from the client predicate (they disagreed at 0.01 vs 0.005 before
  /// settle-residue, so a 0.007 balance was "done" on the tab and outstanding on
  /// the payment screen).
  static String get activeBalanceFilter =>
      'total_share_amount.gte.$kSettledEpsilon,'
      'total_share_amount.lte.-$kSettledEpsilon';

  /// The `pay_back` / `pay_back_exact` argument map — the ONE place those
  /// parameter names live. Pure, so a test can prove that defaulting `paidBy` to
  /// the current user leaves the self-payback call byte-identical to what it
  /// sent before the parameter existed. `pay_back_exact` takes the same four
  /// arguments and delegates to `pay_back`, so one map serves both.
  static Map<String, dynamic> payBackRpcParams({
    required String groupId,
    required String paidBy,
    required String paidFor,
    required double amount,
  }) => {
    "_group_id": groupId,
    "_paid_by": paidBy,
    "_paid_for": paidFor,
    "_amount": amount,
  };

  static Future<List<Group>> fetchData(
    String statusFilter, {
    String? paidTo,
  }) async {
    var currentUserEmail = supabase.auth.currentUser?.email ?? '';
    var query = supabase.from('group').select(Group.groupSelectString);

    if (statusFilter == 'active') {
      query = query.or(
        activeBalanceFilter,
        referencedTable: 'group_shares_summary_helper',
      );
    } else if (statusFilter == 'done') {
      query = query.lt(
        'group_shares_summary_helper.total_share_amount',
        kSettledEpsilon,
      );
      query = query.gt(
        'group_shares_summary_helper.total_share_amount',
        -kSettledEpsilon,
      );
    }

    query = query.eq('group_shares_summary_helper.paid_for', currentUserEmail);

    if (paidTo != null) {
      final safePaidTo = sanitizeFilterValue(paidTo);
      final safeCurrentEmail = sanitizeFilterValue(currentUserEmail);
      query = query.or(
        'and(paid_by.eq.$safeCurrentEmail,paid_for.eq.$safePaidTo),and(paid_by.eq.$safePaidTo,paid_for.eq.$safeCurrentEmail)',
        referencedTable: 'group_shares_summary_helper',
      );
    }

    List<Map<String, dynamic>> data = await query.order(
      'name',
      ascending: true,
    );

    List<Group> retData = List.empty(growable: true);

    for (var element in data) {
      Group group = Group();
      group.loadDataFromJson(element);
      retData.add(group);
    }

    return retData;
  }

  static Future<Group> fetchDetail(String groupId) async {
    Map<String, dynamic> data = await supabase
        .from('group')
        .select(Group.groupSelectString)
        .eq('id', groupId)
        .single();

    Group group = Group();
    group.loadDataFromJson(data);

    return group;
  }

  /// Decodes the `group_members` form value. A missing or empty payload decodes
  /// to NO members.
  ///
  /// group-create-simplify: this used to inject
  /// `{'email': <current user>, 'display_name': ''}` whenever the list came out
  /// empty — that is how a placeholder member row with an empty display name
  /// reached the database on create. The creator is now added explicitly, and
  /// only on the create path, by [resolveSaveMembers].
  static List<Map<String, dynamic>> decodeGroupMembersString(
    String? jsonValue,
  ) {
    return List<Map<String, dynamic>>.from(jsonDecode(jsonValue ?? "[]"));
  }

  /// The `group_member` rows a group save submits, decided before anything is
  /// written.
  ///
  /// * **create** ([isCreate]) — exactly ONE row: the creator, carrying nothing
  ///   but their email. The create form has no member field any more, so
  ///   [membersJson] is deliberately not read here; members are added afterwards
  ///   on the group's own surface. `group_member` stores no display name, so
  ///   there is none to invent — and no placeholder to write.
  /// * **edit** — exactly the roster the form carries, unchanged.
  ///
  /// A client with no signed-in user ([currentUserEmail] null or empty) yields
  /// NO rows rather than a row with an empty email.
  ///
  /// Pure: no Supabase, no context — the caller passes the current user in.
  static List<Map<String, dynamic>> resolveSaveMembers({
    required bool isCreate,
    required String? membersJson,
    required String? currentUserEmail,
  }) {
    if (!isCreate) return decodeGroupMembersString(membersJson);

    final email = currentUserEmail ?? '';
    if (email.isEmpty) return <Map<String, dynamic>>[];
    return [
      {'email': email},
    ];
  }

  /// The `group_member` writes a save performs, decided before anything is
  /// written: submitted members the group does not have an **active** row for
  /// are inserted; the rest are re-adds (rows that exist already, possibly
  /// soft-removed). Rows with no email are never written.
  ///
  /// This is the union/dedup against the group's current roster — the same rule
  /// the `save_group_all` RPC applies server-side — expressed once so the legacy
  /// write path and the tests share it instead of restating it.
  ///
  /// Pure: no Supabase. The caller passes the group's current [existingEmails].
  static GroupMemberWrite resolveMemberWrite({
    required String groupId,
    required List<Map<String, dynamic>> members,
    required Set<String> existingEmails,
  }) {
    final inserts = <Map<String, dynamic>>[];
    final reAddEmails = <String>[];
    for (final member in members) {
      final email = (member['email'] as String?) ?? '';
      if (email.isEmpty) continue;
      if (existingEmails.contains(email)) {
        reAddEmails.add(email);
      } else {
        inserts.add({'group_id': groupId, 'email': email});
      }
    }
    return GroupMemberWrite(inserts: inserts, reAddEmails: reAddEmails);
  }

  /// Who a group save pushes a "you were added to a group" notification to:
  /// submitted members who are real users (guests have no device) and who were
  /// not already in the group.
  ///
  /// group-create-simplify: members join through the **edit** save now, so this
  /// diff is what makes the push reach them. A create submits nothing but the
  /// creator, whom [sendNotification] strips from every receiver set — which is
  /// why the create path no longer raises one at all.
  ///
  /// Pure: no Supabase. The caller passes the group's current [existingEmails].
  static Set<String> resolveNotificationReceivers({
    required List<Map<String, dynamic>> members,
    required Set<String> existingEmails,
  }) {
    final receivers = <String>{};
    for (final member in members) {
      final email = (member['email'] as String?) ?? '';
      if (email.isEmpty) continue;
      if ((member['is_guest'] ?? false) == true) continue;
      if ((member['is_guest_pending'] ?? false) == true) continue;
      if (existingEmails.contains(email)) continue;
      receivers.add(email);
    }
    return receivers;
  }

  /// Emails of the group's **active** members (soft-removed rows are not
  /// active: re-adding one is a join, so it both inserts nothing and notifies).
  static Future<Set<String>> _activeMemberEmails(String groupId) async {
    final rows = await supabase
        .from('group_member')
        .select('email, removed_at')
        .eq('group_id', groupId);
    return rows
        .where((row) => row['removed_at'] == null)
        .map((row) => (row['email'] as String?) ?? '')
        .where((email) => email.isNotEmpty)
        .toSet();
  }

  /// The group's FULL `group_member` roster as models, soft-removed rows
  /// included. [resolvePayback] needs the removed rows to tell "not a member"
  /// from "removed", and needs `is_guest` to decide whether the payer can be
  /// notified. The embed fragment is the same one `Group.groupSelectString`
  /// uses for its members.
  static Future<List<GroupMember>> _groupRoster(String groupId) async {
    final rows = await supabase
        .from('group_member')
        .select(
          '*, ...user(display_name:display_name, username:username, '
          'username_code:username_code, is_guest:is_guest)',
        )
        .eq('group_id', groupId);
    return rows
        .map((row) => GroupMember()..loadDataFromJson(row))
        .toList(growable: false);
  }

  /// Saves a group with members and share recalculation atomically via the
  /// save_group_all RPC (one transaction server-side, including guest user
  /// creation). Falls back to the legacy multi-step write path when the
  /// database doesn't have the RPC yet.
  static Future<String> saveAll(
    BuildContext context,
    String? groupId,
    Map<String, dynamic> formValue,
  ) async {
    try {
      Map<String, dynamic> upsertVals = {
        "name": formValue["name"],
        "color_value":
            formValue["color_value"] ?? ColorSeed.baseColor.color.toARGB32(),
        "simplified_expenses": formValue["simplified_expenses"] ?? false,
        "currency_code": formValue["currency_code"] ?? kDefaultCurrencyCode,
        "user_id": supabase.auth.currentUser?.id,
      };

      if (groupId != null) {
        upsertVals.addAll({'id': groupId});
      }

      final List<Map<String, dynamic>> groupMembers = resolveSaveMembers(
        isCreate: groupId == null,
        membersJson: formValue['group_members'] as String?,
        currentUserEmail: supabase.auth.currentUser?.email,
      );

      // group-create-simplify: a group gains members through the EDIT save now
      // (create submits the creator alone), so the "you were added to a group"
      // push is raised here, for the members this save actually adds. The old
      // create-only call could never reach anybody: its receiver set was the
      // creator, whom sendNotification strips.
      final Set<String> notificationReceiver = groupId == null
          ? const <String>{}
          : resolveNotificationReceivers(
              members: groupMembers,
              existingEmails: await _activeMemberEmails(groupId),
            );

      String savedGroupId;
      try {
        savedGroupId =
            await supabase.rpc(
                  'save_group_all',
                  params: {'_group': upsertVals, '_members': groupMembers},
                )
                as String;
      } on PostgrestException catch (e) {
        if (!isMissingFunctionError(e)) rethrow;
        savedGroupId = await _saveAllLegacy(upsertVals, groupMembers);
      }

      if (notificationReceiver.isNotEmpty && context.mounted) {
        sendGroupNotification(context, savedGroupId, notificationReceiver);
      }

      return savedGroupId;
    } on PostgrestException catch (e) {
      debugPrint('Failed to save group ${groupId ?? 'new'}: ${e.message}');
      rethrow;
    }
  }

  /// Legacy non-atomic write path for servers without the save_group_all
  /// RPC. Performs the same writes as the RPC, one statement at a time.
  static Future<String> _saveAllLegacy(
    Map<String, dynamic> upsertVals,
    List<Map<String, dynamic>> groupMembers,
  ) async {
    Map<String, dynamic> groupInsertResponse = await supabase
        .from('group')
        .upsert(upsertVals)
        .select('id')
        .single();
    final savedGroupId = groupInsertResponse['id'] as String;

    // Resolve any pending guest members by creating guest user records and replacing entries
    final members = List<Map<String, dynamic>>.from(groupMembers);
    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      if ((member['is_guest_pending'] ?? false) == true) {
        final displayName = (member['display_name'] ?? '').toString();
        if (displayName.isNotEmpty) {
          try {
            final guestUser = await UserRepository.createGuest(displayName);
            members[i] = {
              'email': guestUser.email,
              'display_name': guestUser.displayName,
              'is_guest': guestUser.isGuest,
            };
          } catch (e) {
            debugPrint('Failed to create guest "$displayName": $e');
          }
        }
      }
    }
    // Remove entries that failed guest creation (still have is_guest_pending)
    members.removeWhere((m) => (m['is_guest_pending'] ?? false) == true);

    // group-member-removal: never delete here. Membership shrinks only through
    // GroupRepository.removeMember; a member merely absent from `members` keeps
    // their row (and their is_favorite, which the old delete/re-insert cycle
    // destroyed). No upsert/onConflict: this instance's unique constraints are
    // not verifiable from the build, so existence is checked explicitly.
    final existingRows = await supabase
        .from('group_member')
        .select('email')
        .eq('group_id', savedGroupId);
    final existingEmails = existingRows
        .map((row) => (row['email'] as String?) ?? '')
        .toSet();

    final write = resolveMemberWrite(
      groupId: savedGroupId,
      members: members,
      existingEmails: existingEmails,
    );
    final newRows = write.inserts;
    final reAddEmails = write.reAddEmails;

    if (reAddEmails.isNotEmpty) {
      // One round trip for every re-add instead of one per member: almost all
      // of these are already-active members and thus no-ops, so the
      // `removed_at is not null` guard (mirroring the RPC) keeps the write
      // from touching rows that don't need it.
      await supabase
          .from('group_member')
          .update({'removed_at': null})
          .eq('group_id', savedGroupId)
          .inFilter('email', reAddEmails)
          .not('removed_at', 'is', null);
    }

    if (newRows.isNotEmpty) {
      await supabase.from('group_member').insert(newRows);
    }

    await supabase.rpc(
      'update_group_member_shares',
      params: {"_group_id": savedGroupId, "_expense_id": null},
    );

    return savedGroupId;
  }

  /// Removes [email] from [groupId] with defined semantics, decided by
  /// [resolveMemberRemoval] *before* anything is written:
  ///
  /// * unsettled -> returns [MemberRemovalBlocked] having written **nothing**;
  /// * settled with expense involvement -> stamps `removed_at` (the row survives,
  ///   so every `expense_entry_share` of theirs still has a member behind it and
  ///   no balance moves);
  /// * settled with no involvement at all -> deletes the row, no tombstone.
  ///
  /// Both write paths then recalculate shares, which also bumps
  /// `group_update_checker` — that is the channel `GroupDetailNotifier` listens
  /// on, so other clients' open group detail refreshes with no stale roster.
  static Future<MemberRemovalOutcome> removeMember(
    String groupId,
    String email,
  ) async {
    final balance = await _memberGroupBalance(groupId, email);
    final hasHistory = await _hasExpenseHistory(groupId, email);

    final outcome = resolveMemberRemoval(
      balance: balance,
      hasExpenseHistory: hasHistory,
    );

    switch (outcome) {
      case MemberRemovalBlocked():
        // No write of any kind: the guard is the early return itself.
        return outcome;
      case MemberRemovalSoftRemoved():
        await supabase
            .from('group_member')
            .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
            .eq('group_id', groupId)
            .eq('email', email);
      case MemberRemovalHardRemoved():
        await supabase
            .from('group_member')
            .delete()
            .eq('group_id', groupId)
            .eq('email', email);
    }

    await supabase.rpc(
      'update_group_member_shares',
      params: {"_group_id": groupId, "_expense_id": null},
    );

    return outcome;
  }

  /// The member's own net position in the group — `group_shares_summary`'s
  /// `total_share_amount` for `paid_for = email` (identical across their rows).
  /// Deliberately NOT rounded: `resolveMemberRemoval` owns the epsilon, so the
  /// threshold is applied to exactly one value in exactly one place.
  static Future<double> _memberGroupBalance(
    String groupId,
    String email,
  ) async {
    final rows = await supabase
        .from('group_shares_summary')
        .select('total_share_amount')
        .eq('group_id', groupId)
        .eq('paid_for', email)
        .limit(1);

    if (rows.isEmpty) return 0;
    return double.parse((rows.first['total_share_amount'] ?? 0).toString());
  }

  /// Whether the member appears anywhere in the group's expenses — as the holder
  /// of a share OR as a payer. Both sides matter: a hard remove drops the
  /// `group_member` row, and `update_group_member_shares` now ignores shares
  /// whose counterparty has no member row, so a payer without shares of their own
  /// must never be hard-removed or the debts owed to them would vanish.
  static Future<bool> _hasExpenseHistory(String groupId, String email) async {
    final paidRows = await supabase
        .from('expense')
        .select('id')
        .eq('group_id', groupId)
        .eq('paid_by', email)
        .limit(1);
    if (paidRows.isNotEmpty) return true;

    // Both filters sit exactly one embed level from expense_entry — the same
    // shape fetchData already uses for `group_shares_summary_helper.paid_for`.
    final shareRows = await supabase
        .from('expense_entry')
        .select('id, expense!inner(group_id), expense_entry_share!inner(email)')
        .eq('expense.group_id', groupId)
        .eq('expense_entry_share.email', email)
        .limit(1);

    return shareRows.isNotEmpty;
  }

  /// The payback plan for "[paidBy] paid [paidFor] [amount]", recorded by
  /// [recordedBy], with **the default for [paidBy] applied here**: a null
  /// [paidBy] means the signed-in user, which is what keeps the self-payback
  /// path sending exactly the `_paid_by` it sent before the parameter existed.
  ///
  /// Split out of [payBack] so that default has one home and a pure test can
  /// assert it — [payBack] itself needs a Supabase session and an RPC.
  @visibleForTesting
  static PaybackPlan planPayBack({
    String? paidBy,
    required String paidFor,
    required double amount,
    required String recordedBy,
    required List<GroupMember> members,
  }) => resolvePayback(
    paidBy: paidBy ?? recordedBy,
    paidFor: paidFor,
    amount: amount,
    recordedBy: recordedBy,
    members: members,
  );

  /// Records "[paidBy] paid [email] [amount]" in [groupId].
  ///
  /// [paidBy] defaults to the signed-in user, so every existing call site keeps
  /// its exact behaviour and the common case stays on this one code path — the
  /// feature extends the RPC call, it does not re-route it. Passing a different
  /// member records a payback on their behalf: any member may do this for any
  /// two distinct members (there is no owner concept in Deun — see the plan's
  /// Decisions), and the deterrent is visibility, which is why BOTH parties are
  /// notified and the recorder is persisted.
  ///
  /// The plan is resolved by [planPayBack] *before* anything is written; a
  /// rejection throws [PaybackRejectedException] having written nothing. The
  /// same two rules are enforced inside `pay_back` by
  /// `20260816010000_payback_on_behalf.sql` for concurrent clients.
  ///
  /// [members] is the group's FULL roster (soft-removed rows included). Every
  /// in-app caller already holds it on the group it is settling, so pass it:
  /// the fallback SELECT costs a round trip on the hot self-settle path (and
  /// one per group in [payBackAll]), and turns a transient read failure into a
  /// failed settle.
  static Future<void> payBack(
    BuildContext context,
    String groupId,
    String email,
    double amount, {
    String? paidBy,
    List<GroupMember>? members,
    bool sendNotification = true,
  }) async {
    final recordedBy = supabase.auth.currentUser?.email ?? '';
    final plan = planPayBack(
      paidBy: paidBy,
      paidFor: email,
      amount: amount,
      recordedBy: recordedBy,
      members: members ?? await _groupRoster(groupId),
    );

    final PaybackAccepted accepted;
    switch (plan) {
      case PaybackRejected():
        // No write of any kind: the guard is the throw itself.
        throw PaybackRejectedException(plan);
      case PaybackAccepted():
        accepted = plan;
    }

    final params = payBackRpcParams(
      groupId: groupId,
      paidBy: accepted.paidBy,
      paidFor: accepted.paidFor,
      amount: accepted.amount,
    );

    // settle-residue: pay_back_exact snaps `amount` to the exact outstanding
    // value server-side, so the payback cancels the unrounded balance the client
    // could only see rounded. A server without it falls back to pay_back —
    // exactly the way `saveAll` falls back for `save_group_all`.
    String expenseId;
    if (_payBackExactMissing) {
      expenseId = await supabase.rpc('pay_back', params: params) as String;
    } else {
      try {
        expenseId =
            await supabase.rpc('pay_back_exact', params: params) as String;
      } on PostgrestException catch (e) {
        if (!isMissingFunctionError(e)) rethrow;
        _payBackExactMissing = true;
        expenseId = await supabase.rpc('pay_back', params: params) as String;
      }
    }

    // Retry share update once on failure to reduce partial-state risk.
    // This RPC is idempotent (recalculates from scratch), so retrying is safe.
    try {
      await supabase.rpc(
        'update_group_member_shares',
        params: {"_group_id": groupId, "_expense_id": expenseId},
      );
    } catch (e) {
      await supabase.rpc(
        'update_group_member_shares',
        params: {"_group_id": groupId, "_expense_id": expenseId},
      );
    }

    if (context.mounted && sendNotification) {
      sendGroupPayBackNotification(
        context,
        groupId,
        expenseId,
        accepted.notificationReceivers,
        amount,
        // Every name comes off the roster this call resolved the plan against,
        // NOT from the DB row, so the copy works before the migration is
        // applied. `recordedByDisplayName` null on the self path -> today's
        // copy, unchanged.
        paidByDisplayName: accepted.paidByDisplayName,
        paidForDisplayName: accepted.paidForDisplayName,
        recordedByDisplayName: accepted.isOnBehalf
            ? accepted.recordedByDisplayName
            : null,
      );
    }
  }

  /// Which of [groups] a settle-everything-with-[email] run may actually write,
  /// and which it has to leave alone.
  ///
  /// Pure, so the fan-out below is only the *application* of a decision that can
  /// be unit-tested. A group lands in [PayBackAllPlan.skipped] when
  /// [resolvePayback] would reject its payback — which is the same rule
  /// [payBack] enforces, so a skipped group is exactly a group whose write would
  /// have thrown. Checking the whole plan (rather than only the payee's
  /// membership) also covers the mirror case: the **current user** soft-removed
  /// from a shared group, which would otherwise throw `payerNotInGroup` out of
  /// `Future.wait` and abort every group that had not been written yet.
  static PayBackAllPlan resolvePayBackAll({
    required List<Group> groups,
    required String email,
    required String recordedBy,
  }) {
    final settle = <PayBackAllTarget>[];
    final skipped = <String>[];

    for (final group in groups) {
      // Only settle groups where the current user owes this friend, and pay back
      // exactly the per-group amount — not the cross-group total.
      // `amountToSettleWith` is the same value the payment screen shows and
      // applies the same settled predicate, so a balance can never be settled on
      // one path and outstanding on the other.
      final amount = group.amountToSettleWith(email);
      if (amount == null) continue;

      final plan = planPayBack(
        paidFor: email,
        amount: amount,
        recordedBy: recordedBy,
        members: group.groupMembers,
      );
      if (plan is PaybackRejected) {
        skipped.add(group.name);
        continue;
      }

      settle.add(
        PayBackAllTarget(
          groupId: group.id,
          groupName: group.name,
          amount: amount,
          // fetchData already loaded the roster; no extra SELECT per group.
          members: group.groupMembers,
        ),
      );
    }

    return PayBackAllPlan(settle: settle, skipped: skipped);
  }

  /// Settles every active group the current user shares with [email].
  ///
  /// Returns what actually happened. A group whose payback would be rejected —
  /// because [email] or the current user is soft-removed from it — is skipped
  /// rather than written, and is **named in the result** so the caller cannot
  /// report a total as settled when part of it is still outstanding.
  static Future<PayBackAllResult> payBackAll(
    BuildContext context,
    String email,
  ) async {
    final groupList = await GroupRepository.fetchData("active", paidTo: email);
    final plan = resolvePayBackAll(
      groups: groupList,
      email: email,
      recordedBy: supabase.auth.currentUser?.email ?? '',
    );

    await Future.wait(
      plan.settle.map(
        (target) => GroupRepository.payBack(
          context,
          target.groupId,
          email,
          target.amount,
          members: target.members,
          sendNotification: false,
        ),
      ),
    );

    return PayBackAllResult(
      settledGroupNames: [for (final target in plan.settle) target.groupName],
      skippedGroupNames: plan.skipped,
    );
  }

  static Future<void> toggleFavorite(String groupId, bool isFavorite) async {
    final email = supabase.auth.currentUser?.email ?? '';
    await supabase
        .from('group_member')
        .update({'is_favorite': isFavorite})
        .eq('group_id', groupId)
        .eq('email', email);
  }

  static Future<void> delete(String groupId) async {
    await supabase.from('group').delete().eq('id', groupId);
    await supabase
        .from('group_update_checker')
        .delete()
        .eq('group_id', groupId);
  }
}

/// One group a [GroupRepository.payBackAll] run will settle, with everything
/// that write needs already resolved.
class PayBackAllTarget {
  const PayBackAllTarget({
    required this.groupId,
    required this.groupName,
    required this.amount,
    required this.members,
  });

  final String groupId;
  final String groupName;

  /// The per-group amount, never the cross-group total.
  final double amount;

  /// The group's FULL roster, soft-removed rows included — passed straight
  /// through to [GroupRepository.payBack] so it needs no extra SELECT.
  final List<GroupMember> members;
}

/// What a settle-everything-with-one-friend run will and will not write, as
/// resolved by [GroupRepository.resolvePayBackAll].
class PayBackAllPlan {
  const PayBackAllPlan({required this.settle, required this.skipped});

  final List<PayBackAllTarget> settle;

  /// Names of the groups whose payback would be rejected, in roster order.
  final List<String> skipped;
}

/// What a [GroupRepository.payBackAll] run actually did.
///
/// [skippedGroupNames] is the load-bearing half: the friend sheet settles a
/// **cross-group** total, so a single group left unsettled means the "you paid
/// back X" confirmation would be a lie. The names let the caller say which
/// groups are still open instead. No amount is carried, deliberately: groups may
/// use different currencies, and the friendship total is already a converted
/// home-currency figure that a per-group sum could not reproduce.
class PayBackAllResult {
  const PayBackAllResult({
    required this.settledGroupNames,
    required this.skippedGroupNames,
  });

  final List<String> settledGroupNames;
  final List<String> skippedGroupNames;

  /// True when every group that owed something was settled.
  bool get isComplete => skippedGroupNames.isEmpty;
}

/// The `group_member` writes one group save performs, as resolved by
/// [GroupRepository.resolveMemberWrite]. A save never deletes: membership
/// shrinks only through [GroupRepository.removeMember].
class GroupMemberWrite {
  const GroupMemberWrite({required this.inserts, required this.reAddEmails});

  /// Rows to insert, each `{'group_id': ..., 'email': ...}` — members the group
  /// has no row for at all.
  final List<Map<String, dynamic>> inserts;

  /// Emails that already have a row; the write only clears a `removed_at` on
  /// the soft-removed ones and leaves the rest untouched.
  final List<String> reAddEmails;
}
