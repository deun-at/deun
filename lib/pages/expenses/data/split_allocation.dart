import 'package:deun/helper/helper.dart';

import 'split_mode.dart';

/// Whether the current per-member split under-, exactly-, or over-allocates the
/// entry total. Drives the live remaining indicator's semantic color.
enum AllocationStatus { under, ok, over }

/// A pure, UI-free view of how fully an expense entry's split is allocated.
///
/// This deliberately mirrors the existing validation in
/// `ExpenseEntryWidget._isSplitValid` (same cent/percent tolerances) so the
/// restyled allocation bar and remaining indicator stay consistent with the
/// save-time validation — it does NOT introduce new split math.
class SplitAllocation {
  const SplitAllocation({
    required this.status,
    required this.fraction,
    required this.remaining,
  });

  /// Under / ok / over.
  final AllocationStatus status;

  /// Allocated portion of the target, clamped to 0..1 (for [ProgressBar]).
  final double fraction;

  /// Currency remaining to allocate (positive = under, negative = over).
  /// Only meaningful for amount mode; 0 otherwise.
  final double remaining;

  static SplitAllocation compute({
    required SplitMode mode,
    required double total,
    required Map<String, double> amounts,
    required Map<String, double> percentages,
    required Map<String, int> parts,
    required Set<String> enabled,
  }) {
    if (enabled.isEmpty) {
      return const SplitAllocation(
        status: AllocationStatus.under,
        fraction: 0,
        remaining: 0,
      );
    }

    switch (mode) {
      case SplitMode.equal:
        // Equal always allocates fully across the included members.
        return const SplitAllocation(
          status: AllocationStatus.ok,
          fraction: 1.0,
          remaining: 0,
        );

      case SplitMode.amount:
        final sum = enabled.fold<double>(0, (s, e) => s + (amounts[e] ?? 0));
        final diff = roundCurrency(sum) - roundCurrency(total);
        final AllocationStatus status;
        if (diff.abs() < 0.005) {
          status = AllocationStatus.ok;
        } else if (diff < 0) {
          status = AllocationStatus.under;
        } else {
          status = AllocationStatus.over;
        }
        final fraction = total > 0 ? (sum / total).clamp(0.0, 1.0).toDouble() : 0.0;
        return SplitAllocation(
          status: status,
          fraction: fraction,
          remaining: total - sum,
        );

      case SplitMode.percentage:
        final sum = enabled.fold<double>(0, (s, e) => s + (percentages[e] ?? 0));
        final diff = sum - 100;
        final AllocationStatus status;
        if (diff.abs() < 0.01) {
          status = AllocationStatus.ok;
        } else if (diff < 0) {
          status = AllocationStatus.under;
        } else {
          status = AllocationStatus.over;
        }
        return SplitAllocation(
          status: status,
          fraction: (sum / 100).clamp(0.0, 1.0).toDouble(),
          remaining: 0,
        );

      case SplitMode.shares:
        final totalParts = enabled.fold<int>(0, (s, e) => s + (parts[e] ?? 1));
        return SplitAllocation(
          status: totalParts > 0 ? AllocationStatus.ok : AllocationStatus.under,
          fraction: totalParts > 0 ? 1.0 : 0.0,
          remaining: 0,
        );
    }
  }
}
