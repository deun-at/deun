-- guest-merge-rpc: an invite-link join, guest claim included, is one transaction
-- scoped to the joined group.
--
-- Replaces the client-side join in group_join_page.dart, which rewrote the guest's
-- paid_by and shares in EVERY group and then deleted the guest's user row
-- unconditionally. Every FK to "user"(email) is ON DELETE CASCADE (live dump
-- 2026-10-24), so that delete silently wiped the guest's history in other groups.
--
-- 1. lock_group_member_writes(group): the one per-group, transaction-scoped
--    advisory lock every member write takes first (shared with group-write-rpcs'
--    add_group_member / remove_group_member, which reuse it unchanged).
-- 2. group_join_guests(group): SECURITY DEFINER. A not-yet-member cannot read the
--    roster since 20261025190000, so the join page and join_group's own guest
--    check read the claimable guests here. Exposes only active guest placeholders
--    (display name + guest.invalid email) to whoever holds the group id.
-- 3. join_group(group, guest): SECURITY INVOKER like every sibling RPC. Joiner =
--    the session email. Refusals raise before any write. Membership: insert, or
--    clear removed_at, or nothing. The guest merge is independent of that branch,
--    rewrites only this group's rows, and raises on any silent no-op. Recalc runs
--    inside. The guest's user row goes only when has_any_membership() says no
--    group still names it.
--    No `set search_path` on join_group: update_group_member_shares uses
--    unqualified table names and inherits the caller's search_path.
--
-- No table is added to any publication.
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261025190000, before releasing
-- a build containing guest-merge-rpc (the app has no fallback). Re-runnable.
-- Tested on the local harness: supabase/tests/rls_stopgap/40_join_group_cases.sql.

begin;

create or replace function public.lock_group_member_writes(_group_id uuid)
returns void
language sql
volatile
set search_path = ''
as $lock$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('group_member_writes:' || _group_id::text, 0)
  );
$lock$;

revoke execute on function public.lock_group_member_writes(uuid) from public, anon;
grant execute on function public.lock_group_member_writes(uuid) to authenticated, service_role;

create or replace function public.group_join_guests(_group_id uuid)
returns table (email text, display_name text)
language sql
stable
security definer
set search_path = ''
as $group_join_guests$
  select gm.email, u.display_name
  from public.group_member as gm
  join public."user" as u on u.email = gm.email
  where gm.group_id = _group_id
    and gm.removed_at is null
    and u.is_guest is true
  order by u.display_name, gm.email;
$group_join_guests$;

revoke execute on function public.group_join_guests(uuid) from public, anon;
grant execute on function public.group_join_guests(uuid) to authenticated;

create or replace function public.join_group(
  _group_id uuid,
  _guest_email text default null
)
returns void
language plpgsql
security invoker
as $join_group$
declare
  _email text := auth.jwt() ->> 'email';
  _removed_at timestamptz;
  _n integer;
begin
  perform public.lock_group_member_writes(_group_id);

  if _email is null or _email = '' then
    raise exception 'join_group: no email in the session'
      using errcode = '28000';
  end if;

  if _guest_email is not null and not exists (
    select 1 from public.group_join_guests(_group_id) as g where g.email = _guest_email
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

revoke execute on function public.join_group(uuid, text) from public, anon;
grant execute on function public.join_group(uuid, text) to authenticated, service_role;

commit;
