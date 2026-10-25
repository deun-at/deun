import 'dart:async';

import 'package:deun/push_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tap on an expense notification, as FCM hands it over.
const expenseTap = RemoteMessage(data: {'type': 'expense', 'expense_id': 'e1'});

/// Push messaging with no Firebase behind it. Taps and token refreshes arrive
/// through broadcast streams, as the plugin delivers them. [holdPrepare] and
/// [holdToken] keep the permission prompt or the token fetch open until the
/// test completes them.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.canPush = true, this.initialMessage});

  final bool canPush;
  final RemoteMessage? initialMessage;
  Completer<void>? holdPrepare;
  Completer<void>? holdToken;

  // Broadcast controllers that outlive no test; nothing to flush on close.
  // ignore: close_sinks
  final taps = StreamController<RemoteMessage>.broadcast();
  // ignore: close_sinks
  final refreshes = StreamController<String>.broadcast();

  /// Whether anything still listens for taps or token refreshes.
  bool get hasListeners => taps.hasListener || refreshes.hasListener;

  @override
  Future<bool> prepare() async {
    await holdPrepare?.future;
    return canPush;
  }

  @override
  Future<String?> getToken() async {
    await holdToken?.future;
    return 'token-1';
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => taps.stream;

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
}

/// Records device_tokens writes into [log] in call order:
/// `register:<user>:<token>`, then for a removal `unregister:<user>:<token>`
/// when it starts and `unregistered:<user>:<token>` once it has finished.
class FakeDeviceTokenStore implements DeviceTokenStore {
  FakeDeviceTokenStore({List<String>? log}) : log = log ?? [];

  final List<String> log;

  /// Runs inside every removal; a throw or a future that never completes
  /// stands in for a failing or offline delete.
  Future<void> Function() whileUnregistering = () async {};

  List<String> get registers =>
      log.where((e) => e.startsWith('register:')).toList();

  List<String> get unregisters =>
      log.where((e) => e.startsWith('unregister:')).toList();

  @override
  Future<void> register({required String userId, required String token}) async {
    log.add('register:$userId:$token');
  }

  @override
  Future<void> unregister({
    required String userId,
    required String token,
  }) async {
    log.add('unregister:$userId:$token');
    await whileUnregistering();
    log.add('unregistered:$userId:$token');
  }
}

/// A container whose push session runs on [messaging] and [store], with no
/// Firebase or Supabase initialised.
ProviderContainer pushContainer(
  FakePushMessaging messaging,
  FakeDeviceTokenStore store,
) => ProviderContainer.test(
  overrides: [
    pushMessagingProvider.overrideWithValue(messaging),
    deviceTokenStoreProvider.overrideWithValue(store),
  ],
);

/// Starts [userId]'s push session; the future settles when the start has.
Future<void> startPush(
  ProviderContainer container,
  String userId,
  PushOpenHandler onOpened,
) => container
    .read(pushSessionProvider.notifier)
    .start(userId: userId, onOpened: onOpened);
