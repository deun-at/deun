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
    r'cc1490a360707e6a99baadc6744bfaa3bb3276bb';

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
