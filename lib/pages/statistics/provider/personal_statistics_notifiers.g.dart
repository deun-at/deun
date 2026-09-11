// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_statistics_notifiers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PersonalStatisticsNotifier)
final personalStatisticsProvider = PersonalStatisticsNotifierFamily._();

final class PersonalStatisticsNotifierProvider
    extends
        $AsyncNotifierProvider<
          PersonalStatisticsNotifier,
          PersonalStatisticsState
        > {
  PersonalStatisticsNotifierProvider._({
    required PersonalStatisticsNotifierFamily super.from,
    required StatsRange super.argument,
  }) : super(
         retry: null,
         name: r'personalStatisticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$personalStatisticsNotifierHash();

  @override
  String toString() {
    return r'personalStatisticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PersonalStatisticsNotifier create() => PersonalStatisticsNotifier();

  @override
  bool operator ==(Object other) {
    return other is PersonalStatisticsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$personalStatisticsNotifierHash() =>
    r'2a5ba858babd168a9e74061c0154a71af68ac625';

final class PersonalStatisticsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PersonalStatisticsNotifier,
          AsyncValue<PersonalStatisticsState>,
          PersonalStatisticsState,
          FutureOr<PersonalStatisticsState>,
          StatsRange
        > {
  PersonalStatisticsNotifierFamily._()
    : super(
        retry: null,
        name: r'personalStatisticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PersonalStatisticsNotifierProvider call(StatsRange range) =>
      PersonalStatisticsNotifierProvider._(argument: range, from: this);

  @override
  String toString() => r'personalStatisticsProvider';
}

abstract class _$PersonalStatisticsNotifier
    extends $AsyncNotifier<PersonalStatisticsState> {
  late final _$args = ref.$arg as StatsRange;
  StatsRange get range => _$args;

  FutureOr<PersonalStatisticsState> build(StatsRange range);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<PersonalStatisticsState>,
              PersonalStatisticsState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PersonalStatisticsState>,
                PersonalStatisticsState
              >,
              AsyncValue<PersonalStatisticsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// Which currency the personal statistics surface is showing. VIEW STATE, not a
/// preference: it is derived from the same per-currency map the scalars use, so
/// there is nothing to persist and no second source of truth. `null` means
/// "follow the primary currency".

@ProviderFor(PersonalStatsCurrencyNotifier)
final personalStatsCurrencyProvider = PersonalStatsCurrencyNotifierProvider._();

/// Which currency the personal statistics surface is showing. VIEW STATE, not a
/// preference: it is derived from the same per-currency map the scalars use, so
/// there is nothing to persist and no second source of truth. `null` means
/// "follow the primary currency".
final class PersonalStatsCurrencyNotifierProvider
    extends $NotifierProvider<PersonalStatsCurrencyNotifier, Currency?> {
  /// Which currency the personal statistics surface is showing. VIEW STATE, not a
  /// preference: it is derived from the same per-currency map the scalars use, so
  /// there is nothing to persist and no second source of truth. `null` means
  /// "follow the primary currency".
  PersonalStatsCurrencyNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalStatsCurrencyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalStatsCurrencyNotifierHash();

  @$internal
  @override
  PersonalStatsCurrencyNotifier create() => PersonalStatsCurrencyNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Currency? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Currency?>(value),
    );
  }
}

String _$personalStatsCurrencyNotifierHash() =>
    r'8a6ef161cd5ab43a219e9b30a57813ba26ecf49d';

/// Which currency the personal statistics surface is showing. VIEW STATE, not a
/// preference: it is derived from the same per-currency map the scalars use, so
/// there is nothing to persist and no second source of truth. `null` means
/// "follow the primary currency".

abstract class _$PersonalStatsCurrencyNotifier extends $Notifier<Currency?> {
  Currency? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Currency?, Currency?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Currency?, Currency?>,
              Currency?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
