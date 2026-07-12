// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Supabase auth-state change stream. Isolated behind a provider so the
/// central user-switch listener ([AuthUserSwitchListener]) can be driven with a
/// controllable stream in tests.

@ProviderFor(authStateChanges)
final authStateChangesProvider = AuthStateChangesProvider._();

/// The Supabase auth-state change stream. Isolated behind a provider so the
/// central user-switch listener ([AuthUserSwitchListener]) can be driven with a
/// controllable stream in tests.

final class AuthStateChangesProvider
    extends
        $FunctionalProvider<AsyncValue<AuthState>, AuthState, Stream<AuthState>>
    with $FutureModifier<AuthState>, $StreamProvider<AuthState> {
  /// The Supabase auth-state change stream. Isolated behind a provider so the
  /// central user-switch listener ([AuthUserSwitchListener]) can be driven with a
  /// controllable stream in tests.
  AuthStateChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateChangesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateChangesHash();

  @$internal
  @override
  $StreamProviderElement<AuthState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AuthState> create(Ref ref) {
    return authStateChanges(ref);
  }
}

String _$authStateChangesHash() => r'9fa2fe817507b5e89bc3fdcd940ed567253f90d0';

/// Watches Supabase auth-state changes and invalidates the user-scoped providers
/// on sign-out (and on sign-in as a *different* user). Mounted once near the app
/// root; centralizing the invalidation here means new sign-out surfaces cannot
/// silently reintroduce the stale-previous-user-data bug.

@ProviderFor(AuthUserSwitchListener)
final authUserSwitchListenerProvider = AuthUserSwitchListenerProvider._();

