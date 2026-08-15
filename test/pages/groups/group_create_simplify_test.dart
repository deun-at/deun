// group-create-simplify: what happens AFTER the three-field create form. The
// user lands on the NEW group's detail page, that page carries a single-tap
// add-members affordance (members left the create form; they did not
// disappear), and the create write is handed no member field at all.
//
// Each test restates one acceptance criterion.

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

/// A freshly created group as GroupRepository.fetchDetail returns it: the
/// creator is its only member.
Group _group({String name = 'Trip to Rome'}) {
  final g = Group();
  g.id = 'g1';
  g.name = name;
  g.colorValue = kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [_member('me@test.com', 'Me')];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = [];
  return g;
}

/// Offline stubs: return synchronously and never open a realtime channel.
class _StubGroupDetail extends GroupDetailNotifier {
  @override
  Future<Group> build(String groupId) async => _group();
}

class _StubExpenseList extends ExpenseListNotifier {
  @override
  Future<List<Expense>> build(String groupId) async => <Expense>[];
}

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Pumps the create form inside a GoRouter carrying the two routes the
/// post-create hand-off uses. The write path is stubbed: it records the form
/// value it was handed and returns [saved] as the repository round-trip would.
Future<void> _pumpCreateFlow(
  WidgetTester tester, {
  required Group saved,
  required List<Map<String, dynamic>> captured,
}) async {
  final router = GoRouter(
    initialLocation: '/group/edit',
    routes: [
      GoRoute(
        path: '/group',
        builder: (context, state) => const Scaffold(body: Text('GROUP LIST')),
      ),
      GoRoute(
        path: '/group/details',
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          final group = extra['group'] as Group;
          return Scaffold(body: Text('DETAIL ${group.name}'));
        },
      ),
      GoRoute(
        path: '/group/edit',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupEdit(
            saveOverride: (groupId, formValue) async {
              captured.add(formValue);
              return saved;
            },
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fills in a group name and taps Create.
Future<void> _createNamed(WidgetTester tester, String name) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.enterText(
    find.widgetWithText(TextFormField, l10n.groupNameHint),
    name,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.tap(find.text(l10n.createGroup));
  await tester.pumpAndSettle();
  // Drain the success SnackBar's dismiss timer so nothing outlives the test.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Pumps the group detail page inside a GoRouter whose `/group/edit` route is a
/// probe, so a tap on the add-members affordance can be observed landing on the
/// member surface.
Future<void> _pumpGroupDetail(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/group/details',
    routes: [
      GoRoute(
        path: '/group/details',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupDetail(group: _group()),
        ),
      ),
      GoRoute(
        path: '/group/edit',
        builder: (context, state) =>
            const Scaffold(body: Text('MEMBER SURFACE')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupDetailProvider('g1').overrideWith(_StubGroupDetail.new),
        expenseListProvider('g1').overrideWith(_StubExpenseList.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // Never pumpAndSettle here: the loading shimmer repeats forever. Two pumps
  // are enough to resolve the stubbed providers and build the header.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  // U2-T1 — criterion 4 (landing)
  testWidgets('a successful create lands on the NEW group detail page', (
    tester,
  ) async {
    final captured = <Map<String, dynamic>>[];
    await _pumpCreateFlow(
      tester,
      saved: _group(name: 'Trip to Rome'),
      captured: captured,
    );

    await _createNamed(tester, 'Trip to Rome');

    expect(captured, hasLength(1));
    expect(
      find.text('DETAIL Trip to Rome'),
      findsOneWidget,
      reason: 'the create hand-off opens the saved group, not the group list',
    );
  });

  // U2-T2 — criterion 3 (nothing member-shaped leaves the create form)
  testWidgets('the create write path is handed no member field at all', (
    tester,
  ) async {
    final captured = <Map<String, dynamic>>[];
    await _pumpCreateFlow(
      tester,
      saved: _group(name: 'Trip to Rome'),
      captured: captured,
    );

    await _createNamed(tester, 'Trip to Rome');

    expect(captured.single.containsKey('group_members'), isFalse);
    expect(captured.single['name'], 'Trip to Rome');
    // GroupRepository.resolveSaveMembers turns that absence into exactly one
    // row — the creator (proven in test/model/group_repository_test.dart).
  });

  // U2-T3 — criterion 4 (affordance)
  testWidgets(
    'the group detail page carries a single-tap add-members affordance',
    (tester) async {
      await _pumpGroupDetail(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final addMembers = find.byWidgetPredicate(
        (w) => w is HeaderIconButton && w.tooltip == l10n.groupAddMembersAction,
      );

      expect(addMembers, findsOneWidget);
      expect(
        find.descendant(of: find.byType(DeunHeader), matching: addMembers),
        findsOneWidget,
        reason: 'it sits in the always-visible header row',
      );
      expect(
        find.byIcon(Icons.group_add).hitTestable(),
        findsOneWidget,
        reason: 'visible and tappable without scrolling',
      );
      // Additive: the existing search and edit actions are untouched.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // ONE tap reaches the surface where members are added.
      await tester.tap(addMembers);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MEMBER SURFACE'), findsOneWidget);
    },
  );
}
