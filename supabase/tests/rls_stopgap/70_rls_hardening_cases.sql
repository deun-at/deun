-- rls-hardening: the anon key holds no privilege on anything in public, and a
-- signed-in stranger reaches nothing of a group they are not in.
-- Run after 30_cases.sql, once the *_rls_hardening.sql migration is applied as
-- supabase_admin. Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…) {a, b, guest g1, guest g2}; G2 (2222…) {c, guest g2}; c is the stranger to G1.
truncate test_result;
-- ===== anon: nothing granted, directly or through PUBLIC =====
select t('anon executes no public function', 'a@x.test', $q$select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')$q$, 'ok:0');
select t('authenticated executes every public function', 'a@x.test', $q$select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and not has_function_privilege('authenticated', p.oid, 'execute')$q$, 'ok:0');
select t('anon holds nothing on any public table or view', 'a@x.test', $q$select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r','p','v','m','f') and has_table_privilege('anon', c.oid, 'select,insert,update,delete,truncate,references,trigger')$q$, 'ok:0');
select t('anon holds nothing on any public sequence', 'a@x.test', $q$select s.seqrelid from pg_sequence s join pg_class c on c.oid = s.seqrelid join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and has_sequence_privilege('anon', s.seqrelid, 'usage,select,update')$q$, 'ok:0');
select t('a table created later is not granted to anon', 'a@x.test', $q$
  select set_config('role', 'supabase_admin', true);
  create table public.later_admin (id int);
  select set_config('role', 'postgres', true);
  create table public.later_postgres (id int);
  select 1 from pg_class c where c.relname in ('later_admin', 'later_postgres') and has_table_privilege('anon', c.oid, 'select')$q$, 'ok:0');
-- ===== stranger c against group G1: reads, rewrites and deletes nothing =====
select t('stranger reads G1 group row', 'c@x.test', $q$select * from "group" where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger reads G1 expenses', 'c@x.test', $q$select * from expense where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger reads G1 lines', 'c@x.test', $q$select * from expense_entry where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('stranger reads G1 balances', 'c@x.test', $q$select * from group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger renames G1', 'c@x.test', $q$update "group" set name = 'X' where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger deletes G1', 'c@x.test', $q$delete from "group" where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger rewrites G1 expenses', 'c@x.test', $q$update expense set name = 'X' where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger deletes G1 expenses', 'c@x.test', $q$delete from expense where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger rewrites G1 lines', 'c@x.test', $q$update expense_entry set amount = 0 where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('stranger deletes G1 lines', 'c@x.test', $q$delete from expense_entry where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('stranger adds a line to a G1 expense', 'c@x.test', $q$insert into expense_entry (expense_id, amount) values ('e1000000-0000-0000-0000-000000000001', 1)$q$, 'err');
select t('stranger deletes G1 shares', 'c@x.test', $q$delete from expense_entry_share where expense_entry_id in ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('stranger adds a share to a G1 line', 'c@x.test', $q$insert into expense_entry_share (expense_entry_id, email, percentage) values ('f1000000-0000-0000-0000-000000000001', 'c@x.test', 100)$q$, 'err');
select t('stranger rewrites G1 balances', 'c@x.test', $q$update group_shares_summary set total_share_amount = 0 where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger deletes G1 balances', 'c@x.test', $q$delete from group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger adds a G1 balance row', 'c@x.test', $q$insert into group_shares_summary (group_id, paid_by, paid_for, total_expenses, share_amount, total_share_amount) values ('11111111-0000-0000-0000-000000000001', 'c@x.test', 'c@x.test', 0, 0, 0)$q$, 'err');
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result where not pass order by n;
