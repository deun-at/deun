// typed-routes: the two route loaders over provider fakes. Each test reads the
// state a user sees: loading, the page, not-found or the retryable error.

import 'package:deun/app_paths.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/route_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/app_router_harness.dart';
import '../helper/fake_realtime_channel_factory.dart';

/// The loader under a two-route GoRouter, so the back and `go` actions work.
Future<void> _pumpLoader(
  WidgetTester tester,
  Widget loader,
  FakeRouteLoads loads, {
  FakeRealtimeChannelFactory? channels,
}) async {
  final router = GoRouter(
    initialLocation: '/group/page',
    routes: [
      GoRoute(
        path: '/group',
        builder: (context, state) => const Scaffold(body: Text('GROUP LIST')),
        routes: [GoRoute(path: 'page', builder: (context, state) => loader)],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: appRouterOverrides(loads, channels: channels),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: appTheme,
      ),
    ),
  );
}

Widget _groupLoader({Group? prefetched, List<Group>? built}) =>
    GroupRouteLoader(
      groupId: groupId,
      prefetched: prefetched,
      builder: (context, group) {
        built?.add(group);
        return Text('GROUP ${group.id}');
      },
    );

Widget _expenseLoader({
  ExpenseRouteExtra? prefetched,
  List<(Group, Expense)>? built,
}) => ExpenseRouteLoader(
  groupId: groupId,
  expenseId: expenseId,
  prefetched: prefetched,
  builder: (context, group, expense) {
    built?.add((group, expense));
    return Text('EXPENSE ${group.id} ${expense.id}');
  },
);

/// The page is up and none of the route states replaced it.
void _expectPageUp(Finder page, AppLocalizations l10n) {
  expect(page, findsOneWidget);
  expect(find.byKey(kRouteLoadingKey), findsNothing);
  expect(find.text(l10n.generalError), findsNothing);
  expect(find.text(l10n.pageNotFound), findsNothing);
}

void main() {
  testWidgets(
    'a group load that fails shows Retry, and Retry shows the page once the load succeeds',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final loads = FakeRouteLoads.standard()
        ..groupFailure = Exception('offline');
      await _pumpLoader(tester, _groupLoader(), loads);
      await settle(tester);
      expect(find.text(l10n.generalError), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text('GROUP $groupId'), findsNothing);

      loads.groupFailure = null;
      await tester.tap(find.text(l10n.retry));
      await settle(tester);
      _expectPageUp(find.text('GROUP $groupId'), l10n);
      expect(loads.groupCalls, [groupId, groupId]);
    },
  );

  testWidgets(
    'an expense load that fails shows Retry, and Retry shows the page once the load succeeds',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final loads = FakeRouteLoads.standard()
        ..expenseFailure = Exception('offline');
      await _pumpLoader(tester, _expenseLoader(), loads);
      await settle(tester);
      expect(find.text(l10n.generalError), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text('EXPENSE $groupId $expenseId'), findsNothing);

      loads.expenseFailure = null;
      await tester.tap(find.text(l10n.retry));
      await settle(tester);
      _expectPageUp(find.text('EXPENSE $groupId $expenseId'), l10n);
      expect(loads.expenseCalls, [expenseId, expenseId]);
    },
  );

  testWidgets(
    'a group page opened by its location stays up through a failed realtime or resume reload',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final channels = FakeRealtimeChannelFactory();
      final loads = FakeRouteLoads.standard();
      await _pumpLoader(tester, _groupLoader(), loads, channels: channels);
      await settle(tester);
      final page = find.text('GROUP $groupId');
      _expectPageUp(page, l10n);

      loads.groupFailure = Exception('offline');
      channels.deliver(
        'group_detail:$groupId',
        postgresChange(
          PostgresChangeEvent.update,
          newRecord: {'group_id': groupId},
        ),
      );
      await settle(tester);
      expect(loads.groupCalls, hasLength(2), reason: 'the realtime reloaded');
      _expectPageUp(page, l10n);

      ProviderScope.containerOf(
        tester.element(page),
      ).read(appResumeCounterProvider.notifier).increment();
      await settle(tester);
      expect(loads.groupCalls, hasLength(3), reason: 'the resume reloaded');
      _expectPageUp(page, l10n);
    },
  );

  testWidgets(
    'an expense page opened by its location stays up through a failed group reload',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final channels = FakeRealtimeChannelFactory();
      final loads = FakeRouteLoads.standard();
      await _pumpLoader(tester, _expenseLoader(), loads, channels: channels);
      await settle(tester);
      final page = find.text('EXPENSE $groupId $expenseId');
      _expectPageUp(page, l10n);

      loads.groupFailure = Exception('offline');
      channels.deliver(
        'group_detail:$groupId',
        postgresChange(
          PostgresChangeEvent.update,
          newRecord: {'group_id': groupId},
        ),
      );
      await settle(tester);
      expect(loads.groupCalls, hasLength(2), reason: 'the realtime reloaded');
      _expectPageUp(page, l10n);
    },
  );

  testWidgets(
    'a prefetched group builds its page on the first frame and loads nothing',
    (tester) async {
      final loads = FakeRouteLoads.standard();
      final group = routeGroup(groupId);
      final built = <Group>[];
      await _pumpLoader(
        tester,
        _groupLoader(prefetched: group, built: built),
        loads,
      );
      // First frame: no pump beyond pumpWidget.
      expect(built.single, same(group));
      expect(find.byKey(kRouteLoadingKey), findsNothing);
      await settle(tester);
      expect(built.every((g) => identical(g, group)), isTrue);
      expect(loads.groupCalls, isEmpty);
    },
  );

  testWidgets(
    'a prefetched expense builds its page on the first frame and loads nothing',
    (tester) async {
      final loads = FakeRouteLoads.standard();
      final group = routeGroup(groupId);
      final expense = routeExpense(expenseId, group);
      final built = <(Group, Expense)>[];
      await _pumpLoader(
        tester,
        _expenseLoader(
          prefetched: ExpenseRouteExtra(group: group, expense: expense),
          built: built,
        ),
        loads,
      );
      expect(built.single.$1, same(group));
      expect(built.single.$2, same(expense));
      expect(find.byKey(kRouteLoadingKey), findsNothing);
      await settle(tester);
      expect(loads.groupCalls, isEmpty);
      expect(loads.expenseCalls, isEmpty);
    },
  );

  testWidgets(
    'a prefetched object for another id is ignored and the ids in the path load',
    (tester) async {
      var loads = FakeRouteLoads.standard();
      final groups = <Group>[];
      await _pumpLoader(
        tester,
        _groupLoader(prefetched: routeGroup(otherGroupId), built: groups),
        loads,
      );
      expect(find.byKey(kRouteLoadingKey), findsOneWidget);
      await settle(tester);
      expect(groups.last.id, groupId);
      expect(loads.groupCalls, [groupId]);

      await tester.pumpWidget(const SizedBox.shrink());
      loads = FakeRouteLoads.standard();
      final expenses = <(Group, Expense)>[];
      await _pumpLoader(
        tester,
        _expenseLoader(
          prefetched: ExpenseRouteExtra(
            group: routeGroup(groupId),
            expense: loads.expenses[foreignExpenseId],
          ),
          built: expenses,
        ),
        loads,
      );
      await settle(tester);
      expect(expenses.last.$2.id, expenseId);
      expect(loads.expenseCalls, [expenseId]);
    },
  );
}
