-- rls-stopgap — close the live RLS and grant gaps found in the 2026-10-25 dump review.
--
-- NOT YET APPLIED. Jakob applies it by hand to the live instance (api.deun.app),
-- ahead of the rls-hardening feature (docs/ristretto/plans/rls-hardening.md),
-- which builds the full contract and its tests on top of this file.
-- Apply as supabase_admin: some public tables and functions are owned by it, and
-- only the owner can revoke on them or enable RLS. The file is idempotent.
-- Tested on a local Postgres 15.8 loaded with the live public schema
-- (2026-10-25); see the test script beside the hand-over notes.
--
-- Before this file:
--   - every public table was GRANT ALL to anon, so the web build's public anon key
--     could read and write app data;
--   - device_tokens, expense_entry, expense_entry_share, group_shares_summary and
--     birthday_signup had no RLS at all;
--   - "user" allowed SELECT/INSERT/UPDATE/DELETE to everyone (USING true), and a
--     user delete cascades away that user's expenses, shares and memberships;
--   - group_member allowed every operation to every signed-in user.
--
-- After it: anon reaches no table; the five open tables are scoped to group
-- membership (device_tokens to its owner); a user row changes only by its owner
-- (plus guest rows the app mints); group membership changes only from inside the
-- group, or by joining yourself through an invite link.
--
-- Reads of "user" and group_member stay open to every signed-in user (Jakob,
-- 2026-10-25: stranger search, contact matching and the join page's guest list
-- read them). Membership counts a soft-removed row, matching every existing policy.

begin;

-- 1. anon reaches no app table, sequence or function --------------------------

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from anon;

alter default privileges for role postgres, supabase_admin in schema public revoke all on tables from anon;
alter default privileges for role postgres, supabase_admin in schema public revoke all on sequences from anon;
alter default privileges for role postgres, supabase_admin in schema public revoke execute on functions from anon;

-- 2. one membership check, SECURITY DEFINER so group_member policies never recurse

create or replace function public.is_group_member(_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_member gm
    where gm.group_id = _group_id
      and gm.email = (select auth.jwt() ->> 'email')
  );
$$;

revoke execute on function public.is_group_member(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated, service_role;

-- 3. the tables that had no RLS ----------------------------------------------

alter table public.device_tokens enable row level security;
drop policy if exists "device_tokens: owner only" on public.device_tokens;
create policy "device_tokens: owner only" on public.device_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter table public.expense_entry enable row level security;
drop policy if exists "expense_entry: group members" on public.expense_entry;
create policy "expense_entry: group members" on public.expense_entry
  for all to authenticated
  using (exists (
    select 1 from public.expense e
    where e.id = expense_entry.expense_id
      and public.is_group_member(e.group_id)
  ))
  with check (exists (
    select 1 from public.expense e
    where e.id = expense_entry.expense_id
      and public.is_group_member(e.group_id)
  ));

alter table public.expense_entry_share enable row level security;
drop policy if exists "expense_entry_share: group members" on public.expense_entry_share;
create policy "expense_entry_share: group members" on public.expense_entry_share
  for all to authenticated
  using (exists (
    select 1
    from public.expense_entry ee
    join public.expense e on e.id = ee.expense_id
    where ee.id = expense_entry_share.expense_entry_id
      and public.is_group_member(e.group_id)
  ))
  with check (exists (
    select 1
    from public.expense_entry ee
    join public.expense e on e.id = ee.expense_id
    where ee.id = expense_entry_share.expense_entry_id
      and public.is_group_member(e.group_id)
  ));

alter table public.group_shares_summary enable row level security;
drop policy if exists "group_shares_summary: group members" on public.group_shares_summary;
create policy "group_shares_summary: group members" on public.group_shares_summary
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- dead leftover, nothing in the app uses it: RLS on, no policy = closed
alter table public.birthday_signup enable row level security;

-- 4. "user": read by any signed-in user, changed only by its owner --------------

drop policy if exists "Enable read access for all users" on public."user";
drop policy if exists "Enable insert for all users" on public."user";
drop policy if exists "Enable update for all users" on public."user";
drop policy if exists "Enable delete for all users" on public."user";

drop policy if exists "user: signed-in read" on public."user";
create policy "user: signed-in read" on public."user"
  for select to authenticated
  using (true);

-- own row (auth_gate upsert), or a guest row the app mints (createGuest, save_group_all)
drop policy if exists "user: insert own or guest" on public."user";
create policy "user: insert own or guest" on public."user"
  for insert to authenticated
  with check (
    email = (select auth.jwt() ->> 'email')
    or (is_guest and email like 'guest+%@guest.invalid')
  );

drop policy if exists "user: update own" on public."user";
create policy "user: update own" on public."user"
  for update to authenticated
  using (email = (select auth.jwt() ->> 'email'))
  with check (email = (select auth.jwt() ->> 'email'));

-- only a guest no group still names: every FK to "user" is ON DELETE CASCADE,
-- so any other delete would silently wipe expenses and shares in other groups
drop policy if exists "user: delete orphaned guest" on public."user";
create policy "user: delete orphaned guest" on public."user"
  for delete to authenticated
  using (
    is_guest
    and not exists (
      select 1 from public.group_member gm where gm.email = "user".email
    )
  );

-- 5. group_member: read by any signed-in user, changed from inside the group ----

drop policy if exists "Policy with security definer functions" on public.group_member;

drop policy if exists "group_member: signed-in read" on public.group_member;
create policy "group_member: signed-in read" on public.group_member
  for select to authenticated
  using (true);

-- yourself (invite-link join, the creator's own row), a member adding someone,
-- or the creator filling a group save_group_all just created
drop policy if exists "group_member: insert self or by member" on public.group_member;
create policy "group_member: insert self or by member" on public.group_member
  for insert to authenticated
  with check (
    email = (select auth.jwt() ->> 'email')
    or public.is_group_member(group_id)
    or exists (
      select 1 from public."group" g
      where g.id = group_member.group_id
        and g.user_id = (select auth.uid())
    )
  );

-- favourite toggle and re-join on your own row; removed_at by members
drop policy if exists "group_member: update by member" on public.group_member;
create policy "group_member: update by member" on public.group_member
  for update to authenticated
  using (
    email = (select auth.jwt() ->> 'email')
    or public.is_group_member(group_id)
  )
  with check (
    email = (select auth.jwt() ->> 'email')
    or public.is_group_member(group_id)
  );

drop policy if exists "group_member: delete by member" on public.group_member;
create policy "group_member: delete by member" on public.group_member
  for delete to authenticated
  using (public.is_group_member(group_id));

commit;
