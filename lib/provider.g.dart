// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
        isAutoDispose: true,
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
    r'c8bdf335185c10c7ea70a5c8270feec9bce9ae99';

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
    r'6c06d8ad30004e3c3fe17f06bb4d2296d3f9f775';

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
