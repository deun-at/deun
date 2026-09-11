import 'dart:convert';

import 'package:async_preferences/async_preferences.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/settings/theme_mode_pref.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helper/helper.dart';
import 'pages/users/user_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

/// Persisted-preferences key for the user's Appearance (theme-mode) choice.
const String kThemeModePrefKey = 'theme_mode';

/// Persisted-preferences key for the in-app notifications toggle (E7-T3 v0:
/// stores the user's preference; does not yet gate FCM).
const String kNotificationsEnabledPrefKey = 'notifications_enabled';

/// Persisted-preferences key holding every sticky conversion rate as one JSON
/// object. ONE blob rather than a key per pair, so a cleared rate is
/// representable: a per-key store cannot express "this entry is gone" against a
/// merge-based hydration.
const String kStickyRatesPrefKey = 'sticky_conversion_rates';

/// Map key for one (group, source currency) pair.
String stickyRateKey(String groupId, Currency from) => '$groupId|${from.code}';

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

/// The last rate the user entered manually, per group and source currency. A
/// LOCAL prefill only: it seeds the next expense entered in that currency in
/// that group so a trip can hold one agreed rate, and it is deliberately not
/// synced — correctness lives in the frozen per-row value, and two members
/// legitimately get different rates for the same day (exchange office vs card).
///
/// [hydrated] is stored and awaited by every mutation, and by the editor before
/// it reads a prefill. Two failures come from not doing that:
///   * hydration REPLACES the map wholesale, so a merge cannot resurrect a
///     cleared entry — but only if a `clear` that lands first is not then
///     overwritten by a late hydrate. Awaiting [hydrated] first orders them.
///   * this is a keepAlive provider, and the editor reads a prefill
///     synchronously right after its first build. Without awaiting, the first
///     foreign-currency pick after app start never prefills.
@Riverpod(keepAlive: true)
class StickyRateNotifier extends _$StickyRateNotifier {
  final AsyncPreferences _preferences = AsyncPreferences();

  late final Future<void> _hydration;

  /// Resolves once the stored rates have been loaded into [state]. Await this
  /// before reading [stickyRate].
  Future<void> get hydrated => _hydration;

  @override
  Map<String, double> build() {
    // The synchronous default keeps the first frame off storage; every reader
    // and writer awaits [hydrated] before it acts on the map.
    _hydration = _hydrate();
    return const {};
  }

  Future<void> _hydrate() async {
    final stored = await _preferences.getString(kStickyRatesPrefKey);
    if (stored == null || stored.isEmpty) return;
    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      // REPLACE, never merge: a merge cannot represent a deletion.
      state = {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      };
    } catch (_) {
      // A hand-edited or corrupt blob is inert, not fatal — a prefill is a
      // convenience and must never block the editor.
    }
  }

  Future<void> _persist() =>
      _preferences.setString(kStickyRatesPrefKey, jsonEncode(state));

  /// The remembered rate for [groupId] and [from], or null. Synchronous by
  /// design (the Contract's shape) — await [hydrated] before calling it.
  double? stickyRate(String groupId, Currency from) =>
      state[stickyRateKey(groupId, from)];

  Future<void> setStickyRate(String groupId, Currency from, double rate) async {
    await _hydration;
    state = {...state, stickyRateKey(groupId, from): rate};
    await _persist();
  }

  Future<void> clearStickyRate(String groupId, Currency from) async {
    await _hydration;
    final next = {...state}..remove(stickyRateKey(groupId, from));
    state = next;
    await _persist();
  }
}
