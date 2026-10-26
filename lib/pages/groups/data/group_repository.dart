import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';

part 'group_repository.g.dart';

class GroupRepository {
  GroupRepository(
    this._supabase,
    this._currentUser, {
    Future<Object?> Function(Map<String, dynamic> params)? saveGroupAllRpc,
  }) : _saveGroupAllRpc = saveGroupAllRpc;

  final SupabaseClient _supabase;
  final CurrentUser? _currentUser;

  /// Null outside tests. When set, [saveAll] sends its one `save_group_all`
  /// call here instead of the client.
  final Future<Object?> Function(Map<String, dynamic> params)? _saveGroupAllRpc;

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

  /// The RPC the group delete calls — the ONE place its name lives.
  static const String deleteRpcName = 'delete_group';

  /// The `delete_group` argument map.
  static Map<String, dynamic> deleteRpcParams(String groupId) => {
    '_group_id': groupId,
  };

  Future<List<Group>> fetchData(String statusFilter, {String? paidTo}) async {
    var currentUserEmail = _currentUser?.email ?? '';
    var query = _supabase.from('group').select(Group.groupSelectString);

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
      group.loadDataFromJson(element, currentUserEmail: _currentUser?.email);
      retData.add(group);
    }

    return narrowToStatus(retData, statusFilter);
  }

  Future<Group> fetchDetail(String groupId) async {
    Map<String, dynamic> data = await _supabase
        .from('group')
        .select(Group.groupSelectString)
        .eq('id', groupId)
        .single();

    Group group = Group();
    group.loadDataFromJson(data, currentUserEmail: _currentUser?.email);

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
  ///   the Members page (`MemberRepository.addMember` / `removeMember`) is the
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

  /// Saves a group in ONE server transaction (`save_group_all`): the group
  /// row, the creator's membership on a create (guest user creation included)
  /// and the share recalculation commit together or not at all. Returns the id
  /// the RPC returned. Any failure, a missing function included, is thrown as
  /// the RPC's own error having written nothing: there is no client-side
  /// fallback.
  Future<String> saveAll(
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
        "user_id": _currentUser?.id,
      };

      if (groupId != null) {
        upsertVals.addAll({'id': groupId});
      }

      // group-member-add-flow: membership is not a group attribute any more —
      // an edit submits NO members, and a create submits the creator alone.
      final List<Map<String, dynamic>> groupMembers = resolveSaveMembers(
        isCreate: groupId == null,
        currentUserEmail: _currentUser?.email,
      );

      final Map<String, dynamic> params = {
        '_group': upsertVals,
        '_members': groupMembers,
      };
      final override = _saveGroupAllRpc;
      return (override != null
              ? await override(params)
              : await _supabase.rpc('save_group_all', params: params))
          as String;
    } on PostgrestException catch (e) {
      debugPrint('Failed to save group ${groupId ?? 'new'}: ${e.message}');
      rethrow;
    }
  }

  /// Deletes [groupId] in ONE server transaction (`delete_group`): the group
  /// row (its members, expenses and summary rows go by FK cascade) and its
  /// `group_update_checker` row, whose DELETE event drops the group from other
  /// members' lists. Never recalculates: that would re-create the checker row.
  Future<void> delete(String groupId) async {
    await _supabase.rpc(deleteRpcName, params: deleteRpcParams(groupId));
  }
}

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepository(
  ref.watch(supabaseClientProvider),
  ref.watch(currentUserProvider),
);
