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

/// Tracks whether any real-time channel has failed after exhausting retries.
/// UI can watch this to show a "live updates paused" banner.

@ProviderFor(RealtimeConnectionStatus)
final realtimeConnectionStatusProvider = RealtimeConnectionStatusProvider._();

/// Tracks whether any real-time channel has failed after exhausting retries.
/// UI can watch this to show a "live updates paused" banner.
final class RealtimeConnectionStatusProvider
    extends $NotifierProvider<RealtimeConnectionStatus, bool> {
  /// Tracks whether any real-time channel has failed after exhausting retries.
  /// UI can watch this to show a "live updates paused" banner.
  RealtimeConnectionStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeConnectionStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeConnectionStatusHash();

  @$internal
  @override
  RealtimeConnectionStatus create() => RealtimeConnectionStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$realtimeConnectionStatusHash() =>
    r'20c65d4107ad3d5ab6fafeaad8512f634d6816d0';

/// Tracks whether any real-time channel has failed after exhausting retries.
/// UI can watch this to show a "live updates paused" banner.

abstract class _$RealtimeConnectionStatus extends $Notifier<bool> {
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
