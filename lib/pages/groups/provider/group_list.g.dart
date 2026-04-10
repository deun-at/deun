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

String _$groupListNotifierHash() => r'1df9e8f9bae5f7be4ca12b72faf1788a847f9369';

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
