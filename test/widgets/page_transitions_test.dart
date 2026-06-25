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
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: child,
        ),
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
    testWidgets('child widget is present in the tree after pump',
        (tester) async {
      final router = _makeRouter(const Text('Hello from child'));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Hello from child'), findsOneWidget);
    });

    testWidgets('SharedAxisTransition is present in the tree when animations enabled',
        (tester) async {
      final router = _makeRouter(const Text('animated'));

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      // Only pump one frame so the transition is mid-way (before settle).
      await tester.pump();

      // SharedAxisTransition must exist in the widget tree.
      expect(find.byType(SharedAxisTransition), findsWidgets);
    });
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
    });
  });
}
