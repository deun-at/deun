import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';
import '../../../helper/realtime_mixin.dart';
import '../data/group_model.dart';

part 'group_list.g.dart';

@riverpod
class GroupListNotifier extends _$GroupListNotifier with RealtimeNotifierMixin {
  @override
  FutureOr<List<Group>> build(String statusFilter) async {
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      ref: ref,
      channelName: 'group_list:$statusFilter',
      table: 'group_update_checker',
      onEvent: (payload) async {
        if (payload.eventType == PostgresChangeEvent.delete) {
          final groupId = payload.oldRecord['group_id'];
          state = state.whenData((groups) {
            final index = groups.indexWhere((g) => g.id == groupId);
            if (index == -1) return groups;
            final updated = List<Group>.from(groups);
            updated.removeAt(index);
            return updated;
          });
          return;
        } else if (payload.eventType == PostgresChangeEvent.update ||
            payload.eventType == PostgresChangeEvent.insert) {
          final groupId = payload.newRecord['group_id'];
          final group = await Group.fetchDetail(groupId);

          bool matchesFilter;
          final absAmt = group.totalShareAmount.abs();
          if (statusFilter == GroupListFilter.active.value) {
            matchesFilter = absAmt >= 0.01;
          } else if (statusFilter == GroupListFilter.done.value) {
            matchesFilter = absAmt < 0.01;
          } else {
            matchesFilter = true;
          }

          state = state.whenData((groups) {
            final updated = List<Group>.from(groups);
            final index = updated.indexWhere((g) => g.id == group.id);

            if (!matchesFilter) {
              if (index != -1) updated.removeAt(index);
              return updated;
            }

            if (index != -1) {
              updated[index] = group;
            } else {
              updated.add(group);
            }
            updated.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            return updated;
          });
          return;
        }
      },
      onSubscribed: () => reload(statusFilter),
    );

    return await Group.fetchData(statusFilter);
  }

  Future<void> reload(String statusFilter) async {
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() async => await Group.fetchData(statusFilter));
  }
}
