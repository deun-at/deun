-- removed-member-access: a soft-removed member reads and changes nothing of the
-- group they were removed from; re-joining by the current invite token or being
-- re-added by an active member restores access; active members keep seeing the
-- removed member's rows; the creator column grants nothing once a group has a
-- member row. Run after 30_cases.sql, once every migration in the tree is
-- applied in order as supabase_admin (*_removed_member_access.sql last).
-- Throwaway local Postgres only, never the live instance.
-- Seed: G1 (1111…, user_id a) {a, b, guest g1, guest g2}; G2 (2222…) {c, guest g2};
-- d is in no group. Here b is soft-removed from G1 for the whole file, and put
-- back at its end.
truncate test_result;
-- Known invite tokens, as 40 and 80 pin them.
update public."group" set invite_token = 'a1000000-0000-4000-8000-000000000001' where id = '11111111-0000-0000-0000-000000000001';
update public."group" set invite_token = 'a2000000-0000-4000-8000-000000000001' where id = '22222222-0000-0000-0000-000000000001';
update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test';
insert into public.expense_update_checker (group_id, expense_id, created_at) values ('11111111-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', now()) on conflict do nothing;
-- ===== soft-removed b reads nothing of G1 =====
select t('removed: reads no group row, so no invite token', 'b@x.test', $q$select id, invite_token from "group"$q$, 'ok:0');
select t('removed: reads only their own membership row', 'b@x.test', $q$select * from group_member$q$, 'ok:1');
select t('removed: reads no expenses', 'b@x.test', $q$select * from expense where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: reads no lines', 'b@x.test', $q$select * from expense_entry where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: reads no shares', 'b@x.test', $q$select * from expense_entry_share where expense_entry_id in ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: reads no balances', 'b@x.test', $q$select * from group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: reads no checker rows', 'b@x.test', $q$select group_id from group_update_checker where group_id = '11111111-0000-0000-0000-000000000001' union all select group_id from expense_update_checker where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: no token, no guests and no valid invite, as for a stranger', 'b@x.test', $q$
  select 1 from public.group_join_guests('11111111-0000-0000-0000-000000000001', null)
  union all select 1 where public.group_invite_valid('11111111-0000-0000-0000-000000000001', null)
    or public.group_invite_valid('11111111-0000-0000-0000-000000000001', 'a2000000-0000-4000-8000-000000000001')$q$, 'ok:0');
