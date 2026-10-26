import 'package:deun/helper/currency.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_member_model.dart';
import 'member_add.dart';
import 'member_removal.dart';

part 'member_repository.g.dart';

class MemberRepository {
  MemberRepository(this._supabase, this._currentUser);

  final SupabaseClient _supabase;
  final CurrentUser? _currentUser;

  /// The RPC an invite-link join calls — the ONE place its name lives.
  static const String joinGroupRpcName = 'join_group';

  /// The `join_group` argument map — the ONE place its argument names live.
  /// Always both keys: `_guest_email` is null when joining as a new member.
  static Map<String, dynamic> joinGroupRpcParams({
    required String groupId,
    String? guestEmail,
  }) => {'_group_id': groupId, '_guest_email': guestEmail};

  /// The RPCs the member writes — the ONE place their
  /// names live.
  static const String addMemberRpcName = 'add_group_member';
  static const String removeMemberRpcName = 'remove_group_member';

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
  Future<List<GroupMember>> roster(String groupId) async {
    final rows = await _supabase
        .from('group_member')
        .select(_rosterSelect)
        .eq('group_id', groupId);
    return rows
        .map((row) => GroupMember()..loadDataFromJson(row))
        .toList(growable: false);
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
  Future<MemberRemovalOutcome> removeMember(
    String groupId,
    String email, {
    required Currency currency,
  }) async => memberRemovalOutcomeFromRpc(
    await _supabase.rpc(
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
  Future<MemberAddOutcome> addMember(String groupId, String email) async =>
      memberAddOutcomeFromRpc(
        await _supabase.rpc(
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
  Future<void> joinGroup(String groupId, {String? guestEmail}) async {
    await _supabase.rpc(
      joinGroupRpcName,
      params: joinGroupRpcParams(groupId: groupId, guestEmail: guestEmail),
    );
  }

  /// What the join page shows: the claimable guests (through the SECURITY
  /// DEFINER `group_join_guests`, since a not-yet-member cannot read the roster)
  /// and the signed-in user's own membership row, read in parallel.
  Future<GroupJoinState> fetchJoinState(String groupId) async {
    final email = _currentUser?.email;
    final results = await Future.wait<dynamic>([
      _supabase.rpc('group_join_guests', params: {'_group_id': groupId}),
      if (email != null)
        _supabase
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
  Future<MemberRemovalOutcome> previewMemberRemoval(
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
  Future<double> _memberGroupBalance(String groupId, String email) async {
    final rows = await _supabase
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
  Future<bool> _hasExpenseHistory(String groupId, String email) async {
    final paidRows = await _supabase
        .from('expense')
        .select('id')
        .eq('group_id', groupId)
        .eq('paid_by', email)
        .limit(1);
    if (paidRows.isNotEmpty) return true;

    // Both filters sit exactly one embed level from expense_entry — the same
    // shape fetchData already uses for `group_shares_summary_helper.paid_for`.
    final shareRows = await _supabase
        .from('expense_entry')
        .select('id, expense!inner(group_id), expense_entry_share!inner(email)')
        .eq('expense.group_id', groupId)
        .eq('expense_entry_share.email', email)
        .limit(1);

    return shareRows.isNotEmpty;
  }

  /// Stars or unstars [groupId] on the signed-in user's own membership row.
  Future<void> toggleFavorite(String groupId, bool isFavorite) async {
    final email = _currentUser?.email ?? '';
    await _supabase
        .from('group_member')
        .update({'is_favorite': isFavorite})
        .eq('group_id', groupId)
        .eq('email', email);
  }
}

@Riverpod(keepAlive: true)
MemberRepository memberRepository(Ref ref) => MemberRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(currentUserProvider),
);
