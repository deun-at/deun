import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/presentation/friend_detail_sheet.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Friendship _friendship({
  required double shareAmount,
  String? paypalMe,
  String? iban,
}) {
  final f = Friendship();
  f.user = SupaUser(
    email: 'sam@test.com',
    displayName: 'Sam',
    username: 'sam',
    usernameCode: '0001',
    paypalMe: paypalMe,
    iban: iban,
  );
  f.status = 'accepted';
  f.isIncomingRequest = false;
  f.shareAmount = shareAmount;
  return f;
}

Future<void> _pump(
  WidgetTester tester, {
  required Friendship friendship,
  Brightness brightness = Brightness.light,
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
          data: getThemeData(context, kBrandSeed, brightness)
              .copyWith(splashFactory: NoSplash.splashFactory),
          child: Scaffold(
            body: FriendDetailSheet(friendship: friendship),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows friend name and balance', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam'));

    expect(find.text('Sam'), findsOneWidget);
    // The header renders the signed net balance (you owe Sam → negative).
    expect(find.text(l10n.toCurrency(-25.0)), findsOneWidget);
  });

  testWidgets('owe state shows pay-back methods: PayPal only when set, IBAN only when set, Mark paid always',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam'));

    // Sam has PayPal but no IBAN.
    expect(find.text(l10n.paymentMethodPaypal), findsOneWidget);
    expect(find.text(l10n.paymentMethodIban), findsNothing);
    expect(find.text(l10n.payBackDialogDone), findsOneWidget);
  });

  testWidgets('IBAN method appears when the friend has an IBAN', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: -25.0, iban: 'DE123'));

    expect(find.text(l10n.paymentMethodIban), findsOneWidget);
    expect(find.text(l10n.paymentMethodPaypal), findsNothing);
    expect(find.text(l10n.payBackDialogDone), findsOneWidget);
  });

  testWidgets('settled / owed friend shows no pay-back methods', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: 15.0, paypalMe: 'sam', iban: 'DE1'));

    // The current user is owed money → nothing to pay back.
    expect(find.text(l10n.paymentMethodPaypal), findsNothing);
    expect(find.text(l10n.paymentMethodIban), findsNothing);
    expect(find.text(l10n.payBackDialogDone), findsNothing);
  });

  testWidgets('remove-friend action is present', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: -25.0));

    expect(find.text(l10n.friendshipDialogRemoveAsFriend), findsOneWidget);
  });

  testWidgets('tapping Copy IBAN writes to the clipboard', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _pump(tester, friendship: _friendship(shareAmount: -25.0, iban: 'DE89370400440532013000'));

    await tester.tap(find.text(l10n.paymentMethodIban));
    await tester.pumpAndSettle();

    expect(clipboardText, 'DE89370400440532013000');
  });

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam', iban: 'DE1'),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sam'), findsOneWidget);
  });
}
