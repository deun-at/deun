import 'package:deun/constants.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';
import 'pages/expenses/expense_category.dart';
import 'pages/users/user_model.dart';
import 'pages/statistics/statistics_models.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
class GroupListNotifier extends _$GroupListNotifier {
  @override
  FutureOr<List<Group>> build(String statusFilter) async {
    _subscribeToRealTimeUpdates(statusFilter);

    return await fetchGroupList(statusFilter);
  }

  Future<void> reload(String statusFilter) async {
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
              debugPrint(payload.eventType.toString());
              if (payload.eventType == PostgresChangeEvent.delete) {
                final groupId = payload.oldRecord['group_id'];
                state = state.whenData((groups) {
                  final index = groups.indexWhere((g) => g.id == groupId);
                  if (index == -1) return groups; // Group not found
                  final updated = List<Group>.from(groups);
                  updated.removeAt(index);
                  return updated;
                });
                return;
              } else if (payload.eventType == PostgresChangeEvent.update ||
                  payload.eventType == PostgresChangeEvent.insert) {
                final groupId = payload.newRecord['group_id'];
                final group = await Group.fetchDetail(groupId);

                bool matchesFilter;
                final absAmt = group.totalShareAmount.abs();
                if (statusFilter == GroupListFilter.active.value) {
                  matchesFilter = absAmt >= 0.01;
                } else if (statusFilter == GroupListFilter.done.value) {
                  matchesFilter = absAmt < 0.01;
                } else {
                  matchesFilter = true;
                }

                state = state.whenData((groups) {
                  final updated = List<Group>.from(groups);
                  final index = updated.indexWhere((g) => g.id == group.id);

                  if (!matchesFilter) {
                    if (index != -1) updated.removeAt(index);
                    return updated;
                  }

                  if (index != -1) {
                    updated[index] = group;
                  } else {
                    updated.add(group);
                  }
                  updated.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  return updated;
                });
                return;
              }
            })
        .subscribe((status, _) {
      debugPrint('---subscribe--- groupList ${status.toString()}');
    });
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  FutureOr<Group> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);
    return await Group.fetchDetail(groupId);
  }

  Future<void> reload(String groupId) async {
    state = await AsyncValue.guard(() async => await Group.fetchDetail(groupId));
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
        .subscribe((status, _) {
      debugPrint('---subscribe--- groupDetails ${status.toString()}');
    });
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

  Future<void> reload(String groupId) async {
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
            })
        .subscribe((status, _) {
      debugPrint('---subscribe--- expenseList ${status.toString()}');
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
        .subscribe((status, _) {
      debugPrint('---subscribe--- friendshipList ${status.toString()}');
    });

    supabase
        .channel('public:friendship_list_group_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) async {
              reload();
            })
        .subscribe((status, _) {
      debugPrint('---subscribe--- friendshipGroupList ${status.toString()}');
    });
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
  FutureOr<SupaUser> build() async {
    return await fetchUserDetail();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchUserDetail());
  }

  Future<SupaUser> fetchUserDetail() async {
    return await UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '');
  }
}

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale? build() => null;

  void setLocale(Locale locale) => state = locale;

  void resetLocale() => state = null;
}

@riverpod
class GroupMonthlyTotalsNotifier extends _$GroupMonthlyTotalsNotifier {
  @override
  FutureOr<GroupMonthlyTotalsState> build(String groupId) async {
    return await _loadRange(groupId, 0);
  }

  Future<void> loadOffset(String groupId, int endOffsetMonths) async {
    state = await AsyncValue.guard(() async => await _loadRange(groupId, endOffsetMonths));
  }

  Future<GroupMonthlyTotalsState> _loadRange(String groupId, int endOffsetMonths) async {
    DateTime now = DateTime.now();
    // Determine the last included month start for this page (0 = current month)
    DateTime lastIncludedMonthStart = DateTime(now.year, now.month - endOffsetMonths, 1);

    // Build 6 months ending at lastIncludedMonthStart
    List<DateTime> starts = [];
    for (int i = 5; i >= 0; i--) {
      starts.add(DateTime(lastIncludedMonthStart.year, lastIncludedMonthStart.month - i, 1));
    }
    final List<DateTime> ends = starts.map((s) => DateTime(s.year, s.month + 1, 1)).toList();

    // Fetch expenses for range
    final expenses = await Expense.fetchRange(groupId, starts.first, ends.last);

    // Aggregate into months
    final List<double> totals = List<double>.filled(6, 0);
    for (final expense in expenses) {
      final date = DateTime.parse(expense.expenseDate);
      for (int i = 0; i < 6; i++) {
        if (!date.isBefore(starts[i]) && date.isBefore(ends[i])) {
          final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
          totals[i] = totals[i] + sum;
          break;
        }
      }
    }

    final months = List<MonthBucket>.generate(6, (i) => MonthBucket(start: starts[i], end: ends[i], total: totals[i]));

    return GroupMonthlyTotalsState(groupId: groupId, endOffsetMonths: endOffsetMonths, months: months);
  }
}

