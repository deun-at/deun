// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(GroupListNotifier)
const groupListNotifierProvider = GroupListNotifierFamily._();

final class GroupListNotifierProvider
    extends $AsyncNotifierProvider<GroupListNotifier, List<Group>> {
  const GroupListNotifierProvider._(
      {required GroupListNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'groupListNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupListNotifierHash();

  @override
  String toString() {
    return r'groupListNotifierProvider'
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

String _$groupListNotifierHash() => r'deb99cdeb12b236dfaaa4cbb7d7546a460f28b79';

final class GroupListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<GroupListNotifier, AsyncValue<List<Group>>,
            List<Group>, FutureOr<List<Group>>, String> {
  const GroupListNotifierFamily._()
      : super(
          retry: null,
          name: r'groupListNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupListNotifierProvider call(
    String statusFilter,
  ) =>
      GroupListNotifierProvider._(argument: statusFilter, from: this);

  @override
  String toString() => r'groupListNotifierProvider';
}

abstract class _$GroupListNotifier extends $AsyncNotifier<List<Group>> {
  late final _$args = ref.$arg as String;
  String get statusFilter => _$args;

  FutureOr<List<Group>> build(
    String statusFilter,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<AsyncValue<List<Group>>, List<Group>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<Group>>, List<Group>>,
        AsyncValue<List<Group>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupDetailNotifier)
const groupDetailNotifierProvider = GroupDetailNotifierFamily._();

final class GroupDetailNotifierProvider
    extends $AsyncNotifierProvider<GroupDetailNotifier, Group> {
  const GroupDetailNotifierProvider._(
      {required GroupDetailNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'groupDetailNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupDetailNotifierHash();

  @override
  String toString() {
    return r'groupDetailNotifierProvider'
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
    r'45fe0a2c5c3065ba01a82d18e4f81e22ceb8f304';

final class GroupDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<GroupDetailNotifier, AsyncValue<Group>, Group,
            FutureOr<Group>, String> {
  const GroupDetailNotifierFamily._()
      : super(
          retry: null,
          name: r'groupDetailNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupDetailNotifierProvider call(
    String groupId,
  ) =>
      GroupDetailNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupDetailNotifierProvider';
}

abstract class _$GroupDetailNotifier extends $AsyncNotifier<Group> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<Group> build(
    String groupId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<AsyncValue<Group>, Group>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Group>, Group>,
        AsyncValue<Group>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ExpenseListNotifier)
const expenseListNotifierProvider = ExpenseListNotifierFamily._();

final class ExpenseListNotifierProvider
    extends $AsyncNotifierProvider<ExpenseListNotifier, List<Expense>> {
  const ExpenseListNotifierProvider._(
      {required ExpenseListNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'expenseListNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expenseListNotifierHash();

  @override
  String toString() {
    return r'expenseListNotifierProvider'
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
    r'bb2328de7de7e29da3e4373c14cf843f3c9d9327';

final class ExpenseListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<ExpenseListNotifier, AsyncValue<List<Expense>>,
            List<Expense>, FutureOr<List<Expense>>, String> {
  const ExpenseListNotifierFamily._()
      : super(
          retry: null,
          name: r'expenseListNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ExpenseListNotifierProvider call(
    String groupId,
  ) =>
      ExpenseListNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'expenseListNotifierProvider';
}

abstract class _$ExpenseListNotifier extends $AsyncNotifier<List<Expense>> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<List<Expense>> build(
    String groupId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<AsyncValue<List<Expense>>, List<Expense>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<Expense>>, List<Expense>>,
        AsyncValue<List<Expense>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(expenseList)
const expenseListProvider = ExpenseListProvider._();

final class ExpenseListProvider extends $FunctionalProvider<
        AsyncValue<List<Expense>>, List<Expense>, FutureOr<List<Expense>>>
    with $FutureModifier<List<Expense>>, $FutureProvider<List<Expense>> {
  const ExpenseListProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'expenseListProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expenseListHash();

  @$internal
  @override
  $FutureProviderElement<List<Expense>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Expense>> create(Ref ref) {
    return expenseList(ref);
  }
}

String _$expenseListHash() => r'00dca8aef60e04c10e83bf68f036038277de8956';

@ProviderFor(FriendshipListNotifier)
const friendshipListNotifierProvider = FriendshipListNotifierProvider._();

final class FriendshipListNotifierProvider
    extends $AsyncNotifierProvider<FriendshipListNotifier, List<Friendship>> {
  const FriendshipListNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'friendshipListNotifierProvider',
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
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<Friendship>>, List<Friendship>>,
        AsyncValue<List<Friendship>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(FriendshipDetailNotifier)
const friendshipDetailNotifierProvider = FriendshipDetailNotifierFamily._();

final class FriendshipDetailNotifierProvider
    extends $AsyncNotifierProvider<FriendshipDetailNotifier, Friendship> {
  const FriendshipDetailNotifierProvider._(
      {required FriendshipDetailNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'friendshipDetailNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$friendshipDetailNotifierHash();

  @override
  String toString() {
    return r'friendshipDetailNotifierProvider'
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
        $ClassFamilyOverride<FriendshipDetailNotifier, AsyncValue<Friendship>,
            Friendship, FutureOr<Friendship>, String> {
  const FriendshipDetailNotifierFamily._()
      : super(
          retry: null,
          name: r'friendshipDetailNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  FriendshipDetailNotifierProvider call(
    String email,
  ) =>
      FriendshipDetailNotifierProvider._(argument: email, from: this);

  @override
  String toString() => r'friendshipDetailNotifierProvider';
}

abstract class _$FriendshipDetailNotifier extends $AsyncNotifier<Friendship> {
  late final _$args = ref.$arg as String;
  String get email => _$args;

  FutureOr<Friendship> build(
    String email,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<AsyncValue<Friendship>, Friendship>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<Friendship>, Friendship>,
        AsyncValue<Friendship>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(UserDetailNotifier)
const userDetailNotifierProvider = UserDetailNotifierProvider._();

final class UserDetailNotifierProvider
    extends $AsyncNotifierProvider<UserDetailNotifier, user_model.User> {
  const UserDetailNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'userDetailNotifierProvider',
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
    r'c09c8559275cc9173c125d0a21bc9d2e24e80467';

abstract class _$UserDetailNotifier extends $AsyncNotifier<user_model.User> {
  FutureOr<user_model.User> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<user_model.User>, user_model.User>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<user_model.User>, user_model.User>,
        AsyncValue<user_model.User>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ThemeColor)
const themeColorProvider = ThemeColorProvider._();

final class ThemeColorProvider extends $NotifierProvider<ThemeColor, Color> {
  const ThemeColorProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themeColorProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themeColorHash();

  @$internal
  @override
  ThemeColor create() => ThemeColor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Color value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Color>(value),
    );
  }
}

String _$themeColorHash() => r'98cc6f9878defc73ab82ff40763299c45a5086ce';

abstract class _$ThemeColor extends $Notifier<Color> {
  Color build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Color, Color>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Color, Color>, Color, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(LocaleNotifier)
const localeNotifierProvider = LocaleNotifierProvider._();

final class LocaleNotifierProvider
    extends $NotifierProvider<LocaleNotifier, Locale?> {
  const LocaleNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localeNotifierProvider',
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
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Locale?, Locale?>, Locale?, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthlyTotalsNotifier)
const groupMonthlyTotalsNotifierProvider = GroupMonthlyTotalsNotifierFamily._();

final class GroupMonthlyTotalsNotifierProvider extends $AsyncNotifierProvider<
    GroupMonthlyTotalsNotifier, GroupMonthlyTotalsState> {
  const GroupMonthlyTotalsNotifierProvider._(
      {required GroupMonthlyTotalsNotifierFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'groupMonthlyTotalsNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupMonthlyTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthlyTotalsNotifierProvider'
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
            String> {
  const GroupMonthlyTotalsNotifierFamily._()
      : super(
          retry: null,
          name: r'groupMonthlyTotalsNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupMonthlyTotalsNotifierProvider call(
    String groupId,
  ) =>
      GroupMonthlyTotalsNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupMonthlyTotalsNotifierProvider';
}

abstract class _$GroupMonthlyTotalsNotifier
    extends $AsyncNotifier<GroupMonthlyTotalsState> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  FutureOr<GroupMonthlyTotalsState> build(
    String groupId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref
        as $Ref<AsyncValue<GroupMonthlyTotalsState>, GroupMonthlyTotalsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<GroupMonthlyTotalsState>,
            GroupMonthlyTotalsState>,
        AsyncValue<GroupMonthlyTotalsState>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthMemberTotalsNotifier)
const groupMonthMemberTotalsNotifierProvider =
    GroupMonthMemberTotalsNotifierFamily._();

final class GroupMonthMemberTotalsNotifierProvider
    extends $AsyncNotifierProvider<GroupMonthMemberTotalsNotifier,
        List<MemberMonthTotal>> {
  const GroupMonthMemberTotalsNotifierProvider._(
      {required GroupMonthMemberTotalsNotifierFamily super.from,
      required GroupMonthMemberTotalsArgs super.argument})
      : super(
          retry: null,
          name: r'groupMonthMemberTotalsNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupMonthMemberTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthMemberTotalsNotifierProvider'
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
            GroupMonthMemberTotalsArgs> {
  const GroupMonthMemberTotalsNotifierFamily._()
      : super(
          retry: null,
          name: r'groupMonthMemberTotalsNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupMonthMemberTotalsNotifierProvider call(
    GroupMonthMemberTotalsArgs args,
  ) =>
      GroupMonthMemberTotalsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'groupMonthMemberTotalsNotifierProvider';
}

abstract class _$GroupMonthMemberTotalsNotifier
    extends $AsyncNotifier<List<MemberMonthTotal>> {
  late final _$args = ref.$arg as GroupMonthMemberTotalsArgs;
  GroupMonthMemberTotalsArgs get args => _$args;

  FutureOr<List<MemberMonthTotal>> build(
    GroupMonthMemberTotalsArgs args,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref
        as $Ref<AsyncValue<List<MemberMonthTotal>>, List<MemberMonthTotal>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<MemberMonthTotal>>, List<MemberMonthTotal>>,
        AsyncValue<List<MemberMonthTotal>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(GroupMonthCategoryTotalsNotifier)
const groupMonthCategoryTotalsNotifierProvider =
    GroupMonthCategoryTotalsNotifierFamily._();

final class GroupMonthCategoryTotalsNotifierProvider
    extends $AsyncNotifierProvider<GroupMonthCategoryTotalsNotifier,
        List<CategoryMonthTotal>> {
  const GroupMonthCategoryTotalsNotifierProvider._(
      {required GroupMonthCategoryTotalsNotifierFamily super.from,
      required GroupMonthCategoryTotalsArgs super.argument})
      : super(
          retry: null,
          name: r'groupMonthCategoryTotalsNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupMonthCategoryTotalsNotifierHash();

  @override
  String toString() {
    return r'groupMonthCategoryTotalsNotifierProvider'
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
            GroupMonthCategoryTotalsArgs> {
  const GroupMonthCategoryTotalsNotifierFamily._()
      : super(
          retry: null,
          name: r'groupMonthCategoryTotalsNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupMonthCategoryTotalsNotifierProvider call(
    GroupMonthCategoryTotalsArgs args,
  ) =>
      GroupMonthCategoryTotalsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'groupMonthCategoryTotalsNotifierProvider';
}

abstract class _$GroupMonthCategoryTotalsNotifier
    extends $AsyncNotifier<List<CategoryMonthTotal>> {
  late final _$args = ref.$arg as GroupMonthCategoryTotalsArgs;
  GroupMonthCategoryTotalsArgs get args => _$args;

  FutureOr<List<CategoryMonthTotal>> build(
    GroupMonthCategoryTotalsArgs args,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref
        as $Ref<AsyncValue<List<CategoryMonthTotal>>, List<CategoryMonthTotal>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<CategoryMonthTotal>>,
            List<CategoryMonthTotal>>,
        AsyncValue<List<CategoryMonthTotal>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CategoryExpenseDetailsNotifier)
const categoryExpenseDetailsNotifierProvider =
    CategoryExpenseDetailsNotifierFamily._();

final class CategoryExpenseDetailsNotifierProvider
    extends $AsyncNotifierProvider<CategoryExpenseDetailsNotifier,
        List<CategoryExpenseDetail>> {
  const CategoryExpenseDetailsNotifierProvider._(
      {required CategoryExpenseDetailsNotifierFamily super.from,
      required CategoryExpenseDetailsArgs super.argument})
      : super(
          retry: null,
          name: r'categoryExpenseDetailsNotifierProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$categoryExpenseDetailsNotifierHash();

  @override
  String toString() {
    return r'categoryExpenseDetailsNotifierProvider'
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
    r'650441b46e73be35d40f2f11f81a8eb177afb316';

final class CategoryExpenseDetailsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
            CategoryExpenseDetailsNotifier,
            AsyncValue<List<CategoryExpenseDetail>>,
            List<CategoryExpenseDetail>,
            FutureOr<List<CategoryExpenseDetail>>,
            CategoryExpenseDetailsArgs> {
  const CategoryExpenseDetailsNotifierFamily._()
      : super(
          retry: null,
          name: r'categoryExpenseDetailsNotifierProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  CategoryExpenseDetailsNotifierProvider call(
    CategoryExpenseDetailsArgs args,
  ) =>
      CategoryExpenseDetailsNotifierProvider._(argument: args, from: this);

  @override
  String toString() => r'categoryExpenseDetailsNotifierProvider';
}

abstract class _$CategoryExpenseDetailsNotifier
    extends $AsyncNotifier<List<CategoryExpenseDetail>> {
  late final _$args = ref.$arg as CategoryExpenseDetailsArgs;
  CategoryExpenseDetailsArgs get args => _$args;

  FutureOr<List<CategoryExpenseDetail>> build(
    CategoryExpenseDetailsArgs args,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<AsyncValue<List<CategoryExpenseDetail>>,
        List<CategoryExpenseDetail>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<CategoryExpenseDetail>>,
            List<CategoryExpenseDetail>>,
        AsyncValue<List<CategoryExpenseDetail>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
