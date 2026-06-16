import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_list.dart';
import 'package:deun/pages/groups/presentation/group_list_item.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _myEmail = 'me@test.com';

GroupMember _member(String email, {bool isFavorite = false}) {
  final m = GroupMember();
  m.groupId = 'g';
  m.email = email;
  m.displayName = email.split('@').first;
  m.isGuest = false;
  m.isFavorite = isFavorite;
  return m;
}

Group _group({
  required String id,
  required String name,
  double totalShareAmount = 0,
  bool favorite = false,
  List<GroupMember>? members,
}) {
  final g = Group();
  g.id = id;
  g.name = name;
  g.colorValue = kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.groupMembers = members ??
      [
        _member(_myEmail, isFavorite: favorite),
        _member('sam@test.com'),
      ];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = totalShareAmount;
  g.expenses = null;
  return g;
}

/// Fake notifier that returns a fixed group list and records favorite toggles
/// without touching Supabase.
class _FakeGroupListNotifier extends GroupListNotifier {
  _FakeGroupListNotifier(this._groups, this.toggled);

  final List<Group> _groups;
  final List<String> toggled;

  @override
  Future<List<Group>> build() async => _groups;

  @override
  Future<void> reload() async {}

  @override
  Future<void> toggleFavorite(String groupId) async {
    toggled.add(groupId);
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<Group> groups,
  List<String>? toggled,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupListProvider.overrideWith(() => _FakeGroupListNotifier(groups, toggled ?? [])),
        userDetailProvider.overrideWith(() => _FakeUserNotifier()),
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
            data: getThemeData(context, kBrandSeed, brightness)
                .copyWith(splashFactory: NoSplash.splashFactory),
            child: const GroupList(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUserNotifier extends UserDetailNotifier {
  @override
  Future<SupaUser> build() async => const SupaUser(email: _myEmail, displayName: 'Alex');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Stub the shared_preferences platform channel (used by Supabase's auth
    // storage) so init doesn't throw a MissingPluginException. Done via the
    // channel directly to avoid a direct dev-dependency on shared_preferences.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      },
    );

    // Initialize Supabase so Group.isFavorite's `supabase.auth.currentUser`
    // access resolves (to null session) instead of throwing. No network is
    // used by these tests.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets('renders greeting, group name and a card', (tester) async {
    await _pumpScreen(tester, groups: [_group(id: 'a', name: 'Trip to Rome', totalShareAmount: 25)]);

    expect(find.textContaining('Alex'), findsOneWidget); // greeting "Hi, Alex"
    expect(find.text('Trip to Rome'), findsOneWidget);
    expect(find.byType(GroupListItem), findsOneWidget);
  });

  testWidgets('hero shows the aggregated owed amount', (tester) async {
    await _pumpScreen(tester, groups: [
      _group(id: 'a', name: 'A', totalShareAmount: 20),
      _group(id: 'b', name: 'B', totalShareAmount: -5),
    ]);

    // Net owed = 15. The € formatting includes the digits.
    expect(find.textContaining('15'), findsWidgets);
    // The "you're owed" hero lead label appears (also used as a card label, so
    // there may be more than one on screen).
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeOverallOwed), findsWidgets);
  });

  testWidgets('tapping the star toggles favorite and does not navigate', (tester) async {
    final toggled = <String>[];
    final navObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupListProvider.overrideWith(
            () => _FakeGroupListNotifier([_group(id: 'a', name: 'A', totalShareAmount: 10)], toggled),
          ),
          userDetailProvider.overrideWith(() => _FakeUserNotifier()),
        ],
        child: MaterialApp(
          navigatorObservers: [navObserver],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Theme(
              // NoSplash avoids the ink fragment shader, which the test engine
              // in this toolchain can't decode (test-only theme tweak).
              data: getThemeData(context, kBrandSeed, Brightness.light)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: const GroupList(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pushesBeforeTap = navObserver.pushCount;
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    expect(toggled, ['a']);
    // No navigation happened as a result of the star tap.
    expect(navObserver.pushCount, pushesBeforeTap);
  });

  testWidgets('cards appear in favorite-sort order', (tester) async {
    await _pumpScreen(tester, groups: [
      _group(id: 'settled', name: 'Zeta settled', totalShareAmount: 0),
      _group(id: 'fav', name: 'Alpha fav', totalShareAmount: 12, favorite: true),
      _group(id: 'active', name: 'Beta active', totalShareAmount: -4),
    ]);

    final items = tester.widgetList<GroupListItem>(find.byType(GroupListItem)).toList();
    expect(items.map((i) => i.group.id).toList(), ['fav', 'active', 'settled']);
  });

  testWidgets('renders without throwing in dark mode', (tester) async {
    await _pumpScreen(
      tester,
      groups: [_group(id: 'a', name: 'Dark Group', totalShareAmount: 10)],
      brightness: Brightness.dark,
    );
    expect(find.text('Dark Group'), findsOneWidget);
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
