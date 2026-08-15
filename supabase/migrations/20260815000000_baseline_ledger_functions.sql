-- Baseline: ledger functions recovered from the live self-hosted instance (2026-08-15).
--
-- `pay_back` and `update_group_member_shares` predate this repo's migration history and
-- existed only on the server, so `supabase/migrations` could not rebuild the database.
-- This migration codifies them EXACTLY as they run in production today. It changes no
-- behaviour and is safe to re-run: both are CREATE OR REPLACE of their current definition.
--
-- Known issues in these definitions are deliberately preserved here rather than fixed --
-- they are tracked as roadmap features, and a baseline that quietly "improves" what it
-- captures is not a baseline:
--   * settle-residue           -- shares are computed unrounded (`amount * percentage / 100`)
--                                 while the client rounds to cents, so settling a rounded
--                                 balance against an unrounded one leaves a remainder.
--   * group-member-removal     -- the `total_share_amount` subquery never joins `group_member`,
--                                 so shares belonging to a removed member keep counting toward
--                                 everyone else's net balance.
--   * payback-on-behalf        -- `pay_back` validates nothing: it does not check that
--                                 `_paid_by` and `_paid_for` are distinct, or that either is a
--                                 member of `_group_id`.

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

  insert into
    expense (group_id, name, paid_by, expense_date, is_paid_back_row)
  values
    ($1, 'paid_back', $2, now(), true)
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

create or replace function public.update_group_member_shares(
  _group_id uuid,
  _expense_id uuid
)
returns void
language plpgsql
as $function$
begin

delete from group_shares_summary where group_id = $1;

insert into
  group_shares_summary (group_id, paid_by, paid_for, total_expenses, share_amount, total_share_amount)
    select
      gm.group_id,
      coalesce(e.paid_by, gm.email) as paid_by,
      gm.email as paid_for,
      coalesce(sum(case e.is_paid_back_row when false then (ee.amount * (ees.percentage / 100)) else 0.0 end),0.0) as total_expenses,
      coalesce(sum(ee.amount * (ees.percentage / 100)),0.0) as share_amount,
      coalesce((
        select
          sum(
            case sub_e.paid_by
            when gm.email
            then (sub_ee.amount * (sub_ees.percentage / 100))
            else (-sub_ee.amount * (sub_ees.percentage / 100))
            end
          ) as test
        from
          expense as sub_e
        left join expense_entry as sub_ee on sub_ee.expense_id = sub_e.id
        left join expense_entry_share as sub_ees on sub_ees.expense_entry_id = sub_ee.id
        where
          sub_e.group_id = gm.group_id and
          sub_e.id is not null and
          (
            (
            sub_ees.email = gm.email and
            sub_e.paid_by <> gm.email
          ) or
          (
            sub_e.paid_by = gm.email and
            sub_ees.email <> gm.email
          )
          )
      ),0.0) as total_share_amount
    from
      group_member as gm
    left join expense as e on e.group_id = gm.group_id
    left join expense_entry as ee on ee.expense_id = e.id
    left join expense_entry_share as ees on ees.expense_entry_id = ee.id and ees.email = gm.email
    where
      gm.group_id = $1
    group by
      gm.group_id,
      gm.email,
      e.paid_by
    order by
      e.paid_by,
      gm.email
on conflict (group_id, paid_by, paid_for) do
update
set
  total_expenses = excluded.total_expenses,
  share_amount = excluded.share_amount,
  total_share_amount = excluded.total_share_amount;

insert into
  group_update_checker (group_id, created_at)
values ($1, now())
on conflict (group_id) do update set created_at = now();

if $2 is not null then
  insert into
    expense_update_checker (group_id, expense_id, created_at)
  values ($1, $2, now())
  on conflict (group_id, expense_id) do update set created_at = now();
end if;

end;
$function$;
