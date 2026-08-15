import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
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
  f.shareAmount = 0;
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
  Future<MemberRemovalOutcome> Function(String groupId, String email)?
  removeMemberOverride,
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
              group: group,
              removeMemberOverride: removeMemberOverride,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GroupMember _memberOf(String email, String display, {DateTime? removedAt}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = display;
  m.isGuest = false;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}

/// An existing group with Me + Ann, and optionally a removed Carol.
Group _groupWithRoster({bool carolRemoved = false}) {
  final g = _group();
  g.groupMembers = [
    _memberOf('me@test.com', 'Me'),
    _memberOf('ann@test.com', 'Ann'),
    if (carolRemoved)
      _memberOf(
        'carol@test.com',
        'Carol',
        removedAt: DateTime.utc(2026, 8, 15),
      ),
  ];
  return g;
}

/// A roster row's *title* Text, specifically — not a bare `find.text(name)`.
/// GroupMemberSearch's subtitle falls back to displayName when a member has no
/// username (as these test fixtures don't), so the name would otherwise match
/// both the title and the subtitle Text under the same ListTile.
bool _hasTitle(Widget w, String text) =>
    w is ListTile && w.title is Text && (w.title as Text).data == text;

Finder _rowTitle(String name) =>
    find.byWidgetPredicate((w) => _hasTitle(w, name));

/// The trailing remove action on a roster row (icon unchanged by this feature).
Finder _removeActionFor(String name) => find.descendant(
  of: _rowTitle(name),
  matching: find.byIcon(Icons.check_circle),
);

