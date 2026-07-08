-- claim_role: permanently assigns a role to the calling user on first call.
-- Idempotent for a matching role; raises on any attempt to claim a different role.
create or replace function public.claim_role(p_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing_role text;
  v_full_name text;
begin
  if auth.uid() is null then
    raise exception 'claim_role requires an authenticated user';
  end if;

  select role into v_existing_role
  from public.profiles
  where id = auth.uid();

  if v_existing_role is null then
    select coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name')
    into v_full_name
    from auth.users
    where id = auth.uid();

    insert into public.profiles (id, role, full_name)
    values (auth.uid(), p_role, v_full_name);
  elsif v_existing_role = p_role then
    return;
  else
    raise exception 'user % already holds role %, cannot claim %', auth.uid(), v_existing_role, p_role;
  end if;
end;
$$;
