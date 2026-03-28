// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_mixin.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Counter incremented on app resume. Providers listen to this to reload data
/// without a full rebuild (preserving pagination state, scroll position, etc.).

@ProviderFor(AppResumeCounter)
final appResumeCounterProvider = AppResumeCounterProvider._();

/// Counter incremented on app resume. Providers listen to this to reload data
/// without a full rebuild (preserving pagination state, scroll position, etc.).
final class AppResumeCounterProvider
    extends $NotifierProvider<AppResumeCounter, int> {
  /// Counter incremented on app resume. Providers listen to this to reload data
  /// without a full rebuild (preserving pagination state, scroll position, etc.).
  AppResumeCounterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appResumeCounterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appResumeCounterHash();

  @$internal
  @override
  AppResumeCounter create() => AppResumeCounter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$appResumeCounterHash() => r'67ad20102f26fecd92c2e5693ddd43839d769825';

/// Counter incremented on app resume. Providers listen to this to reload data
/// without a full rebuild (preserving pagination state, scroll position, etc.).

abstract class _$AppResumeCounter extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
