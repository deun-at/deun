// guest-merge-rpc: the invite-link join page on its three seams. Each test
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

GroupMember _guest(String email, String name) => GroupMember()
  ..groupId = 'g1'
  ..email = email
  ..displayName = name
  ..isGuest = true
  ..isFavorite = false;

Group _group(String id) => Group()..id = id;

/// Pumps the join page for group `g1` under a router whose `/group/details`
/// probe prints the id of the group it was handed.
Future<void> _pump(
  WidgetTester tester, {
  required GroupJoiner joinGroup,
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
            groupName: 'Trip',
            joinGroup: joinGroup,
            loadJoinState:
                loadJoinState ??
                (_) async => GroupJoinState(
                  isActiveMember: false,
                  joinableGuests: [_guest(_gina, 'Gina')],
                ),
            loadGroup: loadGroup ?? (id) async => _group(id),
          ),
        ),
      ),
      GoRoute(
        path: '/group/details',
        builder: (context, state) {
          final group = (state.extra as Map<String, dynamic>)['group'] as Group;
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
  late List<(String, String?)> calls;

  setUp(() => calls = []);

  Future<void> recordJoin(String groupId, {String? guestEmail}) async =>
      calls.add((groupId, guestEmail));

  testWidgets(
    'joining with a guest picked passes exactly that group and that guest, once',
    (tester) async {
      await _pump(tester, joinGroup: recordJoin);

      await tester.tap(find.text('Gina'));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', _gina)]);
    },
  );

  testWidgets('joining as a new member passes no guest', (tester) async {
    await _pump(tester, joinGroup: recordJoin);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(calls, [('g1', null)]);
  });

  testWidgets('a second tap while a join is in flight makes no second call', (
    tester,
  ) async {
    final inFlight = Completer<void>();
    await _pump(
      tester,
      joinGroup: (groupId, {guestEmail}) {
        calls.add((groupId, guestEmail));
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
        joinGroup: (groupId, {guestEmail}) async {
          calls.add((groupId, guestEmail));
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

      expect(calls, [('g1', _gina), ('g1', _gina)]);
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
      loadJoinState: (_) async =>
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
        loadJoinState: (_) async => throw Exception('load failed'),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.groupInviteJoinAsNew), findsOneWidget);
      expect(find.textContaining('DETAILS'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(calls, [('g1', null)]);
    },
  );
}
