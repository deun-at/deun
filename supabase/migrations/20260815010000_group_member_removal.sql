-- group-member-removal: give membership a defined removal, and stop the ledger
-- counting shares that belong to nobody.
--
-- Three changes:
--   1. group_member.removed_at  -- nullable timestamp = soft removal marker.
--   2. update_group_member_shares -- its total_share_amount subquery never checked
--      that the *counterparty* of a share is still a group_member, so a member row
--      deleted by the old form-save path left their expense_entry_share rows
--      counting toward every remaining member's net balance. The group detail
--      (built from the outer query) and the group list (built from
--      total_share_amount) then disagreed permanently and the phantom amount
--      belonged to nobody, so no settle-up could clear it.
--   3. save_group_all -- stop deleting group_member rows for members merely absent
--      from the submitted list, and clear removed_at for members that come back.
--
-- Applied by hand against the self-hosted instance -- see docs/ristretto/MANUAL_OPS.md.

alter table public.group_member
  add column if not exists removed_at timestamptz null;

comment on column public.group_member.removed_at is
  'Set when the member was removed from the group while still appearing on past '
  'expenses. Their expense_entry_share rows and the ledger math are untouched; '
  'removal only changes visibility. Null = active member. Clearing it re-adds them.';

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
          )
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
              sub_e.paid_by <> gm.email and
              -- group-member-removal: the payer must still be a member of this
              -- group. Semi-join (exists), not a join, so no row fans out.
              exists (
                select 1 from group_member as payer_gm
                where payer_gm.group_id = gm.group_id
                  and payer_gm.email = sub_e.paid_by
              )
            ) or
            (
              sub_e.paid_by = gm.email and
              sub_ees.email <> gm.email and
              -- group-member-removal: THE fix. Without this, a share whose owner
              -- no longer has a group_member row kept counting toward gm's net
              -- balance forever. A soft-removed member still has their row, so
              -- their arithmetic is unchanged -- removal changes visibility only.
              exists (
                select 1 from group_member as sharer_gm
                where sharer_gm.group_id = gm.group_id
                  and sharer_gm.email = sub_ees.email
              )
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
    -- NOTE: currency_code is deliberately still absent from this UPDATE. It is
    -- absent in the shipped function too; preserving it keeps this migration a
    -- faithful change of member handling only. Tracked separately.
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
