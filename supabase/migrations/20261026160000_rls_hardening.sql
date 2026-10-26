-- rls-hardening: the anon key executes no function in public.
--
-- The stopgap (20261025180000, applied 2026-10-25) revoked anon's own grants on
-- every public table, sequence and function, and in the default privileges. But
-- Postgres grants EXECUTE on every new function to PUBLIC, and anon belongs to
-- PUBLIC, so every public function stayed callable with the web build's anon
-- key. Today each one either fails on its first table (anon holds no table
-- grant) or is SECURITY DEFINER and already revoked from public. This closes
-- the door itself, so a function that touches no table, or a new SECURITY
-- DEFINER one, is not reachable without a session.
--
-- authenticated and service_role keep what they had: every public function
-- carries its own grant to authenticated (the 2026-10-25 dump, the grants in
-- the stopgap and later migrations, and the postgres / supabase_admin default
-- privileges for functions created since). The RLS switches, policies, the
-- membership helper and the column grants are the stopgap's and its follow-up's
-- (20261025190000) and stay as they are.
--
-- Default privileges cannot take PUBLIC's EXECUTE away inside one schema, only
-- for a role in every schema, which would also reach the platform's own
-- schemas. So a function created after this file runs is callable by PUBLIC
-- again: every later migration that creates a function revokes execute from
-- public and anon itself (test/pages/groups/rls_hardening_migration_test.dart).
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261026100000,
-- 20261026120000 and 20261026140000 when those are applied. If one of them is
-- applied after this file, run this file again: it is idempotent.
-- Tested on the local harness: supabase/tests/rls_stopgap/70_rls_hardening_cases.sql.

begin;

revoke execute on all functions in schema public from public, anon;

commit;
