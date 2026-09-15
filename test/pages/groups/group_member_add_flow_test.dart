// group-member-add-flow: a standalone Members page carrying every add path
// (friend, email/handle lookup, guest) and the existing removal flow. Each
// test restates one acceptance criterion.

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/provider/expense_list.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_add.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:deun/pages/groups/presentation/group_detail.dart';
import 'package:deun/pages/groups/presentation/group_members_page.dart';
import 'package:deun/pages/groups/provider/group_detail.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/widgets/restyle/deun_header.dart';
import 'package:deun/widgets/restyle/member_avatar.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/restyle/search_field.dart';
import 'package:deun/widgets/restyle/section_label.dart';
import 'package:deun/widgets/restyle/sheet_scaffold.dart';
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

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

// Every member/candidate carries a username, so its fullUsername subtitle
// ("sam#0001") never collides with its own displayName title ("Sam") in a
// text finder — the same trap the old GroupMemberSearch fixtures avoided by
// scoping to the ListTile title.
GroupMember _member(
  String email,
  String name, {
  DateTime? removedAt,
  bool isGuest = false,
}) {
  final m = GroupMember();
  m.groupId = 'g1';
  m.email = email;
  m.displayName = name;
  m.username = isGuest ? null : email.split('@').first;
  m.usernameCode = isGuest ? null : '0001';
  m.isGuest = isGuest;
  m.isFavorite = false;
  m.removedAt = removedAt;
  return m;
}

SupaUser _user(String email, String name) => SupaUser(
  email: email,
  displayName: name,
  username: email.split('@').first,
  usernameCode: '0001',
);

/// The [SoftCard] row whose title Text is [name] — scopes an icon lookup to
/// one specific roster row when more than one row carries the same icon.
Finder _rowFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(SoftCard)).first;

Finder _iconIn(String name, IconData icon) =>
    find.descendant(of: _rowFor(name), matching: find.byIcon(icon));

Group _group({
  List<GroupMember>? members,
  Map<String, double> memberBalances = const {},
  String currencyCode = 'EUR',
}) {
  final g = Group();
  g.id = 'g1';
  g.name = 'Trip';
  g.colorValue = kBrandSeed.toARGB32();
  g.simplifiedExpenses = true;
  g.createdAt = '';
  g.userId = null;
  g.currencyCode = currencyCode;
  g.groupMembers =
      members ?? [_member('me@test.com', 'Me'), _member('ann@test.com', 'Ann')];
  g.groupSharesSummary = {};
  g.totalExpenses = 0;
  g.totalShareAmount = 0;
  g.expenses = [];
  g.memberBalances = memberBalances;
  return g;
}

class _StubExpenseList extends ExpenseListNotifier {
  @override
  Future<List<Expense>> build(String groupId) async => <Expense>[];
}

/// A reload queue: the notifier starts on [_current] and swaps to
/// [_afterReload] (when given) the first time [reload] is called, so a
/// write's effect on the roster is observable offline.
class _FakeGroupDetailNotifier extends GroupDetailNotifier {
  _FakeGroupDetailNotifier(this._current, [this._afterReload]);
  Group _current;
  final Group? _afterReload;
  int reloads = 0;

  @override
  Future<Group> build(String groupId) async => _current;

  @override
  Future<void> reload(String groupId) async {
    reloads++;
    if (_afterReload != null) _current = _afterReload;
    state = AsyncData(_current);
  }
}

