-- Atomic save RPCs for expense and group writes.
--
-- Motivation: the app previously performed these writes as 5-9 separate
-- PostgREST calls (upsert parent -> delete children -> insert children ->
-- recalculate shares). A failure mid-sequence left orphaned rows or a group
-- without members. These functions wrap the same statements in one
-- transaction (a plpgsql function body is always atomic).
--
-- Backwards compatible: nothing existing is modified. Old app versions keep
-- using the multi-step path; new app versions call these functions and fall
-- back to the multi-step path automatically when they don't exist yet
-- (missing-function error PGRST202/42883).
--
-- NOTE: assumes update_group_member_shares(_group_id uuid, _expense_id uuid).
-- If your function declares text parameters instead, adjust the two PERFORM
-- calls below with ::text casts.
--
-- Both functions are SECURITY INVOKER (the default): every statement runs as
-- the calling user, so existing RLS policies apply exactly as they do for the
-- current client-side calls.

create or replace function public.save_expense_all(
  _group_id uuid,
  _expense jsonb,
  _entries jsonb
) returns uuid
language plpgsql
as $$
declare
  _expense_id uuid;
  _item jsonb;
  _entry_id uuid;
begin
  if _expense ? 'id' then
    _expense_id := (_expense->>'id')::uuid;
    update public.expense e set
      name = r.name,
      expense_date = r.expense_date,
      paid_by = r.paid_by,
      group_id = r.group_id,
      user_id = r.user_id,
      category = r.category
    from jsonb_populate_record(null::public.expense, _expense) r
    where e.id = _expense_id;
    if not found then
      insert into public.expense (id, name, expense_date, paid_by, group_id, user_id, category)
      select r.id, r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category
      from jsonb_populate_record(null::public.expense, _expense) r;
    end if;
  else
    insert into public.expense (name, expense_date, paid_by, group_id, user_id, category)
    select r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category
    from jsonb_populate_record(null::public.expense, _expense) r
    returning id into _expense_id;
  end if;

  -- expense_entry_share rows are removed via ON DELETE CASCADE,
  -- same as the existing client-side delete relies on.
  delete from public.expense_entry where expense_id = _expense_id;

  for _item in select * from jsonb_array_elements(coalesce(_entries, '[]'::jsonb)) loop
    insert into public.expense_entry (expense_id, name, amount, quantity, split_mode, sort_id)
    select _expense_id, r.name, r.amount, r.quantity, r.split_mode, r.sort_id
    from jsonb_populate_record(null::public.expense_entry, _item->'entry') r
    returning id into _entry_id;

    insert into public.expense_entry_share (expense_entry_id, email, percentage, fixed_amount, parts, is_locked)
    select _entry_id, s.email, s.percentage, s.fixed_amount, s.parts, coalesce(s.is_locked, false)
    from jsonb_populate_recordset(null::public.expense_entry_share, _item->'shares') s;
  end loop;

  perform public.update_group_member_shares(_group_id, _expense_id);

  return _expense_id;
end;
$$;

create or replace function public.save_group_all(
  _group jsonb,
  _members jsonb
) returns uuid
language plpgsql
as $$
declare
  _group_id uuid;
  _m jsonb;
  _email text;
  _favorites jsonb;
begin
  if _group ? 'id' then
    _group_id := (_group->>'id')::uuid;
    update public."group" g set
      name = r.name,
      color_value = r.color_value,
      simplified_expenses = r.simplified_expenses,
      user_id = r.user_id
    from jsonb_populate_record(null::public."group", _group) r
    where g.id = _group_id;
  else
    insert into public."group" (name, color_value, simplified_expenses, user_id)
    select r.name, r.color_value, r.simplified_expenses, r.user_id
    from jsonb_populate_record(null::public."group", _group) r
    returning id into _group_id;
  end if;

  -- Preserve favorite flags across the delete/reinsert cycle (the old
  -- client-side flow silently reset is_favorite on every group edit).
  select coalesce(jsonb_object_agg(gm.email, gm.is_favorite), '{}'::jsonb)
    into _favorites
    from public.group_member gm
    where gm.group_id = _group_id;

  delete from public.group_member where group_id = _group_id;

  for _m in select * from jsonb_array_elements(coalesce(_members, '[]'::jsonb)) loop
    _email := _m->>'email';

    if coalesce((_m->>'is_guest_pending')::boolean, false) then
      -- Resolve pending guests by creating a guest user record, mirroring
      -- the client-side UserRepository.createGuest behavior.
      if coalesce(_m->>'display_name', '') = '' then
        continue;
      end if;
      _email := 'guest+' || replace(gen_random_uuid()::text, '-', '') || '@guest.invalid';
      insert into public."user" (email, display_name, is_guest)
      values (_email, _m->>'display_name', true);
    end if;

    if _email is not null and _email <> '' then
      insert into public.group_member (group_id, email, is_favorite)
      values (_group_id, _email, coalesce((_favorites->>_email)::boolean, false));
    end if;
  end loop;

  perform public.update_group_member_shares(_group_id, null::uuid);

  return _group_id;
end;
$$;
