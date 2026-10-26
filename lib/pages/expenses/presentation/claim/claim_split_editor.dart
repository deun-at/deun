import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:deun/helper/helper.dart';
import 'package:flutter/material.dart';

/// Inline split editor (F163): the grey in-card box that replaces the old
/// modal bottom sheet. Choose who shares a single unit via toggleable member
/// pills, with the live per-person cost (unit / selected) in the title. "Done"
/// applies the selection through [onDone]. The claim RPC is unchanged — this is
/// only a sheet→inline container swap.
class ClaimSplitEditorCard extends StatefulWidget {
  const ClaimSplitEditorCard({
    super.key,
    required this.unitCost,
    required this.members,
    required this.display,
    required this.initialClaimers,
    required this.onDone,
    required this.currency,
  });

  final double unitCost;
  final List<GroupMember> members;
  final MemberDisplay display;
  final Set<String> initialClaimers;
  final ValueChanged<List<String>> onDone;
  final Currency currency;

  @override
  State<ClaimSplitEditorCard> createState() => _ClaimSplitEditorCardState();
}

class _ClaimSplitEditorCardState extends State<ClaimSplitEditorCard> {
  late final Set<String> _selected = {...widget.initialClaimers};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final perPerson = _selected.isEmpty
        ? 0.0
        : widget.unitCost / _selected.length;

    return Container(
      width: double.infinity,
      // Grey surface box, radius14 (mockup L1276-1293) — surface is the warm
      // #F4F3EF token, distinct from the white item card it nests in.
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.claimSplitEditorTitle(
              l10n.toCurrency(perPerson, widget.currency.code),
            ),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.claimSplitEditorHint,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final m in widget.members)
                _SplitMemberPill(
                  key: ValueKey('editor-member:${m.email}'),
                  name: widget.display.nameOf(m.email),
                  colorKey: m.email,
                  isYou: widget.display.isYou(m.email),
                  selected: _selected.contains(m.email),
                  onTap: () => setState(() {
                    if (!_selected.remove(m.email)) _selected.add(m.email);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 11),
          _SplitDoneButton(
            label: l10n.claimSplitDone,
            onTap: () => widget.onDone(_selected.toList()),
          ),
        ],
      ),
    );
  }
}

/// A toggleable member pill in the inline split editor: avatar + name, tinted
/// with the primary accent and a solid border when selected, faint outline when
/// not (mockup L1281-1286).
class _SplitMemberPill extends StatelessWidget {
  const _SplitMemberPill({
    super.key,
    required this.name,
    required this.colorKey,
    required this.isYou,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String colorKey;
  final bool isYou;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.surfaceContainerLowest;
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.35)
        : colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: BorderSide(color: borderColor, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: selected ? 1 : 0.55,
              child: MemberAvatar(
                name: name,
                colorKey: colorKey,
                radius: 11,
                isYou: isYou,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The solid-ink "Done" button that applies the inline split editor selection.
class _SplitDoneButton extends StatelessWidget {
  const _SplitDoneButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: semantic.ink,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                color: semantic.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
