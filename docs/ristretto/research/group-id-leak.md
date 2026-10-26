# group-id-leak — research
Researched: 2026-10-26 · at commit 38657a6 · reached: repo (live dump supabase/schema/baseline.sql incl. realtime schema, migrations, lib/, harness, plans), supabase.com/docs/guides/realtime/postgres-changes, github.com/eulerto/wal2json · not reached: live instance (house rule), realtime server source for v2.34.7

## Why
Not stated.
Candidates (proposals — a person picks or rewrites):
- Members of every group · noticed by: a stranger who knows only a group id cannot become a member, so no unknown name appears in the member list. The harness case "stranger joins G1 by id" flips from ok:1 to err.
- Whoever shares an invite · noticed by: a link posted in the wrong chat can be revoked by rotating it, and the old link then says the invite is no longer valid.
- Jakob as operator · noticed by: no realtime payload sent to a non-member carries the id of a group that still exists.

## Domain
- RLS is not applied to DELETE events. Filtering a DELETE needs `replica identity full` (docs) · source: https://supabase.com/docs/guides/realtime/postgres-changes, 2026-10-26 · in domain/supabase-realtime.md (now marked conflict, see Open)
- Under RLS, a DELETE goes to every subscription whose filter matches the old row, with no RLS check, and `old_record` is trimmed to the primary-key columns the role may SELECT. So `{expense_id, group_id}` reaches every unfiltered `expense_update_checker` subscriber · source: baseline.sql `realtime.apply_rls` :1726/:1755/:1760, 2026-10-26 · proposed → domain/supabase-realtime.md
- `pk` (`is_pkey`) comes from wal2json `include-pk`, and filters match on `old_columns` built from wal2json `identity`. Under default identity a filter on a PK column therefore hears deletes, which is how `expense_list:<group>` hears them today · source: baseline.sql :1568–1590, :1755, 2026-10-26 · proposed → domain/supabase-realtime.md (with the entry above)
- The publication's `publish` flags gate events for the whole publication, not per table · source: baseline.sql `realtime.list_changes` :1977/:2008, 2026-10-26 · proposed → domain/supabase-realtime.md
- A channel filter on a column the role cannot SELECT is rejected · source: baseline.sql `realtime.subscription_check_filters` :2110–2140, 2026-10-26 · proposed → domain/supabase-realtime.md
- Broadcast-from-DB (`realtime.send`, `realtime.broadcast_changes`, `realtime.messages`) is installed on live. realtime_client 2.7.1 supports `private` channels · source: baseline.sql :1804/:2075/:3353, pubspec.lock, 2026-10-26 · proposed → domain/supabase-realtime.md

