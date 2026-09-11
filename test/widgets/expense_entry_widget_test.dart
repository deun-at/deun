import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/item_icon.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/stepper_control.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// F161 D4: the include toggle is a keyed GestureDetector (index 0), not a
// Material Checkbox anymore.
Finder _toggleFinder(String email) =>
    find.byKey(ValueKey('split_toggle_0_$email'));

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  String? initialAmount = '12.00',
  bool isSingleEntry = false,
  TextEditingController? expenseLevelAmountController,
  Locale locale = const Locale('en'),
  Currency currency = Currency.eur,
}) async {
  final members = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  final entry = ExpenseEntry(index: 0);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
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
            child: Scaffold(
              body: SingleChildScrollView(
                child: FormBuilder(
                  child: ExpenseEntryWidget(
                    expenseEntry: entry,
                    index: 0,
                    onRemove: () {},
                    groupMembers: members,
                    currency: currency,
                    initialAmount: initialAmount,
                    isSingleEntry: isSingleEntry,
                    expenseLevelAmountController: expenseLevelAmountController,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

  testWidgets(
    'itemized item card shows no per-item split UI — items are shared for claiming (F118)',
    (tester) async {
      await _pump(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // No split-mode selector, no member toggles/avatars, no allocation bar.
      expect(find.byType(AppSegmentedControl<SplitMode>), findsNothing);
      expect(_toggleFinder('a@test.com'), findsNothing);
      expect(find.byType(MemberAvatar), findsNothing);
      expect(
        find.byKey(const ValueKey('split_segment_0_a@test.com')),
        findsNothing,
      );
      expect(find.text(l10n.splitSectionLabel), findsNothing);
      // The item card itself (name + amount/quantity) is still there.
      expect(find.text(l10n.itemNameHint), findsOneWidget);
      expect(find.text(l10n.itemQtyStepperValue(1)), findsOneWidget);
    },
  );

  testWidgets(
    'itemized item card shows auto icon, "each" price, line total, trash '
    'left + qty stepper right, and recomputes total on qty change (F117)',
    (tester) async {
      await _pump(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Leading auto-icon from iconForItemName — empty name → generic receipt.
      expect(find.byIcon(iconForItemName('')), findsOneWidget);
      // Inline unit-price "each" suffix.
      expect(find.text(l10n.itemPriceEachSuffix), findsOneWidget);
      // Line total = unit price (12.00) × qty (1). initialAmount seeds 12.00.
      expect(find.text(l10n.toCurrency(12)), findsOneWidget);
      // Qty stepper on the right, trash on the left.
      expect(find.byType(StepperControl), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Editing the name swaps the auto icon (pizza keyword).
      await tester.enterText(
        find.widgetWithText(TextField, l10n.itemNameHint),
        'Margherita Pizza',
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(iconForItemName('Margherita Pizza')), findsOneWidget);

      // Bumping qty to 2 recomputes the line total to 24.00.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text(l10n.itemQtyStepperValue(2)), findsOneWidget);
      expect(find.text(l10n.toCurrency(24)), findsOneWidget);
    },
  );

  testWidgets('itemized item card: editing unit price updates the line total', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Seeded unit price 12.00 → total 12.00.
    expect(find.text(l10n.toCurrency(12)), findsOneWidget);

    // F158: the unit price now opens the shared amount keypad on tap, not a
    // raw inline field. Tap the price tile → clear the "12" seed → type 5.
    await tester.tap(find.text('12.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
    await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
    await tester.tap(find.byKey(const ValueKey('keypad_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
    await tester.pumpAndSettle();
    // qty stays 1 → total tracks the new unit price.
    expect(find.text(l10n.toCurrency(5)), findsOneWidget);
  });

  testWidgets('quick split renders the 4-way SplitMode segmented control', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    expect(find.text(l10n.splitModeEqual), findsOneWidget);
    expect(find.text(l10n.splitModeShares), findsOneWidget);
    expect(find.text(l10n.splitModePercentage), findsOneWidget);
    expect(find.text(l10n.splitModeExact), findsOneWidget);
  });

  testWidgets('quick split (single entry) also shows the split-mode selector', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    expect(find.text(l10n.splitModeEqual), findsOneWidget);
    expect(find.text(l10n.splitModeExact), findsOneWidget);
  });

  testWidgets('Equal mode splits the total evenly across included members', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Default mode is Equal: €12 over 2 members → €6.00 each, no steppers.
    expect(find.byType(StepperControl), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));
    expect(
      find.text(l10n.splitEqualSummary(l10n.toCurrency(6))),
      findsOneWidget,
    );

    // Unchecking a member re-splits over the remaining one.
    await tester.tap(_toggleFinder('a@test.com'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.toCurrency(12)), findsOneWidget);
  });

  testWidgets('unchecked member shows "Not in" and no amount (F108)', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Both members in: no "Not in", two €6.00 amounts.
    expect(find.text(l10n.splitNotInLabel), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));

    // Uncheck Alice: her row shows "Not in", no €6.00 remains, and Bob's
    // per-head amount recalculates to the full €12.00.
    await tester.tap(_toggleFinder('a@test.com'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.splitNotInLabel), findsOneWidget);
    expect(find.text(l10n.toCurrency(6)), findsNothing);
    expect(find.text(l10n.toCurrency(12)), findsOneWidget);

    // Re-check: back to two equal shares, "Not in" gone.
    await tester.tap(_toggleFinder('a@test.com'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.splitNotInLabel), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));
  });

  testWidgets('include toggle is a 26px round toggle (F161 D4)', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    // Included member: filled primary circle + white check(17). The toggle is
    // a keyed GestureDetector wrapping a 26px circular Container.
    final toggle = _toggleFinder('a@test.com');
    expect(toggle, findsOneWidget);
    final circle = tester.widget<Container>(
      find.descendant(
        of: toggle,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect((circle.decoration as BoxDecoration).shape, BoxShape.circle);
    // Check glyph shown when included.
    expect(
      find.descendant(of: toggle, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets(
    'Exact mode shows editable per-member amount fields on quick split',
    (tester) async {
      final controller = TextEditingController(text: '12.00');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        initialAmount: null,
        isSingleEntry: true,
        expenseLevelAmountController: controller,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.splitModeExact));
      await tester.pumpAndSettle();

      // F158: Exact seeds each member with an equal share, each editable via the
      // shared amount keypad (tap the tile → keypad), not a raw inline field.
      expect(find.text('6.00'), findsNWidgets(2));

      // Editing one member (via keypad) locks it and rebalances the other: tap
      // the first tile → clear the "6" seed → type 9 → confirm.
      await tester.tap(find.text('6.00').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('3.00'), findsOneWidget);
    },
  );

  testWidgets(
    'quick split renders the segmented allocation bar and member avatars '
    '(F161 D3: no ProgressBar)',
    (tester) async {
      final controller = TextEditingController(text: '12.00');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        initialAmount: null,
        isSingleEntry: true,
        expenseLevelAmountController: controller,
      );
      // One colored segment per included member (the single bar), plus avatars.
      expect(
        find.byKey(const ValueKey('split_segment_0_a@test.com')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('split_segment_0_b@test.com')),
        findsOneWidget,
      );
      expect(find.byType(MemberAvatar), findsNWidgets(2));
    },
  );

  testWidgets(
    'split section renders one segment per included member with the member\'s '
    'avatar color, and toggling a member out removes its segment (F109)',
    (tester) async {
      final controller = TextEditingController(text: '12.00');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        initialAmount: null,
        isSingleEntry: true,
        expenseLevelAmountController: controller,
      );

      final aliceSeg = find.byKey(const ValueKey('split_segment_0_a@test.com'));
      final bobSeg = find.byKey(const ValueKey('split_segment_0_b@test.com'));

      // Both members included: two segments, each in the member's avatar color.
      expect(aliceSeg, findsOneWidget);
      expect(bobSeg, findsOneWidget);
      expect(
        tester.widget<Container>(aliceSeg).color,
        memberAvatarColor('a@test.com'),
      );
      expect(
        tester.widget<Container>(bobSeg).color,
        memberAvatarColor('b@test.com'),
      );

      // Toggle Alice out: her segment disappears, Bob's remains.
      await tester.tap(_toggleFinder('a@test.com'));
      await tester.pumpAndSettle();
      expect(aliceSeg, findsNothing);
      expect(bobSeg, findsOneWidget);
    },
  );

  testWidgets('switching to Shares mode shows steppers', (tester) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // No steppers in default (equal) mode.
    expect(find.byType(StepperControl), findsNothing);

    await tester.tap(find.text(l10n.splitModeShares));
    await tester.pumpAndSettle();

    expect(find.byType(StepperControl), findsNWidgets(2));
  });

  testWidgets(
    'split header shows "N of N people" count that decrements on toggle-out (F104)',
    (tester) async {
      final controller = TextEditingController(text: '12.00');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        initialAmount: null,
        isSingleEntry: true,
        expenseLevelAmountController: controller,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Both members included initially: "2 of 2 people".
      expect(find.text(l10n.splitPeopleCount(2, 2)), findsOneWidget);

      // Toggle Alice out (reuses the F108 include toggle): "1 of 2 people".
      await tester.tap(_toggleFinder('a@test.com'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.splitPeopleCount(1, 2)), findsOneWidget);
      expect(find.text(l10n.splitPeopleCount(2, 2)), findsNothing);
    },
  );

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // multi-currency-core review: the per-member amount tile is display-only text.
  // It used to be SEEDED locale-formatted ("6,00") and then REWRITTEN as machine
  // field text ("6.00"), so a German user watched the separator flip on the
  // first recompute or keypad confirm.
  // ---------------------------------------------------------------------------
  group('per-member exact-amount tiles are locale-formatted throughout', () {
    Future<void> pumpExact(
      WidgetTester tester, {
      required Locale locale,
      Currency currency = Currency.eur,
    }) async {
      final controller = TextEditingController(text: '12.00');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        initialAmount: null,
        isSingleEntry: true,
        expenseLevelAmountController: controller,
        locale: locale,
        currency: currency,
      );
      final l10n = await AppLocalizations.delegate.load(locale);
      await tester.tap(find.text(l10n.splitModeExact));
      await tester.pumpAndSettle();
    }

    testWidgets('the German seed uses a comma', (tester) async {
      await pumpExact(tester, locale: const Locale('de'));
      expect(find.text('6,00'), findsNWidgets(2));
      expect(find.text('6.00'), findsNothing);
    });

    testWidgets(
      'the separator does not flip after a keypad confirm rebalances the '
      'other member',
      (tester) async {
        await pumpExact(tester, locale: const Locale('de'));

        // Edit Alice to 9 → Bob is recomputed through
        // _updateUnlockedControllers, which is the write that used to switch
        // the tile from "3,00" to "3.00".
        await tester.tap(find.text('6,00').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
        await tester.tap(find.byKey(const ValueKey('keypad_9')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
        await tester.pumpAndSettle();

        // The edited tile AND the recomputed tile both stay German.
        expect(find.text('9,00'), findsOneWidget);
        expect(find.text('3,00'), findsOneWidget);
        expect(find.text('9.00'), findsNothing);
        expect(find.text('3.00'), findsNothing);
      },
    );

    testWidgets('the English seed and recompute both use a period', (
      tester,
    ) async {
      await pumpExact(tester, locale: const Locale('en'));
      expect(find.text('6.00'), findsNWidgets(2));

      await tester.tap(find.text('6.00').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('9.00'), findsOneWidget);
      expect(find.text('3.00'), findsOneWidget);
    });

    testWidgets('a 0-decimal currency renders whole units, seed and after', (
      tester,
    ) async {
      await pumpExact(
        tester,
        locale: const Locale('en'),
        currency: Currency.jpy,
      );
      // ¥12 over two members → ¥6 each, never "6.00".
      expect(find.text('6'), findsNWidgets(2));
      expect(find.text('6.00'), findsNothing);

      await tester.tap(find.text('6').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  // multi-currency-core review: _getAmountPreview used to hand both callers a
  // String they immediately re-parsed. It returns a double now, so the preview
  // is formatted once, by MoneyText, in the reader's locale.
  testWidgets('the equal-mode preview is locale-formatted, not re-parsed', (
    tester,
  ) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
      locale: const Locale('de'),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    // German renders "EUR 6,00" — the code leads in every locale, only the
    // decimal separator follows it. Compare against the pipeline's own output
    // rather than a hand-typed literal.
    expect(l10n.toCurrency(6), 'EUR 6,00');
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
