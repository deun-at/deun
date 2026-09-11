import 'dart:io';

import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/widgets/restyle/currency_breakdown_disclosure.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acceptance tests for multi-currency-group. Every assertion restates one
/// acceptance criterion from the plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the home-currency surface is gone', () {
    test(
      'currency_conversion.dart and exchange_rate_service.dart do not exist',
      () {
        expect(
          File('lib/helper/currency_conversion.dart').existsSync(),
          isFalse,
        );
        expect(
          File('lib/helper/exchange_rate_service.dart').existsSync(),
          isFalse,
        );
      },
    );

    test('grepping lib/ for homeCurrency returns no matches', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('homeCurrency')) {
          hits.add(entity.path);
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'no code path may reference a home currency',
      );
    });

    test('no code path fetches an exchange rate', () {
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('package:http/') ||
            source.contains('frankfurter') ||
            source.contains('ExchangeRate')) {
          hits.add(entity.path);
        }
      }
      expect(hits, isEmpty);
    });

    test('http is no longer a dependency of the app', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        RegExp(r'^\s+http:\s', multiLine: true).hasMatch(pubspec),
        isFalse,
        reason:
            'exchange_rate_service.dart was its only importer; the app now '
            'genuinely has no HTTP client',
      );
    });

    test('the deleted features\' test files are removed, not skipped', () {
      expect(
        File('test/helper/currency_conversion_test.dart').existsSync(),
        isFalse,
      );
      expect(
        File('test/provider/home_currency_test.dart').existsSync(),
        isFalse,
      );
    });

    test(
      'the home-currency and approximate l10n strings are gone from both locales',
      () async {
        for (final locale in const [Locale('en'), Locale('de')]) {
          final l10n = await AppLocalizations.delegate.load(locale);
          // The generated class no longer declares them, so this compiles only
          // while they are absent; the runtime check pins the ARB files too.
          expect(
            File('lib/l10n/app_${locale.languageCode}.arb').readAsStringSync(),
            isNot(contains('settingsHomeCurrency')),
          );
          expect(
            File('lib/l10n/app_${locale.languageCode}.arb').readAsStringSync(),
            isNot(contains('homeAggregate')),
          );
          expect(l10n.localeName, locale.languageCode);
        }
      },
    );

    test(
      'no "≈ approximate" marker survives: MoneyText has no approximate flag',
      () {
        final source = File(
          'lib/widgets/restyle/money_text.dart',
        ).readAsStringSync();
        expect(source, isNot(contains('approximate')));
        expect(source, isNot(contains('≈')));
      },
    );
  });

  group('CurrencyBreakdownDisclosure', () {
    Widget harness(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeBuilder(
        colorValue: 0xFF5750E6,
        builder: (context) => Scaffold(body: child),
      ),
    );

    const twoCurrencies = CurrencyBreakdown(
      primary: CurrencyAmount(Currency.jpy, 3000),
      others: [CurrencyAmount(Currency.eur, -25.50)],
    );

    testWidgets(
      'a single-currency breakdown shows no expand affordance at all',
      (tester) async {
        await tester.pumpWidget(
          harness(
            const CurrencyBreakdownDisclosure(
              breakdown: CurrencyBreakdown(
                primary: CurrencyAmount(Currency.eur, 10),
              ),
              foreground: Colors.black,
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets('two currencies disclose exactly one, never a count of zero', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        harness(
          const CurrencyBreakdownDisclosure(
            breakdown: twoCurrencies,
            foreground: Colors.black,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(l10n.currencyBreakdownMore(1)), findsOneWidget);
      expect(find.text(l10n.currencyBreakdownMore(0)), findsNothing);
    });

    testWidgets(
      'expanding reveals one row per remaining currency at its own decimal digits',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(
          harness(
            const CurrencyBreakdownDisclosure(
              breakdown: twoCurrencies,
              foreground: Colors.black,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('EUR'), findsNothing);

        await tester.tap(find.text(l10n.currencyBreakdownMore(1)));
        await tester.pumpAndSettle();

        expect(find.text('EUR'), findsOneWidget);
        // The code identifies the row, so the amount is bare — a symbol here
        // would either duplicate the code (CHF) or fail to distinguish the
        // seven currencies that share "$".
        expect(find.text('-25.50'), findsOneWidget);
        // The primary is NOT repeated in the expanded list when there is no
        // selector.
        expect(find.text('JPY'), findsNothing);
      },
    );

    testWidgets('a currency whose symbol is its code is labelled once', (
      tester,
    ) async {
      // CHF (and RON) render their symbol as the code itself. The code column
      // carries the identity; the amount must not repeat it.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        harness(
          const CurrencyBreakdownDisclosure(
            breakdown: CurrencyBreakdown(
              primary: CurrencyAmount(Currency.eur, 10),
              others: [CurrencyAmount(Currency.chf, -2.14)],
            ),
            foreground: Colors.black,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.currencyBreakdownMore(1)));
      await tester.pumpAndSettle();

      expect(find.text('CHF'), findsOneWidget);
      expect(find.text('-2.14'), findsOneWidget);
    });

    testWidgets('every disclosed row carries its own code label', (
      tester,
    ) async {
      // The regression this guards: an unlabelled row reads as a continuation
      // of the row above it.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        harness(
          const CurrencyBreakdownDisclosure(
            breakdown: CurrencyBreakdown(
              primary: CurrencyAmount(Currency.eur, 10.59),
              others: [
                CurrencyAmount(Currency.usd, -4),
                CurrencyAmount(Currency.chf, -2.14),
              ],
            ),
            foreground: Colors.black,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.currencyBreakdownMore(2)));
      await tester.pumpAndSettle();

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('CHF'), findsOneWidget);
      expect(find.text('-4.00'), findsOneWidget);
      expect(find.text('-2.14'), findsOneWidget);
    });

    testWidgets('collapsing restores the inline state', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        harness(
          const CurrencyBreakdownDisclosure(
            breakdown: twoCurrencies,
            foreground: Colors.black,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.currencyBreakdownMore(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.currencyBreakdownMore(1)));
      await tester.pumpAndSettle();
      expect(find.text('EUR'), findsNothing);
    });

    testWidgets('each expanded row carries its own direction and colour', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        harness(
          const CurrencyBreakdownDisclosure(
            breakdown: CurrencyBreakdown(
              primary: CurrencyAmount(Currency.jpy, 3000),
              others: [
                CurrencyAmount(Currency.eur, -25.50),
                CurrencyAmount(Currency.usd, 40),
              ],
            ),
            foreground: Colors.black,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.currencyBreakdownMore(2)));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(CurrencyBreakdownDisclosure));
      final semantic = Theme.of(ctx).extension<SemanticColors>()!;
      expect(
        tester.widget<Text>(find.text('-25.50')).style?.color,
        semantic.danger,
      );
      expect(
        tester.widget<Text>(find.text('40.00')).style?.color,
        semantic.success,
      );
    });

    testWidgets(
      'as a selector it lists the primary too, so the user can switch back',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final picked = <Currency>[];
        await tester.pumpWidget(
          harness(
            CurrencyBreakdownDisclosure(
              breakdown: twoCurrencies,
              foreground: Colors.black,
              selected: Currency.jpy,
              onSelected: picked.add,
            ),
          ),
        );
        await tester.pump();
        // The count is always the hidden-currency count — one here — in both
        // modes. Selector mode changes the WORDING (it names the switch rather
        // than promising "+N more rows"), which is what lets it list the
        // primary as well without contradicting the count.
        expect(find.text(l10n.currencyBreakdownSelect(1)), findsOneWidget);
        expect(find.text(l10n.currencyBreakdownSelect(2)), findsNothing);
        expect(find.text(l10n.currencyBreakdownMore(1)), findsNothing);

        await tester.tap(find.text(l10n.currencyBreakdownSelect(1)));
        await tester.pumpAndSettle();

        expect(find.byType(MoneyText), findsNWidgets(2));
        expect(find.text('JPY'), findsOneWidget);
        expect(find.text('EUR'), findsOneWidget);
        await tester.tap(find.text('EUR'));
        await tester.pumpAndSettle();
        expect(picked, [Currency.eur]);
      },
    );

    testWidgets(
      'without a selector the label counts the hidden currencies only',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(
          harness(
            const CurrencyBreakdownDisclosure(
              breakdown: CurrencyBreakdown(
                primary: CurrencyAmount(Currency.jpy, 3000),
                others: [
                  CurrencyAmount(Currency.eur, -25.50),
                  CurrencyAmount(Currency.usd, 40),
                ],
              ),
              foreground: Colors.black,
            ),
          ),
        );
        await tester.pump();
        expect(find.text(l10n.currencyBreakdownMore(2)), findsOneWidget);

        await tester.tap(find.text(l10n.currencyBreakdownMore(2)));
        await tester.pumpAndSettle();
        // Exactly the two it promised — the inline primary is not repeated.
        expect(find.byType(MoneyText), findsNWidgets(2));
      },
    );

    testWidgets(
      'the expanded state is local and starts collapsed on a fresh mount',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.pumpWidget(
          harness(
            const CurrencyBreakdownDisclosure(
              key: ValueKey('a'),
              breakdown: twoCurrencies,
              foreground: Colors.black,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.currencyBreakdownMore(1)));
        await tester.pumpAndSettle();
        expect(find.text('EUR'), findsOneWidget);

        // A fresh mount (what an app relaunch gives you) is collapsed again:
        // nothing was persisted.
        await tester.pumpWidget(
          harness(
            const CurrencyBreakdownDisclosure(
              key: ValueKey('b'),
              breakdown: twoCurrencies,
              foreground: Colors.black,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('EUR'), findsNothing);
      },
    );
  });

  group('the personal statistics state has no estimate machinery', () {
    test(
      'approximate and excludedCount are gone from the state and its widgets',
      () {
        final files = [
          'lib/pages/statistics/statistics_models.dart',
          'lib/pages/statistics/provider/personal_statistics_notifiers.dart',
          'lib/pages/statistics/widgets/personal_summary_section.dart',
          'lib/pages/groups/presentation/group_list.dart',
          'lib/pages/groups/presentation/group_list_view_model.dart',
          'lib/pages/friends/data/friendship_model.dart',
        ];
        for (final path in files) {
          final source = File(path).readAsStringSync();
          expect(source, isNot(contains('approximate')), reason: path);
          expect(source, isNot(contains('excludedCount')), reason: path);
        }
      },
    );
  });

  group('settled classification uses the group\'s own currency', () {
    Group g(String id, double net, String code) {
      final group = Group();
      group.id = id;
      group.name = id;
      group.colorValue = 0;
      group.simplifiedExpenses = true;
      group.createdAt = '';
      group.userId = null;
      group.currencyCode = code;
      group.groupMembers = [];
      group.groupSharesSummary = {};
      group.totalExpenses = 0;
      group.totalShareAmount = net;
      group.expenses = null;
      return group;
    }

    test('a JPY group at 0.4 is settled and at 0.6 is active', () {
      final groups = [g('lo', 0.4, 'JPY'), g('hi', 0.6, 'JPY')];
      expect(
        GroupRepository.narrowToStatus(groups, 'active').map((x) => x.id),
        ['hi'],
      );
      expect(GroupRepository.narrowToStatus(groups, 'done').map((x) => x.id), [
        'lo',
      ]);
    });

    test('a EUR group at 0.004 is settled and at 0.006 is active', () {
      final groups = [g('lo', 0.004, 'EUR'), g('hi', 0.006, 'EUR')];
      expect(
        GroupRepository.narrowToStatus(groups, 'active').map((x) => x.id),
        ['hi'],
      );
    });

    test('the query bounds are a superset in both directions', () {
      // active filters on the SMALLEST supported epsilon, done on the LARGEST,
      // so neither tab can drop a row before isSettled judges it per currency.
      expect(
        GroupRepository.activeBalanceFilter,
        contains('gte.$kSettledEpsilon'),
      );
      expect(kSettledEpsilon, Currency.eur.settledEpsilon);
      expect(kMaxSettledEpsilon, Currency.jpy.settledEpsilon);
      expect(kSettledEpsilon, lessThan(kMaxSettledEpsilon));
    });

    test('a group\'s tab placement and its row rendering cannot disagree', () {
      // One predicate decides both: narrowToStatus and GroupListItem call the
      // same isSettled(amount, currency).
      final jpy = g('jpy', 0.4, 'JPY');
      expect(GroupRepository.narrowToStatus([jpy], 'active'), isEmpty);
      expect(isSettled(jpy.totalShareAmount, jpy.currency), isTrue);
    });

    test(
      'Group.currency resolves the persisted code, unknown falls back to EUR',
      () {
        expect(g('a', 0, 'JPY').currency, Currency.jpy);
        expect(g('b', 0, 'XYZ').currency, Currency.eur);
      },
    );
  });

  group('canChangeGroupCurrency', () {
    test(
      'is true for every group today — no expense carries its own currency yet',
      () {
        final g = Group()
          ..loadDataFromJson({
            'id': 'g1',
            'name': 'Trip',
            'color_value': 0,
            'simplified_expenses': true,
            'created_at': '',
            'user_id': null,
            'currency_code': 'USD',
            'group_member': const [],
            'group_shares_summary': const [],
          });
        expect(canChangeGroupCurrency(g), isTrue);
      },
    );
  });
}
