-- group-write-rpcs: add_group_member, remove_group_member, delete_expense and
-- delete_group, each one transaction. Run after 30_cases.sql, once
-- *_join_group_guest_merge.sql and *_group_write_rpcs.sql are applied as
-- supabase_admin. Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…) {a, b, guest g1, guest g2}: a is owed 5.00 net, guest g1 owes
-- 5.00, b and guest g2 are at 0 with no G1 expense (g2 pays E4 in G2).
-- G2 (2222…) {c, guest g2}. d and e have accounts and no group.
truncate test_result;

-- add_group_member -----------------------------------------------------------

select t('add: a new member gets one row, not favourite, a balance row and a checker bump', 'a@x.test', $q$
do $c$
declare _r text;
begin
  _r := public.add_group_member('11111111-0000-0000-0000-000000000001', 'd@x.test');
  if _r is distinct from 'inserted' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test' and removed_at is null and not is_favorite) <> 1 then
    raise exception 'no single active, non-favourite row for d';
  end if;
  if not exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'd@x.test') then
    raise exception 'balances not recalculated for the new member';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');

select t('add: an active member writes nothing and does not recalculate', 'a@x.test', $q$
do $c$
declare _r text;
begin
  perform set_config('role', 'postgres', true);
  update public.group_update_checker set created_at = '2000-01-01' where group_id = '11111111-0000-0000-0000-000000000001';
  perform set_config('role', 'authenticated', true);
  _r := public.add_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test');
  if _r is distinct from 'already_member' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test') <> 1 then
    raise exception 'a second row for b';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> '2000-01-01' then
    raise exception 'recalculated although nothing was written';
  end if;
end
$c$$q$, 'ok');

select t('add: a soft-removed member is re-added on the same row', 'a@x.test', $q$
do $c$
declare _r text;
begin
  perform set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() - interval '1 day' where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test';
  perform set_config('role', 'authenticated', true);
  _r := public.add_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test');
  if _r is distinct from 're_added' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test' and removed_at is null) <> 1
     or (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test') <> 1 then
    raise exception 'b not re-added on exactly one row';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');

select t('add: a failed recalculation leaves no new row', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  create function public.__fail_recalc() returns trigger language plpgsql as $f$ begin raise exception 'recalc down'; end $f$;
  create trigger __fail_recalc before insert on public.group_shares_summary for each row execute function public.__fail_recalc();
  perform set_config('role', 'authenticated', true);
  begin
    perform public.add_group_member('11111111-0000-0000-0000-000000000001', 'd@x.test');
    raise exception 'add returned although its recalculation failed';
  exception when others then
    if sqlerrm <> 'recalc down' then raise; end if;
  end;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test') then
    raise exception 'the member outlived the failed recalculation';
  end if;
end
$c$$q$, 'ok');

-- remove_group_member ----------------------------------------------------------

select t('remove: a member who owes is blocked with the magnitude and nothing changes', 'a@x.test', $q$
do $c$
declare _r jsonb;
begin
  perform set_config('role', 'postgres', true);
  update public.group_update_checker set created_at = '2000-01-01' where group_id = '11111111-0000-0000-0000-000000000001';
  perform set_config('role', 'authenticated', true);
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 0.005);
  if _r is distinct from '{"outcome": "blocked", "outstanding": 5}'::jsonb then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid' and removed_at is null) then
    raise exception 'blocked removal changed the row';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> '2000-01-01' then
    raise exception 'blocked removal recalculated';
  end if;
end
$c$$q$, 'ok');

select t('remove: a member who is owed is blocked the same way', 'b@x.test', $q$
do $c$
declare _r jsonb;
begin
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'a@x.test', 0.005);
  if _r is distinct from '{"outcome": "blocked", "outstanding": 5}'::jsonb then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'a@x.test' and removed_at is null) then
    raise exception 'blocked removal changed the row';
  end if;
end
$c$$q$, 'ok');

select t('remove: the epsilon is the client''s, compared with >=', 'a@x.test', $q$
do $c$
declare _r jsonb;
begin
  perform set_config('role', 'postgres', true);
  insert into public.expense (id, group_id, name, paid_by, expense_date) values ('e9000000-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Residue', 'b@x.test', now());
  insert into public.expense_entry (id, expense_id, amount) values ('f9000000-0000-0000-0000-000000000001', 'e9000000-0000-0000-0000-000000000001', 0.008);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values ('f9000000-0000-0000-0000-000000000001', 'a@x.test', 50), ('f9000000-0000-0000-0000-000000000001', 'b@x.test', 50);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  perform set_config('role', 'authenticated', true);
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test', 0.004);
  if _r is distinct from '{"outcome": "blocked", "outstanding": 0.004}'::jsonb then raise exception 'at the epsilon: answered %', _r; end if;
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test', 0.005);
  if _r ->> 'outcome' is distinct from 'soft_removed' then raise exception 'below the epsilon: answered %', _r; end if;
end
$c$$q$, 'ok');

