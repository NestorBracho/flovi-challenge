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

-- cancel_request_dispatcher: lets the owning dispatcher cancel their own request from
-- any non-cancelled status (including completed), per CAP-10's "at any time" rule.
-- SECURITY DEFINER bypasses RLS, so this independently re-verifies caller role and
-- ownership before writing (AD-3) — the column-level UPDATE lockdown on `status`
-- (see relocation_requests migration) does not block this function's own UPDATE,
-- since it runs as the function owner, not as the calling `authenticated` role.
create or replace function public.cancel_request_dispatcher(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_created_by uuid;
begin
  select role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is distinct from 'dispatcher' then
    raise exception 'cancel_request_dispatcher requires the caller to be a dispatcher';
  end if;

  select created_by into v_created_by
  from public.relocation_requests
  where id = p_request_id;

  if not found then
    raise exception 'cancel_request_dispatcher: relocation request % does not exist', p_request_id;
  end if;

  if v_created_by is distinct from auth.uid() then
    raise exception 'cancel_request_dispatcher: caller does not own relocation request %', p_request_id;
  end if;

  -- Idempotency check folded into the WHERE clause so the already-cancelled check
  -- and the write happen as one atomic statement instead of separate read-then-write
  -- steps.
  update public.relocation_requests
  set status = 'cancelled'
  where id = p_request_id
    and status <> 'cancelled';
end;
$$;

-- book_request: resolves the priority-based winner among concurrent bidders for an
-- unbooked relocation request. The client must INSERT its own booking_bids row itself
-- (a plain RLS-gated table write, committed independently) immediately before calling
-- this RPC — see Story 1.3 Dev Notes for why the bid insert cannot happen inside this
-- function. This function's own transaction cannot see another concurrent session's
-- writes until that session commits, and this function only commits at the very end
-- of its own sleep-then-decide logic; if the insert happened in here too, whichever
-- caller's transaction won the row lock first would decide using only its own bid,
-- silently making lock-acquisition order the tie-break instead of completed_rides_count.
create or replace function public.book_request(p_request_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_status text;
  v_driver_id uuid;
  v_winner uuid;
begin
  select role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is distinct from 'driver' then
    raise exception 'book_request requires the caller to be a driver';
  end if;

  -- Bid window: gives every genuinely-concurrent bidder's own direct INSERT (made by
  -- their own client, right before calling this RPC) time to commit and become visible
  -- to this transaction's read of booking_bids below.
  perform pg_sleep(0.3);

  select status, driver_id into v_status, v_driver_id
  from public.relocation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'book_request: relocation request % does not exist', p_request_id;
  end if;

  if v_status = 'unbooked' then
    -- Idempotent safety-net: guarantees at least the caller's own bid exists even if
    -- the client somehow reached this RPC without inserting one first, so the
    -- winner-selection query below is never empty.
    insert into public.booking_bids (request_id, driver_id)
    values (p_request_id, auth.uid())
    on conflict do nothing;

    -- completed_rides_count is read fresh here, never cached on the bid row, so the
    -- priority read happens inside the same transaction that performs the resulting
    -- write (AD-6).
    select bb.driver_id into v_winner
    from public.booking_bids bb
    join public.profiles p on p.id = bb.driver_id
    where bb.request_id = p_request_id
    order by p.completed_rides_count desc, bb.bid_at asc
    limit 1;

    update public.relocation_requests
    set driver_id = v_winner, status = 'booked'
    where id = p_request_id;

    -- Resets the ledger so a future rebooking round (e.g. after a revert-to-unbooked
    -- path) doesn't see stale bids from this round.
    delete from public.booking_bids where request_id = p_request_id;

    return v_winner = auth.uid();
  end if;

  -- Someone else already decided, or the row was never open: no assignment logic
  -- runs, no state change. Covers both the losing bidder (AC #5) and the
  -- already-closed request (AC #6).
  return v_driver_id = auth.uid();
end;
$$;

-- cancel_request_driver: lets the driver assigned to a booked request cancel it before
-- the 24h cutoff (AD-7). A cancellation never leaves the request stranded: the highest
-- completed_rides_count active driver (excluding the canceller) is auto-assigned if one
-- exists, else the request reverts to 'unbooked'. Either way, the owning dispatcher gets
-- a notifications row describing what happened (AC #3), using EXPERIENCE.md's verbatim
-- microcopy (Story 2.4 renders this message as-is, unparaphrased).
create or replace function public.cancel_request_driver(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_status text;
  v_driver_id uuid;
  v_scheduled_date date;
  v_created_by uuid;
  v_cutoff timestamptz;
  v_new_driver_id uuid;
  v_cancelling_driver_name text;
  v_new_driver_name text;
  v_message text;
begin
  select role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is distinct from 'driver' then
    raise exception 'cancel_request_driver requires the caller to be a driver';
  end if;

  -- Locks the row before any decision, defending against a concurrent
  -- cancel_request_dispatcher call racing this one. Unlike book_request, only one
  -- legitimate caller ever exists per request here, so a single FOR UPDATE is
  -- sufficient — no bid-window is needed (see Dev Notes).
  select status, driver_id, scheduled_date, created_by
  into v_status, v_driver_id, v_scheduled_date, v_created_by
  from public.relocation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'cancel_request_driver: relocation request % does not exist', p_request_id;
  end if;

  if v_driver_id is distinct from auth.uid() then
    raise exception 'cancel_request_driver: caller does not own relocation request %', p_request_id;
  end if;

  -- Defensive, not explicitly an AC: guards against a dispatcher having cancelled R a
  -- moment earlier while the driver's client still shows it as their booked gig (stale
  -- realtime lag).
  if v_status is distinct from 'booked' then
    raise exception 'cancel_request_driver: relocation request % is not booked', p_request_id;
  end if;

  -- Defensively-correct cutoff form (see Dev Notes): correct regardless of session
  -- timezone, not just under Supabase's UTC default that AD-7's literal formula relies on.
  v_cutoff := (v_scheduled_date::timestamp at time zone 'UTC') - interval '24 hours';

  if now() >= v_cutoff then
    raise exception 'Too close to the ride to cancel (within 24h).';
  end if;

  -- Reassignment ranking: highest completed_rides_count among active drivers,
  -- excluding the canceller. id ASC is an arbitrary-but-stable tiebreak (profiles has
  -- no created_at column to break ties on chronologically — see Dev Notes).
  select id into v_new_driver_id
  from public.profiles
  where role = 'driver' and is_active = true and id <> auth.uid()
  order by completed_rides_count desc, id asc
  limit 1;

  if v_new_driver_id is not null then
    update public.relocation_requests
    set driver_id = v_new_driver_id
    where id = p_request_id;
  else
    update public.relocation_requests
    set status = 'unbooked', driver_id = null
    where id = p_request_id;
  end if;

  select full_name into v_cancelling_driver_name
  from public.profiles
  where id = auth.uid();

  if v_new_driver_id is not null then
    select full_name into v_new_driver_name
    from public.profiles
    where id = v_new_driver_id;

    v_message := v_cancelling_driver_name || ' cancelled a gig — automatically reassigned to ' || v_new_driver_name || '.';
  else
    v_message := v_cancelling_driver_name || ' cancelled a gig — returned to the available pool.';
  end if;

  insert into public.notifications (request_id, dispatcher_id, message)
  values (p_request_id, v_created_by, v_message);
end;
$$;

-- complete_request: lets the driver assigned to a booked request mark it completed,
-- incrementing their own completed_rides_count in the same transaction (AD-6). This is
-- the only path that ever writes completed_rides_count — book_request (Story 1.3) and
-- cancel_request_driver (Story 1.4) both only ever read it live at decision time.
create or replace function public.complete_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_role text;
  v_status text;
  v_driver_id uuid;
begin
  select role into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is distinct from 'driver' then
    raise exception 'complete_request requires the caller to be a driver';
  end if;

  -- Locks the row before any decision, defending against a concurrent
  -- cancel_request_driver/cancel_request_dispatcher call racing this one. Only one
  -- legitimate caller ever exists per request here, so a single FOR UPDATE is
  -- sufficient — no bid-window is needed (same reasoning as cancel_request_driver).
  select status, driver_id into v_status, v_driver_id
  from public.relocation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'complete_request: relocation request % does not exist', p_request_id;
  end if;

  if v_driver_id is distinct from auth.uid() then
    raise exception 'complete_request: caller does not own relocation request %', p_request_id;
  end if;

  -- Covers "R is not currently booked": already completed/cancelled, or reassigned
  -- away from this caller since their client last saw it.
  if v_status is distinct from 'booked' then
    raise exception 'complete_request: relocation request % is not booked', p_request_id;
  end if;

  update public.relocation_requests
  set status = 'completed'
  where id = p_request_id;

  -- No client-facing UPDATE policy exists on profiles at all (Story 1.1) — this
  -- SECURITY DEFINER function's RLS-bypass is the only path that can ever increment
  -- completed_rides_count.
  update public.profiles
  set completed_rides_count = completed_rides_count + 1
  where id = auth.uid();
end;
$$;
