import 'package:deun/app_paths.dart';
import 'package:deun/deep_links.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/auth/update_password.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/friends/presentation/friend_add_page.dart';
import 'package:deun/pages/friends/presentation/friend_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/friends/presentation/friend_qr_page.dart';
import 'package:deun/pages/friends/presentation/friend_accept_page.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/groups/presentation/group_detail_payment.dart';
import 'package:deun/pages/groups/presentation/group_invite_page.dart';
import 'package:deun/pages/groups/presentation/group_join_page.dart';
import 'package:deun/pages/groups/presentation/group_list.dart';
import 'package:deun/pages/groups/presentation/group_members_page.dart';
import 'package:deun/pages/settings/contact.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:deun/pages/settings/setting.dart';
import 'package:deun/pages/statistics/category_detail_bottom_sheet.dart';
import 'package:deun/pages/statistics/group_statistics_page.dart';
import 'package:deun/pages/statistics/month_detail_bottom_sheet.dart';
import 'package:deun/pages/statistics/personal_statistics_page.dart';
import 'package:deun/widgets/dev/widget_gallery_page.dart';
import 'package:deun/widgets/modal_bottom_sheet_page.dart';
import 'package:deun/widgets/page_transitions.dart';
import 'package:deun/widgets/restyle/app_bottom_nav.dart';
import 'package:deun/widgets/route_loader.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app's one route table. [rootNavigatorKey] is the navigator the
/// drill-down pages and sheets open on; each call builds its own shell keys, so
/// a test can build several routers.
GoRouter buildAppRouter({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required String initialLocation,
}) {
  final shellGroupKey = GlobalKey<NavigatorState>(debugLabel: 'shellGroup');
  final shellFriendKey = GlobalKey<NavigatorState>(debugLabel: 'shellFriend');
  final shellSettingKey = GlobalKey<NavigatorState>(debugLabel: 'shellSetting');

  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
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
            navigatorKey: shellGroupKey,
            routes: [
              // top route inside branch
              GoRoute(
                path: '/group',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: GroupList()),
                routes: [
                  // Literal segments (`new`, `join`, `expense/new`) come before the
                  // parameter routes they would otherwise match.
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const GroupEdit(),
                    ),
                  ),
                  GoRoute(
                    path: 'join',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final groupId = state.uri.queryParameters['groupId'];
                      final groupName = state.uri.queryParameters['name'];
                      return MaterialPage(
                        key: state.pageKey,
                        child: GroupJoinPage(
                          groupId: groupId ?? '',
                          groupName: groupName,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':groupId',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: GroupRouteLoader(
                        groupId: _groupId(state),
                        prefetched: _groupExtra(state),
                        builder: (context, group) => GroupDetail(group: group),
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: GroupRouteLoader(
                            groupId: _groupId(state),
                            prefetched: _groupExtra(state),
                            builder: (context, group) =>
                                GroupEdit(group: group),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'members',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: GroupRouteLoader(
                            groupId: _groupId(state),
                            prefetched: _groupExtra(state),
                            builder: (context, group) =>
                                GroupMembersPage(group: group),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'share',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => ModalBottomSheetPage(
                          key: state.pageKey,
                          builder: (context) => GroupRouteLoader(
                            groupId: _groupId(state),
                            prefetched: _groupExtra(state),
                            builder: (context, group) =>
                                GroupInvitePage(group: group),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'payment',
                        parentNavigatorKey: rootNavigatorKey,
                        // F155/F58: full-page settle-up view (not a routed bottom sheet) so
                        // it drills in with a back-arrow header instead of a non-draggable
                        // modal sheet. Same shared-axis transition as the edit/statistics
                        // routes.
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: GroupRouteLoader(
                            groupId: _groupId(state),
                            prefetched: _groupExtra(state),
                            builder: (context, group) =>
                                GroupPaymentBottomSheet(group: group),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'statistics',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: GroupRouteLoader(
                            groupId: _groupId(state),
                            prefetched: _groupExtra(state),
                            builder: (context, group) =>
                                GroupStatisticsPage(group: group),
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'month',
                            parentNavigatorKey: rootNavigatorKey,
                            redirect: (context, state) =>
                                _redirectBadWindow(state),
                            pageBuilder: (context, state) {
                              final window = _statisticsWindow(state)!;
                              return ModalBottomSheetPage(
                                key: state.pageKey,
                                builder: (context) => GroupRouteLoader(
                                  groupId: _groupId(state),
                                  prefetched: _groupExtra(state),
                                  builder: (context, group) =>
                                      StatisticsMonthDetailBottomSheet(
                                        group: group,
                                        monthStart: window.start,
                                        monthEnd: window.end,
                                      ),
                                ),
                              );
                            },
                          ),
                          GoRoute(
                            path: 'category',
                            parentNavigatorKey: rootNavigatorKey,
                            redirect: (context, state) =>
                                _redirectBadWindow(state, needsName: true),
                            pageBuilder: (context, state) {
                              final groupId = _groupId(state);
                              final window = _statisticsWindow(state)!;
                              // Needs only the id, so it never waits on a load.
                              return ModalBottomSheetPage(
                                key: state.pageKey,
                                builder: (context) => isUuid(groupId)
                                    ? CategoryDetailBottomSheet(
                                        groupId: groupId,
                                        categoryName:
                                            state.uri.queryParameters['name']!,
                                        monthStart: window.start,
                                        monthEnd: window.end,
                                      )
                                    : const RouteNotFound(),
                              );
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'expense/new',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final groupId = _groupId(state);
                          final extra = _expenseExtra(state);
                          return MaterialPage(
                            key: state.pageKey,
                            child: GroupRouteLoader(
                              groupId: groupId,
                              prefetched: extra?.group,
                              // A scan rides only with the group it was made for.
                              builder: (context, group) => ExpenseDetail(
                                group: group,
                                receiptResult: extra?.group.id == groupId
                                    ? extra?.receiptResult
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'expense/:expenseId',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: ExpenseRouteLoader(
                            groupId: _groupId(state),
                            expenseId: _expenseId(state),
                            prefetched: _expenseExtra(state),
                            builder: (context, group, expense) =>
                                ExpenseDetailRead(
                                  group: group,
                                  expense: expense,
                                ),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'expense/:expenseId/edit',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: ExpenseRouteLoader(
                            groupId: _groupId(state),
                            expenseId: _expenseId(state),
                            prefetched: _expenseExtra(state),
                            builder: (context, group, expense) =>
                                ExpenseDetail(group: group, expense: expense),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'expense/:expenseId/claim',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => MaterialPage(
                          key: state.pageKey,
                          child: ExpenseRouteLoader(
                            groupId: _groupId(state),
                            expenseId: _expenseId(state),
                            prefetched: _expenseExtra(state),
                            builder: (context, group, expense) =>
                                ClaimPage(group: group, expense: expense),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // second branch (Friend)
          StatefulShellBranch(
            navigatorKey: shellFriendKey,
            routes: [
              // top route inside branch
              GoRoute(
                path: '/friend',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: FriendList()),
                routes: [
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const FriendAddPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'qr',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const FriendQrPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'accept',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final email = state.uri.queryParameters['email'];
                      final username = state.uri.queryParameters['u'];
                      final code = state.uri.queryParameters['c'];
                      return MaterialPage(
                        key: state.pageKey,
                        child: FriendAcceptPage(
                          email: email,
                          username: username,
                          usernameCode: code,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          // third branch (Setting)
          StatefulShellBranch(
            navigatorKey: shellSettingKey,
            routes: [
              // top route inside branch
              GoRoute(
                path: '/setting',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: Setting()),
                routes: [
                  // child route
                  GoRoute(
                    path: 'privacy-policy',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const PrivacyPolicy(),
                    ),
                  ),
                  GoRoute(
                    path: 'statistics',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const PersonalStatisticsPage(),
                    ),
                  ),
                  // child route
                  GoRoute(
                    path: 'contact',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: const Contact(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const PrivacyPolicy()),
      ),
      GoRoute(
        path: '/contact',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const Contact()),
      ),
      GoRoute(
        path: '/update-password',
        pageBuilder: (context, state) =>
            MaterialPage(key: state.pageKey, child: const UpdatePassword()),
      ),
      ...devGalleryRoutes(enabled: kDebugMode),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.pageNotFound)),
        body: Center(child: Text(AppLocalizations.of(context)!.pageNotFound)),
      );
    },
  );
}

String _groupId(GoRouterState state) => state.pathParameters['groupId']!;

String _expenseId(GoRouterState state) => state.pathParameters['expenseId']!;

/// The group a group route was pushed with, if any. Read by type, never cast.
Group? _groupExtra(GoRouterState state) => switch (state.extra) {
  final Group group => group,
  _ => null,
};

/// The prefetched object an expense route was pushed with, if any.
ExpenseRouteExtra? _expenseExtra(GoRouterState state) => switch (state.extra) {
  final ExpenseRouteExtra extra => extra,
  _ => null,
};

/// The window a statistics sheet's location carries, or null when a bound is
/// missing or unparseable.
({DateTime start, DateTime end})? _statisticsWindow(GoRouterState state) {
  final query = state.uri.queryParameters;
  final start = DateTime.tryParse(query['from'] ?? '');
  final end = DateTime.tryParse(query['to'] ?? '');
  if (start == null || end == null) return null;
  return (start: start, end: end);
}

/// Sends a statistics sheet whose window — or, for the category sheet, whose
/// category name — is missing or unparseable to its group's statistics page.
String? _redirectBadWindow(GoRouterState state, {bool needsName = false}) {
  final complete =
      _statisticsWindow(state) != null &&
      (!needsName || state.uri.queryParameters['name'] != null);
  return complete ? null : AppPaths.groupStatistics(_groupId(state));
}

// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
class ScaffoldWithNestedNavigation extends ConsumerStatefulWidget {
  const ScaffoldWithNestedNavigation({Key? key, required this.navigationShell})
    : super(key: key ?? const ValueKey('ScaffoldWithNestedNavigation'));
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNestedNavigation> createState() =>
      _ScaffoldWithNestedNavigationState();
}

class _ScaffoldWithNestedNavigationState
    extends ConsumerState<ScaffoldWithNestedNavigation> {
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendshipState = ref.watch(friendshipListProvider);
    final pendingCount = ref.watch(pendingFriendRequestCountProvider);
    final showBadge = pendingCount > 0 && friendshipState.hasValue;

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: TabSwitchTransition(
        index: widget.navigationShell.currentIndex,
        child: widget.navigationShell,
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: widget.navigationShell.currentIndex,
        onSelect: _goBranch,
        items: [
          AppBottomNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: l10n.groups,
          ),
          AppBottomNavItem(
            icon: Icons.group_outlined,
            selectedIcon: Icons.group,
            label: l10n.friends,
            badgeCount: showBadge ? pendingCount : 0,
          ),
          AppBottomNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
