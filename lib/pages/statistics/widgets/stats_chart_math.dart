/// Pure, presentation-only chart-math helpers for the group statistics screen.
///
/// These contain no Supabase queries and no stats aggregation — that all lives
/// in `statistics_notifiers.dart`. They only scale already-computed values into
/// bar fractions and pick label intervals so the chart widgets stay declarative.
library;

/// The bar fill fraction for [value] against [max], clamped into 0..1.
/// Returns 0 when [max] is 0 (no data to scale against).
double barFraction(double value, double max) {
  if (max <= 0) return 0.0;
  return (value / max).clamp(0.0, 1.0).toDouble();
}

/// The largest value across [values], or 0 for an empty list. Used to pick a
/// shared scale for grouped bars (e.g. paid vs fair-share).
double maxOfBars(List<double> values) {
  if (values.isEmpty) return 0.0;
  return values.reduce((a, b) => a > b ? a : b);
}

/// How many series points to skip between axis labels so that roughly six
/// labels show for a series of [count] points. Never less than 1.
int labelStep(int count) {
  if (count <= 6) return 1;
  return (count / 6).ceil().clamp(1, count);
}

/// [part] as a percentage (0..100) of [total]; 0 when [total] is 0.
double percentOfTotal(double part, double total) {
  if (total <= 0) return 0.0;
  return part / total * 100;
}
