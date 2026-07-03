import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_list.dart';
import 'package:deun/pages/groups/presentation/group_list_item.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/restyle/money_text.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
  Color? color,
}) {
  final g = Group();
  g.id = id;
  g.name = name;
  g.colorValue = (color ?? kGroupColorPalette.first).toARGB32();
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

    expect(find.text('Alex'), findsOneWidget); // name line of the greeting header
    expect(find.text('Trip to Rome'), findsOneWidget);
    expect(find.byType(GroupListItem), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // F87: time-aware, multi-line greeting header
  // -------------------------------------------------------------------------

  test('greetingBucketForHour pins each bucket to its hour range', () {
    // morning 05-11, afternoon 12-16, evening 17-21, night 22-04.
    for (var h = 0; h < 24; h++) {
      final GreetingBucket expected;
      if (h >= 5 && h < 12) {
        expected = GreetingBucket.morning;
      } else if (h >= 12 && h < 17) {
        expected = GreetingBucket.afternoon;
      } else if (h >= 17 && h < 22) {
        expected = GreetingBucket.evening;
      } else {
        expected = GreetingBucket.night;
      }
      expect(greetingBucketForHour(h), expected, reason: 'hour $h');
    }
    // Boundary spot-checks.
    expect(greetingBucketForHour(4), GreetingBucket.night);
    expect(greetingBucketForHour(5), GreetingBucket.morning);
    expect(greetingBucketForHour(11), GreetingBucket.morning);
    expect(greetingBucketForHour(12), GreetingBucket.afternoon);
    expect(greetingBucketForHour(17), GreetingBucket.evening);
    expect(greetingBucketForHour(22), GreetingBucket.night);
  });

  testWidgets('greeting header renders a muted greeting line above the name line', (tester) async {
    await _pumpScreen(tester, groups: [_group(id: 'a', name: 'A', totalShareAmount: 10)]);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The greeting label for the current wall-clock hour is one of the four
    // localized time-of-day variants, rendered above the name line.
    final bucket = greetingBucketForHour(DateTime.now().hour);
    final expectedGreeting = {
      GreetingBucket.morning: l10n.homeGreetingMorning,
      GreetingBucket.afternoon: l10n.homeGreetingAfternoon,
      GreetingBucket.evening: l10n.homeGreetingEvening,
      GreetingBucket.night: l10n.homeGreetingNight,
    }[bucket]!;

    final greetingFinder = find.text(expectedGreeting);
    expect(greetingFinder, findsOneWidget);
    // Name line present too -> two lines.
    expect(find.text('Alex'), findsOneWidget);

    // Greeting line is the muted secondary token (not the name's headline).
    final ctx = tester.element(greetingFinder);
    final theme = Theme.of(ctx);
    final greetingStyle = tester.widget<Text>(greetingFinder).style!;
    expect(greetingStyle.color, theme.colorScheme.onSurfaceVariant);

    // The name line sits below the greeting line (multi-line, stacked).
    final greetingY = tester.getTopLeft(greetingFinder).dy;
    final nameY = tester.getTopLeft(find.text('Alex')).dy;
    expect(nameY, greaterThan(greetingY));
  });

  testWidgets('hero shows the aggregated owed amount', (tester) async {
    await _pumpScreen(tester, groups: [
      _group(id: 'a', name: 'A', totalShareAmount: 20),
      _group(id: 'b', name: 'B', totalShareAmount: -5),
    ]);

    // Net owed = 15. The € formatting includes the digits.
    expect(find.textContaining('15'), findsWidgets);
    // Net positive -> the hero lead label is the "owed" ("Overall, you're
    // owed") copy, and NOT the "owe" copy.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeOverallOwed), findsOneWidget);
    expect(find.text(l10n.homeOverallOwe), findsNothing);
  });

  testWidgets('hero owe/owed labels map to the sign of the net balance', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Net negative (owe > owed) -> the "owe" lead label, never the "owed" one.
    await _pumpScreen(tester, groups: [
      _group(id: 'a', name: 'A', totalShareAmount: 10),
      _group(id: 'b', name: 'B', totalShareAmount: -40),
    ]);
    expect(find.text(l10n.homeOverallOwe), findsOneWidget);
    expect(find.text(l10n.homeOverallOwed), findsNothing);

    // Both stat chips carry the full "You're owed" / "You owe" copy from the
    // handoff (findsWidgets: the same phrasing is reused on group-card footers).
    expect(find.text(l10n.homeStatOwed), findsWidgets);
    expect(find.text(l10n.homeStatOwe), findsWidgets);
  });

  testWidgets('hero shows the settled lead when the net balance is zero', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Net zero (owed == owe) -> the neutral settled lead, neither directional
    // label. Two offsetting groups so the card list (and thus the hero) renders.
    await _pumpScreen(tester, groups: [
      _group(id: 'c', name: 'C', totalShareAmount: 30),
      _group(id: 'd', name: 'D', totalShareAmount: -30),
    ]);
    expect(find.text(l10n.homeOverallSettled), findsOneWidget);
    expect(find.text(l10n.homeOverallOwe), findsNothing);
    expect(find.text(l10n.homeOverallOwed), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('overall-balance hero amount uses the big displayMedium tier ($brightness)', (tester) async {
      // Regression guard for F03: the hero amount must use the large w700
      // Bricolage hero tier (displayMedium, 45px / -0.02em) — not the smaller,
      // lighter displaySmall (40px / w600) that read far weaker than the v3 hero.
      await _pumpScreen(
        tester,
        brightness: brightness,
        groups: [_group(id: 'a', name: 'A', totalShareAmount: 20)],
      );

      // The hero amount is the first MoneyText on screen (rendered above the
      // group cards).
      final heroMoney = tester.widget<MoneyText>(find.byType(MoneyText).first);

      // Resolve the expected hero size straight from the active theme so the
      // assertion tracks the token, not a hard-coded number.
      final ctx = tester.element(find.byType(MoneyText).first);
      final expected = Theme.of(ctx).textTheme.displayMedium!;

      expect(heroMoney.style?.fontSize, expected.fontSize);
      expect(heroMoney.style?.fontWeight, FontWeight.w700);
      expect(heroMoney.style?.fontSize, greaterThan(Theme.of(ctx).textTheme.displaySmall!.fontSize!));
    });
  }

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
    // The list is a lazy ListView; give the test surface enough height that all
    // three cards build (the redesign hero is tall, so the default 600px
    // viewport would scroll the last card out of the build window).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(tester, groups: [
      _group(id: 'settled', name: 'Zeta settled', totalShareAmount: 0),
      _group(id: 'fav', name: 'Alpha fav', totalShareAmount: 12, favorite: true),
      _group(id: 'active', name: 'Beta active', totalShareAmount: -4),
    ]);

    final items = tester.widgetList<GroupListItem>(find.byType(GroupListItem)).toList();
    expect(items.map((i) => i.group.id).toList(), ['fav', 'active', 'settled']);
  });

  testWidgets('settled group card shows the gray label and no amount', (tester) async {
    await _pumpScreen(tester, groups: [_group(id: 's', name: 'Settled Group', totalShareAmount: 0)]);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // The gray "settled" lead label is shown...
    expect(find.text(l10n.balanceSettled), findsOneWidget);
    // ...but no balance amount (no €0.00) is rendered inside the card.
    final card = find.byType(GroupListItem);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(MoneyText)),
      findsNothing,
      reason: 'a settled group shows "gray, no amount" per the spec',
    );
  });

  testWidgets('unsettled group card still shows the balance amount', (tester) async {
    await _pumpScreen(tester, groups: [_group(id: 'a', name: 'Active Group', totalShareAmount: 25)]);

    final card = find.byType(GroupListItem);
    expect(
      find.descendant(of: card, matching: find.byType(MoneyText)),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // F04: per-group tinted leading icon (not one flat uniform square)
  // -------------------------------------------------------------------------

  // Resolves the leading-icon container background for the card whose icon is
  // the receipt glyph, scoped to a single GroupListItem.
  Color leadingTint(WidgetTester tester, Finder card) {
    final container = tester.widget<Container>(
      find
          .descendant(of: card, matching: find.byType(Container))
          .first,
    );
    return (container.decoration as BoxDecoration).color!;
  }

  for (final brightness in Brightness.values) {
    testWidgets('group cards show distinct per-group tints matching the palette ($brightness)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const indigo = Color(0xFF5750E6);
      const orange = Color(0xFFE0853D);

      await _pumpScreen(
        tester,
        brightness: brightness,
        groups: [
          _group(id: 'i', name: 'Indigo', totalShareAmount: 10, color: indigo),
          _group(id: 'o', name: 'Orange', totalShareAmount: 12, color: orange),
        ],
      );

      final indigoCard = find.ancestor(
        of: find.text('Indigo'),
        matching: find.byType(GroupListItem),
      );
      final orangeCard = find.ancestor(
        of: find.text('Orange'),
        matching: find.byType(GroupListItem),
      );

      final indigoTint = leadingTint(tester, indigoCard);
      final orangeTint = leadingTint(tester, orangeCard);

      // Two different group colors must NOT collapse to the same flat square.
      expect(indigoTint, isNot(orangeTint),
          reason: 'per-group tints must differ (F04)');

      // Tints resolve through the centralized mapping for this brightness.
      expect(indigoTint, groupTint(indigo.toARGB32(), brightness));
      expect(orangeTint, groupTint(orange.toARGB32(), brightness));

      if (brightness == Brightness.light) {
        // Exact spec light tint tokens.
        expect(indigoTint, const Color(0xFFECEBFC));
        expect(orangeTint, const Color(0xFFFBEEDD));
      } else {
        // Dark tints are derived dark surfaces, not the near-white light tint.
        expect(indigoTint.computeLuminance(), lessThan(0.35));
        expect(orangeTint.computeLuminance(), lessThan(0.35));
      }
    });
  }

  testWidgets('renders without throwing in dark mode', (tester) async {
    await _pumpScreen(
      tester,
      groups: [_group(id: 'a', name: 'Dark Group', totalShareAmount: 10)],
      brightness: Brightness.dark,
    );
    expect(find.text('Dark Group'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // F05: balance footer hierarchy — muted caption lead label + heavier,
  // semantic-colored card-title amount (not one small flat block).
  // -------------------------------------------------------------------------

  // Resolves the rendered Text style for the balance lead label text *inside the
  // group card* (the same label string also appears in the overall hero, so we
  // scope the lookup to the GroupListItem subtree).
  TextStyle leadLabelStyle(WidgetTester tester, String label) =>
      tester
          .widget<Text>(find.descendant(
            of: find.byType(GroupListItem),
            matching: find.text(label),
          ))
          .style!;

  for (final brightness in Brightness.values) {
    testWidgets('owed card footer: muted caption lead label + green card-title amount ($brightness)',
        (tester) async {
      await _pumpScreen(
        tester,
        brightness: brightness,
        groups: [_group(id: 'a', name: 'Owed Group', totalShareAmount: 25)],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final ctx = tester.element(find.byType(GroupListItem));
      final theme = Theme.of(ctx);
      final semantic = theme.extension<SemanticColors>()!;

      // Lead label: localized "You're owed", caption tier (labelMedium) in the
      // muted onSurfaceVariant token — NOT the tiny labelSmall.
      final labelStyle = leadLabelStyle(tester, l10n.balanceOwed);
      expect(labelStyle.fontSize, theme.textTheme.labelMedium!.fontSize);
      expect(labelStyle.color, theme.colorScheme.onSurfaceVariant);

      // Amount: heavier card-title weight (w700), card-title size (titleMedium),
      // colored by the positive/success semantic token.
      final cardMoney = find.descendant(
        of: find.byType(GroupListItem),
        matching: find.byType(MoneyText),
      );
      final money = tester.widget<MoneyText>(cardMoney);
      expect(money.semantic, MoneySemantic.positive);
      expect(money.style?.fontWeight, FontWeight.w700);
      expect(money.style?.fontSize, theme.textTheme.titleMedium!.fontSize);
      // The amount is heavier/larger than the caption lead label (clear hierarchy).
      expect(money.style!.fontSize!, greaterThan(labelStyle.fontSize!));

      // The rendered amount glyph carries the success color.
      final amountText = tester.widget<Text>(
        find.descendant(of: cardMoney, matching: find.byType(Text)),
      );
      expect(amountText.style?.color, semantic.success);
    });
  }

  testWidgets('owe card footer: amount uses the danger (red) semantic token', (tester) async {
    await _pumpScreen(
      tester,
      groups: [_group(id: 'a', name: 'Owe Group', totalShareAmount: -18)],
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.descendant(of: find.byType(GroupListItem), matching: find.text(l10n.balanceOwe)),
      findsOneWidget,
    );

    final cardMoney = find.descendant(
      of: find.byType(GroupListItem),
      matching: find.byType(MoneyText),
    );
    final money = tester.widget<MoneyText>(cardMoney);
    expect(money.semantic, MoneySemantic.negative);
    expect(money.style?.fontWeight, FontWeight.w700);

    final ctx = tester.element(find.byType(GroupListItem));
    final semantic = Theme.of(ctx).extension<SemanticColors>()!;
    final amountText = tester.widget<Text>(
      find.descendant(of: cardMoney, matching: find.byType(Text)),
    );
    expect(amountText.style?.color, semantic.danger);
  });

  testWidgets('settled card footer: muted gray caption label, no colored amount', (tester) async {
    await _pumpScreen(
      tester,
      groups: [_group(id: 's', name: 'Settled', totalShareAmount: 0)],
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final ctx = tester.element(find.byType(GroupListItem));
    final theme = Theme.of(ctx);

    // Lead label present and in the neutral muted-gray caption token...
    final labelStyle = leadLabelStyle(tester, l10n.balanceSettled);
    expect(labelStyle.fontSize, theme.textTheme.labelMedium!.fontSize);
    expect(labelStyle.color, theme.colorScheme.onSurfaceVariant);
    // ...with no amount rendered (settled = gray, no amount).
    expect(
      find.descendant(of: find.byType(GroupListItem), matching: find.byType(MoneyText)),
      findsNothing,
    );
  });

  // -------------------------------------------------------------------------
  // V3-T5: Staggered list entrance
  // -------------------------------------------------------------------------

  testWidgets('group cards are fully visible after pumpAndSettle (stagger completes)', (tester) async {
    await _pumpScreen(tester, groups: [
      _group(id: 'a', name: 'Alpha Group', totalShareAmount: 10),
      _group(id: 'b', name: 'Beta Group', totalShareAmount: -5),
    ]);

    // All cards visible — entrance animation must have completed.
    expect(find.byType(GroupListItem), findsNWidgets(2));
    // The AnimationLimiter must be in the tree (wrapping the data list).
    expect(find.byType(AnimationLimiter), findsOneWidget);
  });

  testWidgets(
      'group cards are visible immediately when disableAnimations is true (reduced motion)', (tester) async {
    final groups = [
      _group(id: 'a', name: 'Alpha Group', totalShareAmount: 10),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupListProvider.overrideWith(() => _FakeGroupListNotifier(groups, [])),
          userDetailProvider.overrideWith(() => _FakeUserNotifier()),
        ],
        child: MaterialApp(
          // Use builder to inject MediaQuery override *inside* MaterialApp so it
          // takes effect after MaterialApp's own MediaQuery is established.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
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
              data: getThemeData(context, kBrandSeed, Brightness.light)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: const GroupList(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(GroupListItem), findsOneWidget);
    // In reduced-motion mode there is no AnimationLimiter wrapper.
    expect(find.byType(AnimationLimiter), findsNothing);
  });

  testWidgets('favorite toggle does not throw and keeps cards visible (no-replay guard)', (tester) async {
    final toggled = <String>[];
    final groups = [_group(id: 'a', name: 'Alpha Group', totalShareAmount: 10)];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupListProvider.overrideWith(() => _FakeGroupListNotifier(groups, toggled)),
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
              data: getThemeData(context, kBrandSeed, Brightness.light)
                  .copyWith(splashFactory: NoSplash.splashFactory),
              child: const GroupList(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AnimationLimiter is in the tree for the data list.
    expect(find.byType(AnimationLimiter), findsOneWidget);

    // Trigger a favorite toggle (state change / rebuild).
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    // After rebuild: AnimationLimiter still present (not unmounted/remounted),
    // card is still visible — no crash, no hidden items.
    expect(find.byType(AnimationLimiter), findsOneWidget);
    expect(find.byType(GroupListItem), findsOneWidget);
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
