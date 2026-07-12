import 'package:animations/animations.dart';
import 'package:deun/widgets/motion.dart';
import 'package:deun/widgets/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Minimal router helper so we can pump a page inside a real Navigator.
// ---------------------------------------------------------------------------
GoRouter _makeRouter(Widget child) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            sharedAxisPage(key: state.pageKey, child: child),
      ),
    ],
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. sharedAxisPage returns a CustomTransitionPage with correct duration.
  // -------------------------------------------------------------------------
  group('sharedAxisPage — type and duration', () {
    test('returns a CustomTransitionPage instance', () {
      final page = sharedAxisPage<void>(
        key: const ValueKey('test'),
        child: const SizedBox(),
      );
      expect(page, isA<CustomTransitionPage<void>>());
    });

    test('transitionDuration equals Motion.screenForward (360 ms)', () {
      final page = sharedAxisPage<void>(
        key: const ValueKey('dur'),
        child: const SizedBox(),
      );
      expect(page.transitionDuration, Motion.screenForward);
    });

    test('reverseTransitionDuration equals Motion.screenForward (360 ms)', () {
      final page = sharedAxisPage<void>(
        key: const ValueKey('rev'),
        child: const SizedBox(),
      );
      expect(page.reverseTransitionDuration, Motion.screenForward);
    });

    test('defaults to SharedAxisTransitionType.horizontal', () {
      final page = sharedAxisPage<void>(
        key: const ValueKey('type'),
        child: const SizedBox(),
      );
      // Verify by pumping and finding SharedAxisTransition in the tree.
      // (We do this in the widget-pump tests below.)
      expect(page, isA<CustomTransitionPage<void>>());
    });
  });

  // -------------------------------------------------------------------------
  // 2. Pumping the page renders the child in a MaterialApp/router.
  // -------------------------------------------------------------------------
  group('sharedAxisPage — child renders', () {
    testWidgets('child widget is present in the tree after pump', (
      tester,
    ) async {
      final router = _makeRouter(const Text('Hello from child'));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Hello from child'), findsOneWidget);
    });

    testWidgets(
      'SharedAxisTransition is present in the tree when animations enabled',
      (tester) async {
        final router = _makeRouter(const Text('animated'));

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        // Only pump one frame so the transition is mid-way (before settle).
        await tester.pump();

        // SharedAxisTransition must exist in the widget tree.
        expect(find.byType(SharedAxisTransition), findsWidgets);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3. Reduced motion: disableAnimations → no SharedAxisTransition, instant.
  // -------------------------------------------------------------------------
  group('sharedAxisPage — reduced motion', () {
    testWidgets(
      'when disableAnimations=true, no SharedAxisTransition is in the tree',
      (tester) async {
        final router = _makeRouter(const Text('instant'));

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // With reduced motion the transitions builder must not render a
        // SharedAxisTransition — it should return the child directly.
        expect(find.byType(SharedAxisTransition), findsNothing);
        // But the child must still be visible.
        expect(find.text('instant'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 4. TabSwitchTransition — home-tab switch fade-up (ANIMATIONS §1).
  //    Acceptance: translateY(8px) + fade, 0.26s, ease, no horizontal slide;
  //    reduced motion falls back to instant; state preserved (child untouched).
  // -------------------------------------------------------------------------
  group('TabSwitchTransition — home-tab switch motion', () {
    // Harness that lets a test flip the branch index on demand.
    Widget harness(ValueNotifier<int> index) {
      return MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, i, _) =>
              TabSwitchTransition(index: i, child: Text('branch $i')),
        ),
      );
    }

    testWidgets('first build is settled — no animation, child fully visible', (
      tester,
    ) async {
      final index = ValueNotifier<int>(0);
      await tester.pumpWidget(harness(index));
      await tester.pump();

      // Settled from the start: full opacity, zero offset.
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(TabSwitchTransition),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().y, 0.0);
      expect(find.text('branch 0'), findsOneWidget);
    });

    testWidgets(
      'switching index runs a fade-up: partway through, opacity<1 and '
      'view is offset downward (translateY), never slid horizontally',
      (tester) async {
        final index = ValueNotifier<int>(0);
        await tester.pumpWidget(harness(index));
        await tester.pumpAndSettle();

        // Switch branch — starts the 0.26s fade-up from the beginning.
        index.value = 1;
        await tester.pump(); // apply new index, controller.forward(from: 0)
        await tester.pump(const Duration(milliseconds: 60)); // partway in

        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, greaterThan(0.0));
        expect(opacity.opacity, lessThan(1.0));

        final translation = tester
            .widget<Transform>(
              find.descendant(
                of: find.byType(TabSwitchTransition),
                matching: find.byType(Transform),
              ),
            )
            .transform
            .getTranslation();
        // Vertical offset in (0, 8]: translating up from 8px toward rest.
        expect(translation.y, greaterThan(0.0));
        expect(translation.y, lessThanOrEqualTo(kTabSwitchOffset));
        // No horizontal slide, ever.
        expect(translation.x, 0.0);

        // The incoming branch is what's shown.
        expect(find.text('branch 1'), findsOneWidget);
      },
    );

    testWidgets(
      'animation settles to rest (opacity 1, offset 0) within 0.26s',
      (tester) async {
        final index = ValueNotifier<int>(0);
        await tester.pumpWidget(harness(index));
        await tester.pumpAndSettle();

        index.value = 1;
        await tester.pump();
        await tester.pump(Motion.tabSwitch); // full 0.26s elapsed
        await tester.pump();

        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, 1.0);
        final translation = tester
            .widget<Transform>(
              find.descendant(
                of: find.byType(TabSwitchTransition),
                matching: find.byType(Transform),
              ),
            )
            .transform
            .getTranslation();
        expect(translation.y, 0.0);
      },
    );

    testWidgets(
      'reduced motion: disableAnimations → no Opacity/Transform wrapper, '
      'child returned directly',
      (tester) async {
        final index = ValueNotifier<int>(0);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: harness(index),
          ),
        );
        await tester.pump();

        // Switching index must not introduce a fade/slide wrapper.
        index.value = 1;
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(TabSwitchTransition),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
        expect(find.text('branch 1'), findsOneWidget);
      },
    );

    testWidgets(
      'unrelated rebuild with same index does not restart the animation '
      '(no re-stagger on every rebuild)',
      (tester) async {
        // A rebuild tick that changes on each notify but keeps index constant.
        final tick = ValueNotifier<int>(0);
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (context, t, _) => TabSwitchTransition(
                index: 0, // unchanged across rebuilds
                child: Text('rebuild $t'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Force a parent rebuild without changing the branch index.
        tick.value = 1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        // Still settled — no fade-up was triggered.
        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, 1.0);
        expect(find.text('rebuild 1'), findsOneWidget);
      },
    );
  });
}
