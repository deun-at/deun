import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/presentation/group_detail_edit.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/soft_card.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake friends notifier that returns a fixed accepted-friends list without the
/// real notifier's Supabase channel subscription (F71 inline roster tests).
class _FakeFriendshipListNotifier extends FriendshipListNotifier {
  _FakeFriendshipListNotifier(this._friends);
  final List<Friendship> _friends;

  @override
  Future<FriendshipListState> build() async =>
      FriendshipListState(acceptedFriends: _friends);
}

Friendship _friend(String email, String display, String username) {
  final f = Friendship();
  f.user = SupaUser(
    email: email,
    displayName: display,
    username: username,
    usernameCode: '0001',
  );
  f.status = 'accepted';
  f.isIncomingRequest = false;
  return f;
}

Group _group({int? colorValue, bool simplifiedExpenses = true}) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip to Rome';
  g.colorValue = colorValue ?? kGroupColorPalette.first.toARGB32();
  g.simplifiedExpenses = simplifiedExpenses;
  g.createdAt = '';
  g.userId = null;
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = 'me@test.com';
  m.displayName = 'Me';
  m.isGuest = false;
  m.isFavorite = false;
  g.groupMembers = [m];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = null;
  return g;
}

Future<void> _pump(
  WidgetTester tester, {
  Group? group,
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
            data: getThemeData(
              context,
              kBrandSeed,
              brightness,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: GroupEdit(
              // Keyed by group id so that a test which pumps create then edit
              // sequentially (in the SAME tester) gets a fresh GroupEdit State
              // each time, mirroring real navigation (a new /group/edit route
              // per push) instead of Flutter's default in-place widget update.
              key: ValueKey(group?.id ?? 'create'),
              group: group,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the edit form inside a GoRouter carrying the `/group/members` probe
/// route, so the read-only members row's navigation can be observed landing
/// on the member surface.
Future<void> _pumpEditWithRouter(
  WidgetTester tester, {
  required Group group,
}) async {
  final router = GoRouter(
    initialLocation: '/group/edit',
    routes: [
      GoRoute(
        path: '/group/edit',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupEdit(group: group),
        ),
      ),
      GoRoute(
        path: '/group/members',
        builder: (context, state) =>
            const Scaffold(body: Text('MEMBER SURFACE')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A group save the test holds open, so the in-flight CTA state is observable —
/// the same gated-[Completer] seam `expense_save_status_test.dart` uses.
class _GatedGroupSave {
  _GatedGroupSave({this.throwing});

  final gate = Completer<void>();
  final Object? throwing;
  int calls = 0;

  Future<Group> call(String? groupId, Map<String, dynamic> formValue) async {
    calls++;
    await gate.future;
    final failure = throwing;
    if (failure != null) throw failure;
    return _group();
  }
}

/// Pumps the edit form inside a router carrying the two destinations `_save`
/// navigates to, so a confirmation held on the CTA can be told apart from one
/// that lands after the route has already changed.
Future<void> _pumpSave(
  WidgetTester tester, {
  Group? group,
  required _GatedGroupSave save,
  bool reduceMotion = false,
}) async {
  final router = GoRouter(
    initialLocation: '/group/edit',
    routes: [
      GoRoute(
        path: '/group',
        builder: (context, state) => const Scaffold(body: Text('GROUP LIST')),
      ),
      GoRoute(
        path: '/group/edit',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupEdit(
            group: group,
            saveOverride: save.call,
            loadGroupExpenseCurrencies: (_) async => const [],
          ),
        ),
      ),
      GoRoute(
        path: '/group/details',
        builder: (context, state) => const Scaffold(body: Text('GROUP DETAIL')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: reduceMotion
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The sticky-footer CTA — the last [PrimaryButton] in the tree (the only other
/// one lives inside the delete dialog).
Finder get _stickyCta => find.byType(PrimaryButton).last;

PrimaryButton _footerButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_stickyCta);

/// Finds the selectable color swatches: AnimatedContainers whose decoration is a
/// circle filled with a palette color.
Finder _swatchFinder() {
  final palette = kGroupColorPalette.map((c) => c.toARGB32()).toSet();
  return find.byWidgetPredicate((w) {
    if (w is! AnimatedContainer) return false;
    final deco = w.decoration;
    if (deco is! BoxDecoration) return false;
    if (deco.shape != BoxShape.circle) return false;
    final color = deco.color;
    return color != null && palette.contains(color.toARGB32());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  testWidgets(
    'renders name field, six swatches, mode selector and Create button (new group)',
    (tester) async {
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Name field hint.
      expect(find.text(l10n.groupNameHint), findsOneWidget);
      // Six color swatches.
      expect(_swatchFinder(), findsNWidgets(kGroupColorPalette.length));
      // Tracking-mode options. The taller centered-icon header pushes this section
      // below the 800x600 test viewport, so scroll it into view before asserting.
      await tester.scrollUntilVisible(
        find.text(l10n.groupTrackingModeSimplifiedTitle),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.groupTrackingModeSimplifiedTitle), findsOneWidget);
      expect(find.text(l10n.groupTrackingModeDetailedTitle), findsOneWidget);
      // Sticky Create button (new group, not Save).
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text(l10n.createGroup), findsOneWidget);
    },
  );

  testWidgets('shows Save button and the group name when editing', (
    tester,
  ) async {
    await _pump(tester, group: _group());

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.save), findsOneWidget);
    expect(find.text('Trip to Rome'), findsOneWidget);
  });

  testWidgets('tapping a swatch updates the selected colorValue', (
    tester,
  ) async {
    await _pump(tester);

    // Initially the first swatch is selected (shows a check).
    BoxDecoration decoOf(int index) {
      final w = tester
          .widgetList<AnimatedContainer>(_swatchFinder())
          .elementAt(index);
      return w.decoration as BoxDecoration;
    }

    // The second swatch starts unselected (no border).
    expect(decoOf(1).border, isNull);

    await tester.tap(_swatchFinder().at(1));
    await tester.pumpAndSettle();

    // After tapping, the second swatch is selected (has a ring border) and the
    // first is no longer.
    expect(decoOf(1).border, isNotNull);
    expect(decoOf(0).border, isNull);
  });

  testWidgets('toggling the mode updates the simplified selection', (
    tester,
  ) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Scroll the tracking-mode section into the 800x600 test viewport (the
    // taller centered-icon header pushes it below the fold).
    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // Default (new group) is Simplified (simplified_expenses == true): exactly
    // one row shows the checked radio.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

    // Tap Detailed. NoSplash (inherited via ThemeBuilder) avoids the ink
    // fragment shader the test engine can't decode.
    await tester.tap(find.text(l10n.groupTrackingModeDetailedTitle));
    await tester.pumpAndSettle();

    // Still exactly one checked radio, but the selection moved to Detailed.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets(
    'mode options render side by side (two Expanded cards in a Row)',
    (tester) async {
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.scrollUntilVisible(
        find.text(l10n.groupTrackingModeSimplifiedTitle),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      // Both option titles share a common IntrinsicHeight ancestor (the
      // side-by-side row), each wrapped in an Expanded so they split the width.
      final simplified = find.text(l10n.groupTrackingModeSimplifiedTitle);
      final detailed = find.text(l10n.groupTrackingModeDetailedTitle);
      final sideBySide = find.ancestor(
        of: simplified,
        matching: find.byType(IntrinsicHeight),
      );
      expect(sideBySide, findsOneWidget);
      expect(
        find.descendant(of: sideBySide, matching: detailed),
        findsOneWidget,
        reason:
            'Simplified and Detailed must sit in the same row (side by side)',
      );
      // Each option card is inside an Expanded.
      expect(
        find.ancestor(of: simplified, matching: find.byType(Expanded)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: detailed, matching: find.byType(Expanded)),
        findsWidgets,
      );
    },
  );

  testWidgets('new group defaults to Simplified selected', (tester) async {
    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeSimplifiedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // The checked radio must belong to the Simplified option's card.
    final simplifiedCard = find.ancestor(
      of: find.text(l10n.groupTrackingModeSimplifiedTitle),
      matching: find.byType(SoftCard),
    );
    expect(
      find.descendant(
        of: simplifiedCard.first,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
      reason: 'a NEW group must default to Simplified',
    );
  });

  testWidgets('editing a Detailed group keeps Detailed selected (regression)', (
    tester,
  ) async {
    await _pump(tester, group: _group(simplifiedExpenses: false));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.scrollUntilVisible(
      find.text(l10n.groupTrackingModeDetailedTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    // The persisted mode (Detailed) must survive the edit-form init and NOT be
    // overwritten by the create-time Simplified default.
    final detailedCard = find.ancestor(
      of: find.text(l10n.groupTrackingModeDetailedTitle),
      matching: find.byType(SoftCard),
    );
    expect(
      find.descendant(
        of: detailedCard.first,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
      reason: 'editing a Detailed group must keep Detailed selected',
    );
  });

  testWidgets(
    'name field sits on white; icon + colour pickers are NOT boxed in a card (F133)',
    (tester) async {
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The group-name field carries its own white SoftCard surface.
      final nameField = find.widgetWithText(TextFormField, l10n.groupNameHint);
      expect(nameField, findsOneWidget);
      expect(
        find.ancestor(of: nameField, matching: find.byType(SoftCard)),
        findsOneWidget,
        reason: 'the name field should sit on its own white SoftCard surface',
      );

      // The colour swatches are UNBOXED: no SoftCard wraps them.
      expect(
        find.ancestor(
          of: _swatchFinder().first,
          matching: find.byType(SoftCard),
        ),
        findsNothing,
        reason: 'colour swatches must not sit inside a white card',
      );

      // The retinted group-icon preview is UNBOXED too. F134: it is the group
      // glyph (groups_rounded), not the expense glyph (receipt_long).
      expect(find.byIcon(Icons.receipt_long), findsNothing);
      final iconPreview = find.byIcon(Icons.groups_rounded);
      expect(iconPreview, findsOneWidget);
      expect(
        find.ancestor(of: iconPreview, matching: find.byType(SoftCard)),
        findsNothing,
        reason: 'the group-icon preview must not sit inside a white card',
      );
    },
  );

  testWidgets('renders in dark mode without throwing', (tester) async {
    await _pump(tester, group: _group(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a currency picker; new group defaults to EUR', (
    tester,
  ) async {
    // Tall viewport so the whole form is on screen at once (the form is
    // built eagerly now, so this only avoids scrolling in the assertions).
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The picker and its section label are on screen.
    expect(find.text(l10n.groupCurrencyLabel), findsOneWidget);
    expect(find.byType(GroupCurrencyField), findsOneWidget);
    // A new group defaults to EUR (curated codes: EUR, USD, GBP, CHF...).
    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets(
    'editing a USD group preselects USD and states the relabel note',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final usd = _group()..currencyCode = 'USD';
      await _pump(tester, group: usd);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text('USD'), findsOneWidget);
      // Changing currency relabels amounts without converting — the UI says so.
      expect(find.text(l10n.groupCurrencyRelabelNote), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // group-form-field-structure: the form's fields live in a Column under one
  // outer scroller, so scrolling can never unregister a field and wipe its
  // value. Each test restates one acceptance criterion.
  // -------------------------------------------------------------------------

  /// Phone-sized viewport: the form is far taller than the viewport, so the
  /// name field ends up well outside a lazy list's 250px cacheExtent when the
  /// form is scrolled to the bottom. Shrink further if the scroll extent is
  /// ever not enough to push the name field off screen.
  void _useShortViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'every form field renders in a single Column under the FormBuilder, wrapped by one outer scroller',
    (tester) async {
      _useShortViewport(tester);
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Exactly one scroller, and it WRAPS the form (rather than the form
      // wrapping it).
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(FormBuilder),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FormBuilder),
          matching: find.byType(SliverList),
        ),
        findsNothing,
        reason:
            'no FormBuilder-owned field may sit inside a lazily-built sliver',
      );

      // The FormBuilder's child is the Column that holds every field.
      final column =
          tester.widget<FormBuilder>(find.byType(FormBuilder)).child as Column;
      expect(column.mainAxisSize, MainAxisSize.min);
      expect(
        column.crossAxisAlignment,
        CrossAxisAlignment.stretch,
        reason:
            'stretch reproduces the tight full-width constraint the fields had '
            'as direct ListView children',
      );

      // All FOUR create fields are already built on a 400x400 viewport WITHOUT
      // any scrolling — a lazy list would not have built the bottom ones.
      // (group-create-simplify: the fifth, group_members, is edit-only now.)
      expect(find.byType(TextFormField), findsOneWidget); // name
      expect(
        _swatchFinder(),
        findsNWidgets(kGroupColorPalette.length),
      ); // color_value
      expect(find.text(l10n.groupMemberSectionTitle), findsNothing);
      expect(
        find.text(l10n.groupTrackingModeSimplifiedTitle),
        findsOneWidget,
      ); // simplified_expenses
      expect(find.byType(GroupCurrencyField), findsOneWidget); // currency_code
    },
  );

  testWidgets(
    'clearValueOnUnregister matches the expense form (true), the false stopgap is gone',
    (tester) async {
      await _pump(tester);

      expect(
        tester
            .widget<FormBuilder>(find.byType(FormBuilder))
            .clearValueOnUnregister,
        isTrue,
      );
    },
  );

  testWidgets(
    'scrolling to the currency picker keeps the name field mounted and its value survives save (create)',
    (tester) async {
      _useShortViewport(tester);
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Type a group name at the top of the form.
      final nameField = find.widgetWithText(TextFormField, l10n.groupNameHint);
      await tester.enterText(nameField, 'Trip to Rome');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Scroll all the way down to the currency picker (a single over-long drag
      // clamps at the max scroll extent).
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(
        find.byType(GroupCurrencyField).hitTestable(),
        findsOneWidget,
        reason: 'the currency picker at the bottom is on screen',
      );

      // The name field is scrolled out of the viewport but STILL MOUNTED, so it
      // never unregistered.
      expect(nameField, findsOneWidget);
      expect(
        tester.getRect(nameField).bottom,
        lessThan(tester.getRect(find.byType(ListView)).top),
        reason: 'the name field is above the scroller viewport, yet mounted',
      );

      // Saving from here (what _save does: saveAndValidate() then .value) keeps
      // the name. This pair of expectations is only satisfiable with the Column
      // restructure: with the old fields-as-ListView-children tree,
      // clearValueOnUnregister: true drops name from FormBuilderState.value.
      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.saveAndValidate(), isTrue);
      expect(form.value['name'], 'Trip to Rome');
    },
  );

  testWidgets(
    'scrolling to the bottom preserves every other field value too (edit)',
    (tester) async {
      _useShortViewport(tester);
      final usd = _group(simplifiedExpenses: false)..currencyCode = 'USD';
      await _pump(tester, group: usd);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.saveAndValidate(), isTrue);

      // Every key GroupRepository.saveAll consumes survives the scroll.
      expect(form.value['name'], 'Trip to Rome');
      expect(form.value['color_value'], kGroupColorPalette.first.toARGB32());
      expect(form.value['simplified_expenses'], isFalse);
      expect(form.value['currency_code'], 'USD');
    },
  );

  testWidgets(
    'no layout regression: section order, full-width fields and sticky footer (create and edit)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      double dyOf(Finder finder) => tester.getTopLeft(finder).dy;

      // Both flows are pumped in this single test (create, then edit). Avoid
      // FriendshipListNotifier's real Supabase realtime subscription here: its
      // retry backoff timer is not cancelled by disposeChannels() (a
      // pre-existing gap, out of scope for this feature), and surviving across
      // the create->edit remount trips flutter_test's "no pending timers"
      // invariant. Neither flow's layout assertions depend on friend data.
      final noRealtimeOverrides = [
        friendshipListProvider.overrideWith(
          () => _FakeFriendshipListNotifier(const []),
        ),
      ];

      // --- create flow -----------------------------------------------------
      await _pump(tester, overrides: noRealtimeOverrides);

      // Content is full width: viewport 800 minus the list's 20+20 padding.
      expect(tester.getSize(find.byType(FormBuilder)).width, 760);

      // Section order, top to bottom.
      expect(
        dyOf(find.byType(TextFormField)),
        lessThan(dyOf(find.text(l10n.groupColorLabel))),
      );
      // group-create-simplify: colour is followed directly by tracking mode —
      // the member section is gone from create.
      expect(find.text(l10n.groupMemberSectionTitle), findsNothing);
      expect(
        dyOf(find.text(l10n.groupColorLabel)),
        lessThan(dyOf(find.text(l10n.groupTrackingModeTitle))),
      );
      expect(
        dyOf(find.text(l10n.groupTrackingModeTitle)),
        lessThan(dyOf(find.text(l10n.groupCurrencyLabel))),
      );

      // The sticky footer is OUTSIDE the scroller, below it.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(PrimaryButton),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byType(PrimaryButton)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom),
      );
      expect(find.text(l10n.createGroup), findsOneWidget);

      // --- edit flow -------------------------------------------------------
      await _pump(tester, group: _group(), overrides: noRealtimeOverrides);

      expect(tester.getSize(find.byType(FormBuilder)).width, 760);

      // The EDIT form is unchanged in shape: same fields, same order — a
      // read-only members row (group-member-add-flow) now sits in the same
      // slot the member section used to, still carrying the same label.
      expect(
        dyOf(find.text('Trip to Rome')),
        lessThan(dyOf(find.text(l10n.groupColorLabel))),
      );
      expect(
        dyOf(find.text(l10n.groupColorLabel)),
        lessThan(dyOf(find.text(l10n.groupMemberSectionTitle))),
      );
      expect(
        dyOf(find.text(l10n.groupMemberSectionTitle)),
        lessThan(dyOf(find.text(l10n.groupTrackingModeTitle))),
      );
      expect(
        dyOf(find.text(l10n.groupTrackingModeTitle)),
        lessThan(dyOf(find.text(l10n.groupCurrencyLabel))),
      );

      // Same order, with the edit-only actions block last.
      expect(
        dyOf(find.text(l10n.groupCurrencyLabel)),
        lessThan(dyOf(find.text(l10n.groupInviteTitle))),
      );
      expect(
        dyOf(find.text(l10n.groupInviteTitle)),
        lessThan(dyOf(find.text(l10n.groupDeleteItemTitle))),
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(PrimaryButton),
        ),
        findsNothing,
      );
      expect(find.text(l10n.save), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // -------------------------------------------------------------------------
  // group-create-simplify: create asks for the three decisions that must be
  // made up front and nothing else. Each test restates one acceptance
  // criterion.
  // -------------------------------------------------------------------------

  testWidgets(
    'the create form carries exactly three inputs: name + colour, tracking mode, currency',
    (tester) async {
      // Tall viewport so the whole create form is on screen at once.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A friend IS available: if any member affordance survived on create, the
      // inline candidate row would render and this test would catch it.
      await _pump(
        tester,
        overrides: [
          friendshipListProvider.overrideWith(
            () => _FakeFriendshipListNotifier([
              _friend('sam@test.com', 'Sam', 'sam'),
            ]),
          ),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The three inputs.
      expect(
        find.widgetWithText(TextFormField, l10n.groupNameHint),
        findsOneWidget,
      );
      expect(_swatchFinder(), findsNWidgets(kGroupColorPalette.length));
      expect(find.text(l10n.groupTrackingModeSimplifiedTitle), findsOneWidget);
      expect(find.text(l10n.groupTrackingModeDetailedTitle), findsOneWidget);
      expect(find.byType(GroupCurrencyField), findsOneWidget);

      // No member section in ANY of its forms: no roster row, no inline
      // friend candidate.
      expect(find.text(l10n.groupMemberSectionTitle), findsNothing);
      expect(find.text(l10n.you), findsNothing);
      expect(find.text('Sam'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);

      // The form registers no member field at all, so no member value can reach
      // GroupRepository.saveAll from here.
      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.fields.keys.toSet(), {
        'name',
        'color_value',
        'simplified_expenses',
        'currency_code',
      });
    },
  );

  // group-member-add-flow: the edit form carries no member field either — it
  // links out to the standalone Members page instead.
  testWidgets(
    'the edit form registers no member field and links to the Members page',
    (tester) async {
      await _pumpEditWithRouter(tester, group: _group());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.fields.keys.toSet(), {
        'name',
        'color_value',
        'simplified_expenses',
        'currency_code',
      });
      expect(form.value.containsKey('group_members'), isFalse);
      // _group() carries exactly one active member (the creator).
      expect(find.text(l10n.groupMemberCountLabel(1)), findsOneWidget);

      await tester.tap(find.text(l10n.groupMemberSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text('MEMBER SURFACE'), findsOneWidget);
    },
  );

  testWidgets(
    'creating with only a name keeps the create defaults: Simplified and EUR',
    (tester) async {
      await _pump(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.enterText(
        find.widgetWithText(TextFormField, l10n.groupNameHint),
        'Trip to Rome',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // What _save hands to GroupRepository.saveAll.
      final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
      expect(form.saveAndValidate(), isTrue);
      expect(form.value['name'], 'Trip to Rome');
      expect(
        form.value['simplified_expenses'],
        isTrue,
        reason: 'the existing create default (Simplified) is untouched',
      );
      expect(form.value['currency_code'], kDefaultCurrencyCode);
      expect(kDefaultCurrencyCode, 'EUR');
      expect(form.value.containsKey('group_members'), isFalse);
    },
  );

  // -------------------------------------------------------------------------
  // multi-currency-group: the shared currency picker replaces the DropdownButton,
  // and the group-currency lock is wired into GroupCurrencyField's disabled state.
  // -------------------------------------------------------------------------

  testWidgets('tapping the currency field opens the shared picker and the pick '
      'lands in the form value', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // A name is required to saveAndValidate(); unrelated to the currency
    // criterion under test, but needed to exercise the form value round-trip.
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.groupNameHint),
      'Trip to Rome',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GroupCurrencyField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
    expect(form.saveAndValidate(), isTrue);
    expect(form.value['currency_code'], 'USD');
  });

  testWidgets('a locked group currency cannot be changed and states why', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Theme(
            data: getThemeData(context, kBrandSeed, Brightness.light),
            child: Scaffold(
              body: FormBuilder(
                child: GroupCurrencyField(group: _group(), locked: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.groupCurrencyLockedNote), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // Disabled: tapping opens nothing.
    await tester.tap(find.byType(GroupCurrencyField));
    await tester.pumpAndSettle();
    expect(find.text('USD'), findsNothing);
  });

  testWidgets(
    'an unlocked group still shows the relabel note, not the lock note',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, group: _group());
      expect(find.text(l10n.groupCurrencyRelabelNote), findsOneWidget);
      expect(find.text(l10n.groupCurrencyLockedNote), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // save-status-rollout — the save confirmation lives on the sticky-footer CTA.
  // It used to be a snackbar fired from `_save`, with the `finally` navigating
  // away one line later, so it landed on the new group's detail page.
  // -------------------------------------------------------------------------

  testWidgets('the check lands on the sticky CTA before the route changes', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final save = _GatedGroupSave();
    await _pumpSave(tester, group: _group(), save: save);

    await tester.tap(_stickyCta);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(_footerButton(tester).loading, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    save.gate.complete();
    await tester.pump(); // the save resolves, the CTA flips to done
    await tester.pump();

    expect(find.byKey(kPrimaryButtonCheckPopKey), findsOneWidget);
    // _StickyFooter has to carry the third state through to its PrimaryButton.
    expect(_footerButton(tester).succeeded, isTrue);
    expect(_footerButton(tester).successLabel, l10n.groupSaveSuccess);
    expect(
      find.text('GROUP DETAIL'),
      findsNothing,
      reason: 'the form must still be on screen while the check shows',
    );

    // …and the navigation still happens once the confirmation has been seen.
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('GROUP DETAIL'), findsOneWidget);
  });

  testWidgets('saving a group fires no success message', (tester) async {
    final save = _GatedGroupSave();
    await _pumpSave(tester, group: _group(), save: save);

    await tester.tap(_stickyCta);
    await tester.pump();
    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(save.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a second tap while saving does not fire a second write', (
    tester,
  ) async {
    final save = _GatedGroupSave();
    await _pumpSave(tester, group: _group(), save: save);

    await tester.tap(_stickyCta);
    await tester.pump();
    await tester.tap(_stickyCta, warnIfMissed: false);
    await tester.pump();

    expect(save.calls, 1);

    save.gate.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('creating a group still confirms "Group created!"', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final save = _GatedGroupSave();
    await _pumpSave(tester, save: save);

    await tester.enterText(find.byType(TextFormField), 'Trip to Rome');
    await tester.pump();

    await tester.tap(_stickyCta);
    await tester.pump();
    save.gate.complete();
    await tester.pump();
    await tester.pump();

    // The copy branches on _isEdit: editing a group used to report that one had
    // been created.
    expect(_footerButton(tester).succeeded, isTrue);
    expect(_footerButton(tester).successLabel, l10n.groupCreateSuccess);
    expect(_footerButton(tester).successLabel, isNot(l10n.groupSaveSuccess));

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a failed save keeps its error, stays put and shows no check', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final save = _GatedGroupSave(throwing: Exception('offline'));
    await _pumpSave(tester, group: _group(), save: save);

    await tester.tap(_stickyCta);
    await tester.pump();
    save.gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.groupCreateError), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(_footerButton(tester).succeeded, isFalse);
    expect(_footerButton(tester).loading, isFalse);
    expect(_footerButton(tester).onPressed, isNotNull);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(
      find.text('GROUP DETAIL'),
      findsNothing,
      reason: 'a failed save must not navigate anywhere',
    );
  });

  testWidgets('reduced motion collapses the confirmation hold', (tester) async {
    final save = _GatedGroupSave();
    await _pumpSave(tester, group: _group(), save: save, reduceMotion: true);

    await tester.tap(_stickyCta);
    await tester.pump();
    save.gate.complete();
    await tester.pump(); // the save resolves, the CTA flips to done

    // 200 ms of frames — well inside Motion.saveConfirmationHold, so with an
    // uncollapsed hold the form would still be sitting on its check here.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      find.text('GROUP DETAIL'),
      findsOneWidget,
      reason: 'with the hold collapsed the route changes straight away',
    );
  });

  // save-status-rollout — groupSaveSuccess is new copy; assert it has real
  // German coverage rather than a carried-over English string, matching the
  // en≠de pair assertion record_payback_sheet_test.dart runs for
  // paybackRecordedShort.
  test('groupSaveSuccess is translated, not copied, in German', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));

    expect(de.groupSaveSuccess, isNotEmpty);
    expect(de.groupSaveSuccess, isNot(en.groupSaveSuccess));
  });
}
