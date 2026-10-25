// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_notifications.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushMessaging)
final pushMessagingProvider = PushMessagingProvider._();

final class PushMessagingProvider
    extends $FunctionalProvider<PushMessaging, PushMessaging, PushMessaging>
    with $Provider<PushMessaging> {
  PushMessagingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushMessagingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushMessagingHash();

  @$internal
  @override
  $ProviderElement<PushMessaging> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushMessaging create(Ref ref) {
    return pushMessaging(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushMessaging value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushMessaging>(value),
    );
  }
}

String _$pushMessagingHash() => r'168f5569e59a684e12ffa7bb9fe26935935412b8';

@ProviderFor(deviceTokenStore)
final deviceTokenStoreProvider = DeviceTokenStoreProvider._();

final class DeviceTokenStoreProvider
    extends
        $FunctionalProvider<
          DeviceTokenStore,
          DeviceTokenStore,
          DeviceTokenStore
        >
    with $Provider<DeviceTokenStore> {
  DeviceTokenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceTokenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceTokenStoreHash();

  @$internal
  @override
  $ProviderElement<DeviceTokenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceTokenStore create(Ref ref) {
    return deviceTokenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceTokenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceTokenStore>(value),
    );
  }
}

String _$deviceTokenStoreHash() => r'd26ad712e5ea16901ac44ab60a6d126d46a5a7e4';

@ProviderFor(initialMessageLatch)
final initialMessageLatchProvider = InitialMessageLatchProvider._();

final class InitialMessageLatchProvider
    extends
        $FunctionalProvider<
          InitialMessageLatch,
          InitialMessageLatch,
          InitialMessageLatch
        >
    with $Provider<InitialMessageLatch> {
  InitialMessageLatchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialMessageLatchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialMessageLatchHash();

  @$internal
  @override
  $ProviderElement<InitialMessageLatch> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InitialMessageLatch create(Ref ref) {
    return initialMessageLatch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InitialMessageLatch value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InitialMessageLatch>(value),
    );
  }
}

String _$initialMessageLatchHash() =>
    r'259ea4c7f5faabe9a0c63c7da53e8361a53b72fc';

/// Owns FCM permission, this device's token registration and the
/// notification-tap, token-refresh and cold-start handling for the signed-in
/// user. Exactly one listener of each kind exists at any time.
///
/// User-scoped: [invalidateUserScopedProviders] disposes it on every
/// sign-out, including one the app did not start, and disposal cancels the
/// listeners. It takes its messaging and store once in [build] and never
/// touches `ref` after an await.

@ProviderFor(PushSession)
final pushSessionProvider = PushSessionProvider._();

/// Owns FCM permission, this device's token registration and the
/// notification-tap, token-refresh and cold-start handling for the signed-in
/// user. Exactly one listener of each kind exists at any time.
///
/// User-scoped: [invalidateUserScopedProviders] disposes it on every
/// sign-out, including one the app did not start, and disposal cancels the
/// listeners. It takes its messaging and store once in [build] and never
/// touches `ref` after an await.
final class PushSessionProvider extends $NotifierProvider<PushSession, void> {
  /// Owns FCM permission, this device's token registration and the
  /// notification-tap, token-refresh and cold-start handling for the signed-in
  /// user. Exactly one listener of each kind exists at any time.
  ///
  /// User-scoped: [invalidateUserScopedProviders] disposes it on every
  /// sign-out, including one the app did not start, and disposal cancels the
  /// listeners. It takes its messaging and store once in [build] and never
  /// touches `ref` after an await.
  PushSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushSessionHash();

  @$internal
  @override
  PushSession create() => PushSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$pushSessionHash() => r'50f188f5de6e182865ff32fd38ab289690ad274f';

/// Owns FCM permission, this device's token registration and the
/// notification-tap, token-refresh and cold-start handling for the signed-in
/// user. Exactly one listener of each kind exists at any time.
///
/// User-scoped: [invalidateUserScopedProviders] disposes it on every
/// sign-out, including one the app did not start, and disposal cancels the
/// listeners. It takes its messaging and store once in [build] and never
/// touches `ref` after an await.

abstract class _$PushSession extends $Notifier<void> {
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
