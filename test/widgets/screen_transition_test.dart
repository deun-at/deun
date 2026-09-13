/// Screen-transition wiring: every full-screen drill-down must take its motion
/// from [PageTransitionsTheme], not from a per-route `CustomTransitionPage`.
///
/// Between 2026-06-25 (`8fdf6e6`, "V3-T4: shared-axis transitions on drill-down
/// routes") and the change these tests guard, every route in `navigation.dart`
/// returned a `CustomTransitionPage`. That supplies its own `transitionsBuilder`
/// and bypasses the theme, so `PredictiveBackPageTransitionsBuilder` — already
/// registered, with `enableOnBackInvokedCallback` already set in the manifest —
/// was never consulted and the back-drag silently disappeared. These tests fail
/// if that regression is reintroduced.
library;

import 'dart:async';
import 'dart:io';

import 'package:deun/constants.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the app theme outside a widget test body.
Future<ThemeData> _appTheme(WidgetTester tester, Brightness brightness) async {
  late ThemeData theme;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          theme = getThemeData(context, kBrandSeed, brightness);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return theme;
}

void main() {
  // -------------------------------------------------------------------------
  // 1. The theme is the single source of screen motion.
  // -------------------------------------------------------------------------
  group('pageTransitionsTheme — one transition for every platform', () {
    testWidgets('Android uses predictive back', (tester) async {
      final theme = await _appTheme(tester, Brightness.light);

      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
    });

    testWidgets('the desktop targets carry fade-forwards, so the web build '
        'matches Android instead of falling back to Zoom', (tester) async {
      final theme = await _appTheme(tester, Brightness.light);

      for (final platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          theme.pageTransitionsTheme.builders[platform],
          isA<FadeForwardsPageTransitionsBuilder>(),
          reason: '$platform should fade forwards',
        );
      }
    });

    testWidgets('iOS is left unregistered so it falls back to Cupertino', (
      tester,
    ) async {
      final theme = await _appTheme(tester, Brightness.light);

      expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS], isNull);
    });

    testWidgets('dark theme registers the same builders', (tester) async {
      final theme = await _appTheme(tester, Brightness.dark);

      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. A push under that theme actually plays fade-forwards.
  //
  //    PredictiveBackPageTransitionsBuilder only renders its shrink-to-edge
  //    transition while a pop *gesture* is in progress; every other navigation
  //    delegates to FadeForwardsPageTransitionsBuilder, which slides the
  //    incoming page in from 25 % of the width while fading it up.
  // -------------------------------------------------------------------------
  group('pushing a MaterialPage plays fade-forwards', () {
    /// Builds the app theme, pushes a second route, and pumps 120 ms into the
    /// 450 ms transition. The platform override is reset inside the test body:
    /// the framework asserts all foundation debug vars are unset *before*
    /// tearDown runs, so a tearDown reset comes too late.
    Future<void> pushPartway(WidgetTester tester) async {
      late ThemeData theme;
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              theme = getThemeData(context, kBrandSeed, Brightness.light);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          navigatorKey: navKey,
          home: const Scaffold(body: Text('group list')),
        ),
      );

      unawaited(
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('group detail')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
    }

    testWidgets('incoming route slides in from 25 % and settles at zero', (
      tester,
    ) async {
      await pushPartway(tester);

      final slides = tester
          .widgetList<SlideTransition>(find.byType(SlideTransition))
          .toList();
      expect(
        slides,
        isNotEmpty,
        reason: 'fade-forwards slides the incoming page horizontally',
      );

      // Partway through, at least one page is offset along x and none along y.
      final offsets = slides.map((s) => s.position.value).toList();
      expect(
        offsets.any((o) => o.dx.abs() > 0.0 && o.dx.abs() <= 0.25),
        isTrue,
        reason: 'expected an x offset within the 25 % travel, got $offsets',
      );
      expect(
        offsets.every((o) => o.dy == 0.0),
        isTrue,
        reason: 'fade-forwards never moves vertically, got $offsets',
      );

      await tester.pumpAndSettle();
      expect(find.text('group detail'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the incoming route fades as well as slides', (tester) async {
      await pushPartway(tester);

      final opacities = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .map((f) => f.opacity.value)
          .toList();
      expect(
        opacities.any((o) => o > 0.0 && o < 1.0),
        isTrue,
        reason: 'expected a partial opacity mid-transition, got $opacities',
      );

      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // -------------------------------------------------------------------------
  // 3. Source guard — no drill-down route may reintroduce a custom page.
  // -------------------------------------------------------------------------
  group('navigation.dart routes through the theme', () {
    late String source;

    setUpAll(() {
      source = File('lib/navigation.dart').readAsStringSync();
    });

    test('no route builds a CustomTransitionPage', () {
      expect(
        source.contains('CustomTransitionPage'),
        isFalse,
        reason:
            'A CustomTransitionPage supplies its own transitionsBuilder and '
            'bypasses PageTransitionsTheme, which disables predictive back. '
            'Use MaterialPage so the theme owns the transition.',
      );
    });

    test('sharedAxisPage is gone', () {
      expect(
        source.contains('sharedAxisPage'),
        isFalse,
        reason: 'sharedAxisPage was removed with the move to platform pages.',
      );
    });

    test('drill-down routes still use MaterialPage', () {
      expect(
        'MaterialPage('.allMatches(source).length,
        greaterThanOrEqualTo(17),
        reason: 'every full-screen drill-down returns a platform page',
      );
    });
  });
}
