import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/editor_mode.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Group _group() {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.expenses = [];
  return g;
}

Future<void> _pump(
  WidgetTester tester, {
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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: ExpenseDetail(group: _group()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

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

  testWidgets('renders the Quick/Itemized top segmented toggle', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    expect(find.byType(AppSegmentedControl<EditorMode>), findsOneWidget);
    expect(find.text(l10n.editorModeQuick), findsOneWidget);
    expect(find.text(l10n.editorModeItemized), findsOneWidget);
  });

  testWidgets('switching to Itemized shows the items list and CTA',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    // Quick CTA visible first; itemized CTA not yet.
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // Items header, add-item action, info callout, and the claiming CTA.
    expect(find.text(l10n.itemizedItemsLabel), findsOneWidget);
    expect(find.text(l10n.addItemByHand), findsOneWidget);
    expect(find.text(l10n.itemizedInfoCallout), findsOneWidget);
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsOneWidget);
  });

  testWidgets('Add item by hand appends an item card', (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();

    // One item card to start (the seeded entry). The top-level expense
    // name field now reuses the same description hint, so the count is
    // entries + 1 (the top-level inset field).
    expect(find.text(l10n.expenseDescriptionHint), findsNWidgets(2));

    await tester.ensureVisible(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addItemByHand));
    await tester.pumpAndSettle();

    // A second item card's name hint appears (2 entries + 1 top-level).
    expect(find.text(l10n.expenseDescriptionHint), findsNWidgets(3));
  });

  testWidgets('switching back to Quick shows the Quick amount card',
      (tester) async {
    await _pump(tester);
    final l10n = await _l10n();

    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editorModeQuick));
    await tester.pumpAndSettle();

    // Quick layout's claiming CTA is gone; quick view is back (SoftCard amount).
    expect(find.text(l10n.expenseSaveAndShareForClaiming), findsNothing);
    expect(find.byType(SoftCard), findsWidgets);
  });

  testWidgets('itemized editor renders in dark mode without throwing',
      (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    final l10n = await _l10n();
    await tester.tap(find.text(l10n.editorModeItemized));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
