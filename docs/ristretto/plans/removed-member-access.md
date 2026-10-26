# removed-member-access

## Spec
- Source: idea — group-id-leak report (2026-10-26), research/removed-member-access.md
- Goal: a soft-removed member loses all read and write access to the group they were removed from; their history stays visible to the remaining members.
- Why: members who remove someone · noticed by: the removed person can no longer read, edit or delete the group's expenses, rewrite its balances, delete the group, or put themselves back — getting back in takes a member re-adding them or a fresh invite link

## Contract
- Acceptance:
  - [auto] A soft-removed member (own `group_member` row with `removed_at` set) reads nothing of that group: no `group` row (so not its `invite_token`), no `group_member` rows other than their own, no `expense` / `expense_entry` / `expense_entry_share` / `group_shares_summary` / checker rows, and `group_join_guests` / `group_invite_valid` behave as for a stranger. Proof: local RLS harness (supabase/tests/rls_stopgap), new cases.
  - [auto] A soft-removed member changes nothing in that group: every insert, update and delete on those tables is refused or affects 0 rows, and `save_group_all`, `save_expense_all`, `claim_set_unit_shares`, `pay_back` / `pay_back_exact`, `add_group_member`, `remove_group_member`, `delete_group`, `delete_expense` and `reset_group_invite` all refuse them (where a function exists in the tree, applied in order). Proof: local RLS harness.
  - [auto] A soft-removed member cannot clear their own `removed_at` by a direct update; the harness case at 30_cases.sql:87 ("self re-admit") flips from ok to refused. Proof: local RLS harness.
  - [auto] Re-join still works: `join_group` with the group's current token clears `removed_at` and restores full access; an active member re-adding them (`add_group_member`, and `save_group_all`'s re-add) also restores it. Proof: local RLS harness.
  - [auto] Active members keep everything they have today, including seeing a removed member's rows, names and history in the ledger and balances; the ledger math (`update_group_member_shares`) still counts removed members' shares, and the guest-delete guard (`has_any_membership`) still counts removed rows. Proof: existing harness suites 30/40/50/60/70/80 green with this migration applied (updated only where a case encoded the old ruling).
  - [auto] Group creation still works for a brand-new group (insert … returning id, then the creator's own row), and once the group has any member row, a non-member whose id is in `group.user_id` (e.g. a fully or soft-removed last editor) can neither read the group nor insert themselves. Proof: local RLS harness.
  - [auto] On the removed member's device, the group leaves the group list on the next refresh (a refetch that comes back not-found drops it instead of keeping the stale entry), and an open group page, a typed `/group/<id>` route or a push tap for it shows the existing not-found state. Proof: widget/provider tests on the group list and group detail with a fake repository answering not-found.
  - [auto] Every new or replaced function revokes execute from public and anon itself (rls-hardening's forward test, test/pages/groups/rls_hardening_migration_test.dart, stays green), and any SECURITY DEFINER helper pins `search_path` and takes the caller from the JWT.
  - [auto] Gates: `flutter analyze` clean, `flutter test` green.
- Provides:
  - `public.is_group_member(_group_id uuid) returns boolean` — now true only for the caller's row with `removed_at is null` (signature unchanged)
  - `public.group_has_members(_group_id uuid) returns boolean` (or an equivalent SECURITY DEFINER helper; exact name the planner's) — used by the creator branches so a group_member policy does not sub-select group_member
  - Replaced policies on `public."group"` (SELECT / UPDATE / DELETE) and `public.group_member` (SELECT / INSERT / UPDATE) per Decisions
- Consumes: —
- Decisions:
  - Why → members who remove someone (Jakob in prep removed-member-access, 2026-10-26)
  - Standing ruling overturned → rls-hardening Decisions (c) / "Membership helper" (a soft-removed member counts as a member for read and write) is overruled: `is_group_member` means an active member (`removed_at is null`). The pins that encode the old ruling flip by decision: test/pages/groups/rls_hardening_migration_test.dart C4 and the self-re-admit case at supabase/tests/rls_stopgap/30_cases.sql:87 (Jakob in prep removed-member-access, 2026-10-26; research/removed-member-access.md)
  - What a soft-removed user sees → the group vanishes, exactly as for full removal: it leaves their group list, and an open screen, a typed `/group/<id>` route or a push for it shows not-found. A balance they still owe stays visible to the remaining members, who can record a payback on their behalf (payback-on-behalf). No read-only view. Consequence: that group no longer counts in the removed user's own friend balances or personal statistics (Jakob in prep removed-member-access, 2026-10-26)
  - Re-join → allowed through the group's current invite link: `join_group` with a valid token clears `removed_at`, as it does today. Removal does not reset the token; a member who wants someone out for good resets the link. Re-adding by an active member (`add_group_member`, `save_group_all`) also stays. Every other path to clearing one's own `removed_at` (the own-row UPDATE branch) is closed (Jakob in prep removed-member-access, 2026-10-26)
  - Creator column → `group.user_id` grants nothing once the group has a member row. The creator SELECT and INSERT branches apply only while the group has no `group_member` rows yet, which is all group creation (`save_group_all`'s insert … returning, then the creator's own row) needs; after that, access is by active membership only. `user_id` keeps its current meaning otherwise (save_group_all still writes it). This also makes "any member can set `user_id` to themselves" harmless, so it needs no separate fix (Jakob in prep removed-member-access, 2026-10-26) (stays context: domain/postgres-rls.md: RETURNING is checked against SELECT policies)
  - Released builds → their client-side re-join (update own `removed_at = null`) is refused once the migration is applied, the same hard-fail ruling as group-id-leak.
  - What stays counting removed rows → `has_any_membership` (guest-delete cascade guard) and `update_group_member_shares` (ledger math) are unchanged; the group_member SELECT keeps the own-row branch (`fetchJoinState` reads it) and lets active members see every row of their groups, removed ones included (ledger names).
  - group_member UPDATE → the own-row branch goes; active members keep `is_favorite` on their own row and `removed_at` on others' through the `is_group_member` branch; column grants unchanged.
  - How the policies are changed → a new migration replaces the helper and policies; the applied stopgap files are not edited. It is applied after 20261026180000 (group-id-leak, whose INSERT policy it replaces) and before 20261026160000 is re-run (or rls-hardening is re-run afterwards; it is idempotent). The manual-checks apply entry says so.
  - Realtime → no "you were removed" event is added. An open screen on the removed member's device is stale until its next fetch, which then comes back not-found (accepted: same as full removal today).
  - Push → unchanged; the push function already sends only to active members.
- Units:
  - Migration: `is_group_member` on `removed_at is null`; creator-branch helper; replaced `group` and `group_member` policies (own-row UPDATE branch dropped, creator branches limited to member-less groups); grants/revokes
  - Harness: flip 30_cases.sql:87, new removed-member cases (read nothing, write nothing, every RPC refused, no self-re-admit, re-join by token and by member, creator backdoor closed, group creation intact); update any 30–80 case that encoded the old ruling
  - Tests that pin the old ruling: rls_hardening_migration_test.dart C4 and its statement→policy rows updated to the new rule
  - Client: group list drops a group whose refetch comes back not-found; group detail / typed route / push tap show the existing not-found state for it; manual-checks apply entry
- Blockers: —

## Approach
- One migration changes the meaning of membership in one place (`is_group_member`) and rewrites the handful of policies that bypass it (the `group` policies that sub-select group_member directly, the creator branches, the own-row UPDATE). Because policies on group_member cannot sub-select group_member without recursion, the "group has no members yet" test for the creator branches goes through a small definer helper. Prove it on the local Docker harness (supabase/tests/rls_stopgap/README.md) against the whole tree's migrations applied in order — never against the live instance.
- On the client, the only change is honouring not-found for a group the user was in: the group list's per-group refresh drops the entry instead of keeping it, and the detail screen and typed route already have a not-found state (typed-routes) that the stale screen falls into on its next fetch.
- Likely touchpoints: supabase/migrations/ (new file), supabase/tests/rls_stopgap/30_cases.sql and a new cases file, test/pages/groups/rls_hardening_migration_test.dart, lib/pages/groups/provider/group_list.dart, lib/pages/groups/provider/group_detail.dart, docs/ristretto/manual-checks.md
- Depends: group-id-leak, rls-hardening, group-write-rpcs, typed-routes
- Parallel-with: —
