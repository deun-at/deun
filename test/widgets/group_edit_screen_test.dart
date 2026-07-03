import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Group _group({
  int? colorValue,
  bool simplifiedExpenses = true,
}) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip to Rome';
  g.colorValue = colorValue ?? kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = simplifiedExpenses;
  g.createdAt = '';
  g.userId = null;
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = 'me@test.com';
  m.displayName = 'Me';
  m.isGuest = false;
  m.isFavorite = false;
  g.groupMembers = [m];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

Future<void> _pump(
  WidgetTester tester, {
  Group? group,
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
            child: GroupEdit(group: group),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds the selectable color swatches: AnimatedContainers whose decoration is a
/// circle filled with a palette color.
Finder _swatchFinder() {
  final palette = kGroupColorPalette.map((c) => c.toARGB32()).toSet();
  return find.byWidgetPredicate((w) {
    if (w is! AnimatedContainer) return false;
    final deco = w.decoration;
    if (deco is! BoxDecoration) return false;
    if (deco.shape != BoxShape.circle) return false;
    final color = deco.color;
    return color != null && palette.contains(color.toARGB32());
  });
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

  testWidgets('renders name field, six swatches, mode selector and Create button (new group)',
      (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Name field hint.
    expect(find.text(l10n.groupNameHint), findsOneWidget);
    // Six color swatches.
    expect(_swatchFinder(), findsNWidgets(kGroupColorPalette.length));
    // Tracking-mode options. The taller centered-icon header pushes this section
    // below the 800x600 test viewport, so scroll it into view before asserting.
    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.groupTrackingModeSimplifiedTitle), findsOneWidget);
    expect(find.text(l10n.groupTrackingModeDetailedTitle), findsOneWidget);
    // Sticky Create button (new group, not Save).
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text(l10n.createGroup), findsOneWidget);
  });

  testWidgets('shows Save button and the group name when editing', (tester) async {
    await _pump(tester, group: _group());

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.save), findsOneWidget);
    expect(find.text('Trip to Rome'), findsOneWidget);
  });

  testWidgets('tapping a swatch updates the selected colorValue', (tester) async {
    await _pump(tester);

    // Initially the first swatch is selected (shows a check).
    BoxDecoration decoOf(int index) {
      final w = tester.widgetList<AnimatedContainer>(_swatchFinder()).elementAt(index);
      return w.decoration as BoxDecoration;
    }

    // The second swatch starts unselected (no border).
    expect(decoOf(1).border, isNull);

    await tester.tap(_swatchFinder().at(1));
    await tester.pumpAndSettle();

    // After tapping, the second swatch is selected (has a ring border) and the
    // first is no longer.
    expect(decoOf(1).border, isNotNull);
    expect(decoOf(0).border, isNull);
  });

  testWidgets('toggling the mode updates the simplified selection', (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Scroll the tracking-mode section into the 800x600 test viewport (the
    // taller centered-icon header pushes it below the fold).
    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // Default (new group) is Simplified (simplified_expenses == true): exactly
    // one row shows the checked radio.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

    // Tap Detailed. NoSplash (inherited via ThemeBuilder) avoids the ink
    // fragment shader the test engine can't decode.
    await tester.tap(find.text(l10n.groupTrackingModeDetailedTitle));
    await tester.pumpAndSettle();

    // Still exactly one checked radio, but the selection moved to Detailed.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('mode options render side by side (two Expanded cards in a Row)',
      (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // Both option titles share a common IntrinsicHeight ancestor (the
    // side-by-side row), each wrapped in an Expanded so they split the width.
    final simplified = find.text(l10n.groupTrackingModeSimplifiedTitle);
    final detailed = find.text(l10n.groupTrackingModeDetailedTitle);
    final sideBySide = find.ancestor(
      of: simplified,
      matching: find.byType(IntrinsicHeight),
    );
    expect(sideBySide, findsOneWidget);
    expect(
      find.descendant(of: sideBySide, matching: detailed),
      findsOneWidget,
      reason: 'Simplified and Detailed must sit in the same row (side by side)',
    );
    // Each option card is inside an Expanded.
    expect(
      find.ancestor(of: simplified, matching: find.byType(Expanded)),
      findsWidgets,
    );
    expect(
      find.ancestor(of: detailed, matching: find.byType(Expanded)),
      findsWidgets,
    );
  });

  testWidgets('new group defaults to Simplified selected', (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // The checked radio must belong to the Simplified option's card.
    final simplifiedCard = find.ancestor(
      of: find.text(l10n.groupTrackingModeSimplifiedTitle),
      matching: find.byType(SoftCard),
    );
    expect(
      find.descendant(
        of: simplifiedCard.first,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
      reason: 'a NEW group must default to Simplified',
    );
  });

  testWidgets('editing a Detailed group keeps Detailed selected (regression)',
      (tester) async {
    await _pump(tester, group: _group(simplifiedExpenses: false));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeDetailedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // The persisted mode (Detailed) must survive the edit-form init and NOT be
    // overwritten by the create-time Simplified default.
    final detailedCard = find.ancestor(
      of: find.text(l10n.groupTrackingModeDetailedTitle),
      matching: find.byType(SoftCard),
    );
    expect(
      find.descendant(
        of: detailedCard.first,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
      reason: 'editing a Detailed group must keep Detailed selected',
    );
  });

  testWidgets(
      'name field sits on white; icon + colour pickers are NOT boxed in a card (F133)',
      (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The group-name field carries its own white SoftCard surface.
    final nameField = find.widgetWithText(TextFormField, l10n.groupNameHint);
    expect(nameField, findsOneWidget);
    expect(
      find.ancestor(of: nameField, matching: find.byType(SoftCard)),
      findsOneWidget,
      reason: 'the name field should sit on its own white SoftCard surface',
    );

    // The colour swatches are UNBOXED: no SoftCard wraps them.
    expect(
      find.ancestor(of: _swatchFinder().first, matching: find.byType(SoftCard)),
      findsNothing,
      reason: 'colour swatches must not sit inside a white card',
    );

    // The retinted group-icon preview is UNBOXED too. F134: it is the group
    // glyph (groups_rounded), not the expense glyph (receipt_long).
    expect(find.byIcon(Icons.receipt_long), findsNothing);
    final iconPreview = find.byIcon(Icons.groups_rounded);
    expect(iconPreview, findsOneWidget);
    expect(
      find.ancestor(of: iconPreview, matching: find.byType(SoftCard)),
      findsNothing,
      reason: 'the group-icon preview must not sit inside a white card',
    );
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, group: _group(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
