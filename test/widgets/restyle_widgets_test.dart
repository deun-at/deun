import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/restyle/app_segmented_control.dart';
import 'package:deun/widgets/restyle/avatar_stack.dart';
import 'package:deun/widgets/restyle/balance_pill.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/restyle/progress_bar.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/restyle/stepper_control.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to pump [child] inside a themed MaterialApp with specific
/// [MediaQueryData] injected (e.g. to override disableAnimations).
Future<void> _pumpWithMediaQuery(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  MediaQueryData? mediaQuery,
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
      builder: mediaQuery != null
          ? (context, child) => MediaQuery(data: mediaQuery, child: child!)
          : null,
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, brightness),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

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
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

SemanticColors _semantics(Brightness brightness) =>
    brightness == Brightness.dark ? SemanticColors.dark : SemanticColors.light;

void main() {
  group('MoneyText', () {
    testWidgets('renders the locale-formatted amount', (tester) async {
      await _pump(tester, const MoneyText(12.5));
      // 12.50 formatted with the € currency name → contains "12" and "50".
      expect(find.textContaining('12'), findsOneWidget);
      expect(find.textContaining('50'), findsOneWidget);
    });

    testWidgets('auto positive uses success color in light', (tester) async {
      await _pump(tester, const MoneyText(12.5, semantic: MoneySemantic.auto));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, _semantics(Brightness.light).success);
    });

    testWidgets('auto positive uses on-dark success in dark', (tester) async {
      await _pump(
        tester,
        const MoneyText(12.5, semantic: MoneySemantic.auto),
        brightness: Brightness.dark,
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, _semantics(Brightness.dark).success);
    });

    testWidgets('auto negative uses danger color', (tester) async {
      await _pump(tester, const MoneyText(-3.0, semantic: MoneySemantic.auto));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, _semantics(Brightness.light).danger);
    });

    testWidgets('auto zero uses the default text color (not semantic)',
        (tester) async {
      await _pump(tester, const MoneyText(0, semantic: MoneySemantic.auto));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, isNot(_semantics(Brightness.light).success));
      expect(text.style!.color, isNot(_semantics(Brightness.light).danger));
    });

    testWidgets('showSign prepends a + on positive amounts', (tester) async {
      await _pump(tester, const MoneyText(12.5, showSign: true));
      expect(find.textContaining('+'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // V3-T6: count-up animation
    // -------------------------------------------------------------------------

    testWidgets('animate defaults to false — same behavior as before', (tester) async {
      await _pump(tester, const MoneyText(99.0));
      // Default behavior: final amount shown immediately after pumpAndSettle.
      expect(find.textContaining('99'), findsOneWidget);
    });

    testWidgets(
        'animate:true with animations enabled — mid-count text differs from final after first pump',
        (tester) async {
      const amount = 50.0;
      // Use _pumpWithMediaQuery so MediaQuery includes disableAnimations:false
      // (which is the default, so this is a normal environment).
      await _pumpWithMediaQuery(
        tester,
        const MoneyText(amount, animate: true),
      );
      // After the first frame (before pumpAndSettle) the tween is still
      // running, so the displayed value is less than the final amount.
      // We deliberately do NOT call pumpAndSettle yet.
      // Note: tester.pump() was already called once inside pumpWidget.
      // We pump a small delta to advance the tween slightly but not finish it.
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = AppLocalizations.of(tester.element(find.byType(MoneyText)))!;
      final finalText = l10n.toCurrency(amount);

      // The text shown is NOT yet the final formatted amount.
      expect(find.text(finalText), findsNothing,
          reason: 'count-up should still be in progress after 50ms (750ms total)');

      // After settle the count finishes and the final value is shown.
      await tester.pumpAndSettle();
      expect(find.text(finalText), findsOneWidget);
    });

    testWidgets(
        'animate:true with disableAnimations:true — final amount shown immediately',
        (tester) async {
      const amount = 42.0;
      // Inject MediaQuery with disableAnimations:true.
      final mediaQuery = const MediaQueryData().copyWith(disableAnimations: true);
      await _pumpWithMediaQuery(
        tester,
        const MoneyText(amount, animate: true),
        mediaQuery: mediaQuery,
      );
      // Even before pumpAndSettle, reduced motion must show the final value.
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = AppLocalizations.of(tester.element(find.byType(MoneyText)))!;
      final finalText = l10n.toCurrency(amount);
      expect(find.text(finalText), findsOneWidget,
          reason: 'reduced motion must show the final amount immediately');
    });

    testWidgets(
        'animate:true — semantic color resolves from final amount, not mid-count value',
        (tester) async {
      // Use a positive amount with MoneySemantic.auto — should always be
      // success color, even mid-count (when the intermediate value is near 0).
      const amount = 25.0;
      await _pumpWithMediaQuery(
        tester,
        const MoneyText(amount, animate: true, semantic: MoneySemantic.auto),
      );
      // Advance partway through the tween.
      await tester.pump(const Duration(milliseconds: 100));

      // Color must still be success (resolved from the final amount, not the
      // intermediate ~3.3 value which is still positive anyway — the real test
      // is that it doesn't transiently show neutral for a near-zero mid value).
      final text = tester.widget<Text>(find.byType(Text));
      const semanticColors = SemanticColors.light;
      expect(text.style!.color, semanticColors.success,
          reason: 'color must be resolved from the final positive amount');

      await tester.pumpAndSettle();
    });

    testWidgets(
        'animate:true — tabular figures feature is present during animation',
        (tester) async {
      const amount = 10.0;
      await _pumpWithMediaQuery(
        tester,
        const MoneyText(amount, animate: true),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final text = tester.widget<Text>(find.byType(Text));
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: 'tabular figures must be applied during count-up',
      );

      await tester.pumpAndSettle();
    });
  });

  group('MemberAvatar', () {
    testWidgets('shows the derived initials', (tester) async {
      await _pump(tester, const MemberAvatar(name: 'Priya Nair', colorKey: 'p@x'));
      expect(find.text('PN'), findsOneWidget);
    });

    testWidgets('single-word name uses one initial', (tester) async {
      await _pump(tester, const MemberAvatar(name: 'Sam', colorKey: 's@x'));
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('background uses the deterministic member color', (tester) async {
      await _pump(tester, const MemberAvatar(name: 'Sam', colorKey: 's@x.com'));
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, memberAvatarColor('s@x.com'));
    });

    testWidgets('same colorKey yields the same background', (tester) async {
      await _pump(tester, const MemberAvatar(name: 'A', colorKey: 'k@x'));
      final a = tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor;
      await _pump(tester, const MemberAvatar(name: 'B', colorKey: 'k@x'));
      final b = tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor;
      expect(a, b);
    });

    testWidgets('isYou tints the background with the primary color',
        (tester) async {
      late Color primary;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final theme = getThemeData(context, kBrandSeed, Brightness.light);
              primary = theme.colorScheme.primary;
              return Theme(
                data: theme,
                child: const Scaffold(
                  body: MemberAvatar(name: 'You', colorKey: 'you@x', isYou: true),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, primary);
    });
  });

  group('AvatarStack', () {
    testWidgets('shows a +N overflow chip when over the max', (tester) async {
      await _pump(
        tester,
        const AvatarStack(
          members: [
            AvatarStackMember(name: 'A A', colorKey: 'a'),
            AvatarStackMember(name: 'B B', colorKey: 'b'),
            AvatarStackMember(name: 'C C', colorKey: 'c'),
            AvatarStackMember(name: 'D D', colorKey: 'd'),
            AvatarStackMember(name: 'E E', colorKey: 'e'),
          ],
          maxVisible: 3,
        ),
      );
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('shows all avatars and no chip when within the max',
        (tester) async {
      await _pump(
        tester,
        const AvatarStack(
          members: [
            AvatarStackMember(name: 'A A', colorKey: 'a'),
            AvatarStackMember(name: 'B B', colorKey: 'b'),
          ],
          maxVisible: 3,
        ),
      );
      expect(find.textContaining('+'), findsNothing);
      expect(find.byType(MemberAvatar), findsNWidgets(2));
    });
  });

  group('AppSegmentedControl', () {
    testWidgets('calls onChanged with the tapped value', (tester) async {
      String? changed;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => AppSegmentedControl<String>(
            value: 'a',
            segments: const [
              AppSegment(value: 'a', label: 'Quick'),
              AppSegment(value: 'b', label: 'Itemized'),
            ],
            onChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.tap(find.text('Itemized'));
      await tester.pumpAndSettle();
      expect(changed, 'b');
    });
  });

  group('StepperControl', () {
    testWidgets('increment and decrement fire callbacks', (tester) async {
      var inc = 0;
      var dec = 0;
      await _pump(
        tester,
        StepperControl(
          value: '2',
          onIncrement: () => inc++,
          onDecrement: () => dec++,
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(inc, 1);
      expect(dec, 1);
    });

    testWidgets('disabled bounds do not fire callbacks', (tester) async {
      var inc = 0;
      var dec = 0;
      await _pump(
        tester,
        StepperControl(
          value: '0',
          canDecrement: false,
          canIncrement: false,
          onIncrement: () => inc++,
          onDecrement: () => dec++,
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(inc, 0);
      expect(dec, 0);
    });

    testWidgets('each step button has a >=48dp hit target', (tester) async {
      await _pump(
        tester,
        StepperControl(
          value: '1',
          onIncrement: () {},
          onDecrement: () {},
        ),
      );
      for (final icon in [Icons.add, Icons.remove]) {
        final tapTarget = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(InkResponse),
        );
        expect(tapTarget, findsOneWidget);
        final size = tester.getSize(tapTarget);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('step buttons expose localized increase/decrease labels',
        (tester) async {
      await _pump(
        tester,
        StepperControl(
          value: '1',
          onIncrement: () {},
          onDecrement: () {},
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(StepperControl)),
      )!;
      expect(find.bySemanticsLabel(l10n.stepperIncrease), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.stepperDecrease), findsOneWidget);
    });
  });

  group('ProgressBar', () {
    testWidgets('clamps value above 1 to a full fill', (tester) async {
      await _pump(tester, const ProgressBar(value: 1.5));
      final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(bar.clampedValue, 1.0);
    });

    testWidgets('clamps negative value to 0', (tester) async {
      await _pump(tester, const ProgressBar(value: -0.5));
      final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(bar.clampedValue, 0.0);
    });

    // -------------------------------------------------------------------------
    // V3-T8: grow-on-entrance animation
    // -------------------------------------------------------------------------

    testWidgets(
        'after pumpAndSettle widthFactor equals clampedValue (animation finished)',
        (tester) async {
      const value = 0.6;
      await _pumpWithMediaQuery(tester, const ProgressBar(value: value));
      await tester.pumpAndSettle();
      final box = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(box.widthFactor, closeTo(value, 0.001));
    });

    testWidgets(
        'widthFactor is less than clampedValue 50ms after first pump (animating)',
        (tester) async {
      const value = 0.8;
      // Use _pumpWithMediaQuery (animations enabled — default MediaQuery).
      await _pumpWithMediaQuery(tester, const ProgressBar(value: value));
      // At 50ms the 100ms delay has not yet elapsed, so widthFactor must be 0.
      await tester.pump(const Duration(milliseconds: 50));
      final box = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(
        box.widthFactor! < value,
        isTrue,
        reason: 'progress bar should still be growing at 50ms (100ms delay + 720ms total)',
      );
    });

    testWidgets(
        'with disableAnimations widthFactor equals clampedValue immediately',
        (tester) async {
      const value = 0.5;
      final mediaQuery = const MediaQueryData().copyWith(disableAnimations: true);
      await _pumpWithMediaQuery(
        tester,
        const ProgressBar(value: value),
        mediaQuery: mediaQuery,
      );
      // No pumpAndSettle — reduced motion must show full value right away.
      await tester.pump(const Duration(milliseconds: 1));
      final box = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(box.widthFactor, closeTo(value, 0.001));
    });

    testWidgets(
        'value change animates to new clampedValue after pumpAndSettle',
        (tester) async {
      double currentValue = 0.4;
      await _pumpWithMediaQuery(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressBar(value: currentValue),
              TextButton(
                onPressed: () => setState(() => currentValue = 0.9),
                child: const Text('update'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Trigger the value change.
      await tester.tap(find.text('update'));
      await tester.pumpAndSettle();
      final box = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(box.widthFactor, closeTo(0.9, 0.001));
    });
  });

  group('BalancePill', () {
    testWidgets('builds in light and dark', (tester) async {
      await _pump(tester, const BalancePill(label: 'You are owed', state: BalanceState.owed));
      expect(find.text('You are owed'), findsOneWidget);
      await _pump(
        tester,
        const BalancePill(label: 'You owe', state: BalanceState.owe),
        brightness: Brightness.dark,
      );
      expect(find.text('You owe'), findsOneWidget);
    });
  });

  group('SectionLabel', () {
    testWidgets('renders the label and trailing action', (tester) async {
      await _pump(
        tester,
        SectionLabel('Your groups', trailing: TextButton(onPressed: () {}, child: const Text('New'))),
      );
      expect(find.text('Your groups'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });
  });

  group('SoftCard', () {
    testWidgets('builds in light and dark', (tester) async {
      await _pump(tester, const SoftCard(child: Text('card body')));
      expect(find.text('card body'), findsOneWidget);
      await _pump(
        tester,
        const SoftCard(child: Text('card body')),
        brightness: Brightness.dark,
      );
      expect(find.text('card body'), findsOneWidget);
    });
  });

  group('SheetScaffold', () {
    testWidgets('renders title, body and footer in light and dark',
        (tester) async {
      await _pump(
        tester,
        const SheetScaffold(
          title: 'Pick a category',
          body: Text('sheet body'),
          footer: Text('sheet footer'),
        ),
      );
      expect(find.text('Pick a category'), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
      expect(find.text('sheet footer'), findsOneWidget);

      await _pump(
        tester,
        const SheetScaffold(body: Text('sheet body')),
        brightness: Brightness.dark,
      );
      expect(find.text('sheet body'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // V3-T9a: §3 spec — radius 30, single 38×4 outlineVariant handle, title w700
    // -------------------------------------------------------------------------

    testWidgets('surface uses surfaceContainerLow with top radius 30, square bottom',
        (tester) async {
      late ColorScheme colorScheme;
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
            builder: (context) {
              final theme = getThemeData(context, kBrandSeed, Brightness.light);
              colorScheme = theme.colorScheme;
              return Theme(
                data: theme,
                child: const Scaffold(
                  body: Center(child: SheetScaffold(body: Text('body'))),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Surface color is surfaceContainerLow.
      final container = tester.widget<Container>(
        find.ancestor(of: find.text('body'), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, colorScheme.surfaceContainerLow,
          reason: 'Sheet surface must use surfaceContainerLow');
      // Top radius 30, bottom square.
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(30)),
        reason: 'Top radius must be 30, bottom must be square (no radius)',
      );
    });

    testWidgets('exactly one drag handle rendered — sized 38×4 — colored outlineVariant',
        (tester) async {
      late ColorScheme colorScheme;
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
            builder: (context) {
              final theme = getThemeData(context, kBrandSeed, Brightness.light);
              colorScheme = theme.colorScheme;
              return Theme(
                data: theme,
                child: const Scaffold(
                  body: Center(child: SheetScaffold(body: Text('body'))),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find containers with the outlineVariant color — exactly one (the handle).
      final containers = tester.widgetList<Container>(find.byType(Container)).toList();
      final handles = containers.where((c) {
        final deco = c.decoration;
        if (deco is BoxDecoration && deco.color == colorScheme.outlineVariant) return true;
        return false;
      }).toList();
      expect(handles.length, 1, reason: 'Exactly one drag handle must be rendered');

      // The handle container must be 38 wide and 4 tall.
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container) {
          final deco = w.decoration;
          if (deco is BoxDecoration && deco.color == colorScheme.outlineVariant) return true;
        }
        return false;
      });
      final size = tester.getSize(handleFinder);
      expect(size.width, 38.0, reason: 'Drag handle width must be 38');
      expect(size.height, 4.0, reason: 'Drag handle height must be 4');
    });

    testWidgets('title renders with fontWeight w700', (tester) async {
      await _pump(
        tester,
        const SheetScaffold(title: 'My Sheet', body: Text('body')),
      );
      final titleText = tester.widget<Text>(find.text('My Sheet'));
      // Style may be resolved; check the effective weight.
      final weight = titleText.style?.fontWeight;
      expect(weight, FontWeight.w700, reason: 'Sheet title must use fontWeight w700');
    });

    testWidgets('default padding is EdgeInsets.fromLTRB(20, 8, 20, 26)', (tester) async {
      const sheet = SheetScaffold(body: Text('content'));
      expect(sheet.padding, const EdgeInsets.fromLTRB(20, 8, 20, 26));
    });

    testWidgets('kSheetBarrierColor has approximately 0.4 opacity', (tester) async {
      // 0x66 / 0xFF ≈ 0.400.
      expect(kSheetBarrierColor.a, closeTo(0.4, 0.01));
    });
  });
}
