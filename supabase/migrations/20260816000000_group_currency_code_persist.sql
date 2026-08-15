-- group-currency-persist: make save_group_all actually store the group's currency.
--
-- The bug: `group.currency_code` has existed since
-- `20260712000000_add_group_currency_code.sql` (multi-currency-foundation), the
-- picker has been on the group create and edit forms since the same feature, and
-- `GroupRepository.saveAll` has always packed `currency_code` into the `_group`
-- jsonb it hands to this RPC. But `save_group_all` never listed the column in
-- either its UPDATE SET or its INSERT column list, so the value was silently
-- dropped on every write. With `default 'EUR' not null` on the column, every
-- group in the instance is EUR regardless of what the user picked -- confirmed
-- 2026-08-16 against the live data: 110 groups, all 'EUR', zero exceptions.
--
-- This affects two features already marked done on the roadmap
-- (multi-currency-foundation, group-create-simplify) and would have quietly
-- undermined the whole multi-currency flight, which builds per-currency balances
-- and a currency lock on top of a value that never persisted.
--
-- The fix is two lines. `jsonb_populate_record(null::public."group", _group)`
-- already materializes `r.currency_code` -- it was simply never selected. There
-- is deliberately NO backfill: existing groups are legitimately EUR, because
-- nobody was ever able to set them to anything else.
--
-- Everything else in this function is reproduced verbatim from the live
-- definition (dumped 2026-08-16, post-`20260815010000`) so this migration is a
-- currency change only. In particular the group-member-removal member handling
-- below is unchanged.
--
-- NOT APPLIED. See docs/ristretto/MANUAL_OPS.md.

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
  for _m in select * from jsonb_array_elements(coalesce(_members, '[]'::jsonb)) loop
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
$$;
