import 'package:deun/pages/expenses/expense_model.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/expenses/expense_detail.dart';
import 'pages/expenses/expense_list.dart';
import 'pages/groups/group_detail.dart';
import 'pages/groups/group_detail_edit.dart';
import 'pages/groups/group_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'pages/groups/group_model.dart';
import 'pages/settings/setting.dart';
import 'widgets/modal_bottom_sheet_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorGroupKey = GlobalKey<NavigatorState>(debugLabel: 'shellGroup');
final _shellNavigatorExpenseKey = GlobalKey<NavigatorState>(debugLabel: 'shellExpense');
final _shellNavigatorSettingKey = GlobalKey<NavigatorState>(debugLabel: 'shellSetting');

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late RouterConfig<Object> _routerConfig;

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
            return ScaffoldWithNestedNavigation(navigationShell: navigationShell);
          },
          branches: [
            // first branch (Group)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorGroupKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/group',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: GroupList(),
                  ),
                  routes: [
                    // child route
                    GoRoute(
                        path: 'details',
                        pageBuilder: (context, state) {
                          var group = state.extra as Group;

                          return defaultTransitionPage(state.pageKey, GroupDetail(group: group));
                        },
                        routes: [
                          GoRoute(
                              path: 'expense',
                              pageBuilder: (context, state) {
                                var extra = state.extra as Map<String, dynamic>;
                                var group = extra['group'] as Group;
                                var expense = extra['expense'] as Expense?;

                                return ModalBottomSheetPage(
                                  key: state.pageKey,
                                  builder: (context) => ExpenseBottomSheet(
                                    group: group,
                                    expense: expense,
                                  ),
                                );
                              })
                        ]),
                    GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) {
                          var group = state.extra as Group?;

                          return ModalBottomSheetPage(
                            key: state.pageKey,
                            builder: (context) => GroupBottomSheet(
                              group: group,
                            ),
                          );
                        })
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
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: ExpenseList(),
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
                    child: Setting(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  CustomTransitionPage<dynamic> defaultTransitionPage(LocalKey key, Widget child) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: Durations.long1,
      reverseTransitionDuration: Durations.long1,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Change the opacity of the screen using a Curve based on the the animation's
        // value
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeIn).animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color colorSelected = ref.watch(themeColorProvider);

    return MaterialApp.router(
      routerConfig: _routerConfig,
      title: 'Deun',
      theme: ThemeData(colorSchemeSeed: colorSelected, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: colorSelected, useMaterial3: true, brightness: Brightness.dark),
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
