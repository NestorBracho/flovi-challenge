---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 1.5: Ride Completion & Priority Count Increment

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want to mark a booked gig as completed,
so that the ride is closed out and my completed-rides count goes up for future priority ranking.

## Acceptance Criteria

1. **Given** a signed-in driver owns booked request R, **when** they call `complete_request(R)`, **then** the RPC verifies caller role `driver` and `driver_id = auth.uid()`, sets `status = 'completed'`, and increments that driver's `profiles.completed_rides_count` by 1 inside the same transaction.
2. **Given** a caller who is not R's assigned driver, or R is not currently `booked`, **when** they call `complete_request(R)`, **then** the RPC raises an exception, with no state change and no increment.
3. **Given** a driver has completed N rides via this RPC, **when** they are later evaluated in a `book_request` bid window (Story 1.3) or a `cancel_request_driver` reassignment (Story 1.4), **then** their updated `completed_rides_count` is what gets read — proving the count actually feeds the priority mechanic end-to-end.

## Tasks / Subtasks

- [x] Task 1 — `complete_request` RPC: checks and locking (AC: #1, #2)
  - [x] Append to `supabase/functions.sql`. `SECURITY DEFINER`, `SET search_path = public`, parameter `p_request_id uuid` (continuing the established convention — fourth RPC to use it)
  - [x] Verify caller's `profiles.role = 'driver'`, else `RAISE EXCEPTION`
  - [x] `SELECT status, driver_id FROM relocation_requests WHERE id = p_request_id FOR UPDATE` — if no row, `RAISE EXCEPTION` (defensive, not in an AC)
  - [x] Verify `driver_id = auth.uid()` AND `status = 'booked'` on the locked row, else `RAISE EXCEPTION` — AC #2's "R is not currently booked" covers a request that's already `completed`/`cancelled`/reassigned away from this caller, not just a wrong-driver caller

- [x] Task 2 — Completion + increment, same transaction (AC: #1)
  - [x] `UPDATE relocation_requests SET status = 'completed' WHERE id = p_request_id`
  - [x] `UPDATE profiles SET completed_rides_count = completed_rides_count + 1 WHERE id = auth.uid()` — no new grant/policy work needed here: Story 1.1 already left `profiles` with zero client-facing UPDATE policy at all, and this RPC's `SECURITY DEFINER` privileges bypass that entirely (same bypass mechanism as every other RPC in this project)
  - [x] Both statements run inside this one function call's single transaction — no cross-transaction visibility concern here (unlike Story 1.3's `book_request`), since nothing else needs to observe an intermediate state mid-function; only the two writes' combined atomicity matters, which one transaction already guarantees

- [x] Task 3 — Prove the count actually feeds back (AC: #3)
  - [x] This AC isn't new code — it's a regression check tying together Stories 1.3 and 1.4, which were both written to read `profiles.completed_rides_count` fresh (via `JOIN`) at decision time rather than from any cached value. Complete a few rides for a test driver via this RPC, then re-run the Story 1.3 concurrent-bid test and/or the Story 1.4 reassignment test and confirm the now-higher count changes who wins/gets reassigned. If it doesn't, the bug is in 1.3/1.4's query, not here.

- [x] Task 4 — Manual verification (AC: #1, #2)
  - [x] As the assigned driver on a `booked` request, call `complete_request` → status becomes `completed`, caller's `completed_rides_count` increments by exactly 1
  - [x] As a non-assigned driver, or as the assigned driver on a request that's `unbooked`/`completed`/`cancelled`, call `complete_request` → exception, no state change, no increment
  - [x] Call twice in a row on the same request → second call fails (status is no longer `booked` after the first call succeeds), count does not double-increment

## Dev Notes

This is the simplest RPC in Epic 1 — it reuses every pattern already established in Stories 1.1–1.4 rather than introducing new ones:
- `SECURITY DEFINER` + `SET search_path = public` (Story 1.1)
- `p_request_id uuid` parameter naming (Stories 1.2–1.4)
- Row-lock-then-check pattern, no bid-window needed (same reasoning as `cancel_request_driver` in Story 1.4 — exactly one legitimate caller per request, no concurrent-bidder problem to solve)
- The increment relies entirely on Story 1.1's decision to leave `profiles` with **no** client-facing UPDATE policy at all — that's what makes `SECURITY DEFINER`'s RLS-bypass the only path to incrementing `completed_rides_count`, closing off any direct-client route to inflate it

### Why AC #3 matters even though it adds no new code
It's the payoff check for a design decision made back in Story 1.3's Dev Notes: the winner-selection query joins live to `profiles.completed_rides_count` rather than caching a count on the bid row, specifically so a driver's count *at decision time* — including any increments from rides they've completed since the last booking round — is what gets used. This story is what actually moves that number, so it's the first point where that design decision becomes empirically checkable rather than just reasoned about.

### Testing standards summary
No automated test suite in scope. Task 3's cross-story regression check is worth doing deliberately rather than assuming it works from code review alone — it's the only place in Epic 1 where three separate stories' correctness is jointly observable in one test.

### Project Structure Notes
No new migration in this story — `profiles` and `relocation_requests` already exist (Stories 1.1/1.2). Only `functions.sql` gets a new entry:
```
supabase/
  functions.sql   # append complete_request after cancel_request_driver
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.5: Ride Completion & Priority Count Increment]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-6 — `completed_rides_count` is incremented only inside `complete_request`'s transaction]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#CAP-14]
- [Source: _bmad-output/implementation-artifacts/1-1-profiles-schema-role-claiming-rpc.md — why `profiles` has no client-facing UPDATE policy]
- [Source: _bmad-output/implementation-artifacts/1-3-driver-visibility-booking-priority-mechanic.md — live-read (not cached) `completed_rides_count` design]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

### Completion Notes List

- Implemented the `complete_request` SECURITY DEFINER RPC (appended to `functions.sql`), exactly per the Tasks/Subtasks breakdown: role check → `FOR UPDATE` lock → ownership + `status = 'booked'` check → `status = 'completed'` update → `profiles.completed_rides_count` increment, all in one function-call transaction. No new migration, grant, or policy work needed — reuses Story 1.1's zero-client-UPDATE-policy design on `profiles`.
- Manual verification (Tasks 3 & 4) was run directly against the user's live Supabase Postgres instance via `psql`, using a connection string supplied by the user for this session only (not written to any file, not retained after use). All tables were confirmed empty before starting (no residue from prior stories' verification sessions).
- Deployed the full `functions.sql` (all 5 RPCs, `CREATE OR REPLACE`) to the live instance first, confirming `complete_request` was newly created alongside the four pre-existing RPCs.
- Test fixtures: 1 throwaway dispatcher + 3 throwaway drivers (`auth.users` + `profiles`), 11 throwaway `relocation_requests`, created/mutated directly as the `postgres` superuser (bypasses RLS/column grants) with `set_config('request.jwt.claim.sub', ...)` used to simulate each caller's `auth.uid()` per the pattern established in Story 1.4's verification.
- AC #1 (happy path): assigned driver called `complete_request` on their own `booked` request → `status` became `completed`, caller's `completed_rides_count` incremented from 0 to exactly 1.
- AC #2: a non-assigned driver got `'complete_request: caller does not own relocation request %'` with zero state change and zero increment; the assigned driver calling on an already-`cancelled` request got `'complete_request: relocation request % is not booked'`, also zero state change. A second call on the same (now-`completed`) request from Task 4's double-call check failed with the same not-booked exception, and the count stayed at exactly 1 (no double-increment).
- AC #3 (the cross-story regression, Task 3): ran two before/after "flip" comparisons rather than a single spot-check, to prove the *specific increments made by this RPC* — not just some pre-existing count — are what changes the outcome. Round 1 (`book_request`, Story 1.3): with `driver_c` ahead of `driver_b` (1 vs 0), a concurrent-bid call correctly picked `driver_c`; after bumping `driver_b` to 2 via two `complete_request` calls, an identical bid scenario on a fresh request flipped to `driver_b` winning. Round 2 (`cancel_request_driver`, Story 1.4): with `driver_b` at 2 vs `driver_c` at 1, a cancellation correctly reassigned to `driver_b`; after bumping `driver_c` to 3 via two more `complete_request` calls, an identical cancellation on a fresh request flipped to reassigning to `driver_c`. Both flips confirm Stories 1.3/1.4's live (not cached) read of `completed_rides_count` is fed correctly by this story's increment.
- All test data (4 profiles/auth.users rows, 11 relocation_requests, 2 notifications generated by the `cancel_request_driver` calls, 0 leftover booking_bids since `book_request` deletes its own bid rows on decision) was deleted after verification; post-cleanup counts on all four tables confirmed zero. No changes were left in the project's live schema beyond this story's `functions.sql` addition.

### File List

- `flovi/supabase/functions.sql` (modified — appended `complete_request` RPC)

## Change Log

- 2026-07-08 — Implemented Story 1.5 in full: the `complete_request` SECURITY DEFINER RPC (status → `completed` + `profiles.completed_rides_count` increment, same transaction). All 4 tasks complete; all 3 ACs manually verified against the live Supabase project, including a two-round before/after regression proving the incremented count flips both `book_request`'s (1.3) and `cancel_request_driver`'s (1.4) decisions. Status → review.
