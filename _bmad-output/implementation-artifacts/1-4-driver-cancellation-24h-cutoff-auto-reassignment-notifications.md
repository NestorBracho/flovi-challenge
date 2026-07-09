---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 1.4: Driver Cancellation, 24h Cutoff, Auto-Reassignment & Notifications

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want to cancel a gig I've booked only with enough notice, and have it automatically reassigned so the dispatcher isn't left stuck,
so that late cancellations don't strand a scheduled ride and dispatchers learn about the change without doing anything.

## Acceptance Criteria

1. **Given** a signed-in driver owns booked request R with `now() < cutoff`, where `cutoff := (scheduled_date::timestamptz AT TIME ZONE 'UTC') - interval '24 hours'` (AD-7), **when** they call `cancel_request_driver(R)`, **then** the RPC verifies caller role `driver` and `driver_id = auth.uid()`, confirms `now() < cutoff`, ranks active drivers (`is_active = true`) by `completed_rides_count DESC` excluding the caller, and assigns R to the top-ranked driver if one exists (status stays `booked`, `driver_id` updated) — else sets `status = 'unbooked'`, `driver_id = NULL`.
2. **Given** a signed-in driver owns booked request R with `now() >= cutoff`, **when** they call `cancel_request_driver(R)`, **then** the RPC raises an exception / returns a blocked result, and R's status/driver_id are unchanged.
3. **Given** a valid cancellation reassigns R to a new driver, or reverts it to `unbooked`, **when** the reassignment/revert completes, **then** a `notifications` row is inserted with `request_id = R`, `dispatcher_id` = R's `created_by`, and a message identifying the request, that the original driver cancelled, and who was reassigned (or that it returned to the available pool if no eligible driver existed).
4. **Given** no `notifications` table exists yet, **when** this story is complete, **then** a `notifications` table exists (`id`, `request_id FK`, `dispatcher_id FK`, `message text`, `created_at timestamptz`, `read_at timestamptz nullable`) with RLS scoping visibility to `dispatcher_id = auth.uid()`.
5. **Given** a caller who is not R's assigned driver, or whose role is not `driver`, **when** they call `cancel_request_driver(R)`, **then** the RPC raises an exception, with no state change.

## Tasks / Subtasks

