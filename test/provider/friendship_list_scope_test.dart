// realtime-event-scope: FriendshipListNotifier hears only the user's own
// friendships and the groups in the user's group list, follows that list as it
// grows, and writes nothing after dispose. Both lists run for real on one
// container: GroupListNotifier through test/helper/group_list_harness.dart and
// FriendshipListNotifier with its fetch and email seams answered by the test.

import 'dart:async';

import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_realtime_channel_factory.dart';
import '../helper/group_list_harness.dart';

const _update = PostgresChangeEvent.update;
const _debounce = Duration(seconds: 2);

class _FriendshipUnderTest extends FriendshipListNotifier {
  _FriendshipUnderTest(this.backend, this.fetches);

  final FakeGroupBackend backend;
  final PendingFetches<FriendshipListState> fetches;

  @override
  String? currentUserEmail() => backend.email;

  @override
  Future<FriendshipListState> fetchFriendshipList() => fetches.next();
}

/// Mounts the friend list first (as the nav badge does), then the group list,
/// lands both first fetches and lets any debounce run out. With
/// [failFirstGroupFetch] the group list's first fetch fails and a reload
/// then returns [groups].
({
  FakeRealtimeChannelFactory channels,
  FakeGroupBackend backend,
  PendingFetches<FriendshipListState> fetches,
  ProviderContainer container,
})
_mount(
  FakeAsync async,
  List<Group> groups, {
  String? email = me,
  bool failFirstGroupFetch = false,
}) {
  final channels = FakeRealtimeChannelFactory();
  final backend = FakeGroupBackend(email);
  final fetches = PendingFetches<FriendshipListState>();
  final container = groupListContainer(channels, backend, [
    friendshipListProvider.overrideWith(
      () => _FriendshipUnderTest(backend, fetches),
    ),
  ]);
  container.listen(friendshipListProvider, (_, _) {}, onError: (_, _) {});
  container.listen(groupListProvider, (_, _) {}, onError: (_, _) {});
  async.elapse(Duration.zero);
  fetches.pending.single.complete(const FriendshipListState());
  if (failFirstGroupFetch) {
    backend.lists.pending.single.completeError('offline');
    async.elapse(Duration.zero);
    unawaited(container.read(groupListProvider.notifier).reload());
    async.elapse(Duration.zero);
    backend.lists.pending.last.complete(groups);
  } else {
    backend.lists.pending.single.complete(groups);
  }
  async.elapse(Duration.zero);
  async.elapse(_debounce);
  return (
    channels: channels,
    backend: backend,
    fetches: fetches,
    container: container,
  );
}

/// The live channels the friend list opened.
List<FakeRealtimeChannel> _friendChannels(
  FakeRealtimeChannelFactory channels,
) => channels.liveChannels
    .where((c) => c.channelName.startsWith('friendship_'))
    .toList();

