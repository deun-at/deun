import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:deun/l10n/app_localizations.dart';

import '../../../constants.dart';
import '../data/group_model.dart';

/// A single group card on the home screen: tinted leading icon, group name,
/// favorite star toggle, chevron, and a footer with the member [AvatarStack]
/// plus a balance lead label and amount.
///
/// Tapping the card opens the group; tapping the star toggles favorite WITHOUT
/// navigating (the star sits in its own gesture region above the card ink).
class GroupListItem extends ConsumerWidget {
  const GroupListItem({
    super.key,
    required this.group,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final Group group;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  static const double _settledThreshold = 0.01;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final groupColor = Color(group.colorValue);
    // Per-group leading-icon tint: the saturated group color on its hand-tuned
    // spec tint background (light) / a dark-surface derivation (dark) — routed
    // through the centralized `groupTint` mapping, never a flat alpha overlay
    // (F04).
    final groupTintBg = groupTint(group.colorValue, Theme.of(context).brightness);
    final amount = group.totalShareAmount;
    final isSettled = amount.abs() < _settledThreshold;

    final String balanceLabel;
    final MoneySemantic moneySemantic;
    if (isSettled) {
      balanceLabel = l10n.balanceSettled;
      moneySemantic = MoneySemantic.neutral;
    } else if (amount > 0) {
      balanceLabel = l10n.balanceOwed;
      moneySemantic = MoneySemantic.positive;
    } else {
      balanceLabel = l10n.balanceOwe;
      moneySemantic = MoneySemantic.negative;
    }

    final members = group.groupMembers
        .map((m) => AvatarStackMember(name: m.displayName, colorKey: m.email))
        .toList();

    // Gap between cards is owned by the SPACED list preset (F143), not the item.
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () {
        GoRouter.of(context).push("/group/details", extra: {'group': group});
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: groupTintBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long, color: groupColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.name,
                      style: textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onFavoriteToggle != null)
                    // IconButton is its own gesture region, so a star tap is
                    // handled here and never bubbles to the card's onTap (no
                    // navigation when toggling favorite).
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite
                            ? Theme.of(context).extension<SemanticColors>()!.warning
                            : colorScheme.outline,
                      ),
                      onPressed: onFavoriteToggle,
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.groupSectionFavorites,
                    ),
                  Icon(Icons.chevron_right, color: colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (members.isNotEmpty) ...[
                    AvatarStack(members: members, radius: 13, maxVisible: 4),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // v3 footer hierarchy (F05): a muted caption lead label
                      // (#9A968C / 12px / w500 in the prototype) above a heavier,
                      // semantic-colored card-title amount. The lead label maps
                      // to the caption tier (labelMedium) in the warm
                      // onSurfaceVariant token — NOT the tinier labelSmall, which
                      // read too weak versus the v3 lead/amount weight contrast.
                      Text(
                        balanceLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Settled groups show "gray, no amount" (DESIGN_SPEC edge
                      // states) — only render the balance amount when unsettled.
                      if (!isSettled) ...[
                        const SizedBox(height: 2),
                        // Amount: card-title size (titleMedium) at w700, colored
                        // green owed / red owe via the SemanticColors token
                        // (MoneySemantic). This is the heavier half of the
                        // lead-label + amount hierarchy.
                        MoneyText(
                          amount.abs(),
                          semantic: moneySemantic,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }
}

