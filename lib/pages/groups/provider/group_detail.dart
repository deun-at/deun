import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/group_model.dart';
import '../data/group_repository.dart';

part 'group_detail.g.dart';

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier with RealtimeNotifierMixin {
  @override
  FutureOr<Group> build(String groupId) async {
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      ref: ref,
      channelName: 'group_detail:$groupId',
      table: 'group_update_checker',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
      onEvent: (payload) async {
        reload(groupId);
      },
    );

    listenForResume(ref: ref, onResume: () => reload(groupId));

    return await GroupRepository.fetchDetail(groupId);
  }

  Future<void> reload(String groupId) async {
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() async => await GroupRepository.fetchDetail(groupId));
  }
}