/// Watches Supabase auth-state changes and invalidates the user-scoped providers
/// on sign-out (and on sign-in as a *different* user). Mounted once near the app
/// root; centralizing the invalidation here means new sign-out surfaces cannot
/// silently reintroduce the stale-previous-user-data bug.
final class AuthUserSwitchListenerProvider
    extends $NotifierProvider<AuthUserSwitchListener, void> {
  /// Watches Supabase auth-state changes and invalidates the user-scoped providers
  /// on sign-out (and on sign-in as a *different* user). Mounted once near the app
  /// root; centralizing the invalidation here means new sign-out surfaces cannot
  /// silently reintroduce the stale-previous-user-data bug.
  AuthUserSwitchListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authUserSwitchListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authUserSwitchListenerHash();

  @$internal
  @override
  AuthUserSwitchListener create() => AuthUserSwitchListener();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$authUserSwitchListenerHash() =>
    r'0490adb749a6e61ec59aedb285070a31cfc1e9a6';

/// Watches Supabase auth-state changes and invalidates the user-scoped providers
/// on sign-out (and on sign-in as a *different* user). Mounted once near the app
/// root; centralizing the invalidation here means new sign-out surfaces cannot
/// silently reintroduce the stale-previous-user-data bug.

abstract class _$AuthUserSwitchListener extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(UserDetailNotifier)
final userDetailProvider = UserDetailNotifierProvider._();

final class UserDetailNotifierProvider
    extends $AsyncNotifierProvider<UserDetailNotifier, SupaUser> {
  UserDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDetailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDetailNotifierHash();

  @$internal
  @override
  UserDetailNotifier create() => UserDetailNotifier();
}

String _$userDetailNotifierHash() =>
    r'99e8a26d1615c267217da2d4bb52cba733ab6ff6';

abstract class _$UserDetailNotifier extends $AsyncNotifier<SupaUser> {
  FutureOr<SupaUser> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SupaUser>, SupaUser>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SupaUser>, SupaUser>,
              AsyncValue<SupaUser>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(LocaleNotifier)
final localeProvider = LocaleNotifierProvider._();

final class LocaleNotifierProvider
    extends $NotifierProvider<LocaleNotifier, Locale?> {
  LocaleNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeNotifierHash();

  @$internal
  @override
  LocaleNotifier create() => LocaleNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$localeNotifierHash() => r'5c0c6044e089a089e96f0c1b78f3994f9224f611';

abstract class _$LocaleNotifier extends $Notifier<Locale?> {
  Locale? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// App-wide theme mode (System / Light / Dark), driven by the Settings
/// Appearance picker (E7-T3). Synchronously defaults to [ThemeMode.system],
/// then hydrates from [AsyncPreferences] after the first frame and persists any
/// change the user makes.

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// App-wide theme mode (System / Light / Dark), driven by the Settings
/// Appearance picker (E7-T3). Synchronously defaults to [ThemeMode.system],
/// then hydrates from [AsyncPreferences] after the first frame and persists any
/// change the user makes.
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, ThemeMode> {
  /// App-wide theme mode (System / Light / Dark), driven by the Settings
  /// Appearance picker (E7-T3). Synchronously defaults to [ThemeMode.system],
  /// then hydrates from [AsyncPreferences] after the first frame and persists any
  /// change the user makes.
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'8adbe6cb9ea01775930c9f3669e33ded3dc20cd2';

/// App-wide theme mode (System / Light / Dark), driven by the Settings
/// Appearance picker (E7-T3). Synchronously defaults to [ThemeMode.system],
/// then hydrates from [AsyncPreferences] after the first frame and persists any
/// change the user makes.

abstract class _$ThemeModeNotifier extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Whether the user wants in-app notifications enabled (E7-T3 v0). Defaults to
/// `true`, hydrates from [AsyncPreferences] and persists the choice. This stores
/// the preference only; it does not (yet) gate FCM registration.

@ProviderFor(NotificationsEnabledNotifier)
final notificationsEnabledProvider = NotificationsEnabledNotifierProvider._();

/// Whether the user wants in-app notifications enabled (E7-T3 v0). Defaults to
/// `true`, hydrates from [AsyncPreferences] and persists the choice. This stores
/// the preference only; it does not (yet) gate FCM registration.
final class NotificationsEnabledNotifierProvider
    extends $NotifierProvider<NotificationsEnabledNotifier, bool> {
  /// Whether the user wants in-app notifications enabled (E7-T3 v0). Defaults to
  /// `true`, hydrates from [AsyncPreferences] and persists the choice. This stores
  /// the preference only; it does not (yet) gate FCM registration.
  NotificationsEnabledNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsEnabledNotifierHash();

  @$internal
  @override
  NotificationsEnabledNotifier create() => NotificationsEnabledNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$notificationsEnabledNotifierHash() =>
    r'ca062ab01c88f76ea8609707703a56e647e8f84f';

/// Whether the user wants in-app notifications enabled (E7-T3 v0). Defaults to
/// `true`, hydrates from [AsyncPreferences] and persists the choice. This stores
/// the preference only; it does not (yet) gate FCM registration.

abstract class _$NotificationsEnabledNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The user's home currency (ISO 4217): the single currency every cross-group
/// aggregate is converted into for display. Defaults to [kDefaultCurrencyCode]
/// (EUR), hydrates from [AsyncPreferences] and persists the choice. Only codes
/// in [kSupportedCurrencyCodes] are accepted; anything else falls back to the
/// default. Device-scoped, so it survives a user switch on the same device.

@ProviderFor(HomeCurrencyNotifier)
final homeCurrencyProvider = HomeCurrencyNotifierProvider._();

/// The user's home currency (ISO 4217): the single currency every cross-group
/// aggregate is converted into for display. Defaults to [kDefaultCurrencyCode]
/// (EUR), hydrates from [AsyncPreferences] and persists the choice. Only codes
/// in [kSupportedCurrencyCodes] are accepted; anything else falls back to the
/// default. Device-scoped, so it survives a user switch on the same device.
final class HomeCurrencyNotifierProvider
    extends $NotifierProvider<HomeCurrencyNotifier, String> {
  /// The user's home currency (ISO 4217): the single currency every cross-group
  /// aggregate is converted into for display. Defaults to [kDefaultCurrencyCode]
  /// (EUR), hydrates from [AsyncPreferences] and persists the choice. Only codes
  /// in [kSupportedCurrencyCodes] are accepted; anything else falls back to the
  /// default. Device-scoped, so it survives a user switch on the same device.
  HomeCurrencyNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeCurrencyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeCurrencyNotifierHash();

  @$internal
  @override
  HomeCurrencyNotifier create() => HomeCurrencyNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$homeCurrencyNotifierHash() =>
    r'cafbe05e54aefe2d9ac59c9512b54522244a8b9c';

/// The user's home currency (ISO 4217): the single currency every cross-group
/// aggregate is converted into for display. Defaults to [kDefaultCurrencyCode]
/// (EUR), hydrates from [AsyncPreferences] and persists the choice. Only codes
/// in [kSupportedCurrencyCodes] are accepted; anything else falls back to the
/// default. Device-scoped, so it survives a user switch on the same device.

abstract class _$HomeCurrencyNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Current cross-group conversion rates, fetched at load from the free no-key
/// rate API with an offline last-known-rates fallback (see
/// [ExchangeRateService]). `null` means no rates are available at all (offline
/// with no cache), in which case aggregates fall back to home-currency groups
/// only. Display-only: never applied to the stored ledger.

@ProviderFor(exchangeRates)
final exchangeRatesProvider = ExchangeRatesProvider._();

/// Current cross-group conversion rates, fetched at load from the free no-key
/// rate API with an offline last-known-rates fallback (see
/// [ExchangeRateService]). `null` means no rates are available at all (offline
/// with no cache), in which case aggregates fall back to home-currency groups
/// only. Display-only: never applied to the stored ledger.

final class ExchangeRatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExchangeRates?>,
          ExchangeRates?,
          FutureOr<ExchangeRates?>
        >
    with $FutureModifier<ExchangeRates?>, $FutureProvider<ExchangeRates?> {
  /// Current cross-group conversion rates, fetched at load from the free no-key
  /// rate API with an offline last-known-rates fallback (see
  /// [ExchangeRateService]). `null` means no rates are available at all (offline
  /// with no cache), in which case aggregates fall back to home-currency groups
  /// only. Display-only: never applied to the stored ledger.
  ExchangeRatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exchangeRatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exchangeRatesHash();

  @$internal
  @override
  $FutureProviderElement<ExchangeRates?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExchangeRates?> create(Ref ref) {
    return exchangeRates(ref);
  }
}

String _$exchangeRatesHash() => r'77e7e54c108b7e55a5554285c56e4609792615a6';
