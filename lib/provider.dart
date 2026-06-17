import 'package:async_preferences/async_preferences.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/settings/theme_mode_pref.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'pages/users/user_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

/// Persisted-preferences key for the user's Appearance (theme-mode) choice.
const String kThemeModePrefKey = 'theme_mode';

/// Persisted-preferences key for the in-app notifications toggle (E7-T3 v0:
/// stores the user's preference; does not yet gate FCM).
const String kNotificationsEnabledPrefKey = 'notifications_enabled';

@Riverpod(keepAlive: true)
class UserDetailNotifier extends _$UserDetailNotifier {
  @override
  FutureOr<SupaUser> build() async {
    return await fetchUserDetail();
  }

  Future<SupaUser> fetchUserDetail() async {
    return await UserRepository.fetchDetail(supabase.auth.currentUser!.email ?? '');
  }
}

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale? build() => null;

  void setLocale(Locale locale) => state = locale;

  void resetLocale() => state = null;
}

/// App-wide theme mode (System / Light / Dark), driven by the Settings
/// Appearance picker (E7-T3). Synchronously defaults to [ThemeMode.system],
/// then hydrates from [AsyncPreferences] after the first frame and persists any
/// change the user makes.
@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  final AsyncPreferences _preferences = AsyncPreferences();

  @override
  ThemeMode build() {
    // Hydrate asynchronously; the synchronous default keeps the first frame
    // from blocking on storage.
    _hydrate();
    return ThemeMode.system;
  }

  Future<void> _hydrate() async {
    final stored = await _preferences.getString(kThemeModePrefKey);
    state = themeModeFromPrefString(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _preferences.setString(kThemeModePrefKey, themeModeToPrefString(mode));
  }
}

/// Whether the user wants in-app notifications enabled (E7-T3 v0). Defaults to
/// `true`, hydrates from [AsyncPreferences] and persists the choice. This stores
/// the preference only; it does not (yet) gate FCM registration.
@Riverpod(keepAlive: true)
class NotificationsEnabledNotifier extends _$NotificationsEnabledNotifier {
  final AsyncPreferences _preferences = AsyncPreferences();

  @override
  bool build() {
    _hydrate();
    return true;
  }

  Future<void> _hydrate() async {
    final stored = await _preferences.getBool(kNotificationsEnabledPrefKey);
    if (stored != null) state = stored;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _preferences.setBool(kNotificationsEnabledPrefKey, value: enabled);
  }
}
