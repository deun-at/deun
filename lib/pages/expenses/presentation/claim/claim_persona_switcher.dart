import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/member_display.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';

/// "Preview as" persona switcher (v3 handoff §9): a card row with the muted
/// "Preview as" label on the left and one avatar circle per member (name in
/// small text underneath) on the right. The selected persona's avatar gets an
/// ink selection ring; the others are dimmed. Re-derives the summary's "your
/// share" for the chosen perspective — does not mutate claims. Solo groups
/// render the single member statically (nothing to preview as). The avatar
/// strip scrolls horizontally so large groups never overflow.
class ClaimPersonaSwitcher extends StatelessWidget {
  const ClaimPersonaSwitcher({
    super.key,
    required this.members,
    required this.selected,
    required this.display,
    required this.onChanged,
  });

  final List<GroupMember> members;
  final String selected;
  final MemberDisplay display;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final interactive = members.length > 1;

    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            l10n.claimPreviewAs,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in members) ...[
                      _PersonaAvatar(
                        key: ValueKey('persona:${m.email}'),
                        name: display.nameOf(m.email),
                        colorKey: m.email,
                        isYou: display.isYou(m.email),
                        selected: m.email == selected,
                        onTap: interactive ? () => onChanged(m.email) : null,
                      ),
                      if (m != members.last) const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One persona in the switcher: avatar circle with the name in small text
/// underneath. Selected → ink ring + full opacity; unselected → dimmed with a
/// muted label. The transparent placeholder ring keeps the avatar size stable
/// across selection changes.
class _PersonaAvatar extends StatelessWidget {
  const _PersonaAvatar({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: selected ? 1 : 0.55,
              child: MemberAvatar(
                name: name,
                colorKey: colorKey,
                radius: 16,
                isYou: isYou,
                ringColor: selected ? semantic.ink : Colors.transparent,
                ringWidth: 2.5,
              ),
            ),
            const SizedBox(height: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
