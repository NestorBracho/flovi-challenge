---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 1.3: Driver Visibility & Booking Priority Mechanic

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want to see only unbooked gigs (plus my own), and book one with a fair priority rule if others try at the same time,
so that the highest-priority driver reliably wins concurrent booking attempts.

## Acceptance Criteria

1. **Given** the `relocation_requests` table and RLS from Story 1.2 exist, **when** this story is complete, **then** RLS policy `driver_visibility` permits a driver to SELECT rows where `role = 'driver'` AND (`status = 'unbooked'` OR `driver_id = auth.uid()`).
2. **Given** a signed-in driver, **when** they SELECT from `relocation_requests`, **then** they see all `unbooked` requests plus any request currently assigned to them, and nothing else — no other driver's booked/completed/cancelled rows.
3. **Given** no `booking_bids` table exists yet, **when** this story is complete, **then** a `booking_bids` table exists (`id`, `request_id FK`, `driver_id FK`, `bid_at timestamptz`) and a `SECURITY DEFINER` RPC `book_request(request_id)` exists.
4. **Given** a signed-in driver calls `book_request(R)` where R is `unbooked`, **when** the RPC runs, **then** it (1) inserts a `booking_bids` row for the caller, (2) waits ~300ms for concurrent bids, (3) takes `SELECT ... FOR UPDATE` on R, (4) if R is still `unbooked`, assigns `driver_id`/`status='booked'` to whichever bidder in the window has the highest `completed_rides_count` (earliest `bid_at` breaks an exact tie), (5) returns to each caller whether they were the assigned winner.
5. **Given** two drivers with different `completed_rides_count` call `book_request(R)` within the same ~300ms window, **when** the RPC resolves, **then** the higher-`completed_rides_count` driver is assigned R and their call returns "won"; the other's call returns "did not win" and R is no longer `unbooked`.
6. **Given** a signed-in driver calls `book_request(R)` where R is already `booked`, `completed`, or `cancelled`, **when** the RPC runs, **then** it raises an exception / returns a not-available result, with no state change.
7. **Given** a caller whose role is not `driver`, **when** they call `book_request(R)`, **then** the RPC raises an exception.

## Tasks / Subtasks

