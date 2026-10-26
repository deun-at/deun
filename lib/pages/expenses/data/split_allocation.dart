import 'package:deun/helper/helper.dart';

import 'split_mode.dart';

/// Whether the current per-member split under-, exactly-, or over-allocates the
/// entry total. Drives the live remaining indicator's semantic color.
enum AllocationStatus { under, ok, over }

/// A pure, UI-free view of how fully an expense entry's split is allocated.
///
/// It is the editor's one split check: the allocation bar, the remaining
/// indicator and the save-time validator (`status == AllocationStatus.ok`) all
/// read it, so they cannot disagree. It does NOT introduce new split math.
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
    required Currency currency,
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
        final diff =
            roundCurrency(sum, currency) - roundCurrency(total, currency);
        final AllocationStatus status;
        if (isSettled(diff, currency)) {
          status = AllocationStatus.ok;
        } else if (diff < 0) {
          status = AllocationStatus.under;
        } else {
          status = AllocationStatus.over;
        }
        final fraction = total > 0
            ? (sum / total).clamp(0.0, 1.0).toDouble()
            : 0.0;
        return SplitAllocation(
          status: status,
          fraction: fraction,
          remaining: total - sum,
        );

      case SplitMode.percentage:
        final sum = enabled.fold<double>(
          0,
          (s, e) => s + (percentages[e] ?? 0),
        );
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

/// Rebalances an Exact split: every member in [enabled] who is not in [locked]
/// gets an equal part of [total] minus the locked included amounts. Locked
/// members and members outside [enabled] keep their amounts, and with nobody
/// left to rebalance (no included member, or every one locked) the amounts come
/// back unchanged. Returns a new map and never rounds — rounding stays where
/// the amounts are shown or saved.
Map<String, double> rebalanceExactAmounts({
  required double total,
  required Set<String> enabled,
  required Set<String> locked,
  required Map<String, double> amounts,
}) => _rebalance(
  target: total,
  enabled: enabled,
  locked: locked,
  values: amounts,
);

/// [rebalanceExactAmounts] for a percentage split, against 100.
Map<String, double> rebalancePercentages({
  required Set<String> enabled,
  required Set<String> locked,
  required Map<String, double> percentages,
}) => _rebalance(
  target: 100,
  enabled: enabled,
  locked: locked,
  values: percentages,
);

Map<String, double> _rebalance({
  required double target,
  required Set<String> enabled,
  required Set<String> locked,
  required Map<String, double> values,
}) {
  final result = Map.of(values);
  double lockedSum = 0;
  int unlockedCount = 0;
  for (final email in enabled) {
    if (locked.contains(email)) {
      lockedSum += values[email] ?? 0;
    } else {
      unlockedCount++;
    }
  }
  if (unlockedCount == 0) return result;
  final perUnlocked = (target - lockedSum) / unlockedCount;
  for (final email in enabled) {
    if (!locked.contains(email)) result[email] = perUnlocked;
  }
  return result;
}

/// Moves each [locked] amount with a changed entry total: it scales by
/// [newTotal] / [oldTotal], and every other amount stays. When either total is
/// ≤ 0 or nobody is locked there is nothing to scale against, so the amounts
/// come back unchanged with `releaseLocks: true` — the caller then clears its
/// locks. Returns a new map.
({Map<String, double> amounts, bool releaseLocks}) scaleLockedAmounts({
  required double oldTotal,
  required double newTotal,
  required Set<String> locked,
  required Map<String, double> amounts,
}) {
  final scaled = Map.of(amounts);
  if (oldTotal <= 0 || newTotal <= 0 || locked.isEmpty) {
    return (amounts: scaled, releaseLocks: true);
  }
  final ratio = newTotal / oldTotal;
  for (final email in locked) {
    scaled[email] = (scaled[email] ?? 0) * ratio;
  }
  return (amounts: scaled, releaseLocks: false);
}
