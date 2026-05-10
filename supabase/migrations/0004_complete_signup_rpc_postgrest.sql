-- Apply / refresh complete_signup RPC for Flutter signup (fixes PGRST202 if migration 0003 was skipped or cache mismatch).
-- Run via Supabase CLI or paste into SQL Editor.

begin;

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
