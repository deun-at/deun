// typed-routes: the real route table (buildAppRouter) with every load, list
// and realtime channel answered offline. Ids are UUIDs because the loaders
// treat any other id as not-found before loading.

import 'package:deun/app_router.dart';
import 'package:deun/constants.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/expenses/provider/expense_by_id.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports Override only from misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_realtime_channel_factory.dart';
import 'fake_supabase.dart';

const groupId = '0b1c2d3e-0000-4000-8000-000000000001';
const otherGroupId = '0b1c2d3e-0000-4000-8000-000000000002';
const missingGroupId = '0b1c2d3e-0000-4000-8000-0000000000ff';
const expenseId = 'e0000000-0000-4000-8000-000000000001';
const claimExpenseId = 'e0000000-0000-4000-8000-000000000002';
const foreignExpenseId = 'e0000000-0000-4000-8000-000000000003';
const missingExpenseId = 'e0000000-0000-4000-8000-0000000000ff';

GroupMember _member(String ofGroup, String email, String name) => GroupMember()
  ..groupId = ofGroup
  ..email = email
  ..displayName = name
  ..username = email.split('@').first
  ..usernameCode = '0001'
  ..isGuest = false
  ..isFavorite = false;

Group routeGroup(String id, {String name = 'Trip'}) => Group()
  ..id = id
  ..name = name
  ..colorValue = kBrandSeed.toARGB32()
  ..simplifiedExpenses = true
  ..createdAt = ''
  ..userId = null
  ..currencyCode = 'EUR'
  ..groupMembers = [
    _member(id, 'me@test.com', 'Me'),
    _member(id, 'ann@test.com', 'Ann'),
  ]
  ..groupSharesSummary = {}
  ..totalExpenses = 0
  ..totalShareAmount = 0
  ..expenses = [];

ExpenseEntryShare _share(
  String entryId,
  String email,
  String name,
  double pct,
) => ExpenseEntryShare()
  ..expenseEntryId = entryId
  ..email = email
  ..displayName = name
  ..percentage = pct
  ..fixedAmount = null
  ..parts = null
  ..isLocked = false
  ..createdAt = '';

ExpenseEntry _entry(
  String expenseId,
  String id,
  int index, {
  required String splitMode,
  required double amount,
  required List<ExpenseEntryShare> shares,
}) {
  final e = ExpenseEntry(index: index);
  e.id = id;
  e.expenseId = expenseId;
  e.name = 'item$index';
  e.amount = amount;
  e.quantity = 1;
  e.splitMode = splitMode;
  e.createdAt = '';
  e.itemGroupId = null;
  e.expenseEntryShares = shares;
  return e;
}

/// A quick expense of [group]; with [claim], an itemized one with per-unit
/// claim entries (hasClaimUnits).
Expense routeExpense(String id, Group group, {bool claim = false}) {
  final e = Expense();
  e.id = id;
  e.groupId = group.id;
  e.group = group;
  e.name = claim ? 'Groceries' : 'Dinner';
  e.amount = 20;
  e.paidBy = 'me@test.com';
  e.paidByDisplayName = 'Me';
  e.expenseDate = '2026-01-02T10:00:00';
  e.createdAt = '2026-01-02T10:00:00';
  e.isPaidBackRow = false;
  e.category = null;
  e.groupMemberShareStatistic = {'me@test.com': 10, 'ann@test.com': 10};
  e.expenseEntries = claim
      ? {
          'u1': _entry(
            id,
            'u1',
            0,
            splitMode: 'claim',
            amount: 12,
            shares: [_share('u1', 'me@test.com', 'Me', 100)],
          ),
          'u2': _entry(
            id,
            'u2',
            1,
            splitMode: 'claim',
            amount: 8,
            shares: const [],
          ),
        }
      : {
          'e0': _entry(
            id,
            'e0',
            0,
            splitMode: 'equal',
            amount: 20,
            shares: [
              _share('e0', 'me@test.com', 'Me', 50),
              _share('e0', 'ann@test.com', 'Ann', 50),
            ],
          ),
        };
  return e;
}

/// What PostgREST's `.single()` throws for zero rows.
PostgrestException rowNotFound() => const PostgrestException(
  message: 'JSON object requested, multiple (or no) rows returned',
  code: 'PGRST116',
);

/// The two loads the loaders sit on, answered from [groups] / [expenses] after
/// 50 ms, with every call recorded. An unknown id throws [rowNotFound]; a set
/// failure throws instead of answering.
class FakeRouteLoads {
  FakeRouteLoads(this.groups, this.expenses);

