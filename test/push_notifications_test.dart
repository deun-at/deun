// push-session-lifecycle: the push session's start/end lifecycle, driven through
// fake messaging (broadcast streams) and a recording token store; no Firebase or
// Supabase init.

import 'dart:async';

import 'package:deun/pages/auth/sign_out.dart';
import 'package:deun/push_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper/fake_push.dart';

/// Signs out through the app's sign-out, with the auth side faked.
Future<void> _signOut(ProviderContainer container) => signOutUser(
  push: container.read(pushSessionProvider.notifier),
  authSignOut: () async {},
);

void main() {
  test('notification routing by data keys is unchanged', () {
    expect(
      pushTargetFor({'type': 'group', 'expense_id': 'g1'}),
      isA<PushGroupTarget>().having((t) => t.groupId, 'groupId', 'g1'),
      reason: "a group push carries the group id in 'expense_id'",
    );
    expect(
      pushTargetFor({'type': 'expense', 'expense_id': 'e1'}),
      isA<PushExpenseTarget>().having((t) => t.expenseId, 'expenseId', 'e1'),
    );
    expect(pushTargetFor({'type': 'friendship'}), isA<PushFriendsTarget>());
    for (final data in <Map<String, dynamic>>[
      {'type': 'reminder', 'expense_id': 'e1'},
      {'type': 'something-new', 'expense_id': 'e1'},
      {'expense_id': 'e1'},
      {},
    ]) {
      expect(pushTargetFor(data), isNull, reason: '$data targets nothing');
    }
  });

  group('one tap opens once and one refresh registers once, however often '
      'the session restarted', () {
    late FakePushMessaging messaging;
    late FakeDeviceTokenStore store;
    late ProviderContainer container;
    late List<RemoteMessage> opened;

    Future<void> onOpened(RemoteMessage message) async => opened.add(message);

    setUp(() {
      messaging = FakePushMessaging();
      store = FakeDeviceTokenStore();
      container = pushContainer(messaging, store);
      opened = [];
    });

    Future<void> tapAndRefresh({required String userId}) async {
      final registersBefore = store.registers.length;
      messaging.taps.add(expenseTap);
      messaging.refreshes.add('token-2');
      await pumpEventQueue();
      expect(opened, [expenseTap], reason: 'one tap opens its target once');
      expect(
        store.registers.skip(registersBefore).toList(),
        ['register:$userId:token-2'],
        reason: 'one refresh registers once, for the session user',
      );
    }

    test('after sign-out then sign-in', () async {
      await startPush(container, 'userA', onOpened);
      await _signOut(container);
      // What the signedOut event does through invalidateUserScopedProviders.
      container.invalidate(pushSessionProvider);
      await startPush(container, 'userA', onOpened);
      await tapAndRefresh(userId: 'userA');
    });

    test(
      'after the main screen starts the session again for the same user',
      () async {
        await startPush(container, 'userA', onOpened);
        await startPush(container, 'userA', onOpened);
        await tapAndRefresh(userId: 'userA');
      },
    );

    test(
      "after a different user's session starts with no sign-out between",
      () async {
        await startPush(container, 'userA', onOpened);
        await startPush(container, 'userB', onOpened);
        await tapAndRefresh(userId: 'userB');
      },
    );
  });

  test('after the app signs out, a tap opens nothing and a refresh registers '
      'nothing', () async {
    final messaging = FakePushMessaging();
    final store = FakeDeviceTokenStore();
    final container = pushContainer(messaging, store);
    final opened = <RemoteMessage>[];
    await startPush(container, 'userA', (m) async => opened.add(m));

    await _signOut(container);
    messaging.taps.add(expenseTap);
    messaging.refreshes.add('token-2');
    await pumpEventQueue();

    expect(opened, isEmpty);
    expect(store.registers, ['register:userA:token-1']);
  });

  test('a session registers its token once; a refresh registers the new one '
      'for the same user; sign-out removes the refreshed one', () async {
    final messaging = FakePushMessaging();
    final store = FakeDeviceTokenStore();
    final container = pushContainer(messaging, store);

    await startPush(container, 'userA', (_) async {});
    expect(store.registers, ['register:userA:token-1']);

    messaging.refreshes.add('token-2');
    await pumpEventQueue();
    expect(store.registers, [
      'register:userA:token-1',
      'register:userA:token-2',
    ]);
    expect(
      container.read(pushSessionProvider.notifier).registeredToken,
      'token-2',
    );

    await _signOut(container);
    expect(
      store.unregisters,
      ['unregister:userA:token-2'],
      reason: 'the replaced token-1 is not the one this device now holds',
    );
  });

  for (final stall in ['permission prompt', 'token fetch']) {
    test('signing out during the $stall leaves no token registered and no '
        'listener once the start finishes', () async {
      final messaging = FakePushMessaging();
      final hold = Completer<void>();
      if (stall == 'permission prompt') {
        messaging.holdPrepare = hold;
      } else {
        messaging.holdToken = hold;
      }
      final store = FakeDeviceTokenStore();
      final container = pushContainer(messaging, store);

      final starting = startPush(container, 'userA', (_) async {});
      await pumpEventQueue();
      final signingOut = _signOut(container);
      hold.complete();
      await starting;
      await signingOut;

      expect(store.log, isEmpty);
      expect(messaging.hasListeners, isFalse);
    });
  }

  test('a cold-start notification opens once per launch, not again after '
      'sign-out and sign-in', () async {
    final messaging = FakePushMessaging(initialMessage: expenseTap);
    final container = pushContainer(messaging, FakeDeviceTokenStore());
    final opened = <RemoteMessage>[];
    Future<void> onOpened(RemoteMessage message) async => opened.add(message);

    await startPush(container, 'userA', onOpened);
    await pumpEventQueue();
    expect(opened, [expenseTap]);

    await _signOut(container);
    container.invalidate(pushSessionProvider);
    await startPush(container, 'userA', onOpened);
    await pumpEventQueue();
    expect(opened, [
      expenseTap,
    ], reason: 'the fake hands the same initial message back on every call');
  });
}
