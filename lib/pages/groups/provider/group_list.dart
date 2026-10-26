import 'dart:async';

import 'package:deun/provider.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helper/realtime_mixin.dart';
import '../data/group_model.dart';
import '../data/group_repository.dart';
import '../data/member_repository.dart';

part 'group_list.g.dart';

int _byName(Group a, Group b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

@Riverpod(keepAlive: true)
class GroupListNotifier extends _$GroupListNotifier with RealtimeNotifierMixin {
  /// One counter for every per-group fetch, delete and full reload, taken when
  /// it starts. Never reset, so a number from a previous build never collides.
  int _readSeq = 0;

  /// Per group, the number of the newest read or delete that has applied.
  final Map<String, int> _applied = {};

  /// The ids of the groups in this build's list — what the group channels
  /// cover and what [userGroupIdsProvider] publishes. Empty until this build's
  /// first data; replaced (never mutated) whenever the id set changes.
  Set<String> _scope = const {};

  /// Whether this build has produced data. `state.value` alone cannot say:
  /// Riverpod carries the previous build's (maybe another account's) value
  /// through AsyncLoading and AsyncError.
  bool _hasData = false;

  /// The signed-in email this build's channels are filtered on.
  String? _email;

  @override
  FutureOr<List<Group>> build() async {
    final r = ref;
    disposeChannels();
    ref.onDispose(() => disposeChannels());
    _applied.clear();
    _scope = const {};
    _hasData = false;

    final email = _email = currentUserEmail();
    if (email != null) {
      subscribeToChannel(
        ref: ref,
        channelName: 'group_list:membership',
        table: 'group_member',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'email',
          value: email,
        ),
        onEvent: _onMembershipEvent,
      );
    }

    listenForResume(ref: ref, onResume: () => reload());

    final groups = await fetchGroups();
    if (!r.mounted) return groups;
    _hasData = true;
    // A fresh instance even when empty, so userGroupIdsProvider notifies that
    // the list has loaded.
    _publishScope(groups, fresh: true);
    return groups;
  }

  @visibleForTesting
  @protected
  Future<List<Group>> fetchGroups() =>
      ref.read(groupRepositoryProvider).fetchData('all');

  @visibleForTesting
  @protected
  Future<Group> fetchGroup(String groupId) =>
      ref.read(groupRepositoryProvider).fetchDetail(groupId);

  @visibleForTesting
  @protected
  String? currentUserEmail() => ref.watch(currentUserProvider)?.email;

  Future<void> reload() async {
    final r = ref;
    if (!r.mounted) return;
    final number = ++_readSeq;
    final result = await AsyncValue.guard(fetchGroups);
    if (!r.mounted) return;
    if (result case AsyncData(value: final fresh)) {
      final current = _currentGroups() ?? const <Group>[];
      final merged = <Group>[];
      final freshIds = <String>{};
      for (final group in fresh) {
        freshIds.add(group.id);
        if (_appliedAfter(group.id, number)) {
          final kept = current.where((g) => g.id == group.id).firstOrNull;
          if (kept != null) merged.add(kept);
        } else {
          _applied[group.id] = number;
          merged.add(group);
        }
      }
      var keptExtra = false;
      for (final group in current) {
        if (freshIds.contains(group.id)) continue;
        if (_appliedAfter(group.id, number)) {
          merged.add(group);
          keptExtra = true;
        } else {
          _applied[group.id] = number;
        }
      }
      if (keptExtra) merged.sort(_byName);
      _setGroups(merged);
    } else {
      state = result; // unchanged: a failed full reload shows its error
    }
  }

  Future<void> toggleFavorite(String groupId) async {
    final previousState = state;
    final email = _email ?? '';

    // Optimistically update
    state = state.whenData((groups) {
      final updated = List<Group>.from(groups);
      final index = updated.indexWhere((g) => g.id == groupId);
      if (index == -1) return groups;

      final group = updated[index];
      final mine = group.groupMembers.firstWhere((m) => m.email == email);
      mine.isFavorite = !mine.isFavorite;
      return updated;
    });

    try {
      final group = state.value?.firstWhere((g) => g.id == groupId);
      if (group != null) {
        await ref
            .read(memberRepositoryProvider)
            .toggleFavorite(groupId, group.isFavoriteFor(email));
      }
    } catch (e) {
      debugPrint(e.toString());
      state = previousState;
    }
  }

  /// This build's list, or null while it has none of its own yet.
  List<Group>? _currentGroups() =>
      _hasData && !state.isLoading ? state.value : null;

  bool _appliedAfter(String groupId, int number) =>
      (_applied[groupId] ?? 0) > number;

  void _setGroups(List<Group> groups) {
    // This build's first data is published as a fresh instance even when it
    // equals the empty scope, so userGroupIdsProvider notifies that the list
    // has loaded (a first fetch that failed, then a reload).
    _publishScope(groups, fresh: !_hasData);
    _hasData = true;
    state = AsyncData(groups);
  }

  void _publishScope(List<Group> groups, {bool fresh = false}) {
    final ids = {for (final group in groups) group.id};
    if (fresh || !setEquals(ids, _scope)) _scope = Set.unmodifiable(ids);
    if (_email == null) return;
    syncInFilterChannels(
      ref: ref,
      prefix: 'group_list',
      table: 'group_update_checker',
      column: 'group_id',
      values: ids,
      onEvent: _onCheckerEvent,
    );
  }

  void _onCheckerEvent(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final groupId = payload.oldRecord['group_id'];
      if (groupId is String) _dropGroup(groupId);
      return;
    }
    final groupId = payload.newRecord['group_id'];
    // Defence in depth while the instance's in-filter support is unverified:
    // a group outside the list is never fetched.
    if (groupId is String && _scope.contains(groupId)) {
      unawaited(_refreshGroup(groupId));
    }
  }

  void _onMembershipEvent(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) return;
    final record = payload.newRecord;
    final groupId = record['group_id'];
    final email = _email;
    if (groupId is String && email != null && record['email'] == email) {
      unawaited(_refreshGroup(groupId));
    }
  }

  void _dropGroup(String groupId) {
    final groups = _currentGroups();
    if (groups == null) return;
    _applied[groupId] = ++_readSeq;
    if (groups.every((g) => g.id != groupId)) return;
    _setGroups([
      for (final group in groups)
        if (group.id != groupId) group,
    ]);
  }

  /// Fetches one group and writes it into the list — or takes it out when the
  /// user has no member row in it any more (soft-removed rows count as rows).
  /// The newest-started read or delete of a group wins; a failed fetch changes
  /// nothing.
  Future<void> _refreshGroup(String groupId) async {
    final r = ref;
    final email = _email;
    if (email == null) return;
    final number = ++_readSeq;
    final Group group;
    try {
      group = await fetchGroup(groupId);
    } catch (error) {
      debugPrint('group_list: refresh of $groupId failed: $error');
      return;
    }
    if (!r.mounted) return;
    final groups = _currentGroups();
    if (groups == null || _appliedAfter(groupId, number)) return;
    _applied[groupId] = number;
    final stillMember = group.groupMembers.any((m) => m.email == email);
    _setGroups(
      [
        for (final g in groups)
          if (g.id != groupId) g,
        if (stillMember) group,
      ]..sort(_byName),
    );
  }
}

/// The ids of the groups in the user's group list — the scope both lists'
/// realtime group channels are filtered on. Empty until the list's first data
/// and again from the moment a rebuild (a user switch) starts; keeps its value
/// through `reload()` and a failed reload.
@riverpod
Set<String> userGroupIds(Ref ref) {
  ref.watch(groupListProvider);
  return ref.read(groupListProvider.notifier)._scope;
}
