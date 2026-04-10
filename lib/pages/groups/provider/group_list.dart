import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/group_model.dart';
import '../data/group_repository.dart';

part 'group_list.g.dart';

@Riverpod(keepAlive: true)
class GroupListNotifier extends _$GroupListNotifier with RealtimeNotifierMixin {
  @override
  FutureOr<List<Group>> build() async {
    disposeChannels();
    ref.onDispose(() => disposeChannels());

    subscribeToChannel(
      ref: ref,
      channelName: 'group_list',
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
          final group = await GroupRepository.fetchDetail(groupId);

          state = state.whenData((groups) {
            final updated = List<Group>.from(groups);
            final index = updated.indexWhere((g) => g.id == group.id);

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
    );

    listenForResume(ref: ref, onResume: () => reload());

    return await GroupRepository.fetchData("all");
  }

  Future<void> reload() async {
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() async => await GroupRepository.fetchData("all"));
  }

  Future<void> toggleFavorite(String groupId) async {
    final previousState = state;

    // Optimistically update
    state = state.whenData((groups) {
      final updated = List<Group>.from(groups);
      final index = updated.indexWhere((g) => g.id == groupId);
      if (index == -1) return groups;

      final group = updated[index];
      final email = group.groupMembers.firstWhere(
        (m) => m.email == (Supabase.instance.client.auth.currentUser?.email ?? ''),
      );
      email.isFavorite = !email.isFavorite;
      return updated;
    });

    try {
      final group = state.value?.firstWhere((g) => g.id == groupId);
      if (group != null) {
        await GroupRepository.toggleFavorite(groupId, group.isFavorite);
      }
    } catch (e) {
      debugPrint(e.toString());
      state = previousState;
    }
  }
}