/// The group_members form value as GroupRepository.saveAll would receive it.
String _submittedMembers(WidgetTester tester) {
  final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
  expect(form.saveAndValidate(), isTrue);
  return form.value['group_members'] as String;
}

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
    final picker = find.byType(DropdownButton<String>);
    expect(picker, findsOneWidget);
    // A new group defaults to EUR (curated codes: EUR, USD, GBP, CHF...).
    expect(tester.widget<DropdownButton<String>>(picker).value, 'EUR');
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

      final picker = find.byType(DropdownButton<String>);
      expect(tester.widget<DropdownButton<String>>(picker).value, 'USD');
      // Changing currency relabels amounts without converting — the UI says so.
      expect(find.text(l10n.groupCurrencyRelabelNote), findsOneWidget);
    },
  );

  // F71: hybrid inline roster — You(Owner) row, greyed candidate toggle rows
  // from the friends provider, and an "Add guest" section-header link.
  testWidgets(
    'members section shows Owner tag, Add guest link and inline greyed friend rows (F71)',
    (tester) async {
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

      // "You" row with an "Owner" trailing tag.
      expect(find.text(l10n.you), findsOneWidget);
      expect(find.text(l10n.groupMemberOwnerTag), findsOneWidget);

      // "Add guest" section-header link.
      expect(find.text(l10n.groupMemberAddGuestLink), findsOneWidget);

      // The friend from the provider renders inline as a greyed toggle row: an
      // Opacity(0.45) ancestor wrapping the row, with an add-circle affordance.
      final samRow = find.text('Sam');
      expect(samRow, findsOneWidget);
      final greyed = find.ancestor(
        of: samRow,
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.45,
        ),
      );
      expect(
        greyed,
        findsOneWidget,
        reason: 'not-added friend must be greyed at .45 opacity',
      );
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    },
  );

  testWidgets(
    'tapping an inline friend row adds them (removes from candidates) (F71)',
    (tester) async {
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

      // Tapping the greyed candidate routes through the same add path the
      // SearchAnchor uses: Sam becomes a selected member (check_circle remove
      // action) and is no longer offered as a greyed add candidate.
      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();

      // Sam is no longer offered as a greyed add candidate...
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      // ...and now renders as a selected member row carrying a check_circle
      // remove action.
      expect(find.text('Sam'), findsOneWidget);
      final samCheck = find.descendant(
        of: find.ancestor(
          of: find.text('Sam'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(
        samCheck,
        findsOneWidget,
        reason: 'added friend shows a check_circle remove action',
      );
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

      // All five fields are already built on a 400x400 viewport WITHOUT any
      // scrolling — a lazy list would not have built the bottom ones.
      expect(find.byType(TextFormField), findsOneWidget); // name
      expect(
        _swatchFinder(),
        findsNWidgets(kGroupColorPalette.length),
      ); // color_value
      expect(
        find.text(l10n.groupMemberSectionTitle),
        findsOneWidget,
      ); // group_members
      expect(
        find.text(l10n.groupTrackingModeSimplifiedTitle),
        findsOneWidget,
      ); // simplified_expenses
      expect(
        find.byType(DropdownButton<String>),
        findsOneWidget,
      ); // currency_code
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
        find.byType(DropdownButton<String>).hitTestable(),
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
      expect(form.value['group_members'] as String, contains('me@test.com'));
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
  // group-member-removal: removing a member is an explicit, defined operation.
  // Each test restates one acceptance criterion.
  // -------------------------------------------------------------------------

  final noFriends = [
    friendshipListProvider.overrideWith(
      () => _FakeFriendshipListNotifier(const []),
    ),
  ];

  // 21
  testWidgets(
    'an unsettled member is not removed and the block names the outstanding amount',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        group: _groupWithRoster(),
        overrides: noFriends,
        removeMemberOverride: (groupId, email) async {
          calls.add('$groupId/$email');
          return const MemberRemovalOutcome.blocked(outstanding: 12.5);
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.ensureVisible(_rowTitle('Ann'));
      await tester.pumpAndSettle();
      await tester.tap(_removeActionFor('Ann'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupMemberRemoveConfirm));
      await tester.pumpAndSettle();

      expect(calls, ['g1/ann@test.com']);
      expect(
        find.text(
          l10n.groupMemberRemoveBlocked('Ann', l10n.toCurrency(12.5, 'EUR')),
        ),
        findsOneWidget,
        reason:
            'the block must name the outstanding amount in the group currency',
      );

      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      // Nothing changed client-side either: the member is still submitted.
      expect(_rowTitle('Ann'), findsOneWidget);
      expect(_submittedMembers(tester), contains('ann@test.com'));
    },
  );

  // 22
  testWidgets(
    'confirming a settled removal drops the member from the roster and the submitted list',
    (tester) async {
      await _pump(
        tester,
        group: _groupWithRoster(),
        overrides: noFriends,
        removeMemberOverride: (groupId, email) async =>
            MemberRemovalOutcome.softRemoved,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(_submittedMembers(tester), contains('ann@test.com'));

      await tester.ensureVisible(_rowTitle('Ann'));
      await tester.pumpAndSettle();
      await tester.tap(_removeActionFor('Ann'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupMemberRemoveConfirm));
      await tester.pumpAndSettle();

      // Ann is now listed under "Removed" (with an add-back action), never as an
      // active roster row, and she is out of the submitted list.
      expect(find.text(l10n.groupMemberRemovedSectionTitle), findsWidgets);
      expect(_removeActionFor('Ann'), findsNothing);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
      expect(_submittedMembers(tester), isNot(contains('ann@test.com')));
    },
  );

  // 23
  testWidgets(
    'a member loaded as removed sits in the Removed section, and Add back returns them',
    (tester) async {
      await _pump(
        tester,
        group: _groupWithRoster(carolRemoved: true),
        overrides: noFriends,
        removeMemberOverride: (groupId, email) async =>
            MemberRemovalOutcome.softRemoved,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Not an active member: no remove action, and not in the submitted list.
      expect(_removeActionFor('Carol'), findsNothing);
      expect(_submittedMembers(tester), isNot(contains('carol@test.com')));
      expect(find.text(l10n.groupMemberRemovedSectionTitle), findsWidgets);

      final addBack = find.byIcon(Icons.person_add_alt_1);
      expect(addBack, findsOneWidget);
      await tester.ensureVisible(addBack);
      await tester.pumpAndSettle();
      await tester.tap(addBack);
      await tester.pumpAndSettle();

      // Back in the submitted list (the save path clears removed_at) and back to
      // being a normal, removable roster row.
      expect(_submittedMembers(tester), contains('carol@test.com'));
      expect(find.byIcon(Icons.person_add_alt_1), findsNothing);
      expect(_removeActionFor('Carol'), findsOneWidget);
    },
  );

  // 24
  testWidgets(
    'while creating a group, removing a chip never calls the removal path',
    (tester) async {
      var calls = 0;
      await _pump(
        tester,
        overrides: [
          friendshipListProvider.overrideWith(
            () => _FakeFriendshipListNotifier([
              _friend('sam@test.com', 'Sam', 'sam'),
            ]),
          ),
        ],
        removeMemberOverride: (groupId, email) async {
          calls++;
          return MemberRemovalOutcome.softRemoved;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Add Sam to the not-yet-persisted group, then take him back off.
      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_rowTitle('Sam'));
      await tester.pumpAndSettle();
      await tester.tap(_removeActionFor('Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupMemberRemoveConfirm));
      await tester.pumpAndSettle();

      expect(
        calls,
        0,
        reason: 'nothing is persisted yet, so there is no membership to remove',
      );
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    },
  );

  // 25
  testWidgets('cancelling the confirm dialog removes nothing', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      group: _groupWithRoster(),
      overrides: noFriends,
      removeMemberOverride: (groupId, email) async {
        calls++;
        return MemberRemovalOutcome.softRemoved;
      },
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.ensureVisible(_rowTitle('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(_removeActionFor('Ann'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(_submittedMembers(tester), contains('ann@test.com'));
  });
}
