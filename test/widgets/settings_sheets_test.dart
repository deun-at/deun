import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/auth/sign_out.dart';
import 'package:deun/pages/settings/settings_sheets.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Pumps a scaffold with a button that opens [openSheet], then taps it so the
/// sheet is on screen and settled.
Future<void> _openSheet(
  WidgetTester tester,
  void Function(BuildContext) openSheet, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
            data: getThemeData(
              context,
              kBrandSeed,
              Brightness.light,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => openSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Types the confirm keyword and taps the destructive button.
Future<void> _confirmDelete(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.enterText(
    find.byType(TextField),
    l10n.deleteAccountConfirmKeyword,
  );
  await tester.pump();
  final confirm = find.widgetWithText(
    PrimaryButton,
    l10n.settingsDeleteAccountConfirmButton,
  );
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pump();
}

void main() {
  testWidgets('language sheet draws no divider between options (F147)', (
    tester,
  ) async {
    await _openSheet(
      tester,
      (context) =>
          showLanguageSheet(context, currentTag: null, onSelected: (_) {}),
    );

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('appearance sheet draws no divider between options (F147)', (
    tester,
  ) async {
    await _openSheet(tester, (context) => showAppearanceSheet(context));

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('deleting the account signs out through the app sign-out, only '
      'after the delete call succeeded', (tester) async {
    final calls = <String>[];
    final deleting = Completer<void>();
    await _openSheet(
      tester,
      (context) => showDeleteAccountSheet(
        context,
        deleteAccount: () {
          calls.add('delete-user-account');
          return deleting.future;
        },
      ),
      overrides: [
        appSignOutProvider.overrideWithValue(
          () async => calls.add('appSignOut'),
        ),
      ],
    );

    await _confirmDelete(tester);
    expect(calls, [
      'delete-user-account',
    ], reason: 'no sign-out while the delete is still running');

    deleting.complete();
    await tester.pump();
    expect(calls, ['delete-user-account', 'appSignOut']);
  });

  testWidgets('a failed account delete keeps the user signed in and shows the '
      'delete error', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    var signOuts = 0;
    await _openSheet(
      tester,
      (context) => showDeleteAccountSheet(
        context,
        deleteAccount: () async => throw Exception('delete-user-account: 500'),
      ),
      overrides: [appSignOutProvider.overrideWithValue(() async => signOuts++)],
    );

    await _confirmDelete(tester);
    await tester.pumpAndSettle();

    expect(signOuts, 0, reason: 'signed in, token still registered');
    expect(find.text(l10n.deleteAccountError), findsOneWidget);
  });
}
