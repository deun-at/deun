import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/expenses/expense_detail.dart';
import 'pages/expenses/expense_list.dart';
import 'pages/groups/group_detail.dart';
import 'pages/groups/group_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'constants.dart';
import 'pages/settings/setting.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorGroupKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellGroup');
final _shellNavigatorExpenseKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellExpense');
final _shellNavigatorSettingKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellSetting');

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late RouterConfig<Object> _routerConfig;

  ColorSeed colorSelected = ColorSeed.baseColor;

  void handleColorSelect(int value) {
    setState(() {
      colorSelected = ColorSeed.values[value];
    });
  }

  @override
  void initState() {
    super.initState();

    // the one and only GoRouter instance
    _routerConfig = GoRouter(
      initialLocation: '/group',
      navigatorKey: _rootNavigatorKey,
      routes: [
        // Stateful nested navigation based on:
        // https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            // the UI shell
            return ScaffoldWithNestedNavigation(
                navigationShell: navigationShell);
          },
          branches: [
            // first branch (Group)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorGroupKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/group',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: GroupList(
                        colorSelected: colorSelected,
                        handleColorSelect: handleColorSelect),
                  ),
                  routes: [
                    // child route
                    GoRoute(
                        path: 'details',
                        builder: (context, state) {
                          int groupDocId = int.parse(state.uri.queryParameters["groupDocId"] as String);
                          return GroupDetail(
                              handleColorSelect: handleColorSelect,
                              groupDocId: groupDocId);
                        },
                        routes: [
                          GoRoute(
                              path: 'expense',
                              builder: (context, state) {
                                int groupDocId = int.parse(state.uri.queryParameters["groupDocId"] as String);
                                int expenseDocId = int.parse(state.uri.queryParameters["expenseDocId"] as String);
                                return ExpenseDetail(
                                    handleColorSelect: handleColorSelect,
                                    groupDocId: groupDocId,
                                    expenseDocId: expenseDocId,
                                  );
                              })
                        ]),
                  ],
                ),
              ],
            ),
            // second branch (Expense)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorExpenseKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/expense',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: ExpenseList(
                        colorSelected: colorSelected,
                        handleColorSelect: handleColorSelect),
                  ),
                ),
              ],
            ),
            // third branch (Setting)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorSettingKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/setting',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    // child: Setting(),
                    child: Scaffold(body: Text('hans')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _routerConfig,
      title: 'SplitIt',
      theme: ThemeData(
          colorSchemeSeed: colorSelected.color,
          useMaterial3: true,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: colorSelected.color,
          useMaterial3: true,
          brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
class ScaffoldWithNestedNavigation extends StatelessWidget {
  const ScaffoldWithNestedNavigation({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('ScaffoldWithNestedNavigation'));
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: navigationShell.currentIndex,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: const Icon(Icons.group),
            icon: const Icon(Icons.group_outlined),
            label: AppLocalizations.of(context)!.groups,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.receipt_long),
            icon: const Icon(Icons.receipt_long_outlined),
            label: AppLocalizations.of(context)!.expenses,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.settings),
            icon: const Icon(Icons.settings_outlined),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
