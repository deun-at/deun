// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$groupListHash() => r'cc51f06b600a614238f596744a8b09f2cf5ed697';

/// See also [groupList].
@ProviderFor(groupList)
final groupListProvider = AutoDisposeFutureProvider<List<Group>>.internal(
  groupList,
  name: r'groupListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$groupListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GroupListRef = AutoDisposeFutureProviderRef<List<Group>>;
String _$groupDetailHash() => r'd59fe9372cf34c22a45f142126b0478ee9e9db2a';

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

/// See also [groupDetail].
@ProviderFor(groupDetail)
const groupDetailProvider = GroupDetailFamily();

/// See also [groupDetail].
class GroupDetailFamily extends Family<AsyncValue<Group>> {
  /// See also [groupDetail].
  const GroupDetailFamily();

  /// See also [groupDetail].
  GroupDetailProvider call(
    String groupId,
  ) {
    return GroupDetailProvider(
      groupId,
    );
  }

  @override
  GroupDetailProvider getProviderOverride(
    covariant GroupDetailProvider provider,
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
  String? get name => r'groupDetailProvider';
}

/// See also [groupDetail].
class GroupDetailProvider extends AutoDisposeFutureProvider<Group> {
  /// See also [groupDetail].
  GroupDetailProvider(
    String groupId,
  ) : this._internal(
          (ref) => groupDetail(
            ref as GroupDetailRef,
            groupId,
          ),
          from: groupDetailProvider,
          name: r'groupDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$groupDetailHash,
          dependencies: GroupDetailFamily._dependencies,
          allTransitiveDependencies:
              GroupDetailFamily._allTransitiveDependencies,
          groupId: groupId,
        );

  GroupDetailProvider._internal(
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
  Override overrideWith(
    FutureOr<Group> Function(GroupDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupDetailProvider._internal(
        (ref) => create(ref as GroupDetailRef),
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
  AutoDisposeFutureProviderElement<Group> createElement() {
    return _GroupDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupDetailProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GroupDetailRef on AutoDisposeFutureProviderRef<Group> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupDetailProviderElement
    extends AutoDisposeFutureProviderElement<Group> with GroupDetailRef {
  _GroupDetailProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupDetailProvider).groupId;
}

String _$expenseDetailHash() => r'66b3fedc0bcd4390c68d01a6d40367abb0a3cbad';

/// See also [expenseDetail].
@ProviderFor(expenseDetail)
const expenseDetailProvider = ExpenseDetailFamily();

/// See also [expenseDetail].
class ExpenseDetailFamily extends Family<AsyncValue<Expense>> {
  /// See also [expenseDetail].
  const ExpenseDetailFamily();

  /// See also [expenseDetail].
  ExpenseDetailProvider call(
    String expenseId,
  ) {
    return ExpenseDetailProvider(
      expenseId,
    );
  }

  @override
  ExpenseDetailProvider getProviderOverride(
    covariant ExpenseDetailProvider provider,
  ) {
    return call(
      provider.expenseId,
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
  String? get name => r'expenseDetailProvider';
}

/// See also [expenseDetail].
class ExpenseDetailProvider extends AutoDisposeFutureProvider<Expense> {
  /// See also [expenseDetail].
  ExpenseDetailProvider(
    String expenseId,
  ) : this._internal(
          (ref) => expenseDetail(
            ref as ExpenseDetailRef,
            expenseId,
          ),
          from: expenseDetailProvider,
          name: r'expenseDetailProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$expenseDetailHash,
          dependencies: ExpenseDetailFamily._dependencies,
          allTransitiveDependencies:
              ExpenseDetailFamily._allTransitiveDependencies,
          expenseId: expenseId,
        );

  ExpenseDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.expenseId,
  }) : super.internal();

  final String expenseId;

  @override
  Override overrideWith(
    FutureOr<Expense> Function(ExpenseDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExpenseDetailProvider._internal(
        (ref) => create(ref as ExpenseDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        expenseId: expenseId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Expense> createElement() {
    return _ExpenseDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseDetailProvider && other.expenseId == expenseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, expenseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ExpenseDetailRef on AutoDisposeFutureProviderRef<Expense> {
  /// The parameter `expenseId` of this provider.
  String get expenseId;
}

class _ExpenseDetailProviderElement
    extends AutoDisposeFutureProviderElement<Expense> with ExpenseDetailRef {
  _ExpenseDetailProviderElement(super.provider);

  @override
  String get expenseId => (origin as ExpenseDetailProvider).expenseId;
}

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

typedef ExpenseListRef = AutoDisposeFutureProviderRef<List<Expense>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
