import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../data/expense_model.dart';

part 'expense_list.g.dart';

@riverpod
class ExpenseListNotifier extends _$ExpenseListNotifier {
  RealtimeChannel? _channel;
  static const int pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;

  @override
  FutureOr<List<Expense>> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);

    // cleanup when provider is disposed
    ref.onDispose(() {
      if (_channel != null) {
        supabase.removeChannel(_channel!);
        _channel = null;
      }
    });

    return await Expense.fetchData(groupId, _offset, _offset + pageSize - 1);
  }

  Future<void> reload(String groupId) async {
    if (!ref.mounted) return; // prevent updates after dispose
    _hasMore = true;

    state = await AsyncValue.guard(() async => await Expense.fetchData(groupId, 0, _offset + pageSize - 1));
  }

  int get offset => _offset;

  void _subscribeToRealTimeUpdates(String groupId) {
    if(_channel != null) {
      supabase.removeChannel(_channel!);
    }

    _channel = supabase
        .channel('public:expense_list_checker')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_update_checker',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final expenseId = payload.oldRecord['expense_id'];
              state = state.whenData((expenses) {
                final index = expenses.indexWhere((e) => e.id == expenseId);
                if (index == -1) return expenses; // Group not found
                final updated = List<Expense>.from(expenses);
                updated.removeAt(index);
                return updated;
              });
              return;
            } else if (payload.eventType == PostgresChangeEvent.update ||
                payload.eventType == PostgresChangeEvent.insert) {
              final expenseId = payload.newRecord['expense_id'];
              final expense = await Expense.fetchDetail(expenseId);

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
        )
        ..subscribe((status, _) {
          debugPrint('---subscribe--- expenseList ${status.toString()}');
          if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
            ref.invalidateSelf();
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            reload(groupId);
          }
        });
  }

  Future<void> loadMoreEntries(String groupId) async {
    if (!_hasMore || state.isLoading) return;

    _offset += pageSize;
    final newExpenses = await Expense.fetchData(groupId, _offset, _offset + pageSize - 1);

    if (newExpenses.isEmpty) {
      _hasMore = false;
      return;
    }

    state = state.whenData((expenses) {
      return [...expenses, ...newExpenses];
    });
  }
}
