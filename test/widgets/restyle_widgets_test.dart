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
  });
}
