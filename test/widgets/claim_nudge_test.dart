import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/provider/claim_notifier.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// F175: the Nudge pill must fire a real push. This spies the push sender (via
/// [ClaimPage.sendNotificationOverride]) and asserts `_nudge()` calls it as
/// `sendNotification('expense', expense.id, <other members>)` — mirroring
/// sendExpenseNotification and never touching the live `push` Edge Function.

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
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = false;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

/// A single unclaimed unit so the callout (and its Nudge pill) renders.
ExpenseEntry _unit(int index, String id, String name, double amount) {
  final e = ExpenseEntry(index: index);
  e.id = id;
  e.expenseId = 'e1';
  e.name = name;
  e.amount = amount;
  e.quantity = 1;
  e.splitMode = 'claim';
  e.createdAt = '';
  e.itemGroupId = null;
  e.expenseEntryShares = const [];
  return e;
}

Expense _expense() {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Supermarket';
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.amount = 4;
  e.expenseEntries = {'u1': _unit(0, 'u1', 'Bread', 4)};
  e.groupMemberShareStatistic = {};
  return e;
}

class _FakeClaimNotifier extends ClaimNotifier {
  _FakeClaimNotifier(this._expense);

  final Expense _expense;

  @override
  Future<Expense> build(String groupId, String expenseId) async => _expense;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      },
    );
    // sendNotification reads supabase.auth.currentUser; initialize so that
    // lookup does not throw even though the real helper is never called here.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('F175: tapping Nudge sends an expense push to the members',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final group = _group();
    final expense = _expense();

    final calls = <List<Object?>>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimProvider(group.id, expense.id)
              .overrideWith(() => _FakeClaimNotifier(expense)),
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
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Theme(
                data: getThemeData(context, kBrandSeed, Brightness.light)
                    .copyWith(splashFactory: NoSplash.splashFactory),
                child: ClaimPage(
                  group: group,
                  expense: expense,
                  sendNotificationOverride:
                      (type, objectId, receivers, title, body) async {
                    calls.add([type, objectId, receivers, title, body]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the Nudge pill in the unclaimed callout.
    await tester.tap(find.text(l10n.claimNudge));
    await tester.pumpAndSettle();

    // Local confirmation snackbar still shows.
    expect(find.text(l10n.claimNudgeSent), findsOneWidget);

    // Exactly one push, wired like sendExpenseNotification.
    expect(calls, hasLength(1));
    final call = calls.single;
    expect(call[0], 'expense'); // type
    expect(call[1], 'e1'); // objectId = expense.id
    // Receivers = the whole group (the fallback set for unowned unclaimed
    // units); the real sendNotification strips the current user server-side.
    expect(call[2], {'a@test.com', 'b@test.com'});
    // Copy is built sender-side and non-empty.
    expect((call[3] as String).isNotEmpty, isTrue); // title
    expect((call[4] as String).isNotEmpty, isTrue); // body
  });
}
