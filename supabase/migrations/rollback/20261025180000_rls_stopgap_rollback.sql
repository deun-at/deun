-- Rollback for 20261025180000_rls_stopgap.sql — restores the pre-stopgap grants and
-- policies exactly as the 2026-10-24 dump shows them. Only for an emergency: it
-- reopens every gap the stopgap closed. Apply as supabase_admin. Idempotent.

begin;

-- policies the stopgap added
drop policy if exists "device_tokens: owner only" on public.device_tokens;
drop policy if exists "expense_entry: group members" on public.expense_entry;
drop policy if exists "expense_entry_share: group members" on public.expense_entry_share;
drop policy if exists "group_shares_summary: group members" on public.group_shares_summary;
drop policy if exists "user: signed-in read" on public."user";
drop policy if exists "user: insert own or guest" on public."user";
drop policy if exists "user: update own" on public."user";
drop policy if exists "user: delete orphaned guest" on public."user";
drop policy if exists "group_member: signed-in read" on public.group_member;
drop policy if exists "group_member: insert self or by member" on public.group_member;
drop policy if exists "group_member: update by member" on public.group_member;
drop policy if exists "group_member: delete by member" on public.group_member;

-- RLS off again on the tables that had none
alter table public.device_tokens disable row level security;
alter table public.expense_entry disable row level security;
alter table public.expense_entry_share disable row level security;
alter table public.group_shares_summary disable row level security;
alter table public.birthday_signup disable row level security;

-- the original open policies
drop policy if exists "Enable read access for all users" on public."user";
create policy "Enable read access for all users" on public."user" for select using (true);
drop policy if exists "Enable insert for all users" on public."user";
create policy "Enable insert for all users" on public."user" for insert with check (true);
drop policy if exists "Enable update for all users" on public."user";
create policy "Enable update for all users" on public."user" for update using (true) with check (true);
drop policy if exists "Enable delete for all users" on public."user";
create policy "Enable delete for all users" on public."user" for delete using (true);
drop policy if exists "Policy with security definer functions" on public.group_member;
create policy "Policy with security definer functions" on public.group_member to authenticated using (true);

-- anon grants back
grant all on all tables in schema public to anon;
grant all on all sequences in schema public to anon;
grant execute on all functions in schema public to anon;
alter default privileges for role postgres, supabase_admin in schema public grant all on tables to anon;
alter default privileges for role postgres, supabase_admin in schema public grant all on sequences to anon;
alter default privileges for role postgres, supabase_admin in schema public grant execute on functions to anon;

drop function if exists public.is_group_member(uuid);

commit;
