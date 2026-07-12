// Regression tests for `auth-switch-stale-providers`: after signing out (and
// signing into a different account on the same device, no restart), no
// user-scoped provider may keep the previous account's cached data.
//
// The feature centralizes the fix in [AuthUserSwitchListener], which reacts to
// Supabase auth-state changes and invalidates the user-scoped `keepAlive`
// providers. Each test below drives that listener with a controllable auth
// stream and asserts the providers refetch (build runs again) — or, for
// device-scoped preferences, that they do NOT.

import 'dart:async';

import 'package:deun/pages/friends/provider/friendship_list.dart';
import 'package:deun/pages/groups/data/group_model.dart';
import 'package:deun/pages/groups/provider/group_list.dart';
import 'package:deun/pages/users/user_model.dart';
import 'package:deun/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every (re)build of the user-scoped providers so a test can assert a
/// refetch happened (or didn't). Each notifier appends its tag at the top of
/// `build()`, before any await, so the count is observable synchronously.
class _CountingUserNotifier extends UserDetailNotifier {
  _CountingUserNotifier(this.log);
  final List<String> log;
  @override
  Future<SupaUser> build() async {
    log.add('user');
    return const SupaUser(email: 'a@test.com', displayName: 'A');
  }
}

class _CountingGroupNotifier extends GroupListNotifier {
  _CountingGroupNotifier(this.log);
  final List<String> log;
  @override
  Future<List<Group>> build() async {
    log.add('group');
    return <Group>[];
  }
}

class _CountingFriendshipNotifier extends FriendshipListNotifier {
  _CountingFriendshipNotifier(this.log);
  final List<String> log;
  @override
  Future<FriendshipListState> build() async {
    log.add('friendship');
    return const FriendshipListState();
  }
}

class _CountingThemeNotifier extends ThemeModeNotifier {
  _CountingThemeNotifier(this.log);
  final List<String> log;
  @override
  ThemeMode build() {
    log.add('theme');
    return ThemeMode.system;
  }
}

class _CountingNotificationsNotifier extends NotificationsEnabledNotifier {
  _CountingNotificationsNotifier(this.log);
  final List<String> log;
  @override
  bool build() {
    log.add('notifications');
    return true;
  }
}

int _count(List<String> log, String tag) => log.where((e) => e == tag).length;

/// A minimal [AuthState] carrying a [Session] whose user has the given [userId],
/// so the listener can distinguish accounts on a sign-in event.
AuthState _signedInAs(String userId) => AuthState(
  AuthChangeEvent.signedIn,
  Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  ),
);

/// Builds a test container wired to a controllable auth stream, with all
/// user-scoped and device-scoped providers replaced by counting fakes.
ProviderContainer _container(
  StreamController<AuthState> controller,
  List<String> log,
) {
  return ProviderContainer.test(
    overrides: [
      authStateChangesProvider.overrideWith((ref) => controller.stream),
      userDetailProvider.overrideWith(() => _CountingUserNotifier(log)),
      groupListProvider.overrideWith(() => _CountingGroupNotifier(log)),
      friendshipListProvider.overrideWith(
        () => _CountingFriendshipNotifier(log),
      ),
      themeModeProvider.overrideWith(() => _CountingThemeNotifier(log)),
      notificationsEnabledProvider.overrideWith(
        () => _CountingNotificationsNotifier(log),
      ),
    ],
  );
}

/// Mounts (and keeps alive) the central listener plus every provider under test.
void _mountAll(ProviderContainer container) {
  container.listen(authUserSwitchListenerProvider, (_, _) {});
  container.listen(userDetailProvider, (_, _) {}, onError: (_, _) {});
  container.listen(groupListProvider, (_, _) {}, onError: (_, _) {});
  container.listen(friendshipListProvider, (_, _) {}, onError: (_, _) {});
  container.listen(themeModeProvider, (_, _) {});
  container.listen(notificationsEnabledProvider, (_, _) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Stub the shared_preferences channel so Supabase auth storage init does not
    // throw, then initialize Supabase so the listener's build() can read
    // `supabase.auth.currentUser` (null session in tests). No network is used.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            if (call.method == 'getAll') return <String, Object>{};
            return null;
          },
        );
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  test(
    'signedOut invalidates the user-scoped providers (user detail, group list, '
    'friendship list) so they refetch',
    () async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      final log = <String>[];
      final container = _container(controller, log);

      _mountAll(container);
      await container.pump();

      // Each provider built exactly once on mount.
      expect(_count(log, 'user'), 1);
      expect(_count(log, 'group'), 1);
      expect(_count(log, 'friendship'), 1);

      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      await container.pump();

      // The central listener invalidated all three → each rebuilt (refetched).
      expect(
        _count(log, 'user'),
        2,
        reason: 'greeting name + settings profile source',
      );
      expect(_count(log, 'group'), 2, reason: 'overall balance hero source');
      expect(_count(log, 'friendship'), 2);
    },
  );

  test(
    'signedOut leaves device-scoped preference providers untouched',
    () async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      final log = <String>[];
      final container = _container(controller, log);

      _mountAll(container);
      await container.pump();

      expect(_count(log, 'theme'), 1);
      expect(_count(log, 'notifications'), 1);

      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      await container.pump();

      // Theme mode + notifications toggle are device-scoped; a user switch must
      // not rebuild them.
      expect(_count(log, 'theme'), 1);
      expect(_count(log, 'notifications'), 1);
    },
  );

  test(
    'signedIn as a DIFFERENT user invalidates; the same user does not',
    () async {
      final controller = StreamController<AuthState>.broadcast();
      addTearDown(controller.close);
      final log = <String>[];
      final container = _container(controller, log);

      _mountAll(container);
      await container.pump();

      expect(_count(log, 'user'), 1);

      // First sign-in establishes the active user; nothing stale to clear yet.
      controller.add(_signedInAs('userA'));
      await pumpEventQueue();
      await container.pump();
      expect(
        _count(log, 'user'),
        1,
        reason: 'first sign-in: no prior user to invalidate',
      );

      // Re-emit for the SAME user (e.g. token refresh) → no needless refetch.
      controller.add(_signedInAs('userA'));
      await pumpEventQueue();
      await container.pump();
      expect(
        _count(log, 'user'),
        1,
        reason: 'same-user re-emit must not refetch',
      );

      // Sign-in as a genuinely different account → invalidate.
      controller.add(_signedInAs('userB'));
      await pumpEventQueue();
      await container.pump();
      expect(_count(log, 'user'), 2, reason: 'account switch must refetch');
      expect(_count(log, 'group'), 2);
      expect(_count(log, 'friendship'), 2);
    },
  );
}
