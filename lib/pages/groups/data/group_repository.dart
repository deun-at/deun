import 'dart:async';

import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';
import '../../../main.dart';
import 'group_member_model.dart';
import 'member_add.dart';
import 'member_removal.dart';
import 'payback_request.dart';

class GroupRepository {
  /// Null outside tests. When set, every RPC [payBack] issues (and
  /// [applyPayBackAll]'s default write) goes through it instead of
  /// `supabase.rpc`.
  @visibleForTesting
  static PaybackRpc? payBackRpcOverride;

  /// Null outside tests. When set, [saveAll] sends its one `save_group_all`
  /// call here instead of `supabase.rpc`.
  @visibleForTesting
  static Future<Object?> Function(Map<String, dynamic> params)?
  saveGroupAllOverride;

  /// Every RPC a payback write issues.
  static Future<Object?> _payBackRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final override = payBackRpcOverride;
    if (override != null) return override(function, params);
    return await supabase.rpc(function, params: params);
  }

  /// The PostgREST `or` predicate behind the **active** group list. The filter
  /// runs inside the query, so it cannot call [isSettled] — the balance lives on
  /// a referenced table while `currency_code` lives on the parent row, so no
  /// single currency is knowable here. Building it from [kSettledEpsilon] (the
  /// SMALLEST supported epsilon) makes it a deliberate SUPERSET: it keeps every
  /// group any currency could call outstanding, and [narrowToStatus] then makes
  /// the real per-currency decision on the client.
  ///
  /// Keeping the bound tied to the shared epsilon is also what stops the
  /// server-side filter from drifting away from the client predicate (they
  /// disagreed at 0.01 vs 0.005 before settle-residue, so a 0.007 balance was
  /// "done" on the tab and outstanding on the payment screen).
  static String get activeBalanceFilter =>
      'total_share_amount.gte.$kSettledEpsilon,'
      'total_share_amount.lte.-$kSettledEpsilon';

  /// Narrows a server-fetched list to what [statusFilter] actually means in each
  /// group's OWN currency.
  ///
  /// The query-side predicates bracket with [kSettledEpsilon] /
  /// [kMaxSettledEpsilon] and return a superset on purpose (see
  /// [activeBalanceFilter]); this is where the decision is finally made, through
  /// the same [isSettled] every screen uses. Without it a 0-decimal group with
  /// |net| in [0.005, 0.5) rendered a settled ¥0 hero while still counting as
  /// active — the tab/hero drift settle-residue closed, reopened for JPY/ISK/KRW.
  ///
  /// Pure; any other [statusFilter] (e.g. `"all"`) passes through untouched.
  static List<Group> narrowToStatus(List<Group> groups, String statusFilter) {
    switch (statusFilter) {
      case 'active':
        return [
          for (final group in groups)
            if (!isSettled(group.totalShareAmount, group.currency)) group,
        ];
      case 'done':
        return [
          for (final group in groups)
            if (isSettled(group.totalShareAmount, group.currency)) group,
        ];
      default:
        return groups;
    }
  }

  /// The `pay_back_exact` argument map, the ONE place those parameter names
  /// live. Pure, so a test can prove that defaulting `paidBy` to the current
  /// user leaves the self-payback call byte-identical to what it sent before the
  /// parameter existed.
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

  /// The RPC an invite-link join calls — the ONE place its name lives.
  static const String joinGroupRpcName = 'join_group';

  /// The `join_group` argument map — the ONE place its argument names live.
  /// Always both keys: `_guest_email` is null when joining as a new member.
  static Map<String, dynamic> joinGroupRpcParams({
    required String groupId,
    String? guestEmail,
  }) => {'_group_id': groupId, '_guest_email': guestEmail};

  /// The RPCs the member writes and the group delete call — the ONE place their
  /// names live.
  static const String addMemberRpcName = 'add_group_member';
  static const String removeMemberRpcName = 'remove_group_member';
  static const String deleteRpcName = 'delete_group';

  /// The `add_group_member` argument map — the ONE place its names live.
  static Map<String, dynamic> addMemberRpcParams({
    required String groupId,
    required String email,
  }) => {'_group_id': groupId, '_email': email};

  /// The `remove_group_member` argument map. `_settled_epsilon` is the group's
  /// own [Currency.settledEpsilon]: the server blocks iff |balance| >= it, the
  /// exact mirror of [isSettled], and has no epsilon of its own.
  static Map<String, dynamic> removeMemberRpcParams({
    required String groupId,
    required String email,
    required Currency currency,
  }) => {
    '_group_id': groupId,
    '_email': email,
    '_settled_epsilon': currency.settledEpsilon,
  };

  /// The `delete_group` argument map.
  static Map<String, dynamic> deleteRpcParams(String groupId) => {
    '_group_id': groupId,
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
      // The widest supported epsilon, so a settled 0-decimal balance (|net| < 0.5
      // in JPY/ISK/KRW) is not excluded before narrowToStatus can judge it in its
      // own currency. EUR rows are narrowed back to |net| < 0.005 on the client.
      query = query.lt(
        'group_shares_summary_helper.total_share_amount',
        kMaxSettledEpsilon,
      );
      query = query.gt(
        'group_shares_summary_helper.total_share_amount',
        -kMaxSettledEpsilon,
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

    return narrowToStatus(retData, statusFilter);
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

  /// The `group_member` rows a group save submits, decided before anything is
  /// written.
  ///
  /// * **create** ([isCreate]) — exactly ONE row: the creator, carrying nothing
  ///   but their email. The create form has no member field any more; members
  ///   are added afterwards on the group's own surface. `group_member` stores
  ///   no display name, so there is none to invent — and no placeholder to
  ///   write.
  /// * **edit** — NO rows at all. group-member-add-flow: membership is not a
  ///   group attribute any more, so an edit save must never read or write it —
  ///   the Members page (`GroupRepository.addMember` / `removeMember`) is the
  ///   only membership writer once a group exists.
  ///
  /// A client with no signed-in user ([currentUserEmail] null or empty) yields
  /// NO rows rather than a row with an empty email.
  ///
  /// Pure: no Supabase, no context — the caller passes the current user in.
  static List<Map<String, dynamic>> resolveSaveMembers({
    required bool isCreate,
    required String? currentUserEmail,
  }) {
    if (!isCreate) return const <Map<String, dynamic>>[];

    final email = currentUserEmail ?? '';
    if (email.isEmpty) return <Map<String, dynamic>>[];
    return [
      {'email': email},
    ];
  }

  /// The `group_member` select every roster read uses: the membership row plus
  /// the user fields `GroupMember` parses. Same embed as `Group.groupSelectString`.
  static const String _rosterSelect =
      '*, ...user(display_name:display_name, username:username, '
      'username_code:username_code, is_guest:is_guest)';

  /// The group's FULL `group_member` roster as models, soft-removed rows
  /// included. [resolvePayback] needs the removed rows to tell "not a member"
  /// from "removed", and needs `is_guest` to decide whether the payer can be
  /// notified. The embed fragment is the same one `Group.groupSelectString`
  /// uses for its members.
  static Future<List<GroupMember>> _groupRoster(String groupId) async {
    final rows = await supabase
        .from('group_member')
        .select(_rosterSelect)
        .eq('group_id', groupId);
    return rows
        .map((row) => GroupMember()..loadDataFromJson(row))
        .toList(growable: false);
  }

  /// Saves a group in ONE server transaction (`save_group_all`): the group
  /// row, the creator's membership on a create (guest user creation included)
  /// and the share recalculation commit together or not at all. Returns the id
  /// the RPC returned. Any failure, a missing function included, is thrown as
  /// the RPC's own error having written nothing: there is no client-side
  /// fallback.
  static Future<String> saveAll(
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

      // group-member-add-flow: membership is not a group attribute any more —
      // an edit submits NO members, and a create submits the creator alone.
      final List<Map<String, dynamic>> groupMembers = resolveSaveMembers(
        isCreate: groupId == null,
        currentUserEmail: supabase.auth.currentUser?.email,
      );

      final Map<String, dynamic> params = {
        '_group': upsertVals,
        '_members': groupMembers,
      };
      final override = saveGroupAllOverride;
      return (override != null
              ? await override(params)
              : await supabase.rpc('save_group_all', params: params))
          as String;
    } on PostgrestException catch (e) {
      debugPrint('Failed to save group ${groupId ?? 'new'}: ${e.message}');
      rethrow;
    }
  }

  /// Removes [email] from [groupId] in ONE server transaction
  /// (`remove_group_member`). The server decides, under the group's
  /// member-write lock and with every in-flight expense write committed first:
  ///
  /// * unsettled in the group's own currency (|balance| >= the epsilon sent) ->
  ///   [MemberRemovalBlocked], having written **nothing**;
  /// * settled with a payment or a share in the group -> `removed_at` stamped
  ///   (the row survives, so no balance moves);
  /// * settled with neither -> the row is deleted.
  ///
  /// Every write recalculates the group inside the same transaction, which also
  /// bumps `group_update_checker`, the channel `GroupDetailNotifier` listens on.
  /// The answer is parsed by [memberRemovalOutcomeFromRpc]; an unrecognised one
  /// throws.
  static Future<MemberRemovalOutcome> removeMember(
    String groupId,
    String email, {
    required Currency currency,
  }) async => memberRemovalOutcomeFromRpc(
    await supabase.rpc(
      removeMemberRpcName,
      params: removeMemberRpcParams(
        groupId: groupId,
        email: email,
        currency: currency,
      ),
    ),
  );

  /// Adds [email] to [groupId] **on its own** in ONE server transaction
  /// (`add_group_member`): no row -> inserted (not favourite); a soft-removed
  /// row -> `removed_at` cleared; an active row -> nothing written. The server
  /// decides under the group's member-write lock and recalculates in the same
  /// transaction, which bumps `group_update_checker`, so another client's open
  /// group detail picks the change up. The answer is parsed by
  /// [memberAddOutcomeFromRpc]; an unrecognised one throws.
  static Future<MemberAddOutcome> addMember(
    String groupId,
    String email,
  ) async => memberAddOutcomeFromRpc(
    await supabase.rpc(
      addMemberRpcName,
      params: addMemberRpcParams(groupId: groupId, email: email),
    ),
  );

  /// Joins [groupId] through its invite link as the signed-in user, claiming
  /// the guest placeholder [guestEmail] when given.
  ///
  /// One RPC, one transaction: the membership write, the guest merge (scoped to
  /// this group), the share recalculation and the orphaned-guest delete all
  /// happen in `join_group` or not at all. No fallback: the migration ships
  /// before the app (guest-merge-rpc plan, "Legacy fallback").
  static Future<void> joinGroup(String groupId, {String? guestEmail}) async {
    await supabase.rpc(
      joinGroupRpcName,
      params: joinGroupRpcParams(groupId: groupId, guestEmail: guestEmail),
    );
  }

  /// What the join page shows: the claimable guests (through the SECURITY
  /// DEFINER `group_join_guests`, since a not-yet-member cannot read the roster)
  /// and the signed-in user's own membership row, read in parallel.
  static Future<GroupJoinState> fetchJoinState(String groupId) async {
    final email = supabase.auth.currentUser?.email;
    final results = await Future.wait<dynamic>([
      supabase.rpc('group_join_guests', params: {'_group_id': groupId}),
      if (email != null)
        supabase
            .from('group_member')
            .select(_rosterSelect)
            .eq('group_id', groupId)
            .eq('email', email),
    ]);

    final guests = [
      for (final row in (results[0] as List).cast<Map<String, dynamic>>())
        GroupMember()
          ..loadDataFromJson({...row, 'group_id': groupId, 'is_guest': true}),
    ];
    final own = results.length > 1
        ? [
            for (final row in (results[1] as List).cast<Map<String, dynamic>>())
              GroupMember()..loadDataFromJson(row),
          ]
        : const <GroupMember>[];

    return resolveGroupJoinState(
      roster: [...own, ...guests],
      currentEmail: email,
    );
  }

  /// What `remove_group_member` is expected to decide, read on the client so
  /// the page can confirm a soft removal BEFORE anything is written: the same
  /// balance and history the server reads, resolved by [resolveMemberRemoval].
  ///
  /// [removeMember] never sends this result: the server re-resolves under its
  /// locks, so a balance that moves between the preview and the confirmation is
  /// still caught.
  static Future<MemberRemovalOutcome> previewMemberRemoval(
    String groupId,
    String email, {
    required Currency currency,
  }) async => resolveMemberRemoval(
    balance: await _memberGroupBalance(groupId, email),
    hasExpenseHistory: await _hasExpenseHistory(groupId, email),
    currency: currency,
  );

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
  /// Completes only once the payback AND its balance recalculation have
  /// committed: `pay_back` runs `update_group_member_shares` in the same
  /// transaction (`20261026120000_pay_back_atomic_recalc.sql`), so this method
  /// throws only when nothing was recorded, and retrying after an error never
  /// records the payment twice. A response lost in transit after the server
  /// committed is the one exception: it still surfaces as an error.
  ///
  /// [members] is the group's FULL roster (soft-removed rows included). Every
  /// in-app caller already holds it on the group it is settling, so pass it:
  /// the fallback SELECT costs a round trip on the hot self-settle path and
  /// turns a transient read failure into a failed settle.
  ///
  /// [notifications] is built by the caller before its first await, so the push
  /// that follows the write never reads a BuildContext.
  static Future<void> payBack(
    String groupId,
    String email,
    double amount, {
    String? paidBy,
    List<GroupMember>? members,
    required NotificationSender notifications,
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

    await _writePayBack(groupId, accepted);
    _notifyPayBack(notifications, groupId, accepted);
  }

  /// The write half of a payback: ONE RPC, `pay_back_exact`, which snaps
  /// `amount` to the exact outstanding value server-side (settle-residue) and
  /// records the payback through `pay_back`. It completes only once the server
  /// has committed. Any failure, a missing function included, is thrown as the
  /// RPC's own error having recorded nothing: there is no client-side
  /// fallback.
  static Future<void> _writePayBack(
    String groupId,
    PaybackAccepted accepted,
  ) async {
    await _payBackRpc(
      'pay_back_exact',
      payBackRpcParams(
        groupId: groupId,
        paidBy: accepted.paidBy,
        paidFor: accepted.paidFor,
        amount: accepted.amount,
      ),
    );
  }

  /// The notify step a single payback and every settle-all group share, so the
  /// copy is identical by construction. Fire-and-forget: never delays or fails
  /// a write that committed. Every name comes off the roster the plan was
  /// resolved against, NOT from the DB row, so the copy works before the
  /// migration is applied; `recordedByDisplayName` null on the self path ->
  /// today's copy, unchanged.
  static void _notifyPayBack(
    NotificationSender notifications,
    String groupId,
    PaybackAccepted accepted,
  ) {
    unawaited(
      notifications.paybackRecorded(
        groupId: groupId,
        receivers: accepted.notificationReceivers,
        amount: accepted.amount,
        paidByDisplayName: accepted.paidByDisplayName,
        paidForDisplayName: accepted.paidForDisplayName,
        recordedByDisplayName: accepted.isOnBehalf
            ? accepted.recordedByDisplayName
            : null,
      ),
    );
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
      if (plan is! PaybackAccepted) {
        skipped.add(group.name);
        continue;
      }

      settle.add(
        PayBackAllTarget(
          groupId: group.id,
          groupName: group.name,
          currency: group.currency,
          amount: amount,
          // The plan just resolved: the write and its push need no extra read.
          accepted: plan,
        ),
      );
    }

    return PayBackAllPlan(settle: settle, skipped: skipped);
  }

  /// Null outside tests. When set, [applyPayBackAll] runs it in place of each
  /// settled target's payback write; the notify step still runs after each write
  /// that completes.
  @visibleForTesting
  static PayBackAllWrite? payBackAllWriteOverride;

  /// Settles every active group the current user shares with [email].
  ///
  /// Returns what actually happened. A group whose payback would be rejected —
  /// because [email] or the current user is soft-removed from it — is skipped
  /// rather than written, and is **named in the result** so the caller cannot
  /// report a total as settled when part of it is still outstanding.
  static Future<PayBackAllResult> payBackAll(
    String email, {
    required NotificationSender notifications,
  }) async {
    final groupList = await GroupRepository.fetchData("active", paidTo: email);
    return applyPayBackAll(
      resolvePayBackAll(
        groups: groupList,
        email: email,
        recordedBy: supabase.auth.currentUser?.email ?? '',
      ),
      notifications: notifications,
    );
  }

  /// Writes every settled target, each followed by the same notify step a single
  /// payback runs. A failed write sends nothing for its group, does not hold back
  /// the others (Future.wait waits for all), and still fails the run.
  @visibleForTesting
  static Future<PayBackAllResult> applyPayBackAll(
    PayBackAllPlan plan, {
    required NotificationSender notifications,
  }) async {
    final write =
        payBackAllWriteOverride ??
        (PayBackAllTarget t) => _writePayBack(t.groupId, t.accepted);
    await Future.wait(
      plan.settle.map((target) async {
        await write(target);
        _notifyPayBack(notifications, target.groupId, target.accepted);
      }),
    );

    return PayBackAllResult(
      settledGroupNames: [for (final target in plan.settle) target.groupName],
      skippedGroupNames: plan.skipped,
      settledAmounts: sumByCurrency([
        for (final target in plan.settle)
          CurrencyAmount(target.currency, target.amount.abs()),
      ]),
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

  /// Deletes [groupId] in ONE server transaction (`delete_group`): the group
  /// row (its members, expenses and summary rows go by FK cascade) and its
  /// `group_update_checker` row, whose DELETE event drops the group from other
  /// members' lists. Never recalculates: that would re-create the checker row.
  static Future<void> delete(String groupId) async {
    await supabase.rpc(deleteRpcName, params: deleteRpcParams(groupId));
  }
}

/// One group a [GroupRepository.payBackAll] run will settle, with everything
/// that write needs already resolved.
class PayBackAllTarget {
  const PayBackAllTarget({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.amount,
    required this.accepted,
  });

  final String groupId;
  final String groupName;

  /// The group's own currency — the one this per-group write settles in.
  final Currency currency;

  /// The per-group amount, never the cross-group total.
  final double amount;

  /// The payback plan already resolved against the group's full roster: the
  /// write takes its ids and amount, the push its receivers and names.
  final PaybackAccepted accepted;
}

/// Settle-all's per-target write, as one function.
typedef PayBackAllWrite = Future<void> Function(PayBackAllTarget target);

/// One RPC as a payback write issues it: the function name and its argument
/// map.
typedef PaybackRpc =
    Future<Object?> Function(String function, Map<String, dynamic> params);

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
/// Each group is settled in ITS OWN currency, so what was paid is a list of
/// per-currency totals, never one merged figure — the confirmation names them
/// all. [skippedGroupNames] stays load-bearing: a single group left unsettled
/// means a "you paid back X" confirmation would be a lie.
class PayBackAllResult {
  const PayBackAllResult({
    required this.settledGroupNames,
    required this.skippedGroupNames,
    this.settledAmounts = const [],
  });

  final List<String> settledGroupNames;
  final List<String> skippedGroupNames;

  /// Total actually settled per currency, primary first. Positive magnitudes.
  final List<CurrencyAmount> settledAmounts;

  /// True when every group that owed something was settled.
  bool get isComplete => skippedGroupNames.isEmpty;
}
