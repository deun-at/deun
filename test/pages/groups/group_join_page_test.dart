// guest-merge-rpc, group-id-leak: the invite-link join page on its three seams. Each test
// restates one contract criterion; no Supabase is reached.

import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/member_removal.dart';
import 'package:deun/pages/groups/presentation/group_join_page.dart';
import 'package:deun/widgets/restyle/primary_button.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _gina = 'guest+gina@guest.invalid';
const _token = '9b2c4e1a-6d3f-4a8b-b1c2-7e5d0f9a3c64';

GroupMember _guest(String email, String name) => GroupMember()
  ..groupId = 'g1'
  ..email = email
  ..displayName = name
  ..isGuest = true
  ..isFavorite = false;

Group _group(String id) => Group()..id = id;

/// Pumps the join page for group `g1` under a router whose group-detail
/// probe prints the id of the group it was handed.
Future<void> _pump(
  WidgetTester tester, {
  required GroupJoiner joinGroup,
  String? token = _token,
  GroupJoinStateLoader? loadJoinState,
  GroupDetailLoader? loadGroup,
}) async {
  final router = GoRouter(
    initialLocation: '/group/join',
    routes: [
      GoRoute(
        path: '/group/join',
        builder: (context, state) => Theme(
          data: getThemeData(
            context,
            kBrandSeed,
            Brightness.light,
          ).copyWith(splashFactory: NoSplash.splashFactory),
          child: GroupJoinPage(
            groupId: 'g1',
            token: token,
            groupName: 'Trip',
            joinGroup: joinGroup,
            loadJoinState:
                loadJoinState ??
                (_, {required token}) async => GroupJoinState(
                  isActiveMember: false,
                  joinableGuests: [_guest(_gina, 'Gina')],
                ),
            loadGroup: loadGroup ?? (id) async => _group(id),
          ),
        ),
      ),
      GoRoute(
        path: '/group/:groupId',
        builder: (context, state) {
          final group = state.extra! as Group;
          return Scaffold(body: Text('DETAILS ${group.id}'));
        },
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

void main() {
  late List<(String, String, String?)> calls;

  setUp(() => calls = []);

  Future<void> recordJoin(
    String groupId, {
    required String token,
    String? guestEmail,
  }) async => calls.add((groupId, token, guestEmail));

  testWidgets(
    "joining with a guest picked passes exactly that group, the link's token and that guest, once",
    (tester) async {
      await _pump(tester, joinGroup: recordJoin);

      await tester.tap(find.text('Gina'));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', _token, _gina)]);
    },
  );

  testWidgets('joining as a new member passes no guest', (tester) async {
    await _pump(tester, joinGroup: recordJoin);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(calls, [('g1', _token, null)]);
  });

  testWidgets('a second tap while a join is in flight makes no second call', (
    tester,
  ) async {
    final inFlight = Completer<void>();
    await _pump(
      tester,
      joinGroup: (groupId, {required token, guestEmail}) {
        calls.add((groupId, token, guestEmail));
        return inFlight.future;
      },
    );

    // Two taps in the same frame, then one after the rebuild.
    await tester.tap(find.byType(PrimaryButton));
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.pump();

    expect(calls, hasLength(1));

    inFlight.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a failed join shows an error, keeps the page and the guest choice, and the button works again',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        joinGroup: (groupId, {required token, guestEmail}) async {
          calls.add((groupId, token, guestEmail));
          throw Exception('join failed');
        },
      );

      await tester.tap(find.text('Gina'));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.generalError), findsOneWidget);
      expect(find.textContaining('DETAILS'), findsNothing);
      expect(
        tester
            .widget<RadioGroup<String?>>(find.byType(RadioGroup<String?>))
            .groupValue,
        _gina,
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', _token, _gina), ('g1', _token, _gina)]);
      expect(find.textContaining('DETAILS'), findsNothing);
    },
  );

  testWidgets('a successful join opens the group that was just joined', (
    tester,
  ) async {
    final loaded = <String>[];
    await _pump(
      tester,
      joinGroup: recordJoin,
      loadGroup: (id) async {
        loaded.add(id);
        return _group(id);
      },
    );

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(loaded, ['g1']);
    expect(find.text('DETAILS g1'), findsOneWidget);
  });

  testWidgets('an active member goes straight to the group with no join call', (
    tester,
  ) async {
    await _pump(
      tester,
      joinGroup: recordJoin,
      loadJoinState: (_, {required token}) async =>
          const GroupJoinState(isActiveMember: true, joinableGuests: []),
    );

    expect(find.text('DETAILS g1'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets(
    'when the join state cannot be loaded the page stops loading, stays, and still joins as a new member',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        joinGroup: recordJoin,
        loadJoinState: (_, {required token}) async =>
            throw Exception('load failed'),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.groupInviteJoinAsNew), findsOneWidget);
      expect(find.textContaining('DETAILS'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', _token, null)]);
    },
  );

  for (final (label, linkToken) in [
    ('no token', null),
    ('a malformed token', 'not-a-uuid'),
  ]) {
    testWidgets(
      'a link with $label shows the invite as no longer valid, lists no guests, offers no join and loads nothing',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final loads = <String>[];
        await _pump(
          tester,
          joinGroup: recordJoin,
          token: linkToken,
          loadJoinState: (_, {required token}) async {
            loads.add(token);
            return GroupJoinState(
              isActiveMember: false,
              joinableGuests: [_guest(_gina, 'Gina')],
            );
          },
        );

        expect(find.text(l10n.groupInviteInvalid), findsOneWidget);
        expect(find.text('Gina'), findsNothing);
        expect(find.byType(PrimaryButton), findsNothing);
        expect(loads, isEmpty);
        expect(calls, isEmpty);
      },
    );
  }

  testWidgets(
    'a token the server rejects shows the invite as no longer valid before listing anything',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        joinGroup: recordJoin,
        loadJoinState: (_, {required token}) async =>
            throw const InviteRejected(),
      );

      expect(find.text(l10n.groupInviteInvalid), findsOneWidget);
      expect(find.byType(RadioListTile<String?>), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.textContaining('DETAILS'), findsNothing);
    },
  );

  testWidgets(
    'a join refused for its token switches to the no-longer-valid state, with no error and no navigation',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        joinGroup: (groupId, {required token, guestEmail}) async {
          calls.add((groupId, token, guestEmail));
          throw const InviteRejected();
        },
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', _token, null)]);
      expect(find.text(l10n.groupInviteInvalid), findsOneWidget);
      expect(find.text(l10n.generalError), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.textContaining('DETAILS'), findsNothing);
    },
  );

  testWidgets(
    'a link with a well-formed token loads the join state for that group and token and offers joining',
    (tester) async {
      final loads = <(String, String)>[];
      await _pump(
        tester,
        joinGroup: recordJoin,
        loadJoinState: (groupId, {required token}) async {
          loads.add((groupId, token));
          return GroupJoinState(
            isActiveMember: false,
            joinableGuests: [_guest(_gina, 'Gina')],
          );
        },
      );

      expect(loads, [('g1', _token)]);
      expect(find.text('Gina'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
    },
  );

  testWidgets(
    'the invite strings group-id-leak adds are translated in German',
    (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final de = await AppLocalizations.delegate.load(const Locale('de'));
      final strings = <String, String Function(AppLocalizations)>{
        'groupInviteInvalid': (l) => l.groupInviteInvalid,
        'groupInviteResetLink': (l) => l.groupInviteResetLink,
        'groupInviteResetTitle': (l) => l.groupInviteResetTitle,
        'groupInviteResetBody': (l) => l.groupInviteResetBody,
        'groupInviteResetConfirm': (l) => l.groupInviteResetConfirm,
      };
      for (final MapEntry(key: key, value: read) in strings.entries) {
        expect(read(de), isNotEmpty, reason: key);
        expect(read(de), isNot(read(en)), reason: key);
      }
    },
  );
}
