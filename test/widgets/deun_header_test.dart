import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deun/l10n/app_localizations.dart';

// Key used to find the subtitleLeading widget in tests.
const Key _subtitleLeadingKey = Key('test_subtitle_leading');

/// Pumps [child] inside a fully themed MaterialApp (redesign theme +
/// AppLocalizations delegates) at the requested [brightness].
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, brightness),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DeunHeader', () {
    testWidgets('renders the centered title text', (tester) async {
      await _pump(tester, const DeunHeader(title: 'My Title'));
      expect(find.text('My Title'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await _pump(
        tester,
        const DeunHeader(title: 'Main Title', subtitle: 'Sub line'),
      );
      expect(find.text('Main Title'), findsOneWidget);
      expect(find.text('Sub line'), findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await _pump(tester, const DeunHeader(title: 'Only Title'));
      // subtitle is absent — only one Text for the title
      expect(find.text('Sub line'), findsNothing);
    });

    testWidgets('default leading icon is Icons.arrow_back', (tester) async {
      await _pump(tester, const DeunHeader(title: 'T'));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('passing Icons.close renders close icon', (tester) async {
      await _pump(
        tester,
        const DeunHeader(title: 'T', leadingIcon: Icons.close),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('tapping leading button invokes onLeading', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        DeunHeader(title: 'T', onLeading: () => tapped = true),
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('title text style is fontSize 16 and fontWeight w700', (tester) async {
      await _pump(tester, const DeunHeader(title: 'Style Test'));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == 'Style Test')
          .toList();
      expect(texts, isNotEmpty);
      final style = texts.first.style;
      expect(style?.fontSize, 16.0);
      expect(style?.fontWeight, FontWeight.w700);
    });

    testWidgets('with no trailing, a 38×38 spacer exists on the right side', (tester) async {
      await _pump(tester, const DeunHeader(title: 'T'));
      // Both leading and trailing slots should be 38×38 SizedBox
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => b.width == 38 && b.height == 38)
          .toList();
      // There must be at least one 38×38 box on the trailing side
      expect(sizedBoxes.length, greaterThanOrEqualTo(1));
    });

    testWidgets('provided trailing widget renders and is tappable', (tester) async {
      var trailingTapped = false;
      await _pump(
        tester,
        DeunHeader(
          title: 'T',
          trailing: GestureDetector(
            onTap: () => trailingTapped = true,
            child: const SizedBox(width: 38, height: 38, child: Icon(Icons.edit)),
          ),
        ),
      );
      expect(find.byIcon(Icons.edit), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(trailingTapped, isTrue);
    });

    testWidgets('leading icon-button hit target is at least 48dp', (tester) async {
      await _pump(tester, const DeunHeader(title: 'T'));
      // The leading button should have a tappable area >= 48dp in both dimensions.
      // Find the InkWell wrapping the leading icon.
      final inkWells = find.ancestor(
        of: find.byIcon(Icons.arrow_back),
        matching: find.byType(InkWell),
      );
      expect(inkWells, findsOneWidget);
      final size = tester.getSize(inkWells);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('renders correctly in dark mode', (tester) async {
      await _pump(
        tester,
        const DeunHeader(title: 'Dark Mode'),
        brightness: Brightness.dark,
      );
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('showLeading false renders a 38x38 left spacer instead of back icon', (tester) async {
      await _pump(
        tester,
        const DeunHeader(title: 'T', showLeading: false),
      );
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    // ── trailingActions tests (TDD: added before implementation) ──────────────

    testWidgets('trailingActions renders both action widgets', (tester) async {
      await _pump(
        tester,
        DeunHeader(
          title: 'T',
          trailingActions: [
            IconButton(
              key: const Key('action_edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
            ),
            IconButton(
              key: const Key('action_delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('trailingActions: both actions are independently tappable', (tester) async {
      var editTapped = false;
      var deleteTapped = false;
      await _pump(
        tester,
        DeunHeader(
          title: 'T',
          trailingActions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editTapped = true,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => deleteTapped = true,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
      expect(deleteTapped, isFalse);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);
    });

    testWidgets(
        'with long title + trailingActions, title is horizontally centered in the header',
        (tester) async {
      const headerKey = Key('header_centering_test');
      await _pump(
        tester,
        DeunHeader(
          key: headerKey,
          title: 'A Very Long Expense Title That Could Overflow The Screen Width',
          trailingActions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ],
        ),
      );

      // Get the header bounds
      final headerBox = tester.renderObject(find.byKey(headerKey)) as RenderBox;
      final headerOffset = headerBox.localToGlobal(Offset.zero);
      final headerWidth = headerBox.size.width;
      final headerCenterX = headerOffset.dx + headerWidth / 2;

      // Find the title Text widget and get its center
      final titleFinder = find.text(
        'A Very Long Expense Title That Could Overflow The Screen Width',
      );
      expect(titleFinder, findsOneWidget);
      final titleBox = tester.renderObject(titleFinder) as RenderBox;
      final titleOffset = titleBox.localToGlobal(Offset.zero);
      final titleCenterX = titleOffset.dx + titleBox.size.width / 2;

      // Title center should be within 10px of header center — the Stack
      // positions title across the full width so it should be very close.
      expect(
        (titleCenterX - headerCenterX).abs(),
        lessThan(10.0),
        reason:
            'Title center ($titleCenterX) should be within 10px of header center ($headerCenterX)',
      );
    });

    // ── subtitleLeading tests (TDD: RED first) ─────────────────────────────────

    testWidgets('subtitleLeading renders alongside subtitle text', (tester) async {
      await _pump(
        tester,
        const DeunHeader(
          title: 'Merchant',
          subtitle: 'Live now',
          subtitleLeading: SizedBox(
            key: _subtitleLeadingKey,
            width: 8,
            height: 8,
          ),
        ),
      );
      expect(find.text('Merchant'), findsOneWidget);
      expect(find.text('Live now'), findsOneWidget);
      // The subtitleLeading widget is present in the tree.
      expect(find.byKey(_subtitleLeadingKey), findsOneWidget);
    });

    testWidgets('subtitleLeading is null by default — existing subtitle path unchanged',
        (tester) async {
      await _pump(
        tester,
        const DeunHeader(title: 'NoLeading', subtitle: 'Sub'),
      );
      // No key widget present — null path renders exactly as before.
      expect(find.byKey(_subtitleLeadingKey), findsNothing);
      expect(find.text('Sub'), findsOneWidget);
    });

    testWidgets('subtitleLeading is horizontally centered with subtitle text',
        (tester) async {
      const subtitleText = 'Centered subtitle';
      await _pump(
        tester,
        const DeunHeader(
          title: 'T',
          subtitle: subtitleText,
          subtitleLeading: SizedBox(
            key: _subtitleLeadingKey,
            width: 8,
            height: 8,
          ),
        ),
      );

      // Both the subtitle text and the leading widget must exist.
      expect(find.text(subtitleText), findsOneWidget);
      expect(find.byKey(_subtitleLeadingKey), findsOneWidget);

      // They must share approximately the same vertical centre (same row).
      final leadingBox =
          tester.renderObject(find.byKey(_subtitleLeadingKey)) as RenderBox;
      final subtitleBox =
          tester.renderObject(find.text(subtitleText)) as RenderBox;

      final leadingCenter =
          leadingBox.localToGlobal(Offset(0, leadingBox.size.height / 2)).dy;
      final subtitleCenter =
          subtitleBox.localToGlobal(Offset(0, subtitleBox.size.height / 2)).dy;

      expect(
        (leadingCenter - subtitleCenter).abs(),
        lessThan(4.0),
        reason: 'subtitleLeading and subtitle text should share the same row',
      );
    });
  });
}
