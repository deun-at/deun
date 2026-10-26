# supabase/schema — the reference schema

`baseline.sql` is a schema-only `pg_dump` of the whole live database on api.deun.app
(self-hosted Supabase, custom Docker), supplied by Jakob. It is **not a migration** and is never
applied: it records what the live database already is, so the repo can say what a rebuild needs.
Its header names the dump stamp, the command, the server version and any redactions.

## Rebuild order

1. A fresh self-hosted Supabase stack. It creates its own schemas (see below).
2. The app-owned parts of `baseline.sql`, applied as `supabase_admin`.
3. Every file in `supabase/migrations/` (not `rollback/`) stamped **after** the baseline's
   `dump-stamp`, in filename order. A short stamp pads with zeros: `20260417` is `20260417000000`.

Migrations stamped before the dump are history: the dump already contains them, and replaying
them breaks the rebuild. For example, `20260417_user_spending_summary.sql` cannot turn the dump's
`get_user_spending_summary` back to an `int` color column, because create-or-replace cannot
change a return type.

`test/supabase/rebuild_set.dart` implements exactly this rule. The tests under `test/supabase/`
check four things against it. Every `.from`, `.rpc` and realtime target in `lib/` must exist in
the rebuild. Every function, column and index a pre-stamp migration creates must exist in it. The
dump must hold no row data. The dump must hold no secret.

## Rules for later work

- Every new migration is stamped after the dump stamp. A migration stamped earlier is neither
  replayed nor in the dump, so the chain-coverage test goes red.
- A newer dump replaces `baseline.sql` wholesale and moves the stamp. The dump is never
  hand-edited. The only permitted edit is a redaction: the value becomes a named placeholder
  (`<REDACTED:what>`) and the header lists it.

## Refreshing the dump

1. Apply every migration still open in `docs/ristretto/manual-checks.md` first.
2. On the server, run `date -u +%Y%m%d%H%M%S`, then
   `docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only`. Use no
   `--schema` filter: a filtered dump drops publication membership.
3. Put the output at `supabase/schema/baseline.sql`, **unstaged**, and run
   `flutter test test/supabase/schema_baseline_privacy_test.dart`. Redact whatever it names
   before staging, because a secret that reaches git history stays there.
4. Copy the current header on top. Update `dump-stamp`, `taken`, `server` and `redactions`. Then
   run `flutter test test/supabase/`.

## What the app owns

- Everything in schema `public`: the tables `user`, `group`, `group_member`, `expense`,
  `expense_entry`, `expense_entry_share`, `group_shares_summary`, `friendship`,
  `group_update_checker`, `expense_update_checker`, `payment_reminder`, `device_tokens` and
  `birthday_signup`, the `"Friendship Status"` enum, the functions, and the RLS switches,
  policies and grants on them. RLS and policies are captured as dumped but not asserted by tests.
- Membership of the `supabase_realtime` publication: the
  `ALTER PUBLICATION supabase_realtime ADD TABLE …` lines.

## What a fresh stack already provides

The schemas `_realtime`, `auth`, `extensions`, `graphql`, `graphql_public`, `pgbouncer`,
`pgsodium`, `realtime`, `storage`, `supabase_functions` and `vault`, with everything in them, the
event triggers, and the publications themselves (`supabase_realtime`,
`supabase_realtime_messages_publication`). They are in the dump only because it is unfiltered;
do not apply them over a stack. The dump creates its extensions with `IF NOT EXISTS`.

## Live-only objects

Neither a migration nor `lib/` names these, but they exist live and are part of the dump:
`pay_back_all()`, `get_group_monthly_statistics()`, the `birthday_signup` table, and the
`"Friendship Status"` enum (the type of `friendship.status`). Dropping any of them is separate
work.

## Not rebuilt from the repo

- Edge Functions, which `pg_dump` does not contain. `exchange-rate` lives in
  `supabase/functions/exchange-rate/`, and `push` is recovered by push-server-compose.
  `delete-user-account`, `send-contact-email` and `parse-receipt` exist only on the server.
- Data, auth users, storage objects, vault secrets, and the stack's own configuration.
- `supabase/config.toml` was removed. Only the Supabase CLI reads it, and this project uses
  neither the CLI nor a local `supabase db reset`. git history keeps it.
