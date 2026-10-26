// injectable-repositories: currentUserProvider follows the auth stream, and the
// repositories built from it fetch and write as that account. The client is a
// FakeSupabaseClient: every RPC is recorded and thrown, nothing is sent.

import 'dart:async';

import 'package:deun/helper/notification_sender.dart';
import 'package:deun/pages/groups/data/group_member_model.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:deun/pages/groups/data/payback_repository.dart';
import 'package:deun/pages/groups/data/payback_request.dart';
import 'package:deun/pages/users/current_user.dart';
import 'package:deun/pages/users/user_repository.dart';
import 'package:deun/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helper/fake_supabase.dart';

const _carol = 'carol@test.com';
final _ann = authUser('ann-id', 'ann@test.com');
final _bob = authUser('bob-id', 'bob@test.com');
final _bobRenamed = authUser('bob-id', 'bob@new.test');

GroupMember _member(String email) => GroupMember()
  ..groupId = 'g1'
  ..email = email
  ..displayName = email
  ..isGuest = false
  ..isFavorite = false;

({
  ProviderContainer container,
  StreamController<AuthState> auth,
  FakeSupabaseClient client,
})
_setUp({User? restored}) {
  final auth = StreamController<AuthState>.broadcast();
  addTearDown(auth.close);
  final client = FakeSupabaseClient(currentUser: restored);
  final container = ProviderContainer.test(
    overrides: [
      authStateChangesProvider.overrideWith((ref) => auth.stream),
      supabaseClientProvider.overrideWithValue(client),
    ],
  );
  container.listen(currentUserProvider, (_, _) {});
  return (container: container, auth: auth, client: client);
}

void main() {
  test(
    "before any auth event, the session the client restored is the current user",
    () {
      final restored = _setUp(restored: _ann);
      expect(
        restored.container.read(currentUserProvider),
        const CurrentUser(id: 'ann-id', email: 'ann@test.com'),
      );

      final none = _setUp();
      expect(none.container.read(currentUserProvider), isNull);
    },
  );

  test(
    'every fetch and write runs as the account signed in right now',
    () async {
      final s = _setUp();
      final roster = [
        _member('ann@test.com'),
        _member('bob@test.com'),
        _member('bob@new.test'),
        _member(_carol),
      ];
      final notifications = NotificationSender(push: (request) async {});

      Future<void> emit(AuthState state) async {
        s.auth.add(state);
        await pumpEventQueue();
        await s.container.pump();
      }

      /// The parameters of the one RPC [call] sends.
      Future<Map<String, dynamic>> sent(Future<void> Function() call) async {
        s.client.rpcs.clear();
        await expectLater(call(), throwsA(isA<SentRpc>()));
        return s.client.rpcs.single.params!;
      }

      Future<Map<String, dynamic>> spending() => sent(
        () => s.container
            .read(userRepositoryProvider)
            .fetchSpendingSummary(start: DateTime(2026), end: DateTime(2027)),
      );
      Future<Map<String, dynamic>> createGroup() => sent(
        () => s.container.read(groupRepositoryProvider).saveAll(null, {
          'name': 'Trip',
        }),
      );
      Future<void> payCarol() => s.container
          .read(paybackRepositoryProvider)
          .payBack(
            'g1',
            _carol,
            5,
            members: roster,
            notifications: notifications,
          );

      Future<void> expectActingAs(String email, String id) async {
        expect((await spending())['p_user_email'], email);
        final create = await createGroup();
        expect((create['_group'] as Map)['user_id'], id);
        expect(create['_members'], [
          {'email': email},
        ]);
        expect((await sent(payCarol))['_paid_by'], email);
      }

      await emit(authEvent(AuthChangeEvent.initialSession, _ann));
      await expectActingAs('ann@test.com', 'ann-id');

      await emit(authEvent(AuthChangeEvent.signedIn, _bob));
      await expectActingAs('bob@test.com', 'bob-id');

      await emit(
        authEvent(AuthChangeEvent.tokenRefreshed, _bob, token: 'refreshed'),
      );
      await expectActingAs('bob@test.com', 'bob-id');

      await emit(authEvent(AuthChangeEvent.userUpdated, _bobRenamed));
      await expectActingAs('bob@new.test', 'bob-id');

      // Signed out: nobody. A write that needs a person is refused before
      // anything is sent; the rest go out with no user.
      await emit(authEvent(AuthChangeEvent.signedOut, null));
      expect(s.container.read(currentUserProvider), isNull);
      expect((await spending())['p_user_email'], '');
      final create = await createGroup();
      expect((create['_group'] as Map)['user_id'], isNull);
      expect(create['_members'], isEmpty);
      s.client.rpcs.clear();
      await expectLater(payCarol(), throwsA(isA<PaybackRejectedException>()));
      expect(s.client.rpcs, isEmpty);
    },
  );
}
