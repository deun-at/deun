-- payback-on-behalf: `pay_back` gains the two guards it never had, and records
-- WHO wrote the row.
--
-- Why here and not in the client alone: payback-on-behalf widens who may trigger
-- a payback from "the payer" to "any member", so the same guard has to hold for
-- concurrent clients, not just for the one showing the message. The client half
-- (GroupRepository.payBack -> resolvePayback) rejects both cases before any
-- write; this is the backstop.
--
-- Why `pay_back` and not a new RPC: `pay_back_exact` (settle-residue) delegates
-- its insert to `pay_back`, so both entry points inherit these rules from one
-- place. `pay_back_exact` is deliberately NOT touched by this migration.
--
-- Attribution: `expense.user_id` already means "the user who created this row"
-- everywhere else (ExpenseRepository.saveAll writes it, sendExpenseNotification
-- reads it). `pay_back` simply never set it. auth.uid() is the recorder — the
-- signed-in caller — which is the same person as `_paid_by` on the ordinary
-- self-payback and a different person when a payback is recorded on someone's
-- behalf. Nothing else in this insert changes.
--
-- `group_member.removed_at` is relied on here; it is live (group-member-removal,
-- applied 2026-08-16).
--
-- NOT APPLIED. See docs/ristretto/MANUAL_OPS.md.

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

  return new_expense_id;
end;
$function$;
