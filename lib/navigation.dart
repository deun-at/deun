import 'dart:async';

import 'package:deun/app_router.dart';
import 'package:deun/constants.dart';
import 'package:deun/deep_links.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/provider.dart';
import 'package:deun/push_notifications.dart';
import 'package:deun/widgets/currency_scope.dart';
import 'package:deun/widgets/initialization_helper.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
    _routerConfig = buildAppRouter(
      rootNavigatorKey: _rootNavigatorKey,
      initialLocation: widget.isPasswordRecovery
          ? '/update-password'
          : '/group',
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
