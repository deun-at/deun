import 'package:deun/main.dart';
import 'package:deun/push_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sign_out.g.dart';

/// Signs out of the app: removes this device's push token while the session
/// can still delete it (device_tokens is owner-only), then ends the auth
/// session. A failed or slow removal never blocks sign-out: it is logged and
/// cut off after [tokenRemovalTimeout]. Invalidates nothing — the
/// AuthUserSwitchListener reacts to the signedOut event.
Future<void> signOutUser({
  required PushSession push,
  required Future<void> Function() authSignOut,
  Duration tokenRemovalTimeout = const Duration(seconds: 3),
}) async {
  try {
    await push.end().timeout(tokenRemovalTimeout);
  } catch (e) {
    debugPrint('Removing the device token failed: $e');
  }
  await authSignOut();
}

/// The one sign-out every surface calls.
typedef AppSignOut = Future<void> Function();

@Riverpod(keepAlive: true)
AppSignOut appSignOut(Ref ref) =>
    () => signOutUser(
      push: ref.read(pushSessionProvider.notifier),
      authSignOut: () => supabase.auth.signOut(),
    );
