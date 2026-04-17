// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_notifiers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupMonthlyTotalsNotifier)
final groupMonthlyTotalsProvider = GroupMonthlyTotalsNotifierFamily._();

final class GroupMonthlyTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthlyTotalsNotifier,
          GroupMonthlyTotalsState
        > {
  GroupMonthlyTotalsNotifierProvider._({
    required GroupMonthlyTotalsNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupMonthlyTotalsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupMonthlyTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthlyTotalsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupMonthlyTotalsNotifier create() => GroupMonthlyTotalsNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupMonthlyTotalsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupMonthlyTotalsNotifierHash() =>
    r'f8d7a0f44e02ecbaac1527419fdd1f8cbaca380c';

final class GroupMonthlyTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthlyTotalsNotifier,
          AsyncValue<GroupMonthlyTotalsState>,
          GroupMonthlyTotalsState,
          FutureOr<GroupMonthlyTotalsState>,
          String
        > {
  GroupMonthlyTotalsNotifierFamily._()
    : super(
        retry: null,
        name: r'groupMonthlyTotalsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupMonthlyTotalsNotifierProvider call(String groupId) =>
      GroupMonthlyTotalsNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupMonthlyTotalsProvider';
}

abstract class _$GroupMonthlyTotalsNotifier
    extends $AsyncNotifier<GroupMonthlyTotalsState> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<GroupMonthlyTotalsState> build(String groupId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<GroupMonthlyTotalsState>,
              GroupMonthlyTotalsState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<GroupMonthlyTotalsState>,
                GroupMonthlyTotalsState
              >,
              AsyncValue<GroupMonthlyTotalsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(GroupMonthMemberTotalsNotifier)
final groupMonthMemberTotalsProvider = GroupMonthMemberTotalsNotifierFamily._();

final class GroupMonthMemberTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthMemberTotalsNotifier,
          List<MemberMonthTotal>
        > {
  GroupMonthMemberTotalsNotifierProvider._({
    required GroupMonthMemberTotalsNotifierFamily super.from,
    required GroupMonthMemberTotalsArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupMonthMemberTotalsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupMonthMemberTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthMemberTotalsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupMonthMemberTotalsNotifier create() => GroupMonthMemberTotalsNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupMonthMemberTotalsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupMonthMemberTotalsNotifierHash() =>
    r'd55f3d930341f2ff82972a77b1697c28e43409b2';

final class GroupMonthMemberTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthMemberTotalsNotifier,
          AsyncValue<List<MemberMonthTotal>>,
          List<MemberMonthTotal>,
          FutureOr<List<MemberMonthTotal>>,
          GroupMonthMemberTotalsArgs
        > {
  GroupMonthMemberTotalsNotifierFamily._()
    : super(
        retry: null,
        name: r'groupMonthMemberTotalsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupMonthMemberTotalsNotifierProvider call(
    GroupMonthMemberTotalsArgs args,
  ) => GroupMonthMemberTotalsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'groupMonthMemberTotalsProvider';
}

abstract class _$GroupMonthMemberTotalsNotifier
    extends $AsyncNotifier<List<MemberMonthTotal>> {
  late final _$args = ref.$arg as GroupMonthMemberTotalsArgs;
  GroupMonthMemberTotalsArgs get args => _$args;

  FutureOr<List<MemberMonthTotal>> build(GroupMonthMemberTotalsArgs args);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<MemberMonthTotal>>, List<MemberMonthTotal>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MemberMonthTotal>>,
                List<MemberMonthTotal>
              >,
              AsyncValue<List<MemberMonthTotal>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(GroupMonthCategoryTotalsNotifier)
final groupMonthCategoryTotalsProvider =
    GroupMonthCategoryTotalsNotifierFamily._();

final class GroupMonthCategoryTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthCategoryTotalsNotifier,
          List<CategoryMonthTotal>
        > {
  GroupMonthCategoryTotalsNotifierProvider._({
    required GroupMonthCategoryTotalsNotifierFamily super.from,
    required GroupMonthCategoryTotalsArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupMonthCategoryTotalsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupMonthCategoryTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthCategoryTotalsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupMonthCategoryTotalsNotifier create() =>
      GroupMonthCategoryTotalsNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupMonthCategoryTotalsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupMonthCategoryTotalsNotifierHash() =>
    r'b023471cd4cda1891b5e2d1c6262021adc886bca';

final class GroupMonthCategoryTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthCategoryTotalsNotifier,
          AsyncValue<List<CategoryMonthTotal>>,
          List<CategoryMonthTotal>,
          FutureOr<List<CategoryMonthTotal>>,
          GroupMonthCategoryTotalsArgs
        > {
  GroupMonthCategoryTotalsNotifierFamily._()
    : super(
        retry: null,
        name: r'groupMonthCategoryTotalsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupMonthCategoryTotalsNotifierProvider call(
    GroupMonthCategoryTotalsArgs args,
  ) => GroupMonthCategoryTotalsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'groupMonthCategoryTotalsProvider';
}

abstract class _$GroupMonthCategoryTotalsNotifier
    extends $AsyncNotifier<List<CategoryMonthTotal>> {
  late final _$args = ref.$arg as GroupMonthCategoryTotalsArgs;
  GroupMonthCategoryTotalsArgs get args => _$args;

  FutureOr<List<CategoryMonthTotal>> build(GroupMonthCategoryTotalsArgs args);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CategoryMonthTotal>>,
              List<CategoryMonthTotal>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CategoryMonthTotal>>,
                List<CategoryMonthTotal>
              >,
              AsyncValue<List<CategoryMonthTotal>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(CategoryExpenseDetailsNotifier)
final categoryExpenseDetailsProvider = CategoryExpenseDetailsNotifierFamily._();

final class CategoryExpenseDetailsNotifierProvider
    extends
        $AsyncNotifierProvider<
          CategoryExpenseDetailsNotifier,
          List<CategoryExpenseDetail>
        > {
  CategoryExpenseDetailsNotifierProvider._({
    required CategoryExpenseDetailsNotifierFamily super.from,
    required CategoryExpenseDetailsArgs super.argument,
  }) : super(
         retry: null,
         name: r'categoryExpenseDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$categoryExpenseDetailsNotifierHash();

  @override
  String toString() {
    return r'categoryExpenseDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CategoryExpenseDetailsNotifier create() => CategoryExpenseDetailsNotifier();

  @override
  bool operator ==(Object other) {
    return other is CategoryExpenseDetailsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$categoryExpenseDetailsNotifierHash() =>
    r'a8b767dcd6d872aa2e4c06ce33eef8534e6c68ac';

final class CategoryExpenseDetailsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CategoryExpenseDetailsNotifier,
          AsyncValue<List<CategoryExpenseDetail>>,
          List<CategoryExpenseDetail>,
          FutureOr<List<CategoryExpenseDetail>>,
          CategoryExpenseDetailsArgs
        > {
  CategoryExpenseDetailsNotifierFamily._()
    : super(
        retry: null,
        name: r'categoryExpenseDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CategoryExpenseDetailsNotifierProvider call(
    CategoryExpenseDetailsArgs args,
  ) => CategoryExpenseDetailsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'categoryExpenseDetailsProvider';
}

abstract class _$CategoryExpenseDetailsNotifier
    extends $AsyncNotifier<List<CategoryExpenseDetail>> {
  late final _$args = ref.$arg as CategoryExpenseDetailsArgs;
  CategoryExpenseDetailsArgs get args => _$args;

  FutureOr<List<CategoryExpenseDetail>> build(CategoryExpenseDetailsArgs args);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CategoryExpenseDetail>>,
              List<CategoryExpenseDetail>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CategoryExpenseDetail>>,
                List<CategoryExpenseDetail>
              >,
              AsyncValue<List<CategoryExpenseDetail>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(GroupRangeDataNotifier)
final groupRangeDataProvider = GroupRangeDataNotifierFamily._();

final class GroupRangeDataNotifierProvider
    extends $AsyncNotifierProvider<GroupRangeDataNotifier, GroupRangeData> {
  GroupRangeDataNotifierProvider._({
    required GroupRangeDataNotifierFamily super.from,
    required StatsRangeArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupRangeDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupRangeDataNotifierHash();

  @override
  String toString() {
    return r'groupRangeDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupRangeDataNotifier create() => GroupRangeDataNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupRangeDataNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupRangeDataNotifierHash() =>
    r'7a13e6ffd91bbb0a649b7069b76e9789585c72f4';

final class GroupRangeDataNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupRangeDataNotifier,
          AsyncValue<GroupRangeData>,
          GroupRangeData,
          FutureOr<GroupRangeData>,
          StatsRangeArgs
        > {
  GroupRangeDataNotifierFamily._()
    : super(
        retry: null,
        name: r'groupRangeDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupRangeDataNotifierProvider call(StatsRangeArgs args) =>
      GroupRangeDataNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'groupRangeDataProvider';
}

abstract class _$GroupRangeDataNotifier extends $AsyncNotifier<GroupRangeData> {
  late final _$args = ref.$arg as StatsRangeArgs;
  StatsRangeArgs get args => _$args;

  FutureOr<GroupRangeData> build(StatsRangeArgs args);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<GroupRangeData>, GroupRangeData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GroupRangeData>, GroupRangeData>,
              AsyncValue<GroupRangeData>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(groupSpendingSummary)
final groupSpendingSummaryProvider = GroupSpendingSummaryFamily._();

final class GroupSpendingSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SpendingSummary>,
          SpendingSummary,
          FutureOr<SpendingSummary>
        >
    with $FutureModifier<SpendingSummary>, $FutureProvider<SpendingSummary> {
  GroupSpendingSummaryProvider._({
    required GroupSpendingSummaryFamily super.from,
    required StatsRangeArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupSpendingSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupSpendingSummaryHash();

  @override
  String toString() {
    return r'groupSpendingSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SpendingSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SpendingSummary> create(Ref ref) {
    final argument = this.argument as StatsRangeArgs;
    return groupSpendingSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupSpendingSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupSpendingSummaryHash() =>
    r'2a9ac1276696921b9b61556192900d38b6060af1';

final class GroupSpendingSummaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SpendingSummary>, StatsRangeArgs> {
  GroupSpendingSummaryFamily._()
    : super(
        retry: null,
        name: r'groupSpendingSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupSpendingSummaryProvider call(StatsRangeArgs args) =>
      GroupSpendingSummaryProvider._(argument: args, from: this);

  @override
  String toString() => r'groupSpendingSummaryProvider';
}

@ProviderFor(groupTrend)
final groupTrendProvider = GroupTrendFamily._();

final class GroupTrendProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MonthBucket>>,
          List<MonthBucket>,
          FutureOr<List<MonthBucket>>
        >
    with
        $FutureModifier<List<MonthBucket>>,
        $FutureProvider<List<MonthBucket>> {
  GroupTrendProvider._({
    required GroupTrendFamily super.from,
    required StatsRangeArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupTrendProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupTrendHash();

  @override
  String toString() {
    return r'groupTrendProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MonthBucket>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MonthBucket>> create(Ref ref) {
    final argument = this.argument as StatsRangeArgs;
    return groupTrend(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupTrendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupTrendHash() => r'ddd15b6ce19c3e51f4bf44f3589a603dd2572516';

final class GroupTrendFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<MonthBucket>>, StatsRangeArgs> {
  GroupTrendFamily._()
    : super(
        retry: null,
        name: r'groupTrendProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupTrendProvider call(StatsRangeArgs args) =>
      GroupTrendProvider._(argument: args, from: this);

  @override
  String toString() => r'groupTrendProvider';
}

@ProviderFor(groupMemberBreakdown)
final groupMemberBreakdownProvider = GroupMemberBreakdownFamily._();

final class GroupMemberBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemberSpendingBreakdown>>,
          List<MemberSpendingBreakdown>,
          FutureOr<List<MemberSpendingBreakdown>>
        >
    with
        $FutureModifier<List<MemberSpendingBreakdown>>,
        $FutureProvider<List<MemberSpendingBreakdown>> {
  GroupMemberBreakdownProvider._({
    required GroupMemberBreakdownFamily super.from,
    required StatsRangeArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupMemberBreakdownProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupMemberBreakdownHash();

  @override
  String toString() {
    return r'groupMemberBreakdownProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MemberSpendingBreakdown>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemberSpendingBreakdown>> create(Ref ref) {
    final argument = this.argument as StatsRangeArgs;
    return groupMemberBreakdown(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupMemberBreakdownProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupMemberBreakdownHash() =>
    r'a0c470ec8a1c7127e153c096c9ae3fcae96aed6e';

final class GroupMemberBreakdownFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MemberSpendingBreakdown>>,
          StatsRangeArgs
        > {
  GroupMemberBreakdownFamily._()
    : super(
        retry: null,
        name: r'groupMemberBreakdownProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupMemberBreakdownProvider call(StatsRangeArgs args) =>
      GroupMemberBreakdownProvider._(argument: args, from: this);

  @override
  String toString() => r'groupMemberBreakdownProvider';
}

@ProviderFor(groupCategoryBreakdown)
final groupCategoryBreakdownProvider = GroupCategoryBreakdownFamily._();

final class GroupCategoryBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CategoryMonthTotal>>,
          List<CategoryMonthTotal>,
          FutureOr<List<CategoryMonthTotal>>
        >
    with
        $FutureModifier<List<CategoryMonthTotal>>,
        $FutureProvider<List<CategoryMonthTotal>> {
  GroupCategoryBreakdownProvider._({
    required GroupCategoryBreakdownFamily super.from,
    required StatsRangeArgs super.argument,
  }) : super(
         retry: null,
         name: r'groupCategoryBreakdownProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupCategoryBreakdownHash();

  @override
  String toString() {
    return r'groupCategoryBreakdownProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CategoryMonthTotal>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategoryMonthTotal>> create(Ref ref) {
    final argument = this.argument as StatsRangeArgs;
    return groupCategoryBreakdown(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupCategoryBreakdownProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupCategoryBreakdownHash() =>
    r'53b6961c1bfc4470cfaf77a56351f526c311ecb9';

final class GroupCategoryBreakdownFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<CategoryMonthTotal>>,
          StatsRangeArgs
        > {
  GroupCategoryBreakdownFamily._()
    : super(
        retry: null,
        name: r'groupCategoryBreakdownProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupCategoryBreakdownProvider call(StatsRangeArgs args) =>
      GroupCategoryBreakdownProvider._(argument: args, from: this);

  @override
  String toString() => r'groupCategoryBreakdownProvider';
}
