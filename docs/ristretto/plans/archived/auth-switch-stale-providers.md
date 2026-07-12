# auth-switch-stale-providers — Invalidate user-scoped providers on user switch

## Spec
- Source: idea (bug report, 2026-07-12 planning session)
- Flight: —
- Goal: After signing out and into a different account on the same device, no screen shows the previous user's data.
- Acceptance:
  - Signing out and signing in as another account (no app restart) shows the new user's greeting name, overall balance hero, and settings profile — verified by a regression test that invalidates via the central listener and asserts the user-scoped providers refetch.
  - The invalidation lives in one central place reacting to Supabase auth-state changes (signedOut, and signedIn when the user differs), not sprinkled at each sign-out call site.
  - All user-scoped `keepAlive` providers are covered — at minimum the user detail, group list, and friendship list notifiers; any other keepAlive provider holding per-user state found during implementation joins the list.
  - Preference-style keepAlive providers that are device-scoped, not user-scoped (theme mode, notifications toggle), are left untouched by the switch.
  - `flutter analyze` and `flutter test` pass.
## Approach
- Root cause (verified 2026-07-12): `UserDetailNotifier`, `GroupListNotifier`, and `FriendshipListNotifier` are `keepAlive: true` and build once with the then-current auth user; the sign-out paths only call `supabase.auth.signOut()`, so the cached state survives into the next session. Non-keepAlive providers dispose naturally when the login screen replaces the tree.
- Add one auth-state listener (e.g. where the app has ProviderScope access at startup, or a small bootstrap provider) that invalidates the user-scoped providers on sign-out/user-change. Prefer invalidate-on-signedOut so the next session always builds fresh.
- Likely touchpoints: lib/provider.dart, lib/auth_gate.dart or lib/main.dart (wherever the listener can reach a ref), lib/pages/groups/provider/, lib/pages/friends/provider/.
- Decisions / tradeoffs: central listener over per-call-site `ref.invalidate` — sign-out surfaces multiply (settings sheet, settings page, future account deletion) and each new one would silently reintroduce the bug.
- Depends: —
- Parallel-with: —
- Blockers: —

status: done

## Evidence

Implemented a single central listener, `AuthUserSwitchListener` (keepAlive), in
`lib/provider.dart`. It watches Supabase auth-state changes via a new
`authStateChangesProvider` (a `Stream<AuthState>` provider isolated so tests can
drive it) and, on `signedOut` (always) and `signedIn` when the user id differs,
calls the single choke-point `invalidateUserScopedProviders(ref)` which
invalidates `userDetailProvider`, `groupListProvider`, and
`friendshipListProvider`. The listener is mounted once at the app root via a
`Consumer` wrapper in `lib/main.dart` (`ref.watch(authUserSwitchListenerProvider)`).

Criterion-by-criterion (regression tests in
`test/provider/auth_switch_invalidation_test.dart`, all driving the real
`AuthUserSwitchListener` through a controllable auth stream):

- "Signing out (then in as another account) shows the new user's greeting name,
  overall balance hero, settings profile — verified by a regression test that
  invalidates via the central listener and asserts the user-scoped providers
  refetch": test `signedOut invalidates the user-scoped providers ...` asserts
  `userDetail` (greeting name + settings profile source), `groupList` (overall
  balance hero source), and `friendship` each rebuild (build count 1 → 2) after a
  `signedOut` event. Test `signedIn as a DIFFERENT user invalidates; the same
  user does not` covers the sign-in-as-another-account path (build count → 2).
- "Invalidation lives in one central place reacting to auth-state changes
  (signedOut, and signedIn when the user differs)": all invalidation flows
  through `invalidateUserScopedProviders`, exercised only via the listener's
  reaction to stream events; the differ/same-user branch is proven by the third
  test (same-user re-emit stays at build count 1; different user → 2).
- "All user-scoped keepAlive providers covered (user detail, group list,
  friendship list)": audited every `@Riverpod(keepAlive: true)` — the three
  user-scoped ones are invalidated; `RealtimeConnectionStatus` is
  connection-health (device/global), not per-user, so excluded.
- "Preference-style device-scoped keepAlive providers (theme mode, notifications)
  left untouched": test `signedOut leaves device-scoped preference providers
  untouched` asserts `themeMode` and `notifications` build counts stay at 1
  across a `signedOut` event.
- "`flutter analyze` and `flutter test` pass": see gate summary.

Gate summary (`.ristretto.json`, Flutter SDK at `C:\Users\ASUS\flutter\bin`):
- format: `dart format` on the 3 touched Dart files — 0 changed (already formatted).
- lint: `flutter analyze` — "No issues found!".
- test: `flutter test` — all 879 tests passed (3 new in
  `test/provider/auth_switch_invalidation_test.dart`).
