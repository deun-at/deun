-- Test world: G1 (creator a; members a, b, guest g1, guest g2), G2 (creator c; members c, guest g2).
-- d has an account but no group (the invite-link joiner). guest g2 sits in both groups.
insert into auth.users (id, email) values
 ('aaaaaaaa-0000-0000-0000-000000000001','a@x.test'),
 ('bbbbbbbb-0000-0000-0000-000000000001','b@x.test'),
 ('cccccccc-0000-0000-0000-000000000001','c@x.test'),
 ('dddddddd-0000-0000-0000-000000000001','d@x.test'),
 ('eeeeeeee-0000-0000-0000-000000000001','e@x.test');
insert into public."user" (email, display_name, user_id, iban) values
 ('a@x.test','A','aaaaaaaa-0000-0000-0000-000000000001','AT-A'),
 ('b@x.test','B','bbbbbbbb-0000-0000-0000-000000000001','AT-B'),
 ('c@x.test','C','cccccccc-0000-0000-0000-000000000001','AT-C'),
 ('d@x.test','D','dddddddd-0000-0000-0000-000000000001',null);
insert into public."user" (email, display_name, is_guest) values
 ('guest+g1@guest.invalid','Guest1',true), ('guest+g2@guest.invalid','Guest2',true);
insert into public."group" (id, name, user_id) values
 ('11111111-0000-0000-0000-000000000001','G1','aaaaaaaa-0000-0000-0000-000000000001'),
 ('22222222-0000-0000-0000-000000000001','G2','cccccccc-0000-0000-0000-000000000001');
insert into public.group_member (group_id, email) values
 ('11111111-0000-0000-0000-000000000001','a@x.test'), ('11111111-0000-0000-0000-000000000001','b@x.test'),
 ('11111111-0000-0000-0000-000000000001','guest+g1@guest.invalid'), ('11111111-0000-0000-0000-000000000001','guest+g2@guest.invalid'),
 ('22222222-0000-0000-0000-000000000001','c@x.test'), ('22222222-0000-0000-0000-000000000001','guest+g2@guest.invalid');
insert into public.expense (id, group_id, name, paid_by, expense_date) values
 ('e1000000-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','E1','a@x.test',now()),
 ('e2000000-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','E2','guest+g1@guest.invalid',now()),
 ('e3000000-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001','E3','c@x.test',now()),
 ('e4000000-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001','E4','guest+g2@guest.invalid',now());
insert into public.expense_entry (id, expense_id, amount) values
 ('f1000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001',30),
 ('f2000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001',20),
 ('f3000000-0000-0000-0000-000000000001','e3000000-0000-0000-0000-000000000001',10),
 ('f4000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001',8);
insert into public.expense_entry_share (expense_entry_id, email, percentage) values
 ('f1000000-0000-0000-0000-000000000001','a@x.test',50), ('f1000000-0000-0000-0000-000000000001','guest+g1@guest.invalid',50),
 ('f2000000-0000-0000-0000-000000000001','a@x.test',50), ('f2000000-0000-0000-0000-000000000001','guest+g1@guest.invalid',50),
 ('f3000000-0000-0000-0000-000000000001','c@x.test',50), ('f3000000-0000-0000-0000-000000000001','guest+g2@guest.invalid',50),
 ('f4000000-0000-0000-0000-000000000001','c@x.test',50), ('f4000000-0000-0000-0000-000000000001','guest+g2@guest.invalid',50);
insert into public.device_tokens (user_id, token) values
 ('aaaaaaaa-0000-0000-0000-000000000001','tokA'), ('cccccccc-0000-0000-0000-000000000001','tokC');
insert into public.friendship (requester, addressee, status) values ('a@x.test','c@x.test','accepted'), ('b@x.test','d@x.test','pending');
insert into public.payment_reminder (group_id, reminder_from, reminder_to) values ('11111111-0000-0000-0000-000000000001','a@x.test','b@x.test');
select public.update_group_member_shares('11111111-0000-0000-0000-000000000001', null);
select public.update_group_member_shares('22222222-0000-0000-0000-000000000001', null);
