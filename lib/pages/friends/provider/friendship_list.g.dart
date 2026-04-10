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
    extends
        $AsyncNotifierProvider<FriendshipListNotifier, FriendshipListState> {
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
    r'990260c72f381d5a2f2b51da25bb0f4e10c0616d';

abstract class _$FriendshipListNotifier
    extends $AsyncNotifier<FriendshipListState> {
  FutureOr<FriendshipListState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<FriendshipListState>, FriendshipListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FriendshipListState>, FriendshipListState>,
              AsyncValue<FriendshipListState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(pendingFriendRequestCount)
final pendingFriendRequestCountProvider = PendingFriendRequestCountProvider._();

final class PendingFriendRequestCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  PendingFriendRequestCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingFriendRequestCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingFriendRequestCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return pendingFriendRequestCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$pendingFriendRequestCountHash() =>
    r'cd9238a16180347c1f633974cb3316c28efb7f45';
