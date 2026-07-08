# Story 3.4: Cancel (24h Rule) & Mark Complete

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want to cancel a booked gig only when I have enough notice, and mark a finished gig complete,
so that I can back out responsibly without stranding a ride, and keep my completed-rides count accurate.

## Acceptance Criteria

1. **Given** a Booked-gig row for a gig with `now() < cutoff` (client-computed via the same `scheduled_date @ 00:00 UTC − 24h` formula as AD-7, for instant feedback), **when** the row renders, **then** it shows an active "Cancel" (ghost) action.
2. **Given** a Booked-gig row for a gig with `now() >= cutoff`, **when** the row renders, **then** the Cancel control is disabled/muted with adjacent text "Too close to the ride to cancel (within 24h)." (CAP-11).
3. **Given** a signed-in driver taps "Cancel" on a gig with ≥24h remaining, **when** the `cancel_request_driver` RPC call succeeds, **then** the row is removed from Booked (the server-side reassignment and dispatcher notification happen per Epic 1 Story 1.4, observable in Epic 2 Story 2.4) (CAP-11, CAP-12 trigger half).
4. **Given** a signed-in driver's cancellation is rejected server-side (e.g. a race where cutoff passed between render and tap), **when** the RPC call returns the blocked result, **then** the row stays in Booked and the same "too close to cancel" messaging is shown, matching the RPC's exception 1:1 (AD-7's authoritative server-side re-check).
5. **Given** a Booked-gig row for a gig currently `booked`, **when** the row renders, **then** it also shows a "Mark complete" (ghost) action, available any time the gig is `booked`.
6. **Given** a signed-in driver taps "Mark complete", **when** the `complete_request` RPC call succeeds, **then** the row is removed from Booked immediately, with no separate confirmation screen (CAP-14).
7. **Given** any transient motion on this screen (row removal after cancel/complete), **when** `prefers-reduced-motion` is set, **then** the removal reduces to instant/opacity-only (UX-DR25).

## Tasks / Subtasks

- [ ] Task 1 — Client-side cutoff computation: a Dart-specific version of the same timezone trap caught in Story 1.4 (AC: #1, #2)
  - [ ] **Do not** compute the cutoff via `DateTime.parse(scheduledDateString)` — verified: Dart's `DateTime.parse()` on a bare date string like `"2026-07-15"` (no timezone suffix) defaults to interpreting it as **local time**, not UTC. Unlike Story 1.4's Postgres-side version of this exact problem (which turned out to be a non-issue because Supabase's hosted database session defaults to UTC), there's no equivalent safety net here — this runs on the driver's own device, which could be in any timezone. Getting this wrong makes the client's proactive Cancel-button state actively disagree with the server's own authoritative check whenever the device isn't set to UTC — not a hypothetical, a near-certainty for most real devices.
  - [ ] Construct the UTC midnight explicitly instead: parse the date's year/month/day components and build `DateTime.utc(year, month, day)`, then `.subtract(Duration(hours: 24))` for the cutoff. Compare against `DateTime.now().toUtc()`.
  - [ ] This is purely for **instant proactive UI feedback** (AD-7) — the authoritative check is still `cancel_request_driver`'s own server-side re-computation; this client copy existing at all is a UX nicety, not the enforcement

- [ ] Task 2 — Cancel action and its two failure/success paths (AC: #1, #2, #3, #4)
  - [ ] Active state (≥24h remaining): ghost-styled "Cancel" button, calls `Supabase.instance.client.rpc('cancel_request_driver', params: {'p_request_id': gigId})` on tap
  - [ ] Disabled state (<24h remaining, computed client-side per Task 1): muted, non-interactive, with adjacent text `"Too close to the ride to cancel (within 24h)."`
  - [ ] Success: remove the row from Booked (optimistic — no need to wait for a realtime echo, consistent with the pattern established across Epic 2's dispatcher-web stories)
  - [ ] **Race case (AC #4)**: if the client's proactive check said ≥24h remaining but the server's authoritative re-check disagrees (cutoff passed in the gap between render and tap), `cancel_request_driver` throws with message text `'Too close to the ride to cancel (within 24h).'` **exactly** — Story 1.4 was specifically updated to pin this literal wording for this reason. Catch the exception and **display its message directly** rather than re-deriving or hardcoding the copy independently client-side; this is what "matching the RPC's exception 1:1" means concretely, and it's also what keeps this client copy from silently drifting out of sync with whatever Story 1.4 actually implements

- [ ] Task 3 — Mark complete (AC: #5, #6)
  - [ ] Ghost-styled "Mark complete" action, visible any time the row is `booked` (both regardless of the 24h state, since finishing a ride is not gated by the cancellation window at all)
  - [ ] `Supabase.instance.client.rpc('complete_request', params: {'p_request_id': gigId})` — on success, remove the row immediately, no confirmation screen or interstitial

- [ ] Task 4 — Reduced motion on row removal (AC: #7)
  - [ ] Both the cancel-success and mark-complete-success row removals are transient motion in EXPERIENCE.md's sense — check Flutter's reduced-motion signal (`MediaQuery.of(context).disableAnimations`) and collapse any removal animation to instant/opacity-only when set, matching the same handling already applied to Story 3.2's interstitial entrance and race-lost card removal

## Dev Notes

### The Dart-side echo of Story 1.4's timezone catch — this one has no safety net
Worth stating plainly: Story 1.4's Postgres formula turned out to be correct as literally written specifically *because* Supabase's hosted default session timezone is UTC — that was a fact about the server environment, verified, not a general guarantee. This story's client-side computation runs on whatever device the driver is using, with whatever timezone it happens to be set to. `DateTime.parse()`'s local-time default on a bare date string is a well-documented Dart ambiguity, not a bug, but it's exactly the kind of thing that "just works" during development (if the dev agent's own machine happens to be near UTC, or during testing with dates far enough from the boundary that a few hours of timezone skew doesn't change the outcome) while being silently wrong near the actual 24h boundary in whatever timezone a real driver is in.

### The exception-message-as-UI-copy pattern, made concrete
AD-3 states RPC failure messages map 1:1 to the client's displayed copy, "never a per-app custom error shape" — this story is the first place that principle actually matters for a *specific, user-facing* piece of text (rather than a generic fallback banner). Displaying the caught exception's message directly, rather than a client-maintained copy of the same string, is what keeps this guarantee real rather than aspirational — two independently-written copies of the same sentence are exactly the kind of thing that drifts apart over even one future edit to either side.

### Testing standards summary
No automated test suite in scope. Manually verify: a booked gig scheduled comfortably >24h out shows an active Cancel; one within 24h shows the disabled/muted state with the exact copy; tapping Cancel on an eligible gig removes it and (if Epic 1/2 are far enough along) produces the expected dispatcher-side reassignment/notification; Mark complete removes a row instantly with no intermediate screen; toggling reduced-motion collapses both removal animations to instant.

### Project Structure Notes
No new files — extends `booked_gig_row.dart` (Story 3.3) with the two ghost-button actions and their state logic.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 3.4: Cancel (24h Rule) & Mark Complete]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-7 — 24h cutoff computed identically on both clients, AD-3 — exception message maps 1:1 to displayed copy]
- [Source: _bmad-output/implementation-artifacts/1-4-driver-cancellation-24h-cutoff-auto-reassignment-notifications.md — the exact cutoff-exception message text, pinned there specifically for this story]
- [Source: _bmad-output/implementation-artifacts/3-3-booked-gigs-list.md — the Booked-gig row this story extends]
- [External: Dart `DateTime.parse()` local-time default on bare date strings — https://github.com/dart-lang/sdk/issues/37420]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
