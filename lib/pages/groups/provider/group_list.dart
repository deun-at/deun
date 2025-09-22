import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants.dart';
import '../../../main.dart';
import '../data/group_model.dart';

part 'group_list.g.dart';

@Riverpod(keepAlive: false)
class GroupListNotifier extends _$GroupListNotifier {
  RealtimeChannel? _channel;

  @override
  FutureOr<List<Group>> build(String statusFilter) async {
    _subscribeToRealTimeUpdates(statusFilter);

    // cleanup when provider is disposed
    ref.onDispose(() {
      if (_channel != null) {
        supabase.removeChannel(_channel!);
        _channel = null;
      }
    });

    return await Group.fetchData(statusFilter);
  }

  Future<void> reload(String statusFilter) async {
    if (!ref.mounted) return; // prevent updates after dispose
    state = await AsyncValue.guard(() async => await Group.fetchData(statusFilter));
  }

  void _subscribeToRealTimeUpdates(String statusFilter) {
    _channel = supabase
        .channel('public:group_list_checker')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_update_checker',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final groupId = payload.oldRecord['group_id'];
              state = state.whenData((groups) {
                final index = groups.indexWhere((g) => g.id == groupId);
                if (index == -1) return groups; // Group not found
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
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- groupList ${status.toString()}');
        });
  }
}