## As-is
- Exists: supabase/schema/baseline.sql — `supabase_realtime` = expense_update_checker (PK `(expense_id, group_id)`), group_update_checker (PK `group_id`), friendship (PK `(requester, addressee)`), all on default identity. Checker rows are upserted, never deleted by the app. They are deleted only by FK cascade (expense delete → `{expense_id, group_id}` of a LIVE group; group delete → id of a DEAD group, harmless because group_member.group_id has an FK to group). An account delete cascades the user's paid expenses, so it leaks too. Friendship deletes leak both emails (social graph, not group ids)
- Exists: supabase/migrations/20261025180000_rls_stopgap.sql — :165–175 `group_member: insert self or by member` admits `email = own` for ANY group_id. No invite/token column or table exists anywhere in the schema. Group ids are `gen_random_uuid()`, so they cannot be guessed, only leaked
- Exists: supabase/migrations/20261026100000_join_group_guest_merge.sql (unapplied) — `join_group(_group_id, _guest_email)` is SECURITY INVOKER and its own-row insert passes only through that self-insert branch. `group_join_guests(_group_id)` is SECURITY DEFINER and lists guest names to anyone holding an id. Both take only the group id
- Exists: lib/pages/groups/presentation/group_invite_page.dart — the only invite source: `https://app.deun.app/#/group/join?groupId=<uuid>&name=<name>` (link, QR, share sheet). Copy: "Anyone with this link can join the group." The id travels in the fragment
- Exists: lib/deep_links.dart — allowlists `/group/join` when `groupId` is a uuid and passes the whole fragment through, so an extra param already survives into the router. Android App Links cover app.deun.app and deun.app (android/app/src/main/AndroidManifest.xml)
- Exists: lib/app_router.dart — the `join` route reads only `groupId` and `name`
- Exists: lib/pages/groups/data/member_repository.dart — `joinGroup` calls RPC `join_group`, and `fetchJoinState` calls `group_join_guests` plus the user's own row. No client fallback
- Exists: lib/pages/friends/presentation/friend_qr_page.dart — the friend link is `#/friend/accept?u=&c=` and carries no group id. Not affected
- Exists: lib/pages/expenses/provider/expense_list.dart — the only reader of checker DELETE events: `expense_list:<group>` on expense_update_checker `group_id=eq`, which removes `oldRecord['expense_id']`. Taking the table out of the publication also loses this channel's insert and update events (live expense list)
- Exists: lib/pages/expenses/provider/claim_notifier.dart — `claim:<expense>` on expense_update_checker `expense_id=eq`, insert and update only in effect, plus presence carrying member emails
- Exists: lib/pages/groups/provider/group_list.dart — group_update_checker in-filter chunks, which handle delete. A `group_list:membership` channel on group_member `email=eq` expects 20261025200000. lib/pages/groups/provider/group_detail.dart listens to group_update_checker `group_id=eq`
- Exists: main (released builds) lib/pages/groups/presentation/group_join_page.dart — joins client-side with `insert into group_member` (own row), then a client merge. The web build deploys from main
- Already settled: group_member reads limited to own groups so ids are known "only through its invite link" — 20261025190000 header, rls-hardening Decisions "Reads of group_member"
- Already settled: the expense_update_checker leak was left to Jakob, and publishing group_member was flagged "do not apply yet" — rls-hardening Decisions (taken, closer 2026-10-26), realtime-event-scope Open findings
- Already settled: join_group stays SECURITY INVOKER, with "Jakob decides on SECURITY DEFINER" as a follow-up — guest-merge-rpc Decisions "Security mode"
- Already settled: house rule (h): migrations are authored here and applied by Jakob, with no client fallback — roadmap, rls-hardening Decisions
- Touches: supabase/migrations/20261025200000_realtime_event_scope.sql — publishing group_member sends `(email, group_id)` on every removal, and on join_group's guest-row delete. The same leak, so it must not be applied as written
- Touches: supabase/migrations/20261026100000_join_group_guest_merge.sql — option (a) means join_group needs SECURITY DEFINER or a definer insert, plus a token argument and a token check in `group_join_guests`
- Touches: supabase/tests/rls_stopgap/30_cases.sql — :92 asserts the hole (ok:1) and must flip. The 40_join_group_cases.sql outsider-join cases need the token
- Touches: test/pages/groups/rls_hardening_migration_test.dart — C6 pins the self-insert rule, and the statement→policy table maps `rpc:join_group` to it
- Touches: lib/pages/groups/presentation/group_invite_page.dart — the link gains a token. test/widgets/group_invite_page_test.dart and test/deep_links_test.dart pin the link shape
- Touches: lib/pages/groups/presentation/group_join_page.dart — a bad or expired token now raises. Today every failure shows `generalError`, so a dead link would need its own message (en+de)

## Open
- Backward compatibility (ruling): dropping the self-insert branch breaks every released build's join (main inserts its own row) until users update, and the web build only after a deploy. Every link already in chats has no token: hard-fail, grandfather until a date, or a per-group "old links still work" switch? Each grandfather keeps the leak open for its lifetime.
- Option (c), a lead not offered in the input: give expense_update_checker a PK of `expense_id` alone (keep a UNIQUE `(group_id, expense_id)` for the upserts) plus `replica identity full`. Filters would still match `group_id` through `old_columns`, while the payload is trimmed to `{expense_id}`. This rests on wal2json's `pk` following the PRIMARY KEY and not the identity index: the README does not say, so it is unverified. It is reachable locally with a wal2json-equipped Postgres (supabase/postgres image) and the dump's `realtime.apply_rls`, but not with the plain postgres:15.8 harness. The same trick (a surrogate PK) would apply to group_member and friendship.
- Not viable as found: revoking column SELECT on `group_id` (it rejects the app's own `group_id=eq` filter), and `publish` without delete (publication-wide: it kills the group-delete and friendship-delete events realtime-event-scope relies on).
- (a) alone does not hide ids: ids keep leaking but become useless. (b) alone leaves "id = membership", so any other future leak (a URL, a screenshot, a log, the group_member publication) reopens it. The ruling on (a), (b) or (c) is Jakob's.
- Where a token lives and who may rotate it (any member, or the creator only), and whether `group_join_guests` requires it too: undecided.
- Realtime v2.34.7 server behaviour is inferred from the dumped `realtime` schema functions, not from the server code or a live socket (house rule: no live probes).
- Domain conflict noted on supabase-realtime.md "postgres_changes and DELETE": a PK-column filter hears deletes without full identity. This also bears on realtime-event-scope's "replica identity full" note.
