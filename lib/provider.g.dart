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

@ProviderFor(StickyRateNotifier)
final stickyRateProvider = StickyRateNotifierProvider._();

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
final class StickyRateNotifierProvider
    extends $NotifierProvider<StickyRateNotifier, Map<String, double>> {
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
  StickyRateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stickyRateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stickyRateNotifierHash();

  @$internal
  @override
  StickyRateNotifier create() => StickyRateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, double> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, double>>(value),
    );
  }
}

String _$stickyRateNotifierHash() =>
    r'c50bccb2ff878586e1b0cd34516e080806ede5f2';

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

abstract class _$StickyRateNotifier extends $Notifier<Map<String, double>> {
  Map<String, double> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Map<String, double>, Map<String, double>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, double>, Map<String, double>>,
              Map<String, double>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
