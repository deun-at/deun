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

status: planned
