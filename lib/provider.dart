import 'package:async_preferences/async_preferences.dart';
import 'package:deun/helper/currency_conversion.dart';
import 'package:deun/helper/exchange_rate_service.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/settings/theme_mode_pref.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/users/user_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

/// Persisted-preferences key for the user's Appearance (theme-mode) choice.
const String kThemeModePrefKey = 'theme_mode';

/// Persisted-preferences key for the in-app notifications toggle (E7-T3 v0:
/// stores the user's preference; does not yet gate FCM).
const String kNotificationsEnabledPrefKey = 'notifications_enabled';

/// Persisted-preferences key for the user's home currency — the currency every
/// cross-group aggregate (overall balance, friendships, statistics) is
/// converted into for display. Device-scoped, like the theme/notification prefs.
const String kHomeCurrencyPrefKey = 'home_currency';

/// The Supabase auth-state change stream. Isolated behind a provider so the
/// central user-switch listener ([AuthUserSwitchListener]) can be driven with a
/// controllable stream in tests.
@riverpod
Stream<AuthState> authStateChanges(Ref ref) => supabase.auth.onAuthStateChange;

/// Invalidates every user-scoped `keepAlive` provider so a new session never
/// inherits the previous account's cached data. This is the single choke point
/// referenced by [AuthUserSwitchListener].
///
/// Device-scoped preference providers ([ThemeModeNotifier],
/// [NotificationsEnabledNotifier]) are intentionally excluded: they survive a
/// user switch on the same device.
void invalidateUserScopedProviders(Ref ref) {
  ref.invalidate(userDetailProvider);
  ref.invalidate(groupListProvider);
  ref.invalidate(friendshipListProvider);
}

/// Watches Supabase auth-state changes and invalidates the user-scoped providers
/// on sign-out (and on sign-in as a *different* user). Mounted once near the app
/// root; centralizing the invalidation here means new sign-out surfaces cannot
/// silently reintroduce the stale-previous-user-data bug.
@Riverpod(keepAlive: true)
class AuthUserSwitchListener extends _$AuthUserSwitchListener {
  String? _lastUserId;

  @override
  void build() {
    _lastUserId = supabase.auth.currentUser?.id;
    ref.listen(authStateChangesProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      _onAuthState(state);
    });
  }

  void _onAuthState(AuthState state) {
    final userId = state.session?.user.id;
    switch (state.event) {
      case AuthChangeEvent.signedOut:
        // Always refresh on sign-out so the next session builds fresh,
        // regardless of who signs in next.
        invalidateUserScopedProviders(ref);
        _lastUserId = null;
      case AuthChangeEvent.signedIn:
        // A same-user token refresh / re-emit must not needlessly refetch;
        // only a genuine account change invalidates.
        if (_lastUserId != null && _lastUserId != userId) {
          invalidateUserScopedProviders(ref);
        }
        _lastUserId = userId;
      default:
        break;
    }
  }
}

@Riverpod(keepAlive: true)
class UserDetailNotifier extends _$UserDetailNotifier {
  @override
  FutureOr<SupaUser> build() async {
    return await fetchUserDetail();
  }

  Future<SupaUser> fetchUserDetail() async {
    return await UserRepository.fetchDetail(
      supabase.auth.currentUser!.email ?? '',
    );
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
    await _preferences.setString(
      kThemeModePrefKey,
      themeModeToPrefString(mode),
    );
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

/// The user's home currency (ISO 4217): the single currency every cross-group
/// aggregate is converted into for display. Defaults to [kDefaultCurrencyCode]
/// (EUR), hydrates from [AsyncPreferences] and persists the choice. Only codes
/// in [kSupportedCurrencyCodes] are accepted; anything else falls back to the
/// default. Device-scoped, so it survives a user switch on the same device.
@Riverpod(keepAlive: true)
class HomeCurrencyNotifier extends _$HomeCurrencyNotifier {
  final AsyncPreferences _preferences = AsyncPreferences();

  @override
  String build() {
    _hydrate();
    return kDefaultCurrencyCode;
  }

  Future<void> _hydrate() async {
    final stored = await _preferences.getString(kHomeCurrencyPrefKey);
    if (stored != null && kSupportedCurrencyCodes.contains(stored)) {
      state = stored;
    }
  }

  Future<void> setHomeCurrency(String code) async {
    if (!kSupportedCurrencyCodes.contains(code)) return;
    state = code;
    await _preferences.setString(kHomeCurrencyPrefKey, code);
  }
}

/// Current cross-group conversion rates, fetched at load from the free no-key
/// rate API with an offline last-known-rates fallback (see
/// [ExchangeRateService]). `null` means no rates are available at all (offline
/// with no cache), in which case aggregates fall back to home-currency groups
/// only. Display-only: never applied to the stored ledger.
@Riverpod(keepAlive: true)
Future<ExchangeRates?> exchangeRates(Ref ref) =>
    ExchangeRateService().loadRates();
