import 'package:flutter/material.dart' show ThemeMode;

/// Pure, storage-agnostic mapping between [ThemeMode] and the stable string we
/// persist for the user's Appearance choice (E7-T3).
///
/// Keeping the mapping pure (no Flutter widgets, no I/O) lets the
/// `ThemeModeNotifier` stay thin and lets the mapping be unit-tested directly.

/// The stable persisted token for [mode]. Round-trips with
/// [themeModeFromPrefString].
String themeModeToPrefString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return 'system';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
  }
}

/// Parses a persisted token back to a [ThemeMode], falling back to
/// [ThemeMode.system] for `null` or any unrecognized value.
ThemeMode themeModeFromPrefString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}
