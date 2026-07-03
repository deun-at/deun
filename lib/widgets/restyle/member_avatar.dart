import 'package:deun/constants.dart';
import 'package:flutter/material.dart';

/// Circular member avatar: white initials over a deterministic
/// [memberAvatarColor] background (keyed by email/id), with an optional ring.
///
/// Pass [imageUrl] to render a photo instead of initials. Set [isYou] to tint
/// the background with the theme's primary color (the "you" accent).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.colorKey,
    this.radius = 18,
    this.imageUrl,
    this.isYou = false,
    this.ringColor,
    this.ringWidth = 0,
    this.backgroundColor,
  });

  /// Display name used to derive the initials.
  final String name;

  /// Stable key (email / user id) → background color via [memberAvatarColor].
  final String colorKey;

  /// Avatar radius in logical pixels.
  final double radius;

  /// Optional avatar photo. When non-null and non-empty it replaces initials.
  final String? imageUrl;

  /// Tints the background with [ColorScheme.primary] (the "you" accent).
  final bool isYou;

  /// Optional ring drawn around the avatar (e.g. a surface-colored separator in
  /// an [AvatarStack]). Ignored when [ringWidth] is 0.
  final Color? ringColor;

  /// Width of the optional ring.
  final double ringWidth;

  /// Overrides the deterministic per-member background (and the [isYou] accent)
  /// with a single fixed color. Used by the group-detail hero stack, which
  /// renders all avatars uniformly (F140) rather than per-member.
  final Color? backgroundColor;

  /// Up to two uppercase initials derived from [name] (first letters of the
  /// first two words).
  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = backgroundColor ??
        (isYou ? colorScheme.primary : memberAvatarColor(colorKey));
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              initialsFor(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.8,
              ),
            ),
    );

    if (ringWidth > 0) {
      avatar = Container(
        padding: EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor ?? colorScheme.surface,
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
