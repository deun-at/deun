-- Per-unit claim entries (E3-T1).
--
-- Motivation: the Tap-to-Claim feature models claims PER UNIT. An itemized
-- item with quantity N is now stored as N expense_entry rows (quantity 1,
-- split_mode 'claim', amount = unit price), grouped by item_group_id so the
-- editor can re-collapse them. Each unit's expense_entry_share rows hold that
-- unit's claimers; split = unit_cost / claimers, expressed as
-- percentage = 100 / claimers (keeps groupMemberShareStatistic and
-- get_user_spending_summary correct with no read-side changes).
--
-- Backwards compatible:
--   * item_group_id is nullable; existing rows stay null and render as before.
--   * save_expense_all is replaced to accept per-unit entries + item_group_id,
--     generating a fresh group id per run of equal item_group_seq values.
--   * claim_set_unit_shares is new; old clients ignore it.
--   * explode_itemized_entries backfill is OPT-IN (call per expense), never run
--     automatically by this migration.
--
-- SECURITY INVOKER (default): every statement runs as the calling user, so
-- existing RLS policies apply exactly as for the current client-side calls.
-- Mirrors the style of 20260610120000_atomic_save_rpcs.sql.

-- 1. Schema: group units that belong to the same itemized line.
alter table public.expense_entry
  add column if not exists item_group_id uuid;

create index if not exists expense_entry_item_group_id_idx
  on public.expense_entry (item_group_id);

-- 2. Replace save_expense_all to persist item_group_id and assign a fresh
--    group id per run of units sharing the same _item->'entry'->>'item_group_seq'.
--    An explicit item_group_id (client-assigned) takes precedence; a null seq
--    means a standalone entry (no grouping).
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
  _seq text;
  _prev_seq text;
  _group uuid;
  _has_explicit boolean;
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

  _prev_seq := null;
  _group := null;
  for _item in select * from jsonb_array_elements(coalesce(_entries, '[]'::jsonb)) loop
    -- Resolve item_group_id: an explicit non-empty value wins; otherwise
    -- generate one new uuid per run of equal item_group_seq values; a null
    -- seq means a standalone entry (group id stays null).
    _has_explicit := (_item->'entry') ? 'item_group_id'
      and coalesce(_item->'entry'->>'item_group_id', '') <> '';

    if _has_explicit then
      _group := (_item->'entry'->>'item_group_id')::uuid;
      _prev_seq := null;
    else
      _seq := _item->'entry'->>'item_group_seq';
      if _seq is null then
        _group := null;
      elsif _seq is distinct from _prev_seq then
        _group := gen_random_uuid();
      end if;
      _prev_seq := _seq;
    end if;

    insert into public.expense_entry (expense_id, name, amount, quantity, split_mode, sort_id, item_group_id)
    select _expense_id, r.name, r.amount, r.quantity, r.split_mode, r.sort_id, _group
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

-- 3. Atomic claim mutation: set the exact claimer set for one unit.
--    Empty _shares => the unit becomes unclaimed (no share rows).
--    Each claimer gets percentage = 100 / claimers so the percentage-based
--    aggregations (groupMemberShareStatistic, get_user_spending_summary)
--    stay correct.
create or replace function public.claim_set_unit_shares(
  _group_id uuid,
  _expense_id uuid,
  _entry_id uuid,
  _shares jsonb
) returns void
language plpgsql
as $$
begin
  delete from public.expense_entry_share where expense_entry_id = _entry_id;

  insert into public.expense_entry_share (expense_entry_id, email, percentage)
  select _entry_id, s.email, s.percentage
  from jsonb_populate_recordset(null::public.expense_entry_share, _shares) s;

  -- Recompute member shares (also bumps expense_update_checker so the
  -- claim screen's realtime subscription fires).
  perform public.update_group_member_shares(_group_id, _expense_id);
end;
$$;

-- 4. OPT-IN backfill: explode existing quantity>1 itemized entries of one
--    expense into per-unit claim entries. Idempotent: skips entries that are
--    already single units (quantity 1) or already claim units. Existing
--    shares on a multi-unit entry are dropped (a quantity>1 itemized line had
--    no per-unit claimers yet). Call per expense when ready; never automatic.
create or replace function public.explode_itemized_entries(_expense_id uuid)
returns int
language plpgsql
as $$
declare
  _e record;
  _unit_price numeric;
  _i int;
  _group uuid;
  _new_entry uuid;
  _count int := 0;
  _sort int;
begin
  for _e in
    select id, name, amount, quantity, sort_id
    from public.expense_entry
    where expense_id = _expense_id
      and quantity > 1
      and split_mode <> 'claim'
  loop
    _unit_price := round((_e.amount / _e.quantity)::numeric, 2);
    _group := gen_random_uuid();
    _sort := coalesce(_e.sort_id, 0);

    for _i in 1.._e.quantity loop
      insert into public.expense_entry
        (expense_id, name, amount, quantity, split_mode, sort_id, item_group_id)
      values
        (_expense_id, _e.name, _unit_price, 1, 'claim', _sort + _i, _group)
      returning id into _new_entry;
      _count := _count + 1;
    end loop;

    delete from public.expense_entry where id = _e.id; -- cascades shares
  end loop;

  return _count;
end;
$$;
