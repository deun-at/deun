import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/presentation/pending_request_list.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required void Function(String, String) onAccept,
  required void Function(String, String) onDecline,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: getThemeData(context, kBrandSeed, Brightness.light)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(
            body: PendingRequestList(
              isLoading: false,
              onAccept: onAccept,
              onDecline: onDecline,
              pendingRequests: const [
                {
                  'email': 'friend@test.com',
                  'display_name': 'Friend',
                  'username': 'friend',
                  'user_code': '0001',
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Accept action fires onAccept with the request identity',
      (tester) async {
    String? acceptedEmail;
    var declineCalls = 0;
    await _pump(
      tester,
      onAccept: (email, name) => acceptedEmail = email,
      onDecline: (email, name) => declineCalls++,
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.accept));
    await tester.pump();

    expect(acceptedEmail, 'friend@test.com');
    expect(declineCalls, 0);
  });

  testWidgets('Decline action fires onDecline with the request identity',
      (tester) async {
    String? declinedEmail;
    var acceptCalls = 0;
    await _pump(
      tester,
      onAccept: (email, name) => acceptCalls++,
      onDecline: (email, name) => declinedEmail = email,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(declinedEmail, 'friend@test.com');
    expect(acceptCalls, 0);
  });
}
