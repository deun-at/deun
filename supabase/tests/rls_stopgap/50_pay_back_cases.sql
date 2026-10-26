-- payback-atomic-recalc: pay_back records a payback and recalculates the group's
-- balances in one transaction. Run after 30_cases.sql, once the
-- *_pay_back_atomic_recalc.sql migration is applied as supabase_admin.
-- Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…) {a, b, guest g1, guest g2}; guest g1 owes a 5.00 net, and
-- every other G1 member is at 0.
truncate test_result;
select t('pay_back: the payback, its balances and both checkers commit together', 'a@x.test', $q$
do $c$
declare
  _id uuid;
begin
  _id := public.pay_back('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5);
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.expense where id = _id and is_paid_back_row and user_id = 'aaaaaaaa-0000-0000-0000-000000000001') then
    raise exception 'payback row missing or not attributed to the recorder';
  end if;
  if exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and total_share_amount <> 0) then
    raise exception 'balances not recalculated';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
  if (select created_at from public.expense_update_checker where group_id = '11111111-0000-0000-0000-000000000001' and expense_id = _id) is distinct from now() then
    raise exception 'expense checker not bumped for the payback';
  end if;
end
$c$$q$, 'ok');
select t('pay_back_exact: the app''s main path settles the balance in the same call', 'a@x.test', $q$
do $c$
begin
  perform public.pay_back_exact('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5);
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and total_share_amount <> 0) then
    raise exception 'balances not recalculated';
  end if;
end
$c$$q$, 'ok');
select t('pay_back: a rolled-back payback leaves neither the row nor a balance change', 'a@x.test', $q$
do $c$
begin
  begin
    perform public.pay_back('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5);
    if (select total_share_amount from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'guest+g1@guest.invalid' limit 1) <> 0 then
      raise exception 'summary not updated inside the payback''s transaction';
    end if;
    raise exception using errcode = 'P0001', message = '__undo__';
  exception when others then
    if sqlerrm <> '__undo__' then raise; end if;
  end;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.expense where group_id = '11111111-0000-0000-0000-000000000001' and is_paid_back_row) then
    raise exception 'payback row survived the rollback';
  end if;
  if (select total_share_amount from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'guest+g1@guest.invalid' limit 1) <> -5 then
    raise exception 'balance change survived the rollback';
  end if;
end
$c$$q$, 'ok');
select t('pay_back: a failed recalculation leaves no payback behind', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  create function public.__fail_recalc() returns trigger language plpgsql as $f$
  begin
    raise exception 'recalc down';
  end
  $f$;
  create trigger __fail_recalc before insert on public.group_shares_summary
    for each row execute function public.__fail_recalc();
  perform set_config('role', 'authenticated', true);
  begin
    perform public.pay_back('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5);
    raise exception 'pay_back returned although its recalculation failed';
  exception when others then
    if sqlerrm <> 'recalc down' then raise; end if;
  end;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.expense where group_id = '11111111-0000-0000-0000-000000000001' and is_paid_back_row) then
    raise exception 'payback outlived its failed recalculation';
  end if;
end
$c$$q$, 'ok');
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result order by n;
