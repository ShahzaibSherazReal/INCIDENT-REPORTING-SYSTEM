-- Roles: User + Operator + System Administrator; username login helper; operator signup RPC; incident validation flag.

begin;

-- Allow normal app accounts (vs dashboard Operator / legacy System Administrator).
alter table public.users drop constraint if exists users_role_check;
alter table public.users add constraint users_role_check
  check (role in ('User', 'Operator', 'System Administrator'));

alter table public.users add column if not exists username text;
create unique index if not exists idx_users_username_lower on public.users (lower(trim(username)))
  where username is not null and trim(username) <> '';

alter table public.incidents add column if not exists operator_validated boolean not null default false;

-- Resolve email for login when user types username (anon may call).
create or replace function public.resolve_login_identifier(p_identifier text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select u.email::text
  from public.users u
  where lower(trim(u.email)) = lower(trim(p_identifier))
     or (
       u.username is not null
       and trim(u.username) <> ''
       and lower(trim(u.username)) = lower(trim(p_identifier))
     )
  limit 1;
$$;

grant execute on function public.resolve_login_identifier(text) to anon, authenticated;

-- Finish signup after auth.signUp (session required). Operator requires invite code (hardcoded check).
-- Parameter order matches PostgREST RPC lookup (alphabetical json keys: p_operator_code, p_register_as_operator, p_username).
create or replace function public.complete_signup(
  p_operator_code text,
  p_register_as_operator boolean,
  p_username text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  auth_email text;
  clean_user text := trim(p_username);
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if clean_user is null or clean_user = '' then
    raise exception 'Username required';
  end if;
  if length(clean_user) < 2 then
    raise exception 'Username too short';
  end if;

  select email into auth_email from auth.users where id = uid;
  if auth_email is null then
    raise exception 'Auth user missing';
  end if;

  if exists (select 1 from public.users where id = uid) then
    raise exception 'Profile already exists';
  end if;

  if p_register_as_operator then
    if trim(coalesce(p_operator_code, '')) is distinct from '000000' then
      raise exception 'Invalid operator code';
    end if;
    insert into public.users (id, email, username, role)
    values (uid, auth_email, clean_user, 'Operator');
  else
    insert into public.users (id, email, username, role)
    values (uid, auth_email, clean_user, 'User');
  end if;
end;
$$;

grant execute on function public.complete_signup(text, boolean, text) to authenticated;

commit;
