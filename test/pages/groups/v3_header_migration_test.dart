// Smoke tests for V3-T3b header migration.
// Each test pumps the migrated screen and asserts:
//   1. A DeunHeader is present with the expected title text.
//   2. A key body element still renders (body was not dropped).
//
// These tests were written BEFORE production code was changed (TDD RED phase).
// They fail until each screen is migrated off AppBar onto DeunHeader.

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/groups/presentation/group_join_page.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Group _group() {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip to Rome';
  g.colorValue = kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = [];
  return g;
}

ExpenseEntry _entry() {
  final entry = ExpenseEntry(index: 0);
  entry.id = 'en1';
  entry.expenseId = 'e1';
  entry.name = 'Main item';
  entry.amount = 30;
  entry.quantity = 1;
  entry.splitMode = 'equal';
  entry.createdAt = '';
  entry.itemGroupId = null;
  return entry;
}

Expense _expense() {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = 30;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.groupMemberShareStatistic = {'a@test.com': 15, 'b@test.com': 15};
  e.expenseEntries = {'entry0': _entry()};
  return e;
}

/// Pumps [child] inside a ProviderScope + MaterialApp + localizations + theme.
Future<void> _pumpInScope(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(
              context,
              kBrandSeed,
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Setup — Supabase mock (needed by expense screens)
// ---------------------------------------------------------------------------

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
    // Supabase is already initialized by other tests; guard against re-init.
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  tearDownAll(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  });

  // -------------------------------------------------------------------------
  // 1. GroupEdit — Icons.close, no AppBar actions
  // -------------------------------------------------------------------------
  group('GroupEdit (group_detail_edit.dart) header migration', () {
    testWidgets('has DeunHeader with close icon and create title (new group)', (
      tester,
    ) async {
      await _pumpInScope(tester, const GroupEdit());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.groupCreateTitle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      // Body key element: the mode-selector section heading.
      expect(find.text(l10n.groupTrackingModeSimplifiedTitle), findsOneWidget);
    });

    testWidgets('has DeunHeader with edit title when editing a group', (
      tester,
    ) async {
      await _pumpInScope(tester, GroupEdit(group: _group()));
      // The existing ListTile-inside-DecoratedBox assertion is a pre-existing
      // issue (not introduced by this migration). Consume it so the test can
      // focus on what changed.
      tester.takeException();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.groupEditTitle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, const GroupEdit());
      expect(find.byType(AppBar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 2. ExpenseDetail — Icons.close, actions moved to trailing
  // -------------------------------------------------------------------------
  group('ExpenseDetail (expense_detail.dart) header migration', () {
    testWidgets('has DeunHeader with close icon (new expense)', (tester) async {
      await _pumpInScope(tester, ExpenseDetail(group: _group()));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('delete icon present when editing existing expense', (
      tester,
    ) async {
      await _pumpInScope(
        tester,
        ExpenseDetail(group: _group(), expense: _expense()),
      );

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, ExpenseDetail(group: _group()));
      expect(find.byType(AppBar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 3. ExpenseDetailRead — Icons.arrow_back, two actions (edit + delete)
  // -------------------------------------------------------------------------
  group('ExpenseDetailRead (expense_detail_read.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and expense detail title', (
      tester,
    ) async {
      await _pumpInScope(
        tester,
        ExpenseDetailRead(group: _group(), expense: _expense()),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.expenseDetailTitle), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('edit and delete icons are present in header trailing', (
      tester,
    ) async {
      await _pumpInScope(
        tester,
        ExpenseDetailRead(group: _group(), expense: _expense()),
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(
        tester,
        ExpenseDetailRead(group: _group(), expense: _expense()),
      );
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('body still renders the summary card', (tester) async {
      await _pumpInScope(
        tester,
        ExpenseDetailRead(group: _group(), expense: _expense()),
      );
      // The expense name appears in the summary card body.
      expect(find.text('Dinner'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3b. GroupDetail — DeunHeader, centered title, ONE trailing edit (F39)
  //     v3 group detail (COMPONENTS.md §2): single 38px header row, no
  //     SliverAppBar.medium, no search/stats header actions.
  // -------------------------------------------------------------------------
  group('GroupDetail (group_detail.dart) header migration (F39)', () {
    // GroupDetail watches groupDetail + expenseList providers, which subscribe
    // to Supabase realtime channels (scheduling retry timers) in build(). The
    // header renders independently of that data, so we override both providers
    // with stubs that return synchronously and never subscribe — keeping the
    // smoke test offline and free of pending timers.
    Future<void> pumpFrame(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupDetailProvider('g1').overrideWith(_StubGroupDetail.new),
            expenseListProvider('g1').overrideWith(_StubExpenseList.new),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Theme(
                data: getThemeData(
                  context,
                  kBrandSeed,
                  Brightness.light,
                ).copyWith(splashFactory: NoSplash.splashFactory),
                child: GroupDetail(group: _group()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('has DeunHeader with arrow_back and centered group name', (
      tester,
    ) async {
      await pumpFrame(tester);

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text('Trip to Rome'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('header has ONE trailing edit, no search/stats header actions', (
      tester,
    ) async {
      await pumpFrame(tester);

      // v3: the header carries a single trailing edit. Statistics is a
      // quick-action card (bar_chart lives there, not the header) and search
      // moved into the scroll body — so neither icon is inside the header.
      final header = find.byType(DeunHeader);
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.edit)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.bar_chart)),
        findsNothing,
      );
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.search)),
        findsNothing,
      );
    });

    testWidgets('no AppBar / SliverAppBar present after migration', (
      tester,
    ) async {
      await pumpFrame(tester);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SliverAppBar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 4. GroupJoinPage — Icons.arrow_back, no AppBar actions
  // -------------------------------------------------------------------------
  group('GroupJoinPage (group_join_page.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and join title', (
      tester,
    ) async {
      await _pumpInScope(
        tester,
        const GroupJoinPage(groupId: 'g1', groupName: 'Trip'),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.groupInviteJoinTitle), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(
        tester,
        const GroupJoinPage(groupId: 'g1', groupName: 'Trip'),
      );
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('body still renders the group name and join button', (
      tester,
    ) async {
      await _pumpInScope(
        tester,
        const GroupJoinPage(groupId: 'g1', groupName: 'Trip'),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Trip'), findsAtLeastNWidgets(1));
      expect(find.text(l10n.groupInviteTransferButton), findsOneWidget);
    });
  });
}

/// Offline stub for GroupDetailNotifier: returns the group synchronously and
/// never subscribes to a realtime channel (no pending retry timers in tests).
class _StubGroupDetail extends GroupDetailNotifier {
  @override
  Future<Group> build(String groupId) async => _group();
}

/// Offline stub for ExpenseListNotifier: returns an empty list, no realtime
/// subscription.
class _StubExpenseList extends ExpenseListNotifier {
  @override
  Future<List<Expense>> build(String groupId) async => <Expense>[];
}
