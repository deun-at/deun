// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FriendshipListNotifier)
final friendshipListProvider = FriendshipListNotifierProvider._();

final class FriendshipListNotifierProvider
    extends $AsyncNotifierProvider<FriendshipListNotifier, List<Friendship>> {
  FriendshipListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'friendshipListProvider',
        isAutoDispose: false,
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
    r'60aadb56222cd560a96e33f959b40ce21b323c2f';

abstract class _$FriendshipListNotifier
    extends $AsyncNotifier<List<Friendship>> {
  FutureOr<List<Friendship>> build();
  @$mustCallSuper
  @override
  void runBuild() {
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
    element.handleCreate(ref, build);
  }
}
