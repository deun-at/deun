import 'package:deun/main.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'pages/groups/data/group_repository.dart';
import 'pages/expenses/data/expense_repository.dart';
import 'pages/expenses/data/expense_category.dart';
import 'pages/users/user_model.dart';
import 'pages/statistics/statistics_models.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
class UserDetailNotifier extends _$UserDetailNotifier {
  @override
  FutureOr<SupaUser> build() async {
    return await fetchUserDetail();
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
    final expenses = await ExpenseRepository.fetchRange(groupId, starts.first, ends.last);

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
    final expenses = await ExpenseRepository.fetchRange(args.groupId, args.monthStart, args.monthEnd);

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
    final group = await GroupRepository.fetchDetail(args.groupId);
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
    final expenses = await ExpenseRepository.fetchRange(args.groupId, args.monthStart, args.monthEnd);

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
      return CategoryMonthTotal(categoryName: entry.key, categoryDisplayName: category.name, total: entry.value);
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
    final expenses = await ExpenseRepository.fetchRange(args.groupId, args.monthStart, args.monthEnd);

    // Filter expenses by category
    final categoryExpenses = expenses.where((expense) {
      final categoryName = expense.category?.name ?? 'other';
      return categoryName == args.categoryName;
    }).toList();

    // Convert to CategoryExpenseDetail list
    final List<CategoryExpenseDetail> details = [];
    for (final expense in categoryExpenses) {
      final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
      details.add(
        CategoryExpenseDetail(
          expenseId: expense.id,
          expenseName: expense.name,
          expenseDate: expense.expenseDate,
          amount: sum,
          paidBy: expense.paidBy ?? 'unknown',
          paidByDisplayName: expense.paidByDisplayName ?? 'Unknown',
        ),
      );
    }

    // Sort by date (newest first)
    details.sort((a, b) => -a.expenseDate.compareTo(b.expenseDate));

    return details;
  }
}
