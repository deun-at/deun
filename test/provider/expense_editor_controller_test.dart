/// The expense editor's rules, proven on its controller with no widget:
/// rate ownership, the latest-answer rule, the conversion a save hands over,
/// the save and delete refusals, what is remembered, and what happens when
/// the editor closes while work is still out.
library;

import 'dart:async';
import 'dart:convert';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:deun/pages/expenses/data/expense_conversion.dart';
import 'package:deun/pages/expenses/data/expense_deletion_impact.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/pages/expenses/provider/expense_editor_controller.dart';
import 'package:deun/pages/expenses/service/rate_source.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The editor fixtures, shared with the suite that owns the rate field rather
// than copied. `show` keeps that file's own `main` out of this one.
import '../widgets/expense_editor_currency_rate_test.dart'
    show
        StubLookup,
        closeConversionSheet,
        convertedClaimExpense,
        convertedChfExpense,
        convertedExpense,
        initTestSupabase,
        installFakePrefs,
        openConversionSheet,
        pickCurrency,
        prefsValues;

GroupMember _member(String email, String name) => GroupMember()
  ..groupId = 'g1'
  ..email = email
  ..displayName = name
  ..isGuest = false
  ..isFavorite = false;

/// An EUR group, the same `g1` the shared expense fixtures belong to.
Group _group() => Group()
  ..id = 'g1'
  ..name = 'Trip'
  ..colorValue = kBrandSeed.toARGB32()
  ..simplifiedExpenses = true
  ..currencyCode = 'EUR'
  ..groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ]
  ..expenses = [];

const _july1 = '2026-07-01';
const _july4 = '2026-07-04';

/// A Wednesday expense's rate, quoted the day before.
final _quoteJuly1 = RateQuote(
  rate: 0.9432,
  effectiveDate: DateTime(2026, 6, 30),
);

/// A Saturday expense's rate, quoted on the Friday.
final _quoteJuly4 = RateQuote(
  rate: 0.9611,
  effectiveDate: DateTime(2026, 7, 3),
);

/// No rate for any date, at once.
Future<RateQuote?> _noRate({
  required Currency base,
  required Currency quote,
  required DateTime date,
}) async => null;

/// A rate lookup that holds each date's answer back until that date is
/// released, so two requests can resolve in either order. [StubLookup]'s one
/// gate holds every date together, so it cannot stage that.
class _GatedLookup {
  _GatedLookup(this.byDate);

  final Map<String, RateQuote?> byDate;
  final Map<String, Completer<void>> _gates = {};
  final List<String> calls = [];

  Future<RateQuote?> call({
    required Currency base,
    required Currency quote,
    required DateTime date,
  }) async {
    final day = ymd(date);
    calls.add(day);
    await _gate(day).future;
    return byDate[day];
  }

  /// Lets the answer for [day] arrive.
  void release(String day) => _gate(day).complete();

  Completer<void> _gate(String day) =>
      _gates.putIfAbsent(day, Completer<void>.new);
}

/// One opened editor as the screen holds it: args created once, and the one
/// subscription that keeps the auto-dispose controller alive.
class _Editor {
  _Editor(this.container, this.args)
    : _subscription = container.listen(
        expenseEditorControllerProvider(args),
        (_, _) {},
      );

  final ProviderContainer container;
  final ExpenseEditorArgs args;
  final ProviderSubscription<ExpenseEditorState> _subscription;

  ExpenseEditorState get state =>
      container.read(expenseEditorControllerProvider(args));

  ExpenseEditorController get controller =>
      container.read(expenseEditorControllerProvider(args).notifier);

  /// The screen going away: its subscription closes and the controller is
  /// disposed.
  Future<void> close() async {
    _subscription.close();
    await container.pump();
    expect(
      container.exists(expenseEditorControllerProvider(args)),
      isFalse,
      reason: 'precondition: the controller is disposed',
    );
  }
}

/// A write the test holds open; records each conversion it was handed.
class _GatedWrite {
  final _gate = Completer<void>();
  final conversions = <ExpenseConversion>[];

