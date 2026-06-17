import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/claim_math.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

part 'claim_notifier.g.dart';

/// Owns the claim state for a single itemized expense. Loads the expense,
/// exposes its claim units + cost math, and mutates claimer sets per unit.
@riverpod
class ClaimNotifier extends _$ClaimNotifier with RealtimeNotifierMixin {
  late String _groupId;

  @override
  FutureOr<Expense> build(String groupId, String expenseId) async {
    _groupId = groupId;
    disposeChannels();
    ref.onDispose(() => disposeChannels());

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
