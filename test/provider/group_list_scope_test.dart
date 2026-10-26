// realtime-event-scope: GroupListNotifier hears only the user's own groups and
// memberships, and a realtime refresh that fails, races another read or
// outlives its build never corrupts the list. Fetches are answered by the test
// through the notifier's seams; channels come from FakeRealtimeChannelFactory.
// The fake delivers whatever a test emits regardless of the filter — as an
// instance that ignored the filter would — so the client-side check is tested
// too.

import 'dart:async';

import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/app_router_harness.dart' show rowNotFound;
import '../helper/fake_realtime_channel_factory.dart';
import '../helper/group_list_harness.dart';

const _update = PostgresChangeEvent.update;

({
  FakeRealtimeChannelFactory channels,
  FakeGroupBackend backend,
  ProviderContainer container,
})
_mount(FakeAsync async, List<Group> groups, {String? email = me}) {
  final channels = FakeRealtimeChannelFactory();
  final backend = FakeGroupBackend(email);
  final container = groupListContainer(channels, backend);
  container.listen(groupListProvider, (_, _) {}, onError: (_, _) {});
  async.elapse(Duration.zero);
  backend.lists.pending.single.complete(groups);
  async.elapse(Duration.zero);
  return (channels: channels, backend: backend, container: container);
}

List<Group> _listed(ProviderContainer c) =>
    c.read(groupListProvider).requireValue;

Set<String> _ids(ProviderContainer c) => {for (final g in _listed(c)) g.id};

Map<String, double> _totals(ProviderContainer c) => {
  for (final g in _listed(c)) g.id: g.totalExpenses,
};

void _reload(ProviderContainer c, FakeAsync async) {
  unawaited(c.read(groupListProvider.notifier).reload());
  async.elapse(Duration.zero);
}

