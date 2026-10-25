import 'dart:async';
import 'dart:io' show Platform;

import 'package:deun/constants.dart';
import 'package:deun/helper/helper.dart';
import 'package:deun/main.dart';
import 'package:deun/pages/expenses/data/expense_repository.dart';
import 'package:deun/pages/groups/data/group_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'push_notifications.g.dart';

/// The push messaging platform: Firebase in the app, a fake in tests.
abstract interface class PushMessaging {
  /// Asks for notification permission and reports whether pushes can work on
  /// this device: false when permission is denied, on web, or when iOS has no
  /// APNS token.
  Future<bool> prepare();

  Future<String?> getToken();

  /// The notification that opened the app from a terminated state, if any.
  Future<RemoteMessage?> getInitialMessage();

  Stream<RemoteMessage> get onMessageOpenedApp;

  Stream<String> get onTokenRefresh;
}

/// [PushMessaging] over FirebaseMessaging.
class FirebasePushMessaging implements PushMessaging {
  const FirebasePushMessaging();

  @override
  Future<bool> prepare() async {
    // You may set the permission requests to "provisional" which allows the user to choose what type
    // of notifications they would like to receive once the user receives a notification.
    final notificationSettings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.denied) {
      return false;
    }
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      // For apple platforms, ensure the APNS token is available before making
      // any FCM plugin API calls.
      return await FirebaseMessaging.instance.getAPNSToken() != null;
    }
    return true;
  }

  @override
  Future<String?> getToken() async {
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kFcmVapidKey,
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return token;
  }

  @override
  Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;
}

/// Where this device's push tokens are stored for each user.
abstract interface class DeviceTokenStore {
  Future<void> register({required String userId, required String token});

  Future<void> unregister({required String userId, required String token});
}

/// [DeviceTokenStore] over the `device_tokens` table (PK `(user_id, token)`,
/// owner-only RLS since the 2026-10-25 stopgap).
class SupabaseDeviceTokenStore implements DeviceTokenStore {
  const SupabaseDeviceTokenStore();

  @override
  Future<void> register({required String userId, required String token}) async {
    await supabase.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
    });
  }

  @override
  Future<void> unregister({
    required String userId,
    required String token,
  }) async {
    await supabase
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }
}

@Riverpod(keepAlive: true)
PushMessaging pushMessaging(Ref ref) => const FirebasePushMessaging();

@Riverpod(keepAlive: true)
DeviceTokenStore deviceTokenStore(Ref ref) => const SupabaseDeviceTokenStore();

/// Where a tapped notification leads, read from its data keys.
sealed class PushTarget {
  const PushTarget();
}

class PushGroupTarget extends PushTarget {
  const PushGroupTarget(this.groupId);
  final String groupId;
}

class PushExpenseTarget extends PushTarget {
  const PushExpenseTarget(this.expenseId);
  final String expenseId;
}

class PushFriendsTarget extends PushTarget {
  const PushFriendsTarget();
}

/// The target of a notification's [data]. For type 'group' the group id
/// travels in `expense_id`; any other or missing type, 'reminder' included,
/// targets nothing.
PushTarget? pushTargetFor(Map<String, dynamic> data) =>
    switch ((data['type'], data['expense_id'])) {
      ('group', final String id) => PushGroupTarget(id),
      ('expense', final String id) => PushExpenseTarget(id),
      ('friendship', _) => const PushFriendsTarget(),
      _ => null,
    };

/// Opens [message]'s target from the root navigator. Logs failures and never
/// throws.
Future<void> openPushMessage(
  RemoteMessage message,
  GlobalKey<NavigatorState> rootNavigatorKey,
) async {
  try {
    switch (pushTargetFor(message.data)) {
      case PushGroupTarget(:final groupId):
        final group = await GroupRepository.fetchDetail(groupId);
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        navigateToGroup(context, group);
      case PushExpenseTarget(:final expenseId):
        final expense = await ExpenseRepository.fetchDetail(expenseId);
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        navigateToExpense(context, expense);
      case PushFriendsTarget():
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) return;
        navigateToFriends(context);
      case null:
        break;
    }
  } catch (e) {
    debugPrint('Failed to handle push notification navigation: $e');
  }
}

/// Opens a tapped notification's target.
typedef PushOpenHandler = Future<void> Function(RemoteMessage message);

/// Lets the notification that cold-started the app open once per app process.
/// It lives outside [PushSession] because the session is rebuilt after every
/// sign-out, while the plugin may hand the same initial message back each time.
class InitialMessageLatch {
  bool _taken = false;

