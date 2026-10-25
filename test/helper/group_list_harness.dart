// realtime-event-scope: a GroupListNotifier whose fetch and email seams the
// test answers, plus fixtures and channel queries over
// FakeRealtimeChannelFactory.

import 'dart:async';

import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports Override only from misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_realtime_channel_factory.dart';

const me = 'me@test.com';
const other = 'other@test.com';

/// Hands out one pending Completer per fetch, so a test decides when each lands.
class PendingFetches<T> {
  final List<Completer<T>> pending = [];

  Future<T> next() {
    final completer = Completer<T>();
    pending.add(completer);
    return completer.future;
  }
}

/// One per-group fetch the notifier started.
class GroupFetch {
  GroupFetch(this.groupId);

  final String groupId;
  final Completer<Group> completer = Completer();
}

/// The signed-in email and the server, as the notifiers under test see them.
/// [email] is mutable so a test can switch accounts.
class FakeGroupBackend {
  FakeGroupBackend(this.email);

  String? email;
  final PendingFetches<List<Group>> lists = PendingFetches();
  final List<GroupFetch> groupFetches = [];

  List<GroupFetch> fetchesOf(String groupId) =>
      groupFetches.where((f) => f.groupId == groupId).toList();
}

class GroupListUnderTest extends GroupListNotifier {
  GroupListUnderTest(this.backend);

  final FakeGroupBackend backend;

  @override
  String? currentUserEmail() => backend.email;

  @override
  Future<List<Group>> fetchGroups() => backend.lists.next();

  @override
  Future<Group> fetchGroup(String groupId) {
    final fetch = GroupFetch(groupId);
    backend.groupFetches.add(fetch);
    return fetch.completer.future;
  }
}

/// A container whose channels come from [channels] and whose group list is
/// [backend]'s, plus [overrides].
ProviderContainer groupListContainer(
  FakeRealtimeChannelFactory channels,
  FakeGroupBackend backend, [
  List<Override> overrides = const [],
]) => ProviderContainer.test(
  // A first fetch that fails stays failed until the test reloads.
  retry: (_, _) => null,
  overrides: [
    realtimeChannelFactoryProvider.overrideWithValue(channels),
    groupListProvider.overrideWith(() => GroupListUnderTest(backend)),
    ...overrides,
  ],
);

GroupMember _member(String groupId, String email, {DateTime? removedAt}) =>
    GroupMember()
      ..groupId = groupId
      ..email = email
      ..displayName = email
      ..isGuest = false
      ..isFavorite = false
      ..removedAt = removedAt;

/// A group [id] whose active members are [members] and whose soft-removed
/// members are [removedMembers]. [total] marks which read a row came from.
Group testGroup(
  String id, {
  double total = 0,
  List<String> members = const [me],
  List<String> removedMembers = const [],
}) => Group()
  ..id = id
  ..name = id
  ..totalExpenses = total
  ..groupMembers = [
    for (final email in members) _member(id, email),
    for (final email in removedMembers)
      _member(id, email, removedAt: DateTime.utc(2026, 10, 1)),
  ];

PostgresChangePayload checkerChange(PostgresChangeEvent type, String groupId) =>
    type == PostgresChangeEvent.delete
    ? postgresChange(type, oldRecord: {'group_id': groupId})
    : postgresChange(type, newRecord: {'group_id': groupId});

PostgresChangePayload membershipChange(
  PostgresChangeEvent type,
  String groupId,
  String email,
) => postgresChange(type, newRecord: {'group_id': groupId, 'email': email});

/// The values of [channel]'s `in` filter.
List<String> inFilterValues(FakeRealtimeChannel channel) =>
    (channel.filter!.value as List).cast<String>();

extension ScopedChannels on FakeRealtimeChannelFactory {
  List<FakeRealtimeChannel> get liveChannels =>
      opened.where((c) => !c.isClosed).toList();

  /// The live `group_update_checker` chunk channels named under [prefix].
  List<FakeRealtimeChannel> liveCheckers(String prefix) => liveChannels
      .where(
        (c) =>
            c.table == 'group_update_checker' &&
            c.channelName.startsWith('$prefix:'),
      )
      .toList();

  /// The live chunk channel under [prefix] whose filter carries [groupId].
  FakeRealtimeChannel checkerFor(String prefix, String groupId) => liveCheckers(
    prefix,
  ).singleWhere((c) => inFilterValues(c).contains(groupId));

  /// The group list's live membership channel.
  FakeRealtimeChannel get membership =>
      liveChannels.singleWhere((c) => c.table == 'group_member');
}
