import 'package:equatable/equatable.dart';

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
