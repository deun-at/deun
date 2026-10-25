// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSignOut)
final appSignOutProvider = AppSignOutProvider._();

final class AppSignOutProvider
    extends $FunctionalProvider<AppSignOut, AppSignOut, AppSignOut>
    with $Provider<AppSignOut> {
  AppSignOutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSignOutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSignOutHash();

  @$internal
  @override
  $ProviderElement<AppSignOut> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSignOut create(Ref ref) {
    return appSignOut(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSignOut value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSignOut>(value),
    );
  }
}

String _$appSignOutHash() => r'0581800a07a657b60face89ebc29319cf8680fd2';