- [x] Task 1 — `notifications` table migration + full RLS/grant surface (AC: #4)
  - [x] New migration `supabase/migrations/<ts4>_create_notifications.sql`, columns exactly per AC #4; `created_at default now()`, `read_at` nullable no default
  - [x] Enable RLS. Append to `policies.sql`: one `FOR ALL` policy (name it `dispatcher_own_notifications`) — `USING (dispatcher_id = auth.uid()) WITH CHECK (dispatcher_id = auth.uid())`
  - [x] `GRANT SELECT ON notifications TO authenticated;`
  - [x] `REVOKE UPDATE ON notifications FROM authenticated;` then `GRANT UPDATE (read_at) ON notifications TO authenticated;` — **build this now even though no AC in this story exercises it.** Story 2.4 (Epic 2) needs to mark visible unread notifications read via a direct client-side `UPDATE notifications SET read_at = now() WHERE ...`, and per AD-1/the architecture's design paradigm, Epic 2 has zero domain logic of its own — it can only call what Epic 1 already exposed. If this grant/policy isn't in place now, Story 2.4 hits a dead end it has no authority to fix itself.
  - [x] No INSERT/DELETE grant to `authenticated` at all — only `cancel_request_driver` (as owner) ever inserts a notification

- [x] Task 2 — `cancel_request_driver` RPC: checks and locking (AC: #1, #2, #5)
  - [x] Append to `supabase/functions.sql`. `SECURITY DEFINER`, `SET search_path = public`, parameter `p_request_id uuid` (continuing the established convention)
  - [x] Verify caller's `profiles.role = 'driver'`, else `RAISE EXCEPTION` (AC #5)
  - [x] `SELECT status, driver_id, scheduled_date, created_by FROM relocation_requests WHERE id = p_request_id FOR UPDATE` — lock the row before any decision (defends against a concurrent `cancel_request_dispatcher`/`complete_request` call racing this one)
  - [x] Verify `driver_id = auth.uid()` on the locked row, else `RAISE EXCEPTION` (AC #5). Also verify `status = 'booked'` — defensive, not explicitly in an AC, but needed if the dispatcher cancelled R a moment earlier and the driver's client still shows it as their booked gig (stale realtime lag)
  - [x] Compute the cutoff (see Dev Notes for the exact, timezone-safe form) and compare to `now()`; if `now() >= cutoff`, `RAISE EXCEPTION` with message text **exactly** `'Too close to the ride to cancel (within 24h).'` — no further statements execute (AC #2 — status/driver_id must stay untouched). The exact wording matters here, not just the fact of raising: per AD-3, an RPC failure's exception message is meant to map 1:1 to the client's displayed copy — Story 3.4 (driver-mobile) will catch this exception and display its message directly rather than maintaining a separate hardcoded copy of its own, so a mismatched or paraphrased message here would surface as wrong-looking UI text three stories later with no error to flag it

- [x] Task 3 — Reassignment/revert decision (AC: #1)
  - [x] `SELECT id FROM profiles WHERE role = 'driver' AND is_active = true AND id <> auth.uid() ORDER BY completed_rides_count DESC, id ASC LIMIT 1` — `id ASC` is an arbitrary-but-deterministic tiebreak (no `bid_at`-equivalent exists for reassignment, and `profiles` has no `created_at` column to break ties on instead — see Dev Notes)
  - [x] If a row is found: `UPDATE relocation_requests SET driver_id = <found id> WHERE id = p_request_id` — `status` stays `'booked'`, only `driver_id` changes
  - [x] If no row is found: `UPDATE relocation_requests SET status = 'unbooked', driver_id = NULL WHERE id = p_request_id`

- [x] Task 4 — Notification message (AC: #3)
  - [x] Use the **exact fixed microcopy template from EXPERIENCE.md** (not a paraphrase — see Dev Notes for the verbatim source): reassigned → `'{cancelling_driver_full_name} cancelled a gig — automatically reassigned to {new_driver_full_name}.'`; reverted → `'{cancelling_driver_full_name} cancelled a gig — returned to the available pool.'`
  - [x] Look up both full names from `profiles` (cancelling driver = `auth.uid()`'s own row; new driver = the row found in Task 3, if any)
  - [x] `INSERT INTO notifications (request_id, dispatcher_id, message) VALUES (p_request_id, <R's created_by, captured in Task 2's locked SELECT>, <message>)`

- [x] Task 5 — Manual verification (AC: all)
  - [x] As the assigned driver, cancel a booked request with `scheduled_date` ≥25h out → succeeds; if another active driver with higher `completed_rides_count` exists, they're assigned and a notification with the "automatically reassigned to X" wording appears for the dispatcher; if no other active driver exists, R reverts to `unbooked` and the notification reads "returned to the available pool"
  - [x] Same request but `scheduled_date` within 24h → blocked, no state change, no notification created
  - [x] As a non-assigned driver, or as a dispatcher, call `cancel_request_driver` on someone else's booked request → exception, no state change
  - [x] As the dispatcher who owns R, confirm the new `notifications` row is visible via SELECT (RLS), and confirm a direct `UPDATE notifications SET read_at = now() WHERE id = ...` succeeds (proving Task 1's forward-looking grant actually works, even though no story yet calls it from a UI)

### Review Findings

Adversarial code review of the Epic 1 Supabase contract (2026-07-09). Both fixed in the working tree; each still needs applying to the live project (re-deploy `functions.sql` + the `ALTER POLICY` in the review's deploy checklist).

- [x] [Review][Patch][HIGH] `cancel_request_driver` hard-failed when a driver's `full_name` was NULL [flovi/supabase/functions.sql] — `profiles.full_name` is nullable (claim_role populates it from the OAuth full_name/name claim, which can be absent), but `notifications.message` is `NOT NULL` and `NULL || text` evaluates to NULL in Postgres. A nameless canceller — or a nameless auto-reassignment target, which breaks it even for a *named* canceller — made the message NULL, aborting the whole cancellation with a not-null violation (opaque error, no cancellation, CAP-11/CAP-12 broken) instead of it succeeding. Fixed: `coalesce(full_name, 'A driver')` / `coalesce(full_name, 'another driver')` at the message build. Named drivers see byte-identical microcopy (COALESCE only changes output when full_name is actually NULL). *Likelihood note:* real Google accounts almost always supply a name, so it won't fire in the seeded demo — but the path was fully unguarded.
- [x] [Review][Patch][Low] `dispatcher_own_notifications` was predicate-gated, not role-gated [flovi/supabase/policies.sql] — `using (dispatcher_id = auth.uid())` deviates from AD-4's "role-gated, not just predicate-gated" rule for notifications. Functionally safe today (single policy → no OR-combine; `dispatcher_id` only ever holds a dispatcher's id), but wouldn't defend a future second permissive policy on the table. Fixed: added the `(select role from profiles where id = auth.uid()) = 'dispatcher'` gate to both USING and WITH CHECK.

## Dev Notes

### The 24h cutoff formula — a real timezone subtlety, resolved by Supabase's default
AD-7 writes the formula as `(scheduled_date::timestamptz AT TIME ZONE 'UTC') - interval '24 hours'`. Read literally, this has a subtle bug: casting a `date` directly to `timestamptz` anchors "midnight" to the **session's** timezone first, and only *then* does `AT TIME ZONE 'UTC'` reformat that already-anchored instant — it does not retroactively fix the anchor. This formula only produces true UTC midnight if the database session's timezone is already UTC. Confirmed: **hosted Supabase projects default to UTC** for exactly this kind of reason, so AD-7's formula as literally written is correct in this project's actual environment — but it's fragile, not portable, and would silently break if the project's timezone setting were ever changed. Use the more defensively-correct equivalent instead, which is correct regardless of session timezone: cast to a plain `timestamp` first (no zone attached), then anchor that wall-clock reading to UTC:
```sql
v_cutoff := (v_scheduled_date::timestamp AT TIME ZONE 'UTC') - interval '24 hours';
```
This computes the identical instant to AD-7's formula under Supabase's UTC default, and stays correct if that default is ever changed. Story 3.4 (driver-mobile) computes this same cutoff client-side in Dart for instant UI feedback (AD-7) — that side doesn't share this Postgres-cast subtlety, but should be checked against the same UTC-midnight-minus-24h definition when built.

### Notification message — verbatim microcopy, not a paraphrase
EXPERIENCE.md's Flow 3 gives the literal example: *"Marcus cancelled a gig — automatically reassigned to Priya Nair."* and its edge case: *"...Elena's notification reads 'returned to the available pool' instead of naming a new driver."* UX-DR27 requires this fixed microcopy be reproduced verbatim, not approximated — Task 4's templates above are lifted directly from these lines with names substituted.
**Split of responsibility with Story 2.4**: UX-DR11 describes the rendered Notification item as "**bold** request route + **plain-weight** description of what happened." The route (origin → destination) is *not* part of the message template above — it comes from Story 2.4 joining the notification's `request_id` back to `relocation_requests` and bolding that separately. This story's `message` column holds only the plain-weight "what happened" sentence.

### Row locking, not a bid-window
Unlike Story 1.3's `book_request` (which needed the whole multi-caller bid-window redesign because *multiple drivers* compete for one row), `cancel_request_driver` only ever has **one** legitimate caller for a given request at a time — the driver who owns it. A single `SELECT ... FOR UPDATE` at the top of the function is sufficient here; there's no cross-transaction-visibility problem to solve because there's no second bidder to wait for.

### Reassignment tiebreak has no specified rule (unlike CAP-7's `bid_at`)
The architecture only defines a tiebreak for the concurrent-booking race (`bid_at ASC`, since that's a genuine race with a natural "who bid first" signal). Reassignment isn't a race — it's a single deterministic ranking query — but ties on `completed_rides_count` are still possible among multiple equally-ranked active drivers. `profiles` has no `created_at` column (see the ER diagram — only `id`, `role`, `full_name`, `completed_rides_count`, `is_active`) to break ties on chronologically, so `id ASC` is used as an arbitrary-but-stable tiebreak, purely so results are reproducible across runs rather than dependent on physical row order.

### Previous Story Intelligence
Continues the `p_request_id` parameter convention (Stories 1.2/1.3) and the `SECURITY DEFINER` + `SET search_path = public` pattern on every RPC. Reuses the column-level `REVOKE`/`GRANT` technique introduced in Story 1.2 (there for `relocation_requests`, here for `notifications.read_at`).

### Testing standards summary
No automated test suite in scope. Verify manually per Task 5, including the forward-looking `read_at` UPDATE grant even though no story yet exercises it from a UI — that's the only way to confirm Story 2.4 won't hit a dead end later.

### Project Structure Notes
```
supabase/
  migrations/
    <ts1>_create_profiles.sql
    <ts2>_create_relocation_requests.sql
    <ts3>_create_booking_bids.sql
    <ts4>_create_notifications.sql   # this story — ts4 > ts3
  functions.sql   # append cancel_request_driver after book_request
  policies.sql    # append dispatcher_own_notifications
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.4: Driver Cancellation, 24h Cutoff, Auto-Reassignment & Notifications]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-7 — One canonical 24-hour-cutoff formula, computed identically on both sides]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-6 — reassignment ranking, active driver pool]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — Component Patterns (Notification item, UX-DR11), Flow 3 and its edge case (verbatim message text)]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#CAP-11, CAP-12, CAP-13]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — column-level GRANT/REVOKE technique]
- [External: Supabase databases default to UTC timezone — https://supabase.com/docs/guides/database/managing-timezones]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

- Implemented the `notifications` table (migration `20260708192145_create_notifications.sql`, columns exactly per AC #4), the `dispatcher_own_notifications` FOR ALL policy (appended to `policies.sql`), and the `cancel_request_driver` SECURITY DEFINER RPC (appended to `functions.sql`), all exactly per the Tasks/Subtasks breakdown and Dev Notes' timezone-safe cutoff formula and verbatim microcopy templates.
- `notifications` grants: `SELECT` open to `authenticated` (RLS-scoped), column-level `UPDATE (read_at)` only (forward-looking grant for Story 2.4, per Task 1), and `INSERT`/`DELETE` both explicitly revoked since Supabase's platform-level default privileges otherwise grant them — only `cancel_request_driver` (as owner) ever inserts a row.
- Manual verification (Task 5) was run directly against the user's live Supabase Postgres instance via `psql`, using a connection string supplied by the user for this session only (not written to any file, not retained after use). Six throwaway `auth.users`/`profiles` rows (one dispatcher, four drivers with varying `completed_rides_count`/`is_active` combinations, one solo canceller) and three throwaway `relocation_requests` rows (pre-set to `booked` by temporarily disabling the `relocation_requests_before_insert` trigger, since it forces `unbooked`/`null driver_id` on every INSERT) were used; RLS-scoped sessions were simulated per-role with `SET LOCAL ROLE authenticated` + `set_config('request.jwt.claim.sub', ...)` to exercise `auth.uid()` exactly as PostgREST would. All test data was deleted after verification (confirmed zero residue); no changes were left in the project's live schema beyond this story's migration/RPC/policy.
- All ACs verified end-to-end: AC #1 reassignment path (driver cancelled a request ≥25h out; highest-`completed_rides_count` **active** driver was assigned, correctly excluding a higher-count but `is_active = false` driver — status stayed `booked`) and revert path (no other active driver eligible → `status = 'unbooked'`, `driver_id = NULL`); AC #2 (cancellation attempt on a request scheduled for "today" raised exactly `'Too close to the ride to cancel (within 24h).'` with zero state change and zero notification); AC #3 (notification message text matched the EXPERIENCE.md microcopy verbatim, byte-for-byte diffed against the story's template — including the em dash — for both the reassigned and reverted cases); AC #4 (`notifications` table exists with the RLS policy scoping `SELECT` to `dispatcher_id = auth.uid()` — confirmed a driver role saw zero rows — and the `read_at` `UPDATE` grant succeeded for the owning dispatcher); AC #5 (a non-owning driver got `'caller does not own relocation request %'`, and a dispatcher-role caller got `'cancel_request_driver requires the caller to be a driver'`, both with zero state change).

### File List

- `flovi/supabase/migrations/20260708192145_create_notifications.sql` (new — `notifications` table, RLS enable, SELECT/column-scoped UPDATE grants, explicit INSERT/DELETE revokes)
- `flovi/supabase/policies.sql` (modified — appended `dispatcher_own_notifications` policy)
- `flovi/supabase/functions.sql` (modified — appended `cancel_request_driver` RPC)

## Change Log

- 2026-07-08 — Implemented Story 1.4 in full: `notifications` schema, `dispatcher_own_notifications` RLS policy (including the forward-looking `read_at` update grant for Story 2.4), and the `cancel_request_driver` SECURITY DEFINER RPC implementing the 24h cutoff check, auto-reassignment/revert-to-pool decision, and verbatim notification microcopy. All 5 tasks complete, all 5 ACs manually verified against the live Supabase project. Status → review.