  Future<void> call(ExpenseConversion conversion) async {
    conversions.add(conversion);
    await _gate.future;
  }

  void release() => _gate.complete();
}

/// Remembering the typed rate fails after the expense write has committed.
class _ThrowingStickyRate extends StickyRateNotifier {
  int setCalls = 0;

  @override
  Future<void> setStickyRate(String groupId, Currency from, double rate) async {
    setCalls++;
    throw Exception('disk full');
  }
}

_Editor _open({
  Expense? expense,
  RateLookup? lookupRate,
  List<Override> overrides = const [],
}) => _Editor(
  ProviderContainer.test(overrides: overrides),
  ExpenseEditorArgs(
    group: _group(),
    expense: expense,
    lookupRate: lookupRate ?? _noRate,
  ),
);

/// Picks CHF on the harness date and lets the pick's own prefill settle.
Future<void> _pickChf(_Editor editor) async {
  await editor.controller.pickEntryCurrency(
    Currency.chf,
    expenseDate: DateTime(2026, 7, 1),
  );
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installFakePrefs);

  group('rate ownership', () {
    test(
      'a prefill requested before the user typed never replaces the typed rate',
      () async {
        final lookup = _GatedLookup({_july1: _quoteJuly1});
        final editor = _open(lookupRate: lookup.call);
        await _pickChf(editor);
        expect(lookup.calls, [
          _july1,
        ], reason: 'precondition: the prefill is out');
        final pickTimeDate = editor.state.rateDate;
        expect(pickTimeDate, isNotNull);

        editor.controller.rateTyped('0.95');
        lookup.release(_july1);
        await pumpEventQueue();

        final state = editor.state;
        expect(state.rateText, '0.95');
        expect(state.rateOrigin, RateOrigin.user);
        expect(state.rateDate, pickTimeDate);
        expect(state.prefilledRateDate, isNull);
      },
    );

    test(
      'a date change requests no lookup for an expense opened on its frozen rate',
      () async {
        final lookup = StubLookup({_july4: _quoteJuly4});
        final editor = _open(
          expense: convertedExpense(),
          lookupRate: lookup.call,
        );

        await editor.controller.prefillRate(expenseDate: DateTime(2026, 7, 4));

        expect(lookup.calls, isEmpty);
        expect(editor.state.rateText, '0.0058');
        expect(editor.state.rateOrigin, RateOrigin.user);
      },
    );

    test(
      'a date change requests no lookup for a currency picked onto a remembered rate',
      () async {
        prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9432});
        final lookup = StubLookup({_july1: _quoteJuly1, _july4: _quoteJuly4});
        final editor = _open(lookupRate: lookup.call);
        await _pickChf(editor);

        await editor.controller.prefillRate(expenseDate: DateTime(2026, 7, 4));

        expect(lookup.calls, isEmpty);
        expect(editor.state.rateText, '0.9432');
        expect(editor.state.rateOrigin, RateOrigin.user);
      },
    );
  });

  group('latest prefill wins', () {
    test(
      'only the latest request lands, dated with its own effective date',
      () async {
        final lookup = _GatedLookup({_july1: _quoteJuly1, _july4: _quoteJuly4});
        final editor = _open(lookupRate: lookup.call);
        await editor.controller.pickEntryCurrency(
          Currency.chf,
          expenseDate: DateTime(2026, 7, 1),
        );
        final moved = editor.controller.prefillRate(
          expenseDate: DateTime(2026, 7, 4),
        );
        await pumpEventQueue();
        expect(lookup.calls, [
          _july1,
          _july4,
        ], reason: 'precondition: both requests are out');

        lookup.release(_july4);
        await moved;
        lookup.release(_july1);
        await pumpEventQueue();

        final state = editor.state;
        expect(state.rateText, '0.9611');
        expect(state.prefilledRateDate, '2026-07-03');
        expect(state.rateOrigin, RateOrigin.prefilled);
        expect(state.rateUnavailable, isFalse);
      },
    );

    test(
      'an empty answer for the new date clears a prefill that had already landed',
      () async {
        final lookup = _GatedLookup({_july1: _quoteJuly1, _july4: null});
        final editor = _open(lookupRate: lookup.call);
        await _pickChf(editor);
        lookup.release(_july1);
        await pumpEventQueue();
        expect(
          editor.state.rateText,
          '0.9432',
          reason: 'precondition: the 2026-07-01 answer landed',
        );

        final moved = editor.controller.prefillRate(
          expenseDate: DateTime(2026, 7, 4),
        );
        await pumpEventQueue();
        lookup.release(_july4);
        await moved;

        final state = editor.state;
        expect(state.rateText, '');
        expect(state.prefilledRateDate, isNull);
        expect(state.rateOrigin, RateOrigin.none);
        expect(state.rateUnavailable, isTrue);
      },
    );

    test(
      'an older answer arriving after an empty one for the new date is dropped',
      () async {
        final lookup = _GatedLookup({_july1: _quoteJuly1, _july4: null});
        final editor = _open(lookupRate: lookup.call);
        await editor.controller.pickEntryCurrency(
          Currency.chf,
          expenseDate: DateTime(2026, 7, 1),
        );
        final moved = editor.controller.prefillRate(
          expenseDate: DateTime(2026, 7, 4),
        );
        await pumpEventQueue();

        lookup.release(_july4);
        await moved;
        lookup.release(_july1);
        await pumpEventQueue();

        final state = editor.state;
        expect(state.rateText, '');
        expect(state.prefilledRateDate, isNull);
        expect(state.rateOrigin, RateOrigin.none);
        expect(state.rateUnavailable, isTrue);
      },
    );
  });

  group('switch back', () {
    test(
      'switching back converts 3000 JPY at 0.0058 to 17.40 and clears the rate',
      () {
        final editor = _open(expense: convertedExpense());

        final texts = editor.controller.switchBackToGroupCurrency(
          enteredTexts: ['3000'],
          quantities: [1],
        );

        expect(texts, ['17.40']);
        final state = editor.state;
        expect(state.entryCurrency, Currency.eur);
        expect(state.rateText, '');
        expect(state.rateDate, isNull);
        expect(state.rateOrigin, RateOrigin.none);
        expect(state.prefilledRateDate, isNull);
        expect(state.conversion.isIdentity, isTrue);
      },
    );

    test('switching back keeps a qty-3 10.00 CHF line at its 28.30 total', () {
      final editor = _open(expense: convertedClaimExpense());

      final texts = editor.controller.switchBackToGroupCurrency(
        enteredTexts: ['10'],
        quantities: [3],
      );

      expect(
        roundCurrency(double.parse(texts.single) * 3, Currency.eur),
        28.30,
      );
      expect(editor.state.rateText, '');
    });
  });

  group('remembered rates change under an open editor', () {
    test(
      'stored remembered rates loading after the editor opened leave the currency and rate',
      () async {
        prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9});
        final editor = _open(expense: convertedChfExpense());
        editor.controller.rateTyped('0.95');

        // The screen reads the remembered rates; the first read starts the load.
        editor.container.listen(stickyRateProvider, (_, _) {});
        await editor.container.read(stickyRateProvider.notifier).hydrated;
        await editor.container.pump();
        expect(
          editor.container.read(stickyRateProvider),
          {'g1|CHF': 0.9},
          reason:
              'precondition: the stored rates loaded after the editor opened',
        );

        final state = editor.state;
        expect(state.entryCurrency, Currency.chf);
        expect(state.rateText, '0.95');
        expect(state.rateOrigin, RateOrigin.user);
      },
    );
  });

  group('closing mid-lookup', () {
    test(
      'closing the editor while a lookup is out writes nothing when it answers',
      () async {
        final lookup = _GatedLookup({_july1: _quoteJuly1});
        final editor = _open(lookupRate: lookup.call);
        await _pickChf(editor);
        expect(
          lookup.calls,
          hasLength(1),
          reason: 'precondition: the lookup is out',
        );

        await editor.close();
        lookup.release(_july1);
        // A state write on the disposed Ref throws UnmountedRefException inside
        // the unawaited prefill, which the test zone reports as a failure.
        await pumpEventQueue();

        expect(lookup.calls, hasLength(1));
      },
    );
  });
  group('the conversion a save hands over', () {
    test(
      'in the group currency the write receives the identity conversion',
      () async {
        final editor = _open();
        final writes = <ExpenseConversion>[];

        final outcome = await editor.controller.save(
          total: 20,
          write: (c) async => writes.add(c),
        );

        expect(outcome, EditorSaveOutcome.saved);
        expect(writes.single.isIdentity, isTrue);
        expect(writes.single.groupCurrency, Currency.eur);
        expect(writes.single.rate, isNull);
      },
    );

    test(
      'a prefilled foreign rate reaches the write dated with its effective date',
      () async {
        final editor = _open(
          lookupRate: StubLookup({_july1: _quoteJuly1}).call,
        );
        await _pickChf(editor);
        final writes = <ExpenseConversion>[];

        await editor.controller.save(
          total: 20,
          write: (c) async => writes.add(c),
        );

        expect(writes.single.entryCurrency, Currency.chf);
        expect(writes.single.rate, 0.9432);
        expect(writes.single.rateDate, '2026-06-30');
      },
    );

    test(
      'a typed foreign rate reaches the write dated with the pick-time date',
      () async {
        final today = ymd(DateTime.now());
        final editor = _open();
        await _pickChf(editor);
        editor.controller.rateTyped('0.95');
        final writes = <ExpenseConversion>[];

        await editor.controller.save(
          total: 20,
          write: (c) async => writes.add(c),
        );

        expect(writes.single.entryCurrency, Currency.chf);
        expect(writes.single.rate, 0.95);
        expect(writes.single.rateDate, today);
      },
    );
  });

  group('refusals, single flight and remembered rates', () {
    test('a non-positive total writes nothing and says so', () async {
      final editor = _open();
      final writes = <ExpenseConversion>[];

      expect(
        await editor.controller.save(
          total: 0,
          write: (c) async => writes.add(c),
        ),
        EditorSaveOutcome.refusedZeroTotal,
      );
      expect(
        await editor.controller.save(
          total: -5,
          write: (c) async => writes.add(c),
        ),
        EditorSaveOutcome.refusedZeroTotal,
      );

      expect(writes, isEmpty);
      expect(editor.state.saveStatus, EditorSaveStatus.idle);
    });

    test(
      'a foreign currency with no rate writes nothing and says so',
      () async {
        final editor = _open(); // _noRate: the prefill finds nothing
        await _pickChf(editor);
        expect(
          editor.state.rateUnavailable,
          isTrue,
          reason: 'precondition: no rate in the field',
        );
        final writes = <ExpenseConversion>[];

        final outcome = await editor.controller.save(
          total: 20,
          write: (c) async => writes.add(c),
        );

        expect(outcome, EditorSaveOutcome.refusedNoRate);
        expect(writes, isEmpty);
        expect(editor.state.saveStatus, EditorSaveStatus.idle);
      },
    );

    test('a save started while a save is out writes nothing', () async {
      final editor = _open();
      final write = _GatedWrite();
      final first = editor.controller.save(total: 20, write: write.call);
      expect(editor.state.saveStatus, EditorSaveStatus.busy);

      expect(
        await editor.controller.save(total: 20, write: write.call),
        EditorSaveOutcome.ignoredInFlight,
      );

      write.release();
      expect(await first, EditorSaveOutcome.saved);
      expect(write.conversions, hasLength(1));
    });

    test('a save started while a delete is out writes nothing', () async {
      final editor = _open();
      final writes = <ExpenseConversion>[];
      Future<EditorSaveOutcome> tapSave() =>
          editor.controller.save(total: 20, write: (c) async => writes.add(c));

      final probe = Completer<ExpenseDeletionImpact>();
      final probing = editor.controller.probeDeletion(() => probe.future);
      expect(await tapSave(), EditorSaveOutcome.ignoredInFlight);
      probe.complete(ExpenseDeletionImpact.none);
      expect(await probing, ExpenseDeletionImpact.none);

      final deleteGate = Completer<void>();
      final deleting = editor.controller.delete(() => deleteGate.future);
      expect(await tapSave(), EditorSaveOutcome.ignoredInFlight);
      deleteGate.complete();
      expect(await deleting, EditorDeleteOutcome.deleted);

      expect(writes, isEmpty);
    });

    test(
      'after a good write a typed foreign rate is remembered for the group and currency',
      () async {
        final editor = _open();
        await _pickChf(editor);
        editor.controller.rateTyped('0.95');

        final outcome = await editor.controller.save(
          total: 20,
          write: (_) async {},
        );

        expect(outcome, EditorSaveOutcome.saved);
        expect(
          editor.container
              .read(stickyRateProvider.notifier)
              .stickyRate('g1', Currency.chf),
          0.95,
        );
        expect(jsonDecode(prefsValues[kStickyRatesPrefKey]!), {'g1|CHF': 0.95});
      },
    );

    test('a prefilled rate is never remembered', () async {
      final editor = _open(lookupRate: StubLookup({_july1: _quoteJuly1}).call);
      await _pickChf(editor);
      expect(
        editor.state.rateOrigin,
        RateOrigin.prefilled,
        reason: 'precondition',
      );

      await editor.controller.save(total: 20, write: (_) async {});

      expect(
        editor.container
            .read(stickyRateProvider.notifier)
            .stickyRate('g1', Currency.chf),
        isNull,
      );
    });

    test(
      'a rate that cannot be remembered still reports the save as succeeded',
      () async {
        final sticky = _ThrowingStickyRate();
        final editor = _open(
          overrides: [stickyRateProvider.overrideWith(() => sticky)],
        );
        await _pickChf(editor);
        editor.controller.rateTyped('0.95');
        final writes = <ExpenseConversion>[];

        final outcome = await editor.controller.save(
          total: 20,
          write: (c) async => writes.add(c),
        );

        expect(outcome, EditorSaveOutcome.saved);
        expect(writes, hasLength(1));
        expect(sticky.setCalls, 1);
        expect(editor.state.saveStatus, EditorSaveStatus.done);
      },
    );

    test('a failed write remembers nothing and returns to idle', () async {
      final editor = _open();
      await _pickChf(editor);
      editor.controller.rateTyped('0.95');

      final outcome = await editor.controller.save(
        total: 20,
        write: (_) async => throw Exception('offline'),
      );

      expect(outcome, EditorSaveOutcome.failed);
      expect(editor.state.saveStatus, EditorSaveStatus.idle);
      expect(
        editor.container
            .read(stickyRateProvider.notifier)
            .stickyRate('g1', Currency.chf),
        isNull,
      );
    });
  });

  group('closing mid-write', () {
    test(
      'closing the editor while a write is out neither writes state nor remembers the rate',
      () async {
        final editor = _open();
        await _pickChf(editor);
        editor.controller.rateTyped('0.95');
        final write = _GatedWrite();
        final saving = editor.controller.save(total: 20, write: write.call);

        // `close()` pumps the container, so the controller is already disposed
        // when the write resolves: this proves the rule only after disposal has
        // run. In the app the auto-dispose controller outlives the unmounted
        // screen until the scheduler runs, and a write that resolves in that gap
        // still remembers the typed rate (the user's own, after a committed
        // write); `canPop` is false while a save is busy, so only an outside
        // route teardown can reach it.
        await editor.close();
        write.release();
        // A state write on the disposed Ref would make `saving` complete with an
        // UnmountedRefException.
        await expectLater(saving, completes);
        await pumpEventQueue();

        expect(
          write.conversions,
          hasLength(1),
          reason: 'the write already sent is not sent again',
        );
        expect(
          editor.container
              .read(stickyRateProvider.notifier)
              .stickyRate('g1', Currency.chf),
          isNull,
        );
      },
    );
  });
  group('entries survive a change in the remembered rates', () {
    test(
      'the entries stay as they were when remembered rates load or one is reset',
      () async {
        prefsValues[kStickyRatesPrefKey] = jsonEncode({'g1|CHF': 0.9});
        final editor = _open(
          lookupRate: StubLookup({_july1: _quoteJuly1}).call,
        );
        editor.controller.setMode(
          EditorMode.itemized,
          quickAmountText: '12.50',
          itemizedTotal: 12.5,
          firstAmountFieldText: '12.50',
        );
        editor.controller.addEntry(quickAmountText: '12.50');
        List<(int, String?)> entries() => [
          for (final e in editor.state.entries) (e.index, e.initialAmount),
        ];
        final before = entries();
        expect(before, [(0, '12.50'), (1, null)], reason: 'precondition');

        editor.container.listen(stickyRateProvider, (_, _) {});
        await editor.container.read(stickyRateProvider.notifier).hydrated;
        await editor.container.pump();
        expect(entries(), before);

        await _pickChf(editor);
        await editor.controller.resetStickyRate(
          expenseDate: DateTime(2026, 7, 1),
        );
        await pumpEventQueue();
        expect(
          editor.state.rateText,
          '0.9432',
          reason: 'precondition: the reset fetched',
        );

        expect(entries(), before);
        expect(editor.state.editorMode, EditorMode.itemized);
        expect(editor.state.entryCurrency, Currency.chf);
      },
    );
  });

  group('a fresh session per editor', () {
    setUpAll(initTestSupabase);

    tearDownAll(() async {
      await Supabase.instance.dispose();
    });

    testWidgets(
      'a new editor on the same group starts fresh after one closed unsaved',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final group = _group();
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
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Theme(
                          data: getThemeData(
                            context,
                            kBrandSeed,
                            Brightness.light,
                          ).copyWith(splashFactory: NoSplash.splashFactory),
                          child: ExpenseDetail(
                            group: group,
                            lookupRate: _noRate,
                          ),
                        ),
                      ),
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        );

        Future<void> openEditor() async {
          await tester.tap(find.text('OPEN'));
          await tester.pumpAndSettle();
          // A new expense opens the amount keypad on its first frame.
          if (find.byType(AmountKeypadSheet).evaluate().isNotEmpty) {
            Navigator.of(tester.element(find.byType(AmountKeypadSheet))).pop();
            await tester.pumpAndSettle();
          }
        }

        await openEditor();
        await pickCurrency(tester, 'CHF');
        await openConversionSheet(tester);
        await tester.enterText(
          find.byKey(const ValueKey('expense_rate_field')),
          '0.95',
        );
        await tester.pumpAndSettle();
        await closeConversionSheet(tester);
        await tester.tap(find.text(l10n.editorModeItemized));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.addItemByHand));
        await tester.pumpAndSettle();
        expect(
          find.byType(ExpenseEntryWidget),
          findsNWidgets(2),
          reason: 'precondition',
        );

        await tester.tap(
          find.descendant(
            of: find.byType(DeunHeader),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.discardChangesConfirm));
        await tester.pumpAndSettle();
        expect(
          find.byType(ExpenseDetail),
          findsNothing,
          reason: 'precondition: closed unsaved',
        );

        await openEditor();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('expense_entry_currency')),
            matching: find.text('EUR'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('expense_conversion_row')),
          findsNothing,
        );
        expect(
          tester
              .widget<AppSegmentedControl<EditorMode>>(
                find.byType(AppSegmentedControl<EditorMode>),
              )
              .value,
          EditorMode.quick,
        );
        expect(find.byType(ExpenseEntryWidget), findsOneWidget);
        expect(
          tester
              .state<FormBuilderState>(find.byType(FormBuilder))
              .fields['expense_entry[0][amount]']
              ?.value,
          isNull,
        );
      },
    );
  });
}