Future<_FakeGroupDetailNotifier> _pumpMembersPage(
  WidgetTester tester, {
  required Group group,
  Group? afterReload,
  Future<MemberSearchResults> Function(String query, Set<String> exclude)?
  searchOverride,
  Future<MemberAddOutcome> Function(String groupId, String email)?
  addMemberOverride,
  Future<SupaUser> Function(String displayName)? createGuestOverride,
  Future<MemberRemovalOutcome> Function(
    String groupId,
    String email, {
    required Currency currency,
  })?
  previewRemovalOverride,
  Future<MemberRemovalOutcome> Function(
    String groupId,
    String email, {
    required Currency currency,
  })?
  removeMemberOverride,
  void Function(String groupId, Set<String> emails)? notifyOverride,
}) async {
  final notifier = _FakeGroupDetailNotifier(group, afterReload);
  final router = GoRouter(
    initialLocation: '/group/members',
    routes: [
      GoRoute(
        path: '/group/members',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupMembersPage(
            group: group,
            searchOverride: searchOverride,
            addMemberOverride: addMemberOverride,
            createGuestOverride: createGuestOverride,
            previewRemovalOverride: previewRemovalOverride,
            removeMemberOverride: removeMemberOverride,
            notifyOverride: notifyOverride,
          ),
        ),
      ),
      GoRoute(
        path: '/group/details/payment',
        builder: (context, state) => const Scaffold(body: Text('PAYMENT')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [groupDetailProvider(group.id).overrideWith(() => notifier)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

/// Pumps the real [GroupDetail] in a router carrying `/group/members` and
/// `/group/edit` probe routes, so the add-members entry point's destination
/// can be observed.
Future<void> _pumpGroupDetail(
  WidgetTester tester, {
  required Group group,
}) async {
  final router = GoRouter(
    initialLocation: '/group/details',
    routes: [
      GoRoute(
        path: '/group/details',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupDetail(group: group),
        ),
      ),
      GoRoute(
        path: '/group/members',
        builder: (context, state) => const Scaffold(body: Text('MEMBERS')),
      ),
      GoRoute(
        path: '/group/edit',
        builder: (context, state) => const Scaffold(body: Text('GROUP FORM')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupDetailProvider(
          group.id,
        ).overrideWith(() => _FakeGroupDetailNotifier(group)),
        expenseListProvider(group.id).overrideWith(_StubExpenseList.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // Never pumpAndSettle here: the loading shimmer repeats forever.
  await tester.pump();
  await tester.pump();
}

/// Types [query] into the page's search field and lets the 400 ms debounce
/// and the resulting search settle.
Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

bool _anyTextContains(WidgetTester tester, String needle) {
  final lower = needle.toLowerCase();
  return tester
      .widgetList<Text>(find.byType(Text))
      .any((t) => (t.data ?? '').toLowerCase().contains(lower));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  // 1
  testWidgets(
    'the group-detail add-members action opens the Members page, not the group form',
    (tester) async {
      await _pumpGroupDetail(tester, group: _group());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      final addMembers = find.byWidgetPredicate(
        (w) => w is HeaderIconButton && w.tooltip == l10n.groupAddMembersAction,
      );
      await tester.tap(addMembers);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('MEMBERS'), findsOneWidget);
      expect(find.text('GROUP FORM'), findsNothing);
    },
  );

  // 2
  testWidgets(
    'adding a member writes on its own and the page carries no save button',
    (tester) async {
      final addCalls = <(String, String)>[];
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('sam@test.com', 'Sam')],
          otherUsers: const [],
        ),
        addMemberOverride: (groupId, email) async {
          addCalls.add((groupId, email));
          return MemberAddOutcome.inserted;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'sam');

      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();

      expect(addCalls, [('g1', 'sam@test.com')]);
      expect(find.widgetWithText(PrimaryButton, l10n.save), findsNothing);
      expect(find.byType(FormBuilder), findsNothing);
    },
  );

  // 3
  testWidgets(
    'a failed add leaves the group attributes untouched and the query in the field',
    (tester) async {
      final group = _group();
      await _pumpMembersPage(
        tester,
        group: group,
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('sam@test.com', 'Sam')],
          otherUsers: const [],
        ),
        addMemberOverride: (groupId, email) async => throw Exception('boom'),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'sam');

      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SnackBar, l10n.groupMemberAddError('Sam')),
        findsOneWidget,
      );
      expect(
        find.text('sam'),
        findsOneWidget,
        reason: 'the query stays in the field',
      );
      // Roster unchanged: still exactly the two original rows.
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
    },
  );

  // 4
  testWidgets(
    'all four add paths are on the page: friend, email/handle lookup, and create-guest',
    (tester) async {
      final addCalls = <(String, String)>[];
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('sam@test.com', 'Sam')],
          otherUsers: [_user('priya@test.com', 'Priya')],
        ),
        addMemberOverride: (groupId, email) async {
          addCalls.add((groupId, email));
          return MemberAddOutcome.inserted;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'sam');

      expect(
        find.widgetWithText(SectionLabel, l10n.groupMemberSectionFriends),
        findsOneWidget,
      );
      expect(find.text('Sam'), findsOneWidget);
      expect(
        find.widgetWithText(SectionLabel, l10n.groupMemberSectionOtherUsers),
        findsOneWidget,
      );
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text(l10n.groupMemberAddGuestOption('sam')), findsOneWidget);

      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();
      expect(addCalls, [('g1', 'sam@test.com')]);

      await _search(tester, 'priya');
      await tester.tap(find.text('Priya'));
      await tester.pumpAndSettle();
      expect(addCalls, [('g1', 'sam@test.com'), ('g1', 'priya@test.com')]);
    },
  );

  // 5
  testWidgets(
    'a failed guest creation says so and keeps the name for a retry',
    (tester) async {
      final addCalls = <(String, String)>[];
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async =>
            const MemberSearchResults(friends: [], otherUsers: []),
        createGuestOverride: (name) async => throw Exception('boom'),
        addMemberOverride: (groupId, email) async {
          addCalls.add((groupId, email));
          return MemberAddOutcome.inserted;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'Max');

      await tester.tap(find.text(l10n.groupMemberAddGuestOption('Max')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.groupMemberGuestCreateButton));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SnackBar, l10n.groupMemberGuestCreateError('Max')),
        findsOneWidget,
      );
      expect(
        find.text('Max'),
        findsWidgets,
        reason: 'the guest field keeps the name',
      );
      expect(addCalls, isEmpty);
    },
  );

  // 6
  testWidgets('creating a guest adds them and marks the row Guest', (
    tester,
  ) async {
    final addCalls = <(String, String)>[];
    final group = _group();
    final afterAdd = _group(
      members: [
        ..._group().groupMembers,
        _member('guest+1@guest.invalid', 'Max', isGuest: true),
      ],
    );
    await _pumpMembersPage(
      tester,
      group: group,
      afterReload: afterAdd,
      searchOverride: (query, exclude) async =>
          const MemberSearchResults(friends: [], otherUsers: []),
      createGuestOverride: (name) async => SupaUser(
        email: 'guest+1@guest.invalid',
        displayName: name,
        isGuest: true,
      ),
      addMemberOverride: (groupId, email) async {
        addCalls.add((groupId, email));
        return MemberAddOutcome.inserted;
      },
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _search(tester, 'Max');

    await tester.tap(find.text(l10n.groupMemberAddGuestOption('Max')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.groupMemberGuestCreateButton));
    await tester.pumpAndSettle();

    expect(addCalls, [('g1', 'guest+1@guest.invalid')]);
    expect(find.text('Max'), findsOneWidget);
    expect(find.text(l10n.groupMemberIsGuest), findsOneWidget);
    expect(find.byType(MemberAvatar), findsWidgets);
  });

  // 7
  testWidgets(
    'a settled removal goes through GroupRepository.removeMember, never a direct delete',
    (tester) async {
      final removeCalls = <(String, String)>[];
      final group = _group();
      final afterRemove = _group(members: [_member('me@test.com', 'Me')]);
      await _pumpMembersPage(
        tester,
        group: group,
        afterReload: afterRemove,
        previewRemovalOverride: (groupId, email, {required currency}) async =>
            MemberRemovalOutcome.softRemoved,
        removeMemberOverride: (groupId, email, {required currency}) async {
          removeCalls.add((groupId, email));
          return MemberRemovalOutcome.softRemoved;
        },
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(_iconIn('Ann', Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.groupMemberRemoveConfirm));
      await tester.pumpAndSettle();

      expect(removeCalls, [('g1', 'ann@test.com')]);
      expect(find.text('Ann'), findsNothing);
    },
  );

  // 8
  testWidgets('a hard removal commits with no dialog', (tester) async {
    final removeCalls = <(String, String)>[];
    await _pumpMembersPage(
      tester,
      group: _group(),
      previewRemovalOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.hardRemoved,
      removeMemberOverride: (groupId, email, {required currency}) async {
        removeCalls.add((groupId, email));
        return MemberRemovalOutcome.hardRemoved;
      },
    );

    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(_iconIn('Ann', Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    expect(removeCalls, [('g1', 'ann@test.com')]);
  });

  // 9
  testWidgets('a soft removal confirms once and says the past expenses stay', (
    tester,
  ) async {
    await _pumpMembersPage(
      tester,
      group: _group(),
      previewRemovalOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.softRemoved,
      removeMemberOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.softRemoved,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(_iconIn('Ann', Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.groupMemberRemoveBody), findsOneWidget);
  });

  testWidgets('cancelling the soft-removal confirmation writes nothing', (
    tester,
  ) async {
    final removeCalls = <(String, String)>[];
    await _pumpMembersPage(
      tester,
      group: _group(),
      previewRemovalOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.softRemoved,
      removeMemberOverride: (groupId, email, {required currency}) async {
        removeCalls.add((groupId, email));
        return MemberRemovalOutcome.softRemoved;
      },
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(_iconIn('Ann', Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(removeCalls, isEmpty);
    expect(find.text('Ann'), findsOneWidget);
  });

  // 10
  testWidgets(
    'an unsettled member carries a balance and a settle-up route, and no remove action',
    (tester) async {
      final group = _group(
        currencyCode: 'USD',
        memberBalances: {'ann@test.com': -12.5},
      );
      await _pumpMembersPage(tester, group: group);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.toCurrency(12.5, 'USD')), findsOneWidget);
      expect(_iconIn('Ann', Icons.close), findsNothing);
      await tester.tap(find.text('Ann'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text(l10n.groupDetailSettleUp));
      await tester.pumpAndSettle();
      expect(find.text('PAYMENT'), findsOneWidget);
    },
  );

  // 11
  testWidgets(
    'adding someone already in the group says so and adds no second row',
    (tester) async {
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('ann@test.com', 'Ann')],
          otherUsers: const [],
        ),
        addMemberOverride: (groupId, email) async =>
            MemberAddOutcome.alreadyMember,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'ann');

      await tester.tap(find.text('Ann').first);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SnackBar, l10n.groupMemberAlreadyInGroup('Ann')),
        findsOneWidget,
      );
      expect(find.text('Ann'), findsOneWidget);
    },
  );

  // 12
  testWidgets(
    'after a successful add the page stays open, the roster carries them and the field is empty',
    (tester) async {
      final group = _group();
      final afterAdd = _group(
        members: [..._group().groupMembers, _member('sam@test.com', 'Sam')],
      );
      await _pumpMembersPage(
        tester,
        group: group,
        afterReload: afterAdd,
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('sam@test.com', 'Sam')],
          otherUsers: const [],
        ),
        addMemberOverride: (groupId, email) async => MemberAddOutcome.inserted,
      );
      await _search(tester, 'sam');

      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupMembersPage), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  // 13
  testWidgets(
    'the guest row appears only with a query, and there is no standing guest button',
    (tester) async {
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async =>
            const MemberSearchResults(friends: [], otherUsers: []),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        find.textContaining(l10n.groupMemberAddGuestSubtitle),
        findsNothing,
      );
      expect(find.byIcon(Icons.person_add), findsNothing);

      await _search(tester, 'Max');

      expect(find.text(l10n.groupMemberAddGuestOption('Max')), findsOneWidget);
    },
  );

  // 14
  testWidgets(
    'a soft-removed member is not on the roster but is still findable in search',
    (tester) async {
      final group = _group(
        members: [
          _member('me@test.com', 'Me'),
          _member(
            'carol@test.com',
            'Carol',
            removedAt: DateTime.utc(2026, 8, 15),
          ),
        ],
      );
      final addCalls = <(String, String)>[];
      await _pumpMembersPage(
        tester,
        group: group,
        searchOverride: (query, exclude) async => MemberSearchResults(
          friends: [_user('carol@test.com', 'Carol')],
          otherUsers: const [],
        ),
        addMemberOverride: (groupId, email) async {
          addCalls.add((groupId, email));
          return MemberAddOutcome.reAdded;
        },
      );

      // Absent from the roster (only the guest-step / results block area would
      // hold a second "Carol" — none is open here).
      expect(find.text('Carol'), findsNothing);

      await _search(tester, 'carol');
      expect(find.text('Carol'), findsOneWidget);

      await tester.tap(find.text('Carol'));
      await tester.pumpAndSettle();

      expect(addCalls, [('g1', 'carol@test.com')]);
      expect(_anyTextContains(tester, 'removed'), isFalse);
    },
  );

  // 15
  testWidgets('the Members page is a page with the search above the roster', (
    tester,
  ) async {
    await _pumpMembersPage(tester, group: _group());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byType(DeunHeader), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SheetScaffold), findsNothing);
    expect(
      tester.getTopLeft(find.byType(SearchField)).dy,
      lessThan(
        tester
            .getTopLeft(
              find.widgetWithText(SectionLabel, l10n.groupMemberSectionTitle),
            )
            .dy,
      ),
    );
  });

  // 16
  testWidgets('a successful add reloads the group detail provider', (
    tester,
  ) async {
    final addFake = await _pumpMembersPage(
      tester,
      group: _group(),
      searchOverride: (query, exclude) async => MemberSearchResults(
        friends: [_user('sam@test.com', 'Sam')],
        otherUsers: const [],
      ),
      addMemberOverride: (groupId, email) async => MemberAddOutcome.inserted,
    );
    await _search(tester, 'sam');
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    expect(addFake.reloads, 1);
  });

  testWidgets('a successful removal reloads the group detail provider', (
    tester,
  ) async {
    final removeFake = await _pumpMembersPage(
      tester,
      group: _group(),
      previewRemovalOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.hardRemoved,
      removeMemberOverride: (groupId, email, {required currency}) async =>
          MemberRemovalOutcome.hardRemoved,
    );
    await tester.tap(_iconIn('Ann', Icons.close));
    await tester.pumpAndSettle();
    expect(removeFake.reloads, 1);
  });

  // 17
  testWidgets(
    'an ambiguous username renders the disambiguation hint instead of throwing',
    (tester) async {
      await _pumpMembersPage(
        tester,
        group: _group(),
        searchOverride: (query, exclude) async =>
            throw const AmbiguousUsernameException(),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _search(tester, 'sam');

      expect(find.text(l10n.addFriendshipAmbiguousUsername), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // 18
  testWidgets(
    'a group of one shows one add-members call to action that opens the Members page',
    (tester) async {
      final solo = _group(members: [_member('me@test.com', 'Me')]);
      await _pumpGroupDetail(tester, group: solo);

      expect(find.byType(AddMembersCta), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.groupMembersEmptyCtaTitle), findsOneWidget);

      await tester.tap(find.byType(AddMembersCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('MEMBERS'), findsOneWidget);
    },
  );

  testWidgets('the call to action is gone once a second member exists', (
    tester,
  ) async {
    await _pumpGroupDetail(tester, group: _group());
    expect(find.byType(AddMembersCta), findsNothing);
  });
}