@riverpod
class GroupMonthMemberTotalsNotifier extends _$GroupMonthMemberTotalsNotifier {
  @override
  FutureOr<List<MemberMonthTotal>> build(GroupMonthMemberTotalsArgs args) async {
    return await _load(args);
  }

  Future<List<MemberMonthTotal>> _load(GroupMonthMemberTotalsArgs args) async {
    final expenses = await Expense.fetchRange(args.groupId, args.monthStart, args.monthEnd);

    final Map<String, MemberMonthTotal> byMember = {};
    for (final expense in expenses) {
      for (final entry in expense.expenseEntries.values) {
        if (entry.expenseEntryShares.isEmpty) {
          // If no shares stored, fall back to paidBy if available
          final email = expense.paidBy ?? 'unknown';
          final displayName = expense.paidByDisplayName ?? 'Unknown';
          final existing = byMember[email];
          byMember[email] = MemberMonthTotal(
            email: email,
            displayName: displayName,
            total: (existing?.total ?? 0) + entry.amount,
          );
        } else {
          for (final share in entry.expenseEntryShares) {
            final amount = entry.amount * (share.percentage / 100);
            final existing = byMember[share.email];
            byMember[share.email] = MemberMonthTotal(
              email: share.email,
              displayName: share.displayName,
              total: (existing?.total ?? 0) + amount,
            );
          }
        }
      }
    }

    // Ensure members with zero are present if group has members
    final group = await Group.fetchDetail(args.groupId);
    for (final m in group.groupMembers) {
      byMember[m.email] = byMember[m.email] ?? MemberMonthTotal(email: m.email, displayName: m.displayName, total: 0);
    }

    final list = byMember.values.toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}

@riverpod
class GroupMonthCategoryTotalsNotifier extends _$GroupMonthCategoryTotalsNotifier {
  @override
  FutureOr<List<CategoryMonthTotal>> build(GroupMonthCategoryTotalsArgs args) async {
    return await _load(args);
  }

  Future<List<CategoryMonthTotal>> _load(GroupMonthCategoryTotalsArgs args) async {
    final expenses = await Expense.fetchRange(args.groupId, args.monthStart, args.monthEnd);

    final Map<String, double> byCategory = {};
    for (final expense in expenses) {
      final categoryName = expense.category?.name ?? 'other';
      final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
      byCategory[categoryName] = (byCategory[categoryName] ?? 0) + sum;
    }

    // Filter out categories with zero amount and convert to list
    final list = byCategory.entries.where((entry) => entry.value > 0).map((entry) {
      final category = ExpenseCategory.values.firstWhere(
        (c) => c.name == entry.key,
        orElse: () => ExpenseCategory.other,
      );
      return CategoryMonthTotal(
        categoryName: entry.key,
        categoryDisplayName: category.name,
        total: entry.value,
      );
    }).toList();

    // Sort by total (descending), but keep 'other' category at the end
    list.sort((a, b) {
      if (a.categoryName == 'other' && b.categoryName != 'other') return 1;
      if (b.categoryName == 'other' && a.categoryName != 'other') return -1;
      return b.total.compareTo(a.total);
    });

    return list;
  }
}

@riverpod
class CategoryExpenseDetailsNotifier extends _$CategoryExpenseDetailsNotifier {
  @override
  FutureOr<List<CategoryExpenseDetail>> build(CategoryExpenseDetailsArgs args) async {
    return await _load(args);
  }

  Future<List<CategoryExpenseDetail>> _load(CategoryExpenseDetailsArgs args) async {
    final expenses = await Expense.fetchRange(args.groupId, args.monthStart, args.monthEnd);

    // Filter expenses by category
    final categoryExpenses = expenses.where((expense) {
      final categoryName = expense.category?.name ?? 'other';
      return categoryName == args.categoryName;
    }).toList();

    // Convert to CategoryExpenseDetail list
    final List<CategoryExpenseDetail> details = [];
    for (final expense in categoryExpenses) {
      final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
      details.add(CategoryExpenseDetail(
        expenseId: expense.id,
        expenseName: expense.name,
        expenseDate: expense.expenseDate,
        amount: sum,
        paidBy: expense.paidBy ?? 'unknown',
        paidByDisplayName: expense.paidByDisplayName ?? 'Unknown',
      ));
    }

    // Sort by date (newest first)
    details.sort((a, b) => -a.expenseDate.compareTo(b.expenseDate));

    return details;
  }
}
