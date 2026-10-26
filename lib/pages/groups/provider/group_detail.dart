import 'package:deun/provider.dart';
import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/group_model.dart';
import '../data/group_repository.dart';

part 'group_detail.g.dart';

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier
    with RealtimeNotifierMixin {
  @override
  FutureOr<Group> build(String groupId) async {
    ref.watch(currentUserProvider);
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      ref: ref,
      channelName: 'group_detail:$groupId',
      table: 'group_update_checker',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'group_id',
        value: groupId,
      ),
      onEvent: (payload) async {
        await reload(groupId);
      },
    );

    listenForResume(ref: ref, onResume: () => reload(groupId));

    return await fetchGroup(groupId);
  }

  @visibleForTesting
  @protected
  Future<Group> fetchGroup(String groupId) =>
      ref.read(groupRepositoryProvider).fetchDetail(groupId);

  Future<void> reload(String groupId) async {
    if (!ref.mounted) return;
    final result = await AsyncValue.guard(() => fetchGroup(groupId));
    if (!ref.mounted) return;
    state = result;
  }
}
