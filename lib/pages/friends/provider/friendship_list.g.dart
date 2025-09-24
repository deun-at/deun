// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
    r'd50cfd5685c4decb33d36d4906dbb50f5bb8d994';

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
