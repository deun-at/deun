-- payback-atomic-recalc: `pay_back` recalculates the group's balances in the
-- same transaction as the payback it records.
--
-- Why: the client wrote the payback (pay_back / pay_back_exact) and then called
-- `update_group_member_shares` as a SECOND request, retrying it once. When both
-- attempts failed, the payback was committed but the balance stayed stale and
-- the client threw. The user saw an error for a payment that had been recorded,
-- and a retry recorded it twice (research/code-review-2026-10.md, finding 7).
-- Now the payback and its recalculation commit together or not at all, so a
-- thrown error means nothing was written.
--
-- Precedent: save_expense_all / save_group_all (20260610120000),
-- claim_set_unit_shares (20260618000000) and join_group (20261026100000)
-- already `perform public.update_group_member_shares(...)` in-transaction.
--
-- Body: 20260816010000_payback_on_behalf.sql's `pay_back` verbatim (four guards,
-- errcodes, auth.uid() attribution, positional $1..$4) plus the one `perform`
-- before `return`. It passes the same arguments the client passed (the group and
-- the new payback's id), so group_update_checker and expense_update_checker are
-- bumped exactly as before, now atomically with the row. The signature and
-- return type are the same, so `create or replace` replaces the function in place:
-- no overload, grants kept, still SECURITY INVOKER (the recalculation runs with
-- the caller's rights, exactly as the client's separate call did).
-- `pay_back_exact` (20260815020000) delegates to `pay_back` and inherits this
-- untouched.
--
-- Old clients still call update_group_member_shares afterwards. It recomputes
-- from scratch, so the extra call only bumps the checkers a second time.
--
-- NOT APPLIED. See docs/ristretto/manual-checks.md. Apply it BEFORE the client
-- change reaches main: a push to main deploys the web build, and that client no
-- longer recalculates on its own.

create or replace function public.pay_back(
  _group_id uuid,
  _paid_by text,
  _paid_for text,
  _amount numeric
)
returns uuid
language plpgsql
as $function$
declare
    new_expense_id uuid;
    new_expense_entry_id uuid;
begin

  if _paid_by is null or _paid_for is null then
    raise exception 'pay_back: payer and payee are both required'
      using errcode = '22004';
  end if;

  if _paid_by = _paid_for then
    raise exception 'pay_back: payer and payee must be different members (%)', _paid_by
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.group_member as gm
    where gm.group_id = _group_id
      and gm.email = _paid_by
      and gm.removed_at is null
  ) then
    raise exception 'pay_back: % is not a current member of group %', _paid_by, _group_id
      using errcode = '23503';
  end if;

  if not exists (
    select 1
    from public.group_member as gm
    where gm.group_id = _group_id
      and gm.email = _paid_for
      and gm.removed_at is null
  ) then
    raise exception 'pay_back: % is not a current member of group %', _paid_for, _group_id
      using errcode = '23503';
  end if;

  insert into
    expense (group_id, name, paid_by, expense_date, is_paid_back_row, user_id)
  values
    ($1, 'paid_back', $2, now(), true, auth.uid())
  returning id into new_expense_id;

  insert into
    expense_entry (expense_id, amount)
  values
    (new_expense_id, $4)
  returning id into new_expense_entry_id;

  insert into
    expense_entry_share (expense_entry_id, email, percentage)
  values
    (new_expense_entry_id, $3, 100);

  perform public.update_group_member_shares(_group_id, new_expense_id);

  return new_expense_id;
end;
$function$;
