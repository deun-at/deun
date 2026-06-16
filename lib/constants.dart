import 'package:flutter/material.dart';

const String kWebAppBaseUrl = 'https://app.deun.app';

/// Brand seed color (indigo) used to derive the M3 [ColorScheme]. Kept as a
/// top-level constant rather than a [ColorSeed] enum value so it does not leak
/// into color-picker iterations over [ColorSeed].
const kBrandSeed = Color(0xFF5750E6);

/// Group color-picker swatches (feed [Group.colorValue]). Six base colors from
/// DESIGN_SPEC "Group color palette"; the hero card derives its tint via the
/// surface mapping, so only the base colors are exposed here.
const List<Color> kGroupColorPalette = <Color>[
  Color(0xFF5750E6),
  Color(0xFF2F73D9),
  Color(0xFFE0853D),
  Color(0xFFD45A8A),
  Color(0xFFE0735A),
  Color(0xFFB85C9E),
];

/// Index of the [kGroupColorPalette] swatch matching [colorValue] (an ARGB int
/// as stored in `Group.colorValue`). Returns 0 (the first swatch) when
/// [colorValue] is null or not one of the palette colors, so the swatch row
/// always shows a sensible default selection.
int selectedGroupSwatchIndex(int? colorValue) {
  if (colorValue == null) return 0;
  for (var i = 0; i < kGroupColorPalette.length; i++) {
    if (kGroupColorPalette[i].toARGB32() == colorValue) return i;
  }
  return 0;
}

/// Fixed palette of member-avatar background colors (DESIGN_SPEC "Member avatar
/// colors"). White initials are drawn on top by the avatar widget; this only
/// supplies the background. Pick via [memberAvatarColor] for a stable mapping.
const List<Color> kMemberAvatarPalette = <Color>[
  Color(0xFF5750E6),
  Color(0xFF2F73D9),
  Color(0xFFE0735A),
  Color(0xFFE3A02E),
  Color(0xFFB85C9E),
  Color(0xFF4C6FB5),
  Color(0xFF3F9E84),
  Color(0xFFC76A4E),
  Color(0xFF8268C8),
  Color(0xFFC99A2E),
];

/// Deterministically maps a stable [key] (member email or user id) to a color
/// from [kMemberAvatarPalette]. The same key always yields the same color, so
/// a person keeps their avatar color across rebuilds and screens.
Color memberAvatarColor(String key) {
  // FNV-1a hash: stable across runs/platforms (unlike String.hashCode, which is
  // randomized per isolate) so a member's color never shifts between sessions.
  var hash = 0x811c9dc5;
  for (final codeUnit in key.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return kMemberAvatarPalette[hash % kMemberAvatarPalette.length];
}

/// Public VAPID key for web push. Overridable at build time so it can be
/// rotated without a code change.
const String kFcmVapidKey = String.fromEnvironment(
  'FCM_VAPID_KEY',
  defaultValue: 'BL4YZRDAw8gBPt37GNhz6ub5UxTtDUdjERYzFOgOI2ZdCqwwBToztXtL9Wj0QwqDfKe4CoBQjcjSP54OG3fjFvE',
);

/// Google OAuth client IDs. Public identifiers, but kept overridable at
/// build time so they can be rotated without a code change.
const String kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '820724879316-jauhp8t8g5r3pmir1r5gsghbn2qchav5.apps.googleusercontent.com',
);
const String kGoogleIosClientId = String.fromEnvironment(
  'GOOGLE_IOS_CLIENT_ID',
  defaultValue: '820724879316-8sacuk8sjju1rvr878gl9lqin0or5h9d.apps.googleusercontent.com',
);

enum ColorSeed {
  baseColor('Teal', Colors.teal),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  m3Baseline('M3 Baseline', Color(0xff6750a4)),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}

const spacer = SizedBox(
  height: 12,
);

enum MobileAdMobs {
  androidGroupList(String.fromEnvironment('MOBILE_AD_MOB_ANDROID_GROUP_LIST')),
  androidExpenseList(String.fromEnvironment('MOBILE_AD_MOB_ANDROID_EXPENSE_LIST')),
  iosGroupList(String.fromEnvironment('MOBILE_AD_MOB_IOS_GROUP_LIST')),
  iosExpenseList(String.fromEnvironment('MOBILE_AD_MOB_IOS_EXPENSE_LIST'));

  const MobileAdMobs(this.value);
  final String value;
}