select t('removed: the current link lists the guests, as for a stranger holding it', 'b@x.test', $q$select * from public.group_join_guests('11111111-0000-0000-0000-000000000001', 'a1000000-0000-4000-8000-000000000001')$q$, 'ok:2');
-- ===== soft-removed b changes nothing in G1: direct writes =====
select t('removed: renames the group', 'b@x.test', $q$update "group" set name = 'X' where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: rewrites the invite token', 'b@x.test', $q$update "group" set invite_token = gen_random_uuid() where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: deletes the group', 'b@x.test', $q$delete from "group" where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: adds an expense', 'b@x.test', $q$insert into expense (group_id, name, paid_by, expense_date) values ('11111111-0000-0000-0000-000000000001', 'X', 'b@x.test', now())$q$, 'err');
select t('removed: rewrites expenses', 'b@x.test', $q$update expense set name = 'X' where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: deletes expenses', 'b@x.test', $q$delete from expense where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: adds a line', 'b@x.test', $q$insert into expense_entry (expense_id, amount) values ('e1000000-0000-0000-0000-000000000001', 1)$q$, 'err');
select t('removed: rewrites lines', 'b@x.test', $q$update expense_entry set amount = 0 where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: deletes lines', 'b@x.test', $q$delete from expense_entry where expense_id in ('e1000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: adds a share', 'b@x.test', $q$insert into expense_entry_share (expense_entry_id, email, percentage) values ('f1000000-0000-0000-0000-000000000001', 'b@x.test', 100)$q$, 'err');
select t('removed: rewrites shares', 'b@x.test', $q$update expense_entry_share set percentage = 0 where expense_entry_id in ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: deletes shares', 'b@x.test', $q$delete from expense_entry_share where expense_entry_id in ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('removed: adds a balance row', 'b@x.test', $q$insert into group_shares_summary (group_id, paid_by, paid_for, total_expenses, share_amount, total_share_amount) values ('11111111-0000-0000-0000-000000000001', 'b@x.test', 'b@x.test', 0, 0, 0)$q$, 'err');
select t('removed: rewrites balances', 'b@x.test', $q$update group_shares_summary set total_share_amount = 0 where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: deletes balances', 'b@x.test', $q$delete from group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: bumps the group checker', 'b@x.test', $q$insert into group_update_checker (group_id, created_at) values ('11111111-0000-0000-0000-000000000001', now()) on conflict (group_id) do update set created_at = now()$q$, 'err');
select t('removed: rewrites the group checker', 'b@x.test', $q$update group_update_checker set created_at = now() where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: adds an expense checker', 'b@x.test', $q$insert into expense_update_checker (group_id, expense_id, created_at) values ('11111111-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000001', now())$q$, 'err');
select t('removed: rewrites an expense checker', 'b@x.test', $q$update expense_update_checker set created_at = now() where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: adds someone to the group', 'b@x.test', $q$insert into group_member (group_id, email) values ('11111111-0000-0000-0000-000000000001', 'd@x.test')$q$, 'err');
select t('removed: soft-removes an active member', 'b@x.test', $q$update group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'a@x.test'$q$, 'ok:0');
select t('removed: deletes memberships, their own included', 'b@x.test', $q$delete from group_member where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('removed: clears their own removed_at', 'b@x.test', $q$update group_member set removed_at = null where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test'$q$, 'ok:0');
select t('removed: stars the group on their own row', 'b@x.test', $q$update group_member set is_favorite = true where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test'$q$, 'ok:0');
-- ===== soft-removed b changes nothing in G1: every RPC refuses =====
select t('removed: save_group_all edit', 'b@x.test', $q$select save_group_all('{"id":"11111111-0000-0000-0000-000000000001","name":"X","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"bbbbbbbb-0000-0000-0000-000000000001"}', '[]')$q$, 'err');
select t('removed: save_group_all re-adding themselves', 'b@x.test', $q$select save_group_all('{"id":"11111111-0000-0000-0000-000000000001","name":"G1","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"bbbbbbbb-0000-0000-0000-000000000001"}', '[{"email":"b@x.test"}]')$q$, 'err');
select t('removed: save_expense_all new', 'b@x.test', $q$select save_expense_all('11111111-0000-0000-0000-000000000001', '{"group_id":"11111111-0000-0000-0000-000000000001","name":"X","paid_by":"b@x.test","expense_date":"2026-10-26"}', '[]')$q$, 'err');
select t('removed: save_expense_all edit', 'b@x.test', $q$select save_expense_all('11111111-0000-0000-0000-000000000001', '{"id":"e1000000-0000-0000-0000-000000000001","group_id":"11111111-0000-0000-0000-000000000001","name":"X","paid_by":"a@x.test","expense_date":"2026-10-26"}', '[]')$q$, 'err');
select t('removed: claim_set_unit_shares', 'b@x.test', $q$select claim_set_unit_shares('11111111-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', '[{"email":"b@x.test","percentage":100}]')$q$, 'err');
select t('removed: pay_back', 'b@x.test', $q$select pay_back('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5)$q$, 'err');
select t('removed: pay_back_exact', 'b@x.test', $q$select pay_back_exact('11111111-0000-0000-0000-000000000001', 'guest+g1@guest.invalid', 'a@x.test', 5)$q$, 'err');
select t('removed: add_group_member re-adding themselves', 'b@x.test', $q$select add_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test')$q$, 'err');
select t('removed: add_group_member adding someone', 'b@x.test', $q$select add_group_member('11111111-0000-0000-0000-000000000001', 'd@x.test')$q$, 'err');
select t('removed: remove_group_member', 'b@x.test', $q$select remove_group_member('11111111-0000-0000-0000-000000000001', 'guest+g2@guest.invalid', 0.005)$q$, 'err');
select t('removed: delete_group deletes nothing', 'b@x.test', $q$
do $c$
begin
  perform public.delete_group('11111111-0000-0000-0000-000000000001');
  perform set_config('role', 'postgres', true);
  if not exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'a soft-removed member deleted the group';
  end if;
end
$c$$q$, 'ok');
select t('removed: delete_expense', 'b@x.test', $q$select delete_expense('e1000000-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001')$q$, 'err');
select t('removed: reset_group_invite', 'b@x.test', $q$select reset_group_invite('11111111-0000-0000-0000-000000000001')$q$, 'err');
select t('removed: update_group_member_shares', 'b@x.test', $q$select update_group_member_shares('11111111-0000-0000-0000-000000000001', null)$q$, 'err');
select t('removed: join_group without the token', 'b@x.test', $q$select join_group('11111111-0000-0000-0000-000000000001', null)$q$, 'err');
-- ===== re-join =====
select t('re-join: join_group with the current token restores reads and writes', 'b@x.test', $q$
do $c$
begin
  perform public.join_group('11111111-0000-0000-0000-000000000001', 'a1000000-0000-4000-8000-000000000001');
  if not exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'no group row after re-join';
  end if;
  if not exists (select 1 from public.expense where group_id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'no expenses after re-join';
  end if;
  update public."group" set name = 'G1b' where id = '11111111-0000-0000-0000-000000000001';
  if not found then
    raise exception 'cannot write after re-join';
  end if;
end
$c$$q$, 'ok');
select t('re-join: an active member''s add_group_member restores access', 'a@x.test', $q$
do $c$
declare _r text;
begin
  _r := public.add_group_member('11111111-0000-0000-0000-000000000001', 'b@x.test');
  if _r is distinct from 're_added' then raise exception 'answered %', _r; end if;
  perform set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000001","email":"b@x.test","role":"authenticated"}', true);
  if not exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'no group row after re-add';
  end if;
end
$c$$q$, 'ok');
select t('re-join: an active member''s save_group_all re-add restores access', 'a@x.test', $q$
do $c$
begin
  perform public.save_group_all('{"id":"11111111-0000-0000-0000-000000000001","name":"G1","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"aaaaaaaa-0000-0000-0000-000000000001"}', '[{"email":"b@x.test"}]');
  perform set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000001","email":"b@x.test","role":"authenticated"}', true);
  if not exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'no group row after re-add';
  end if;
end
$c$$q$, 'ok');
-- ===== active members keep everything =====
select t('active: still sees the removed member''s row and, after a recalc, their balance', 'a@x.test', $q$
do $c$
begin
  if not exists (select 1 from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test' and removed_at is not null) then
    raise exception 'removed member''s row not visible';
  end if;
  perform public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  if not exists (select 1 from public.group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001' and paid_for = 'b@x.test') then
    raise exception 'removed member''s balance row gone';
  end if;
end
$c$$q$, 'ok');
select t('active: a soft-removed guest still counts against deleting its user row', 'a@x.test', $q$
  select set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid';
  select set_config('role', 'authenticated', true);
  delete from "user" where email = 'guest+g1@guest.invalid'$q$, 'ok:0');
-- ===== the creator column =====
select t('creator: a brand-new group, then the creator''s own row', 'a@x.test', $q$
do $c$
declare _id uuid;
begin
  insert into public."group" (name, user_id) values ('Fresh', 'aaaaaaaa-0000-0000-0000-000000000001') returning id into _id;
  insert into public.group_member (group_id, email, is_favorite) values (_id, 'a@x.test', false);
  insert into public.group_member (group_id, email, is_favorite) values (_id, 'guest+g1@guest.invalid', false);
  if not exists (select 1 from public."group" where id = _id) then
    raise exception 'the creator cannot read the new group';
  end if;
end
$c$$q$, 'ok');
select t('creator: once the group has a member row, the creator column admits nobody', 'a@x.test', $q$
do $c$
begin
  insert into public."group" (id, name, user_id) values ('33333333-0000-0000-0000-000000000001', 'G3', 'aaaaaaaa-0000-0000-0000-000000000001');
  insert into public.group_member (group_id, email) values ('33333333-0000-0000-0000-000000000001', 'guest+g1@guest.invalid');
  if exists (select 1 from public."group" where id = '33333333-0000-0000-0000-000000000001') then
    raise exception 'the creator column still reads the group';
  end if;
  begin
    insert into public.group_member (group_id, email) values ('33333333-0000-0000-0000-000000000001', 'a@x.test');
    raise exception 'the creator column admitted a row';
  exception when insufficient_privilege then null;
  end;
end
$c$$q$, 'ok');
select t('creator: a hard-removed last editor reads nothing and cannot put themselves back', 'a@x.test', $q$
do $c$
begin
  perform set_config('role', 'postgres', true);
  delete from public.group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'a@x.test';
  perform set_config('role', 'authenticated', true);
  if exists (select 1 from public."group" where id = '11111111-0000-0000-0000-000000000001') then
    raise exception 'the last editor still reads the group';
  end if;
  begin
    insert into public.group_member (group_id, email) values ('11111111-0000-0000-0000-000000000001', 'a@x.test');
    raise exception 'the last editor put themselves back';
  exception when insufficient_privilege then null;
  end;
end
$c$$q$, 'ok');
select t('creator: a soft-removed last editor reads nothing', 'a@x.test', $q$
  select set_config('role', 'postgres', true);
  update public.group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'a@x.test';
  select set_config('role', 'authenticated', true);
  select id, invite_token from "group" where id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
-- b back to active for whatever runs next.
update public.group_member set removed_at = null where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test';
delete from public.expense_update_checker where group_id = '11111111-0000-0000-0000-000000000001' and expense_id = 'e1000000-0000-0000-0000-000000000001';
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result where not pass order by n;
