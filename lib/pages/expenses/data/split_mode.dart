enum SplitMode {
  amount,
  percentage,
  shares;

  static SplitMode fromString(String? value) {
    if (value == 'equal' || value == 'exact') return SplitMode.amount;
    if (value == 'percentage') return SplitMode.percentage;
    if (value == 'shares') return SplitMode.shares;
    return SplitMode.amount;
  }

  String toDbValue() {
    switch (this) {
      case SplitMode.amount:
        return 'exact';
      case SplitMode.percentage:
        return 'percentage';
      case SplitMode.shares:
        return 'shares';
    }
  }
}
