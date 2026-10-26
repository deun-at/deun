-- removed-member-access: a soft-removed member loses all read and write access
-- to the group they were removed from; the remaining members keep seeing their
-- rows, names and history.
--
-- Until now membership meant "has a group_member row", removed_at ignored
-- (rls-stopgap, rls-hardening Decisions (c)). A soft-removed member could read
-- the whole group, rewrite its expenses and balances, delete it, read its
-- invite_token and clear their own removed_at. Jakob overturned that ruling on
-- 2026-10-26 (docs/ristretto/plans/removed-member-access.md, Decisions).
--
-- 1. is_group_member(group): true only for the caller's ACTIVE row
--    (removed_at is null). Signature, SECURITY DEFINER, pinned search_path and
--    grants unchanged. Every policy that already asks it (expense_entry,
--    expense_entry_share, group_shares_summary, group_member) follows.
-- 2. group_has_members(group): SECURITY DEFINER, pinned search_path. Whether a
--    group has any group_member row, removed ones included. It lets the
--    creator branches below ask "no member row yet" without a group_member
--    policy sub-selecting group_member (infinite recursion). It reads the
--    group's id from the row, never a stable snapshot of "group", so the
--    RETURNING of save_group_all's `insert into "group"` passes.
-- 3. "group", expense, expense_update_checker and group_update_checker: the
--    baseline policies sub-selected group_member as the caller, which a
--    removed member passes through their own visible row. Re-created under the
--    SAME names on is_group_member. The creator SELECT branch ("Enable users to
--    view their own data only") applies only while the group has no member
--    row: group.user_id grants nothing once the group has one.
-- 4. group_member INSERT: the creator branch likewise only while the group has
--    no member row. group_member UPDATE: the own-row branch is gone; an active
--    member keeps is_favorite on their own row and removed_at on others'
--    through is_group_member. Released builds' client-side re-join (update own
--    removed_at = null) is refused from now on (hard-fail, by ruling). SELECT
--    and DELETE are unchanged: the own-row read stays (the join page reads it).
-- 5. save_group_all: on a create, the caller's own row is inserted first, so
--    the creator branch (no member row yet) admits it and every later row goes
--    through is_group_member. Otherwise the baseline body verbatim.
--
-- Unchanged on purpose: has_any_membership (the guest-delete guard) and
-- update_group_member_shares (ledger math) keep counting removed rows. Re-join
-- stays: join_group with the group's current token clears removed_at
-- (SECURITY DEFINER), and an active member re-adds through add_group_member
-- or save_group_all.
--
-- Every function created here revokes execute from public and anon itself.
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261026180000 (whose
-- group_member INSERT policy it replaces). Re-runnable. Tested on the local
-- harness: supabase/tests/rls_stopgap/90_removed_member_access_cases.sql.

begin;

-- 1 ---------------------------------------------------------------------------
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
      and gm.removed_at is null
  );
$$;

revoke execute on function public.is_group_member(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated, service_role;

-- 2 ---------------------------------------------------------------------------
create or replace function public.group_has_members(_group_id uuid)
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
  );
$$;

revoke execute on function public.group_has_members(uuid) from public, anon;
grant execute on function public.group_has_members(uuid) to authenticated, service_role;

-- 3: "group" ------------------------------------------------------------------
drop policy if exists "Enable select for users based on group_member" on public."group";
create policy "Enable select for users based on group_member" on public."group"
  for select to authenticated
  using (public.is_group_member(id));

