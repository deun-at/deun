import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake friends notifier that avoids the real notifier's Supabase realtime
/// channel subscription, mirroring group_edit_screen_test.dart's fake — the
/// group-currency probe under test here has nothing to do with friends.
class _FakeFriendshipListNotifier extends FriendshipListNotifier {
  @override
  Future<FriendshipListState> build() async =>
      const FriendshipListState(acceptedFriends: []);
}

Group _group(String code) => Group()
  ..id = 'g1'
  ..name = 'Trip'
  ..colorValue = kBrandSeed.toARGB32()
  ..simplifiedExpenses = true
  ..createdAt = ''
  ..userId = null
  ..currencyCode = code
  ..groupMembers = []
  ..groupSharesSummary = {}
  ..totalExpenses = 0
  ..totalShareAmount = 0;

Expense _expense({String? originalCurrency}) => Expense()
  ..loadDataFromJson({
    'id': 'e1',
    'group_id': 'g1',
    'name': 'Ramen',
    'expense_date': '2026-08-16',
    'created_at': '2026-08-16T10:00:00',
    'is_paid_back_row': false,
    'original_currency_code': originalCurrency,
  });

Future<void> pumpGroupEdit(
  WidgetTester tester, {
  required Group group,
  required Future<List<Expense>> Function(String groupId) probe,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendshipListProvider.overrideWith(
          () => _FakeFriendshipListNotifier(),
        ),
      ],
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
            child: GroupEdit(group: group, loadGroupExpenseCurrencies: probe),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  group('canChangeGroupCurrency reads real expense currencies', () {
    test('no expenses — unchanged, the picker stays open', () {
      expect(canChangeGroupCurrency(_group('EUR')), isTrue);
      expect(canChangeGroupCurrency(_group('EUR'), expenses: const []), isTrue);
    });

    test('every expense in the group currency — still open', () {
      expect(
        canChangeGroupCurrency(
          _group('EUR'),
          expenses: [
            _expense(),
            _expense(originalCurrency: 'EUR'),
          ],
        ),
        isTrue,
      );
    });

    test('ONE expense in another currency locks the group', () {
      expect(
        canChangeGroupCurrency(
          _group('EUR'),
          expenses: [
            _expense(),
            _expense(originalCurrency: 'JPY'),
          ],
        ),
        isFalse,
      );
    });

    test(
      'an unknown original code resolves to EUR and does not lock a EUR group',
      () {
        // Currency.fromCode('XYZ') falls back to EUR, which IS the group
        // currency, so a garbage code cannot lock a group out of its picker.
        expect(
          canChangeGroupCurrency(
            _group('EUR'),
            expenses: [_expense(originalCurrency: 'XYZ')],
          ),
          isTrue,
        );
      },
    );

    test(
      'a JPY group is locked by a EUR expense, not only the other way round',
      () {
        expect(
          canChangeGroupCurrency(
            _group('JPY'),
            expenses: [_expense(originalCurrency: 'EUR')],
          ),
          isFalse,
        );
      },
    );
  });

  group('the group edit picker follows the probe', () {
    testWidgets(
      'a probe finding a foreign-currency expense locks the picker and says why',
      (tester) async {
        await pumpGroupEdit(
          tester,
          group: _group('EUR'),
          probe: (_) async => [_expense(originalCurrency: 'JPY')],
        );
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.groupCurrencyLockedNote), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      },
    );

    testWidgets(
      'a probe finding nothing leaves the picker open with the relabel note',
      (tester) async {
        await pumpGroupEdit(
          tester,
          group: _group('EUR'),
          probe: (_) async => const <Expense>[],
        );
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.groupCurrencyRelabelNote), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      },
    );

    testWidgets(
      'a FAILING probe degrades to an open picker rather than erroring',
      (tester) async {
        await pumpGroupEdit(
          tester,
          group: _group('EUR'),
          probe: (_) async => throw Exception('offline'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      },
    );
  });
}
