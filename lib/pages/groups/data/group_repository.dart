import 'dart:convert';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';
import '../../../main.dart';
import 'member_removal.dart';

class GroupRepository {
  static Future<List<Group>> fetchData(
    String statusFilter, {
    String? paidTo,
  }) async {
    var currentUserEmail = supabase.auth.currentUser?.email ?? '';
    var query = supabase.from('group').select(Group.groupSelectString);

    if (statusFilter == 'active') {
      query = query.or(
        'total_share_amount.gte.0.01,total_share_amount.lte.-0.01',
        referencedTable: 'group_shares_summary_helper',
      );
    } else if (statusFilter == 'done') {
      query = query.lt("group_shares_summary_helper.total_share_amount", 0.01);
      query = query.gt("group_shares_summary_helper.total_share_amount", -0.01);
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

  static List<Map<String, dynamic>> decodeGroupMembersString(
    String? jsonValue,
  ) {
    var selectedGroupMembers = List<Map<String, dynamic>>.from(
      jsonDecode(jsonValue ?? "[]"),
    );

    if (selectedGroupMembers.isEmpty) {
      selectedGroupMembers.add({
        'email': supabase.auth.currentUser?.email ?? '',
        'display_name': '',
      });
    }

    return selectedGroupMembers;
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

      List<Map<String, dynamic>> groupMembers = decodeGroupMembersString(
        formValue['group_members'],
      );

      Set<String> notificationReceiver = {};
      for (var groupMember in groupMembers) {
        if ((groupMember['is_guest'] ?? false) == false &&
            (groupMember['is_guest_pending'] ?? false) == false) {
          notificationReceiver.add(groupMember['email']);
        }
      }

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

      if (groupId == null && context.mounted) {
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

    final newRows = <Map<String, dynamic>>[];
    final reAddEmails = <String>[];
    for (final groupMember in members) {
      final email = (groupMember['email'] as String?) ?? '';
      if (email.isEmpty) continue;
      if (existingEmails.contains(email)) {
        reAddEmails.add(email);
      } else {
        newRows.add({'group_id': savedGroupId, 'email': email});
      }
    }

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

  static Future<void> payBack(
    BuildContext context,
    String groupId,
    String email,
    double amount, {
    bool sendNotification = true,
  }) async {
    final expenseId = await supabase.rpc(
      'pay_back',
      params: {
        "_group_id": groupId,
        "_paid_by": supabase.auth.currentUser?.email,
        "_paid_for": email,
        "_amount": amount,
      },
    );

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
      sendGroupPayBackNotification(context, groupId, expenseId, {
        email,
      }, amount);
    }
  }

  static Future<void> payBackAll(BuildContext context, String email) async {
    final groupList = await GroupRepository.fetchData("active", paidTo: email);

    await Future.wait(
      groupList.map((groupData) async {
        double groupAmount = 0;
        groupData.groupSharesSummary.forEach((key, groupShare) {
          if (key == email) {
            groupAmount = roundCurrency(groupAmount + groupShare.shareAmount);
          }
        });

        // Only settle groups where the current user owes this friend, and pay
        // back exactly the per-group amount — not the cross-group total.
        if (groupAmount <= -0.01) {
          await GroupRepository.payBack(
            context,
            groupData.id,
            email,
            groupAmount.abs(),
            sendNotification: false,
          );
        }
      }),
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
