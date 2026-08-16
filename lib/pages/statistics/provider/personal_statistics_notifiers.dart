import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../helper/currency_breakdown.dart';
import '../../../helper/helper.dart';
import '../../../main.dart';
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

    // The RPC already returns group_id per row and groups by group and month,
    // so the per-currency fold is pure client-side work over rows that already
    // carry the dimension. No RPC change, no migration.
    final loadedGroups = await ref.watch(groupListProvider.future);
    final currencyByGroup = {for (final g in loadedGroups) g.id: g.currency};

    final Map<String, _GroupAgg> byGroup = {};
    final Map<Currency, Map<DateTime, double>> byMonth = {};
    int expenseCount = 0;

    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final groupId = row['group_id'] as String;
      final currency = currencyByGroup[groupId] ?? Currency.eur;
      final groupName = row['group_name'] as String? ?? '';
      final colorValue = (row['color_value'] as num?)?.toInt() ?? 0;
      final month = DateTime.parse(row['month'] as String);
      final paid = (row['total_paid'] as num?)?.toDouble() ?? 0;
      final share = (row['total_share'] as num?)?.toDouble() ?? 0;
      final count = (row['expense_count'] as num?)?.toInt() ?? 0;

      final monthKey = DateTime(month.year, month.month, 1);
      final months = byMonth.putIfAbsent(currency, () => <DateTime, double>{});
      months[monthKey] = (months[monthKey] ?? 0) + share;

      final agg = byGroup.putIfAbsent(
        groupId,
        () => _GroupAgg(
          groupId: groupId,
          groupName: groupName,
          colorValue: colorValue,
          currency: currency,
        ),
      );
      agg.totalPaid += paid;
      agg.totalShare += share;
      agg.expenseCount += count;

      expenseCount += count;
    }

    final shareByCurrency = personalShareByCurrency([
      for (final a in byGroup.values) CurrencyAmount(a.currency, a.totalShare),
    ]);
    final totalPaidByCurrency = <Currency, double>{};
    for (final a in byGroup.values) {
      totalPaidByCurrency[a.currency] = roundCurrency(
        (totalPaidByCurrency[a.currency] ?? 0) + a.totalPaid,
        a.currency,
      );
    }

    final groups =
        byGroup.values
            .map(
              (a) => PersonalGroupSummary(
                groupId: a.groupId,
                groupName: a.groupName,
                colorValue: a.colorValue,
                currency: a.currency,
                totalPaid: a.totalPaid,
                totalShare: a.totalShare,
                expenseCount: a.expenseCount,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalShare.compareTo(a.totalShare));

    final monthlyTotalsByCurrency = <Currency, List<MonthBucket>>{
      for (final entry in byMonth.entries)
        entry.key: [
          for (final m in entry.value.keys.toList()..sort())
            MonthBucket(
              start: m,
              end: DateTime(m.year, m.month + 1, 1),
              total: entry.value[m] ?? 0,
            ),
        ],
    };

    return PersonalStatisticsState(
      groups: groups,
      monthlyTotalsByCurrency: monthlyTotalsByCurrency,
      totalPaidByCurrency: totalPaidByCurrency,
      shareByCurrency: shareByCurrency,
      expenseCount: expenseCount,
    );
  }

  static String _toDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// "Your share" per currency for the personal statistics surface, primary
/// first — the breakdown the hero renders, the selector lists and the trend
/// chart defaults to.
///
/// Spending, not a balance: unlike a balance fold this does NOT drop a currency
/// whose net share rounds away. A group the user only ever paid for others in
/// nets a ~0 share, and dropping it would take its "you paid" total and its
/// whole trend series out of the selector with it — unreachable, with no way
/// back. Pure.
CurrencyBreakdown personalShareByCurrency(Iterable<CurrencyAmount> shares) =>
    currencyBreakdownOf(shares, dropSettled: false);

class _GroupAgg {
  final String groupId;
  final String groupName;
  final int colorValue;
  final Currency currency;
  double totalPaid = 0;
  double totalShare = 0;
  int expenseCount = 0;

  _GroupAgg({
    required this.groupId,
    required this.groupName,
    required this.colorValue,
    required this.currency,
  });
}

/// Which currency the personal statistics surface is showing. VIEW STATE, not a
/// preference: it is derived from the same per-currency map the scalars use, so
/// there is nothing to persist and no second source of truth. `null` means
/// "follow the primary currency".
@riverpod
class PersonalStatsCurrencyNotifier extends _$PersonalStatsCurrencyNotifier {
  @override
  Currency? build() => null;

  void select(Currency currency) => state = currency;
}
