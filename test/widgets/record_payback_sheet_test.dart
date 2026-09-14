import 'dart:async';

import 'package:deun/constants.dart';
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
  _Recorded({this.throws, bool gated = false})
    : gate = gated ? Completer<void>() : null;

  /// What the write should fail with, if anything. `GroupRepository.payBack`
  /// re-resolves the plan against a fresh roster, so it really can reject what
  /// the sheet accepted.
  final Object? throws;

  /// Held open by the test so the in-flight CTA state is observable — the same
  /// gated-[Completer] seam `expense_save_status_test.dart` uses.
  final Completer<void>? gate;

  String? groupId;
  String? paidBy;
  String? paidFor;
  double? amount;
  int calls = 0;

  Future<void> call({
    required String groupId,
    required String paidBy,
    required String paidFor,
    required double amount,
  }) async {
    calls++;
    this.groupId = groupId;
    this.paidBy = paidBy;
    this.paidFor = paidFor;
    this.amount = amount;
    final held = gate;
    if (held != null) await held.future;
    final failure = throws;
    if (failure != null) throw failure;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Group group,
  _Recorded? recorded,
  bool reduceMotion = false,
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
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
      // '/sheet' on top of '/' so the post-write pop lands somewhere instead of
      // emptying the navigator — and so a confirmation held on the sheet can be
      // told apart from one painted over the screen behind it.
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
            body: RecordPaybackSheet(
              group: group,
              recordPayback: recorded?.call,
            ),
          ),
        ),
      },
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

/// The one combination every save-status test submits: Ann paid Bob 10.
Future<void> _annPaysBobTen(WidgetTester tester) async {
  await _pick(tester, const ValueKey('record_payback_paid_by'), 'Ann');
  await _pick(tester, const ValueKey('record_payback_paid_to'), 'Bob');
  await _enterTen(tester);
}

Finder get _submit => find.byKey(const ValueKey('record_payback_submit'));

