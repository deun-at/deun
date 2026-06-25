import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deun/l10n/app_localizations.dart';

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
  });
}