void main() {
  setUp(() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('C1 only the user\'s own rows are asked for', () {
    test(
      'both friendship channels filter on the user\'s email, the group channels on the user\'s groups',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
          final mine = _friendChannels(m.channels);
          for (final channel in mine) {
            expect(channel.filter, isNotNull, reason: channel.channelName);
          }
          final friendship = mine
              .where((c) => c.table == 'friendship')
              .toList();
          expect(
            {for (final c in friendship) c.filter!.column: c.filter!.value},
            {'requester': me, 'addressee': me},
          );
          expect(friendship.map((c) => c.filter!.type).toSet(), {
            PostgresChangeFilterType.eq,
          });
          final checkers = m.channels.liveCheckers('friendship_group_checker');
          expect(checkers.expand(inFilterValues).toList()..sort(), [
            'g1',
            'g2',
          ]);
          expect(mine, hasLength(friendship.length + checkers.length));
        });
      },
    );

    test('with no signed-in email neither list opens a channel', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')], email: null);
        expect(m.channels.opened, isEmpty);
      });
    });

    test('after a user switch only the new account\'s filters are open', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
        final firstAccount = [...m.channels.opened];

        m.backend.email = other;
        // What invalidateUserScopedProviders does for these two.
        m.container
          ..invalidate(groupListProvider)
          ..invalidate(friendshipListProvider);
        async.elapse(Duration.zero);
        m.fetches.pending.last.complete(const FriendshipListState());
        m.backend.lists.pending.last.complete([
          testGroup('g9', members: [other]),
        ]);
        async.elapse(Duration.zero);

        expect(firstAccount.where((c) => !c.isClosed), isEmpty);
        final friendship = _friendChannels(
          m.channels,
        ).where((c) => c.table == 'friendship');
        expect(friendship.map((c) => c.filter!.value).toSet(), {other});
        expect(
          m.channels
              .liveCheckers('friendship_group_checker')
              .expand(inFilterValues),
          ['g9'],
        );
      });
    });
  });

  test('C2 every group of a 250-group user stays live in both lists', () {
    fakeAsync((async) {
      final ids = [
        for (var i = 0; i < 250; i++) 'g${i.toString().padLeft(3, '0')}',
      ];
      final m = _mount(async, [for (final id in ids) testGroup(id)]);

      for (final prefix in ['group_list', 'friendship_group_checker']) {
        final checkers = m.channels.liveCheckers(prefix);
        for (final channel in checkers) {
          expect(inFilterValues(channel).length, lessThanOrEqualTo(100));
        }
        expect(
          checkers.expand(inFilterValues).toList()..sort(),
          ids,
          reason: prefix,
        );
      }

      var reloads = m.fetches.pending.length;
      for (final id in ['g000', 'g137', 'g249']) {
        // The server fans one bump out to every subscribed channel.
        m.channels
            .checkerFor('group_list', id)
            .emitEvent(checkerChange(_update, id));
        m.channels
            .checkerFor('friendship_group_checker', id)
            .emitEvent(checkerChange(_update, id));
        async.elapse(Duration.zero);
        m.backend
            .fetchesOf(id)
            .single
            .completer
            .complete(testGroup(id, total: 1));
        async.elapse(_debounce);

        final row = m.container
            .read(groupListProvider)
            .requireValue
            .singleWhere((g) => g.id == id);
        expect(row.totalExpenses, 1, reason: id);
        expect(m.fetches.pending, hasLength(++reloads), reason: id);
      }
    });
  });

  group('C10 the friend list follows the user\'s friendships and groups', () {
    test(
      'every insert, update and delete on a friendship or friendship-group channel reloads after the debounce',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1')]);
          final heard = [
            ..._friendChannels(
              m.channels,
            ).where((c) => c.table == 'friendship'),
            m.channels.checkerFor('friendship_group_checker', 'g1'),
          ];
          expect(heard, hasLength(3));

          var reloads = m.fetches.pending.length;
          for (final channel in heard) {
            for (final type in PostgresChangeEvent.values.where(
              (t) => t != PostgresChangeEvent.all,
            )) {
              channel.emitEvent(
                channel.table == 'friendship'
                    ? postgresChange(type)
                    : checkerChange(type, 'g1'),
              );
              async.elapse(_debounce);
              expect(
                m.fetches.pending,
                hasLength(++reloads),
                reason: '${channel.channelName} $type',
              );
            }
          }
        });
      },
    );

    test(
      'a group joining the list after its first load reloads the friend list and is then heard',
      () {
        // Starting with one group, with none, and with none after a failed
        // first group fetch: a zero-group user's first group must reload too.
        for (final (start, failedFirst) in [
          ([testGroup('g1')], false),
          (<Group>[], false),
          (<Group>[], true),
        ]) {
          fakeAsync((async) {
            final m = _mount(async, start, failFirstGroupFetch: failedFirst);
            var reloads = m.fetches.pending.length;

            m.channels.membership.emitEvent(
              membershipChange(PostgresChangeEvent.insert, 'g3', me),
            );
            async.elapse(Duration.zero);
            m.backend
                .fetchesOf('g3')
                .single
                .completer
                .complete(testGroup('g3'));
            async.elapse(_debounce);
            expect(
              m.fetches.pending,
              hasLength(++reloads),
              reason:
                  'gain from ${start.length} groups (failed first: $failedFirst)',
            );

            m.channels
                .checkerFor('friendship_group_checker', 'g3')
                .emitEvent(checkerChange(_update, 'g3'));
            async.elapse(_debounce);
            expect(
              m.fetches.pending,
              hasLength(++reloads),
              reason:
                  'joined group event, from ${start.length} (failed: $failedFirst)',
            );
          });
        }
      },
    );
  });

  test(
    'C9 a friend-list reload completing after dispose writes nothing and raises nothing',
    () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')]);
        unawaited(m.container.read(friendshipListProvider.notifier).reload());
        async.elapse(Duration.zero);

        m.container.dispose();
        m.fetches.pending.last.complete(const FriendshipListState());
        async.elapse(Duration.zero);
      });
    },
  );
}
