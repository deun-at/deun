import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/claim_math.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:deun/pages/expenses/presentation/claim/claim_item_card.dart';

/// Uppercase eyebrow caption above the item list (v3 "TAP TO TAKE WHAT YOU
/// HAD"). Natural-case copy comes from l10n; the screaming caps are applied
/// here via styling so the localized strings stay readable.
class ClaimItemsCaption extends StatelessWidget {
  const ClaimItemsCaption(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Interactive list of claimable items (F131): one card per item group, with
/// one slot chip per unit — solo avatar+name, split avatars + "split · €X",
/// or a dashed "take one" per free unit — a ghost "Split one" button and the
/// "tap a slot" hint.
class ClaimItemList extends StatelessWidget {
  const ClaimItemList({
    super.key,
    required this.groups,
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

  final List<ClaimItemGroup> groups;
  final String persona;
  final MemberDisplay display;
  final List<GroupMember> members;
  final String? expandedUnit;
  final ValueChanged<ClaimUnitRow> onTakeOne;
  final ValueChanged<ClaimUnitRow> onTapUnit;
  final ValueChanged<ClaimItemGroup> onSplitOne;
  final void Function(String entryId, List<String> claimers) onApplySplit;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (groups.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          l10n.claimNoItems,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final group in groups) ...[
          ClaimItemCard(
            group: group,
            persona: persona,
            display: display,
            members: members,
            expandedUnit: expandedUnit,
            onTakeOne: onTakeOne,
            onTapUnit: onTapUnit,
            onSplitOne: () => onSplitOne(group),
            onApplySplit: onApplySplit,
            currency: currency,
          ),
          if (group != groups.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
