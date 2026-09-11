-- Per-expense entry currency with a manual, frozen rate
-- (multi-currency-expense-rate).
--
-- An expense may be ENTERED in a currency other than its group's. The client
-- converts once, at entry, and writes the converted GROUP-currency amount into
-- the existing `amount` columns. Nothing downstream of the write knows a
-- conversion happened: `pay_back`, `update_group_member_shares` and
-- `group_shares_summary` keep their arithmetic byte-for-byte.
--
-- The columns added here are PROVENANCE ONLY. No balance path reads them.
--   expense.original_currency_code — ISO 4217 the amounts were typed in, null
--                                    when the expense is in the group currency.
--   expense.conversion_rate        — frozen rate: 1 original = N group.
--   expense.rate_date              — the day the rate is attributed to.
--   expense_entry.original_amount  — that entry's amount AS ENTERED.
--   expense_entry_share.original_fixed_amount
--                                  — that exact-split share AS ENTERED.
--
-- The rule the two amount columns encode: every money column the EDITOR reloads
-- into one of its fields needs an entry-currency twin, because the field holds
-- entry-currency amounts while the column holds the converted ledger value.
-- `expense_entry.amount` has `original_amount`; `expense_entry_share
-- .fixed_amount` (also converted, see ExpenseRepository.saveAll) therefore has
-- `original_fixed_amount`. Without it a name-only re-save of a converted
-- exact-split expense would feed ledger amounts back through the conversion a
-- second time.
--
-- Backwards compatible: every column is nullable, with no fallback value, so
-- existing rows stay null and read exactly as before.
--
-- SECURITY INVOKER (the implicit mode): every statement runs as the calling
-- user, so existing RLS policies apply unchanged. Mirrors 20260618000000.

-- 1. Provenance columns.
alter table public.expense
  add column if not exists original_currency_code text,
  add column if not exists conversion_rate numeric,
  add column if not exists rate_date date;

alter table public.expense_entry
  add column if not exists original_amount numeric;

alter table public.expense_entry_share
  add column if not exists original_fixed_amount numeric;

-- 2. Thread the provenance through save_expense_all. Full re-statement of the
--    20260618000000 body with the five new columns added to the UPDATE SET and
--    the INSERT column lists; the item_group_id grouping logic is unchanged.
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
      category = r.category,
      original_currency_code = r.original_currency_code,
      conversion_rate = r.conversion_rate,
      rate_date = r.rate_date
    from jsonb_populate_record(null::public.expense, _expense) r
    where e.id = _expense_id;
    if not found then
      insert into public.expense (id, name, expense_date, paid_by, group_id, user_id, category,
                                  original_currency_code, conversion_rate, rate_date)
      select r.id, r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category,
             r.original_currency_code, r.conversion_rate, r.rate_date
      from jsonb_populate_record(null::public.expense, _expense) r;
    end if;
  else
    insert into public.expense (name, expense_date, paid_by, group_id, user_id, category,
                                original_currency_code, conversion_rate, rate_date)
    select r.name, r.expense_date, r.paid_by, r.group_id, r.user_id, r.category,
           r.original_currency_code, r.conversion_rate, r.rate_date
    from jsonb_populate_record(null::public.expense, _expense) r
    returning id into _expense_id;
  end if;

  -- expense_entry_share rows are removed via ON DELETE CASCADE,
  -- same as the existing client-side delete relies on.
  delete from public.expense_entry where expense_id = _expense_id;

  _prev_seq := null;
  _group := null;
  for _item in select * from jsonb_array_elements(coalesce(_entries, '[]'::jsonb)) loop
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

    insert into public.expense_entry (expense_id, name, amount, quantity, split_mode, sort_id,
                                      item_group_id, original_amount)
    select _expense_id, r.name, r.amount, r.quantity, r.split_mode, r.sort_id, _group,
           r.original_amount
    from jsonb_populate_record(null::public.expense_entry, _item->'entry') r
    returning id into _entry_id;

    insert into public.expense_entry_share (expense_entry_id, email, percentage, fixed_amount, parts, is_locked,
                                            original_fixed_amount)
    select _entry_id, s.email, s.percentage, s.fixed_amount, s.parts, coalesce(s.is_locked, false),
           s.original_fixed_amount
    from jsonb_populate_recordset(null::public.expense_entry_share, _item->'shares') s;
  end loop;

  perform public.update_group_member_shares(_group_id, _expense_id);

  return _expense_id;
end;
$$;
