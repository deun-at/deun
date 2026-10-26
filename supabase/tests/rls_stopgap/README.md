# RLS stopgap — local policy tests

Runs every app path and RPC against `supabase/migrations/20261025180000_rls_stopgap.sql` as anon, as a group member, as a stranger and as an invite-link joiner, on a throwaway local Postgres. Never point this at the live instance: the cases write (each one inside a subtransaction that is rolled back, but that is no excuse on production).

1. `00_prelude.sql` — Supabase stand-ins: the anon, authenticated, service_role and supabase_admin roles, plus `auth.users`, `auth.jwt()`, `auth.uid()` and `auth.email()`.
2. Load the live public schema: a `pg_dump --schema-only --schema=public` of api.deun.app.
3. `10_seed.sql` — two groups, a two-group guest, an outsider and tokens.
4. `20_runner.sql` — `t(case, actor, sql, expectation)`, which runs each case as its actor and rolls it back.
5. Apply the stopgap, then `20261025190000_rls_stopgap_followup.sql`, both as `supabase_admin`, then run `30_cases.sql`. It prints `75/75 passed` and lists any failures.

On 2026-10-25: 40/68 before the stopgap (the live holes), 68/68 after it, 40/68 again after `migrations/rollback/20261025180000_rls_stopgap_rollback.sql`, and 68/68 after re-applying. Docker image `postgres:15.8`, the same version as the live server.

Follow-up (security review, 2026-10-25): with the stopgap alone, 70/75 (a stranger lists every roster, an outsider lists every group id, a member moves their own membership into another group, a user turns themselves into a guest); with the follow-up, 75/75, including a fresh rebuild that applies both files twice.

guest-merge-rpc (2026-10-26): after step 5, apply `migrations/<timestamp>_join_group_guest_merge.sql` as `supabase_admin` and run `40_join_group_cases.sql`. It prints `14/14 passed` (7/14 before the migration, where every call errs on the missing function); `30_cases.sql` stays 75/75 with the migration applied.

payback-atomic-recalc (2026-10-26): after step 5, apply `migrations/<timestamp>_pay_back_atomic_recalc.sql` as `supabase_admin` and run `50_pay_back_cases.sql`. It prints `4/4 passed` (0/4 before the migration, where `pay_back` only inserts); `30_cases.sql` stays 75/75 with the migration applied.

group-write-rpcs (2026-10-26): after step 5, apply `migrations/<timestamp>_join_group_guest_merge.sql` (it creates `lock_group_member_writes`) and then `migrations/<timestamp>_group_write_rpcs.sql`, both as `supabase_admin`, and run `60_group_write_cases.sql`. It prints `21/21 passed` (2/21 before the migration, where every call errs on the missing function); with it applied `30_cases.sql` stays 75/75, `40_join_group_cases.sql` 14/14 and `50_pay_back_cases.sql` 4/4.
