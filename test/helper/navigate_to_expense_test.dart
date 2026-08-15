import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Acceptance tests for expense-notification-route. Every assertion restates a
/// criterion from the plan: a push notification opens the expense READ view and
/// never the editor, on both notification entry points (cold start begins at the
/// app's initial location `/group`, a background tap can begin on any tab);
/// dismissing it falls back to the group detail with no editor on the stack;
/// itemized expenses land wherever the in-app ledger already sends them; and the
/// group / friendship notification destinations are unchanged.

const _routeGroupList = '/group';
const _routeFriendTab = '/friend';
const _routeGroupDetail = '/group/details';
const _routeEditor = '/group/details/expense';
const _routeReadDetail = '/group/details/expense-detail';
const _routeClaim = '/group/details/claim';

Group _group() {
  final g = Group();
  g.id = 'g';
  g.name = 'Trip';
  g.colorValue = 0xFF2196F3;
  g.simplifiedExpenses = false;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

ExpenseEntry _entry(int index, {required String splitMode}) {
  final e = ExpenseEntry(index: index);
  e.id = 'entry$index';
  e.expenseId = 'x';
  e.name = 'item$index';
  e.amount = 10;
  e.quantity = 1;
  e.splitMode = splitMode;
  e.createdAt = '';
  e.expenseEntryShares = [];
  return e;
}

/// A plain expense — no claim units, so the ledger opens the read detail.
Expense _quick(Group group) {
  final e = Expense();
  e.id = 'x1';
  e.groupId = group.id;
  e.group = group;
  e.name = 'Dinner';
  e.amount = 10;
  e.paidBy = 'sam@test.com';
  e.paidByDisplayName = 'sam';
  e.expenseDate = '2026-01-02T10:00:00';
  e.createdAt = '2026-01-02T10:00:00';
  e.isPaidBackRow = false;
  e.category = null;
  e.expenseEntries = {'e0': _entry(0, splitMode: 'equal')};
  e.groupMemberShareStatistic = {};
  return e;
}

/// An itemized expense with real per-unit claim entries — the ledger opens the
/// claim screen for these.
Expense _claimItemized(Group group) {
  final e = _quick(group);
  e.id = 'x2';
  e.name = 'Groceries';
  e.amount = 20;
  e.expenseEntries = {
    'e0': _entry(0, splitMode: 'claim'),
    'e1': _entry(1, splitMode: 'claim'),
  };
  return e;
}

/// An old itemized expense: several entries, manual splits, no claim units.
Expense _legacyItemized(Group group) {
  final e = _quick(group);
  e.id = 'x3';
  e.name = 'Hotel';
  e.amount = 20;
  e.expenseEntries = {
    'e0': _entry(0, splitMode: 'equal'),
    'e1': _entry(1, splitMode: 'amount'),
  };
  return e;
}

class _Harness {
  _Harness(this.router, this.visited, this.extraByPath);

  final GoRouter router;

  /// Every route path built, in build order. A page that is on the navigation
  /// stack has been built, so absence here means absence from the stack.
  final List<String> visited;
  final Map<String, Map<String, dynamic>?> extraByPath;

  /// The route actually on top of the stack right now. Chained navigation
  /// calls (go then push then push, as `navigateToExpense` does) make
  /// GoRouter rebuild ancestor pages again while settling, so a route built
  /// earlier can be re-appended to [visited] after the true top route —
  /// [visited]`.last` is therefore not a reliable "current top" check. This
  /// reads the router's own current match list instead, which is.
  String get top =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;
}

/// Pumps a router carrying stand-ins for every destination a notification can
/// reach, starts at [initialLocation], and taps a button that runs [action].
Future<_Harness> _pump(
  WidgetTester tester, {
  required String initialLocation,
  required void Function(BuildContext context) action,
}) async {
  final visited = <String>[];
  final extraByPath = <String, Map<String, dynamic>?>{};

  GoRoute trigger(String path, String label) => GoRoute(
    path: path,
    builder: (context, state) {
      visited.add(path);
      return Scaffold(
        body: Column(
          children: [
            Text(label),
            TextButton(
              onPressed: () => action(context),
              child: const Text('trigger'),
            ),
          ],
        ),
      );
    },
  );

  GoRoute stub(String path, String label) => GoRoute(
    path: path,
    builder: (context, state) {
      visited.add(path);
      extraByPath[path] = state.extra as Map<String, dynamic>?;
      return Scaffold(body: Text(label));
    },
  );

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      trigger(_routeGroupList, 'group list'),
      trigger(_routeFriendTab, 'friend tab'),
      stub(_routeGroupDetail, 'group detail'),
      stub(_routeEditor, 'editor'),
      stub(_routeReadDetail, 'read detail'),
      stub(_routeClaim, 'claim'),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  await tester.tap(find.text('trigger'));
  await tester.pumpAndSettle();

  return _Harness(router, visited, extraByPath);
}

void main() {
  group('navigateToExpense', () {
    testWidgets(
      'a cold-start notification opens the read view, not the editor',
      (tester) async {
        final group = _group();
        final expense = _quick(group);

        final h = await _pump(
          tester,
          // Cold start: the app opened at its initialLocation.
          initialLocation: _routeGroupList,
          action: (context) => navigateToExpense(context, expense),
        );

        expect(h.top, _routeReadDetail);
        expect(h.visited, isNot(contains(_routeEditor)));
        expect(find.text('read detail'), findsOneWidget);
      },
    );

    testWidgets(
      'a background notification from another tab opens the same read view',
      (tester) async {
        final group = _group();
        final expense = _quick(group);

        final h = await _pump(
          tester,
          // Background tap: the app was alive on a different branch.
          initialLocation: _routeFriendTab,
          action: (context) => navigateToExpense(context, expense),
        );

        expect(h.top, _routeReadDetail);
        expect(h.visited, isNot(contains(_routeEditor)));
        expect(find.text('read detail'), findsOneWidget);
      },
    );

    testWidgets(
      'the read view gets the group and expense ExpenseDetailRead reads',
      (tester) async {
        final group = _group();
        final expense = _quick(group);

        final h = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => navigateToExpense(context, expense),
        );

        final extra = h.extraByPath[_routeReadDetail];
        expect(extra, isNotNull);
        // ExpenseDetailRead casts these as `Group` and non-nullable `Expense`.
        expect(extra!['group'], same(group));
        expect(extra['expense'], same(expense));
      },
    );

    testWidgets(
      'dismissing the read view returns to the group detail underneath',
      (tester) async {
        final group = _group();
        final expense = _quick(group);

        final h = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => navigateToExpense(context, expense),
        );

        h.router.pop();
        await tester.pumpAndSettle();

        expect(find.text('group detail'), findsOneWidget);
        expect(find.text('read detail'), findsNothing);
        // No editor was ever on the stack, so there is nothing to prompt about
        // unsaved changes on the way back.
        expect(h.visited, isNot(contains(_routeEditor)));
      },
    );

    testWidgets(
      'an itemized claim expense goes exactly where the ledger sends it',
      (tester) async {
        final group = _group();
        final expense = _claimItemized(group);

        final fromNotification = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => navigateToExpense(context, expense),
        );
        final fromLedger = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => openLedgerExpense(context, group, expense),
        );

        expect(fromNotification.top, fromLedger.top);
        expect(fromNotification.top, _routeClaim);
        expect(fromNotification.visited, isNot(contains(_routeEditor)));
      },
    );

    testWidgets(
      'an old itemized expense with no claim units opens the read view',
      (tester) async {
        final group = _group();
        final expense = _legacyItemized(group);

        final fromNotification = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => navigateToExpense(context, expense),
        );
        final fromLedger = await _pump(
          tester,
          initialLocation: _routeGroupList,
          action: (context) => openLedgerExpense(context, group, expense),
        );

        expect(fromNotification.top, fromLedger.top);
        expect(fromNotification.top, _routeReadDetail);
      },
    );
  });

  group('the other notification types are unchanged', () {
    testWidgets('a group notification still opens the group detail', (
      tester,
    ) async {
      final group = _group();

      final h = await _pump(
        tester,
        initialLocation: _routeFriendTab,
        action: (context) => navigateToGroup(context, group),
      );

      expect(h.top, _routeGroupDetail);
      expect(find.text('group detail'), findsOneWidget);
      expect(h.extraByPath[_routeGroupDetail]!['group'], same(group));
    });

    testWidgets('a friendship notification still opens the friends tab', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        initialLocation: _routeGroupList,
        action: (context) => navigateToFriends(context),
      );

      expect(h.top, _routeFriendTab);
      expect(find.text('friend tab'), findsOneWidget);
    });
  });
}
