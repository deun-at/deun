// injectable-repositories: an account switch, driven through the auth stream,
// leaves nothing of the previous account on screen. The data fakes answer for
// whichever user their provider built them for; the real notifiers sit on
// top. AuthUserSwitchListener is not mounted: the providers alone must do it.

import 'dart:async';

import 'package:deun/constants.dart';
import 'package:deun/helper/currency_breakdown.dart';
import 'package:deun/helper/realtime_mixin.dart';
import 'package:deun/l10n/app_localizations.dart';
import 'package:deun/pages/expenses/data/expense_entry_model.dart';
import 'package:deun/pages/expenses/data/expense_model.dart';
import 'package:deun/pages/expenses/presentation/expense_detail_read.dart';
import 'package:deun/pages/friends/data/friendship_model.dart';
import 'package:deun/pages/friends/data/friendship_repository.dart';
import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:deun/widgets/theme_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_realtime_channel_factory.dart';
import '../helper/fake_supabase.dart';
import '../helper/two_user_fixtures.dart';

const _names = {ann: 'Ann', bob: 'Bob'};
final _annUser = authUser('ann-id', ann);
final _bobUser = authUser('bob-id', bob);

class _Users implements UserRepository {
  @override
  Future<SupaUser> fetchDetail(String email) async =>
      SupaUser(email: email, displayName: _names[email]!);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Groups implements GroupRepository {
  _Groups(this.actingAs);

  final CurrentUser? actingAs;

  Group _parse() =>
      Group()
        ..loadDataFromJson(sharedGroupRow(), currentUserEmail: actingAs?.email);

  @override
  Future<List<Group>> fetchData(String statusFilter, {String? paidTo}) async =>
      actingAs == null ? const [] : [_parse()];

  @override
  Future<Group> fetchDetail(String groupId) async => _parse();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Friendships implements FriendshipRepository {
  _Friendships(this.actingAs, this.groups);

  final CurrentUser? actingAs;
  final GroupRepository groups;

  @override
  Future<List<Friendship>> fetchData() async {
    final user = actingAs;
    if (user == null) return const [];
    final friendship = Friendship()
      ..loadDataFromJson(annBobFriendshipRow(), currentUserEmail: user.email);
    final group = (await groups.fetchData('active')).single;
    friendship.balances = [
      CurrencyAmount(
        group.currency,
        group.groupSharesSummary[friendship.user.email]!.shareAmount,
      ),
    ];
    return [friendship];
  }

  @override
  Future<List<Friendship>> fetchPendingIncoming() async => const [];

  @override
  Future<List<Friendship>> fetchPendingOutgoing() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

/// Ann paid 20 for both of them.
Expense _dinner() {
  final e = Expense();
  e.id = 'e1';
  e.groupId = 'g1';
  e.name = 'Dinner';
  e.amount = 20;
  e.paidBy = ann;
  e.paidByDisplayName = 'Ann';
  e.expenseDate = '2026-01-01';
  e.createdAt = '';
  e.isPaidBackRow = false;
  e.category = null;
  e.groupMemberShareStatistic = {ann: 10, bob: 10};
  e.expenseEntries = {
    'x1': ExpenseEntry(index: 0)
      ..splitMode = 'equal'
      ..quantity = 1,
  };
  return e;
}

void main() {
  final sequences = {
    'A, signed out, then signed in as B': [
      authEvent(AuthChangeEvent.signedOut, null),
      authEvent(AuthChangeEvent.signedIn, _bobUser),
    ],
    'A, then signed in as B with no sign-out between': [
      authEvent(AuthChangeEvent.signedIn, _bobUser),
    ],
  };

  for (final MapEntry(key: label, value: toBob) in sequences.entries) {
    testWidgets(
      "switching accounts ($label) shows only B's name and balances, and B as You",
      (tester) async {
        final auth = StreamController<AuthState>.broadcast();
        addTearDown(auth.close);
        final container = ProviderContainer.test(
          retry: (_, _) => null,
          overrides: [
            authStateChangesProvider.overrideWith((ref) => auth.stream),
            // The session the client restored at start: Ann.
            supabaseClientProvider.overrideWithValue(
              FakeSupabaseClient(currentUser: _annUser),
            ),
            realtimeChannelFactoryProvider.overrideWithValue(
              FakeRealtimeChannelFactory(),
            ),
            userRepositoryProvider.overrideWithValue(_Users()),
            groupRepositoryProvider.overrideWith(
              (ref) => _Groups(ref.watch(currentUserProvider)),
            ),
            friendshipRepositoryProvider.overrideWith(
              (ref) => _Friendships(
                ref.watch(currentUserProvider),
                ref.watch(groupRepositoryProvider),
              ),
            ),
          ],
        );

        Future<void> settle(List<AuthState> events) =>
            tester.runAsync(() async {
              for (final event in events) {
                auth.add(event);
                await pumpEventQueue();
                await container.pump();
              }
              await pumpEventQueue();
            });

        await tester.runAsync(() async {
          container.listen(userDetailProvider, (_, _) {}, onError: (_, _) {});
          container.listen(groupListProvider, (_, _) {}, onError: (_, _) {});
          container.listen(
            friendshipListProvider,
            (_, _) {},
            onError: (_, _) {},
          );
        });
        await settle([authEvent(AuthChangeEvent.initialSession, _annUser)]);

        // Precondition: Ann's own view.
        expect(
          container.read(userDetailProvider).requireValue.displayName,
          'Ann',
        );
        expect(
          container
              .read(groupListProvider)
              .requireValue
              .single
              .totalShareAmount,
          10,
        );
        final annsFriend = container
            .read(friendshipListProvider)
            .requireValue
            .acceptedFriends
            .single;
        expect(annsFriend.user.email, bob);
        expect(annsFriend.shareAmount, 10);

        await settle(toBob);

        // The greeting, the balance hero's group and the friend balance are B's.
        expect(
          container.read(userDetailProvider).requireValue.displayName,
          'Bob',
        );
        final group = container.read(groupListProvider).requireValue.single;
        expect(group.totalShareAmount, -10);
        final bobsFriend = container
            .read(friendshipListProvider)
            .requireValue
            .acceptedFriends
            .single;
        expect(bobsFriend.user.email, ann);
        expect(bobsFriend.shareAmount, -10);

        // In the shared group B is "You" and Ann is named.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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
                  data: getThemeData(context, kBrandSeed, Brightness.light),
                  child: ExpenseDetailRead(
                    group: group,
                    expense: _dinner(),
                    loadGroupPaybacks: (_) async => const [],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('You'), findsWidgets);
        expect(find.text('Ann'), findsWidgets);
        expect(find.text('Bob'), findsNothing);
      },
    );
  }
}
