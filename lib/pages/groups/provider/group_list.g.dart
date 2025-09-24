// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_list.dart';

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

String _$groupListNotifierHash() => r'a466051ad2c749cb2d5ff0cb0e7e475c3a932a29';

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
