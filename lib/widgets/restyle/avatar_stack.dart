import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:flutter/material.dart';

/// One entry in an [AvatarStack].
class AvatarStackMember {
  const AvatarStackMember({
    required this.name,
    required this.colorKey,
    this.imageUrl,
    this.isYou = false,
  });

  final String name;
  final String colorKey;
  final String? imageUrl;
  final bool isYou;
}

/// A row of overlapping [MemberAvatar]s with a surface-colored ring on each so
/// they read as separate tokens. Shows at most [maxVisible] avatars and a
/// trailing "+N" chip for any overflow.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.members,
    this.maxVisible = 4,
    this.radius = 14,
    this.overlap = 10,
    this.ringWidth = 2,
    this.ringColor,
    this.uniformColor,
  });

  /// Members to render, in display order.
  final List<AvatarStackMember> members;

  /// Maximum avatars shown before collapsing the remainder into a "+N" chip.
  final int maxVisible;

  /// Radius of each avatar.
  final double radius;

  /// How far each avatar is pulled over the previous one.
  final double overlap;

  /// Ring width separating overlapping avatars.
  final double ringWidth;

  /// Ring color; defaults to the surface behind the stack.
  final Color? ringColor;

  /// When set, every avatar is drawn with this single background color instead
  /// of its per-member color (and the "you" accent is suppressed). Used by the
  /// group-detail hero stack, which renders uniform avatars per the handoff
  /// (F140).
  final Color? uniformColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ring = ringColor ?? colorScheme.surface;
    final overflow = members.length - maxVisible;
    final visible = overflow > 0 ? members.take(maxVisible).toList() : members;
    final step = (radius * 2) - overlap;

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final m = visible[i];
      children.add(Padding(
        padding: EdgeInsets.only(left: i == 0 ? 0 : step),
        child: MemberAvatar(
          name: m.name,
          colorKey: m.colorKey,
          imageUrl: m.imageUrl,
          isYou: m.isYou,
          radius: radius,
          ringColor: ring,
          ringWidth: ringWidth,
          backgroundColor: uniformColor,
        ),
      ));
    }

    if (overflow > 0) {
      children.add(Padding(
        padding: EdgeInsets.only(left: visible.isEmpty ? 0 : step),
        child: Container(
          padding: EdgeInsets.all(ringWidth),
          decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Text(
              '+$overflow',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.7,
              ),
            ),
          ),
        ),
      ));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
