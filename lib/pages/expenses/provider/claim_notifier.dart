import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../helper/realtime_mixin.dart';
import '../data/claim_math.dart';
import '../data/expense_entry_model.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

part 'claim_notifier.g.dart';

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.
@riverpod
class ClaimNotifier extends _$ClaimNotifier with RealtimeNotifierMixin {
  late String _groupId;

  /// Distinct members currently on this claim screen, derived from Supabase
  /// Realtime presence on the `claim:$expenseId` channel — NOT how many members
  /// have claimed something. 0 until the first presence sync arrives (which
  /// includes the current client's own `track`), so the header's =0 branch
  /// ("No one claiming yet") shows only when presence is genuinely empty.
  int claimingNow = 0;

  @override
  FutureOr<Expense> build(String groupId, String expenseId) async {
    _groupId = groupId;
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    final me = supabase.auth.currentUser;

    subscribeToChannel(
      ref: ref,
      channelName: 'claim:$expenseId',
      table: 'expense_update_checker',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'expense_id',
        value: expenseId,
      ),
      onEvent: (_) async {
        final fresh = await ExpenseRepository.fetchDetail(expenseId);
        state = AsyncData(fresh);
      },
      // Presence: one key per member (a member on two devices still counts
      // once). ref.notifyListeners rebuilds the header subtitle live.
      presencePayload: {
        'email': me?.email ?? me?.id ?? 'anon',
        'ts': DateTime.now().toIso8601String(),
      },
      onPresence: (count) {
        claimingNow = count;
        ref.notifyListeners();
      },
    );

    listenForResume(
      ref: ref,
      onResume: () async {
        state = await AsyncValue.guard(() => ExpenseRepository.fetchDetail(expenseId));
      },
    );

    return await ExpenseRepository.fetchDetail(expenseId);
  }

  /// Claim units (split_mode 'claim') in stable DB order.
  List<ClaimUnit> get units {
    final expense = state.value;
    if (expense == null) return const [];
    return expense.expenseEntries.values
        .where((e) => e.isClaimUnit)
        .map((e) => ClaimUnit(
              unitCost: e.amount,
              claimers: e.expenseEntryShares.map((s) => s.email).toList(),
            ))
        .toList();
  }

  /// Item cards for the claim screen (F131): claim units grouped per item via
  /// the same [Expense.entriesByItem] grouping the editor's regrouping uses
  /// (item_group_id; standalone units group with themselves), one
  /// [ClaimUnitRow] slot per unit in stable order.
  List<ClaimItemGroup> get itemGroups {
    final expense = state.value;
    if (expense == null) return const [];
    return [
      for (final group in expense.entriesByItem.values)
        if (group.first.isClaimUnit)
          ClaimItemGroup(
            name: group.first.name,
            unitCost: group.first.amount,
            units: [for (final e in group) _rowOf(e)],
          ),
    ];
  }

  /// All claim-unit rows, flattened across [itemGroups]. The summary math and
  /// the confirm total bind to this; chips mutate via [ClaimUnitRow.entryId].
  List<ClaimUnitRow> get unitRows =>
      [for (final g in itemGroups) ...g.units];

  ClaimUnitRow _rowOf(ExpenseEntry e) => ClaimUnitRow(
        entryId: e.id,
        name: e.name,
        unit: ClaimUnit(
          unitCost: e.amount,
          claimers: e.expenseEntryShares.map((s) => s.email).toList(),
        ),
        claimerNames: {
          for (final s in e.expenseEntryShares) s.email: s.displayName,
        },
      );

  Map<String, double> get memberTotals => memberShareTotals(units);
  double get claimed => claimedTotal(units);
  double get unclaimed => unclaimedTotal(units);

  /// Adds [email] as a claimer of the unit [unitEntryId] (alongside any
  /// existing claimers). Split becomes unitCost / claimers.
  Future<void> claimUnit(String unitEntryId, String email) async {
    final current = _claimersOf(unitEntryId);
    if (current.contains(email)) return;
    await _setClaimers(unitEntryId, [...current, email]);
  }

  /// Removes [email] from the unit's claimers (unclaim / leave a split).
  Future<void> unclaimUnit(String unitEntryId, String email) async {
    final current = _claimersOf(unitEntryId);
    if (!current.contains(email)) return;
    await _setClaimers(unitEntryId, current.where((e) => e != email).toList());
  }

  /// "Split one": sets the exact claimer set chosen in the inline picker.
  Future<void> splitUnit(String unitEntryId, List<String> claimerEmails) async {
    await _setClaimers(unitEntryId, claimerEmails);
  }

  List<String> _claimersOf(String unitEntryId) {
    final entry = state.value?.expenseEntries[unitEntryId];
    return entry?.expenseEntryShares.map((s) => s.email).toList() ?? const [];
  }

  Future<void> _setClaimers(String unitEntryId, List<String> emails) async {
    final expenseId = state.value?.id;
    if (expenseId == null) return;
    await ExpenseRepository.claimSetUnitShares(
      groupId: _groupId,
      expenseId: expenseId,
      unitEntryId: unitEntryId,
      claimerEmails: emails,
    );
    // Realtime will refresh; optimistic refetch keeps UI snappy.
    state = await AsyncValue.guard(() => ExpenseRepository.fetchDetail(expenseId));
  }
}
