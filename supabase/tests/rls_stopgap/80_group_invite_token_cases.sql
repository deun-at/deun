-- group-id-leak: a group id alone joins nothing and lists no guests; the current
-- invite token does, and a member's reset retires the old one.
-- Run after 30_cases.sql, once the *_group_invite_token.sql migration is applied as
-- supabase_admin. Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…) {a, b, guest g1, guest g2}; G2 (2222…) {c, guest g2}; d is in no group.
truncate test_result;
-- ===== the backfill: every group got its own token (before the fixture pins two) =====
select t('backfill: no two groups share an invite token', 'a@x.test', $q$
  select set_config('role', 'postgres', true);
  select invite_token from public."group" group by invite_token having count(*) > 1$q$, 'ok:0');
-- Known tokens for the cases below.
update public."group" set invite_token = 'a1000000-0000-4000-8000-000000000001' where id = '11111111-0000-0000-0000-000000000001';
update public."group" set invite_token = 'a2000000-0000-4000-8000-000000000001' where id = '22222222-0000-0000-0000-000000000001';
-- ===== join_group without the current token: refused with DE401, nothing written =====
select t('join_group with no token is refused', 'd@x.test', $q$
do $c$
begin
  begin
    perform public.join_group('11111111-0000-0000-0000-000000000001', null);
    raise exception 'joined without a token';
  exception when sqlstate 'DE401' then null;
  end;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test') then
    raise exception 'membership written';
  end if;
end
$c$$q$, 'ok');
select t('join_group with another group''s token is refused', 'd@x.test', $q$
do $c$
begin
  begin
    perform public.join_group('11111111-0000-0000-0000-000000000001', 'a2000000-0000-4000-8000-000000000001');
    raise exception 'joined with a wrong token';
  exception when sqlstate 'DE401' then null;
  end;
  perform set_config('role', 'postgres', true);
  if exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test') then
    raise exception 'membership written';
  end if;
end
$c$$q$, 'ok');
-- ===== reset: an active member retires every earlier link =====
select t('reset by a member: a new token, the old one refused for joins and guests, the new one joins', 'd@x.test', $q$
do $c$
declare
  _new uuid;
  _n integer;
begin
  perform set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","email":"a@x.test","role":"authenticated"}', true);
  _new := public.reset_group_invite('11111111-0000-0000-0000-000000000001');
  if _new is null or _new = 'a1000000-0000-4000-8000-000000000001' then
    raise exception 'no new token: %', _new;
  end if;
  perform set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000001","email":"d@x.test","role":"authenticated"}', true);
  select count(*) into _n from public.group_join_guests('11111111-0000-0000-0000-000000000001', 'a1000000-0000-4000-8000-000000000001');
  if _n <> 0 then
    raise exception 'old token still lists % guests', _n;
  end if;
  begin
    perform public.join_group('11111111-0000-0000-0000-000000000001', 'a1000000-0000-4000-8000-000000000001');
    raise exception 'joined with the token from before the reset';
  exception when sqlstate 'DE401' then null;
  end;
  perform public.join_group('11111111-0000-0000-0000-000000000001', _new);
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'd@x.test' and removed_at is null) then
    raise exception 'the new token did not join';
  end if;
end
$c$$q$, 'ok');
select t('reset bumps the group checker other members listen on', 'a@x.test', $q$
do $c$
begin
  perform public.reset_group_invite('11111111-0000-0000-0000-000000000001');
  if (select created_at from public.group_update_checker where group_id = '11111111-0000-0000-0000-000000000001') <> now() then
    raise exception 'group checker not bumped';
  end if;
end
$c$$q$, 'ok');
select t('a non-member cannot reset', 'c@x.test', $q$select public.reset_group_invite('11111111-0000-0000-0000-000000000001')$q$, 'err');
select t('reset_group_invite refuses a soft-removed member', 'b@x.test', $q$
  select set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test';
  select set_config('role', 'authenticated', true);
  select public.reset_group_invite('11111111-0000-0000-0000-000000000001')$q$, 'err');
-- ===== guests and the validity check without the token =====
select t('join guests without a valid token list nothing', 'd@x.test', $q$
  select * from public.group_join_guests('11111111-0000-0000-0000-000000000001', null)
  union all select * from public.group_join_guests('11111111-0000-0000-0000-000000000001', 'a2000000-0000-4000-8000-000000000001')$q$, 'ok:0');
select t('the validity check says yes only to the current token', 'd@x.test', $q$
  select 1 where public.group_invite_valid('11111111-0000-0000-0000-000000000001', 'a1000000-0000-4000-8000-000000000001')
    and not public.group_invite_valid('11111111-0000-0000-0000-000000000001', 'a2000000-0000-4000-8000-000000000001')
    and not public.group_invite_valid('11111111-0000-0000-0000-000000000001', null)$q$, 'ok:1');
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result where not pass order by n;
