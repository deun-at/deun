// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_add_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FriendAddNotifier)
final friendAddProvider = FriendAddNotifierProvider._();

final class FriendAddNotifierProvider
    extends $NotifierProvider<FriendAddNotifier, FriendAddState> {
  FriendAddNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'friendAddProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$friendAddNotifierHash();

  @$internal
  @override
  FriendAddNotifier create() => FriendAddNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FriendAddState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FriendAddState>(value),
    );
  }
}

String _$friendAddNotifierHash() => r'7cb9de257ea2901f5791c0fedec430a5ed5f2769';

abstract class _$FriendAddNotifier extends $Notifier<FriendAddState> {
  FriendAddState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FriendAddState, FriendAddState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FriendAddState, FriendAddState>,
              FriendAddState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
