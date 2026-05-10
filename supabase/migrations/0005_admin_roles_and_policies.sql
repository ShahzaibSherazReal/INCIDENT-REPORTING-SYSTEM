-- Extend roles with Admin + Super Administrator; let them manage cameras/users like legacy System Administrator.

begin;

alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check
  check (role in ('User', 'Operator', 'Admin', 'Super Administrator', 'System Administrator'));

create or replace function public.current_user_is_staff_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_user_role() in ('Admin', 'Super Administrator', 'System Administrator'),
    false
  );
$$;

drop policy if exists "Admins can manage cameras" on public.cameras;
create policy "Admins can manage cameras"
on public.cameras
for all
to authenticated
using (public.current_user_is_staff_manager())
with check (public.current_user_is_staff_manager());

drop policy if exists "Admins can view all profiles" on public.users;
create policy "Admins can view all profiles"
on public.users
for select
to authenticated
using (public.current_user_is_staff_manager());

drop policy if exists "Admins can insert profiles" on public.users;
create policy "Admins can insert profiles"
on public.users
for insert
to authenticated
with check (public.current_user_is_staff_manager());

drop policy if exists "Admins can update profiles" on public.users;
create policy "Admins can update profiles"
on public.users
for update
to authenticated
using (public.current_user_is_staff_manager())
with check (public.current_user_is_staff_manager());

drop policy if exists "Backend service can insert incidents" on public.incidents;
create policy "Backend service can insert incidents"
on public.incidents
for insert
to authenticated
with check (public.current_user_is_staff_manager());

commit;
