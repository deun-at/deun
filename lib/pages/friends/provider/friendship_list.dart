import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/friendship_model.dart';
import '../data/friendship_repository.dart';

part 'friendship_list.g.dart';

@riverpod
class FriendshipListNotifier extends _$FriendshipListNotifier with RealtimeNotifierMixin {
  @override
  FutureOr<List<Friendship>> build() async {
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      channelName: 'friendship_list',
      table: 'friendship',
      onEvent: (payload) {
        reload();
      },
    );

    subscribeToChannel(
      channelName: 'friendship_group_checker',
      table: 'group_update_checker',
      onEvent: (payload) async {
        reload();
      },
    );

    listenForResume(ref: ref, onResume: () => reload());

    return await fetchFriendshipList();
  }

  Future<void> reload() async {
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() async => await fetchFriendshipList());
  }

  Future<List<Friendship>> fetchFriendshipList() async {
    return await FriendshipRepository.fetchData();
  }
}
