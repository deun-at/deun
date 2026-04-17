import 'package:equatable/equatable.dart';

enum StatsRange {
  threeMonths,
  sixMonths,
  twelveMonths,
  allTime;

  int? get months => switch (this) {
        StatsRange.threeMonths => 3,
        StatsRange.sixMonths => 6,
        StatsRange.twelveMonths => 12,
        StatsRange.allTime => null,
      };
}

class StatsRangeArgs extends Equatable {
  final String groupId;
  final StatsRange range;

  /// Number of months to shift the window into the past.
  /// 0 = current period; 1 = shifted by 1 month; etc. Ignored for [StatsRange.allTime].
  final int endOffsetMonths;

  const StatsRangeArgs({
    required this.groupId,
    required this.range,
    this.endOffsetMonths = 0,
  });

  @override
  List<Object?> get props => [groupId, range, endOffsetMonths];
}

class SpendingSummary extends Equatable {
  final double total;
  final int expenseCount;
  final double avgPerMonth;
  final double biggestExpense;
  final double prevPeriodTotal;
  final double deltaPct;

  const SpendingSummary({
    required this.total,
    required this.expenseCount,
    required this.avgPerMonth,
    required this.biggestExpense,
    required this.prevPeriodTotal,
    required this.deltaPct,
  });

  static const empty = SpendingSummary(
    total: 0,
    expenseCount: 0,
    avgPerMonth: 0,
    biggestExpense: 0,
    prevPeriodTotal: 0,
    deltaPct: 0,
  );

  @override
  List<Object?> get props => [total, expenseCount, avgPerMonth, biggestExpense, prevPeriodTotal, deltaPct];
}

class MemberSpendingBreakdown extends Equatable {
  final String email;
  final String displayName;
  final double paid;
  final double fairShare;
  final double pctOfTotal;

  double get delta => paid - fairShare;

  const MemberSpendingBreakdown({
    required this.email,
    required this.displayName,
    required this.paid,
    required this.fairShare,
    required this.pctOfTotal,
  });

  @override
  List<Object?> get props => [email, displayName, paid, fairShare, pctOfTotal];
}

class PersonalGroupSummary extends Equatable {
  final String groupId;
  final String groupName;
  final int colorValue;
  final double totalPaid;
  final double totalShare;
  final int expenseCount;

  const PersonalGroupSummary({
    required this.groupId,
    required this.groupName,
    required this.colorValue,
    required this.totalPaid,
    required this.totalShare,
    required this.expenseCount,
  });

  @override
  List<Object?> get props => [groupId, groupName, colorValue, totalPaid, totalShare, expenseCount];
}

class PersonalStatisticsState extends Equatable {
  final List<PersonalGroupSummary> groups;
  final List<MonthBucket> monthlyTotals;
  final double totalPaid;
  final double totalShare;
  final int expenseCount;

  const PersonalStatisticsState({
    required this.groups,
    required this.monthlyTotals,
    required this.totalPaid,
    required this.totalShare,
    required this.expenseCount,
  });

  static const empty = PersonalStatisticsState(
    groups: [],
    monthlyTotals: [],
    totalPaid: 0,
    totalShare: 0,
    expenseCount: 0,
  );

  @override
  List<Object?> get props => [groups, monthlyTotals, totalPaid, totalShare, expenseCount];
}

class MonthBucket extends Equatable {
  final DateTime start;
  final DateTime end;
  final double total;

  const MonthBucket({required this.start, required this.end, required this.total});

  @override
  List<Object?> get props => [start, end, total];
}

class GroupMonthlyTotalsState extends Equatable {
  final String groupId;
  final int endOffsetMonths; // 0 = current month, 1 = previous month, ...
  final List<MonthBucket> months; // exactly 6, ending at endOffsetMonths

  const GroupMonthlyTotalsState({required this.groupId, required this.endOffsetMonths, required this.months});

  @override
  List<Object?> get props => [groupId, endOffsetMonths, months];
}

class GroupMonthMemberTotalsArgs extends Equatable {
  final String groupId;
  final DateTime monthStart;
  final DateTime monthEnd;

  const GroupMonthMemberTotalsArgs({required this.groupId, required this.monthStart, required this.monthEnd});

  @override
  List<Object?> get props => [groupId, monthStart, monthEnd];
}

class GroupMonthlyTotalsArgs extends Equatable {
  final String groupId;
  final int endOffsetMonths;

  const GroupMonthlyTotalsArgs({required this.groupId, required this.endOffsetMonths});

  @override
  List<Object?> get props => [groupId, endOffsetMonths];
}

class MemberMonthTotal extends Equatable {
  final String email;
  final String displayName;
  final double total;

  const MemberMonthTotal({required this.email, required this.displayName, required this.total});

  @override
  List<Object?> get props => [email, displayName, total];
}

class CategoryMonthTotal extends Equatable {
  final String categoryName;
  final String categoryDisplayName;
  final double total;

  const CategoryMonthTotal({required this.categoryName, required this.categoryDisplayName, required this.total});

  @override
  List<Object?> get props => [categoryName, categoryDisplayName, total];
}

class GroupMonthCategoryTotalsArgs extends Equatable {
  final String groupId;
  final DateTime monthStart;
  final DateTime monthEnd;

  const GroupMonthCategoryTotalsArgs({required this.groupId, required this.monthStart, required this.monthEnd});

  @override
  List<Object?> get props => [groupId, monthStart, monthEnd];
}

class CategoryExpenseDetail extends Equatable {
  final String expenseId;
  final String expenseName;
  final String expenseDate;
  final double amount;
  final String paidBy;
  final String paidByDisplayName;

  const CategoryExpenseDetail({
    required this.expenseId,
    required this.expenseName,
    required this.expenseDate,
    required this.amount,
    required this.paidBy,
    required this.paidByDisplayName,
  });

  @override
  List<Object?> get props => [expenseId, expenseName, expenseDate, amount, paidBy, paidByDisplayName];
}

class CategoryExpenseDetailsArgs extends Equatable {
  final String groupId;
  final String categoryName;
  final DateTime monthStart;
  final DateTime monthEnd;

  const CategoryExpenseDetailsArgs({
    required this.groupId,
    required this.categoryName,
    required this.monthStart,
    required this.monthEnd,
  });

  @override
  List<Object?> get props => [groupId, categoryName, monthStart, monthEnd];
}
