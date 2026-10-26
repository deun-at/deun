-- group-id-leak: a group id alone no longer joins a group or lists its guests.
-- Joining needs the group's current invite token.
--
-- Group ids leak (realtime DELETE payloads of expense_update_checker carry
-- {expense_id, group_id} to every subscriber). Until now an id was enough: the
-- stopgap's group_member INSERT policy admitted `email = own` for ANY group, and
-- group_join_guests listed a group's guests to whoever named it. After this file
-- an id grants nothing.
--
-- 1. "group".invite_token: a fresh random uuid per group, backfilled for every
--    existing row (a volatile default is evaluated per row). Readable only by
--    the group's members and its creator (the group SELECT policies), who are
--    exactly the people who may share it.
-- 2. group_member INSERT: the `email = own` branch is gone. A member adding
--    someone and the creator filling a group save_group_all just created stay.
--    Released builds' client-side join (insert own row) is refused from now on.
-- 3. group_invite_valid(group, token): SECURITY DEFINER, the ONE token
--    comparison. join_group and group_join_guests ask it; the join page asks it
--    before showing anything. Returns one boolean, never a token.
-- 4. group_join_guests(group, token): no rows unless the token is current.
-- 5. join_group(group, token, guest): SECURITY DEFINER now -- with the
--    self-insert branch gone, the joiner's own-row insert cannot pass RLS as the
--    caller. search_path pinned to ''. The caller is the session email; a
--    session without one, and a token that is not the group's current one,
--    raise before any other read or write (a rejected token raises SQLSTATE
--    DE401, which the app maps to "invite no longer valid"). Then the per-group
--    member-write lock, then guest-merge-rpc's join unchanged, every statement
--    scoped to _group_id.
-- 6. reset_group_invite(group): SECURITY INVOKER. An active member gets a new
--    token; every earlier link stops working. Bumps group_update_checker so other
--    members' open screens refetch the group and share the new link.
-- 7. update_group_member_shares gets `search_path = public, pg_temp`: it uses
--    unqualified names and is now also called from join_group, whose own
--    search_path is ''. Same tables, so every other caller is unaffected.
--
-- The token-less join_group(uuid, text) and group_join_guests(uuid) are dropped.
-- Every function created here revokes execute from public and anon itself.
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261026100000 (it defines
-- lock_group_member_writes and the functions replaced here). Order against
-- 20261026160000 does not matter: this file revokes its own functions.
-- Re-runnable. Tested on the local harness:
-- supabase/tests/rls_stopgap/80_group_invite_token_cases.sql.

begin;

-- 1 ---------------------------------------------------------------------------
alter table public."group"
  add column if not exists invite_token uuid not null default gen_random_uuid();

-- 2 ---------------------------------------------------------------------------
drop policy if exists "group_member: insert self or by member" on public.group_member;
drop policy if exists "group_member: insert by member or creator" on public.group_member;
create policy "group_member: insert by member or creator" on public.group_member
  for insert to authenticated
  with check (
    public.is_group_member(group_id)
    or exists (
      select 1 from public."group" g
      where g.id = group_member.group_id
        and g.user_id = (select auth.uid())
    )
  );