  /// True the first time only.
  bool take() {
    final first = !_taken;
    _taken = true;
    return first;
  }
}

@Riverpod(keepAlive: true)
InitialMessageLatch initialMessageLatch(Ref ref) => InitialMessageLatch();

/// One signed-in user's registration: the token it registered or refreshed
/// to, and its two listeners.
class _Session {
  _Session(this.userId, this.generation);

  final String userId;
  final int generation;
  String? token;
  StreamSubscription<RemoteMessage>? opened;
  StreamSubscription<String>? refreshed;

  /// Every device_tokens write this session made, chained in order, so
  /// [PushSession.end] removes the token only after the last write landed.
  Future<void> writes = Future<void>.value();

  void cancel() {
    unawaited(opened?.cancel());
    unawaited(refreshed?.cancel());
  }
}

/// Owns FCM permission, this device's token registration and the
/// notification-tap, token-refresh and cold-start handling for the signed-in
/// user. Exactly one listener of each kind exists at any time.
///
/// User-scoped: [invalidateUserScopedProviders] disposes it on every
/// sign-out, including one the app did not start, and disposal cancels the
/// listeners. It takes its messaging and store once in [build] and never
/// touches `ref` after an await.
@Riverpod(keepAlive: true)
class PushSession extends _$PushSession {
  late PushMessaging _messaging;
  late DeviceTokenStore _store;
  late InitialMessageLatch _initialMessage;
  _Session? _current;
  Future<void>? _ending;

  /// Bumped by every start, end and dispose; a start whose session no longer
  /// carries the current generation registers and subscribes nothing more.
  int _generation = 0;

  /// The token the running session registered or last refreshed to.
  String? get registeredToken => _current?.token;

  @override
  void build() {
    _messaging = ref.read(pushMessagingProvider);
    _store = ref.read(deviceTokenStoreProvider);
    _initialMessage = ref.read(initialMessageLatchProvider);
    _current = null;
    _ending = null;
    ref.onDispose(() => _detach());
  }

  bool _isCurrent(_Session session) => session.generation == _generation;

  /// Stops the running session's listeners and makes any start still in
  /// flight stale. Returns that session.
  _Session? _detach() {
    final session = _current;
    _current = null;
    _generation++;
    session?.cancel();
    return session;
  }

  /// Registers this device for [userId] and starts listening. Does nothing
  /// when a session already runs for [userId]; a session for another user is
  /// replaced.
  Future<void> start({
    required String userId,
    required PushOpenHandler onOpened,
  }) {
    final running = _current;
    if (running != null && running.userId == userId) return running.writes;
    _detach();
    final session = _Session(userId, ++_generation);
    _current = session;
    return session.writes = _run(session, onOpened);
  }

  Future<void> _run(_Session session, PushOpenHandler onOpened) async {
    try {
      final canPush = await _messaging.prepare();
      if (!canPush || !_isCurrent(session)) return;
      final token = await _messaging.getToken();
      if (!_isCurrent(session)) return;
      if (token != null) {
        session.token = token;
        await _register(session.userId, token);
        if (!_isCurrent(session)) return;
      }
      session.opened = _messaging.onMessageOpenedApp.listen(
        (message) => unawaited(onOpened(message)),
      );
      session.refreshed = _messaging.onTokenRefresh.listen(
        (token) => session.writes = session.writes.then(
          (_) => _refresh(session, token),
        ),
        onError: (Object e) => debugPrint('FCM token refresh failed: $e'),
      );
      if (!_initialMessage.take()) return;
      final initial = await _messaging.getInitialMessage();
      if (initial != null && _isCurrent(session)) {
        unawaited(onOpened(initial));
      }
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _refresh(_Session session, String token) async {
    if (!_isCurrent(session)) return;
    session.token = token;
    await _register(session.userId, token);
  }

  Future<void> _register(String userId, String token) async {
    try {
      await _store.register(userId: userId, token: token);
    } catch (e) {
      debugPrint('Device token upsert failed: $e');
    }
  }

  /// Stops listening and removes the token this session registered. A second
  /// call while one runs awaits the same removal; a later call does nothing.
  /// A start still in flight is let settle first, so its write cannot land
  /// after the delete.
  Future<void> end() {
    final session = _detach();
    if (session == null) return _ending ?? Future<void>.value();
    return _ending = _remove(session);
  }

  Future<void> _remove(_Session session) async {
    await session.writes;
    final token = session.token;
    if (token == null) return;
    await _store.unregister(userId: session.userId, token: token);
  }
}