/// The footer CTA's current widget, for reading its three-state flags.
PrimaryButton _cta(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_submit);

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
    // A refused plan never reaches the CTA: no spinner left behind, no check.
    expect(_cta(tester).loading, isFalse);
    expect(_cta(tester).succeeded, isFalse);
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

  // 38 / save-status-rollout — the confirmation is the check on the sheet's own
  // CTA, shown BEFORE the sheet closes. It used to be a snackbar fired one line
  // before `Navigator.pop`, so it was painted over the group detail behind.
  testWidgets('the check lands on the CTA before the sheet closes', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final recorded = _Recorded(gated: true);
    await _pump(tester, group: _group(), recorded: recorded);

    await _annPaysBobTen(tester);
    await tester.tap(_submit);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    recorded.gate!.complete();
    await tester.pump(); // the write resolves, the CTA flips to done
    await tester.pump();

    expect(find.byKey(kPrimaryButtonCheckPopKey), findsOneWidget);
    expect(_cta(tester).succeeded, isTrue);
    expect(_cta(tester).successLabel, l10n.paybackRecordedShort);
    expect(
      find.text('BEHIND'),
      findsNothing,
      reason: 'the sheet must still be on screen while the check shows',
    );

    // …and the sheet still closes once the confirmation has been seen.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(RecordPaybackSheet), findsNothing);
    expect(find.text('BEHIND'), findsOneWidget);
  });

  // save-status-rollout fixer — a user-initiated dismiss (swipe down / tap
  // the barrier) during the 700ms hold must never let the deferred
  // `Navigator.pop()` fall through to the route BENEATH the sheet. Once the
  // user pops the sheet themselves, the sheet's own route sits in
  // `_RouteLifecycle.popping` for its 200ms reverse animation — `mounted` is
  // still true for that whole window, but `ModalRoute.isCurrent` is already
  // false, so an unconditional pop targets the screen underneath instead.
  testWidgets('a user dismissal mid-hold never pops the screen underneath', (
    tester,
  ) async {
    final recorded = _Recorded(gated: true);
    final group = _group();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/root',
        routes: {
          '/root': (context) => Scaffold(
            body: Center(
              child: TextButton(
                child: const Text('ROOT'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          child: const Text('GROUP DETAIL'),
                          onPressed: () => showRecordPaybackSheet(
                            context,
                            group: group,
                            recordPayback: recorded.call,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        },
      ),
    );

    // ROOT -> pushed GROUP DETAIL -> opened sheet, exactly the real stack a
    // dismissed sheet must unwind back through to GROUP DETAIL, not ROOT.
    await tester.tap(find.text('ROOT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GROUP DETAIL'));
    await tester.pumpAndSettle();

    await _annPaysBobTen(tester);
    await tester.tap(_submit);
    await tester.pump();
    recorded.gate!.complete();
    await tester.pump(); // the write resolves, the CTA flips to done

    // 600ms into the 700ms hold, the user dismisses the sheet themselves.
    await tester.pump(const Duration(milliseconds: 600));
    Navigator.of(tester.element(find.byType(RecordPaybackSheet))).pop();
    await tester.pump(); // starts the sheet's own 200ms reverse animation

    // 150ms later (t=750ms): the hold's deferred pop fires at t=700ms,
    // while the sheet's reverse animation (due at t=800ms) is still
    // in flight — `mounted` is true, `isCurrent` is already false.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      find.text('GROUP DETAIL'),
      findsOneWidget,
      reason: 'the deferred pop must not fall through to the screen underneath',
    );
    expect(find.text('ROOT'), findsNothing);
  });

  testWidgets('a recorded payback fires no success snackbar', (tester) async {
    final recorded = _Recorded();
    await _pump(tester, group: _group(), recorded: recorded);

    await _annPaysBobTen(tester);
    await tester.tap(_submit);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(recorded.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a second tap while the write is in flight writes once', (
    tester,
  ) async {
    final recorded = _Recorded(gated: true);
    await _pump(tester, group: _group(), recorded: recorded);

    await _annPaysBobTen(tester);
    await tester.tap(_submit);
    await tester.pump();
    await tester.tap(_submit, warnIfMissed: false);
    await tester.pump();

    expect(recorded.calls, 1);

    recorded.gate!.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('reduced motion collapses the confirmation hold', (tester) async {
    final recorded = _Recorded(gated: true);
    await _pump(
      tester,
      group: _group(),
      recorded: recorded,
      reduceMotion: true,
    );

    await _annPaysBobTen(tester);
    await tester.tap(_submit);
    await tester.pump();
    recorded.gate!.complete();
    await tester.pump(); // the write resolves, the CTA flips to done

    // 200 ms of frames — well inside Motion.saveConfirmationHold, so with an
    // uncollapsed hold the sheet would still be sitting on its check and the
    // screen behind would still be covered.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      find.text('BEHIND'),
      findsOneWidget,
      reason: 'with the hold collapsed the sheet pops straight away',
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(RecordPaybackSheet), findsNothing);
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
    // A failure is words, never a check — and the CTA returns to idle so the
    // corrected payback can be submitted.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(_cta(tester).succeeded, isFalse);
    expect(_cta(tester).loading, isFalse);
    expect(_cta(tester).onPressed, isNotNull);
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
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(_cta(tester).succeeded, isFalse);
    expect(_cta(tester).loading, isFalse);
    expect(_cta(tester).onPressed, isNotNull);
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
        en.paybackRecordedShort: de.paybackRecordedShort,
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
            l10n.groupPayBackOnBehalfNotificationTitle('Me', 'Trip'),
            allOf(contains('Me'), contains('Trip')),
          );
          expect(
            l10n.groupPayBackOnBehalfNotificationBody(
              'Ann',
              'Bob',
              'EUR 10,00',
            ),
            allOf(contains('Ann'), contains('Bob'), contains('EUR 10,00')),
          );
        }
      },
    );
  });
}
