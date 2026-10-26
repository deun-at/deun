// housekeeping: `/dev/gallery` is registered only in debug builds.
// `flutter test` always runs with kDebugMode true, so the release half is
// driven through the `enabled` flag, and the wiring (every call passes
// kDebugMode) is pinned by reading lib/.

import 'dart:io';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/widgets/dev/widget_gallery_page.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _notFound = Key('not-found');

Future<void> _openGallery(WidgetTester tester, {required bool enabled}) async {
  final router = GoRouter(
    initialLocation: '/dev/gallery',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ...devGalleryRoutes(enabled: enabled),
    ],
    errorBuilder: (context, state) => const Text('missing', key: _notFound),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Theme(
        data: getThemeData(context, kBrandSeed, Brightness.light),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with the flag off, /dev/gallery is not found', (tester) async {
    await _openGallery(tester, enabled: false);

    expect(find.byKey(_notFound), findsOneWidget);
    expect(find.byType(WidgetGalleryPage), findsNothing);
  });

  testWidgets('with the flag on, /dev/gallery opens the gallery', (
    tester,
  ) async {
    await _openGallery(tester, enabled: true);

    expect(find.byType(WidgetGalleryPage), findsOneWidget);
    expect(find.byKey(_notFound), findsNothing);
  });

  test('the route table registers the gallery only through kDebugMode', () {
    final sources = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll('\\', '/'): file.readAsStringSync(),
    };
    const home = 'lib/widgets/dev/widget_gallery_page.dart';
    final call = RegExp(r'devGalleryRoutes\s*\(([^)]*)\)');

    final calls = [
      for (final MapEntry(:key, :value) in sources.entries)
        if (key != home)
          for (final match in call.allMatches(value))
            match.group(1)!.replaceAll(RegExp(r'[\s,]'), ''),
    ];
    expect(calls, isNotEmpty, reason: 'the route table spreads the gallery');
    expect(calls, everyElement('enabled:kDebugMode'));

    final elsewhere = [
      for (final MapEntry(:key, :value) in sources.entries)
        if (key != home &&
            (value.contains('WidgetGalleryPage(') ||
                value.contains("'/dev/gallery'")))
          key,
    ];
    expect(elsewhere, isEmpty, reason: 'only devGalleryRoutes builds it');
  });
}
