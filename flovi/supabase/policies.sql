-- profiles: open read for any authenticated user (both apps resolve id/role/full_name/completed_rides_count).
-- No INSERT/UPDATE/DELETE policy is defined on purpose — every write path is a SECURITY DEFINER RPC
-- (e.g. claim_role), and RLS's default-deny with zero write policies blocks all direct client writes.
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

-- relocation_requests: a dispatcher may view/edit/cancel only the rows they created —
-- never another dispatcher's (AD-4). Role-gated (not just predicate-gated) so this
-- permissive policy can never OR-combine with driver_visibility (Story 1.3) across roles.
-- FOR ALL covers SELECT/UPDATE/DELETE; DELETE is moot since no GRANT for it ever exists.
create policy "dispatcher_own"
on public.relocation_requests
for all
to authenticated
using (
  (select role from public.profiles where id = auth.uid()) = 'dispatcher'
  and created_by = auth.uid()
)
with check (
  (select role from public.profiles where id = auth.uid()) = 'dispatcher'
  and created_by = auth.uid()
);

-- relocation_requests: a driver may view unbooked rows (the open pool) plus any row
-- currently assigned to them — never another driver's booked/completed/cancelled rows.
-- FOR SELECT only, never FOR ALL: dispatcher_own and driver_visibility must never
-- OR-combine into write access for the wrong role (see Story 1.3 Dev Notes). Every
-- driver-side mutation goes through a SECURITY DEFINER RPC (book_request), never a
-- direct table write, so no write policy is needed here.
create policy "driver_visibility"
on public.relocation_requests
for select
to authenticated
using (
  (select role from public.profiles where id = auth.uid()) = 'driver'
  and (status = 'unbooked' or driver_id = auth.uid())
);

-- booking_bids: a driver may insert only their own bid row. No SELECT/UPDATE/DELETE
-- policy is defined on purpose — only book_request (SECURITY DEFINER) ever reads or
-- deletes bids; RLS's default-deny with zero read/write policies for those commands
-- blocks all direct client access to other drivers' bids.
create policy "booking_bids_insert_own"
on public.booking_bids
for insert
to authenticated
with check (
  (select role from public.profiles where id = auth.uid()) = 'driver'
  and driver_id = auth.uid()
);

-- notifications: a dispatcher may only see/update their own notifications. FOR ALL
-- covers SELECT/UPDATE (INSERT/DELETE are moot since no GRANT for either ever exists —
-- only cancel_request_driver, as a SECURITY DEFINER function, ever inserts a row).
create policy "dispatcher_own_notifications"
on public.notifications
for all
to authenticated
using (dispatcher_id = auth.uid())
with check (dispatcher_id = auth.uid());