select t('remove: a settled member with no history in THIS group is hard-removed', 'a@x.test', $q$
do $c$
declare _r jsonb;
begin
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 0.005);
  if _r ->> 'outcome' is distinct from 'hard_removed' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid') then
    raise exception 'row survived a hard removal';
  end if;
  if exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'guest+g2@guest.invalid') then
    raise exception 'balances not recalculated';
  end if;
  if not exists (select 1 from public.group_member where group_id = '22222222-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid') then
    raise exception 'the other group lost its member';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');

select t('remove: a settled member holding a share is soft-removed and no balance moves', 'a@x.test', $q$
do $c$
declare _r jsonb; _before jsonb;
begin
  perform set_config('role', 'postgres', true);
  insert into public.expense (id, group_id, name, paid_by, expense_date) values ('e9000000-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'Zero', 'a@x.test', now());
  insert into public.expense_entry (id, expense_id, amount) values ('f9000000-0000-0000-0000-000000000002', 'e9000000-0000-0000-0000-000000000002', 0);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values ('f9000000-0000-0000-0000-000000000002', 'b@x.test', 100);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for) into _before
    from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001';
  perform set_config('role', 'authenticated', true);
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test', 0.005);
  if _r ->> 'outcome' is distinct from 'soft_removed' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if (select removed_at from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test') is distinct from now() then
    raise exception 'removed_at not stamped';
  end if;
  if _before is distinct from (select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for)
      from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'a balance moved';
  end if;
end
$c$$q$, 'ok');

select t('remove: a settled payer with no share of their own is soft-removed, never hard', 'a@x.test', $q$
do $c$
declare _r jsonb;
begin
  perform set_config('role', 'postgres', true);
  insert into public.expense (id, group_id, name, paid_by, expense_date) values ('e9000000-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', 'Zero', 'b@x.test', now());
  insert into public.expense_entry (id, expense_id, amount) values ('f9000000-0000-0000-0000-000000000003', 'e9000000-0000-0000-0000-000000000003', 0);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values ('f9000000-0000-0000-0000-000000000003', 'a@x.test', 100);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  perform set_config('role', 'authenticated', true);
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test', 0.005);
  if _r ->> 'outcome' is distinct from 'soft_removed' then raise exception 'answered %', _r; end if;
end
$c$$q$, 'ok');

select t('remove: a repeated soft removal keeps the first timestamp', 'a@x.test', $q$
do $c$
declare _r jsonb;
begin
  perform set_config('role', 'postgres', true);
  update public.group_member set removed_at = '2026-01-01T00:00:00Z' where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid';
  insert into public.expense (id, group_id, name, paid_by, expense_date, is_paid_back_row) values ('e9000000-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000001', 'paid_back', 'guest+g1@guest.invalid', now(), true);
  insert into public.expense_entry (id, expense_id, amount) values ('f9000000-0000-0000-0000-000000000004', 'e9000000-0000-0000-0000-000000000004', 5);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values ('f9000000-0000-0000-0000-000000000004', 'a@x.test', 100);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  perform set_config('role', 'authenticated', true);
  _r := public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 0.005);
  if _r ->> 'outcome' is distinct from 'soft_removed' then raise exception 'answered %', _r; end if;
  perform set_config('role', 'postgres', true);
  if (select removed_at from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid') <> '2026-01-01T00:00:00Z' then
    raise exception 'the first removal timestamp was overwritten';
  end if;
end
$c$$q$, 'ok');

select t('remove: holds the member-write lock and SHARE locks on expense and expense_entry_share until commit', 'a@x.test', $q$
do $c$
begin
  perform public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 0.005);
  perform set_config('role', 'postgres', true);
  if (select count(*) from pg_locks where pid = pg_backend_pid() and granted and locktype = 'relation' and mode = 'ShareLock'
      and relation in ('public.expense'::regclass, 'public.expense_entry_share'::regclass)) <> 2 then
    raise exception 'share locks not held';
  end if;
  if not exists (select 1 from pg_locks where pid = pg_backend_pid() and granted and locktype = 'advisory' and mode = 'ExclusiveLock') then
    raise exception 'member-write lock not held';
  end if;
end
$c$$q$, 'ok');

select t('remove: a caller outside the group is refused before any lock', 'd@x.test', $q$
select public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 0.005)
$q$, 'err');

select t('remove: a missing epsilon is refused, never read as settled', 'a@x.test', $q$
select public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', null)
$q$, 'err');

