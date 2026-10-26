// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(friendshipRepository)
final friendshipRepositoryProvider = FriendshipRepositoryProvider._();

final class FriendshipRepositoryProvider
    extends
        $FunctionalProvider<
          FriendshipRepository,
          FriendshipRepository,
          FriendshipRepository
        >
    with $Provider<FriendshipRepository> {
  FriendshipRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'friendshipRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$friendshipRepositoryHash();

  @$internal
  @override
  $ProviderElement<FriendshipRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FriendshipRepository create(Ref ref) {
    return friendshipRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FriendshipRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FriendshipRepository>(value),
    );
  }
}

String _$friendshipRepositoryHash() =>
    r'd636af277ee9ba32797ae31a16e7581de450353f';
