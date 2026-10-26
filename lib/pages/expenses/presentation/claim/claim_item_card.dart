import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_split_editor.dart';

/// One item card: auto category icon, name + ×N, "€X each · N ordered"
/// subline, the persona's cost for this item, one chip per unit slot, and the
/// Split one / hint footer row.
class ClaimItemCard extends StatelessWidget {
  const ClaimItemCard({
    super.key,
    required this.group,
    required this.persona,
    required this.display,
    required this.members,
    required this.expandedUnit,
    required this.onTakeOne,
    required this.onTapUnit,
    required this.onSplitOne,
    required this.onApplySplit,
    required this.currency,
  });

  final ClaimItemGroup group;
  final String persona;
  final MemberDisplay display;
  final List<GroupMember> members;
  final String? expandedUnit;
  final ValueChanged<ClaimUnitRow> onTakeOne;
  final ValueChanged<ClaimUnitRow> onTapUnit;
  final VoidCallback onSplitOne;
  final void Function(String entryId, List<String> claimers) onApplySplit;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = group.name ?? '';
    // Auto category icon per item name (same detector the editor uses).
    final category = CategoryDetector.detectCategory(name);
    final categoryColor = category.getColor(context);
    final yourCost = persona.isEmpty ? 0.0 : group.costForPersona(persona);
    // "Holds nothing" is the same settled decision the rest of the app makes,
    // in this receipt's currency — a ¥0.3 cost renders as ¥0, so it must not
    // light the card up as taken.
    final personaHoldsNone = isSettled(yourCost, currency);
    // F163 taken-highlight: tint the whole card + add a faint primary border
    // when the persona holds any part of this item.
    final taken = !personaHoldsNone;

    // F163 inline editor: the expanded unit for this item (if any).
    ClaimUnitRow? expandedRow;
    for (final row in group.units) {
      if (row.entryId == expandedUnit) {
        expandedRow = row;
        break;
      }
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      color: taken ? colorScheme.primary.withValues(alpha: 0.05) : null,
      border: taken
          ? Border.all(
              color: colorScheme.primary.withValues(alpha: 0.20),
              width: 1.5,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.getIcon(), size: 22, color: categoryColor),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          if (group.quantity > 1)
                            TextSpan(
                              text: '  ×${group.quantity}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.quantity > 1
                          ? l10n.claimEachOrdered(
                              l10n.toCurrency(group.unitCost, currency.code),
                              group.quantity,
                            )
                          : l10n.toCurrency(group.unitCost, currency.code),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (taken) ...[
                const SizedBox(width: 8),
                MoneyText(
                  yourCost,
                  currency: currency,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final row in group.units)
                if (row.unit.isClaimed)
                  _ClaimedUnitChip(
                    key: ValueKey('slot:${row.entryId}'),
                    row: row,
                    persona: persona,
                    display: display,
                    onTap: () => onTapUnit(row),
                    currency: currency,
                  )
                else
                  _TakeOneChip(
                    key: ValueKey('slot:${row.entryId}'),
                    onTap: () => onTakeOne(row),
                  ),
            ],
          ),
          // F163: the inline split editor expands in place of the old modal.
          AnimatedSize(
            duration: Motion.sheetRiseDuration,
            curve: Motion.sheetRise,
            alignment: Alignment.topCenter,
            child: expandedRow == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: ClaimSplitEditorCard(
                      key: ValueKey('editor:${expandedRow.entryId}'),
                      unitCost: expandedRow.unit.unitCost,
                      members: members,
                      display: display,
                      currency: currency,
                      // Seed with the unit's claimers; for a still-free unit
                      // (opened via "Split one") preselect the current persona,
                      // matching the old modal's behaviour.
                      initialClaimers: expandedRow.unit.claimers.isNotEmpty
                          ? expandedRow.unit.claimers.toSet()
                          : {if (persona.isNotEmpty) persona},
                      onDone: (claimers) =>
                          onApplySplit(expandedRow!.entryId, claimers),
                    ),
                  ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _SplitOneButton(enabled: group.hasFree, onTap: onSplitOne),
              const Spacer(),
              if (group.hasFree && personaHoldsNone)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.claimTapSlotHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A claimed unit slot: avatar(s) pill with the claimer's name when solo or
/// "split · €each" when shared, tinted with the "you" accent when the persona
/// is a claimer. Tap opens the solo/split modal for this unit.
class _ClaimedUnitChip extends StatelessWidget {
  const _ClaimedUnitChip({
    super.key,
    required this.row,
    required this.persona,
    required this.display,
    required this.onTap,
    required this.currency,
  });

  final ClaimUnitRow row;
  final String persona;
  final MemberDisplay display;
  final VoidCallback onTap;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chipState = ClaimChipState.forPersona(row, persona);

    final claimers = row.unit.claimers;
    final stackMembers = [
      for (final email in claimers)
        AvatarStackMember(
          name: display.nameOf(email),
          colorKey: email,
          isYou: display.isYou(email),
        ),
    ];
    // "You" accent when the persona is one of the claimers.
    final Color bg = chipState.claimedByYou
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.surfaceContainerHighest;
    // F163 selected-state: a 1.5px accent border when the unit is yours,
    // otherwise a faint outline so every claimed chip reads as a bounded slot.
    final Color borderColor = chipState.claimedByYou
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.outlineVariant;
    final label = chipState.splitCount > 1
        ? l10n.claimSplitLabel(
            l10n.toCurrency(chipState.perUnitCost, currency.code),
          )
        : display.nameOf(claimers.first);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarStack(members: stackMembers, radius: 11, ringColor: bg),
            const SizedBox(width: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: chipState.claimedByYou
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A free unit slot: dashed "+ take one" chip. Tap claims it solo for the
/// current persona.
class _TakeOneChip extends StatelessWidget {
  const _TakeOneChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _DashedChip(
      color: colorScheme.primary.withValues(alpha: 0.55),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 15, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            l10n.claimTakeOne,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ghost "Split one" pill on the card footer. Dimmed and inert when the item
/// has no free unit left to split.
class _SplitOneButton extends StatelessWidget {
  const _SplitOneButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.call_split,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.claimSplitOne,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed-border stadium chip used for the open "take one" affordance.
class _DashedChip extends StatelessWidget {
  const _DashedChip({
    required this.child,
    required this.color,
    required this.onTap,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: CustomPaint(
        painter: _DashedStadiumPainter(color: color),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// Paints a dashed stadium (pill) border in [color].
class _DashedStadiumPainter extends CustomPainter {
  const _DashedStadiumPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter oldDelegate) =>
      oldDelegate.color != color;
}
