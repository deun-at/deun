import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../main.dart';
import '../../groups/data/group_repository.dart';
import '../../expenses/data/expense_category.dart';
import '../../expenses/data/expense_model.dart';
import '../../expenses/data/expense_repository.dart';
import '../statistics_models.dart';

// Necessary for code-generation to work
part 'statistics_notifiers.g.dart';

// --- Shared helpers -------------------------------------------------------

class StatsWindow {
  final DateTime start;
  final DateTime end;
  const StatsWindow(this.start, this.end);
}

class GroupRangeData {
  final StatsWindow window;
  final List<Expense> expenses;
  const GroupRangeData({required this.window, required this.expenses});
}

Future<StatsWindow> _resolveWindow(String groupId, StatsRange range, {int offsetMonths = 0}) async {
  final now = DateTime.now();
  if (range == StatsRange.allTime) {
    final end = DateTime(now.year, now.month + 1, 1);
    final rows = await supabase
        .from('expense')
        .select('expense_date')
        .eq('group_id', groupId)
        .eq('is_paid_back_row', false)
        .order('expense_date', ascending: true)
        .limit(1);
    DateTime start;
    if (rows.isEmpty) {
      start = DateTime(now.year, now.month, 1);
    } else {
      final raw = DateTime.parse(rows.first['expense_date'] as String);
      start = DateTime(raw.year, raw.month, 1);
    }
    return StatsWindow(start, end);
  }
  // Shift window into the past by offsetMonths. Last included month is (now - offset).
  final lastIncluded = DateTime(now.year, now.month - offsetMonths, 1);
  final end = DateTime(lastIncluded.year, lastIncluded.month + 1, 1);
  final start = DateTime(lastIncluded.year, lastIncluded.month - (range.months! - 1), 1);
  return StatsWindow(start, end);
}

StatsWindow _previousWindow(StatsWindow window) {
  final months = _monthsBetween(window.start, window.end);
  final prevEnd = window.start;
  final prevStart = DateTime(prevEnd.year, prevEnd.month - months, 1);
  return StatsWindow(prevStart, prevEnd);
}

int _monthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month);
}

List<MonthBucket> _bucketByMonth(List<Expense> expenses, DateTime start, DateTime end) {
  final months = _monthsBetween(start, end);
  if (months <= 0) return const [];
  final starts = List<DateTime>.generate(months, (i) => DateTime(start.year, start.month + i, 1));
  final ends = List<DateTime>.generate(months, (i) => DateTime(start.year, start.month + i + 1, 1));
  final totals = List<double>.filled(months, 0);
  for (final expense in expenses) {
    final date = DateTime.parse(expense.expenseDate);
    for (int i = 0; i < months; i++) {
      if (!date.isBefore(starts[i]) && date.isBefore(ends[i])) {
        final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
        totals[i] = totals[i] + sum;
        break;
      }
    }
  }
  return List<MonthBucket>.generate(
    months,
    (i) => MonthBucket(start: starts[i], end: ends[i], total: totals[i]),
  );
}

double _sumExpenses(List<Expense> expenses) {
  double total = 0;
  for (final expense in expenses) {
    for (final entry in expense.expenseEntries.values) {
      total += entry.amount;
    }
  }
  return total;
}

// --- Existing providers (unchanged behaviour) ----------------------------

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
    DateTime lastIncludedMonthStart = DateTime(now.year, now.month - endOffsetMonths, 1);

    List<DateTime> starts = [];
    for (int i = 5; i >= 0; i--) {
      starts.add(DateTime(lastIncludedMonthStart.year, lastIncludedMonthStart.month - i, 1));
    }
    final List<DateTime> ends = starts.map((s) => DateTime(s.year, s.month + 1, 1)).toList();

    final expenses = await ExpenseRepository.fetchRange(groupId, starts.first, ends.last);

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
    return _aggregateCategories(expenses);
  }
}

List<CategoryMonthTotal> _aggregateCategories(List<Expense> expenses) {
  final Map<String, double> byCategory = {};
  for (final expense in expenses) {
    final categoryName = expense.category?.name ?? 'other';
    final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
    byCategory[categoryName] = (byCategory[categoryName] ?? 0) + sum;
  }

  final list = byCategory.entries.where((entry) => entry.value > 0).map((entry) {
    final category = ExpenseCategory.values.firstWhere(
      (c) => c.name == entry.key,
      orElse: () => ExpenseCategory.other,
    );
    return CategoryMonthTotal(categoryName: entry.key, categoryDisplayName: category.name, total: entry.value);
  }).toList();

  list.sort((a, b) {
    if (a.categoryName == 'other' && b.categoryName != 'other') return 1;
    if (b.categoryName == 'other' && a.categoryName != 'other') return -1;
    return b.total.compareTo(a.total);
  });

  return list;
}

@riverpod
class CategoryExpenseDetailsNotifier extends _$CategoryExpenseDetailsNotifier {
  @override
  FutureOr<List<CategoryExpenseDetail>> build(CategoryExpenseDetailsArgs args) async {
    return await _load(args);
  }

