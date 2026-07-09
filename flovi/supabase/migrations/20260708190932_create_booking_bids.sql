create table public.booking_bids (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.relocation_requests (id),
  driver_id uuid not null references public.profiles (id),
  bid_at timestamptz not null default now()
);

alter table public.booking_bids enable row level security;

-- Only INSERT is granted to authenticated — book_request (SECURITY DEFINER) is the
-- only reader/writer for SELECT/UPDATE/DELETE on this table (see policies.sql).
grant insert on public.booking_bids to authenticated;

revoke select, update, delete on public.booking_bids from authenticated;
