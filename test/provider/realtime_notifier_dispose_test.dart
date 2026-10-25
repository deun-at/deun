// realtime-channel-lifecycle: the realtime notifiers' own side. A fetch that
// lands after its notifier is disposed writes nothing and throws nothing;
// ExpenseListNotifier's mounted realtime path is unchanged; and
// ClaimNotifier.claimingNow follows only its live claim channel. Fetches go
// through each notifier's protected fetch seam and are answered by Completers
// the test controls. Channels come from FakeRealtimeChannelFactory.

import 'dart:async';

import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports Override and ProviderBase only from misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override, ProviderBase;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_realtime_channel_factory.dart';

/// Hands out one pending Completer per fetch, so the test decides when each lands.
class _Fetches<T> {
  final List<Completer<T>> pending = [];

  Future<T> next() {
    final completer = Completer<T>();
    pending.add(completer);
    return completer.future;
  }
}

class _ExpenseListUnderTest extends ExpenseListNotifier {
  _ExpenseListUnderTest(this.pages, this.details);

  final _Fetches<List<Expense>> pages;
  final _Fetches<Expense> details;

  @override
  Future<List<Expense>> fetchPage(String groupId, int from, int to) =>
      pages.next();

  @override
  Future<Expense> fetchExpense(String expenseId) => details.next();
}

class _GroupDetailUnderTest extends GroupDetailNotifier {
  _GroupDetailUnderTest(this.groups);

  final _Fetches<Group> groups;

  @override
  Future<Group> fetchGroup(String groupId) => groups.next();
}

class _ClaimUnderTest extends ClaimNotifier {
  _ClaimUnderTest(this.details);

  final _Fetches<Expense> details;

  @override
  Future<Expense> fetchExpense(String expenseId) => details.next();
}

Expense _expense(
  String id, {
  String name = 'Lunch',
  String date = '2026-01-01',
}) => Expense()
  ..id = id
  ..groupId = 'g1'
  ..name = name
  ..expenseDate = date
  ..createdAt = '2026-01-01T00:00:00Z';

Group _group() => Group()
  ..id = 'g1'
  ..name = 'Trip';

ProviderContainer _container(
  FakeRealtimeChannelFactory channels,
  List<Override> overrides,
) => ProviderContainer.test(
  overrides: [
    realtimeChannelFactoryProvider.overrideWithValue(channels),
    ...overrides,
  ],
);

void _resume(ProviderContainer container, FakeAsync async) {
  container.read(appResumeCounterProvider.notifier).increment();
  async.elapse(Duration.zero);
}

/// Drops the only listener, so Riverpod disposes the autoDispose notifier.
void _unmount(
  ProviderContainer container,
  ProviderSubscription<Object?> sub,
  ProviderBase<Object?> provider,
  FakeAsync async,
) {
  sub.close();
  async.elapse(Duration.zero);
  expect(container.exists(provider), isFalse, reason: 'precondition: disposed');
}

/// Mounts ExpenseListNotifier('g1') and lands its first page.
({
  FakeRealtimeChannelFactory channels,
  ProviderContainer container,
  ProviderSubscription<AsyncValue<List<Expense>>> sub,
  _Fetches<List<Expense>> pages,
  _Fetches<Expense> details,
})
_mountExpenseList(FakeAsync async, {List<Expense> firstPage = const []}) {
  final channels = FakeRealtimeChannelFactory();
  final pages = _Fetches<List<Expense>>();
  final details = _Fetches<Expense>();
  final container = _container(channels, [
    expenseListProvider(
      'g1',
    ).overrideWith(() => _ExpenseListUnderTest(pages, details)),
  ]);
  final sub = container.listen(expenseListProvider('g1'), (_, _) {});
  async.elapse(Duration.zero);
  pages.pending.single.complete(firstPage);
  async.elapse(Duration.zero);
  return (
    channels: channels,
    container: container,
    sub: sub,
    pages: pages,
    details: details,
  );
}

