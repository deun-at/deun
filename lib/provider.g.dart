// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupListNotifier)
const groupListProvider = GroupListNotifierFamily._();

final class GroupListNotifierProvider
    extends $AsyncNotifierProvider<GroupListNotifier, List<Group>> {
  const GroupListNotifierProvider._({
    required GroupListNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupListNotifierHash();

  @override
  String toString() {
    return r'groupListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupListNotifier create() => GroupListNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupListNotifierHash() => r'21a304dec9018e06b58570ae9e91d15cc9f2064a';

final class GroupListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupListNotifier,
          AsyncValue<List<Group>>,
          List<Group>,
          FutureOr<List<Group>>,
          String
        > {
  const GroupListNotifierFamily._()
    : super(
        retry: null,
        name: r'groupListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupListNotifierProvider call(String statusFilter) =>
      GroupListNotifierProvider._(argument: statusFilter, from: this);

  @override
  String toString() => r'groupListProvider';
}

abstract class _$GroupListNotifier extends $AsyncNotifier<List<Group>> {
  late final _$args = ref.$arg as String;
  String get statusFilter => _$args;

  FutureOr<List<Group>> build(String statusFilter);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<List<Group>>, List<Group>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Group>>, List<Group>>,
              AsyncValue<List<Group>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupDetailNotifier)
const groupDetailProvider = GroupDetailNotifierFamily._();

final class GroupDetailNotifierProvider
    extends $AsyncNotifierProvider<GroupDetailNotifier, Group> {
  const GroupDetailNotifierProvider._({
    required GroupDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupDetailNotifierHash();

  @override
  String toString() {
    return r'groupDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupDetailNotifier create() => GroupDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is GroupDetailNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupDetailNotifierHash() =>
    r'0bd56d6afff29b9389b3398971cd1aed2efe8383';

final class GroupDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupDetailNotifier,
          AsyncValue<Group>,
          Group,
          FutureOr<Group>,
          String
        > {
  const GroupDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'groupDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GroupDetailNotifierProvider call(String groupId) =>
      GroupDetailNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupDetailProvider';
}

abstract class _$GroupDetailNotifier extends $AsyncNotifier<Group> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<Group> build(String groupId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<Group>, Group>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Group>, Group>,
              AsyncValue<Group>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ExpenseListNotifier)
const expenseListProvider = ExpenseListNotifierFamily._();

final class ExpenseListNotifierProvider
    extends $AsyncNotifierProvider<ExpenseListNotifier, List<Expense>> {
  const ExpenseListNotifierProvider._({
    required ExpenseListNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseListNotifierHash();

  @override
  String toString() {
    return r'expenseListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ExpenseListNotifier create() => ExpenseListNotifier();

  @override
  bool operator ==(Object other) {
    return other is ExpenseListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseListNotifierHash() =>
    r'd940d04db39e5ee1166d19717b184fba7a8d2cbf';

final class ExpenseListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ExpenseListNotifier,
          AsyncValue<List<Expense>>,
          List<Expense>,
          FutureOr<List<Expense>>,
          String
        > {
  const ExpenseListNotifierFamily._()
    : super(
        retry: null,
        name: r'expenseListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpenseListNotifierProvider call(String groupId) =>
      ExpenseListNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'expenseListProvider';
}

abstract class _$ExpenseListNotifier extends $AsyncNotifier<List<Expense>> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<List<Expense>> build(String groupId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<List<Expense>>, List<Expense>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Expense>>, List<Expense>>,
              AsyncValue<List<Expense>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(FriendshipListNotifier)
const friendshipListProvider = FriendshipListNotifierProvider._();

final class FriendshipListNotifierProvider
    extends $AsyncNotifierProvider<FriendshipListNotifier, List<Friendship>> {
  const FriendshipListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'friendshipListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$friendshipListNotifierHash();

  @$internal
  @override
  FriendshipListNotifier create() => FriendshipListNotifier();
}

String _$friendshipListNotifierHash() =>
    r'98fa8b7b5dcabc1704ae2c0653d1f0ae383b6645';

abstract class _$FriendshipListNotifier
    extends $AsyncNotifier<List<Friendship>> {
  FutureOr<List<Friendship>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<Friendship>>, List<Friendship>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Friendship>>, List<Friendship>>,
              AsyncValue<List<Friendship>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(FriendshipDetailNotifier)
const friendshipDetailProvider = FriendshipDetailNotifierFamily._();

final class FriendshipDetailNotifierProvider
    extends $AsyncNotifierProvider<FriendshipDetailNotifier, Friendship> {
  const FriendshipDetailNotifierProvider._({
    required FriendshipDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'friendshipDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$friendshipDetailNotifierHash();

  @override
  String toString() {
    return r'friendshipDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FriendshipDetailNotifier create() => FriendshipDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is FriendshipDetailNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$friendshipDetailNotifierHash() =>
    r'9bea82c9be1fd123e7a3d773ea57fda328e2e8f7';

final class FriendshipDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          FriendshipDetailNotifier,
          AsyncValue<Friendship>,
          Friendship,
          FutureOr<Friendship>,
          String
        > {
  const FriendshipDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'friendshipDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FriendshipDetailNotifierProvider call(String email) =>
      FriendshipDetailNotifierProvider._(argument: email, from: this);

  @override
  String toString() => r'friendshipDetailProvider';
}

abstract class _$FriendshipDetailNotifier extends $AsyncNotifier<Friendship> {
  late final _$args = ref.$arg as String;
  String get email => _$args;

  FutureOr<Friendship> build(String email);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<Friendship>, Friendship>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Friendship>, Friendship>,
              AsyncValue<Friendship>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(UserDetailNotifier)
const userDetailProvider = UserDetailNotifierProvider._();

final class UserDetailNotifierProvider
    extends $AsyncNotifierProvider<UserDetailNotifier, SupaUser> {
  const UserDetailNotifierProvider._()
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
    r'7e551e2977cefd6d121644b606288a205e6445d7';

abstract class _$UserDetailNotifier extends $AsyncNotifier<SupaUser> {
  FutureOr<SupaUser> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<SupaUser>, SupaUser>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SupaUser>, SupaUser>,
              AsyncValue<SupaUser>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(LocaleNotifier)
const localeProvider = LocaleNotifierProvider._();

final class LocaleNotifierProvider
    extends $NotifierProvider<LocaleNotifier, Locale?> {
  const LocaleNotifierProvider._()
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
    final created = build();
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthlyTotalsNotifier)
const groupMonthlyTotalsProvider = GroupMonthlyTotalsNotifierFamily._();

final class GroupMonthlyTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthlyTotalsNotifier,
          GroupMonthlyTotalsState
        > {
  const GroupMonthlyTotalsNotifierProvider._({
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
    r'c122b417d05c3cfedb425aff18f3e944086bd18a';

final class GroupMonthlyTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthlyTotalsNotifier,
          AsyncValue<GroupMonthlyTotalsState>,
          GroupMonthlyTotalsState,
          FutureOr<GroupMonthlyTotalsState>,
          String
        > {
  const GroupMonthlyTotalsNotifierFamily._()
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
    final created = build(_$args);
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
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthMemberTotalsNotifier)
const groupMonthMemberTotalsProvider = GroupMonthMemberTotalsNotifierFamily._();

final class GroupMonthMemberTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthMemberTotalsNotifier,
          List<MemberMonthTotal>
        > {
  const GroupMonthMemberTotalsNotifierProvider._({
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
    r'ec2a4d5864fd1376cf358db9b7ada2f89104b870';

final class GroupMonthMemberTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthMemberTotalsNotifier,
          AsyncValue<List<MemberMonthTotal>>,
          List<MemberMonthTotal>,
          FutureOr<List<MemberMonthTotal>>,
          GroupMonthMemberTotalsArgs
        > {
  const GroupMonthMemberTotalsNotifierFamily._()
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
    final created = build(_$args);
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
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthCategoryTotalsNotifier)
const groupMonthCategoryTotalsProvider =
    GroupMonthCategoryTotalsNotifierFamily._();

final class GroupMonthCategoryTotalsNotifierProvider
    extends
        $AsyncNotifierProvider<
          GroupMonthCategoryTotalsNotifier,
          List<CategoryMonthTotal>
        > {
  const GroupMonthCategoryTotalsNotifierProvider._({
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
    r'774d3310017b5e2cfe5efead4a6889b160ad63d1';

final class GroupMonthCategoryTotalsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupMonthCategoryTotalsNotifier,
          AsyncValue<List<CategoryMonthTotal>>,
          List<CategoryMonthTotal>,
          FutureOr<List<CategoryMonthTotal>>,
          GroupMonthCategoryTotalsArgs
        > {
  const GroupMonthCategoryTotalsNotifierFamily._()
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
    final created = build(_$args);
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
    element.handleValue(ref, created);
  }
}

@ProviderFor(CategoryExpenseDetailsNotifier)
const categoryExpenseDetailsProvider = CategoryExpenseDetailsNotifierFamily._();

final class CategoryExpenseDetailsNotifierProvider
    extends
        $AsyncNotifierProvider<
          CategoryExpenseDetailsNotifier,
          List<CategoryExpenseDetail>
        > {
  const CategoryExpenseDetailsNotifierProvider._({
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
    r'ffff35936b8d514d5980ed453c57f126aeec19be';

final class CategoryExpenseDetailsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CategoryExpenseDetailsNotifier,
          AsyncValue<List<CategoryExpenseDetail>>,
          List<CategoryExpenseDetail>,
          FutureOr<List<CategoryExpenseDetail>>,
          CategoryExpenseDetailsArgs
        > {
  const CategoryExpenseDetailsNotifierFamily._()
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
    final created = build(_$args);
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
    element.handleValue(ref, created);
  }
}
