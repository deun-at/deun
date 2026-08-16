import '../../../helper/currency_breakdown.dart';
import '../../../helper/helper.dart';
import '../data/group_model.dart';

bool _isUnsettled(Group group) =>
    !isSettled(group.totalShareAmount, group.currency);

/// Aggregated overall balance across the user's groups **in one currency**.
class OverallBalance {
  const OverallBalance({
    required this.owed,
    required this.owe,
    this.currency = Currency.eur,
  });

  /// Total the user is owed across groups (sum of positive nets), as a
  /// positive magnitude.
  final double owed;

  /// Total the user owes across groups (sum of negative nets), as a positive
  /// magnitude.
  final double owe;

  /// The currency [owed] / [owe] / [net] are expressed in. Never a converted
  /// figure: only groups already in this currency contribute.
  final Currency currency;

  /// Net position: `owed - owe` (positive = net owed to the user).
  double get net => roundCurrency(owed - owe, currency);
}

/// The user's net balance per currency, primary first. THE input to the
/// overall-balance hero's "primary inline, remainder collapsed" rendering.
/// Sub-minor-unit balances are treated as settled and ignored, exactly as the
/// converting fold did. Pure.
CurrencyBreakdown balancesByCurrency(List<Group> groups) =>
    currencyBreakdownOf([
      for (final group in groups)
        if (!isSettled(group.totalShareAmount, group.currency))
          CurrencyAmount(group.currency, group.totalShareAmount),
    ]);

/// Totals the per-group net into owed/owe figures **for [currency] only**.
/// Groups in any other currency contribute nothing rather than being converted
/// — there is no rate source and no home currency any more. Pure.
OverallBalance aggregateOverallBalance(
  List<Group> groups, {
  Currency currency = Currency.eur,
}) {
  double owed = 0;
  double owe = 0;
  for (final group in groups) {
    if (group.currency != currency) continue;
    final amount = group.totalShareAmount;
    if (isSettled(amount, group.currency)) continue;
    if (amount > 0) {
      owed = roundCurrency(owed + amount, currency);
    } else {
      owe = roundCurrency(owe + amount.abs(), currency);
    }
  }
  return OverallBalance(owed: owed, owe: owe, currency: currency);
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
