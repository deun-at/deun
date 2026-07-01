enum SplitMode {
  /// Split evenly across the included members (DESIGN_SPEC §8 "Equal").
  equal,

  /// Exact per-member amounts (DESIGN_SPEC §8 "Exact"; persisted as 'exact').
  amount,
  percentage,
  shares;

  static SplitMode fromString(String? value) {
    if (value == 'exact') return SplitMode.amount;
    if (value == 'percentage') return SplitMode.percentage;
    if (value == 'shares') return SplitMode.shares;
    // 'equal', null and unknown all default to equal — matches the model
    // default (expense_entry_model falls back to 'equal') and the v3 prototype.
    return SplitMode.equal;
  }

  String toDbValue() {
    switch (this) {
      case SplitMode.equal:
        return 'equal';
      case SplitMode.amount:
        return 'exact';
      case SplitMode.percentage:
        return 'percentage';
      case SplitMode.shares:
        return 'shares';
    }
  }
}
