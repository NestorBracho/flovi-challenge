# Story 1.5: Ride Completion & Priority Count Increment

Status: ready-for-dev

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

- [ ] Task 1 — `complete_request` RPC: checks and locking (AC: #1, #2)
  - [ ] Append to `supabase/functions.sql`. `SECURITY DEFINER`, `SET search_path = public`, parameter `p_request_id uuid` (continuing the established convention — fourth RPC to use it)
  - [ ] Verify caller's `profiles.role = 'driver'`, else `RAISE EXCEPTION`
  - [ ] `SELECT status, driver_id FROM relocation_requests WHERE id = p_request_id FOR UPDATE` — if no row, `RAISE EXCEPTION` (defensive, not in an AC)
  - [ ] Verify `driver_id = auth.uid()` AND `status = 'booked'` on the locked row, else `RAISE EXCEPTION` — AC #2's "R is not currently booked" covers a request that's already `completed`/`cancelled`/reassigned away from this caller, not just a wrong-driver caller

- [ ] Task 2 — Completion + increment, same transaction (AC: #1)
  - [ ] `UPDATE relocation_requests SET status = 'completed' WHERE id = p_request_id`
  - [ ] `UPDATE profiles SET completed_rides_count = completed_rides_count + 1 WHERE id = auth.uid()` — no new grant/policy work needed here: Story 1.1 already left `profiles` with zero client-facing UPDATE policy at all, and this RPC's `SECURITY DEFINER` privileges bypass that entirely (same bypass mechanism as every other RPC in this project)
  - [ ] Both statements run inside this one function call's single transaction — no cross-transaction visibility concern here (unlike Story 1.3's `book_request`), since nothing else needs to observe an intermediate state mid-function; only the two writes' combined atomicity matters, which one transaction already guarantees

- [ ] Task 3 — Prove the count actually feeds back (AC: #3)
  - [ ] This AC isn't new code — it's a regression check tying together Stories 1.3 and 1.4, which were both written to read `profiles.completed_rides_count` fresh (via `JOIN`) at decision time rather than from any cached value. Complete a few rides for a test driver via this RPC, then re-run the Story 1.3 concurrent-bid test and/or the Story 1.4 reassignment test and confirm the now-higher count changes who wins/gets reassigned. If it doesn't, the bug is in 1.3/1.4's query, not here.

- [ ] Task 4 — Manual verification (AC: #1, #2)
  - [ ] As the assigned driver on a `booked` request, call `complete_request` → status becomes `completed`, caller's `completed_rides_count` increments by exactly 1
  - [ ] As a non-assigned driver, or as the assigned driver on a request that's `unbooked`/`completed`/`cancelled`, call `complete_request` → exception, no state change, no increment
  - [ ] Call twice in a row on the same request → second call fails (status is no longer `booked` after the first call succeeds), count does not double-increment

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

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
