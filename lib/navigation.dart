import 'dart:async';

import 'package:deun/deep_links.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/auth/update_password.dart';
import 'package:deun/pages/expenses/presentation/claim_page.dart';
import 'package:deun/pages/expenses/presentation/expense_detail.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/expenses/data/receipt_scan_result.dart';
import 'package:deun/pages/friends/presentation/friend_add_page.dart';
import 'package:deun/pages/friends/presentation/friend_list.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/friends/presentation/friend_qr_page.dart';
import 'package:deun/pages/friends/presentation/friend_accept_page.dart';
import 'package:deun/pages/groups/presentation/group_detail_payment.dart';
import 'package:deun/pages/settings/contact.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:deun/provider.dart';
import 'package:deun/push_notifications.dart';
import 'helper/realtime_mixin.dart';
import 'package:deun/widgets/currency_scope.dart';
import 'package:deun/widgets/dev/widget_gallery_page.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart';
import 'pages/groups/presentation/group_detail.dart';
import 'pages/groups/presentation/group_invite_page.dart';
import 'pages/groups/presentation/group_join_page.dart';
import 'pages/groups/presentation/group_detail_edit.dart';
import 'pages/groups/presentation/group_list.dart';
import 'pages/groups/presentation/group_members_page.dart';
import 'pages/statistics/category_detail_bottom_sheet.dart';
import 'pages/statistics/group_statistics_page.dart';
import 'pages/statistics/month_detail_bottom_sheet.dart';
import 'pages/statistics/personal_statistics_page.dart';
import 'package:deun/l10n/app_localizations.dart';

