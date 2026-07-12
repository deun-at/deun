import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../helper/currency_conversion.dart';
import '../../../main.dart';
import '../../../provider.dart';
import '../../groups/provider/group_list.dart';
import '../statistics_models.dart';

part 'personal_statistics_notifiers.g.dart';

@riverpod
class PersonalStatisticsNotifier extends _$PersonalStatisticsNotifier {
  @override
  FutureOr<PersonalStatisticsState> build(StatsRange range) async {
    return await _load(range);
  }

  Future<PersonalStatisticsState> _load(StatsRange range) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return PersonalStatisticsState.empty;

    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1, 1);
    final DateTime start;
    if (range == StatsRange.allTime) {
      start = DateTime(now.year - 10, 1, 1);
    } else {
      start = DateTime(now.year, now.month - (range.months! - 1), 1);
    }

    final rows =
        await supabase.rpc(
              'get_user_spending_summary',
              params: {
                'p_user_email': email,
                'p_start': _toDateOnly(start),
                'p_end': _toDateOnly(end),
              },
            )
            as List<dynamic>;

    // Aggregate by group and by month.
    final Map<String, _GroupAgg> byGroup = {};
    final Map<DateTime, double> byMonth = {};
    int expenseCount = 0;

    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final groupId = row['group_id'] as String;
      final groupName = row['group_name'] as String? ?? '';
      final colorValue = (row['color_value'] as num?)?.toInt() ?? 0;
      final month = DateTime.parse(row['month'] as String);
      final paid = (row['total_paid'] as num?)?.toDouble() ?? 0;
      final share = (row['total_share'] as num?)?.toDouble() ?? 0;
      final count = (row['expense_count'] as num?)?.toInt() ?? 0;

      final monthKey = DateTime(month.year, month.month, 1);
      byMonth[monthKey] = (byMonth[monthKey] ?? 0) + share;

      final agg = byGroup.putIfAbsent(
        groupId,
        () => _GroupAgg(
          groupId: groupId,
          groupName: groupName,
          colorValue: colorValue,
        ),
      );
      agg.totalPaid += paid;
      agg.totalShare += share;
      agg.expenseCount += count;

      expenseCount += count;
    }

    // The RPC returns per-group figures in each group's own currency. Convert
    // every group's contribution into the home currency before summing the
    // "Across all groups" hero figures, so mixed-currency spending aggregates
    // into one home-currency total rather than a naive sum. The group currency
    // comes from the loaded group list; groups missing there fall back to the
    // home currency (no conversion). Per-group and monthly figures stay raw —
    // they are read per group, not summed across currencies.
    final homeCurrency = ref.watch(homeCurrencyProvider);
    final rates = ref.watch(exchangeRatesProvider).value;
    final loadedGroups = await ref.watch(groupListProvider.future);
    final currencyByGroup = {
      for (final g in loadedGroups) g.id: g.currencyCode,
    };
    final paidTotal = convertAndSum(
      byGroup.values.map(
        (a) => CurrencyAmount(
          a.totalPaid,
          currencyByGroup[a.groupId] ?? homeCurrency,
        ),
      ),
      homeCurrency,
      rates,
    );
    final shareTotal = convertAndSum(
      byGroup.values.map(
        (a) => CurrencyAmount(
          a.totalShare,
          currencyByGroup[a.groupId] ?? homeCurrency,
        ),
      ),
      homeCurrency,
      rates,
    );
    final totalPaid = paidTotal.amount;
    final totalShare = shareTotal.amount;
    final approximate = paidTotal.approximate || shareTotal.approximate;
    final excludedCount = shareTotal.excludedCount;

    final groups =
        byGroup.values
            .map(
              (a) => PersonalGroupSummary(
                groupId: a.groupId,
                groupName: a.groupName,
                colorValue: a.colorValue,
                totalPaid: a.totalPaid,
                totalShare: a.totalShare,
                expenseCount: a.expenseCount,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalShare.compareTo(a.totalShare));

    final sortedMonths = byMonth.keys.toList()..sort();
    final monthly = sortedMonths.map((m) {
      final end = DateTime(m.year, m.month + 1, 1);
      return MonthBucket(start: m, end: end, total: byMonth[m] ?? 0);
    }).toList();

    return PersonalStatisticsState(
      groups: groups,
      monthlyTotals: monthly,
      totalPaid: totalPaid,
      totalShare: totalShare,
      expenseCount: expenseCount,
      approximate: approximate,
      excludedCount: excludedCount,
    );
  }

  static String _toDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _GroupAgg {
  final String groupId;
  final String groupName;
  final int colorValue;
  double totalPaid = 0;
  double totalShare = 0;
  int expenseCount = 0;

  _GroupAgg({
    required this.groupId,
    required this.groupName,
    required this.colorValue,
  });
}