-- 3 ---------------------------------------------------------------------------
create or replace function public.group_invite_valid(_group_id uuid, _token uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $group_invite_valid$
  select exists (
    select 1 from public."group" as g
    where g.id = _group_id and g.invite_token = _token
  );
$group_invite_valid$;

revoke execute on function public.group_invite_valid(uuid, uuid) from public, anon;
grant execute on function public.group_invite_valid(uuid, uuid) to authenticated;

-- 4, 5: the token-less signatures go first ------------------------------------
drop function if exists public.join_group(uuid, text);
drop function if exists public.group_join_guests(uuid);

-- 4 ---------------------------------------------------------------------------
create or replace function public.group_join_guests(_group_id uuid, _token uuid)
returns table (email text, display_name text)
language sql
stable
security definer
set search_path = ''
as $group_join_guests$
  select gm.email, u.display_name
  from public.group_member as gm
  join public."user" as u on u.email = gm.email
  where public.group_invite_valid(_group_id, _token)
    and gm.group_id = _group_id
    and gm.removed_at is null
    and u.is_guest is true
  order by u.display_name, gm.email;
$group_join_guests$;

revoke execute on function public.group_join_guests(uuid, uuid) from public, anon;
grant execute on function public.group_join_guests(uuid, uuid) to authenticated;

-- 7 (before join_group, which calls it) ---------------------------------------
alter function public.update_group_member_shares(uuid, uuid)
  set search_path = public, pg_temp;

-- 5 ---------------------------------------------------------------------------
create or replace function public.join_group(
  _group_id uuid,
  _token uuid,
  _guest_email text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $join_group$
declare
  _email text := auth.jwt() ->> 'email';
  _removed_at timestamptz;
  _n integer;
begin
  if _email is null or _email = '' then
    raise exception 'join_group: no email in the session'
      using errcode = '28000';
  end if;

  if not public.group_invite_valid(_group_id, _token) then
    raise exception 'join_group: the invite for group % is not valid', _group_id
      using errcode = 'DE401';
  end if;

  perform public.lock_group_member_writes(_group_id);

  if _guest_email is not null and not exists (
    select 1 from public.group_join_guests(_group_id, _token) as g where g.email = _guest_email
  ) then
    raise exception 'join_group: % is not an active guest of group %', _guest_email, _group_id
      using errcode = '23503';
  end if;

  select gm.removed_at into _removed_at
  from public.group_member as gm
  where gm.group_id = _group_id and gm.email = _email;

  if not found then
    insert into public.group_member (group_id, email, is_favorite)
    values (_group_id, _email, false);
  elsif _removed_at is not null then
    update public.group_member
      set removed_at = null
      where group_id = _group_id and email = _email and removed_at is not null;
    get diagnostics _n = row_count;
    if _n = 0 then
      raise exception 'join_group: could not re-activate % in group %', _email, _group_id;
    end if;
  end if;

  if _guest_email is not null then
    update public.expense as e
      set paid_by = _email
      where e.group_id = _group_id and e.paid_by = _guest_email;

    update public.expense_entry_share as s
      set email = _email
      where s.email = _guest_email
        and s.expense_entry_id in (
          select ee.id
          from public.expense_entry as ee
          join public.expense as e on e.id = ee.expense_id
          where e.group_id = _group_id
        );

    delete from public.group_member as gm
      where gm.group_id = _group_id and gm.email = _guest_email;
    get diagnostics _n = row_count;
    if _n = 0 then
      raise exception 'join_group: could not take % out of group %', _guest_email, _group_id;
    end if;

    if exists (
      select 1 from public.expense as e
      where e.group_id = _group_id and e.paid_by = _guest_email
    ) or exists (
      select 1 from public.expense_entry_share as s
      join public.expense_entry as ee on ee.id = s.expense_entry_id
      join public.expense as e on e.id = ee.expense_id
      where e.group_id = _group_id and s.email = _guest_email
    ) then
      raise exception 'join_group: rows of group % still name %', _group_id, _guest_email;
    end if;
  end if;

  perform public.update_group_member_shares(_group_id, null::uuid);

  if _guest_email is not null and not public.has_any_membership(_guest_email) then
    delete from public."user" as u
      where u.email = _guest_email and u.is_guest;
  end if;
end;
$join_group$;

revoke execute on function public.join_group(uuid, uuid, text) from public, anon;
grant execute on function public.join_group(uuid, uuid, text) to authenticated;

-- 6 ---------------------------------------------------------------------------
create or replace function public.reset_group_invite(_group_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $reset_group_invite$
declare
  _token uuid;
begin
  if not exists (
    select 1 from public.group_member as gm
    where gm.group_id = _group_id
      and gm.email = (auth.jwt() ->> 'email')
      and gm.removed_at is null
  ) then
    raise exception 'reset_group_invite: not an active member of group %', _group_id
      using errcode = '42501';
  end if;

  update public."group" as g
    set invite_token = pg_catalog.gen_random_uuid()
    where g.id = _group_id
    returning g.invite_token into _token;
  if _token is null then
    raise exception 'reset_group_invite: group % was not updated', _group_id;
  end if;

  insert into public.group_update_checker (group_id, created_at)
    values (_group_id, pg_catalog.now())
    on conflict (group_id) do update set created_at = pg_catalog.now();

  return _token;
end;
$reset_group_invite$;

revoke execute on function public.reset_group_invite(uuid) from public, anon;
grant execute on function public.reset_group_invite(uuid) to authenticated;

commit;
