create table public.profiles (
  id uuid primary key references auth.users (id),
  role text not null check (role in ('dispatcher', 'driver')),
  full_name text,
  completed_rides_count int not null default 0,
  is_active boolean not null default true
);

alter table public.profiles enable row level security;

-- Defense-in-depth, matching the explicit grant/revoke surface every other table in
-- this schema uses. Supabase's platform-level default privileges grant INSERT/UPDATE/
-- DELETE (and SELECT) to `authenticated` on every new public-schema table. profiles is
-- already write-locked by RLS alone — no write policy exists, so RLS default-denies all
-- client writes, which is what makes the SECURITY DEFINER RPCs the only writers of
-- `role`/`completed_rides_count` (AD-2/AD-6). Revoking the write grants explicitly means
-- that lock no longer rests solely on "no permissive write policy is ever added later."
-- SELECT stays granted (scoped by the open profiles_select_authenticated policy).
grant select on public.profiles to authenticated;
revoke insert, update, delete on public.profiles from authenticated;
