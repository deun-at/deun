truncate test_result;
-- ===== anon: reaches nothing =====
select t('anon reads tokens', 'anon', $q$select * from device_tokens$q$, 'err');
select t('anon reads shares', 'anon', $q$select * from expense_entry_share$q$, 'err');
select t('anon reads users', 'anon', $q$select * from "user"$q$, 'err');
select t('anon reads groups', 'anon', $q$select * from "group"$q$, 'err');
select t('anon updates a user', 'anon', $q$update "user" set iban = 'X' where email = 'a@x.test'$q$, 'err');
select t('anon deletes a user', 'anon', $q$delete from "user" where email = 'c@x.test'$q$, 'err');
select t('anon adds a member', 'anon', $q$insert into group_member (group_id, email) values ('11111111-0000-0000-0000-000000000001', 'd@x.test')$q$, 'err');
select t('anon calls contact match', 'anon', $q$select * from match_contacts_by_email(array['a@x.test'], array[]::text[])$q$, 'err');
-- ===== member a: reads =====
select t('member reads own group summary', 'a@x.test', $q$select * from group_shares_summary where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:>0');
select t('member reads no foreign summary', 'a@x.test', $q$select * from group_shares_summary where group_id = '22222222-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('member reads own group shares', 'a@x.test', $q$select s.* from expense_entry_share s join expense_entry ee on ee.id = s.expense_entry_id join expense e on e.id = ee.expense_id where e.group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:>0');
select t('member reads no foreign shares', 'a@x.test', $q$select * from expense_entry_share where expense_entry_id in ('f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001')$q$, 'ok:0');
select t('member reads no foreign lines', 'a@x.test', $q$select * from expense_entry where id = 'f3000000-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('member sees only own token', 'a@x.test', $q$select * from device_tokens$q$, 'ok:1');
select t('member reads all users (search)', 'a@x.test', $q$select * from "user"$q$, 'ok:6');
select t('member reads memberships of own groups only', 'a@x.test', $q$select * from group_member$q$, 'ok:4');
select t('member: contact match', 'a@x.test', $q$select * from match_contacts_by_email(array['c@x.test','d@x.test'], array[]::text[])$q$, 'ok:2');
select t('member: spending summary', 'a@x.test', $q$select * from get_user_spending_summary('a@x.test', '2000-01-01', '2100-01-01')$q$, 'ok:>0');
-- ===== user rows =====
select t('sign-in upsert, existing row', 'a@x.test', $q$insert into "user" (email, user_id, display_name) values ('a@x.test', 'aaaaaaaa-0000-0000-0000-000000000001', '-') on conflict do nothing$q$, 'ok:0');
select t('sign-in upsert, first sign-in', 'e@x.test', $q$insert into "user" (email, user_id, display_name) values ('e@x.test', 'eeeeeeee-0000-0000-0000-000000000001', '-') on conflict do nothing$q$, 'ok:1');
select t('profile save, own row', 'a@x.test', $q$update "user" set iban = 'AT-NEW', display_name = 'A2' where email = 'a@x.test'$q$, 'ok:1');
select t('username save, own row', 'a@x.test', $q$update "user" set username = 'anna', username_code = '1234' where email = 'a@x.test'$q$, 'ok:1');
select t('update someone else', 'a@x.test', $q$update "user" set iban = 'EVIL' where email = 'c@x.test'$q$, 'ok:0');
select t('delete a real user', 'a@x.test', $q$delete from "user" where email = 'c@x.test'$q$, 'ok:0');
select t('delete a guest still in a group', 'a@x.test', $q$delete from "user" where email = 'guest+g1@guest.invalid'$q$, 'ok:0');
select t('createGuest', 'a@x.test', $q$insert into "user" (email, display_name, is_guest) values ('guest+171@guest.invalid', 'New guest', true)$q$, 'ok:1');
select t('insert someone else as real user', 'a@x.test', $q$insert into "user" (email, display_name) values ('evil@x.test', 'E')$q$, 'err');
select t('insert guest outside guest domain', 'a@x.test', $q$insert into "user" (email, display_name, is_guest) values ('x@x.test', 'E', true)$q$, 'err');
-- ===== RPCs as member =====
select t('save_expense_all, new in own group', 'a@x.test', $q$select save_expense_all('11111111-0000-0000-0000-000000000001', '{"group_id":"11111111-0000-0000-0000-000000000001","name":"Dinner","paid_by":"a@x.test","expense_date":"2026-10-25","user_id":"aaaaaaaa-0000-0000-0000-000000000001"}', '[{"entry":{"name":"l1","amount":12,"quantity":1,"split_mode":"equal","sort_id":0},"shares":[{"email":"a@x.test","percentage":50},{"email":"b@x.test","percentage":50}]}]')$q$, 'ok:1');
select t('save_expense_all, edit existing', 'a@x.test', $q$select save_expense_all('11111111-0000-0000-0000-000000000001', '{"id":"e1000000-0000-0000-0000-000000000001","group_id":"11111111-0000-0000-0000-000000000001","name":"E1b","paid_by":"a@x.test","expense_date":"2026-10-25"}', '[{"entry":{"amount":30,"quantity":1,"split_mode":"equal","sort_id":0},"shares":[{"email":"a@x.test","percentage":100}]}]')$q$, 'ok:1');
select t('save_expense_all, foreign group', 'a@x.test', $q$select save_expense_all('22222222-0000-0000-0000-000000000001', '{"group_id":"22222222-0000-0000-0000-000000000001","name":"X","paid_by":"a@x.test","expense_date":"2026-10-25"}', '[]')$q$, 'err');
select t('claim_set_unit_shares, own group', 'a@x.test', $q$select claim_set_unit_shares('11111111-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', '[{"email":"a@x.test","percentage":100}]')$q$, 'ok:1');
select t('claim_set_unit_shares, foreign group', 'a@x.test', $q$select claim_set_unit_shares('22222222-0000-0000-0000-000000000001', 'e3000000-0000-0000-0000-000000000001', 'f3000000-0000-0000-0000-000000000001', '[{"email":"a@x.test","percentage":100}]')$q$, 'err');
select t('pay_back, own group', 'a@x.test', $q$select pay_back('11111111-0000-0000-0000-000000000001', 'b@x.test', 'a@x.test', 5)$q$, 'ok:1');
select t('pay_back_exact, own group', 'a@x.test', $q$select pay_back_exact('11111111-0000-0000-0000-000000000001', 'b@x.test', 'a@x.test', 5)$q$, 'ok:1');
select t('pay_back, foreign group', 'a@x.test', $q$select pay_back('22222222-0000-0000-0000-000000000001', 'c@x.test', 'guest+g2@guest.invalid', 5)$q$, 'err');
select t('recalc, own group', 'a@x.test', $q$select update_group_member_shares('11111111-0000-0000-0000-000000000001', null)$q$, 'ok:1');
select t('recalc, foreign group', 'a@x.test', $q$select update_group_member_shares('22222222-0000-0000-0000-000000000001', null)$q$, 'err');
select t('save_group_all, create', 'a@x.test', $q$select save_group_all('{"name":"New","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"aaaaaaaa-0000-0000-0000-000000000001"}', '[{"email":"a@x.test"}]')$q$, 'ok:1');
select t('save_group_all, create, guest listed first', 'a@x.test', $q$select save_group_all('{"name":"New2","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"aaaaaaaa-0000-0000-0000-000000000001"}', '[{"is_guest_pending":true,"display_name":"Gx"},{"email":"a@x.test"}]')$q$, 'ok:1');
select t('save_group_all, edit own group', 'a@x.test', $q$select save_group_all('{"id":"11111111-0000-0000-0000-000000000001","name":"G1b","color_value":1,"simplified_expenses":false,"currency_code":"EUR","user_id":"aaaaaaaa-0000-0000-0000-000000000001"}', '[]')$q$, 'ok:1');
-- ===== membership writes =====
select t('add a member to own group', 'a@x.test', $q$insert into group_member (group_id, email, is_favorite) values ('11111111-0000-0000-0000-000000000001', 'd@x.test', false)$q$, 'ok:1');
select t('add a member to foreign group', 'a@x.test', $q$insert into group_member (group_id, email) values ('22222222-0000-0000-0000-000000000001', 'd@x.test')$q$, 'err');
select t('soft-remove in own group', 'a@x.test', $q$update group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test'$q$, 'ok:1');
select t('soft-remove in foreign group', 'a@x.test', $q$update group_member set removed_at = now() where group_id = '22222222-0000-0000-0000-000000000001' and email = 'c@x.test'$q$, 'ok:0');
select t('hard-remove in own group', 'a@x.test', $q$delete from group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid'$q$, 'ok:1');
select t('hard-remove in foreign group', 'a@x.test', $q$delete from group_member where group_id = '22222222-0000-0000-0000-000000000001' and email = 'c@x.test'$q$, 'ok:0');
select t('favourite toggle', 'a@x.test', $q$update group_member set is_favorite = true where group_id = '11111111-0000-0000-0000-000000000001' and email = 'a@x.test'$q$, 'ok:1');
-- ===== tokens, reminders, friendships =====
select t('register own token', 'a@x.test', $q$insert into device_tokens (user_id, token) values ('aaaaaaaa-0000-0000-0000-000000000001', 'tokA2') on conflict do nothing$q$, 'ok:1');
select t('register token for someone else', 'a@x.test', $q$insert into device_tokens (user_id, token) values ('cccccccc-0000-0000-0000-000000000001', 'evil')$q$, 'err');
select t('sign-out deletes own token', 'a@x.test', $q$delete from device_tokens where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and token = 'tokA'$q$, 'ok:1');
select t('delete someone else''s token', 'a@x.test', $q$delete from device_tokens where token = 'tokC'$q$, 'ok:0');
select t('send reminder', 'a@x.test', $q$insert into payment_reminder (group_id, reminder_from, reminder_to) values ('11111111-0000-0000-0000-000000000001', 'a@x.test', 'b@x.test')$q$, 'ok:1');
select t('friend request', 'a@x.test', $q$insert into friendship (requester, addressee) values ('a@x.test', 'd@x.test') on conflict do nothing$q$, 'ok:1');
-- ===== deletes (client paths) =====
select t('expense delete flow', 'a@x.test', $q$delete from expense where id = 'e1000000-0000-0000-0000-000000000001'; delete from expense_update_checker where expense_id = 'e1000000-0000-0000-0000-000000000001'; select update_group_member_shares('11111111-0000-0000-0000-000000000001', null)$q$, 'ok:1');
select t('delete a foreign expense', 'a@x.test', $q$delete from expense where id = 'e3000000-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('group delete flow', 'a@x.test', $q$delete from "group" where id = '11111111-0000-0000-0000-000000000001'; delete from group_update_checker where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok');
select t('delete a foreign group', 'a@x.test', $q$delete from "group" where id = '22222222-0000-0000-0000-000000000001'$q$, 'ok:0');
-- ===== invite-link join by d (today's client flow) =====
select t('join claiming a one-group guest', 'd@x.test', $q$
  insert into group_member (group_id, email, is_favorite) values ('11111111-0000-0000-0000-000000000001', 'd@x.test', false);
  update expense set paid_by = 'd@x.test' where paid_by = 'guest+g1@guest.invalid';
  update expense_entry_share set email = 'd@x.test' where email = 'guest+g1@guest.invalid';
  delete from group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g1@guest.invalid';
  delete from "user" where email = 'guest+g1@guest.invalid';
  select update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  select 1 from "user" where email = 'guest+g1@guest.invalid'$q$, 'ok:0');
select t('join claiming a two-group guest keeps the other group', 'd@x.test', $q$
  insert into group_member (group_id, email, is_favorite) values ('11111111-0000-0000-0000-000000000001', 'd@x.test', false);
  update expense set paid_by = 'd@x.test' where paid_by = 'guest+g2@guest.invalid';
  update expense_entry_share set email = 'd@x.test' where email = 'guest+g2@guest.invalid';
  delete from group_member where group_id = '11111111-0000-0000-0000-000000000001' and email = 'guest+g2@guest.invalid';
  delete from "user" where email = 'guest+g2@guest.invalid';
  select update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
  select set_config('role', 'postgres', true);
  select 1 from expense_entry_share where email = 'guest+g2@guest.invalid'
  union all select 1 from expense where paid_by = 'guest+g2@guest.invalid'
  union all select 1 from "user" where email = 'guest+g2@guest.invalid'$q$, 'ok:4');
select t('re-join after soft removal', 'b@x.test', $q$update group_member set removed_at = null where group_id = '11111111-0000-0000-0000-000000000001' and email = 'b@x.test'$q$, 'ok:1');
-- ===== stranger c against group G1 =====
select t('stranger soft-removes a G1 member', 'c@x.test', $q$update group_member set removed_at = now() where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger deletes G1 members', 'c@x.test', $q$delete from group_member where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger adds someone to G1', 'c@x.test', $q$insert into group_member (group_id, email) values ('11111111-0000-0000-0000-000000000001', 'd@x.test')$q$, 'err');
select t('stranger joins G1 by id (invite model)', 'c@x.test', $q$insert into group_member (group_id, email) values ('11111111-0000-0000-0000-000000000001', 'c@x.test')$q$, 'ok:1');
select t('stranger reads G1 shares', 'c@x.test', $q$select * from expense_entry_share where expense_entry_id = 'f1000000-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger rewrites G1 shares', 'c@x.test', $q$update expense_entry_share set percentage = 0 where expense_entry_id = 'f1000000-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('stranger reads a''s token', 'c@x.test', $q$select * from device_tokens where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$q$, 'ok:0');
-- ===== follow-up (security review 2026-10-25) =====
select t('stranger lists G1 roster', 'c@x.test', $q$select * from group_member where group_id = '11111111-0000-0000-0000-000000000001'$q$, 'ok:0');
select t('outsider cannot list any group ids', 'd@x.test', $q$select distinct group_id from group_member$q$, 'ok:0');
select t('member moves own membership to another group', 'a@x.test', $q$update group_member set group_id = '22222222-0000-0000-0000-000000000001' where email = 'a@x.test'$q$, 'err');
select t('member renames own membership email', 'a@x.test', $q$update group_member set email = 'x@x.test' where email = 'a@x.test'$q$, 'err');
select t('user changes own email', 'a@x.test', $q$update "user" set email = 'new@x.test' where email = 'a@x.test'$q$, 'err');
select t('user turns self into guest', 'a@x.test', $q$update "user" set is_guest = true where email = 'a@x.test'$q$, 'err');
select t('delete a guest whose only group the caller cannot see', 'a@x.test', $q$
  select set_config('role', 'postgres', true);
  insert into "user" (email, display_name, is_guest) values ('guest+g3@guest.invalid', 'Guest3', true);
  insert into group_member (group_id, email) values ('22222222-0000-0000-0000-000000000001', 'guest+g3@guest.invalid');
  select set_config('role', 'authenticated', true);
  delete from "user" where email = 'guest+g3@guest.invalid'$q$, 'ok:0');
select format('%s/%s passed', count(*) filter (where pass), count(*)) from test_result;
select n, name, actor, expect, got from test_result where not pass order by n;
