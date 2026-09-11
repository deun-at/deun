import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/presentation/friend_detail_sheet.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/currency_breakdown_disclosure.dart';
import 'package:deun/widgets/restyle/currency_chips.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Friendship _friendship({
  required double shareAmount,
  String? paypalMe,
  String? iban,
  List<CurrencyAmount>? balances,
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
  f.balances = balances ?? [CurrencyAmount(Currency.eur, shareAmount)];
  return f;
}

Future<void> _pump(
  WidgetTester tester, {
  required Friendship friendship,
  Brightness brightness = Brightness.light,
  FriendSettleAll? settleAll,
}) async {
  await tester.pumpWidget(
    ProviderScope(
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
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: Scaffold(
              body: FriendDetailSheet(
                friendship: friendship,
                settleAll: settleAll,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A stubbed cross-group settle, so "Mark as paid" never reaches the network
/// (same seam as `RecordPaybackSheet.recordPayback`).
FriendSettleAll _settle({
  List<String> skipped = const [],
  List<CurrencyAmount> amounts = const [CurrencyAmount(Currency.eur, 25.0)],
}) =>
    (context, email) async => PayBackAllResult(
      settledGroupNames: const ['Trip'],
      skippedGroupNames: skipped,
      settledAmounts: amounts,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // homeCurrencyProvider hydrates via AsyncPreferences over the
    // `async_preferences` channel; stub it so the fetch resolves (default EUR).
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('async_preferences'),
          (call) async => call.method.startsWith('get') ? null : true,
        );
  });

  testWidgets('shows friend name and balance', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam'),
    );

    expect(find.text('Sam'), findsOneWidget);
    // The header renders the signed net balance (you owe Sam → negative).
    expect(find.text(l10n.toCurrency(-25.0)), findsOneWidget);
  });

  testWidgets(
    'owe state shows pay-back methods: PayPal only when set, IBAN only when set, Mark paid always',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam'),
      );

      // Sam has PayPal but no IBAN.
      expect(find.text(l10n.paymentMethodPaypal), findsOneWidget);
      expect(find.text(l10n.paymentMethodIban), findsNothing);
      expect(find.text(l10n.payBackDialogDone), findsOneWidget);
    },
  );

  testWidgets('IBAN method appears when the friend has an IBAN', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0, iban: 'DE123'),
    );

    expect(find.text(l10n.paymentMethodIban), findsOneWidget);
    expect(find.text(l10n.paymentMethodPaypal), findsNothing);
    expect(find.text(l10n.payBackDialogDone), findsOneWidget);
  });

  testWidgets('settled / owed friend shows no pay-back methods', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      friendship: _friendship(shareAmount: 15.0, paypalMe: 'sam', iban: 'DE1'),
    );

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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(
      tester,
      friendship: _friendship(
        shareAmount: -25.0,
        iban: 'DE89370400440532013000',
      ),
    );

    await tester.tap(find.text(l10n.paymentMethodIban));
    await tester.pumpAndSettle();

    expect(clipboardText, 'DE89370400440532013000');
  });

  // payback-on-behalf review: `payBackAll` skips a shared group whose
  // counterparty (or current user) is soft-removed. Confirming the FULL
  // cross-group total in that case tells the user a balance was settled that is
  // still outstanding.
  testWidgets('a fully settled friendship confirms the whole amount', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0),
      settleAll: _settle(),
    );

    await tester.tap(find.text(l10n.payBackDialogDone));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(l10n.payBackSuccess('sam#0001', l10n.toCurrency(25.0))),
      findsOneWidget,
    );
  });

  testWidgets('a skipped group is named instead of reported as paid', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0),
      settleAll: _settle(skipped: ['Flat share', 'Ski trip']),
    );

    await tester.tap(find.text(l10n.payBackDialogDone));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(l10n.payBackPartialSuccess('sam#0001', 'Flat share, Ski trip')),
      findsOneWidget,
    );
    // The full-amount confirmation must NOT be shown — part of it is still open.
    expect(
      find.text(l10n.payBackSuccess('sam#0001', l10n.toCurrency(25.0))),
      findsNothing,
    );
  });

  // A run can write nothing while skipping nothing: the balance settled
  // concurrently, or every target rounded away in its own currency. Naming an
  // amount then renders "You paid back  to sam#0001" with a blank.
  testWidgets(
    'a run that settles nothing and skips nothing reports "nothing to pay back"',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        friendship: _friendship(shareAmount: -25.0),
        settleAll: _settle(amounts: const []),
      );

      await tester.tap(find.text(l10n.payBackDialogDone));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.payBackNoEntries), findsOneWidget);
      expect(
        find.text(l10n.payBackSuccess('sam#0001', '')),
        findsNothing,
        reason: 'a blank amount must never reach the confirmation',
      );
    },
  );

  testWidgets(
    'a run that settles nothing but skipped a group still names the group',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        friendship: _friendship(shareAmount: -25.0),
        settleAll: _settle(amounts: const [], skipped: ['Flat share']),
      );

      await tester.tap(find.text(l10n.payBackDialogDone));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.payBackPartialSuccess('sam#0001', 'Flat share')),
        findsOneWidget,
      );
      expect(find.text(l10n.payBackNoEntries), findsNothing);
    },
  );

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(
      tester,
      friendship: _friendship(shareAmount: -25.0, paypalMe: 'sam', iban: 'DE1'),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('a single-currency friendship sheet shows no disclosure', (
    tester,
  ) async {
    await _pump(tester, friendship: _friendship(shareAmount: -25.0));
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('a single-currency sheet keeps its inline header amount', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, friendship: _friendship(shareAmount: -25.0));

    expect(find.text(l10n.toCurrency(-25.0)), findsOneWidget);
    expect(find.byType(CurrencyChip), findsNothing);
  });

  testWidgets(
    'a mixed-currency sheet states every currency instead of promoting one',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        friendship: _friendship(
          shareAmount: 0,
          balances: const [
            CurrencyAmount(Currency.jpy, 3000),
            CurrencyAmount(Currency.eur, -25.50),
          ],
        ),
      );

      // The header figure is gone: "JPY 3,000" read as the state of the
      // friendship when the truth is you are owed in JPY and owe in EUR.
      expect(find.text('JPY 3,000'), findsNothing);

      // Both currencies are on screen, one chip each, without a tap.
      expect(find.byType(CurrencyChip), findsNWidgets(2));
      expect(find.text('JPY'), findsOneWidget);
      expect(find.text('3,000'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('-25.50'), findsOneWidget);

      // …so there is nothing left to disclose.
      expect(find.byType(CurrencyBreakdownDisclosure), findsNothing);
      expect(find.text(l10n.currencyBreakdownMore(1)), findsNothing);
    },
  );

  testWidgets('each chip is tinted by its own direction', (tester) async {
    await _pump(
      tester,
      friendship: _friendship(
        shareAmount: 0,
        balances: const [
          CurrencyAmount(Currency.jpy, 3000),
          CurrencyAmount(Currency.eur, -25.50),
        ],
      ),
    );

    final ctx = tester.element(find.byType(CurrencyChip).first);
    final semantic = Theme.of(ctx).extension<SemanticColors>()!;
    expect(
      tester.widget<Text>(find.text('3,000')).style?.color,
      semantic.success,
    );
    expect(
      tester.widget<Text>(find.text('-25.50')).style?.color,
      semantic.danger,
    );
  });

  testWidgets(
    'pay-back methods follow the primary currency: JPY-owed shows none',
    (tester) async {
      await _pump(
        tester,
        friendship: _friendship(
          shareAmount: 0,
          paypalMe: 'sam',
          balances: const [
            CurrencyAmount(Currency.jpy, 3000),
            CurrencyAmount(Currency.eur, -25.50),
          ],
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Primary is +¥3,000 (the friend owes the user), so no pay-back card — the
      // direction is NOT inferred from a sum across currencies.
      expect(find.text(l10n.paymentMethodPaypal), findsNothing);
    },
  );

  testWidgets(
    'settling across currencies names each currency in the confirmation',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        friendship: _friendship(
          shareAmount: 0,
          paypalMe: 'sam',
          balances: const [
            CurrencyAmount(Currency.eur, -25.50),
            CurrencyAmount(Currency.jpy, -3000),
          ],
        ),
        settleAll: _settle(
          amounts: const [
            CurrencyAmount(Currency.jpy, 3000),
            CurrencyAmount(Currency.eur, 25.50),
          ],
        ),
      );

      await tester.tap(find.text(l10n.payBackDialogDone));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(l10n.payBackSuccess('sam#0001', 'JPY 3,000 + EUR 25.50')),
        findsOneWidget,
        reason:
            'the confirmation names the per-currency amounts, not one merged '
            'figure',
      );
    },
  );
}