/// Mounts ClaimNotifier('g1', 'e1') and lands its first fetch.
({
  FakeRealtimeChannelFactory channels,
  ProviderContainer container,
  ProviderSubscription<AsyncValue<Expense>> sub,
  _Fetches<Expense> details,
})
_mountClaim(FakeAsync async) {
  final channels = FakeRealtimeChannelFactory();
  final details = _Fetches<Expense>();
  final container = _container(channels, [
    claimProvider('g1', 'e1').overrideWith(() => _ClaimUnderTest(details)),
  ]);
  final sub = container.listen(claimProvider('g1', 'e1'), (_, _) {});
  async.elapse(Duration.zero);
  details.pending.single.complete(_expense('e1'));
  async.elapse(Duration.zero);
  return (channels: channels, container: container, sub: sub, details: details);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // ClaimNotifier.build reads supabase.auth.currentUser (null session here).
    // Same setup as test/provider/auth_switch_invalidation_test.dart; no
    // network is used (fake channels, seam fetches).
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  setUp(() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  });

  group(
    'C8 a fetch that outlives its notifier writes no state and raises no error',
    () {
      // Red before the guards: the late state write throws UnmountedRefException,
      // which surfaces as an uncaught error and fails the test.

      test('ExpenseListNotifier realtime insert/update', () {
        fakeAsync((async) {
          final m = _mountExpenseList(async);
          m.channels.deliver(
            'expense_list:g1',
            postgresChange(
              PostgresChangeEvent.insert,
              newRecord: {'expense_id': 'e2'},
            ),
          );
          async.elapse(Duration.zero);
          expect(m.details.pending, hasLength(1));

          _unmount(m.container, m.sub, expenseListProvider('g1'), async);
          m.details.pending.single.complete(_expense('e2'));
          async.elapse(Duration.zero);
        });
      });

      test('ExpenseListNotifier resume reload', () {
        fakeAsync((async) {
          final m = _mountExpenseList(async);
          _resume(m.container, async);
          expect(m.pages.pending, hasLength(2));

          _unmount(m.container, m.sub, expenseListProvider('g1'), async);
          m.pages.pending.last.complete([_expense('e1')]);
          async.elapse(Duration.zero);
        });
      });

      test(
        'GroupDetailNotifier realtime event (its resume runs the same reload)',
        () {
          fakeAsync((async) {
            final channels = FakeRealtimeChannelFactory();
            final groups = _Fetches<Group>();
            final container = _container(channels, [
              groupDetailProvider(
                'g1',
              ).overrideWith(() => _GroupDetailUnderTest(groups)),
            ]);
            final sub = container.listen(groupDetailProvider('g1'), (_, _) {});
            async.elapse(Duration.zero);
            groups.pending.single.complete(_group());
            async.elapse(Duration.zero);

            channels.deliver(
              'group_detail:g1',
              postgresChange(
                PostgresChangeEvent.update,
                newRecord: {'group_id': 'g1'},
              ),
            );
            async.elapse(Duration.zero);
            expect(groups.pending, hasLength(2));

            _unmount(container, sub, groupDetailProvider('g1'), async);
            groups.pending.last.complete(_group());
            async.elapse(Duration.zero);
          });
        },
      );

      test('ClaimNotifier realtime refetch', () {
        fakeAsync((async) {
          final m = _mountClaim(async);
          m.channels.deliver(
            'claim:e1',
            postgresChange(
              PostgresChangeEvent.update,
              newRecord: {'expense_id': 'e1'},
            ),
          );
          async.elapse(Duration.zero);
          expect(m.details.pending, hasLength(2));

          _unmount(m.container, m.sub, claimProvider('g1', 'e1'), async);
          m.details.pending.last.complete(_expense('e1'));
          async.elapse(Duration.zero);
        });
      });

      test('ClaimNotifier resume refetch', () {
        fakeAsync((async) {
          final m = _mountClaim(async);
          _resume(m.container, async);
          expect(m.details.pending, hasLength(2));

          _unmount(m.container, m.sub, claimProvider('g1', 'e1'), async);
          m.details.pending.last.complete(_expense('e1'));
          async.elapse(Duration.zero);
        });
      });
    },
  );

  test(
    'C9 while mounted, a realtime insert adds, an update replaces and a delete removes',
    () {
      fakeAsync((async) {
        final m = _mountExpenseList(
          async,
          firstPage: [_expense('e1', date: '2026-01-01')],
        );
        List<Expense> listed() =>
            m.container.read(expenseListProvider('g1')).requireValue;

        m.channels.deliver(
          'expense_list:g1',
          postgresChange(
            PostgresChangeEvent.insert,
            newRecord: {'expense_id': 'e2'},
          ),
        );
        async.elapse(Duration.zero);
        m.details.pending.last.complete(_expense('e2', date: '2026-01-02'));
        async.elapse(Duration.zero);
        expect(listed().map((e) => e.id), unorderedEquals(['e1', 'e2']));

        m.channels.deliver(
          'expense_list:g1',
          postgresChange(
            PostgresChangeEvent.update,
            newRecord: {'expense_id': 'e1'},
          ),
        );
        async.elapse(Duration.zero);
        m.details.pending.last.complete(_expense('e1', name: 'Dinner'));
        async.elapse(Duration.zero);
        expect(listed(), hasLength(2));
        expect(listed().singleWhere((e) => e.id == 'e1').name, 'Dinner');

        m.channels.deliver(
          'expense_list:g1',
          postgresChange(
            PostgresChangeEvent.delete,
            oldRecord: {'expense_id': 'e2'},
          ),
        );
        async.elapse(Duration.zero);
        expect(listed().map((e) => e.id), ['e1']);
      });
    },
  );

  test('C7 ClaimNotifier.claimingNow follows its live claim channel', () {
    fakeAsync((async) {
      final m = _mountClaim(async);
      final notifier = m.container.read(claimProvider('g1', 'e1').notifier);
      m.channels.latest('claim:e1').emitPresence(2);
      expect(notifier.claimingNow, 2);
    });
  });
}
