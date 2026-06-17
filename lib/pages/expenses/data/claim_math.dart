/// A single claimable unit for cost-math purposes: its cost and the emails
/// of the members who have claimed it. Mirrors one `expense_entry`
/// (quantity 1, split_mode 'claim') with its `expense_entry_share` rows.
class ClaimUnit {
  const ClaimUnit({required this.unitCost, required this.claimers});

  final double unitCost;
  final List<String> claimers;

  bool get isClaimed => claimers.isNotEmpty;

  /// Cost to each claimer of this unit = unitCost / number of claimers.
  /// Returns 0 when nobody has claimed it (the payer covers unclaimed units).
  double get perClaimerCost => claimers.isEmpty ? 0 : unitCost / claimers.length;
}

/// Per-member share totals across all units. A member's total is the sum,
/// over every unit they claimed, of `unitCost / claimers`. Equivalent to
/// `Expense.groupMemberShareStatistic` for claim units (percentage = 100/n).
Map<String, double> memberShareTotals(List<ClaimUnit> units) {
  final totals = <String, double>{};
  for (final unit in units) {
    if (!unit.isClaimed) continue;
    final per = unit.perClaimerCost;
    for (final email in unit.claimers) {
      totals[email] = (totals[email] ?? 0) + per;
    }
  }
  return totals;
}

/// Sum of all unit costs that have at least one claimer.
double claimedTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    if (unit.isClaimed) sum += unit.unitCost;
  }
  return sum;
}

/// Sum of all unit costs (claimed or not).
double grandTotal(List<ClaimUnit> units) {
  double sum = 0;
  for (final unit in units) {
    sum += unit.unitCost;
  }
  return sum;
}

/// Total cost not yet claimed by anyone — the payer covers this.
double unclaimedTotal(List<ClaimUnit> units) =>
    grandTotal(units) - claimedTotal(units);
