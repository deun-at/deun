import 'package:deun/constants.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/friends/friendship_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/groups/group_model.dart';
import 'pages/expenses/expense_model.dart';

// Necessary for code-generation to work
part 'provider.g.dart';

@riverpod
class GroupListNotifier extends _$GroupListNotifier {
  @override
  FutureOr<List<Group>> build() async {
    // Initialize entries when the provider is first used
    final groupList = await fetchGroupList();
    _subscribeToRealTimeUpdates();
    return groupList;
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchGroupList());
  }

  Future<List<Group>> fetchGroupList() async {
    return await Group.fetchData();
  }

  void _subscribeToRealTimeUpdates() {
    supabase
        .channel('public:group_update_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) async {
              debugPrint("group update checker changed");
              reload();
            })
        .subscribe();
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  FutureOr<Group> build(String groupId) async {
    // Initialize entries when the provider is first used
    final groupList = await fetchGroupDetail(groupId);
    _subscribeToRealTimeUpdates(groupId);
    return groupList;
  }

  Future<void> reload(groupId) async {
    state = await AsyncValue.guard(() async => await fetchGroupDetail(groupId));
  }

  Future<Group> fetchGroupDetail(String groupId) async {
    return await Group.fetchDetail(groupId);
  }

  void _subscribeToRealTimeUpdates(String groupId) {
    supabase
        .channel('public:group_update_checker')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_update_checker',
            callback: (payload) async {
              debugPrint("group update checker changed");
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
    // Initialize entries when the provider is first used
    final friendshipList = await fetchFriendshipList();
    _subscribeToRealTimeUpdates();
    return friendshipList;
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async => await fetchFriendshipList());
  }

  Future<List<Friendship>> fetchFriendshipList() async {
    return await Friendship.fetchData();
  }

  void _subscribeToRealTimeUpdates() {
    supabase
        .channel('public:friendship')
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
class ThemeColor extends _$ThemeColor {
  @override
  Color build() => ColorSeed.baseColor.color;

  void setColor(Color color) => state = color;
  void resetColor() => state = ColorSeed.baseColor.color;
}
