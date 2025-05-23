import 'dart:async';

import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/auth/update_password.dart';
import 'package:deun/pages/expenses/expense_model.dart';
import 'package:deun/pages/friends/friend_add.dart';
import 'package:deun/pages/friends/friend_list.dart';
import 'package:deun/pages/groups/group_detail_payment.dart';
import 'package:deun/pages/settings/contact.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/expenses/expense_detail.dart';
import 'pages/groups/group_detail.dart';
import 'pages/groups/group_detail_edit.dart';
import 'pages/groups/group_list.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';

import 'pages/groups/group_model.dart';
import 'pages/settings/setting.dart';
import 'widgets/modal_bottom_sheet_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorGroupKey = GlobalKey<NavigatorState>(debugLabel: 'shellGroup');
final _shellNavigatorFriendKey = GlobalKey<NavigatorState>(debugLabel: 'shellFriend');
final _shellNavigatorSettingKey = GlobalKey<NavigatorState>(debugLabel: 'shellSetting');

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key, required this.isPasswordRecovery});

  final bool isPasswordRecovery;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late RouterConfig<Object> _routerConfig;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initUserLocale();
    _initFirebaseMessaging();
    initDeepLinks();

    if (!kIsWeb) {
      final _initializationHelper = InitializationHelper();
      _initializationHelper.initialize();
    }

    // the one and only GoRouter instance
    _routerConfig = GoRouter(
      initialLocation: widget.isPasswordRecovery ? '/update-password' : '/group',
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
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          var extra = state.extra as Map<String, dynamic>;
                          var group = extra['group'] as Group;

                          return DefaultTransitionPage(child: GroupDetail(group: group));
                        },
                        routes: [
                          GoRoute(
                              path: 'expense',
                              parentNavigatorKey: _rootNavigatorKey,
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
                              }),
                          GoRoute(
                              path: 'payment',
                              parentNavigatorKey: _rootNavigatorKey,
                              pageBuilder: (context, state) {
                                var extra = state.extra as Map<String, dynamic>;
                                var group = extra['group'] as Group;

                                return ModalBottomSheetPage(
                                  key: state.pageKey,
                                  builder: (context) => GroupPaymentBottomSheet(
                                    group: group,
                                  ),
                                );
                              }),
                        ]),
                    GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          var extra = state.extra as Map<String, dynamic>?;
                          var group = extra?['group'] as Group?;

                          return ModalBottomSheetPage(
                            key: state.pageKey,
                            builder: (context) => GroupBottomSheet(
                              group: group,
                            ),
                          );
                        }),
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
                    pageBuilder: (context, state) => const NoTransitionPage(child: FriendList()),
                    routes: [
                      GoRoute(
                          path: 'add',
                          parentNavigatorKey: _rootNavigatorKey,
                          pageBuilder: (context, state) {
                            return ModalBottomSheetPage(
                              key: state.pageKey,
                              builder: (context) => FriendAddBottomSheet(),
                            );
                          }),
                    ]),
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
                    routes: [
                      // child route
                      GoRoute(
                        path: 'privacy-policy',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          return DefaultTransitionPage(child: PrivacyPolicy());
                        },
                      ),
                      // child route
                      GoRoute(
                        path: 'contact',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          return DefaultTransitionPage(child: Contact());
                        },
                      ),
                    ]),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/privacy-policy',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PrivacyPolicy(),
          ),
        ),
        GoRoute(
          path: '/contact',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Contact(),
          ),
        ),
        GoRoute(
          path: '/update-password',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: UpdatePassword(),
          ),
        ),
      ],
      errorBuilder: (context, state) {
        return Scaffold(
            appBar: AppBar(
              title: Text('Page not found'),
            ),
            body: Center(child: Text('Page not found')));
      },
    );
  }

  _initUserLocale() async {
    //initialize Prefered Language
    final user = await supabase.from("user").select("*").eq("email", supabase.auth.currentUser!.email ?? '').single();

    if (user["locale"] != null) {
      ref.read(localeNotifierProvider.notifier).setLocale(Locale(user["locale"]));
    }
  }

  _initFirebaseMessaging() async {
    // You may set the permission requests to "provisional" which allows the user to choose what type
    // of notifications they would like to receive once the user receives a notification.
    final notificationSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // debugPrint('User granted permission: ${notificationSettings.authorizationStatus}');

    if (notificationSettings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    if (kIsWeb) {
    } else {
      if (Platform.isIOS) {
        // For apple platforms, ensure the APNS token is available before making any FCM plugin API calls
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) {
          // APNS token is available, make FCM plugin API requests...
          _handlePush();
        }
      } else {
        _handlePush();
      }
    }
  }

  void _handlePush() async {
    final fcmToken = await FirebaseMessaging.instance
        .getToken(vapidKey: "BL4YZRDAw8gBPt37GNhz6ub5UxTtDUdjERYzFOgOI2ZdCqwwBToztXtL9Wj0QwqDfKe4CoBQjcjSP54OG3fjFvE");

    if (fcmToken != null) {
      try {
        await supabase.from('device_tokens').upsert({
          'user_id': supabase.auth.currentUser!.id, // Replace with your user ID field
          'token': fcmToken,
        });
      } catch (e) {
        debugPrint('error: $e');
      }
    }

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
      supabase.from('device_tokens').upsert({
        'user_id': supabase.auth.currentUser!.id, // Replace with your user ID field
        'token': fcmToken,
      });
      // Note: This callback is fired at each app startup and whenever a new
      // token is generated.
    }).onError((err) {
      // Error getting token.
    });
  }

  void _handleMessage(RemoteMessage message) async {
    switch (message.data['type']) {
      case 'group':
        Group group = await Group.fetchDetail(message.data['expense_id']);
        navigateToGroup(_rootNavigatorKey.currentContext!, group);
        break;
      case 'expense':
        Expense expense = await Expense.fetchDetail(message.data['expense_id']);
        navigateToExpense(_rootNavigatorKey.currentContext!, expense);
        break;
      case 'friendship':
        navigateToFriends(_rootNavigatorKey.currentContext!);
        break;
      default:
        break;
    }
  }

  Future<void> initDeepLinks() async {
    // Handle links
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      GoRouter.of(_rootNavigatorKey.currentContext!).go(uri.fragment);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeNotifierProvider);
    Color colorSelected = ref.watch(themeColorProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: _routerConfig,
      title: 'Deun',
      theme: ThemeData(colorSchemeSeed: colorSelected, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: colorSelected, useMaterial3: true, brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return Locale('en');
        }

        return supportedLocales.contains(locale) ? locale : Locale('en');
      },
    );
  }
}

// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
class ScaffoldWithNestedNavigation extends ConsumerStatefulWidget {
  const ScaffoldWithNestedNavigation({
    Key? key,
    required this.navigationShell,
  }) : super(key: key ?? const ValueKey('ScaffoldWithNestedNavigation'));
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNestedNavigation> createState() => _ScaffoldWithNestedNavigationState();
}

class _ScaffoldWithNestedNavigationState extends ConsumerState<ScaffoldWithNestedNavigation> {
  void _goBranch(int index) {
    ref.read(themeColorProvider.notifier).resetColor();

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
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // if (message.data['type'] == 'expense') {
      //   Expense.fetchDetail(message.data['expense_id']).then((expense) {
      //     // ignore: use_build_context_synchronously
      //     showMaterialBanner(context, '${message.notification!.title}\n${message.notification!.body}',
      //         () => navigateToExpense(context, expense));
      //   });
      // } else if (message.data['type'] == 'friendship') {
      //   showMaterialBanner(
      //       // ignore: use_build_context_synchronously
      //       context,
      //       '${message.notification!.title}\n${message.notification!.body}',
      //       () => navigateToFriends(context));
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: const Icon(Icons.receipt_long),
            icon: const Icon(Icons.receipt_long_outlined),
            label: AppLocalizations.of(context)!.groups,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.group),
            icon: const Icon(Icons.group_outlined),
            label: AppLocalizations.of(context)!.friends,
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

class DefaultTransitionPage extends CustomTransitionPage {
  DefaultTransitionPage({required super.child})
      : super(
          transitionDuration: Durations.medium4,
          reverseTransitionDuration: Durations.medium4,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
              child: child,
            );
          },
        );
}
