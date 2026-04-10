import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

part 'expense_list.g.dart';

@riverpod
class ExpenseListNotifier extends _$ExpenseListNotifier with RealtimeNotifierMixin {
  static const int pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;

  @override
  FutureOr<List<Expense>> build(String groupId) async {
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      channelName: 'expense_list:$groupId',
      table: 'expense_update_checker',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      onEvent: (payload) async {
        if (payload.eventType == PostgresChangeEvent.delete) {
          final expenseId = payload.oldRecord['expense_id'];
          state = state.whenData((expenses) {
            final index = expenses.indexWhere((e) => e.id == expenseId);
            if (index == -1) return expenses;
            final updated = List<Expense>.from(expenses);
            updated.removeAt(index);
            return updated;
          });
          return;
        } else if (payload.eventType == PostgresChangeEvent.update ||
            payload.eventType == PostgresChangeEvent.insert) {
          final expenseId = payload.newRecord['expense_id'];
          final expense = await ExpenseRepository.fetchDetail(expenseId);

          state = state.whenData((expenses) {
            final updated = List<Expense>.from(expenses);
            final index = updated.indexWhere((g) => g.id == expense.id);

            if (index != -1) {
              updated[index] = expense;
            } else {
              updated.add(expense);
            }
            updated.sort((a, b) {
              int dateComparison = -a.expenseDate.compareTo(b.expenseDate);
              if (dateComparison == 0) {
                return -a.createdAt.compareTo(b.createdAt);
              }
              return dateComparison;
            });
            return updated;
          });
          return;
        }
      },
    );

    listenForResume(ref: ref, onResume: () => reload(groupId));

    return await ExpenseRepository.fetchData(groupId, _offset, _offset + pageSize - 1);
  }

  Future<void> reload(String groupId) async {
    if (!ref.mounted) return;
    final expectedCount = _offset + pageSize;
    state = await AsyncValue.guard(() async => await ExpenseRepository.fetchData(groupId, 0, expectedCount - 1));
    // Derive _hasMore from actual results instead of blindly resetting to true
    _hasMore = (state.value?.length ?? 0) >= expectedCount;
  }

  int get offset => _offset;

  Future<void> loadMoreEntries(String groupId) async {
    if (!_hasMore || state.isLoading) return;

    _offset += pageSize;
    final newExpenses = await ExpenseRepository.fetchData(groupId, _offset, _offset + pageSize - 1);

    if (newExpenses.isEmpty) {
      _hasMore = false;
      return;
    }

    state = state.whenData((expenses) {
      return [...expenses, ...newExpenses];
    });
  }
}
