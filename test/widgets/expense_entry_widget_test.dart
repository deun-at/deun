import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/split_mode.dart';
import 'package:deun/pages/expenses/presentation/expense_entry_widget.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/stepper_control.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  String? initialAmount = '12.00',
  bool isSingleEntry = false,
  TextEditingController? expenseLevelAmountController,
}) async {
  final members = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  final entry = ExpenseEntry(index: 0);

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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: SingleChildScrollView(
                child: FormBuilder(
                  child: ExpenseEntryWidget(
                    expenseEntry: entry,
                    index: 0,
                    onRemove: () {},
                    groupMembers: members,
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
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
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

    // No split-mode selector, no member checkboxes/avatars, no allocation bar.
    expect(find.byType(AppSegmentedControl<SplitMode>), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(MemberAvatar), findsNothing);
    expect(find.byType(ProgressBar), findsNothing);
    expect(find.text(l10n.splitSectionLabel), findsNothing);
    // The item card itself (name + amount/quantity) is still there.
    expect(find.text(l10n.expenseDescriptionHint), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
  });

  testWidgets('quick split renders the 4-way SplitMode segmented control',
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

    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    expect(find.text(l10n.splitModeEqual), findsOneWidget);
    expect(find.text(l10n.splitModeShares), findsOneWidget);
    expect(find.text(l10n.splitModePercentage), findsOneWidget);
    expect(find.text(l10n.splitModeExact), findsOneWidget);
  });

  testWidgets('quick split (single entry) also shows the split-mode selector',
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

    expect(find.byType(AppSegmentedControl<SplitMode>), findsOneWidget);
    expect(find.text(l10n.splitModeEqual), findsOneWidget);
    expect(find.text(l10n.splitModeExact), findsOneWidget);
  });

  testWidgets('Equal mode splits the total evenly across included members',
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

    // Default mode is Equal: €12 over 2 members → €6.00 each, no steppers.
    expect(find.byType(StepperControl), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));
    expect(find.text(l10n.splitEqualSummary(l10n.toCurrency(6))), findsOneWidget);

    // Unchecking a member re-splits over the remaining one.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.toCurrency(12)), findsOneWidget);
  });

  testWidgets('unchecked member shows "Not in" and no amount (F108)',
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

    // Both members in: no "Not in", two €6.00 amounts.
    expect(find.text(l10n.splitNotInLabel), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));

    // Uncheck Alice: her row shows "Not in", no €6.00 remains, and Bob's
    // per-head amount recalculates to the full €12.00.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.splitNotInLabel), findsOneWidget);
    expect(find.text(l10n.toCurrency(6)), findsNothing);
    expect(find.text(l10n.toCurrency(12)), findsOneWidget);

    // Re-check: back to two equal shares, "Not in" gone.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.splitNotInLabel), findsNothing);
    expect(find.text(l10n.toCurrency(6)), findsNWidgets(2));
  });

  testWidgets('include toggle uses a round (circle) shape', (tester) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.shape, isA<CircleBorder>());
  });

  testWidgets('Exact mode shows editable per-member amount fields on quick split',
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

    // Exact seeds each member with an equal share, editable per member.
    expect(find.widgetWithText(TextFormField, '6.00'), findsNWidgets(2));

    // Editing one member locks it and rebalances the other.
    await tester.enterText(find.widgetWithText(TextFormField, '6.00').first, '9.00');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '3.00'), findsOneWidget);
  });

  testWidgets('quick split renders an allocation ProgressBar and member avatars',
      (tester) async {
    final controller = TextEditingController(text: '12.00');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      initialAmount: null,
      isSingleEntry: true,
      expenseLevelAmountController: controller,
    );
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.byType(MemberAvatar), findsNWidgets(2));
  });

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
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(aliceSeg, findsNothing);
    expect(bobSeg, findsOneWidget);
  });

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
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.splitPeopleCount(1, 2)), findsOneWidget);
    expect(find.text(l10n.splitPeopleCount(2, 2)), findsNothing);
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
