create table public.relocation_requests (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles (id),
  driver_id uuid references public.profiles (id),
  origin text not null,
  destination text not null,
  scheduled_date date not null,
  notes text,
  status text not null default 'unbooked' check (status in ('unbooked', 'booked', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.relocation_requests enable row level security;

-- Forces every INSERT into a safe initial state regardless of client-supplied values:
-- status is always 'unbooked', driver_id always NULL, created_by always the caller,
-- and id/created_at/updated_at always come from their column defaults rather than a
-- client-supplied value (an explicit INSERT value otherwise overrides a DEFAULT in
-- Postgres). This is what lets the INSERT grant below stay column-unrestricted — a
-- spoofed payload is silently corrected here rather than rejected outright.
create or replace function public.relocation_requests_before_insert()
returns trigger
language plpgsql
as $$
begin
  new.id := gen_random_uuid();
  new.status := 'unbooked';
  new.driver_id := null;
  new.created_by := auth.uid();
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

create trigger relocation_requests_before_insert
  before insert on public.relocation_requests
  for each row
  execute function public.relocation_requests_before_insert();

create or replace function public.relocation_requests_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger relocation_requests_set_updated_at
  before update on public.relocation_requests
  for each row
  execute function public.relocation_requests_set_updated_at();

-- Column-scoped privileges: RLS is row-level only, so column-level lockdown of
-- status/driver_id/created_by needs plain Postgres GRANT/REVOKE on top of it.
-- INSERT stays full-row (the BEFORE INSERT trigger above neutralizes bad values),
-- but UPDATE is restricted to only the CAP-4-editable fields — status/driver_id/
-- created_by/id/timestamps have no client-facing UPDATE grant, so all other state
-- transitions must go through the SECURITY DEFINER RPCs.
grant select, insert on public.relocation_requests to authenticated;

revoke update on public.relocation_requests from authenticated;
grant update (origin, destination, scheduled_date, notes) on public.relocation_requests to authenticated;

-- Supabase's platform-level default privileges grant DELETE (and every other
-- privilege) to `authenticated` on every newly created public-schema table, same
-- as it does for INSERT/UPDATE above — DELETE must be revoked explicitly, or the
-- `dispatcher_own` FOR ALL policy (which also covers DELETE) would let a dispatcher
-- hard-delete their own rows, contradicting "no capability ever deletes a request."
revoke delete on public.relocation_requests from authenticated;
