// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_detail.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
    r'2dd69e69059263cd594176ea4a1ac820ee7c4ae2';

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
