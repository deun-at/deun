-- rls-stopgap follow-up — close what the 2026-10-25 security review found in
-- 20261025180000_rls_stopgap.sql.
--
-- 1. group_member was readable by every signed-in user, so every group id could be
--    listed, and the INSERT policy lets anyone add their own row to a group by id
--    (the invite-link join). Together: anyone could join any group and then read
--    its expenses, shares and IBANs. Reads are now limited to the caller's own
--    groups and own rows, so a group id is known only through its invite link.
--    Cost, accepted until guest-merge-rpc: a joiner who is not a member yet sees no
--    guests to claim on the join page; joining as a new member still works.
-- 2. A user could update their own membership row's group_id (another way into any
--    group) and their own user row's email / is_guest (email cascades into every
--    table). UPDATE is now granted per column, matching exactly what the app writes.
-- 3. The guest-delete check must see every membership, not only those visible to
--    the caller, or a guest from another group looks orphaned and its delete would
--    cascade away that group's history. It now asks a SECURITY DEFINER helper.
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261025180000. Idempotent.
-- Tested on the local Postgres 15.8 harness (supabase/tests/rls_stopgap/).

begin;

-- 3. membership lookup that ignores the caller's RLS -------------------------

create or replace function public.has_any_membership(_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.group_member gm where gm.email = _email);
$$;

revoke execute on function public.has_any_membership(text) from public, anon;
grant execute on function public.has_any_membership(text) to authenticated, service_role;

drop policy if exists "user: delete orphaned guest" on public."user";
create policy "user: delete orphaned guest" on public."user"
  for delete to authenticated
  using (is_guest and not public.has_any_membership(email));

-- 1. memberships readable only inside the caller's own groups ------------------

drop policy if exists "group_member: signed-in read" on public.group_member;
drop policy if exists "group_member: read own groups" on public.group_member;
-- No sub-select in this policy: it is expanded inside other tables' policies that
-- read group_member (group, expense, …) while a group_member write is being
-- checked, and a sub-select here makes Postgres report infinite recursion.
create policy "group_member: read own groups" on public.group_member
  for select to authenticated
  using (
    email = (auth.jwt() ->> 'email')
    or public.is_group_member(group_id)
  );

-- 2. UPDATE only on the columns the app writes --------------------------------

revoke update on public.group_member from authenticated;
grant update (is_favorite, removed_at) on public.group_member to authenticated;

revoke update on public."user" from authenticated;
grant update (display_name, first_name, last_name, locale, paypal_me, iban, username, username_code)
  on public."user" to authenticated;

commit;
