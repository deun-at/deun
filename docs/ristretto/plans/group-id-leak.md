# group-id-leak

## Spec
- Source: idea — rls-hardening Open findings (security, LIVE), confirmed in review 2026-10-26; research/group-id-leak.md
- Goal: a group id on its own no longer lets anyone join a group or see its guests; joining needs the group's current invite token.
- Why: members of every group · noticed by: a stranger who knows only a group id cannot become a member, so no unknown name appears in a group's member list

## Contract
- Acceptance:
  - [auto] A signed-in user who is not a member and calls `join_group` with a group id and no token, a wrong token or a token from before a reset is refused, and no `group_member` row is written. Proof: local RLS harness (supabase/tests/rls_stopgap), new cases; the existing case "stranger joins G1 by id (invite model)" in 30_cases.sql flips from ok:1 to err.
  - [auto] The same user inserting their own `group_member` row directly (the released builds' client-side join) is refused for a group they are not in and did not create. Proof: local RLS harness.
  - [auto] With the group's current token, `join_group` still works for every path guest-merge-rpc proved: join as new, join by claiming a guest, the colliding-share rollback, the guest checks (40_join_group_cases.sql cases updated to pass the token, all green).
  - [auto] Creating a group still writes the creator's own row (save_group_all), and a member adding someone (add_group_member, legacy add path) still works. Proof: existing harness suites 30/40/50/60/70 green with the migration applied.
  - [auto] `group_join_guests` without a valid token returns no rows; with the current token it returns the group's active guests as before. Proof: local RLS harness.
  - [auto] An active member resetting the invite link gets a new token; the old token is refused from then on; a non-member cannot reset. Proof: local RLS harness.
  - [auto] The invite link (link text, QR, share sheet) carries the group's current token, and after a reset it carries the new one. Proof: widget test on the invite page.
  - [auto] Opening a join link with a missing, malformed or rejected token shows the "invite no longer valid — ask a member for a new link" state (en and de) and lists no guests and offers no join button; a link with a valid token opens the join page as today. Proof: widget tests on the join page; deep-link allowlist test for the token parameter.
  - [auto] Reset asks for confirmation first; Cancel changes nothing, Reset shows the new link. Proof: widget test on the invite page.
  - [auto] Every new or replaced function revokes execute from public and anon itself (rls-hardening's forward test, test/pages/groups/rls_hardening_migration_test.dart, must stay green), and every SECURITY DEFINER function pins `search_path` and takes the caller from the JWT.
  - [auto] Gates: `flutter analyze` clean, `flutter test` green.
- Provides:
  - `public."group".invite_token uuid not null` (default a fresh random uuid; existing groups get one in the migration)
  - `public.group_invite_valid(_group_id uuid, _token uuid) returns boolean` — SECURITY DEFINER, `search_path = ''`; the one place a token is compared; `join_group`, `group_join_guests` and the client's `fetchJoinState` all use it; returns a boolean, never a token
  - `public.join_group(_group_id uuid, _token uuid, _guest_email text default null) returns void` — SECURITY DEFINER; a rejected token raises SQLSTATE `DE401`; the token-less signature is dropped
  - `public.group_join_guests(_group_id uuid, _token uuid) returns table (email text, display_name text)` — SECURITY DEFINER; the token-less signature is dropped
  - `public.reset_group_invite(_group_id uuid) returns uuid` — SECURITY INVOKER, active members only (42501 otherwise); returns the new token and bumps `group_update_checker`
  - `public.update_group_member_shares(uuid, uuid)` now pins `search_path = public, pg_temp`
  - `MemberRepository.joinGroup(String groupId, {required String token, String? guestEmail}): Future<void>` (maps `DE401` to `InviteRejected`), `MemberRepository.fetchJoinState(String groupId, {required String token}): Future<GroupJoinState>` (throws `InviteRejected` before listing anything), `GroupRepository.resetInviteToken(String groupId): Future<String>`
  - `InviteRejected` (lib/pages/groups/data/member_removal.dart) — the typed "token not current" failure
  - `AppPaths.groupJoin(String groupId, {required String token, String? name})` — the join location carries `token`
- Consumes: — (guest-merge-rpc and rls-hardening are done; this feature edits their surfaces in place)
- Decisions:
  - Why → members of every group (Jakob in prep group-id-leak, 2026-10-26)
  - Fix → (a) invite token: joining needs a per-group token checked server-side, and group_member's self-insert branch is dropped, so a group id alone is useless. Ids keep leaking through realtime but become harmless. Option (b) (unpublish expense_update_checker) is rejected because it kills the live expense list; option (c) (surrogate PK on expense_update_checker so deletes carry only expense_id) is out of scope here and may follow as hardening (Jakob in prep group-id-leak, 2026-10-26; research/group-id-leak.md Open)
  - Old links and old builds → hard-fail. A link without a valid token cannot join, and released builds' client-side `insert into group_member` is refused once the migration is applied. The join page tells the user the invite is no longer valid and to ask a member for a new link. No grandfathering, no per-group switch (Jakob in prep group-id-leak, 2026-10-26)
  - Who may reset the invite link → any active member, from the invite page. A reset issues a new token and every earlier link for that group stops working (Jakob in prep group-id-leak, 2026-10-26)
  - group_join_guests → requires the token too. Without a valid token it returns nothing, so a leaked id reveals no guest names; the join page shows the invalid-invite message before listing anything (Jakob in prep group-id-leak, 2026-10-26)
  - Reset UX → a confirm dialog ("Reset invite link? Links you already shared will stop working." · Cancel / Reset); the new link shows right after (Jakob in prep group-id-leak, 2026-10-26)
  - Where the token lives → a column on `public."group"`. The group SELECT policy already limits reads to members and the creator, who are exactly the people allowed to share it. No separate table.
  - INSERT policy on group_member → keep the "by member" and "creator of the group" branches, drop only the `email = own` branch. Group creation (save_group_all, creator branch) and member adds (by-member branch) are unaffected. The policy is replaced in this feature's migration, not by editing the applied stopgap file.
  - join_group's security mode → SECURITY DEFINER (guest-merge-rpc left "Jakob decides on SECURITY DEFINER" open; with the self-insert branch gone the joiner's own-row insert cannot pass RLS as the caller). It pins `search_path = ''`, refuses a session with no JWT email, checks the token against the group row before any read or write, scopes every statement to `_group_id`, keeps the per-group `lock_group_member_writes` lock, and is granted to authenticated only.
  - Token comparison → server-side only. The client never receives a group's token except by reading its own group row as a member, or from the link it was given; no RPC returns a token to a non-member.
  - Migration order → this migration replaces functions from 20261026100000 (unapplied), so it is applied after it and before 20261026160000 (rls-hardening), or rls-hardening is re-run afterwards (it is idempotent). The manual-checks apply entry says so.
  - Tests that pin the old rule → the harness case at 30_cases.sql:92 flips to "refused"; rls_hardening_migration_test.dart's C6 and its statement→policy row for `rpc:join_group` are updated to the new policy and signatures; test/widgets/group_invite_page_test.dart and test/deep_links_test.dart are updated for the token parameter. These are deliberate rule changes, not weakenings.
  - Realtime → unchanged. expense_update_checker stays published and its deletes still carry `{expense_id, group_id}`; after this feature that id grants nothing (stays context: domain/supabase-realtime.md: postgres_changes DELETE payload under RLS). The group_member publication in 20261025200000 remains "do not apply yet" (it leaks emails, a separate finding).
  - Out of scope, recorded → a soft-removed member still passes `is_group_member` (it ignores `removed_at`) and can clear their own `removed_at`; that is the existing soft-removal model, not this leak.
  - taken: an invite link with a missing, malformed or reset token → shows "This invite link is no longer valid. Ask a member of the group for a new link." / "Dieser Einladungslink ist nicht mehr gültig. Bitte ein Mitglied der Gruppe um einen neuen Link." to everyone, including a current member; the straight-to-the-group redirect runs only after the token is accepted
  - taken: the token is reset while the join page is open → tapping Continue switches the page to that same "no longer valid" state, not the general error
  - taken: a link with a malformed token → still opens the join page and shows it as no longer valid; the deep-link allowlist does not silently drop it
  - taken: the reset confirmation → reuses the app's existing confirm sheet (link-off badge, "Reset invite link?" / "Links you already shared will stop working.", Reset / Cancel) instead of a new dialog; "Reset link" sits beside the QR toggle on the invite sheet
  - taken: a reset → bumps the group's `group_update_checker`, so other members' open group screens refetch the group and share the new link
- Units:
  - Migration: `invite_token` column with backfill, replaced group_member INSERT policy, `join_group` and `group_join_guests` with token (old signatures dropped), `reset_group_invite`, grants/revokes
  - Harness: flip 30_cases.sql:92, add token cases (wrong/old/missing token, reset, non-member reset, direct self-insert refused, guests without token), update 40_join_group_cases.sql to pass tokens
  - Client data: repositories pass the token to `join_group` / `group_join_guests`; reset call; `AppPaths.groupJoin` and the deep-link allowlist accept a uuid `token`
  - Invite page: link carries the token; "Reset link" with confirm dialog; new en/de strings
  - Join page: invalid-invite state (en/de) for missing/malformed/rejected tokens, before any guest list; manual-checks apply entry
- Blockers: —

## Approach
- One migration does the server half: add the column (backfilled), swap the INSERT policy, replace the two join functions with token-taking versions and drop the old signatures, add the reset function. join_group becomes a definer function that checks the token first and then runs guest-merge-rpc's existing logic unchanged. Prove it all on the local Docker harness (supabase/tests/rls_stopgap/README.md) before touching the client — never against the live instance.
- The client threads the token from the link through the router to the join page and the repositories, and the invite page reads the token from the member's own group row. A rejected token surfaces as a specific error the join page maps to the invalid-invite state; every other failure keeps today's general error.
- Likely touchpoints: supabase/migrations/ (new file), supabase/tests/rls_stopgap/30_cases.sql, 40_join_group_cases.sql, a new cases file, lib/pages/groups/data/member_repository.dart, group_repository.dart, lib/pages/groups/presentation/group_invite_page.dart, group_join_page.dart, lib/app_paths.dart, lib/app_router.dart, lib/deep_links.dart, lib/l10n/app_en.arb, app_de.arb, test/widgets/group_invite_page_test.dart, test/pages/groups/group_join_page_test.dart, test/deep_links_test.dart, test/pages/groups/rls_hardening_migration_test.dart, test/pages/groups/join_group_migration_test.dart, docs/ristretto/manual-checks.md
- Depends: guest-merge-rpc, rls-hardening
- Parallel-with: —

## Evidence
- 1: harness 80_group_invite_token_cases.sql (no token, another group's token, a token retired by a reset: refused, no row written) and 30_cases.sql 'stranger joins G1 by id' flipped to err; local harness only, never live.
- 2: 30_cases.sql direct own-row insert cases (:92, :68, :76) now err (72/75 before, 75/75 after); rls_hardening_migration_test C6 pins the replaced policy.
- 3: 40_join_group_cases.sql passes the token, 14/14 (join as new, claim, colliding-share rollback, guest checks).
- 4: harness 30 75/75, 50 4/4, 60 21/21, 70 21/21 with the migration applied; C8 statement-to-policy table green.
- 5: 80 'join guests without a valid token list nothing'; 40 'outsider sees exactly the active guests' with the token.
- 6: 80 'reset by a member', 'a non-member cannot reset', 'reset_group_invite refuses a soft-removed member' (80 9/9).
- 7: group_invite_page_test (copy carries the token; 'reopening the sheet from a stale group snapshot shows the reset token'; 'after a reset here, a later reset elsewhere shows once the group reloads'), app_router_test, deep_links_test token entry.
- 8: group_join_page_test (missing and malformed tokens, rejected on load, token reset while open, well-formed token, en and de strings), deep_links_test.
- 9: group_invite_page_test 'Reset asks first' and 'Reset issues a new token'.
- 10: rls_hardening_migration_test C1 forward test (covers the new file), join_group_migration_test (revokes, pinned search_path, JWT caller, token checked first); security review found no server-side hole.
- gates: flutter analyze no issues; flutter test 1927 passed; harness 30 75/75 · 40 14/14 · 50 4/4 · 60 21/21 · 70 21/21 · 80 9/9 (local container only). Migration authored, not applied; its apply entry stays open in manual-checks.md.
- review: resolved · rounds: 3 · open: 0 block, 0 note, 0 lean · trimmed: 2
- tier: normal
