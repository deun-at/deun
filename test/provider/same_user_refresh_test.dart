// injectable-repositories: a token refresh, an initial-session re-emit and a
// re-emitted sign-in for the account already signed in reach no list: the
// group list, the friend list and an open ledger keep what they loaded, and no
// data source is asked for anything new.

import 'dart:async';

import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_realtime_channel_factory.dart';
import '../helper/fake_supabase.dart';
import '../helper/two_user_fixtures.dart';

final _annUser = authUser('ann-id', ann);

class _Groups implements GroupRepository {
  _Groups(this.log, this.email);

  final List<String> log;
  final String? email;

  @override
  Future<List<Group>> fetchData(String statusFilter, {String? paidTo}) async {
    log.add('groups.fetchData');
    return [
      Group()..loadDataFromJson(sharedGroupRow(), currentUserEmail: email),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Friendships implements FriendshipRepository {
  _Friendships(this.log);

  final List<String> log;

  @override
  Future<List<Friendship>> fetchData() async {
    log.add('friendships.fetchData');
    return const [];
  }

  @override
  Future<List<Friendship>> fetchPendingIncoming() async {
    log.add('friendships.fetchPendingIncoming');
    return const [];
  }

  @override
  Future<List<Friendship>> fetchPendingOutgoing() async {
    log.add('friendships.fetchPendingOutgoing');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Expenses implements ExpenseRepository {
  _Expenses(this.log);

  final List<String> log;

  @override
  Future<List<Expense>> fetchData([
    String? groupId,
    int rangeFrom = 0,
    int rangeTo = 0,
    String? filter,
  ]) async {
    log.add('expenses.fetchData $rangeFrom-$rangeTo');
    return [
      for (var i = rangeFrom; i <= rangeTo; i++)
        Expense()
          ..id = 'e$i'
          ..groupId = 'g1'
          ..name = 'Expense $i'
          ..expenseDate = '2026-01-01'
          ..createdAt = '',
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  test(
    'a token refresh or a re-emitted sign-in for the same account reloads nothing',
    () async {
      final auth = StreamController<AuthState>.broadcast();
      addTearDown(auth.close);
      final log = <String>[];
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          authStateChangesProvider.overrideWith((ref) => auth.stream),
          // Ann's session is restored at start, so every list loads as Ann.
          supabaseClientProvider.overrideWithValue(
            FakeSupabaseClient(currentUser: _annUser),
          ),
          realtimeChannelFactoryProvider.overrideWithValue(
            FakeRealtimeChannelFactory(),
          ),
          groupRepositoryProvider.overrideWith(
            (ref) => _Groups(log, ref.watch(currentUserProvider)?.email),
          ),
          friendshipRepositoryProvider.overrideWith((ref) {
            ref.watch(currentUserProvider);
            return _Friendships(log);
          }),
          expenseRepositoryProvider.overrideWith((ref) {
            ref.watch(currentUserProvider);
            return _Expenses(log);
          }),
        ],
      );
      container.listen(groupListProvider, (_, _) {}, onError: (_, _) {});
      container.listen(friendshipListProvider, (_, _) {}, onError: (_, _) {});
      container.listen(
        expenseListProvider('g1'),
        (_, _) {},
        onError: (_, _) {},
      );
      await pumpEventQueue();
      await container
          .read(expenseListProvider('g1').notifier)
          .loadMoreEntries('g1');

      final groups = container.read(groupListProvider).requireValue;
      final friends = container.read(friendshipListProvider).requireValue;
      final ledger = container.read(expenseListProvider('g1')).requireValue;
      expect(ledger, hasLength(40), reason: 'precondition: two pages loaded');
      final asked = [...log];

      for (final event in [
        authEvent(AuthChangeEvent.initialSession, _annUser),
        authEvent(AuthChangeEvent.tokenRefreshed, _annUser, token: 'refreshed'),
        authEvent(AuthChangeEvent.signedIn, _annUser, token: 're-emitted'),
      ]) {
        auth.add(event);
        await pumpEventQueue();
        await container.pump();
      }

      expect(log, asked, reason: 'no data source is asked for anything new');
      expect(container.read(groupListProvider).requireValue, same(groups));
      expect(
        container.read(friendshipListProvider).requireValue,
        same(friends),
      );
      expect(
        container.read(expenseListProvider('g1')).requireValue,
        same(ledger),
      );
    },
  );
}
