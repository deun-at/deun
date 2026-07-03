import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_category.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/widgets/restyle/expense_picker_sheets.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

GroupMember _member(String email, String name, {String? username}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.username = username;
  m.usernameCode = username != null ? '0001' : null;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
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
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CategoryGridSheet', () {
    testWidgets('renders an icon tile for every category', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        const CategoryGridSheet(selected: ExpenseCategory.food),
      );

      expect(find.byType(SheetScaffold), findsOneWidget);
      // Every category display name renders somewhere in the grid.
      for (final c in ExpenseCategory.values) {
        expect(
          find.text(c.getDisplayName(l10n)),
          findsOneWidget,
          reason: 'missing tile for ${c.name}',
        );
      }
    });

    testWidgets('tapping a category pops it as the result', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      ExpenseCategory? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showCategoryGridSheet(
                  context,
                  selected: ExpenseCategory.food,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ExpenseCategory.travel.getDisplayName(l10n)));
      await tester.pumpAndSettle();

      expect(result, ExpenseCategory.travel);
    });

    testWidgets('chips are colorless: selected uses primary, unselected a '
        'neutral surface (no per-category color)', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      late ColorScheme scheme;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return const CategoryGridSheet(selected: ExpenseCategory.food);
          },
        ),
      );

      // The decorated container wrapping each category's icon.
      Color fillOf(ExpenseCategory c) {
        final containerFinder = find.ancestor(
          of: find.byIcon(c.getIcon()),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        final container = tester.widget<Container>(containerFinder.first);
        return (container.decoration as BoxDecoration).color!;
      }
      // Keep l10n referenced (labels are asserted in sibling tests).
      expect(ExpenseCategory.food.getDisplayName(l10n), isNotEmpty);

      // Selected tile uses the theme's primary fill (standard selected
      // treatment) — not the per-category color.
      expect(fillOf(ExpenseCategory.food), scheme.primary);

      // Two different unselected categories share the SAME neutral fill,
      // proving there is no per-category tinting.
      final a = fillOf(ExpenseCategory.travel);
      final b = fillOf(ExpenseCategory.other);
      expect(a, scheme.surfaceContainerLowest);
      expect(a, b);
      expect(a, isNot(scheme.primary));
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await _pump(
        tester,
        const CategoryGridSheet(selected: ExpenseCategory.coffee),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PaidBySheet', () {
    testWidgets('renders a row per member and pops the chosen email',
        (tester) async {
      final members = [
        _member('a@test.com', 'Alice', username: 'alice'),
        _member('b@test.com', 'Bob', username: 'bob'),
      ];
      String? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showPaidBySheet(
                  context,
                  members: members,
                  selectedEmail: 'a@test.com',
                  currentUserEmail: 'a@test.com',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(SheetScaffold), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      expect(result, 'b@test.com');
    });
  });

  group('AmountKeypadSheet', () {
    testWidgets('builds up an amount and confirms the value', (tester) async {
      double? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAmountKeypadSheet(context, initialAmount: 0);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Type 12.50
      await tester.tap(find.byKey(const ValueKey('keypad_1')));
      await tester.tap(find.byKey(const ValueKey('keypad_2')));
      await tester.tap(find.byKey(const ValueKey('keypad_decimal')));
      await tester.tap(find.byKey(const ValueKey('keypad_5')));
      await tester.tap(find.byKey(const ValueKey('keypad_0')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();

      expect(result, 12.5);
    });

    testWidgets('enforces the 2-decimal limit', (tester) async {
      double? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAmountKeypadSheet(context, initialAmount: 0);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 5 . 2 5 9  -> third decimal ignored -> 5.25
      await tester.tap(find.byKey(const ValueKey('keypad_5')));
      await tester.tap(find.byKey(const ValueKey('keypad_decimal')));
      await tester.tap(find.byKey(const ValueKey('keypad_2')));
      await tester.tap(find.byKey(const ValueKey('keypad_5')));
      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();

      expect(result, 5.25);
    });

    testWidgets('backspace removes the last digit', (tester) async {
      double? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showAmountKeypadSheet(context, initialAmount: 0);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.tap(find.byKey(const ValueKey('keypad_9')));
      await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();

      expect(result, 9.0);
    });

    testWidgets('seeds the display from the initial amount', (tester) async {
      double? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result =
                    await showAmountKeypadSheet(context, initialAmount: 42.0);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Confirm immediately -> the seeded value round-trips.
      await tester.tap(find.byKey(const ValueKey('keypad_confirm')));
      await tester.pumpAndSettle();
      expect(result, 42.0);
    });
  });
}
