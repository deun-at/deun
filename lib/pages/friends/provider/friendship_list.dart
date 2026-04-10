import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/friendship_model.dart';
import '../data/friendship_repository.dart';

part 'friendship_list.g.dart';

class FriendshipListState {
  final List<Friendship> acceptedFriends;
  final List<Friendship> pendingIncomingRequests;
  final List<Friendship> pendingOutgoingRequests;

  const FriendshipListState({
    this.acceptedFriends = const [],
    this.pendingIncomingRequests = const [],
    this.pendingOutgoingRequests = const [],
  });
}

@Riverpod(keepAlive: true)
class FriendshipListNotifier extends _$FriendshipListNotifier with RealtimeNotifierMixin {
  Timer? _debounceTimer;

  @override
  FutureOr<FriendshipListState> build() async {
    disposeChannels();
    ref.onDispose(() {
      disposeChannels();
      _debounceTimer?.cancel();
    });

    subscribeToChannel(
      channelName: 'friendship_list',
      table: 'friendship',
      onEvent: (payload) {
        _debouncedReload();
      },
    );

    subscribeToChannel(
      channelName: 'friendship_group_checker',
      table: 'group_update_checker',
      onEvent: (payload) {
        _debouncedReload();
      },
    );

    listenForResume(ref: ref, onResume: () => reload());

    return await fetchFriendshipList();
  }

  /// Debounce group update reloads to avoid excessive refreshes
  /// when multiple expenses change in quick succession.
  void _debouncedReload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      reload();
    });
  }

  Future<void> reload() async {
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() async => await fetchFriendshipList());
  }

  Future<FriendshipListState> fetchFriendshipList() async {
    final results = await Future.wait([
      FriendshipRepository.fetchData(),
      FriendshipRepository.fetchPendingIncoming(),
      FriendshipRepository.fetchPendingOutgoing(),
    ]);

    return FriendshipListState(
      acceptedFriends: results[0],
      pendingIncomingRequests: results[1],
      pendingOutgoingRequests: results[2],
    );
  }
}

@riverpod
int pendingFriendRequestCount(Ref ref) {
  final state = ref.watch(friendshipListProvider);
  return state.value?.pendingIncomingRequests.length ?? 0;
}