import 'pages/groups/data/group_model.dart';
import 'pages/settings/setting.dart';
import 'widgets/modal_bottom_sheet_page.dart';
import 'widgets/page_transitions.dart';
import 'widgets/restyle/app_bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorGroupKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellGroup',
);
final _shellNavigatorFriendKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellFriend',
);
final _shellNavigatorSettingKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellSetting',
);

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key, required this.isPasswordRecovery});

  final bool isPasswordRecovery;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with WidgetsBindingObserver {
  late RouterConfig<Object> _routerConfig;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer async init to after the first frame renders to avoid skipping frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserLocale();
      _startPushSession();
      _linkSubscription = listenToDeepLinks(_rootNavigatorKey);

      if (!kIsWeb) {
        InitializationHelper().initialize();
      }
    });

    // the one and only GoRouter instance
    _routerConfig = GoRouter(
      initialLocation: widget.isPasswordRecovery
          ? '/update-password'
          : '/group',
      navigatorKey: _rootNavigatorKey,
      routes: [
        // Stateful nested navigation based on:
        // https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            // the UI shell
            return ScaffoldWithNestedNavigation(
              navigationShell: navigationShell,
            );
          },
          branches: [
            // first branch (Group)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorGroupKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/group',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: GroupList()),
                  routes: [
                    // child route
                    GoRoute(
                      path: 'details',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        var extra = state.extra as Map<String, dynamic>;
                        var group = extra['group'] as Group;

                        return MaterialPage(
                          key: state.pageKey,
                          child: GroupDetail(group: group),
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'expense',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            var extra = state.extra as Map<String, dynamic>;
                            var group = extra['group'] as Group;
                            var expense = extra['expense'] as Expense?;
                            var receiptResult =
                                extra['receiptResult'] as ReceiptScanResult?;

                            return MaterialPage(
                              key: state.pageKey,
                              child: ExpenseDetail(
                                group: group,
                                expense: expense,
                                receiptResult: receiptResult,
                              ),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'expense-detail',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            var extra = state.extra as Map<String, dynamic>;
                            var group = extra['group'] as Group;
                            var expense = extra['expense'] as Expense;

                            return MaterialPage(
                              key: state.pageKey,
                              child: ExpenseDetailRead(
                                group: group,
                                expense: expense,
                              ),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'claim',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            var extra = state.extra as Map<String, dynamic>;
                            var group = extra['group'] as Group;
                            var expense = extra['expense'] as Expense;

                            return MaterialPage(
                              key: state.pageKey,
                              child: ClaimPage(group: group, expense: expense),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'statistics',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            var extra = state.extra as Map<String, dynamic>;
                            var group = extra['group'] as Group;

                            return MaterialPage(
                              key: state.pageKey,
                              child: GroupStatisticsPage(group: group),
                            );
                          },
                          routes: [
                            GoRoute(
                              path: 'month',
                              parentNavigatorKey: _rootNavigatorKey,
                              pageBuilder: (context, state) {
                                var extra = state.extra as Map<String, dynamic>;
                                var group = extra['group'] as Group;
                                var monthStart =
                                    extra['monthStart'] as DateTime;
                                var monthEnd = extra['monthEnd'] as DateTime;

                                return ModalBottomSheetPage(
                                  key: state.pageKey,
                                  builder: (context) =>
                                      StatisticsMonthDetailBottomSheet(
                                        group: group,
                                        monthStart: monthStart,
                                        monthEnd: monthEnd,
                                      ),
                                );
                              },
                            ),
                            GoRoute(
                              path: 'category',
                              parentNavigatorKey: _rootNavigatorKey,
                              pageBuilder: (context, state) {
                                var extra = state.extra as Map<String, dynamic>;
                                return ModalBottomSheetPage(
                                  key: state.pageKey,
                                  builder: (context) =>
                                      CategoryDetailBottomSheet(
                                        groupId: extra['groupId'] as String,
                                        categoryName:
                                            extra['categoryName'] as String,
                                        monthStart:
                                            extra['monthStart'] as DateTime,
                                        monthEnd: extra['monthEnd'] as DateTime,
                                      ),
                                );
                              },
                            ),
                          ],
                        ),
                        GoRoute(
                          path: 'payment',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            var extra = state.extra as Map<String, dynamic>;
                            var group = extra['group'] as Group;

                            // F155/F58: full-page settle-up view (not a
                            // routed bottom sheet) so it drills in with a
                            // back-arrow header instead of a non-draggable
                            // modal sheet. Same shared-axis transition as
                            // the edit/statistics routes.
                            return MaterialPage(
                              key: state.pageKey,
                              child: GroupPaymentBottomSheet(group: group),
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        var extra = state.extra as Map<String, dynamic>?;
                        var group = extra?['group'] as Group?;

                        return MaterialPage(
                          key: state.pageKey,
                          child: GroupEdit(group: group),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'share',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        var extra = state.extra as Map<String, dynamic>;
                        var group = extra['group'] as Group;
                        return ModalBottomSheetPage(
                          key: state.pageKey,
                          builder: (context) => GroupInvitePage(group: group),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'members',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) {
                        var extra = state.extra as Map<String, dynamic>;
                        var group = extra['group'] as Group;

                        return MaterialPage(
                          key: state.pageKey,
                          child: GroupMembersPage(group: group),
                        );
                      },
                    ),
                    GoRoute(
                      path: 'join',
                      parentNavigatorKey: _rootNavigatorKey,
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
                  ],
                ),
              ],
            ),
            // second branch (Friend)
            StatefulShellBranch(
              navigatorKey: _shellNavigatorFriendKey,
              routes: [
                // top route inside branch
                GoRoute(
                  path: '/friend',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: FriendList()),
                  routes: [
                    GoRoute(
                      path: 'add',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: const FriendAddPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'qr',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: const FriendQrPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'accept',
                      parentNavigatorKey: _rootNavigatorKey,
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
              navigatorKey: _shellNavigatorSettingKey,
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
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: const PrivacyPolicy(),
                      ),
                    ),
                    GoRoute(
                      path: 'statistics',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => MaterialPage(
                        key: state.pageKey,
                        child: const PersonalStatisticsPage(),
                      ),
                    ),
                    // child route
                    GoRoute(
                      path: 'contact',
                      parentNavigatorKey: _rootNavigatorKey,
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
        // Throwaway dev/QA route for the E0-T4 shared restyle widgets.
        GoRoute(
          path: '/dev/gallery',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WidgetGalleryPage()),
        ),
      ],
      errorBuilder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.pageNotFound),
          ),
          body: Center(child: Text(AppLocalizations.of(context)!.pageNotFound)),
        );
      },
    );
  }

  Future<void> _initUserLocale() async {
    //initialize Prefered Language
    final email = ref.read(currentUserProvider)?.email;
    if (email == null || email.isEmpty) return;

    final user = await supabase
        .from("user")
        .select("locale")
        .eq("email", email)
        .maybeSingle();

    if (!mounted) return;

    if (user?["locale"] != null) {
      ref.read(localeProvider.notifier).setLocale(Locale(user!["locale"]));
    }
  }

  /// Starts the signed-in user's push session. With nobody signed in, nothing
  /// starts.
  void _startPushSession() {
    final userId = ref.read(currentUserProvider)?.id;
    if (!mounted || userId == null) return;
    unawaited(
      ref
          .read(pushSessionProvider.notifier)
          .start(
            userId: userId,
            onOpened: (message) => openPushMessage(
              message,
              _rootNavigatorKey,
              loadGroup: (id) =>
                  ref.read(groupRepositoryProvider).fetchDetail(id),
              loadExpense: (id) =>
                  ref.read(expenseRepositoryProvider).fetchDetail(id),
            ),
          ),
    );
  }

  bool _wasPaused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      // Remove all Supabase channels to prevent channelError loops
      // while the app is backgrounded and the WebSocket is dead.
      supabase.removeAllChannels();
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      // Only re-subscribe if we actually paused (channels were killed).
      // Skip for transient inactive→resumed cycles (keyboard, dialogs).
      ref.read(appResumeCounterProvider.notifier).increment();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return CurrencyScope(
      currency: Currency.eur,
      child: MaterialApp.router(
        routerConfig: _routerConfig,
        title: 'Deun',
        theme: getThemeData(context, kBrandSeed, Brightness.light),
        darkTheme: getThemeData(context, kBrandSeed, Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) {
            return const Locale('en');
          }

          return supportedLocales.contains(locale)
              ? locale
              : const Locale('en');
        },
      ),
    );
  }
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
