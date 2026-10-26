import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

import '../../../groups/data/group_member_model.dart';
import '../../data/split_allocation.dart';
import '../../data/split_mode.dart';

/// F161 D3/D5: one colored bar + a single right-aligned, status-aware remain
/// label. Reads the same numbers the save-time validation uses (via the pure
/// [SplitAllocation] helper) so the bar, the label color, and validity stay in
/// sync. No ProgressBar and no left-aligned detail — matches the v3 mockup.
class ExpenseEntryAllocationSummary extends StatelessWidget {
  const ExpenseEntryAllocationSummary({
    super.key,
    required this.index,
    required this.splitMode,
    required this.currency,
    required this.entryTotal,
    required this.groupMembers,
    required this.enabledMembers,
    required this.memberAmounts,
    required this.memberPercentages,
    required this.memberParts,
    required this.isYou,
    required this.amountPreview,
  });

  final int index;
  final SplitMode splitMode;
  final Currency currency;
  final double entryTotal;
  final List<GroupMember> groupMembers;
  final Set<String> enabledMembers;
  final Map<String, double> memberAmounts;
  final Map<String, double> memberPercentages;
  final Map<String, int> memberParts;
  final bool Function(String email) isYou;

  /// The State's `_getAmountPreview` (it also feeds the member rows).
  final double Function(String email) amountPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final allocation = SplitAllocation.compute(
      mode: splitMode,
      total: entryTotal,
      amounts: memberAmounts,
      percentages: memberPercentages,
      parts: memberParts,
      enabled: enabledMembers,
      currency: currency,
    );

    // Single right-aligned label: grey default (fully-allocated equal/shares
    // show their per-head / parts detail), success when explicitly all set,
    // warning when under, danger when over.
    final Color labelColor;
    final String label;
    switch (allocation.status) {
      case AllocationStatus.ok:
        // Equal/shares are structurally always ok — keep their neutral detail
        // (grey) rather than a redundant "All set". Amount/percentage reaching
        // exactly 100% earn the success confirmation.
        if (splitMode == SplitMode.equal || splitMode == SplitMode.shares) {
          labelColor = colorScheme.onSurfaceVariant;
          label = _allocationDetail(l10n);
        } else {
          labelColor = semantic.success;
          label = l10n.splitAllocatedLabel;
        }
        break;
      case AllocationStatus.under:
        labelColor = semantic.warning;
        label = splitMode == SplitMode.amount
            ? l10n.splitRemainingLabel(
                l10n.toCurrency(allocation.remaining, currency.code),
              )
            : _underLabel(l10n);
        break;
      case AllocationStatus.over:
        labelColor = semantic.danger;
        label = splitMode == SplitMode.amount
            ? l10n.splitOverLabel(
                l10n.toCurrency(allocation.remaining.abs(), currency.code),
              )
            : _overLabel(l10n);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSplitSegments(context, allocation),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// F161 D3: ONE 10px / radius-6 segmented bar on a [surfaceContainerHighest]
  /// track. Each INCLUDED member gets a segment sized as their share OF THE
  /// TOTAL (not of the allocated sum), colored with their avatar color (same
  /// [memberAvatarColor] the [MemberAvatar] uses; "you" uses primary). When the
  /// split under-allocates, the segments don't fill the track — the leftover
  /// track shows through as a visible empty remainder. Rebuilds with the parent
  /// [setState] as members toggle or amounts change.
  Widget _buildSplitSegments(BuildContext context, SplitAllocation allocation) {
    final colorScheme = Theme.of(context).colorScheme;

    // Fraction of the total each segment occupies. For amount mode this is the
    // per-member amount / total (so an under-allocation leaves empty track); for
    // the other modes SplitAllocation.fraction is 1.0 (equal/shares/percent-ok)
    // or <1 (percent under), and each member's slice is their share of that.
    final children = <Widget>[];
    for (final member in groupMembers) {
      if (!enabledMembers.contains(member.email)) continue;
      final amount = amountPreview(member.email);
      final double flexOfTotal = entryTotal > 0
          ? (amount / entryTotal).clamp(0.0, 1.0).toDouble()
          : 0.0;
      // Positive int flex; a zero-share included member keeps a hairline so
      // their color/presence stays visible.
      final flex = (flexOfTotal * 10000).round().clamp(1, 1 << 30);
      final color = isYou(member.email)
          ? colorScheme.primary
          : memberAvatarColor(member.email);
      children.add(
        Expanded(
          flex: flex,
          child: Container(
            key: ValueKey('split_segment_${index}_${member.email}'),
            color: color,
          ),
        ),
      );
    }

    // Empty remainder: the unallocated slice of the track (visible when the
    // split under-allocates). Over-allocation clamps to a full bar.
    final remainderFlex = ((1.0 - allocation.fraction).clamp(0.0, 1.0) * 10000)
        .round();
    if (remainderFlex > 0) {
      children.add(Expanded(flex: remainderFlex, child: const SizedBox()));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 10,
        color: colorScheme.surfaceContainerHighest,
        child: children.isEmpty ? null : Row(children: children),
      ),
    );
  }

  /// The left-side detail of the allocation row (allocated / target).
  String _allocationDetail(AppLocalizations l10n) {
    switch (splitMode) {
      case SplitMode.equal:
        final each = enabledMembers.isNotEmpty
            ? entryTotal / enabledMembers.length
            : 0.0;
        return l10n.splitEqualSummary(l10n.toCurrency(each, currency.code));
      case SplitMode.amount:
        final sum = enabledMembers.fold<double>(
          0,
          (s, e) => s + (memberAmounts[e] ?? 0),
        );
        return "${l10n.toCurrency(sum, currency.code)} / ${l10n.toCurrency(entryTotal, currency.code)}";
      case SplitMode.percentage:
        final sum = enabledMembers.fold<double>(
          0,
          (s, e) => s + (memberPercentages[e] ?? 0),
        );
        return "${sum.toStringAsFixed(1)}% / 100%";
      case SplitMode.shares:
        final totalParts = enabledMembers.fold<int>(
          0,
          (s, e) => s + (memberParts[e] ?? 1),
        );
        return l10n.splitSharesSummary(totalParts);
    }
  }

  String _underLabel(AppLocalizations l10n) {
    if (splitMode == SplitMode.percentage) {
      final sum = enabledMembers.fold<double>(
        0,
        (s, e) => s + (memberPercentages[e] ?? 0),
      );
      return "${(100 - sum).toStringAsFixed(1)}%";
    }
    return l10n.expenseEntrySharesValidationEmpty;
  }

  String _overLabel(AppLocalizations l10n) {
    final sum = enabledMembers.fold<double>(
      0,
      (s, e) => s + (memberPercentages[e] ?? 0),
    );
    return "+${(sum - 100).toStringAsFixed(1)}%";
  }
}
