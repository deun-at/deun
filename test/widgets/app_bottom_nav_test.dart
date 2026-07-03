import 'package:deun/constants.dart';
import 'package:deun/widgets/restyle/app_bottom_nav.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deun/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shared pump helper — matches the idiom in restyle_widgets_test.dart
// ---------------------------------------------------------------------------

/// Three fixed items to use across all tests.
List<AppBottomNavItem> _items() => const [
      AppBottomNavItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Groups',
      ),
      AppBottomNavItem(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Friends',
      ),
      AppBottomNavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          splashFactory: NoSplash.splashFactory,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, brightness),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // Labels
  // -------------------------------------------------------------------------
  group('AppBottomNav — labels', () {
    testWidgets('renders all three labels', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Icon selection
  // -------------------------------------------------------------------------
  group('AppBottomNav — icon variants', () {
    testWidgets('shows selectedIcon for active tab and unselected icon for others (index 0)', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      // Active tab (index 0) uses selectedIcon
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      // Inactive tabs use the outlined icon
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows selectedIcon for active tab at index 1', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 1,
          onSelect: (_) {},
        ),
      );
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows selectedIcon for active tab at index 2', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 2,
          onSelect: (_) {},
        ),
      );
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Tap / onSelect
  // -------------------------------------------------------------------------
  group('AppBottomNav — tap callbacks', () {
    testWidgets('tapping tab 0 calls onSelect(0)', (tester) async {
      int? selected;
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 1,
          onSelect: (i) => selected = i,
        ),
      );
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(selected, 0);
    });

    testWidgets('tapping tab 1 calls onSelect(1)', (tester) async {
      int? selected;
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (i) => selected = i,
        ),
      );
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    });

    testWidgets('tapping tab 2 calls onSelect(2)', (tester) async {
      int? selected;
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (i) => selected = i,
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Badge
  // -------------------------------------------------------------------------
  group('AppBottomNav — badge', () {
    testWidgets('badgeCount > 0 on tab 1 shows a Badge widget', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: [
            _items()[0],
            const AppBottomNavItem(
              icon: Icons.group_outlined,
              selectedIcon: Icons.group,
              label: 'Friends',
              badgeCount: 3,
            ),
            _items()[2],
          ],
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      // Badge widget should be present
      expect(find.byType(Badge), findsAtLeastNWidgets(1));
      // Badge label shows the count
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('badgeCount = 0 shows no Badge', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      expect(find.byType(Badge), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Color tokens — active vs inactive
  // -------------------------------------------------------------------------
  group('AppBottomNav — color tokens', () {
    testWidgets('active icon uses colorScheme.primary color', (tester) async {
      late Color primaryColor;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
          home: Builder(
            builder: (context) {
              final theme = getThemeData(context, kBrandSeed, Brightness.light);
              primaryColor = theme.colorScheme.primary;
              return Theme(
                data: theme,
                child: Scaffold(
                  body: AppBottomNav(
                    items: _items(),
                    selectedIndex: 0,
                    onSelect: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The active icon (receipt_long) should have primary color
      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.receipt_long));
      expect(activeIcon.color, primaryColor);
    });

    testWidgets('inactive icon uses colorScheme.onSurfaceVariant color', (tester) async {
      late Color onSurfaceVariantColor;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
          home: Builder(
            builder: (context) {
              final theme = getThemeData(context, kBrandSeed, Brightness.light);
              onSurfaceVariantColor = theme.colorScheme.onSurfaceVariant;
              return Theme(
                data: theme,
                child: Scaffold(
                  body: AppBottomNav(
                    items: _items(),
                    selectedIndex: 0,
                    onSelect: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An inactive icon (group_outlined at index 1) should use onSurfaceVariant
      final inactiveIcon = tester.widget<Icon>(find.byIcon(Icons.group_outlined));
      expect(inactiveIcon.color, onSurfaceVariantColor);
    });
  });

  // -------------------------------------------------------------------------
  // Reduced-motion: pill animation duration collapses to zero
  // -------------------------------------------------------------------------
  group('AppBottomNav — reduced motion', () {
    testWidgets('with disableAnimations true the bar renders without settling delay', (tester) async {
      // With disableAnimations=true the AnimatedAlign/AnimatedPositioned inside
      // should use Duration.zero. We simply verify the widget builds and all
      // labels are visible immediately (pump without pumpAndSettle would be OK
      // too, but settle is fine — it just means zero-duration animations finish
      // before settle returns).
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.light, splashFactory: NoSplash.splashFactory),
            home: Builder(
              builder: (context) {
                final theme = getThemeData(context, kBrandSeed, Brightness.light);
                return Theme(
                  data: theme,
                  child: Scaffold(
                    body: AppBottomNav(
                      items: _items(),
                      selectedIndex: 0,
                      onSelect: (_) {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      // Pump a single frame — with zero-duration animation everything should be
      // settled already.
      await tester.pump();
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Semantics
  // -------------------------------------------------------------------------
  group('AppBottomNav — semantics', () {
    testWidgets('each tab exposes a Semantics node with isButton', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          // Select index 2 so Groups and Friends are both NOT selected —
          // avoids needing to special-case isSelected for the active tab
          // in the same assertion set.
          selectedIndex: 2,
          onSelect: (_) {},
        ),
      );
      // Inactive tabs: isButton=true, isSelected=false, hasSelectedState=true
      // (Flutter sets hasSelectedState whenever the Semantics 'selected' param
      // is provided — even when false — so we must declare it explicitly.)
      expect(
        tester.getSemantics(find.text('Groups')),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          label: 'Groups',
        ),
      );
      expect(
        tester.getSemantics(find.text('Friends')),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          label: 'Friends',
        ),
      );
      // Active tab (Settings, index 2): isButton=true, isSelected=true,
      // hasSelectedState=true (Flutter sets this automatically when
      // isSelected is used).
      expect(
        tester.getSemantics(find.text('Settings')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Settings',
        ),
      );
      handle.dispose();
    });

    testWidgets('active tab is marked selected in semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 1,
          onSelect: (_) {},
        ),
      );
      // The active tab (Friends, index 1) should be selected.
      // hasSelectedState is set by Flutter automatically alongside isSelected.
      expect(
        tester.getSemantics(find.text('Friends')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Friends',
        ),
      );
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // Bar geometry
  // -------------------------------------------------------------------------
  group('AppBottomNav — bar height', () {
    testWidgets('bar is 78px tall', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );
      final barFinder = find.byType(AppBottomNav);
      expect(barFinder, findsOneWidget);
      final barSize = tester.getSize(barFinder);
      expect(barSize.height, 78.0);
    });
  });

  // -------------------------------------------------------------------------
  // Active indicator (pill) hugs ONLY the icon, not the icon+label (F98)
  // -------------------------------------------------------------------------
  group('AppBottomNav — active pill hugs icon only', () {
    testWidgets('pill is icon-sized (52x34), not item-width', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );

      final barWidth = tester.getSize(find.byType(AppBottomNav)).width;
      final slotWidth = barWidth / 3;

      // The pill is the DecoratedBox with a fully-rounded (stadium) fill.
      final pillSize = tester.getSize(
        find.byKey(const Key('nav-active-pill')),
      );
      // Pill stays the fixed 52x34 icon pill — much narrower than a tab slot,
      // so it cannot be spanning the whole icon+label item.
      expect(pillSize.width, 52.0);
      expect(pillSize.height, 34.0);
      expect(pillSize.width, lessThan(slotWidth));
    });

    testWidgets('pill sits behind the icon and the label is BELOW the pill', (tester) async {
      await _pump(
        tester,
        AppBottomNav(
          items: _items(),
          selectedIndex: 0,
          onSelect: (_) {},
        ),
      );

      final pillRect = tester.getRect(find.byKey(const Key('nav-active-pill')));
      final activeIconRect = tester.getRect(find.byIcon(Icons.receipt_long));
      final labelRect = tester.getRect(find.text('Groups'));

      // Icon center is vertically within the pill (pill hugs the icon).
      expect(activeIconRect.center.dy, greaterThanOrEqualTo(pillRect.top));
      expect(activeIconRect.center.dy, lessThanOrEqualTo(pillRect.bottom));

      // The label sits below the pill: its center is beneath the pill's
      // bottom edge, so the highlight does NOT span the label.
      expect(labelRect.center.dy, greaterThan(pillRect.bottom));
    });
  });
}
