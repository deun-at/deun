import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../data/group_model.dart';

part 'group_detail.g.dart';

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  RealtimeChannel? _channel;

  @override
  FutureOr<Group> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);

    // cleanup when provider is disposed
    ref.onDispose(() {
      if (_channel != null) {
        supabase.removeChannel(_channel!);
        _channel = null;
      }
    });

    return await Group.fetchDetail(groupId);
  }

  Future<void> reload(String groupId) async {
    if (!ref.mounted) return; // prevent updates after dispose
    state = await AsyncValue.guard(() async => await Group.fetchDetail(groupId));
  }

  void _subscribeToRealTimeUpdates(String groupId) {
    _channel = supabase
        .channel('public:group_detail_checker')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_update_checker',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'group_id', value: groupId),
          callback: (payload) async {
            reload(groupId);
          },
        )
        .subscribe((status, _) {
          debugPrint('---subscribe--- groupDetails ${status.toString()}');
        });
  }
}
