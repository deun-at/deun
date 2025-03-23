import 'package:deun/constants.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';
import 'pages/users/user_model.dart' as user_model;

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
class GroupListNotifier extends _$GroupListNotifier {
  @override
  FutureOr<List<Group>> build(String statusFilter) async {
    _subscribeToRealTimeUpdates(statusFilter);

    return await fetchGroupList(statusFilter);
  }

  Future<void> reload(statusFilter) async {
    state = await AsyncValue.guard(() async => await fetchGroupList(statusFilter));
  }

  Future<List<Group>> fetchGroupList(String statusFilter) async {
    return await Group.fetchData(statusFilter);
  }

  void _subscribeToRealTimeUpdates(String statusFilter) {
    supabase
        .channel('public:group_list_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) async {
              reload(statusFilter);
            })
        .subscribe(
      (status, object) {
        if (status == RealtimeSubscribeStatus.channelError) {
          _subscribeToRealTimeUpdates(statusFilter);
        }
      },
    );
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  FutureOr<Group> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);

    return await fetchGroupDetail(groupId);
  }

  Future<void> reload(groupId) async {
    state = await AsyncValue.guard(() async => await fetchGroupDetail(groupId));
  }

  Future<Group> fetchGroupDetail(String groupId) async {
    Group group = await Group.fetchDetail(groupId);

    return group;
  }

  void _subscribeToRealTimeUpdates(String groupId) {
    supabase
        .channel('public:group_detail_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) async {
              reload(groupId);
            })
        .subscribe(
      (status, object) {
        if (status == RealtimeSubscribeStatus.channelError) {
          _subscribeToRealTimeUpdates(groupId);
        }
      },
    );
  }
}

@riverpod
class ExpenseListNotifier extends _$ExpenseListNotifier {
  static const int pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;

  @override
  FutureOr<List<Expense>> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);

    return await fetchExpenseList(groupId, _offset, _offset + pageSize - 1);
  }

  Future<void> reload(groupId) async {
    _offset = 0;
    _hasMore = true;

    state = await AsyncValue.guard(() async => await fetchExpenseList(groupId, _offset, _offset + pageSize - 1));
  }

  int get offset => _offset;

  Future<List<Expense>> fetchExpenseList(String groupId, int rangeFrom, int rangeTo) async {
    List<Expense> expenses = await Expense.fetchData(groupId, rangeFrom, rangeTo);
    return expenses;
  }

  void _subscribeToRealTimeUpdates(String groupId) {
    debugPrint('haaans');
    supabase
        .channel('public:expense_list_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'expense_update_checker',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) async {
              if (payload.eventType == PostgresChangeEvent.delete) {
                state = state.whenData((expenses) {
                  final index = expenses.indexWhere((e) => e.id == payload.oldRecord['expense_id']);
                  if (index == -1) return expenses; // Expense not found, return original list

                  final updatedExpenses = List<Expense>.from(expenses);
                  updatedExpenses.removeAt(index);

                  return updatedExpenses;
                });
                return;
              } else if (payload.eventType == PostgresChangeEvent.update) {
                Expense expense = await Expense.fetchDetail(payload.newRecord['expense_id']);

                state = state.whenData((expenses) {
                  final index = expenses.indexWhere((e) => e.id == expense.id);
                  if (index == -1) return expenses; // Expense not found, return original list

                  final updatedExpenses = List<Expense>.from(expenses);
                  updatedExpenses[index] = expense;

                  return updatedExpenses;
                });
                return;
              } else if (payload.eventType == PostgresChangeEvent.insert) {
                Expense expense = await Expense.fetchDetail(payload.newRecord['expense_id']);

                state = state.whenData((expenses) {
                  return [
                    expense,
                    ...expenses
                  ]; //not optimal, currently just adds it to the beginning instead of sorting it by date
                });

                return;
              }
            })
        .subscribe(
      (status, object) {
        if (status == RealtimeSubscribeStatus.channelError) {
          _subscribeToRealTimeUpdates(groupId);
        }
      },
    );
  }

  Future<void> loadMoreEntries(String groupId) async {
    if (!_hasMore || state.isLoading) return; // ✅ Stop if no more data

    _offset += pageSize; // ✅ Increase the offset for the next page
    final newExpenses = await Expense.fetchData(groupId, _offset, _offset + pageSize - 1);

    if (newExpenses.isEmpty) {
      _hasMore = false; // ✅ No more data to load
      return;
    }

    state = state.whenData((expenses) {
      return [...expenses, ...newExpenses];
    });
  }
}

@riverpod
Future<List<Expense>> expenseList(Ref ref) async {
  return await Expense.fetchData();
}

@riverpod
class FriendshipListNotifier extends _$FriendshipListNotifier {
  @override
  FutureOr<List<Friendship>> build() async {
    _subscribeToRealTimeUpdates();

    return await fetchFriendshipList();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchFriendshipList());
  }

  Future<List<Friendship>> fetchFriendshipList() async {
    return await Friendship.fetchData();
  }

  void _subscribeToRealTimeUpdates() {
    supabase
        .channel('public:friendship_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendship',
          callback: (payload) {
            reload();
          },
        )
        .subscribe(
      (status, object) {
        if (status == RealtimeSubscribeStatus.channelError) {
          _subscribeToRealTimeUpdates();
        }
      },
    );
  }
}

@riverpod
class FriendshipDetailNotifier extends _$FriendshipDetailNotifier {
  @override
  FutureOr<Friendship> build(String email) async {
    return await fetchFriendshipDetail(email);
  }

  Future<void> reload(String email) async {
    state = await AsyncValue.guard(() async => await fetchFriendshipDetail(email));
  }

  Future<Friendship> fetchFriendshipDetail(String email) async {
    return await Friendship.fetchDetail(email);
  }
}

@riverpod
class UserDetailNotifier extends _$UserDetailNotifier {
  @override
  FutureOr<user_model.User> build() async {
    return await fetchUserDetail();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchUserDetail());
  }

  Future<user_model.User> fetchUserDetail() async {
    return await user_model.User.fetchDetail(supabase.auth.currentUser!.email ?? '');
  }
}

@riverpod
class ThemeColor extends _$ThemeColor {
  @override
  Color build() => ColorSeed.baseColor.color;

  void setColor(Color color) => state = color;
  void resetColor() => state = ColorSeed.baseColor.color;
}
