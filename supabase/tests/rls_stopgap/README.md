# RLS stopgap — local policy tests

Runs every app path and RPC against `supabase/migrations/20261025180000_rls_stopgap.sql` as anon, as a group member, as a stranger and as an invite-link joiner, on a throwaway local Postgres. Never point this at the live instance: the cases write (each one inside a subtransaction that is rolled back, but that is no excuse on production).

1. `00_prelude.sql` — Supabase stand-ins: the anon, authenticated, service_role and supabase_admin roles, plus `auth.users`, `auth.jwt()`, `auth.uid()` and `auth.email()`.
2. Load the live public schema: a `pg_dump --schema-only --schema=public` of api.deun.app.
3. `10_seed.sql` — two groups, a two-group guest, an outsider and tokens.
4. `20_runner.sql` — `t(case, actor, sql, expectation)`, which runs each case as its actor and rolls it back.
5. Apply the stopgap, then `20261025190000_rls_stopgap_followup.sql`, both as `supabase_admin`, then run `30_cases.sql`. It prints `75/75 passed` and lists any failures.

On 2026-10-25: 40/68 before the stopgap (the live holes), 68/68 after it, 40/68 again after `migrations/rollback/20261025180000_rls_stopgap_rollback.sql`, and 68/68 after re-applying. Docker image `postgres:15.8`, the same version as the live server.

Follow-up (security review, 2026-10-25): with the stopgap alone, 70/75 (a stranger lists every roster, an outsider lists every group id, a member moves their own membership into another group, a user turns themselves into a guest); with the follow-up, 75/75, including a fresh rebuild that applies both files twice.
