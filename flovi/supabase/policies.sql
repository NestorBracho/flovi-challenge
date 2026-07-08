-- profiles: open read for any authenticated user (both apps resolve id/role/full_name/completed_rides_count).
-- No INSERT/UPDATE/DELETE policy is defined on purpose — every write path is a SECURITY DEFINER RPC
-- (e.g. claim_role), and RLS's default-deny with zero write policies blocks all direct client writes.
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);
