// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payback_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(paybackRepository)
final paybackRepositoryProvider = PaybackRepositoryProvider._();

final class PaybackRepositoryProvider
    extends
        $FunctionalProvider<
          PaybackRepository,
          PaybackRepository,
          PaybackRepository
        >
    with $Provider<PaybackRepository> {
  PaybackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paybackRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paybackRepositoryHash();

  @$internal
  @override
  $ProviderElement<PaybackRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaybackRepository create(Ref ref) {
    return paybackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaybackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaybackRepository>(value),
    );
  }
}

String _$paybackRepositoryHash() => r'e22d09794fd824c2d04a5d0b5fb31585f1368259';
