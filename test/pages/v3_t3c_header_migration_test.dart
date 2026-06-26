// Smoke tests for V3-T3c header migration (batch B).
// Each test pumps the migrated screen and asserts:
//   1. A DeunHeader is present with the expected title text.
//   2. No AppBar is present (removed in the migration).
//   3. A key body element still renders (body was not dropped).
//
// These tests are written BEFORE production code is changed (TDD RED phase).
// They fail until each screen is migrated off AppBar onto DeunHeader.

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/auth/update_password.dart';
import 'package:deun/pages/friends/presentation/friend_accept_page.dart';
import 'package:deun/pages/friends/presentation/friend_add_page.dart';
import 'package:deun/pages/friends/presentation/friend_qr_page.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/settings/privacy_policy.dart';
import 'package:deun/pages/statistics/group_statistics_page.dart';
import 'package:deun/pages/statistics/provider/statistics_notifiers.dart';
import 'package:deun/pages/statistics/statistics_models.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

GroupMember _member(String email, String name) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.isGuest = false;
  m.isFavorite = false;
  return m;
}

Group _group() {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip to Rome';
  g.colorValue = kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = [
    _member('a@test.com', 'Alice'),
    _member('b@test.com', 'Bob'),
  ];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = [];
  return g;
}

/// Pumps [child] inside a ProviderScope + MaterialApp + localizations + theme.
Future<void> _pumpInScope(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  List<dynamic> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Stats overrides (needed by GroupStatisticsPage)
const _summary = SpendingSummary(
  total: 500,
  expenseCount: 3,
  avgPerMonth: 100,
  biggestExpense: 200,
  prevPeriodTotal: 400,
  deltaPct: 25,
);

final _statsOverrides = [
  groupSpendingSummaryProvider
      .overrideWith((ref, StatsRangeArgs args) async => _summary),
  groupTrendProvider
      .overrideWith((ref, StatsRangeArgs args) async => const <MonthBucket>[]),
  groupMemberBreakdownProvider.overrideWith(
      (ref, StatsRangeArgs args) async => const <MemberSpendingBreakdown>[]),
  groupCategoryBreakdownProvider.overrideWith(
      (ref, StatsRangeArgs args) async => const <CategoryMonthTotal>[]),
];

// ---------------------------------------------------------------------------
// WebView stub (needed by PrivacyPolicy, which constructs a WebViewController
// in build(). Without a platform implementation the assert fires.)
// ---------------------------------------------------------------------------

class _MockPlatformWebViewController extends PlatformWebViewController {
  _MockPlatformWebViewController(super.params)
      : super.implementation();

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _MockPlatformWebViewWidget extends PlatformWebViewWidget {
  _MockPlatformWebViewWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _MockWebViewPlatform extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _MockPlatformWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _MockPlatformWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      throw UnimplementedError();

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Supabase mock (needed by friend screens)
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Install WebView stub so PrivacyPolicy can build without a platform.
    WebViewPlatform.instance = _MockWebViewPlatform();

    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      },
    );
    // Supabase is already initialized by other tests; guard against re-init.
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  tearDownAll(() async {
    try {
      await Supabase.instance.dispose();
    } catch (_) {}
  });

  // -------------------------------------------------------------------------
  // 1. FriendAddPage — Icons.arrow_back, no actions
  // -------------------------------------------------------------------------
  group('FriendAddPage (friend_add_page.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and addFriends title',
        (tester) async {
      await _pumpInScope(tester, const FriendAddPage());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.addFriends), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, const FriendAddPage());
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('body still renders the search field', (tester) async {
      await _pumpInScope(tester, const FriendAddPage());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.addFriendshipSearchHint), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. FriendQrPage — Icons.arrow_back, drop custom font styling
  // -------------------------------------------------------------------------
  group('FriendQrPage (friend_qr_page.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and friendQrTitle',
        (tester) async {
      await _pumpInScope(tester, const FriendQrPage());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.friendQrTitle), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, const FriendQrPage());
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('body still renders the segmented control', (tester) async {
      await _pumpInScope(tester, const FriendQrPage());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.friendQrTabMyCode), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. FriendAcceptPage — Icons.arrow_back, requestFriendship title
  // -------------------------------------------------------------------------
  group('FriendAcceptPage (friend_accept_page.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and requestFriendship title',
        (tester) async {
      await _pumpInScope(
        tester,
        const FriendAcceptPage(email: 'friend@example.com'),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.requestFriendship), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(
        tester,
        const FriendAcceptPage(email: 'friend@example.com'),
      );
      expect(find.byType(AppBar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 4. UpdatePassword — showLeading: false (deep-link recovery screen)
  //
  // Note: the title key (updatePasswordTitle) appears both in the DeunHeader
  // AND in the body's large heading text — so we use findsWidgets/findsAtLeastNWidgets.
  // -------------------------------------------------------------------------
  group('UpdatePassword (update_password.dart) header migration', () {
    testWidgets('has DeunHeader with updatePasswordTitle and no back button',
        (tester) async {
      await _pumpInScope(tester, const UpdatePassword());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      // Title text appears in both DeunHeader and the body heading.
      expect(find.text(l10n.updatePasswordTitle), findsAtLeastNWidgets(1));
      // showLeading: false → no arrow_back icon
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, const UpdatePassword());
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('body still renders the password instructions text', (tester) async {
      await _pumpInScope(tester, const UpdatePassword());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // updatePasswordInstructions is unique in the tree (not repeated in header).
      expect(find.text(l10n.updatePasswordInstructions), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 5. GroupStatisticsPage — statisticsTitle, arrow_back, wrapped in ThemeBuilder
  // -------------------------------------------------------------------------
  group('GroupStatisticsPage (group_statistics_page.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and group stats title',
        (tester) async {
      await _pumpInScope(
        tester,
        GroupStatisticsPage(group: _group()),
        overrides: _statsOverrides,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.statisticsGroupTitle('Trip to Rome')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(
        tester,
        GroupStatisticsPage(group: _group()),
        overrides: _statsOverrides,
      );
      expect(find.byType(AppBar), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 6. PrivacyPolicy — settingsPrivacyPolicy title, arrow_back
  //    Requires WebView stub (set in setUpAll).
  // -------------------------------------------------------------------------
  group('PrivacyPolicy (privacy_policy.dart) header migration', () {
    testWidgets('has DeunHeader with arrow_back and settingsPrivacyPolicy title',
        (tester) async {
      await _pumpInScope(tester, const PrivacyPolicy());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(DeunHeader), findsOneWidget);
      expect(find.text(l10n.settingsPrivacyPolicy), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('no AppBar present after migration', (tester) async {
      await _pumpInScope(tester, const PrivacyPolicy());
      expect(find.byType(AppBar), findsNothing);
    });
  });
}
