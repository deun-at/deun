import '../../../helper/helper.dart';
import '../data/group_model.dart';

/// Balance below this magnitude (in currency units) counts as settled.
const double _kSettledThreshold = 0.01;

/// Whether a group's net balance is effectively non-zero (still owing/owed).
bool _isUnsettled(Group group) => group.totalShareAmount.abs() >= _kSettledThreshold;

/// Aggregated overall balance across all of a user's groups.
class OverallBalance {
  const OverallBalance({required this.owed, required this.owe});

  /// Total the user is owed across groups (sum of positive nets), as a
  /// positive magnitude.
  final double owed;

  /// Total the user owes across groups (sum of negative nets), as a positive
  /// magnitude.
  final double owe;

  /// Net position: `owed - owe` (positive = net owed to the user).
  double get net => roundCurrency(owed - owe);
}

/// Totals the per-group net (`Group.totalShareAmount`, already computed by the
/// settlement logic) into overall owed/owe figures. Sub-cent balances are
/// treated as settled and ignored. Pure: does not touch Supabase or recompute
/// any settlement.
OverallBalance aggregateOverallBalance(List<Group> groups) {
  double owed = 0;
  double owe = 0;
  for (final group in groups) {
    final amount = group.totalShareAmount;
    if (amount.abs() < _kSettledThreshold) continue;
    if (amount > 0) {
      owed = roundCurrency(owed + amount);
    } else {
      owe = roundCurrency(owe + amount.abs());
    }
  }
  return OverallBalance(owed: owed, owe: owe);
}

/// Returns a new list ordered by the home-screen priority:
/// fav-unsettled → fav-settled → unsettled → settled, then case-insensitive
/// name within each tier. Pure: does not mutate [groups].
///
/// [isFavorite] supplies favorite state; callers in the app pass
/// `(g) => g.isFavorite`, while tests pass a deterministic predicate.
List<Group> sortGroups(List<Group> groups, {required bool Function(Group) isFavorite}) {
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
