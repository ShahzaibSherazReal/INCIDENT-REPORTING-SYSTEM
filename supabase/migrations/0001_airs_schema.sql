-- AIRS initial schema, constraints, and RLS policies
-- Run in Supabase SQL Editor or via Supabase CLI migrations

begin;

create extension if not exists "pgcrypto";

-- Enum-like constraints can be done via CHECK for easier future edits.
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  role text not null check (role in ('Operator', 'System Administrator')),
  created_at timestamptz not null default now()
);

create table if not exists public.cameras (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  stream_url text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  camera_id uuid not null references public.cameras(id) on delete cascade,
  incident_type text not null check (
    incident_type in ('Fire', 'Smoke', 'Weapon', 'Accident', 'Fall', 'PPE Violation')
  ),
  confidence_score numeric(5, 4) not null check (confidence_score >= 0 and confidence_score <= 1),
  snapshot_url text not null,
  is_false_positive boolean not null default false
);

revoke all on public.users from anon, authenticated;
revoke all on public.cameras from anon, authenticated;
revoke all on public.incidents from anon, authenticated;

grant select on public.users to authenticated;
grant select on public.cameras to authenticated;
grant select on public.incidents to authenticated;
grant insert, update, delete on public.cameras to authenticated;
grant insert on public.users to authenticated;
grant update(role, email) on public.users to authenticated;
grant update(is_false_positive) on public.incidents to authenticated;

create index if not exists idx_incidents_created_at on public.incidents(created_at desc);
create index if not exists idx_incidents_camera_id on public.incidents(camera_id);
create index if not exists idx_cameras_active on public.cameras(is_active);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_cameras_updated_at on public.cameras;
create trigger trg_cameras_updated_at
before update on public.cameras
for each row
execute function public.set_updated_at();

-- ===== RLS =====
alter table public.users enable row level security;
alter table public.cameras enable row level security;
alter table public.incidents enable row level security;

create or replace function public.current_user_role()
returns text
language sql
stable
as $$
  select role from public.users where id = auth.uid()
$$;

-- users table policies
drop policy if exists "Users can view own profile" on public.users;
create policy "Users can view own profile"
on public.users
for select
to authenticated
using (id = auth.uid());

drop policy if exists "Admins can view all profiles" on public.users;
create policy "Admins can view all profiles"
on public.users
for select
to authenticated
using (public.current_user_role() = 'System Administrator');

drop policy if exists "Admins can insert profiles" on public.users;
create policy "Admins can insert profiles"
on public.users
for insert
to authenticated
with check (public.current_user_role() = 'System Administrator');

drop policy if exists "Admins can update profiles" on public.users;
create policy "Admins can update profiles"
on public.users
for update
to authenticated
using (public.current_user_role() = 'System Administrator')
with check (public.current_user_role() = 'System Administrator');

-- cameras policies
drop policy if exists "Authenticated can read cameras" on public.cameras;
create policy "Authenticated can read cameras"
on public.cameras
for select
to authenticated
using (true);

drop policy if exists "Admins can manage cameras" on public.cameras;
create policy "Admins can manage cameras"
on public.cameras
for all
to authenticated
using (public.current_user_role() = 'System Administrator')
with check (public.current_user_role() = 'System Administrator');

-- incidents policies
drop policy if exists "Authenticated can read incidents" on public.incidents;
create policy "Authenticated can read incidents"
on public.incidents
for select
to authenticated
using (true);

drop policy if exists "Backend service can insert incidents" on public.incidents;
create policy "Backend service can insert incidents"
on public.incidents
for insert
to authenticated
with check (public.current_user_role() = 'System Administrator');

drop policy if exists "Authenticated can mark false positive" on public.incidents;
create policy "Authenticated can mark false positive"
on public.incidents
for update
to authenticated
using (true)
with check (
  is_false_positive in (true, false)
);

commit;
