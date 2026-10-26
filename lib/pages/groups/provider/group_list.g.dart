// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GroupListNotifier)
final groupListProvider = GroupListNotifierProvider._();

final class GroupListNotifierProvider
    extends $AsyncNotifierProvider<GroupListNotifier, List<Group>> {
  GroupListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupListNotifierHash();

  @$internal
  @override
  GroupListNotifier create() => GroupListNotifier();
}

String _$groupListNotifierHash() => r'248b96d02e17f293d20d318d5d74c4287cebf990';

abstract class _$GroupListNotifier extends $AsyncNotifier<List<Group>> {
  FutureOr<List<Group>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Group>>, List<Group>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Group>>, List<Group>>,
              AsyncValue<List<Group>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The ids of the groups in the user's group list — the scope both lists'
/// realtime group channels are filtered on. Empty until the list's first data
/// and again from the moment a rebuild (a user switch) starts; keeps its value
/// through `reload()` and a failed reload.

@ProviderFor(userGroupIds)
final userGroupIdsProvider = UserGroupIdsProvider._();

/// The ids of the groups in the user's group list — the scope both lists'
/// realtime group channels are filtered on. Empty until the list's first data
/// and again from the moment a rebuild (a user switch) starts; keeps its value
/// through `reload()` and a failed reload.

final class UserGroupIdsProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// The ids of the groups in the user's group list — the scope both lists'
  /// realtime group channels are filtered on. Empty until the list's first data
  /// and again from the moment a rebuild (a user switch) starts; keeps its value
  /// through `reload()` and a failed reload.
  UserGroupIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userGroupIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userGroupIdsHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return userGroupIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$userGroupIdsHash() => r'd36593c0dfffff8cfdb1f0d43d1bb12f7cabe98e';