  Future<List<CategoryExpenseDetail>> _load(CategoryExpenseDetailsArgs args) async {
    final expenses = await ExpenseRepository.fetchRange(args.groupId, args.monthStart, args.monthEnd);

    final categoryExpenses = expenses.where((expense) {
      final categoryName = expense.category?.name ?? 'other';
      return categoryName == args.categoryName;
    }).toList();

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

    details.sort((a, b) => -a.expenseDate.compareTo(b.expenseDate));

    return details;
  }
}

// --- New range-based providers -------------------------------------------

@riverpod
class GroupRangeDataNotifier extends _$GroupRangeDataNotifier {
  @override
  FutureOr<GroupRangeData> build(StatsRangeArgs args) async {
    final window = await _resolveWindow(args.groupId, args.range, offsetMonths: args.endOffsetMonths);
    final expenses = await ExpenseRepository.fetchRange(args.groupId, window.start, window.end);
    return GroupRangeData(window: window, expenses: expenses);
  }
}

@riverpod
Future<SpendingSummary> groupSpendingSummary(Ref ref, StatsRangeArgs args) async {
  final data = await ref.watch(groupRangeDataProvider(args).future);
  final expenses = data.expenses;
  if (expenses.isEmpty) {
    return SpendingSummary.empty;
  }

  final total = _sumExpenses(expenses);
  double biggest = 0;
  for (final expense in expenses) {
    final sum = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
    if (sum > biggest) biggest = sum;
  }

  final months = _monthsBetween(data.window.start, data.window.end);
  final avgPerMonth = months > 0 ? total / months : 0.0;

  // Previous period — only meaningful for bounded ranges.
  double prevTotal = 0;
  if (args.range != StatsRange.allTime) {
    final prev = _previousWindow(data.window);
    final prevExpenses = await ExpenseRepository.fetchRange(args.groupId, prev.start, prev.end);
    prevTotal = _sumExpenses(prevExpenses);
  }
  final deltaPct = prevTotal > 0 ? ((total - prevTotal) / prevTotal) * 100 : 0.0;

  return SpendingSummary(
    total: total,
    expenseCount: expenses.length,
    avgPerMonth: avgPerMonth,
    biggestExpense: biggest,
    prevPeriodTotal: prevTotal,
    deltaPct: deltaPct,
  );
}

@riverpod
Future<List<MonthBucket>> groupTrend(Ref ref, StatsRangeArgs args) async {
  final data = await ref.watch(groupRangeDataProvider(args).future);
  return _bucketByMonth(data.expenses, data.window.start, data.window.end);
}

@riverpod
Future<List<MemberSpendingBreakdown>> groupMemberBreakdown(Ref ref, StatsRangeArgs args) async {
  final data = await ref.watch(groupRangeDataProvider(args).future);
  final expenses = data.expenses;

  final Map<String, String> names = {};
  final Map<String, double> paid = {};
  final Map<String, double> fairShare = {};
  double total = 0;

  for (final expense in expenses) {
    final expenseTotal = expense.expenseEntries.values.fold<double>(0, (acc, e) => acc + e.amount);
    total += expenseTotal;

    final payer = expense.paidBy;
    if (payer != null) {
      names[payer] = expense.paidByDisplayName ?? payer;
      paid[payer] = (paid[payer] ?? 0) + expenseTotal;
    }

    for (final entry in expense.expenseEntries.values) {
      if (entry.expenseEntryShares.isEmpty) {
        final email = expense.paidBy ?? 'unknown';
        names[email] = expense.paidByDisplayName ?? 'Unknown';
        fairShare[email] = (fairShare[email] ?? 0) + entry.amount;
      } else {
        for (final share in entry.expenseEntryShares) {
          names[share.email] = share.displayName;
          final amount = entry.amount * (share.percentage / 100);
          fairShare[share.email] = (fairShare[share.email] ?? 0) + amount;
        }
      }
    }
  }

  // Include all group members so everyone shows up, even with zero activity.
  final group = await GroupRepository.fetchDetail(args.groupId);
  for (final m in group.groupMembers) {
    names[m.email] = names[m.email] ?? m.displayName;
  }

  final emails = names.keys.toSet();
  final list = emails.map((email) {
    final p = paid[email] ?? 0;
    final f = fairShare[email] ?? 0;
    final pct = total > 0 ? (p / total) * 100 : 0.0;
    return MemberSpendingBreakdown(
      email: email,
      displayName: names[email] ?? email,
      paid: p,
      fairShare: f,
      pctOfTotal: pct,
    );
  }).toList();

  list.sort((a, b) => b.paid.compareTo(a.paid));
  return list;
}

@riverpod
Future<List<CategoryMonthTotal>> groupCategoryBreakdown(Ref ref, StatsRangeArgs args) async {
  final data = await ref.watch(groupRangeDataProvider(args).future);
  return _aggregateCategories(data.expenses);
}
