import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/payback_detail_sheet.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

Group _group() {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.currencyCode = 'EUR';
  g.simplifiedExpenses = false;
  g.createdAt = '';
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

/// A payback row as `pay_back` writes one: one entry, one share. Same
/// fixture shape as `expense_detail_read_test.dart`'s `_paybackExpense`.
Expense _payback({
  double amount = 12.5,
  String counterpartyEmail = 'b@test.com',
  String counterpartyName = 'Bob',
  String? recordedByEmail,
  String? recordedByDisplayName,
}) {
  final share = ExpenseEntryShare();
  share.expenseEntryId = 'pe1';
  share.email = counterpartyEmail;
  share.displayName = counterpartyName;
  share.percentage = 100;
  share.fixedAmount = null;
  share.parts = null;
  share.isLocked = false;
  share.createdAt = '';

  final entry = ExpenseEntry(index: 0)
    ..id = 'pe1'
    ..expenseId = 'p1'
    ..amount = amount
    ..quantity = 1
    ..splitMode = 'equal'
    ..createdAt = ''
    ..expenseEntryShares = [share];

  final e = Expense();
  e.id = 'p1';
  e.groupId = 'g1';
  e.name = 'paid_back';
  e.amount = amount;
  e.paidBy = 'a@test.com';
  e.paidByDisplayName = 'Alice';
  e.expenseDate = '2026-01-05';
  e.createdAt = '';
  e.isPaidBackRow = true;
  e.category = null;
  e.groupMemberShareStatistic = {counterpartyEmail: amount};
  e.expenseEntries = {'pe1': entry};
  e.recordedByEmail = recordedByEmail;
  e.recordedByDisplayName = recordedByDisplayName;
  return e;
}

/// Captures what the sheet would have written, so the test never touches the
/// network.
class _Deleted {
  _Deleted({this.throws});

  final Object? throws;
  String? expenseId;
  String? groupId;
  int calls = 0;

  Future<void> call(String expenseId, String groupId) async {
    calls++;
    this.expenseId = expenseId;
    this.groupId = groupId;
    final failure = throws;
    if (failure != null) throw failure;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Expense expense, {
  _Deleted? deleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/sheet',
      routes: {
        '/': (context) => const Scaffold(body: Text('BEHIND')),
        '/sheet': (context) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(
            body: PaybackDetailSheet(
              group: _group(),
              expense: expense,
              deleteExpense: deleted?.call,
            ),
          ),
        ),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  // criterion 2 — the existing settlement confirmation, naming counterparty
  // and amount.
  testWidgets('deleting names the counterparty and the amount, in the existing '
      'settlement copy', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deleted = _Deleted();
    await _pump(tester, _payback(), deleted: deleted);

    await tester.tap(find.byKey(const ValueKey('payback_detail_delete')));
    await tester.pumpAndSettle();

    // expense-delete-settled-guard's copy, unchanged — no second notion of
    // "deleting a settlement" and no new ARB key.
    expect(find.text(l10n.expenseDeletePaybackTitle), findsOneWidget);
    expect(
      find.text(l10n.expenseDeletePaybackMessage(l10n.toCurrency(12.5), 'Bob')),
      findsOneWidget,
    );
    expect(find.text(l10n.expenseDeleteItemTitle), findsNothing);
    expect(find.text(l10n.expenseDeleteSettledTitle), findsNothing);
    expect(deleted.calls, 0);
  });

  // criterion 2, cancel path — cancelling writes nothing.
  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deleted = _Deleted();
    await _pump(tester, _payback(), deleted: deleted);

    await tester.tap(find.byKey(const ValueKey('payback_detail_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(deleted.calls, 0);
    expect(find.byType(PaybackDetailSheet), findsOneWidget);
    expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
    expect(find.text(l10n.expenseDeleteError), findsNothing);
  });

  // criterion 3 — the row itself is deleted, through the shared expense
  // delete.
  testWidgets('confirming hard-deletes the payback row through the shared '
      'expense delete', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deleted = _Deleted();
    await _pump(tester, _payback(), deleted: deleted);

    await tester.tap(find.byKey(const ValueKey('payback_detail_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();

    expect(deleted.calls, 1);
    expect(deleted.expenseId, 'p1');
    expect(deleted.groupId, 'g1');
    expect(find.text(l10n.expenseDeleteSuccess), findsOneWidget);
    // The sheet is gone and the screen underneath is back.
    expect(find.byType(PaybackDetailSheet), findsNothing);
    expect(find.text('BEHIND'), findsOneWidget);
  });

  // criterion 4 — an on-behalf payback takes the same path, with no special
  // case.
  testWidgets('a payback recorded on someone else behalf deletes by the same '
      'path', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deleted = _Deleted();
    await _pump(
      tester,
      _payback(recordedByEmail: 'b@test.com', recordedByDisplayName: 'Bob'),
      deleted: deleted,
    );

    // The sheet says who recorded it — the same attribution the ledger row
    // carries.
    expect(find.text(l10n.paybackRecordedBy('Bob')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('payback_detail_delete')));
    await tester.pumpAndSettle();
    // Same confirmation, not a variant.
    expect(find.text(l10n.expenseDeletePaybackTitle), findsOneWidget);
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();

    expect(deleted.calls, 1);
    expect(deleted.expenseId, 'p1');
    expect(deleted.groupId, 'g1');
    expect(find.text(l10n.expenseDeleteSuccess), findsOneWidget);
  });

  // criterion 3, failure case — a refused delete leaves the row where it is.
  testWidgets('a failed delete keeps the sheet open and says so', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final deleted = _Deleted(throws: Exception('offline'));
    await _pump(tester, _payback(), deleted: deleted);

    await tester.tap(find.byKey(const ValueKey('payback_detail_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();

    expect(deleted.calls, 1);
    expect(find.text(l10n.expenseDeleteError), findsOneWidget);
    expect(find.text(l10n.expenseDeleteSuccess), findsNothing);
    expect(find.byType(PaybackDetailSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('payback_detail_delete')), findsOneWidget);
  });
}
