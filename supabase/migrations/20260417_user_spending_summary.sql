-- Cross-group personal spending summary.
-- Returns one row per (group, month) with the caller's paid vs fair-share totals.
-- Runs with security invoker so existing RLS policies on expense / expense_entry / expense_entry_share / group / group_member apply.

create or replace function get_user_spending_summary(
  p_user_email text,
  p_start date,
  p_end date
) returns table (
  group_id uuid,
  group_name text,
  color_value int,
  month date,
  total_paid numeric,
  total_share numeric,
  expense_count int
) language sql stable security invoker as $$
  with entry_totals as (
    select
      e.id as expense_id,
      e.group_id,
      e.paid_by,
      e.expense_date,
      ee.id as entry_id,
      ee.amount as entry_amount
    from expense e
    join expense_entry ee on ee.expense_id = e.id
    where e.is_paid_back_row = false
      and e.expense_date >= p_start
      and e.expense_date < p_end
      and e.group_id in (
        select gm.group_id from group_member gm where gm.email = p_user_email
      )
  ),
  my_share as (
    select
      et.group_id,
      date_trunc('month', et.expense_date)::date as month,
      sum(et.entry_amount * (ees.percentage / 100.0)) as total_share
    from entry_totals et
    join expense_entry_share ees on ees.expense_entry_id = et.entry_id
    where ees.email = p_user_email
    group by et.group_id, date_trunc('month', et.expense_date)
  ),
  my_paid as (
    select
      e.group_id,
      date_trunc('month', e.expense_date)::date as month,
      sum(entry_sum.total) as total_paid,
      count(distinct e.id)::int as expense_count
    from expense e
    join lateral (
      select coalesce(sum(ee.amount), 0) as total
      from expense_entry ee where ee.expense_id = e.id
    ) entry_sum on true
    where e.is_paid_back_row = false
      and e.expense_date >= p_start
      and e.expense_date < p_end
      and e.paid_by = p_user_email
    group by e.group_id, date_trunc('month', e.expense_date)
  ),
  combined as (
    select group_id, month from my_share
    union
    select group_id, month from my_paid
  )
  select
    g.id as group_id,
    g.name as group_name,
    g.color_value,
    c.month,
    coalesce(p.total_paid, 0)::numeric as total_paid,
    coalesce(s.total_share, 0)::numeric as total_share,
    coalesce(p.expense_count, 0) as expense_count
  from combined c
  join "group" g on g.id = c.group_id
  left join my_paid p on p.group_id = c.group_id and p.month = c.month
  left join my_share s on s.group_id = c.group_id and s.month = c.month
  order by c.month asc, g.name asc;
$$;
