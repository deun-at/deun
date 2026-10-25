import 'dart:async';

import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../../../main.dart' show supabase;
import '../../groups/provider/group_list.dart';
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
class FriendshipListNotifier extends _$FriendshipListNotifier
    with RealtimeNotifierMixin {
  Timer? _debounceTimer;

  /// Whether the group list had this build's data when the last scope
  /// arrived. A scope gain after that means a group joined after its bump
  /// went out, so the friend list reloads.
  bool _groupListLoaded = false;

  @override
  FutureOr<FriendshipListState> build() async {
    disposeChannels();
    ref.onDispose(() {
      disposeChannels();
      _debounceTimer?.cancel();
    });
    _groupListLoaded = false;

    final email = currentUserEmail();
    if (email != null) {
      // A friendship row matches on either column, and filters AND together.
      for (final column in const ['requester', 'addressee']) {
        subscribeToChannel(
          ref: ref,
          channelName: 'friendship_list:$column',
          table: 'friendship',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: column,
            value: email,
          ),
          onEvent: (_) => _debouncedReload(),
        );
      }
      // listen, not watch: a scope change never rebuilds the friend list.
      ref.listen(userGroupIdsProvider, _onGroupScope, fireImmediately: true);
    }

    listenForResume(ref: ref, onResume: () => reload());

    return await fetchFriendshipList();
  }

  @visibleForTesting
  @protected
  String? currentUserEmail() => supabase.auth.currentUser?.email;

  void _onGroupScope(Set<String>? previous, Set<String> next) {
    final groupList = ref.read(groupListProvider);
    final gained =
        _groupListLoaded && previous != null && !previous.containsAll(next);
    _groupListLoaded = groupList.hasValue && !groupList.isLoading;
    syncInFilterChannels(
      ref: ref,
      prefix: 'friendship_group_checker',
      table: 'group_update_checker',
      column: 'group_id',
      values: next,
      onEvent: (_) => _debouncedReload(),
    );
    if (gained) _debouncedReload();
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
    final r = ref;
    if (!r.mounted) return;
    final result = await AsyncValue.guard(fetchFriendshipList);
    if (!r.mounted) return;
    state = result;
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
