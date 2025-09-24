import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../data/friendship_model.dart';

part 'friendship_list.g.dart';

@riverpod
class FriendshipListNotifier extends _$FriendshipListNotifier {
  @override
  FutureOr<List<Friendship>> build() async {
    _subscribeToRealTimeUpdates();
    return await fetchFriendshipList();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchFriendshipList());
  }

  Future<List<Friendship>> fetchFriendshipList() async {
    return await Friendship.fetchData();
  }

  void _subscribeToRealTimeUpdates() {
    supabase
        .channel('public:friendship_list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendship',
          callback: (payload) {
            reload();
          },
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- friendshipList ${status.toString()}');
          if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
            ref.invalidateSelf();
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            reload();
          }
        });

    supabase
        .channel('public:friendship_list_group_checker')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_update_checker',
          callback: (payload) async {
            reload();
          },
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- friendshipGroupList ${status.toString()}');
          if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
            ref.invalidateSelf();
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            reload();
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            reload();
          }
        });
  }
}
