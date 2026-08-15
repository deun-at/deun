import '../../../helper/currency_conversion.dart';
import '../../../helper/helper.dart';
import '../data/group_model.dart';

/// Whether a group's net balance is effectively non-zero (still owing/owed).
bool _isUnsettled(Group group) => !isSettled(group.totalShareAmount);

/// Aggregated overall balance across all of a user's groups.
class OverallBalance {
  const OverallBalance({
    required this.owed,
    required this.owe,
    this.approximate = false,
    this.excludedCount = 0,
  });

  /// Total the user is owed across groups (sum of positive nets), as a
  /// positive magnitude.
  final double owed;

  /// Total the user owes across groups (sum of negative nets), as a positive
  /// magnitude.
  final double owe;

  /// True when at least one group's balance was converted from a foreign
  /// currency into the home currency, so the totals are estimates (mark "≈").
  /// False when every counted group was already in the home currency (exact).
  final bool approximate;

  /// Number of groups excluded because their currency had no available rate.
  final int excludedCount;

  /// Net position: `owed - owe` (positive = net owed to the user).
  double get net => roundCurrency(owed - owe);
}

/// Totals the per-group net (`Group.totalShareAmount`, already computed by the
/// settlement logic) into overall owed/owe figures, converting each group's
/// contribution from its own currency into [homeCurrency] before summing so a
/// €10 balance in a EUR group and a $10 balance in a USD group produce one
/// home-currency total rather than a naive 20. Sub-cent balances are treated as
/// settled and ignored. Groups whose currency has no available rate are
/// excluded and counted. Pure: does not touch Supabase or recompute settlement.
OverallBalance aggregateOverallBalance(
  List<Group> groups, {
  String homeCurrency = kDefaultCurrencyCode,
  ExchangeRates? rates,
}) {
  double owed = 0;
  double owe = 0;
  bool approximate = false;
  int excluded = 0;
  for (final group in groups) {
    final amount = group.totalShareAmount;
    if (isSettled(amount)) continue;
    final converted = convertToHome(
      amount,
      group.currencyCode,
      homeCurrency,
      rates,
    );
    if (converted == null) {
      excluded++;
      continue;
    }
    if (group.currencyCode != homeCurrency) approximate = true;
    if (converted > 0) {
      owed = roundCurrency(owed + converted);
    } else {
      owe = roundCurrency(owe + converted.abs());
    }
  }
  return OverallBalance(
    owed: owed,
    owe: owe,
    approximate: approximate,
    excludedCount: excluded,
  );
}

/// Returns a new list ordered by the home-screen priority:
/// fav-unsettled → fav-settled → unsettled → settled, then case-insensitive
/// name within each tier. Pure: does not mutate [groups].
///
/// [isFavorite] supplies favorite state; callers in the app pass
/// `(g) => g.isFavorite`, while tests pass a deterministic predicate.
List<Group> sortGroups(
  List<Group> groups, {
  required bool Function(Group) isFavorite,
}) {
  int rank(Group g) {
    final fav = isFavorite(g);
    final unsettled = _isUnsettled(g);
    if (fav && unsettled) return 0;
    if (fav) return 1;
    if (unsettled) return 2;
    return 3;
  }

  final sorted = List<Group>.from(groups);
  sorted.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}
