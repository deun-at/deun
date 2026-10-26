-- guest-merge-rpc: join_group and group_join_guests under the live policy set.
-- Run after 30_cases.sql, once the *_join_group_guest_merge.sql migration is applied
-- as supabase_admin. Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…) {a, b, guest g1, guest g2}; G2 (2222…) {c, guest g2}; d is in no group.
truncate test_result;
-- ===== joinable guests =====
select t('join guests: an outsider sees exactly the active guests', 'd@x.test', $q$select * from public.group_join_guests('11111111-0000-0000-0000-000000000001')$q$, 'ok:2');
select t('join guests: a soft-removed guest is not offered', 'd@x.test', $q$
  select set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid';
  select set_config('role', 'authenticated', true);
  select * from public.group_join_guests('11111111-0000-0000-0000-000000000001')$q$, 'ok:1');
select t('join guests: anon reaches nothing', 'anon', $q$select * from public.group_join_guests('11111111-0000-0000-0000-000000000001')$q$, 'err');
-- ===== joins =====
select t('join_group: outsider claims a one-group guest', 'd@x.test', $q$
do $c$
begin
  perform public.join_group('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid');
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test' and removed_at is null) then
    raise exception 'joiner is not an active member';
  end if;
  if exists (select 1 from public.group_member where email = 'guest+g1@guest.invalid') then
    raise exception 'guest membership kept';
  end if;
  if (select paid_by from public.expense where id = 'e2000000-0000-0000-0000-000000000001') <> 'd@x.test' then
    raise exception 'payer not moved';
  end if;
  if (select count(*) from public.expense_entry_share where email = 'd@x.test') <> 2 then
    raise exception 'shares not moved';
  end if;
  if exists (select 1 from public."user" where email = 'guest+g1@guest.invalid') then
    raise exception 'orphaned guest user row kept';
  end if;
  if exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and 'guest+g1@guest.invalid' in (paid_by, paid_for)) then
    raise exception 'summary still names the guest';
  end if;
  if not exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'd@x.test') then
    raise exception 'balances not recomputed';
  end if;
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');
select t('join_group: claiming a two-group guest leaves the other group alone', 'd@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  insert into public.expense (id, group_id, name, paid_by, expense_date) values
    ('e5000000-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'E5', 'guest+g2@guest.invalid', now());
  insert into public.expense_entry (id, expense_id, amount) values
    ('f5000000-0000-0000-0000-000000000001', 'e5000000-0000-0000-0000-000000000001', 12);
  insert into public.expense_entry_share (expense_entry_id, email, percentage) values
    ('f5000000-0000-0000-0000-000000000001', 'b@x.test', 50),
    ('f5000000-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 50);
  perform set_config('role', 'authenticated', true);
  perform public.join_group('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid');
  perform set_config('role', 'postgres', true);
  if (select paid_by from public.expense where id = 'e5000000-0000-0000-0000-000000000001') <> 'd@x.test' then
    raise exception 'G1 payer not moved';
  end if;
  if not exists (select 1 from public.expense_entry_share where expense_entry_id = 'f5000000-0000-0000-0000-000000000001' and email = 'd@x.test') then
    raise exception 'G1 share not moved';
  end if;
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid') then
    raise exception 'G1 guest membership kept';
  end if;
  if (select paid_by from public.expense where id = 'e4000000-0000-0000-0000-000000000001') <> 'guest+g2@guest.invalid' then
    raise exception 'G2 payer rewritten';
  end if;
  if (select count(*) from public.expense_entry_share where email = 'guest+g2@guest.invalid' and expense_entry_id in ('f3000000-0000-0000-0000-000000000001', 'f4000000-0000-0000-0000-000000000001')) <> 2 then
    raise exception 'G2 shares rewritten';
  end if;
  if not exists (select 1 from public.group_member where group_id = '22222222-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid') then
    raise exception 'G2 membership lost';
  end if;
  if not exists (select 1 from public."user" where email = 'guest+g2@guest.invalid') then
    raise exception 'two-group guest user row deleted';
  end if;
end
$c$$q$, 'ok');
select t('join_group: soft-removed member re-joins claiming a guest', 'b@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test';
  perform set_config('role', 'authenticated', true);
  perform public.join_group('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid');
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test' and removed_at is null) <> 1 then
    raise exception 'membership not re-activated exactly once';
  end if;
  if (select paid_by from public.expense where id = 'e2000000-0000-0000-0000-000000000001') <> 'b@x.test' then
    raise exception 'payer not moved';
  end if;
  if exists (select 1 from public.expense_entry_share where email = 'guest+g1@guest.invalid') then
    raise exception 'guest shares left';
  end if;
end
$c$$q$, 'ok');
select t('join_group: outsider joins as a new member', 'd@x.test', $q$
do $c$
begin
  perform public.join_group('11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if (select count(*) from public.group_member where group_id = '11111111-0000-0000-0000-000000000001') <> 5 then
    raise exception 'expected exactly one new membership';
  end if;
  if (select count(*) from public."user" where is_guest) <> 2 then
    raise exception 'a guest user row was deleted';
  end if;
end
$c$$q$, 'ok');
select t('join_group: active member, no guest', 'a@x.test', $q$select public.join_group('11111111-0000-0000-0000-000000000001')$q$, 'ok:1');
-- ===== refusals =====
select t('join_group refuses a real user as the guest', 'd@x.test', $q$select public.join_group('11111111-0000-0000-0000-000000000001', 'b@x.test')$q$, 'err');
select t('join_group refuses a guest of another group', 'd@x.test', $q$select public.join_group('22222222-0000-0000-0000-000000000001', 'guest+g1@guest.invalid')$q$, 'err');
select t('join_group refuses a soft-removed guest', 'd@x.test', $q$
  select set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid';
  select set_config('role', 'authenticated', true);
  select public.join_group('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid')$q$, 'err');
select t('join_group refuses a session with no email', 'd@x.test', $q$
  select set_config('request.jwt.claims', '{"role":"authenticated","sub":"dddddddd-0000-0000-0000-000000000001"}', true);
  select public.join_group('11111111-0000-0000-0000-000000000001')$q$, 'err');
select t('join_group: anon reaches nothing', 'anon', $q$select public.join_group('11111111-0000-0000-0000-000000000001')$q$, 'err');
-- ===== atomic outcome =====
-- a already holds a share on each of the guest's entries (PK expense_entry_id, email):
-- the rewrite collides and the whole join rolls back instead of half-merging.
select t('join_group: a colliding share rolls the whole join back', 'a@x.test', $q$select public.join_group('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid')$q$, 'err');
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result order by n;
