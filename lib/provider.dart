import 'package:deun/constants.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
class GroupListNotifier extends _$GroupListNotifier {
  @override
  FutureOr<List<Group>> build() async {
    _subscribeToRealTimeUpdates();

    return await fetchGroupList();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchGroupList());
  }

  Future<List<Group>> fetchGroupList() async {
    return await Group.fetchData();
  }

  void _subscribeToRealTimeUpdates() {
    supabase
        .channel('public:group_list_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) async {
              debugPrint("group list changed");
              reload();
            })
        .subscribe();
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  FutureOr<Group> build(String groupId) async {
    _subscribeToRealTimeUpdates(groupId);

    return await fetchGroupDetail(groupId);
  }

  Future<void> reload(groupId) async {
    state = await AsyncValue.guard(() async => await fetchGroupDetail(groupId));
  }

  Future<Group> fetchGroupDetail(String groupId) async {
    return await Group.fetchDetail(groupId);
  }

  void _subscribeToRealTimeUpdates(String groupId) {
    supabase
        .channel('public:group_detail_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) async {
              debugPrint("group detail changed");
              reload(groupId);
            })
        .subscribe();
  }
}

@riverpod
Future<List<Expense>> expenseList(Ref ref) async {
  return await Expense.fetchData();
}

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
              debugPrint("friendship changed");
              reload();
            })
        .subscribe();
  }
}

@riverpod
class FriendshipDetailNotifier extends _$FriendshipDetailNotifier {
  @override
  FutureOr<Friendship> build(String email) async {
    return await fetchFriendshipDetail(email);
  }

  Future<void> reload(String email) async {
    state = await AsyncValue.guard(() async => await fetchFriendshipDetail(email));
  }

  Future<Friendship> fetchFriendshipDetail(String email) async {
    return await Friendship.fetchDetail(email);
  }
}

@riverpod
class ThemeColor extends _$ThemeColor {
  @override
  Color build() => ColorSeed.baseColor.color;

  void setColor(Color color) => state = color;
  void resetColor() => state = ColorSeed.baseColor.color;
}