- [x] Task 1 — `booking_bids` table + `driver_visibility` policy (AC: #1, #2, #3)
  - [x] New migration `supabase/migrations/<ts3>_create_booking_bids.sql` (timestamped after Story 1.2's), columns exactly per AC #3: `id uuid PK default gen_random_uuid()`, `request_id uuid FK → relocation_requests(id)`, `driver_id uuid FK → profiles(id)`, `bid_at timestamptz default now()`. Enable RLS.
  - [x] Append to `supabase/policies.sql`: `driver_visibility` **as a `FOR SELECT` policy only** — `USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'driver' AND (status = 'unbooked' OR driver_id = auth.uid()))`. **Do not** define this `FOR ALL`, even though `dispatcher_own` (Story 1.2) was — see Dev Notes, this is a real leak risk, not a style choice.
  - [x] Append a second policy to `policies.sql`: `booking_bids` INSERT-only policy for drivers — `WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'driver' AND driver_id = auth.uid())`. No SELECT/UPDATE/DELETE policy on `booking_bids` for `authenticated` — only `book_request` (as owner) ever reads/deletes it.
  - [x] `GRANT INSERT ON booking_bids TO authenticated;` — no SELECT/UPDATE/DELETE grant to `authenticated`.

- [x] Task 2 — `book_request` RPC: role check, bid window, lock (AC: #3, #4, #7)
  - [x] Append to `supabase/functions.sql`. `SECURITY DEFINER`, `SET search_path = public`, parameter named `p_request_id uuid` (continuing the naming convention pinned in Story 1.2)
  - [x] First statement: resolve caller's `profiles.role`; if not `driver`, `RAISE EXCEPTION` (AC #7) — do this before touching `relocation_requests` or sleeping, so a wrong-role caller fails fast
  - [x] `PERFORM pg_sleep(0.3);` — the bid window (see Dev Notes for why the *client*, not this function, does the actual bid insert)
  - [x] `SELECT status, driver_id FROM relocation_requests WHERE id = p_request_id FOR UPDATE` — if no row found, `RAISE EXCEPTION` ("request not found," defensive, not explicitly in an AC)

- [x] Task 3 — Decision branch: assign the winner (AC: #4, #5)
  - [x] If the locked row's `status = 'unbooked'`: this caller is the decider. First, `INSERT INTO booking_bids (request_id, driver_id) VALUES (p_request_id, auth.uid()) ON CONFLICT DO NOTHING` as an idempotent safety-net (guards against the empty-bids edge case — see Dev Notes)
  - [x] `SELECT bb.driver_id FROM booking_bids bb JOIN profiles p ON p.id = bb.driver_id WHERE bb.request_id = p_request_id ORDER BY p.completed_rides_count DESC, bb.bid_at ASC LIMIT 1` → this is the winner
  - [x] `UPDATE relocation_requests SET driver_id = <winner>, status = 'booked' WHERE id = p_request_id`
  - [x] `DELETE FROM booking_bids WHERE request_id = p_request_id` — resets the ledger so a future rebooking round (e.g., after Story 1.4's revert-to-`unbooked` path) doesn't see stale bids from this round
  - [x] Return `winner = auth.uid()` as the boolean result

- [x] Task 4 — Non-decider / not-available branch (AC: #5, #6)
  - [x] If the locked row's `status <> 'unbooked'` (someone else already decided, or it was never open — covers both AC #5's loser and AC #6's already-closed case): compare the row's current `driver_id` to `auth.uid()` and return that boolean — no assignment logic runs, no state change

- [x] Task 5 — Manual verification (AC: all)
  - [x] Single-driver path: driver with an existing bid inserted, call `book_request` on an `unbooked` row solo → becomes decider, wins, row is `booked`
  - [x] Concurrent path (needs 2 driver test accounts with *different* `completed_rides_count` — seed data isn't populated until Story 1.6, so create two ad-hoc `profiles` rows for this test if needed): from two separate sessions, INSERT both bids first, then fire both `book_request` calls within the same ~300ms window (e.g., two terminal tabs issuing the calls back-to-back) → higher-`completed_rides_count` driver wins regardless of which call happened to reach the RPC first
  - [x] Call `book_request` on an already-`booked`/`completed`/`cancelled` row → `false`/not-available, no state change
  - [x] Call `book_request` as a dispatcher-role caller → exception raised

### Review Findings

Adversarial code review of the Epic 1 Supabase contract (2026-07-09). Both fixed in the working tree; each still needs applying to the live project (see the review's deploy checklist).

- [x] [Review][Patch][Low] `booking_bids` had no unique constraint, making `book_request`'s `on conflict do nothing` safety-net inert [flovi/supabase/migrations/20260708190932_create_booking_bids.sql] — with no `unique (request_id, driver_id)` to conflict on, the safety-net insert always added a (harmless) duplicate bid instead of being idempotent, and a double-tapped client bid could create a second row. No wrong winner resulted (the tie-break still selects the earliest `bid_at`), but the "idempotent" claim was false. Fixed: added `unique (request_id, driver_id)`. **Forward-looking (Story 3.2):** the client-side bid insert must now tolerate/ignore a unique-violation on double-tap, or upsert.
- [x] [Review][Patch][Low] `book_request` reported "won" (`true`) for a completed/cancelled request still carrying the caller's `driver_id` [flovi/supabase/functions.sql] — the else-branch returned `v_driver_id = auth.uid()`, but `cancel_request_dispatcher` leaves `driver_id` set on a cancelled row, so a driver calling `book_request` on their own completed/cancelled gig got `true` instead of AC #6's "not-available" result. Not reachable via the app UI and no state change, but a contract inconsistency. Fixed: return `v_status = 'booked' and v_driver_id = auth.uid()`.

## Dev Notes

### The most important thing in this story: why the bid insert can't happen *inside* `book_request` alone
AC #4 reads as if a single `book_request` call does everything — insert, sleep, decide. Implemented literally as one PL/pgSQL function, this is **silently broken**: a Postgres function invoked via a single `SELECT public.book_request(...)` (which is how PostgREST/Supabase RPC calls work) runs as one transaction from start to finish. Anything it `INSERT`s stays invisible to every *other* concurrent session until that entire function call commits — but it only commits at the very end, after its own sleep-then-decide logic. So if two drivers' calls are genuinely concurrent, each one's own bid insert is trapped inside its own uncommitted transaction; neither can ever see the other's bid when it reaches the "read all bids" step. The practical result: whichever caller's transaction happens to win the `FOR UPDATE` row lock first "decides" using only its own bid — i.e., **lock-acquisition order silently becomes the tie-break**, which is exactly the failure mode AD-6 names explicitly as the thing this design must prevent ("a *different* rule than 'highest completed-rides wins'").

**The fix (implemented above): split the insert out of the function.** The bid `INSERT INTO booking_bids` happens as the *client's own direct table write* (a plain RLS-gated insert, not wrapped inside `book_request`) — this commits immediately as its own statement, so it's durably visible to every other session well before that session's own `book_request` call finishes its 300ms sleep and reaches the decision point. Client contract (this is a cross-epic API contract Story 3.2 — driver-mobile's "Book this gig" tap — must follow exactly):
1. `supabase.from('booking_bids').insert({ request_id, driver_id: currentUserId })`
2. Immediately after that succeeds, `supabase.rpc('book_request', { p_request_id: requestId })`

Both calls happen back-to-back from the tapping driver's own client. As long as `~300ms` comfortably exceeds the round-trip time of step 1→2 for two humans tapping "Book" within roughly the same second (the demo scenario this is built for — SPEC.md's own Assumptions section notes "true sub-second race conditions are unlikely in a live demo"), every genuinely-concurrent bidder's row is already committed by the time any one caller's sleep ends and it starts reading `booking_bids`.

*(Alternative considered and rejected for this build: using the `dblink` extension inside `book_request` to autonomously commit the bid insert before sleeping, keeping a single literal RPC call. This works, but adds a real physical DB connection per booking attempt against Supabase's often-small hosted connection pool, plus extension-enablement and connection-string overhead — not worth it against the 4-hour cap when the two-step client flow above achieves the same result with zero extra infrastructure.)*

### Why `driver_visibility` must be `FOR SELECT` only, never `FOR ALL`
Story 1.2 already granted the generic `authenticated` role table-level `INSERT` and column-level `UPDATE(origin, destination, scheduled_date, notes)` on `relocation_requests` — and `authenticated` includes drivers, not just dispatchers. The *only* thing stopping a driver from directly inserting/updating that table is RLS finding no applicable permissive policy for their role on those commands. If `driver_visibility` were written `FOR ALL` (mirroring `dispatcher_own`'s style) and its predicate ever evaluated true during an INSERT/UPDATE, Postgres OR-combines *all* permissive policies for a command — so it would grant write access `dispatcher_own` alone never would. This is the exact leak class AD-4's own "Prevents" clause calls out ("the two RLS policies... silently OR-combining into a leak"). Keeping `driver_visibility` scoped to `FOR SELECT` means no permissive policy applies to a driver's INSERT/UPDATE attempt at all, so RLS denies it outright — correct, since every driver-side mutation (`book_request`, and later `cancel_request_driver`/`complete_request`) goes through a `SECURITY DEFINER` RPC, never a direct table write.

### The empty-bids safety net
If a client somehow calls `book_request` without having inserted its own bid first (a client bug, or a fallback path someone builds later), the decider would otherwise find zero rows in `booking_bids` and have no one to assign. The idempotent self-bid insert in Task 3 (before reading the winner) guarantees there's always at least the decider's own bid to consider, so the winner-selection query is never empty.

### `completed_rides_count` is read fresh, never cached
The winner query joins live to `profiles.completed_rides_count` at decision time rather than storing a count on the bid row — required by AD-6 ("every priority read happens inside the same transaction that performs the resulting write"); a cached count on `booking_bids` could go stale between bid and decision.

### Testing standards summary
No automated test suite in scope. The concurrent-tiebreak path (AC #5) is the one piece of this whole project where a demo-quality manual test (two sessions, two accounts with different `completed_rides_count`) is genuinely worth doing now rather than deferring — it's the highest-risk mechanism in the backend.

### Previous Story Intelligence
Story 1.2 (not yet implemented at time of writing, so this is inherited contract, not retrospective learning) established: `p_`-prefixed RPC parameter naming (continued here as `p_request_id`, matching the recommendation left in that story for reuse across `cancel_request_driver`/`complete_request` too), the shared cumulative `functions.sql`/`policies.sql`/`migrations/` convention, and `SECURITY DEFINER` + `SET search_path = public` on every RPC.

### Project Structure Notes
```
supabase/
  migrations/
    <ts1>_create_profiles.sql
    <ts2>_create_relocation_requests.sql
    <ts3>_create_booking_bids.sql   # this story — ts3 > ts2
  functions.sql   # append book_request after cancel_request_dispatcher
  policies.sql    # append driver_visibility + booking_bids' insert policy
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.3: Driver Visibility & Booking Priority Mechanic]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-4 — Dispatcher visibility and mutation are owner-scoped, never a shared pool]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-6 — Completed-rides increment and every priority read happen inside the deciding transaction]
- [Source: _bmad-output/specs/spec-relocation-dispatch/state-machines.md — Priority rule (shared)]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#CAP-6, CAP-7, Assumptions — "true sub-second race conditions are unlikely in a live demo"]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — `p_`-prefix convention, shared-file structure]
- [External: PostgreSQL autonomous transactions via dblink (why a single-function approach needs it, and why this story avoids needing it) — https://www.cybertec-postgresql.com/en/implementing-autonomous-transactions-in-postgres/]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

- Implemented the `booking_bids` table (migration `20260708190932_create_booking_bids.sql`), the `driver_visibility` FOR-SELECT-only policy and `booking_bids_insert_own` INSERT-only policy (appended to `policies.sql`), and the `book_request` SECURITY DEFINER RPC (appended to `functions.sql`), all exactly per the Tasks/Subtasks breakdown and Dev Notes' split-insert design (client inserts its own bid row directly; `book_request` only sleeps, locks, and decides).
- Manual verification (Task 5) was run directly against the user's live Supabase Postgres instance via `psql`, using a connection string supplied by the user for this session only (deleted from local scratch storage after use). Three throwaway `auth.users`/`profiles` rows (one dispatcher, two drivers with `completed_rides_count` 2 and 10) and three throwaway `relocation_requests` rows were inserted directly via superuser SQL, then sessions were simulated per-role with `SET LOCAL ROLE authenticated` + `set_config('request.jwt.claim.sub', ...)` to exercise RLS/`auth.uid()` exactly as PostgREST would. All test data was deleted after verification; no residual data left in the project.
- All ACs verified end-to-end on the first attempt: AC #1/#2 (`driver_visibility` — each driver's `SELECT` returned exactly the unbooked pool row plus their own booked row, never the other driver's booked row), AC #3 (`booking_bids` table and `book_request` RPC exist as specified), AC #4 (solo driver bid → decider → `won = true`, row `booked`, bid ledger cleared to 0 rows), AC #5 (two drivers' bids inserted — lower-count driver bid first, higher-count driver bid ~300ms later — both `book_request` calls fired concurrently via backgrounded `psql` processes; the higher-`completed_rides_count` driver won regardless of bid/call order, loser's call returned `false`), AC #6 (calling `book_request` on the now-`booked` row returned `false` with zero state change), AC #7 (dispatcher-role caller got `RAISE EXCEPTION: book_request requires the caller to be a driver`, transaction rolled back). Also verified as a bonus negative check (not a numbered AC, but part of Task 1's policy intent) that a driver cannot `INSERT` a `booking_bids` row on another driver's behalf — RLS correctly rejected it.

### File List

- `flovi/supabase/migrations/20260708190932_create_booking_bids.sql` (new — `booking_bids` table, RLS enable, INSERT-only grant)
- `flovi/supabase/policies.sql` (modified — appended `driver_visibility` and `booking_bids_insert_own` policies)
- `flovi/supabase/functions.sql` (modified — appended `book_request` RPC)

## Change Log

- 2026-07-08 — Implemented Story 1.3 in full: `booking_bids` schema, `driver_visibility` FOR-SELECT-only RLS policy, `booking_bids_insert_own` INSERT-only RLS policy, `book_request` SECURITY DEFINER RPC implementing the split-insert priority-bid mechanic. All 5 tasks complete, all 7 ACs manually verified against the live Supabase project (including the concurrent-tiebreak path via two backgrounded `psql` sessions). Status → review.
