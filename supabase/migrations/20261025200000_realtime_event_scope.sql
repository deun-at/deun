-- realtime-event-scope: let the group list's and friend list's filtered realtime
-- channels hear deletes, and let the group list hear a group the user joins.
--
-- 1. Replica identity full on group_update_checker and friendship. Realtime can
--    match a DELETE against a channel filter (group_id=in.(...), requester=eq.,
--    addressee=eq.) only when the old row carries the filtered column. Without it
--    a group another member deleted, or a friend request someone cancelled, stays
--    on other devices until a reload.
--    Accepted cost: RLS is not applied to deletes, but RLS trims a DELETE's old
--    record to the primary key: the group id for group_update_checker, the two
--    emails for friendship.
-- 2. group_member joins supabase_realtime, so the group list's email=eq.<user>
--    channel hears a group the user creates, joins or is added to. Its SELECT
--    policy (20261025190000) already limits insert and update events to the
--    caller's own groups and rows.
--
-- Deliberately not here: full identity on group_member (its deletes would send
-- every removed member's email to every subscriber; a hard removal is heard
-- through the group's checker bump instead) and anything on
-- expense_update_checker. No RLS, policy or data statement.
--
-- NOT YET APPLIED. Apply after 20261025190000. Re-runnable.

begin;

alter table public.group_update_checker replica identity full;
alter table public.friendship replica identity full;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise exception 'publication supabase_realtime does not exist';
  end if;
  -- A FOR ALL TABLES publication already carries group_member.
  if exists (
    select 1 from pg_publication
    where pubname = 'supabase_realtime' and puballtables
  ) then
    return;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'group_member'
  ) then
    alter publication supabase_realtime add table public.group_member;
  end if;
end
$$;

commit;