  factory FakeRouteLoads.standard() {
    final group = routeGroup(groupId);
    final other = routeGroup(otherGroupId, name: 'Other trip');
    return FakeRouteLoads(
      {groupId: group, otherGroupId: other},
      {
        expenseId: routeExpense(expenseId, group),
        claimExpenseId: routeExpense(claimExpenseId, group, claim: true),
        foreignExpenseId: routeExpense(foreignExpenseId, other),
      },
    );
  }

  final Map<String, Group> groups;
  final Map<String, Expense> expenses;
  final List<String> groupCalls = [];
  final List<String> expenseCalls = [];
  Object? groupFailure;
  Object? expenseFailure;

  static const delay = Duration(milliseconds: 50);

  Future<Group> loadGroup(String id) async {
    groupCalls.add(id);
    await Future<void>.delayed(delay);
    final failure = groupFailure;
    if (failure != null) throw failure;
    return groups[id] ?? (throw rowNotFound());
  }

  Future<Expense> loadExpense(String id) async {
    expenseCalls.add(id);
    await Future<void>.delayed(delay);
    final failure = expenseFailure;
    if (failure != null) throw failure;
    return expenses[id] ?? (throw rowNotFound());
  }
}

/// The real notifier — channel, resume listener, reload — over the fake load.
class FakeGroupDetailNotifier extends GroupDetailNotifier {
  FakeGroupDetailNotifier(this.loads);
  final FakeRouteLoads loads;

  @override
  Future<Group> fetchGroup(String groupId) => loads.loadGroup(groupId);
}

class FakeGroupListNotifier extends GroupListNotifier {
  FakeGroupListNotifier(this._groups);
  final List<Group> _groups;

  @override
  Future<List<Group>> build() async => _groups;

  @override
  Future<void> reload() async {}
}

class FakeUserDetailNotifier extends UserDetailNotifier {
  @override
  Future<SupaUser> build() async =>
      const SupaUser(email: 'me@test.com', displayName: 'Me');
}

class FakeFriendshipListNotifier extends FriendshipListNotifier {
  @override
  Future<FriendshipListState> build() async => const FriendshipListState();
}

class StubExpenseListNotifier extends ExpenseListNotifier {
  @override
  Future<List<Expense>> build(String groupId) async => <Expense>[];
}

class FakeClaimNotifier extends ClaimNotifier {
  FakeClaimNotifier(this.loads);
  final FakeRouteLoads loads;

  @override
  Future<Expense> build(String groupId, String expenseId) async =>
      loads.expenses[expenseId]!;
}

List<Override> appRouterOverrides(
  FakeRouteLoads loads, {
  List<Group> listed = const [],
  FakeRealtimeChannelFactory? channels,
}) => [
  currentUserProvider.overrideWithValue(null),
  supabaseClientProvider.overrideWithValue(FakeSupabaseClient()),
  realtimeChannelFactoryProvider.overrideWithValue(
    channels ?? FakeRealtimeChannelFactory(),
  ),
  groupDetailProvider.overrideWith2((_) => FakeGroupDetailNotifier(loads)),
  expenseByIdProvider.overrideWith((ref, id) => loads.loadExpense(id)),
  groupListProvider.overrideWith(() => FakeGroupListNotifier(listed)),
  userDetailProvider.overrideWith(FakeUserDetailNotifier.new),
  friendshipListProvider.overrideWith(FakeFriendshipListNotifier.new),
  expenseListProvider.overrideWith2((_) => StubExpenseListNotifier()),
  claimProvider.overrideWith2((_) => FakeClaimNotifier(loads)),
];

/// The app theme over the router's navigator, as NavigationScreen applies it.
Widget appTheme(BuildContext context, Widget? child) => Theme(
  data: getThemeData(
    context,
    kBrandSeed,
    Brightness.light,
  ).copyWith(splashFactory: NoSplash.splashFactory),
  child: child!,
);

/// Pumps a fresh app on the real route table at [location]. Clears any app a
/// previous call pumped, so a test can pump several in turn.
Future<GoRouter> pumpApp(
  WidgetTester tester,
  String location, {
  required FakeRouteLoads loads,
  List<Group> listed = const [],
  List<Override> overrides = const [],
  GlobalKey<NavigatorState>? rootNavigatorKey,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final router = buildAppRouter(
    rootNavigatorKey: rootNavigatorKey ?? GlobalKey<NavigatorState>(),
    initialLocation: location,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...appRouterOverrides(loads, listed: listed),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: appTheme,
      ),
    ),
  );
  return router;
}

/// Lets loads, transitions and sheets finish without pumpAndSettle (the
/// loading indicators and some pages animate forever).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