-- the creator, only while the group has no member row (save_group_all's create)
drop policy if exists "Enable users to view their own data only" on public."group";
create policy "Enable users to view their own data only" on public."group"
  for select to authenticated
  using (user_id = (select auth.uid()) and not public.group_has_members(id));

drop policy if exists "Enable update for users based on group_member" on public."group";
create policy "Enable update for users based on group_member" on public."group"
  for update to authenticated
  using (public.is_group_member(id))
  with check (public.is_group_member(id));

drop policy if exists "Enable delete for users based on group_member" on public."group";
create policy "Enable delete for users based on group_member" on public."group"
  for delete to authenticated
  using (public.is_group_member(id));

-- 3: expense ------------------------------------------------------------------
drop policy if exists "Enable select for users based on group_member" on public.expense;
create policy "Enable select for users based on group_member" on public.expense
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "Enable insert for users based on group_member" on public.expense;
create policy "Enable insert for users based on group_member" on public.expense
  for insert to authenticated
  with check (public.is_group_member(group_id));

drop policy if exists "Enable update for users based on group_member" on public.expense;
create policy "Enable update for users based on group_member" on public.expense
  for update to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

drop policy if exists "Enable delete for users based on group_member" on public.expense;
create policy "Enable delete for users based on group_member" on public.expense
  for delete to authenticated
  using (public.is_group_member(group_id));

-- 3: expense_update_checker (membership of the expense's group, as before) ----
drop policy if exists "Enable select for users based on group_member" on public.expense_update_checker;
create policy "Enable select for users based on group_member" on public.expense_update_checker
  for select to authenticated
  using (exists (
    select 1 from public.expense e
    where e.id = expense_update_checker.expense_id
      and public.is_group_member(e.group_id)
  ));

drop policy if exists "Enable insert for users based on group_member" on public.expense_update_checker;
create policy "Enable insert for users based on group_member" on public.expense_update_checker
  for insert to authenticated
  with check (exists (
    select 1 from public.expense e
    where e.id = expense_update_checker.expense_id
      and public.is_group_member(e.group_id)
  ));

drop policy if exists "Enable update for users based on group_member" on public.expense_update_checker;
create policy "Enable update for users based on group_member" on public.expense_update_checker
  for update to authenticated
  using (exists (
    select 1 from public.expense e
    where e.id = expense_update_checker.expense_id
      and public.is_group_member(e.group_id)
  ))
  with check (exists (
    select 1 from public.expense e
    where e.id = expense_update_checker.expense_id
      and public.is_group_member(e.group_id)
  ));

-- 3: group_update_checker -----------------------------------------------------
drop policy if exists "Enable select for users based on group_member" on public.group_update_checker;
create policy "Enable select for users based on group_member" on public.group_update_checker
  for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "Enable insert for users based on group_member" on public.group_update_checker;
create policy "Enable insert for users based on group_member" on public.group_update_checker
  for insert to authenticated
  with check (public.is_group_member(group_id));

drop policy if exists "Enable update for users based on group_member" on public.group_update_checker;
create policy "Enable update for users based on group_member" on public.group_update_checker
  for update to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- 4: group_member -------------------------------------------------------------
-- an active member adding someone, or the creator filling a group that has no
-- member row yet (save_group_all's create)
drop policy if exists "group_member: insert by member or creator" on public.group_member;
create policy "group_member: insert by member or creator" on public.group_member
  for insert to authenticated
  with check (
    public.is_group_member(group_id)
    or (
      not public.group_has_members(group_id)
      and exists (
        select 1 from public."group" g
        where g.id = group_member.group_id
          and g.user_id = (select auth.uid())
      )
    )
  );

-- active members only: is_favorite on their own row, removed_at on others'
drop policy if exists "group_member: update by member" on public.group_member;
create policy "group_member: update by member" on public.group_member
  for update to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- 5 ---------------------------------------------------------------------------
create or replace function public.save_group_all(_group jsonb, _members jsonb)
returns uuid
language plpgsql
as $save_group_all$
declare
  _group_id uuid;
  _m jsonb;
  _email text;
begin
  if _group ? 'id' then
    _group_id := (_group->>'id')::uuid;
    update public."group" g set
      name = r.name,
      color_value = r.color_value,
      simplified_expenses = r.simplified_expenses,
      -- group-currency-persist: THE fix (edit half). Relabels only -- no amount
      -- is converted, matching what the edit form's own note promises the user.
      currency_code = r.currency_code,
      user_id = r.user_id
    from jsonb_populate_record(null::public."group", _group) r
    where g.id = _group_id;
  else
    -- group-currency-persist: THE fix (create half). Without this a new group
    -- fell back to the column default and the create form's currency choice was
    -- discarded before it ever reached a row.
    insert into public."group" (name, color_value, simplified_expenses, currency_code, user_id)
    select r.name, r.color_value, r.simplified_expenses,
           coalesce(r.currency_code, 'EUR'), r.user_id
    from jsonb_populate_record(null::public."group", _group) r
    returning id into _group_id;
  end if;

  -- group-member-removal: NO `delete from group_member` here any more. Membership
  -- shrinks ONLY through the explicit removal path. A member merely absent from
  -- _members is left alone. Nothing is deleted, so is_favorite survives on its
  -- own and the old _favorites snapshot is gone along with the delete it existed
  -- to protect against.
  -- removed-member-access: the caller's own entry first, then the rest in the
  -- order sent. The creator branch admits a group's first row only, so on a
  -- create the creator's row must be that row.
  for _m in
    select m.value
    from jsonb_array_elements(coalesce(_members, '[]'::jsonb)) with ordinality as m(value, ord)
    order by (m.value->>'email') is not distinct from (auth.jwt() ->> 'email') desc, m.ord
  loop
    _email := _m->>'email';

    if coalesce((_m->>'is_guest_pending')::boolean, false) then
      if coalesce(_m->>'display_name', '') = '' then
        continue;
      end if;
      _email := 'guest+' || replace(gen_random_uuid()::text, '-', '') || '@guest.invalid';
      insert into public."user" (email, display_name, is_guest)
      values (_email, _m->>'display_name', true);
    end if;

    if _email is not null and _email <> '' then
      if exists (
        select 1 from public.group_member gm
        where gm.group_id = _group_id and gm.email = _email
      ) then
        -- Re-add: clear the marker. Historical expense_entry_share rows are
        -- untouched, so nothing is duplicated.
        update public.group_member
          set removed_at = null
          where group_id = _group_id and email = _email and removed_at is not null;
      else
        insert into public.group_member (group_id, email, is_favorite)
        values (_group_id, _email, false);
      end if;
    end if;
  end loop;

  perform public.update_group_member_shares(_group_id, null::uuid);

  return _group_id;
end;
$save_group_all$;

revoke execute on function public.save_group_all(jsonb, jsonb) from public, anon;
grant execute on function public.save_group_all(jsonb, jsonb) to authenticated, service_role;

commit;