void main() {
  setUp(() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group('C1 only the user\'s own rows are asked for', () {
    test(
      'every channel carries a filter of the user\'s email or group ids',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
          final live = m.channels.liveChannels;
          expect(live, isNotEmpty);
          for (final channel in live) {
            expect(channel.filter, isNotNull, reason: channel.channelName);
          }
          final membership = m.channels.membership.filter!;
          expect(membership.type, PostgresChangeFilterType.eq);
          expect(membership.column, 'email');
          expect(membership.value, me);
          final checkers = live
              .where((c) => c.table == 'group_update_checker')
              .toList();
          expect(checkers.map((c) => c.filter!.column).toSet(), {'group_id'});
          expect(checkers.expand(inFilterValues).toList()..sort(), [
            'g1',
            'g2',
          ]);
          expect(
            live.where(
              (c) =>
                  c.table != 'group_member' &&
                  c.table != 'group_update_checker',
            ),
            isEmpty,
          );
        });
      },
    );

    test('with no signed-in email no channel opens', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')], email: null);
        expect(m.channels.opened, isEmpty);
      });
    });

    test(
      'after a rebuild under another account only that account\'s filters are open',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
          final firstAccount = [...m.channels.opened];

          m.backend.email = other;
          m.container.invalidate(groupListProvider);
          async.elapse(Duration.zero);
          m.backend.lists.pending.last.complete([
            testGroup('g9', members: [other]),
          ]);
          async.elapse(Duration.zero);

          expect(firstAccount.where((c) => !c.isClosed), isEmpty);
          expect(m.channels.membership.filter!.value, other);
          expect(m.channels.liveCheckers('group_list').expand(inFilterValues), [
            'g9',
          ]);
        });
      },
    );
  });

  test(
    'C3 an event for a group outside the list starts no fetch and changes nothing',
    () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
        final before = _listed(m.container);
        final checker = m.channels.checkerFor('group_list', 'g1');
        checker.emitEvent(
          checkerChange(PostgresChangeEvent.insert, 'stranger'),
        );
        checker.emitEvent(checkerChange(_update, 'stranger'));
        m.channels.membership.emitEvent(
          membershipChange(
            PostgresChangeEvent.insert,
            'stranger',
            'someone@else.com',
          ),
        );
        async.elapse(Duration.zero);

        expect(m.backend.groupFetches, isEmpty);
        expect(_listed(m.container), equals(before));
      });
    },
  );

  test(
    'C4 a membership insert or update for the user adds the group, which then goes live',
    () {
      for (final type in [PostgresChangeEvent.insert, _update]) {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1')]);
          m.channels.membership.emitEvent(membershipChange(type, 'g3', me));
          async.elapse(Duration.zero);
          m.backend
              .fetchesOf('g3')
              .single
              .completer
              .complete(testGroup('g3', total: 1));
          async.elapse(Duration.zero);
          expect(_totals(m.container), {'g1': 0, 'g3': 1}, reason: '$type');

          m.channels
              .checkerFor('group_list', 'g3')
              .emitEvent(checkerChange(_update, 'g3'));
          async.elapse(Duration.zero);
          m.backend
              .fetchesOf('g3')
              .last
              .completer
              .complete(testGroup('g3', total: 7));
          async.elapse(Duration.zero);
          expect(_totals(m.container)['g3'], 7, reason: '$type');
        });
      }
    },
  );

  test(
    'C5 a deleted group leaves, and neither an in-flight fetch nor a later event brings it back',
    () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
        final checker = m.channels.checkerFor('group_list', 'g1');
        checker.emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);
        checker.emitEvent(checkerChange(PostgresChangeEvent.delete, 'g1'));
        async.elapse(Duration.zero);
        expect(_ids(m.container), {'g2'});

        m.backend
            .fetchesOf('g1')
            .single
            .completer
            .complete(testGroup('g1', total: 5));
        async.elapse(Duration.zero);
        expect(_ids(m.container), {'g2'});

        for (final channel in m.channels.liveCheckers('group_list')) {
          channel.emitEvent(checkerChange(PostgresChangeEvent.insert, 'g1'));
        }
        async.elapse(Duration.zero);
        expect(m.backend.fetchesOf('g1'), hasLength(1));
        expect(_ids(m.container), {'g2'});
      });
    },
  );

  test(
    'C6 a hard-removed user loses the group and its checker stops fetching',
    () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')]);
        m.channels
            .checkerFor('group_list', 'g1')
            .emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);
        m.backend
            .fetchesOf('g1')
            .single
            .completer
            .complete(testGroup('g1', members: [other]));
        async.elapse(Duration.zero);
        expect(_ids(m.container), isEmpty);

        for (final channel in m.channels.liveCheckers('group_list')) {
          channel.emitEvent(checkerChange(_update, 'g1'));
        }
        async.elapse(Duration.zero);
        expect(m.backend.fetchesOf('g1'), hasLength(1));
      });
    },
  );

  group('C7 the newest read of a group wins', () {
    test('of two fetches for one group, the later-started one wins', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')]);
        final checker = m.channels.checkerFor('group_list', 'g1');
        checker.emitEvent(checkerChange(_update, 'g1'));
        checker.emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);
        final [earlier, later] = m.backend.fetchesOf('g1');

        later.completer.complete(testGroup('g1', total: 2));
        async.elapse(Duration.zero);
        earlier.completer.complete(testGroup('g1', total: 1));
        async.elapse(Duration.zero);

        expect(_totals(m.container), {'g1': 2});
      });
    });

    test(
      'a fetch that started before a reload cannot overwrite the reload\'s row',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1')]);
          m.channels
              .checkerFor('group_list', 'g1')
              .emitEvent(checkerChange(_update, 'g1'));
          async.elapse(Duration.zero);
          _reload(m.container, async);

          m.backend.lists.pending.last.complete([testGroup('g1', total: 3)]);
          async.elapse(Duration.zero);
          m.backend
              .fetchesOf('g1')
              .single
              .completer
              .complete(testGroup('g1', total: 1));
          async.elapse(Duration.zero);

          expect(_totals(m.container), {'g1': 3});
        });
      },
    );

    test(
      'reads that started after a reload began survive the reload landing later',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1')]);
          _reload(m.container, async);
          m.channels
              .checkerFor('group_list', 'g1')
              .emitEvent(checkerChange(_update, 'g1'));
          m.channels.membership.emitEvent(
            membershipChange(PostgresChangeEvent.insert, 'g3', me),
          );
          async.elapse(Duration.zero);
          m.backend
              .fetchesOf('g1')
              .single
              .completer
              .complete(testGroup('g1', total: 4));
          m.backend
              .fetchesOf('g3')
              .single
              .completer
              .complete(testGroup('g3', total: 6));
          async.elapse(Duration.zero);

          m.backend.lists.pending.last.complete([testGroup('g1', total: 3)]);
          async.elapse(Duration.zero);

          expect(_totals(m.container), {'g1': 4, 'g3': 6});
        });
      },
    );
  });

  test(
    'C8 a failed refresh keeps the list as it was, raises nothing, and the next event refreshes',
    () {
      fakeAsync((async) {
        final m = _mount(async, [
          testGroup('g1', total: 1),
          testGroup('g2', total: 2),
        ]);
        final before = _listed(m.container);
        m.channels
            .checkerFor('group_list', 'g1')
            .emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);
        m.backend
            .fetchesOf('g1')
            .single
            .completer
            .completeError(
              Exception(
                'JSON object requested, multiple (or no) rows returned',
              ),
            );
        async.elapse(Duration.zero);

        expect(
          m.container.read(groupListProvider),
          isA<AsyncData<List<Group>>>(),
        );
        expect(_listed(m.container), equals(before));

        m.channels
            .checkerFor('group_list', 'g1')
            .emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);
        m.backend
            .fetchesOf('g1')
            .last
            .completer
            .complete(testGroup('g1', total: 9));
        async.elapse(Duration.zero);
        expect(_totals(m.container), {'g1': 9, 'g2': 2});
      });
    },
  );

  test(
    'C10 a refresh that comes back not-found takes the group out, and a later event fetches nothing',
    () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1'), testGroup('g2')]);
        // removed-member-access: the removed member hears their own row's
        // update, and the group itself now reads as no row.
        m.channels.membership.emitEvent(membershipChange(_update, 'g1', me));
        async.elapse(Duration.zero);
        m.backend.fetchesOf('g1').single.completer.completeError(rowNotFound());
        async.elapse(Duration.zero);
        expect(
          m.container.read(groupListProvider),
          isA<AsyncData<List<Group>>>(),
        );
        expect(_ids(m.container), {'g2'});

        for (final channel in m.channels.liveCheckers('group_list')) {
          channel.emitEvent(checkerChange(_update, 'g1'));
        }
        async.elapse(Duration.zero);
        expect(m.backend.fetchesOf('g1'), hasLength(1));
      });
    },
  );

  group('C9 nothing lands after the group list\'s build is gone', () {
    // Red before the guards: a late state write throws UnmountedRefException,
    // which surfaces as an uncaught error and fails the test.

    test('a per-group fetch completing after dispose', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')]);
        m.channels
            .checkerFor('group_list', 'g1')
            .emitEvent(checkerChange(_update, 'g1'));
        async.elapse(Duration.zero);

        m.container.dispose();
        m.backend
            .fetchesOf('g1')
            .single
            .completer
            .complete(testGroup('g1', total: 5));
        async.elapse(Duration.zero);
      });
    });

    test('a reload completing after dispose', () {
      fakeAsync((async) {
        final m = _mount(async, [testGroup('g1')]);
        _reload(m.container, async);

        m.container.dispose();
        m.backend.lists.pending.last.complete([testGroup('g1', total: 5)]);
        async.elapse(Duration.zero);
      });
    });

    test(
      'a fetch from before a rebuild writes nothing into the rebuilt list',
      () {
        fakeAsync((async) {
          final m = _mount(async, [testGroup('g1')]);
          m.channels
              .checkerFor('group_list', 'g1')
              .emitEvent(checkerChange(_update, 'g1'));
          async.elapse(Duration.zero);

          m.container.invalidate(groupListProvider);
          async.elapse(Duration.zero);
          m.backend.lists.pending.last.complete([testGroup('g2')]);
          async.elapse(Duration.zero);
          m.backend
              .fetchesOf('g1')
              .single
              .completer
              .complete(testGroup('g1', total: 5));
          async.elapse(Duration.zero);

          expect(_ids(m.container), {'g2'});
        });
      },
    );
  });
}
