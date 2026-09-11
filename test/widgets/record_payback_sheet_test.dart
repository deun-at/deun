import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/payback_request.dart';
import 'package:deun/pages/groups/presentation/record_payback_sheet.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GroupMember _member(String email, String name, {DateTime? removedAt}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}

Group _group({List<GroupMember>? members}) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = false;
  g.createdAt = '';
  g.userId = null;
  g.currencyCode = 'EUR';
  g.groupMembers =
      members ??
      [
        _member('ann@test.com', 'Ann'),
        _member('bob@test.com', 'Bob'),
        _member('carol@test.com', 'Carol'),
      ];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

/// Captures what the sheet would have written, so the test never touches the
/// network (same seam pattern as `ExpenseDetailRead.loadGroupPaybacks`).
class _Recorded {
  _Recorded({this.throws});

  /// What the write should fail with, if anything. `GroupRepository.payBack`
  /// re-resolves the plan against a fresh roster, so it really can reject what
  /// the sheet accepted.
  final Object? throws;

  String? groupId;
  String? paidBy;
  String? paidFor;
  double? amount;
  int calls = 0;
}

Future<void> _pump(
  WidgetTester tester, {
  required Group group,
  _Recorded? recorded,
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
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(
            body: RecordPaybackSheet(
              group: group,
              recordPayback: recorded == null
                  ? null
                  : ({
                      required String groupId,
                      required String paidBy,
                      required String paidFor,
                      required double amount,
                    }) async {
                      recorded.calls++;
                      recorded.groupId = groupId;
                      recorded.paidBy = paidBy;
                      recorded.paidFor = paidFor;
                      recorded.amount = amount;
                      final failure = recorded.throws;
                      if (failure != null) throw failure;
                    },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a picker row and chooses [name] from the shared paid-by sheet.
Future<void> _pick(WidgetTester tester, Key rowKey, String name) async {
  await tester.tap(find.byKey(rowKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Enters 10 on the amount keypad and confirms.
Future<void> _enterTen(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('record_payback_amount')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('keypad_1')));
  await tester.tap(find.byKey(const ValueKey('keypad_0')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
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

  // 34 — criterion: any member may record "X paid Y" for any two members.
  testWidgets('records a payment between two members who are not me', (
    tester,
  ) async {
    final recorded = _Recorded();
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');
    await _enterTen(tester);

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pumpAndSettle();

    expect(recorded.calls, 1);
    expect(recorded.groupId, 'g1');
    expect(recorded.paidBy, 'ann@test.com');
    expect(recorded.paidFor, 'bob@test.com');
    expect(recorded.amount, 10);
  });

  // 35 — criterion: payer == payee is rejected BEFORE any write.
  testWidgets('the same member on both sides writes nothing and says why', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded();
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Ann');
    await _enterTen(tester);

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pumpAndSettle();

    expect(recorded.calls, 0);
    expect(find.text(l10n.paybackRecordSamePersonError), findsOneWidget);
    // The sheet stays open so the mistake can be corrected.
    expect(find.byType(RecordPaybackSheet), findsOneWidget);
  });

  // 36 — criterion: a zero amount writes nothing.
  testWidgets('submitting without an amount writes nothing', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded();
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pumpAndSettle();

    expect(recorded.calls, 0);
    expect(find.text(l10n.paybackRecordAmountError), findsOneWidget);
  });

  // 37 — criterion: a soft-removed member cannot be named, and the picker does
  // not offer them in the first place.
  testWidgets('a soft-removed member is not offered as a payer', (
    tester,
  ) async {
    await _pump(
      tester,
      group: _group(
        members: [
          _member('ann@test.com', 'Ann'),
          _member('bob@test.com', 'Bob'),
          _member(
            'carol@test.com',
            'Carol',
            removedAt: DateTime.utc(2026, 8, 15),
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('record_payback_paid_by')));
    await tester.pumpAndSettle();

    // PaidBySheet binds to `group.activeMembers`, and renders each member's
    // name as BOTH the tile title and (via fullUsername, which falls back to the
    // display name) its subtitle — hence findsWidgets, not findsOneWidget.
    expect(find.text('Ann'), findsWidgets);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Carol'), findsNothing);
  });

  testWidgets('each member picker is titled for the side it is picking', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      group: _group(
        members: [
          _member('ann@test.com', 'Ann'),
          _member('bob@test.com', 'Bob'),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('record_payback_paid_to')));
    await tester.pumpAndSettle();

    // Both sides reuse PaidBySheet, which hardcoded the "Paid by" title — so
    // picking the payee announced itself as picking the payer.
    final titles = tester
        .widgetList<SheetScaffold>(find.byType(SheetScaffold))
        .map((s) => s.title)
        .toList();
    expect(titles, contains(l10n.paybackRecordPaidToLabel));
    expect(titles, isNot(contains(l10n.paidBySheetTitle)));
  });

  // 38 — the recorded payment names both parties back to the user.
  testWidgets('a recorded payment confirms who paid whom', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded();
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');
    await _enterTen(tester);

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        l10n.paybackRecordSuccess('Ann', 'Bob', l10n.toCurrency(10, 'EUR')),
      ),
      findsOneWidget,
    );
  });

  // 44 — the repository re-resolves against a FRESH roster, so a member removed
  // while the sheet was open is rejected there and not by the sheet's own check.
  // That reason must reach the user instead of the generic write error.
  testWidgets('a rejection from the write says why, not "could not pay back"', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded(
      throws: const PaybackRejectedException(
        PaybackRejected(
          reason: PaybackRejection.payeeNotInGroup,
          displayName: 'Bob',
        ),
      ),
    );
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');
    await _enterTen(tester);

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pump();
    await tester.pump();

    expect(recorded.calls, 1);
    expect(find.text(l10n.paybackRecordNotMemberError('Bob')), findsOneWidget);
    expect(find.text(l10n.payBackError), findsNothing);
    // The sheet stays open so the mistake can be corrected.
    expect(find.byType(RecordPaybackSheet), findsOneWidget);
  });

  // 45 — anything else is still the generic write error.
  testWidgets('an unexpected write failure keeps the generic error', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded(throws: Exception('offline'));
    await _pump(tester, group: _group(), recorded: recorded);

    await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
    await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');
    await _enterTen(tester);

    await tester.tap(find.byKey(const ValueKey('record_payback_submit')));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.payBackError), findsOneWidget);
  });

  // 39 — the submit button exists and is enabled at rest (the guard is the
  // resolver, not a disabled button, so the user always gets a reason).
  testWidgets('the confirm CTA is the sheet footer button', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, group: _group());

    expect(
      find.widgetWithText(PrimaryButton, l10n.paybackRecordSubmit),
      findsOneWidget,
    );
    expect(find.text(l10n.paybackRecordTitle), findsOneWidget);
  });

  group('copy exists in both languages', () {
    late AppLocalizations en;
    late AppLocalizations de;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      de = await AppLocalizations.delegate.load(const Locale('de'));
    });

    // 40 — criterion: all new copy exists in EN and DE.
    test('every new string is translated, not copied', () {
      final pairs = <String, String>{
        en.paymentRecordPayment: de.paymentRecordPayment,
        en.paybackRecordTitle: de.paybackRecordTitle,
        en.paybackRecordSubtitle: de.paybackRecordSubtitle,
        en.paybackRecordPaidByLabel: de.paybackRecordPaidByLabel,
        en.paybackRecordPaidToLabel: de.paybackRecordPaidToLabel,
        en.paybackRecordSubmit: de.paybackRecordSubmit,
        en.paybackRecordSamePersonError: de.paybackRecordSamePersonError,
        en.paybackRecordAmountError: de.paybackRecordAmountError,
      };

      pairs.forEach((english, german) {
        expect(german, isNotEmpty);
        expect(german, isNot(english));
      });
    });

    // 41 — the placeholdered strings interpolate in both languages.
    test(
      'the placeholdered strings carry their arguments in both languages',
      () {
        for (final l10n in [en, de]) {
          expect(l10n.paybackRecordedBy('Ann'), contains('Ann'));
          expect(l10n.paybackRecordNotMemberError('Carol'), contains('Carol'));
          expect(
            l10n.paybackRecordSuccess('Ann', 'Bob', '10,00 €'),
            allOf(contains('Ann'), contains('Bob'), contains('10,00 €')),
          );
          expect(
            l10n.groupPayBackOnBehalfNotificationTitle('Me', 'Trip'),
            allOf(contains('Me'), contains('Trip')),
          );
          expect(
            l10n.groupPayBackOnBehalfNotificationBody('Ann', 'Bob', '10,00 €'),
            allOf(contains('Ann'), contains('Bob'), contains('10,00 €')),
          );
        }
      },
    );
  });
}