select t('remove: a failed recalculation leaves the member in place', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  create function public.__fail_recalc() returns trigger language plpgsql as $f$ begin raise exception 'recalc down'; end $f$;
  create trigger __fail_recalc before insert on public.group_shares_summary for each row execute function public.__fail_recalc();
  perform set_config('role', 'authenticated', true);
  begin
    perform public.remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 0.005);
    raise exception 'remove returned although its recalculation failed';
  exception when others then
    if sqlerrm <> 'recalc down' then raise; end if;
  end;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid') then
    raise exception 'the removal outlived the failed recalculation';
  end if;
end
$c$$q$, 'ok');

-- delete_expense ---------------------------------------------------------------

select t('delete expense: every balance returns exactly, no leftover summary row, checker row gone', 'a@x.test', $q$
do $c$
declare _before jsonb;
begin
  perform set_config('role', 'postgres', true);
  select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for) into _before
    from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001';
  insert into public.expense (id, group_id, name, paid_by, expense_date) values ('e9000000-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001', 'Taxi', 'b@x.test', now());
  insert into public.expense_entry (id, expense_id, amount) values ('f9000000-0000-0000-0000-000000000005', 'e9000000-0000-0000-0000-000000000005', 12);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values ('f9000000-0000-0000-0000-000000000005', 'a@x.test', 50), ('f9000000-0000-0000-0000-000000000005', 'guest+g2@guest.invalid', 50);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', 'e9000000-0000-0000-0000-000000000005');
  perform set_config('role', 'authenticated', true);
  perform public.delete_expense('e9000000-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.expense where id = 'e9000000-0000-0000-0000-000000000005')
     or exists (select 1 from public.expense_entry_share where expense_entry_id = 'f9000000-0000-0000-0000-000000000005') then
    raise exception 'expense or its shares survived';
  end if;
  if exists (select 1 from public.expense_update_checker where expense_id = 'e9000000-0000-0000-0000-000000000005') then
    raise exception 'expense checker row survived';
  end if;
  if _before is distinct from (select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for)
      from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'balances did not return exactly';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');

select t('delete expense: a payback row goes the same way and balances return exactly', 'a@x.test', $q$
do $c$
declare _before jsonb; _id uuid;
begin
  perform set_config('role', 'postgres', true);
  select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for) into _before
    from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001';
  _id := public.pay_back('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5);
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', _id);
  perform set_config('role', 'authenticated', true);
  perform public.delete_expense(_id, '11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.expense where id = _id) or exists (select 1 from public.expense_update_checker where expense_id = _id) then
    raise exception 'payback row or its checker survived';
  end if;
  if _before is distinct from (select jsonb_agg(jsonb_build_array(paid_by, paid_for, total_share_amount, share_amount, total_expenses) order by paid_by, paid_for)
      from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'balances did not return exactly';
  end if;
end
$c$$q$, 'ok');

select t('delete expense: an expense of another group is left alone', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  insert into public.group_member (group_id, email) values ('22222222-0000-0000-0000-000000000001', 'a@x.test');
  perform set_config('role', 'authenticated', true);
  perform public.delete_expense('e3000000-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.expense where id = 'e3000000-0000-0000-0000-000000000001') then
    raise exception 'deleted an expense of a group it was not given';
  end if;
end
$c$$q$, 'ok');

select t('delete expense: a failed recalculation leaves the expense in place', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  create function public.__fail_recalc() returns trigger language plpgsql as $f$ begin raise exception 'recalc down'; end $f$;
  create trigger __fail_recalc before insert on public.group_shares_summary for each row execute function public.__fail_recalc();
  perform set_config('role', 'authenticated', true);
  begin
    perform public.delete_expense('e1000000-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001');
    raise exception 'delete returned although its recalculation failed';
  exception when others then
    if sqlerrm <> 'recalc down' then raise; end if;
  end;
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.expense where id = 'e1000000-0000-0000-0000-000000000001') then
    raise exception 'the delete outlived the failed recalculation';
  end if;
end
$c$$q$, 'ok');

-- delete_group -----------------------------------------------------------------

select t('delete group: the group, its members and its checker row go; the other group stays', 'a@x.test', $q$
do $c$
begin
  perform public.delete_group('11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'group survived';
  end if;
  if exists (select 1 from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'group checker row survived (or was re-created)';
  end if;
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'members survived';
  end if;
  if not exists (select 1 from public.group_update_checker where group_id = '22222222-0000-0000-0000-000000000001') then
    raise exception 'the other group lost its checker row';
  end if;
end
$c$$q$, 'ok');

select t('delete group: a non-member deletes nothing', 'c@x.test', $q$
do $c$
begin
  perform public.delete_group('11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'a non-member deleted the group';
  end if;
end
$c$$q$, 'ok');

select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result order by n;
