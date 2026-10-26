-- group-write-rpcs: adding a member, removing a member, deleting a group and
-- deleting an expense each commit as ONE server transaction, recalculation and
-- checker cleanup included, or not at all.
--
-- Replaces four client-side multi-statement writes (group_repository.dart
-- addMember / removeMember / delete, expense_repository.dart delete). Each sent
-- its write and then `update_group_member_shares` as separate requests, so a
-- failure half-way left a removed member whose balances were never recalculated,
-- a deleted expense still counted, or a deleted group still in another list.
--
-- 1. add_group_member(group, email) -> 'inserted' | 're_added' | 'already_member'.
--    Takes the group's member-write lock (lock_group_member_writes, created by
--    20261026100000_join_group_guest_merge.sql and reused unchanged), then:
--    no row -> insert (is_favorite false); a soft-removed row -> clear removed_at;
--    an active row -> write nothing and do not recalculate.
-- 2. remove_group_member(group, email, settled_epsilon) -> jsonb
--    {outcome: 'blocked' | 'soft_removed' | 'hard_removed', outstanding}.
--    Member-write lock, a caller membership check, then SHARE locks on expense and
--    expense_entry_share: every writer that creates history or moves a balance
--    (save_expense_all, pay_back, claim_set_unit_shares, join_group's merge,
--    delete_expense) takes ROW EXCLUSIVE on one of them, so an in-flight writer
--    commits before the balance and history reads, and a new one waits until the
--    removal commits. Locked in the order every writer touches them (expense
--    first). Unsettled (abs(balance) >= the epsilon the client sent, the mirror of
--    isSettled) -> blocked, nothing written. Settled with history (paid_by on, or
--    a share on, any of the group's expenses) -> stamp removed_at. Otherwise ->
--    delete the row.
-- 3. delete_group(group): today's two deletes; never recalculates, because the
--    recalc would re-create the group_update_checker row other lists drop on.
-- 4. delete_expense(expense, group): the delete is scoped to the group, then the
--    expense's checker row, then a recalc with a NULL expense id so the deleted
--    row is never re-announced.
--
-- All four: SECURITY INVOKER and volatile (the plpgsql defaults), no grants, no
-- `set search_path` (update_group_member_shares uses unqualified table names and
-- inherits the caller's search_path, as in join_group). RLS decides exactly as
-- it did for the direct statements. The explicit checker deletes are RLS no-ops
-- today (neither checker table has a DELETE policy); the FK cascades from
-- "group" and expense remove those rows, and their DELETE events still reach
-- realtime. No table is added to any publication.
--
-- NOT YET APPLIED. Apply as supabase_admin after 20261026100000 (it calls
-- lock_group_member_writes), BEFORE releasing a build containing
-- group-write-rpcs: the app has no fallback. Re-runnable.
-- Tested on the local harness: supabase/tests/rls_stopgap/60_group_write_cases.sql.

begin;

create or replace function public.add_group_member(_group_id uuid, _email text)
returns text
language plpgsql
as $add_group_member$
declare
  _removed_at timestamptz;
  _outcome text;
begin
  perform public.lock_group_member_writes(_group_id);

  select gm.removed_at into _removed_at
  from public.group_member as gm
  where gm.group_id = _group_id and gm.email = _email;

  if not found then
    insert into public.group_member (group_id, email, is_favorite)
    values (_group_id, _email, false);
    _outcome := 'inserted';
  elsif _removed_at is not null then
    update public.group_member
      set removed_at = null
      where group_id = _group_id and email = _email and removed_at is not null;
    _outcome := 're_added';
  else
    return 'already_member';
  end if;

  perform public.update_group_member_shares(_group_id, null::uuid);
  return _outcome;
end;
$add_group_member$;

create or replace function public.remove_group_member(
  _group_id uuid,
  _email text,
  _settled_epsilon numeric
)
returns jsonb
language plpgsql
as $remove_group_member$
declare
  _balance numeric;
  _has_history boolean;
  _outcome text;
begin
  perform public.lock_group_member_writes(_group_id);

  if not public.is_group_member(_group_id) then
    raise exception 'remove_group_member: caller is not a member of group %', _group_id
      using errcode = '42501';
  end if;

  if _settled_epsilon is null or _settled_epsilon <= 0 then
    raise exception 'remove_group_member: settled epsilon must be positive, got %', _settled_epsilon
      using errcode = '22023';
  end if;

  lock table public.expense in share mode;
  lock table public.expense_entry_share in share mode;

  select gss.total_share_amount into _balance
  from public.group_shares_summary as gss
  where gss.group_id = _group_id and gss.paid_for = _email
  limit 1;
  _balance := coalesce(_balance, 0);

  if abs(_balance) >= _settled_epsilon then
    return jsonb_build_object('outcome', 'blocked', 'outstanding', abs(_balance));
  end if;

  _has_history := exists (
    select 1 from public.expense as e
    where e.group_id = _group_id and e.paid_by = _email
  ) or exists (
    select 1 from public.expense_entry_share as s
    join public.expense_entry as ee on ee.id = s.expense_entry_id
    join public.expense as e on e.id = ee.expense_id
    where e.group_id = _group_id and s.email = _email
  );

  if _has_history then
    update public.group_member
      set removed_at = now()
      where group_id = _group_id and email = _email and removed_at is null;
    _outcome := 'soft_removed';
  else
    delete from public.group_member
      where group_id = _group_id and email = _email;
    _outcome := 'hard_removed';
  end if;

  perform public.update_group_member_shares(_group_id, null::uuid);
  return jsonb_build_object('outcome', _outcome, 'outstanding', abs(_balance));
end;
$remove_group_member$;

create or replace function public.delete_group(_group_id uuid)
returns void
language plpgsql
as $delete_group$
begin
  delete from public."group" where id = _group_id;
  delete from public.group_update_checker where group_id = _group_id;
end;
$delete_group$;

create or replace function public.delete_expense(_expense_id uuid, _group_id uuid)
returns void
language plpgsql
as $delete_expense$
begin
  delete from public.expense where id = _expense_id and group_id = _group_id;
  delete from public.expense_update_checker
    where expense_id = _expense_id and group_id = _group_id;
  perform public.update_group_member_shares(_group_id, null::uuid);
end;
$delete_expense$;

commit;
