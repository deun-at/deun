import 'dart:async';

import 'package:deun/pages/auth/sign_out.dart';
import 'package:deun/push_notifications.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helper/fake_push.dart';

void main() {
  test("sign-out deletes this device's token for the signed-in user, and the "
      'delete finishes before the auth session ends', () async {
    final log = <String>[];
    final store = FakeDeviceTokenStore(log: log)
      ..whileUnregistering = () => Future<void>.delayed(Duration.zero);
    final container = pushContainer(FakePushMessaging(), store);
    await startPush(container, 'userA', (_) async {});

    await signOutUser(
      push: container.read(pushSessionProvider.notifier),
      authSignOut: () async => log.add('authSignOut'),
    );

    expect(log, [
      'register:userA:token-1',
      'unregister:userA:token-1',
      'unregistered:userA:token-1',
      'authSignOut',
    ]);
  });

  test('a throwing token removal still ends the auth session and raises '
      'nothing', () async {
    final store = FakeDeviceTokenStore()
      ..whileUnregistering = () async => throw StateError('offline');
    final container = pushContainer(FakePushMessaging(), store);
    await startPush(container, 'userA', (_) async {});
    var signedOut = false;

    await expectLater(
      signOutUser(
        push: container.read(pushSessionProvider.notifier),
        authSignOut: () async => signedOut = true,
      ),
      completes,
    );
    expect(signedOut, isTrue);
  });

  test('a token removal that never completes still ends the auth session '
      'within 3 s', () {
    fakeAsync((async) {
      final store = FakeDeviceTokenStore()
        ..whileUnregistering = () => Completer<void>().future;
      final container = pushContainer(FakePushMessaging(), store);
      startPush(container, 'userA', (_) async {});
      async.flushMicrotasks();
      var signedOut = false;
      var finished = false;

      signOutUser(
        push: container.read(pushSessionProvider.notifier),
        authSignOut: () async => signedOut = true,
      ).then((_) => finished = true);
      async.elapse(const Duration(seconds: 3));

      expect(signedOut, isTrue);
      expect(finished, isTrue, reason: 'and without an error');
    });
  });

  test('where pushes cannot work, a session registers and subscribes nothing, '
      'and sign-out attempts no delete and raises nothing', () async {
    final messaging = FakePushMessaging(canPush: false);
    final store = FakeDeviceTokenStore();
    final container = pushContainer(messaging, store);

    await startPush(container, 'userA', (_) async {});
    expect(messaging.hasListeners, isFalse);

    var signedOut = false;
    await expectLater(
      signOutUser(
        push: container.read(pushSessionProvider.notifier),
        authSignOut: () async => signedOut = true,
      ),
      completes,
    );
    expect(store.log, isEmpty);
    expect(signedOut, isTrue);
  });
}
