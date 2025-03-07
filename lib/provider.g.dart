// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$expenseListHash() => r'00dca8aef60e04c10e83bf68f036038277de8956';

/// See also [expenseList].
@ProviderFor(expenseList)
final expenseListProvider = AutoDisposeFutureProvider<List<Expense>>.internal(
  expenseList,
  name: r'expenseListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$expenseListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExpenseListRef = AutoDisposeFutureProviderRef<List<Expense>>;
String _$groupListNotifierHash() => r'1bc29dbbcaaad4a2bdd79fd070f4d64977ac2c84';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$GroupListNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<Group>> {
  late final String statusFilter;

  FutureOr<List<Group>> build(
    String statusFilter,
  );
}

/// See also [GroupListNotifier].
@ProviderFor(GroupListNotifier)
const groupListNotifierProvider = GroupListNotifierFamily();

/// See also [GroupListNotifier].
class GroupListNotifierFamily extends Family<AsyncValue<List<Group>>> {
  /// See also [GroupListNotifier].
  const GroupListNotifierFamily();

  /// See also [GroupListNotifier].
  GroupListNotifierProvider call(
    String statusFilter,
  ) {
    return GroupListNotifierProvider(
      statusFilter,
    );
  }

  @override
  GroupListNotifierProvider getProviderOverride(
    covariant GroupListNotifierProvider provider,
  ) {
    return call(
      provider.statusFilter,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupListNotifierProvider';
}

/// See also [GroupListNotifier].
class GroupListNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    GroupListNotifier, List<Group>> {
  /// See also [GroupListNotifier].
  GroupListNotifierProvider(
    String statusFilter,
  ) : this._internal(
          () => GroupListNotifier()..statusFilter = statusFilter,
          from: groupListNotifierProvider,
          name: r'groupListNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$groupListNotifierHash,
          dependencies: GroupListNotifierFamily._dependencies,
          allTransitiveDependencies:
              GroupListNotifierFamily._allTransitiveDependencies,
          statusFilter: statusFilter,
        );

  GroupListNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.statusFilter,
  }) : super.internal();

  final String statusFilter;

  @override
  FutureOr<List<Group>> runNotifierBuild(
    covariant GroupListNotifier notifier,
  ) {
    return notifier.build(
      statusFilter,
    );
  }

  @override
  Override overrideWith(GroupListNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GroupListNotifierProvider._internal(
        () => create()..statusFilter = statusFilter,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        statusFilter: statusFilter,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<GroupListNotifier, List<Group>>
      createElement() {
    return _GroupListNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupListNotifierProvider &&
        other.statusFilter == statusFilter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, statusFilter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupListNotifierRef on AutoDisposeAsyncNotifierProviderRef<List<Group>> {
  /// The parameter `statusFilter` of this provider.
  String get statusFilter;
}

class _GroupListNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GroupListNotifier,
        List<Group>> with GroupListNotifierRef {
  _GroupListNotifierProviderElement(super.provider);

  @override
  String get statusFilter => (origin as GroupListNotifierProvider).statusFilter;
}

String _$groupDetailNotifierHash() =>
    r'4a51f1930db65d2bce87dd5996f6ca4e745a4a65';

abstract class _$GroupDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Group> {
  late final String groupId;

  FutureOr<Group> build(
    String groupId,
  );
}

/// See also [GroupDetailNotifier].
@ProviderFor(GroupDetailNotifier)
const groupDetailNotifierProvider = GroupDetailNotifierFamily();

/// See also [GroupDetailNotifier].
class GroupDetailNotifierFamily extends Family<AsyncValue<Group>> {
  /// See also [GroupDetailNotifier].
  const GroupDetailNotifierFamily();

  /// See also [GroupDetailNotifier].
  GroupDetailNotifierProvider call(
    String groupId,
  ) {
    return GroupDetailNotifierProvider(
      groupId,
    );
  }

  @override
  GroupDetailNotifierProvider getProviderOverride(
    covariant GroupDetailNotifierProvider provider,
  ) {
    return call(
      provider.groupId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupDetailNotifierProvider';
}

/// See also [GroupDetailNotifier].
class GroupDetailNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<GroupDetailNotifier, Group> {
  /// See also [GroupDetailNotifier].
  GroupDetailNotifierProvider(
    String groupId,
  ) : this._internal(
          () => GroupDetailNotifier()..groupId = groupId,
          from: groupDetailNotifierProvider,
          name: r'groupDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$groupDetailNotifierHash,
          dependencies: GroupDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              GroupDetailNotifierFamily._allTransitiveDependencies,
          groupId: groupId,
        );

  GroupDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  FutureOr<Group> runNotifierBuild(
    covariant GroupDetailNotifier notifier,
  ) {
    return notifier.build(
      groupId,
    );
  }

  @override
  Override overrideWith(GroupDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: GroupDetailNotifierProvider._internal(
        () => create()..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<GroupDetailNotifier, Group>
      createElement() {
    return _GroupDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupDetailNotifierProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupDetailNotifierRef on AutoDisposeAsyncNotifierProviderRef<Group> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<GroupDetailNotifier, Group>
    with GroupDetailNotifierRef {
  _GroupDetailNotifierProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupDetailNotifierProvider).groupId;
}

String _$expenseListNotifierHash() =>
    r'e76e532819dfea710736d8ce8b650bf90066876a';

abstract class _$ExpenseListNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<Expense>> {
  late final String groupId;

  FutureOr<List<Expense>> build(
    String groupId,
  );
}

/// See also [ExpenseListNotifier].
@ProviderFor(ExpenseListNotifier)
const expenseListNotifierProvider = ExpenseListNotifierFamily();

/// See also [ExpenseListNotifier].
class ExpenseListNotifierFamily extends Family<AsyncValue<List<Expense>>> {
  /// See also [ExpenseListNotifier].
  const ExpenseListNotifierFamily();

  /// See also [ExpenseListNotifier].
  ExpenseListNotifierProvider call(
    String groupId,
  ) {
    return ExpenseListNotifierProvider(
      groupId,
    );
  }

  @override
  ExpenseListNotifierProvider getProviderOverride(
    covariant ExpenseListNotifierProvider provider,
  ) {
    return call(
      provider.groupId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'expenseListNotifierProvider';
}

/// See also [ExpenseListNotifier].
class ExpenseListNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ExpenseListNotifier, List<Expense>> {
  /// See also [ExpenseListNotifier].
  ExpenseListNotifierProvider(
    String groupId,
  ) : this._internal(
          () => ExpenseListNotifier()..groupId = groupId,
          from: expenseListNotifierProvider,
          name: r'expenseListNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$expenseListNotifierHash,
          dependencies: ExpenseListNotifierFamily._dependencies,
          allTransitiveDependencies:
              ExpenseListNotifierFamily._allTransitiveDependencies,
          groupId: groupId,
        );

  ExpenseListNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  FutureOr<List<Expense>> runNotifierBuild(
    covariant ExpenseListNotifier notifier,
  ) {
    return notifier.build(
      groupId,
    );
  }

  @override
  Override overrideWith(ExpenseListNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ExpenseListNotifierProvider._internal(
        () => create()..groupId = groupId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ExpenseListNotifier, List<Expense>>
      createElement() {
    return _ExpenseListNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseListNotifierProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExpenseListNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<List<Expense>> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _ExpenseListNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ExpenseListNotifier,
        List<Expense>> with ExpenseListNotifierRef {
  _ExpenseListNotifierProviderElement(super.provider);

  @override
  String get groupId => (origin as ExpenseListNotifierProvider).groupId;
}

String _$friendshipListNotifierHash() =>
    r'b10672c661b7b864fe6cbd5154cf7d64b649f036';

/// See also [FriendshipListNotifier].
@ProviderFor(FriendshipListNotifier)
final friendshipListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    FriendshipListNotifier, List<Friendship>>.internal(
  FriendshipListNotifier.new,
  name: r'friendshipListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendshipListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FriendshipListNotifier = AutoDisposeAsyncNotifier<List<Friendship>>;
String _$friendshipDetailNotifierHash() =>
    r'9bea82c9be1fd123e7a3d773ea57fda328e2e8f7';

abstract class _$FriendshipDetailNotifier
    extends BuildlessAutoDisposeAsyncNotifier<Friendship> {
  late final String email;

  FutureOr<Friendship> build(
    String email,
  );
}

/// See also [FriendshipDetailNotifier].
@ProviderFor(FriendshipDetailNotifier)
const friendshipDetailNotifierProvider = FriendshipDetailNotifierFamily();

/// See also [FriendshipDetailNotifier].
class FriendshipDetailNotifierFamily extends Family<AsyncValue<Friendship>> {
  /// See also [FriendshipDetailNotifier].
  const FriendshipDetailNotifierFamily();

  /// See also [FriendshipDetailNotifier].
  FriendshipDetailNotifierProvider call(
    String email,
  ) {
    return FriendshipDetailNotifierProvider(
      email,
    );
  }

  @override
  FriendshipDetailNotifierProvider getProviderOverride(
    covariant FriendshipDetailNotifierProvider provider,
  ) {
    return call(
      provider.email,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'friendshipDetailNotifierProvider';
}

/// See also [FriendshipDetailNotifier].
class FriendshipDetailNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<FriendshipDetailNotifier,
        Friendship> {
  /// See also [FriendshipDetailNotifier].
  FriendshipDetailNotifierProvider(
    String email,
  ) : this._internal(
          () => FriendshipDetailNotifier()..email = email,
          from: friendshipDetailNotifierProvider,
          name: r'friendshipDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$friendshipDetailNotifierHash,
          dependencies: FriendshipDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              FriendshipDetailNotifierFamily._allTransitiveDependencies,
          email: email,
        );

  FriendshipDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.email,
  }) : super.internal();

  final String email;

  @override
  FutureOr<Friendship> runNotifierBuild(
    covariant FriendshipDetailNotifier notifier,
  ) {
    return notifier.build(
      email,
    );
  }

  @override
  Override overrideWith(FriendshipDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FriendshipDetailNotifierProvider._internal(
        () => create()..email = email,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        email: email,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<FriendshipDetailNotifier, Friendship>
      createElement() {
    return _FriendshipDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendshipDetailNotifierProvider && other.email == email;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, email.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FriendshipDetailNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<Friendship> {
  /// The parameter `email` of this provider.
  String get email;
}

class _FriendshipDetailNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FriendshipDetailNotifier,
        Friendship> with FriendshipDetailNotifierRef {
  _FriendshipDetailNotifierProviderElement(super.provider);

  @override
  String get email => (origin as FriendshipDetailNotifierProvider).email;
}

String _$userDetailNotifierHash() =>
    r'c09c8559275cc9173c125d0a21bc9d2e24e80467';

/// See also [UserDetailNotifier].
@ProviderFor(UserDetailNotifier)
final userDetailNotifierProvider = AutoDisposeAsyncNotifierProvider<
    UserDetailNotifier, user_model.User>.internal(
  UserDetailNotifier.new,
  name: r'userDetailNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userDetailNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserDetailNotifier = AutoDisposeAsyncNotifier<user_model.User>;
String _$themeColorHash() => r'4ef7e05d68a34bec800592eac7cd770666832636';

/// See also [ThemeColor].
@ProviderFor(ThemeColor)
final themeColorProvider =
    AutoDisposeNotifierProvider<ThemeColor, Color>.internal(
  ThemeColor.new,
  name: r'themeColorProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$themeColorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemeColor = AutoDisposeNotifier<Color>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
