import 'package:deun/pages/settings/theme_mode_pref.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themeModeToPrefString', () {
    test('maps each mode to a stable string', () {
      expect(themeModeToPrefString(ThemeMode.system), 'system');
      expect(themeModeToPrefString(ThemeMode.light), 'light');
      expect(themeModeToPrefString(ThemeMode.dark), 'dark');
    });
  });

  group('themeModeFromPrefString', () {
    test('parses each stored string back to its mode', () {
      expect(themeModeFromPrefString('system'), ThemeMode.system);
      expect(themeModeFromPrefString('light'), ThemeMode.light);
      expect(themeModeFromPrefString('dark'), ThemeMode.dark);
    });

    test('falls back to system for null', () {
      expect(themeModeFromPrefString(null), ThemeMode.system);
    });

    test('falls back to system for an unknown string', () {
      expect(themeModeFromPrefString('twilight'), ThemeMode.system);
      expect(themeModeFromPrefString(''), ThemeMode.system);
    });
  });

  group('round-trip', () {
    test('every mode survives a to/from round-trip', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromPrefString(themeModeToPrefString(mode)), mode);
      }
    });
  });
}
