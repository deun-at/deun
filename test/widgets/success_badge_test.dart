import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/success_badge.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a [SuccessBadge] inside a minimal MaterialApp that provides
/// [SemanticColors] via [getThemeData].
Future<void> _pump(
  WidgetTester tester, {
  bool disableAnimations = false,
  Color? color,
  IconData icon = Icons.check_circle,
  double size = 56,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: Center(
                child: SuccessBadge(
                  icon: icon,
                  size: size,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // With animations enabled:
  //   - Immediately after the first pump the icon's effective scale is < 1
  //     (mid-pop animation).
  //   - After pumpAndSettle the icon is at full scale (Transform.scale == 1.0)
  //     and the ring's opacity is ~0 (faded out).
  // ---------------------------------------------------------------------------
  group('SuccessBadge — animations enabled', () {
    testWidgets('icon scale is < 1 immediately after first pump (mid-pop)',
        (tester) async {
      await _pump(tester, disableAnimations: false);
      // After the first pump frame (t=0), the successPop tween starts at 0.
      // We do NOT call pumpAndSettle — we inspect the mid-animation state.
      // Find the ScaleTransition that is a direct descendant of SuccessBadge.
      final badgeFinder = find.byType(SuccessBadge);
      expect(badgeFinder, findsOneWidget);
      final scaleFinder = find.descendant(
        of: badgeFinder,
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget,
          reason: 'ScaleTransition should wrap the icon during animation');

      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      // At t=0 the animation value is 0 → scale is 0, which is < 1.
      expect(scaleWidget.scale.value, lessThan(1.0));
    });

    testWidgets('icon is at full scale after pumpAndSettle', (tester) async {
      await _pump(tester, disableAnimations: false);
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(SuccessBadge);
      expect(badgeFinder, findsOneWidget);
      final scaleFinder = find.descendant(
        of: badgeFinder,
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsOneWidget);
      final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
      expect(scaleWidget.scale.value, closeTo(1.0, 0.01));
    });

    testWidgets('ring opacity is ~0 after pumpAndSettle (faded out)',
        (tester) async {
      await _pump(tester, disableAnimations: false);
      await tester.pumpAndSettle();

      // The ring is an Opacity widget in the Stack.  After the ring animation
      // finishes (850 ms easeOut) its opacity interpolates to 0.
      // Narrow the search to descendants of SuccessBadge.
      final badgeFinder = find.byType(SuccessBadge);
      final opacityFinder = find.descendant(
        of: badgeFinder,
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget,
          reason: 'The ring Opacity widget should exist inside SuccessBadge');
      final opacityWidget = tester.widget<Opacity>(opacityFinder);
      // The ring opacity should be ~0 after settle.
      expect(opacityWidget.opacity, lessThan(0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // With animations disabled (reduced-motion):
  //   - Icon renders at full scale on first pump (no pop).
  //   - No ScaleTransition animating (static — no animated ring).
  // ---------------------------------------------------------------------------
  group('SuccessBadge — reduced motion (disableAnimations: true)', () {
    testWidgets('icon is at full scale immediately on first pump',
        (tester) async {
      await _pump(tester, disableAnimations: true);
      // With reduced motion there is no ScaleTransition inside SuccessBadge.
      final badgeFinder = find.byType(SuccessBadge);
      expect(badgeFinder, findsOneWidget);
      final scaleFinder = find.descendant(
        of: badgeFinder,
        matching: find.byType(ScaleTransition),
      );
      expect(scaleFinder, findsNothing,
          reason: 'No ScaleTransition when reduced motion is on');
      // The icon is present.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('no animated ring rendered in reduced-motion mode',
        (tester) async {
      await _pump(tester, disableAnimations: true);
      // With reduced motion the ring is omitted entirely — no Opacity inside
      // the badge.
      final badgeFinder = find.byType(SuccessBadge);
      expect(badgeFinder, findsOneWidget);
      final opacityFinder = find.descendant(
        of: badgeFinder,
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Color resolution:
  //   - Default resolves to SemanticColors.success from the theme.
  //   - An explicit color overrides it.
  // ---------------------------------------------------------------------------
  group('SuccessBadge — color', () {
    testWidgets('default color resolves to SemanticColors.success',
        (tester) async {
      await _pump(tester, disableAnimations: true);
      // In reduced-motion mode the icon is rendered statically; check its color
      // matches the light-mode SemanticColors.success value.
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, equals(SemanticColors.light.success));
    });

    testWidgets('explicit color overrides SemanticColors.success',
        (tester) async {
      const override = Color(0xFFFF0000);
      await _pump(tester, disableAnimations: true, color: override);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, equals(override));
    });
  });

  // ---------------------------------------------------------------------------
  // API surface:
  //   - Custom icon data is respected.
  //   - Size parameter is passed through.
  // ---------------------------------------------------------------------------
  group('SuccessBadge — API', () {
    testWidgets('custom icon is rendered', (tester) async {
      await _pump(
        tester,
        disableAnimations: true,
        icon: Icons.check_circle_outline,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('size parameter controls the icon size', (tester) async {
      await _pump(tester, disableAnimations: true, size: 48);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.size, equals(48.0));
    });
  });
}
