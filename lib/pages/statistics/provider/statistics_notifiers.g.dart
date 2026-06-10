// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_notifiers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single shared fetch per (group, month range). The member-totals,
/// category-totals and category-details providers all derive from this so
/// opening a month detail fires one database query instead of three.

@ProviderFor(monthExpenses)
final monthExpensesProvider = MonthExpensesFamily._();

/// Single shared fetch per (group, month range). The member-totals,
/// category-totals and category-details providers all derive from this so
/// opening a month detail fires one database query instead of three.

final class MonthExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          FutureOr<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $FutureProvider<List<Expense>> {
  /// Single shared fetch per (group, month range). The member-totals,
  /// category-totals and category-details providers all derive from this so
  /// opening a month detail fires one database query instead of three.
  MonthExpensesProvider._({
    required MonthExpensesFamily super.from,
    required (String, DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'monthExpensesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthExpensesHash();

  @override
  String toString() {
    return r'monthExpensesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Expense>> create(Ref ref) {
    final argument = this.argument as (String, DateTime, DateTime);
    return monthExpenses(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthExpensesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthExpensesHash() => r'a4bdfb6ee152037f0a45862540b999e8d2cd8c5b';

/// Single shared fetch per (group, month range). The member-totals,
/// category-totals and category-details providers all derive from this so
/// opening a month detail fires one database query instead of three.

final class MonthExpensesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Expense>>,
          (String, DateTime, DateTime)
        > {
  MonthExpensesFamily._()
    : super(
        retry: null,
        name: r'monthExpensesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Single shared fetch per (group, month range). The member-totals,
  /// category-totals and category-details providers all derive from this so
  /// opening a month detail fires one database query instead of three.

  MonthExpensesProvider call(
    String groupId,
    DateTime monthStart,
    DateTime monthEnd,
  ) => MonthExpensesProvider._(
    argument: (groupId, monthStart, monthEnd),
    from: this,
  );

  @override
  String toString() => r'monthExpensesProvider';
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
    r'341c58b8e72e6e73d256c813560e49e26caa99e2';

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
    r'0451cebbaf6bc57435d2d373b4c19cbd3b4ec8b1';

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
    r'a37fe8d56f344563239197492a21646f8514f7f0';

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
