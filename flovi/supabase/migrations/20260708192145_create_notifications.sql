create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.relocation_requests (id),
  dispatcher_id uuid not null references public.profiles (id),
  message text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.notifications enable row level security;

-- Only cancel_request_driver (SECURITY DEFINER) ever inserts a notification, so no
-- INSERT/DELETE grant is given to authenticated at all. SELECT is open (RLS scopes
-- visibility to the owning dispatcher); UPDATE is restricted to read_at only, built
-- now even though no AC in this story exercises it — Story 2.4 (Epic 2) needs to
-- mark visible unread notifications read via a direct client-side UPDATE, and per
-- AD-1, Epic 2 has zero domain logic of its own, so this grant must already exist.
grant select on public.notifications to authenticated;

revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Supabase's platform-level default privileges grant INSERT/DELETE to `authenticated`
-- on every newly created public-schema table (see relocation_requests migration) —
-- both must be revoked explicitly, since only cancel_request_driver (SECURITY DEFINER)
-- ever inserts a row here, and nothing ever deletes one.
revoke insert, delete on public.notifications from authenticated;
