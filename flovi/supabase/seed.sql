-- seed.sql — demo data for Epic 2 (dispatcher-web) and Epic 3 (driver-mobile) to build
-- against before either app's real login flow exists.
--
-- IMPORTANT — these seeded accounts can never actually sign in. This project's only
-- auth path is Google OAuth (no email/password flow exists anywhere in this spec), and
-- these `auth.users` rows are created via the Supabase Dashboard's "Add user" (or the
-- Admin API) with no real Google identity behind them. Their sole purpose is to give
-- the Requests list status-pill variety (AC #2) and to give the priority mechanic
-- pre-existing competitors with different `completed_rides_count` values to rank
-- against once a *real* driver (a genuine Google-authenticated account) logs in. For
-- the live demo, the operator needs 2–3 of their own real Google accounts to play the
-- competing-drivers role — see Story 1.6 Dev Notes.
--
-- Prerequisite (do this first, out-of-band): create 5 auth users via Supabase Dashboard
-- → Authentication → Users → Add user (or the Admin API's
-- `supabase.auth.admin.createUser({ email, email_confirm: true })`). Do NOT hand-write
-- `INSERT INTO auth.users` — `profiles.id` is FK'd to `auth.users(id)`, and raw inserts
-- into `auth.users` are not a safe/supported pattern against a hosted project (missing
-- `auth.identities` rows, internal trigger/constraint fragility). Paste the 5 real
-- UUIDs returned by that step into the placeholders below before running this script.
--
-- Run as a privileged role (e.g. the Supabase SQL Editor), not as `authenticated` —
-- the INSERT-then-UPDATE pattern below relies on this script's session not being
-- subject to Story 1.2's `REVOKE UPDATE ... FROM authenticated`.

-- ---------------------------------------------------------------------------
-- These 5 auth.users rows already exist in the flovi-challenge Supabase project
-- (created via Dashboard → Authentication → Users → Add user, auto-confirmed):
-- Dispatcher 1: f307bf58-f3ff-4622-9318-34783ae92f79 (demo.dispatcher1@flovi.test)
-- Dispatcher 2: 6e0b4b4f-672c-4454-995c-cb9c6fe90ba7 (demo.dispatcher2@flovi.test)
-- Driver A:     43027bbe-661c-4090-9f35-3d798223517e (demo.drivera@flovi.test)
-- Driver B:     e3f3fd2f-a3bb-4c8d-b8f2-4e4d3e00af2c (demo.driverb@flovi.test)
-- Driver C:     6a9244cc-e573-474a-b109-491ff825863a (demo.driverc@flovi.test)

-- ---------------------------------------------------------------------------
-- Profiles: 2 dispatchers, 3 drivers with varying completed_rides_count so the
-- priority rule (highest completed_rides_count wins ties) is demoable.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, role, full_name, completed_rides_count) values
  ('f307bf58-f3ff-4622-9318-34783ae92f79', 'dispatcher', 'Demo Dispatcher 1', 0),
  ('6e0b4b4f-672c-4454-995c-cb9c6fe90ba7', 'dispatcher', 'Demo Dispatcher 2', 0),
  ('43027bbe-661c-4090-9f35-3d798223517e', 'driver',     'Demo Driver A',     0),
  ('e3f3fd2f-a3bb-4c8d-b8f2-4e4d3e00af2c', 'driver',     'Demo Driver B',     3),
  ('6a9244cc-e573-474a-b109-491ff825863a', 'driver',     'Demo Driver C',     7);

-- ---------------------------------------------------------------------------
-- Relocation requests: 2 unbooked, 2 booked, 1 completed.
--
-- Two separate trigger effects to work around here, both from Story 1.2's
-- `relocation_requests_before_insert` BEFORE INSERT trigger:
--   1. It unconditionally forces status = 'unbooked' / driver_id = NULL on every
--      INSERT, regardless of what's specified — correct for real client inserts,
--      but it neutralizes a plain INSERT's attempt to seed a non-unbooked row.
--      Rows that need to land as 'booked'/'completed' are inserted first, then
--      explicitly UPDATEd to their target status in a second statement against
--      the row's trigger-generated id.
--   2. It also sets `created_by := auth.uid()` unconditionally. Run as the
--      `postgres` role (no JWT), `auth.uid()` is NULL, which fails the column's
--      NOT NULL constraint outright — even for the plain unbooked inserts. Each
--      insert below is preceded by `set_config('request.jwt.claim.sub', ...)` to
--      simulate the intended dispatcher as caller, same technique Story 1.4/1.5's
--      verification used to simulate `auth.uid()` outside a real client session.
-- ---------------------------------------------------------------------------

-- Unbooked #1 (created_by: Dispatcher 1)
select set_config('request.jwt.claim.sub', 'f307bf58-f3ff-4622-9318-34783ae92f79', true);
insert into public.relocation_requests (origin, destination, scheduled_date, notes) values
  ('Miami, FL', 'Orlando, FL', current_date + 3, 'Standard relocation, no rush');

-- Unbooked #2 (created_by: Dispatcher 2)
select set_config('request.jwt.claim.sub', '6e0b4b4f-672c-4454-995c-cb9c6fe90ba7', true);
insert into public.relocation_requests (origin, destination, scheduled_date, notes) values
  ('Tampa, FL', 'Jacksonville, FL', current_date + 5, null);

-- Booked #1 — created by Dispatcher 1, assigned to Driver B
select set_config('request.jwt.claim.sub', 'f307bf58-f3ff-4622-9318-34783ae92f79', true);
do $$
declare
  v_id uuid;
begin
  insert into public.relocation_requests (origin, destination, scheduled_date, notes)
  values ('Fort Lauderdale, FL', 'Naples, FL', current_date + 2, 'Customer requested morning pickup')
  returning id into v_id;

  update public.relocation_requests
  set status = 'booked', driver_id = 'e3f3fd2f-a3bb-4c8d-b8f2-4e4d3e00af2c'
  where id = v_id;
end $$;

-- Booked #2 — created by Dispatcher 2, assigned to Driver C
select set_config('request.jwt.claim.sub', '6e0b4b4f-672c-4454-995c-cb9c6fe90ba7', true);
do $$
declare
  v_id uuid;
begin
  insert into public.relocation_requests (origin, destination, scheduled_date, notes)
  values ('Orlando, FL', 'Tampa, FL', current_date + 1, null)
  returning id into v_id;

  update public.relocation_requests
  set status = 'booked', driver_id = '6a9244cc-e573-474a-b109-491ff825863a'
  where id = v_id;
end $$;

-- Completed — created by Dispatcher 1, assigned to Driver A, already finished
select set_config('request.jwt.claim.sub', 'f307bf58-f3ff-4622-9318-34783ae92f79', true);
do $$
declare
  v_id uuid;
begin
  insert into public.relocation_requests (origin, destination, scheduled_date, notes)
  values ('Jacksonville, FL', 'Miami, FL', current_date - 2, 'Completed last week')
  returning id into v_id;

  update public.relocation_requests
  set status = 'completed', driver_id = '43027bbe-661c-4090-9f35-3d798223517e'
  where id = v_id;
end $$;
