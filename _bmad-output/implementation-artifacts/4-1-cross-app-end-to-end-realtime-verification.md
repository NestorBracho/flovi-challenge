---
baseline_commit: 38fb8462306aa90bfdfb6daa09936b82bc9e3d6f
---

# Story 4.1: Cross-App End-to-End Realtime Verification

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator preparing to present the demo,
I want to prove the full dispatcher↔driver realtime loop works against both live, deployed apps,
so that the 5-minute walkthrough is a proven, rehearsed flow rather than an untested hope.

## Acceptance Criteria

1. **Given** both apps are deployed at their public URLs (Story 2.5, Story 3.5), **when** a dispatcher creates a new relocation request on the live dispatcher-web URL, **then** it appears on the live driver-mobile URL's Gigs list within seconds, with no manual refresh (CAP-9 dispatcher→driver direction, Key Flow 2).
2. **Given** the driver books that gig on the live driver-mobile URL, **when** the booking succeeds, **then** the live dispatcher-web URL's Requests view reflects the `booked` status and assigned driver within seconds, with no manual refresh (CAP-9 driver→dispatcher direction).
3. **Given** the driver cancels that booked gig with ≥24h notice on the live driver-mobile URL, **when** the cancellation succeeds, **then** the gig is auto-reassigned (or reverts to `unbooked`) within seconds, and a new item appears in the live dispatcher-web URL's Notifications feed identifying the request and what happened, with no manual refresh on either side (CAP-12, CAP-13, Key Flow 3).
4. **Given** the full verification pass above ran without needing a manual refresh anywhere, **when** it's timed as a rehearsal, **then** it completes within a 5-minute walkthrough window, confirming NFR7 — this run is the demo rehearsal, not a separate exercise.
5. **Given** any step in this verification fails or exceeds the seconds-scale sync expectation, **when** the failure is diagnosed, **then** it is fixed at its source (Epic 1 RPC/RLS/realtime config, or the relevant Epic 2/3 story) and this story is re-run to confirm before being considered complete.

## Tasks / Subtasks

This story has no new code of its own to write — it's a live, hands-on rehearsal against both deployed apps. "Done" means a passing, timed run, not a written procedure. Fixes discovered along the way land in whichever Epic 1/2/3 story actually owns the broken piece, as their own new commits.

- [x] Task 0 — Prerequisites, not steps (AC: all)
  - [x] Both apps are actually **deployed** (Stories 2.5/3.5 done, not just storied) — this story cannot start meaningfully before that, unlike almost every other story in this project, which could be built in relative isolation
  - [x] Two **real** Google accounts, signed in separately (one as dispatcher, one as driver) — per Story 1.6's finding, seeded demo accounts have no real Google identity behind them and can never actually sign in. Use two browser windows/profiles (or two devices) so both sessions are visibly live at once during the walkthrough, matching how the actual 5-minute demo will be presented.
  - [x] To actually exercise the **reassignment** branch of CAP-12 (not just the revert-to-`unbooked` branch), a *second* real, active driver account with a nonzero `completed_rides_count` needs to exist. If only one real driver account is available for this rehearsal, that's fine — run the revert-to-`unbooked` path instead and note explicitly that reassignment itself was proven earlier in Story 1.4's own manual verification, not re-proven live here. Don't let "only one driver account handy" block this story; just be accurate about which branch was actually exercised live.

- [x] Task 1 — Dispatcher → driver direction (AC: #1, Key Flow 2)
  - [x] On the live dispatcher-web URL: sign in, create a **new** relocation request (not seed data — a fresh row this rehearsal creates itself, matching Flow 2's own narrative)
  - [x] On the live driver-mobile URL, already open and idle on Gigs: confirm the new gig appears without any refresh, within a few seconds

- [x] Task 2 — Driver → dispatcher direction (AC: #2)
  - [x] On the driver-mobile URL: book that same gig
  - [x] On the dispatcher-web URL, already open on Requests: confirm the status pill updates to `booked` with the correct driver name, without refresh

- [x] Task 3 — Cancellation, reassignment/revert, and notification (AC: #3)
  - [x] On the driver-mobile URL: cancel that booked gig (with the account and timing arranged so ≥24h remains — see Task 0's note on which branch is actually exercisable)
  - [x] Confirm on dispatcher-web: the request's status/driver reflects the outcome, and a new Notifications item appears identifying the request and what happened — all without refresh

- [x] Task 4 — Time it, because this run *is* the rehearsal (AC: #4)
  - [x] Run Tasks 1-3 back-to-back as the actual walkthrough script, timed with a stopwatch, start to finish. Confirm it fits comfortably inside 5 minutes — this is the literal NFR7 evidence, not a separate future exercise to schedule
  - [x] `book_request`'s own ~300ms bid-window sleep (Story 1.3) is expected, normal latency, not a failure to chase — don't mistake it for a sync problem while timing

- [x] Task 5 — Fix-at-source loop (AC: #5)
  - [x] Any failure or slower-than-expected sync gets diagnosed and fixed in whichever story actually owns it (an RPC/RLS/publication issue is Epic 1's; a subscription or UI issue is the specific Epic 2/3 story that built it) — as a new commit there, not a workaround patched into this story
  - [x] Re-run the whole sequence after any fix — a partial re-check of just the failed step isn't sufficient, since a fix in Epic 1 can have knock-on effects across both apps

## Dev Notes

### What "done" means for a story with no code of its own
Every other story in this project produces new files. This one's deliverable is a *confirmed, timed, passing live run* — the artifact is evidence (or a log of what broke and where it was fixed), not a diff. Don't look for something to "implement" here beyond actually running the rehearsal.

### Why two real Google accounts are non-negotiable, and what to do with only one driver account
This traces directly back to Story 1.6: Google OAuth is the only sign-in path in this entire app, and seeded `auth.users` rows have no real identity behind them. This story is exactly the moment that constraint becomes concrete and unavoidable — there's no way to fake either side of this rehearsal with seed data alone.

### Testing standards summary
This story *is* the testing — there is no separate automated check to run instead of or in addition to the live walkthrough. No automated test suite exists anywhere in this project (explicit non-goal per SPEC.md), so this manual, timed, two-account rehearsal is the actual verification method for the entire cross-app realtime contract, not a substitute for one.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 4.1: Cross-App End-to-End Realtime Verification]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — Key Flows 2 and 3, the exact scripted scenarios this story proves live]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#NFR7 — 5-minute walkthrough requirement]
- [Source: _bmad-output/implementation-artifacts/1-6-realtime-publication-seed-data-auth-configuration.md — why seeded accounts can't be used for this rehearsal]
- [Source: _bmad-output/implementation-artifacts/1-3-driver-visibility-booking-priority-mechanic.md — the ~300ms bid window that's expected latency, not a bug, during Task 4's timing]

## Dev Agent Record

### Agent Model Used

claude-sonnet-5 (Claude Code), driving Chrome via the claude-in-chrome browser-automation tools while the user handled Google sign-in interactively.

### Debug Log References

- First attempt at Task 1 hit a `403` on `POST .../relocation_requests` (Postgrest RLS rejection). Root cause: both browser tabs were signed into the same real Google account (`nestorbracho2207@gmail.com`), which had already claimed the `driver` role during Story 3.5's own live testing — `dispatcher_own`'s RLS policy requires `role = 'dispatcher'`, so the insert was correctly denied. Not a code bug; resolved by the user signing into a second real Google account for the dispatcher session (Task 0's own prerequisite).
- Second finding, this one a real code bug: `RequestCard.vue` never rendered which driver was assigned to a booked/completed request, and `useRequests.ts` didn't even fetch it — violates AC #2's "assigned driver" requirement. Root-caused to Story 2.2's `SELECT_COLUMNS` never joining `profiles`.
- Third finding, also a real bug: `RequestModal.vue`'s `handleSave` swallowed any insert/update error silently (`if (error || !data) { return }`) with zero user feedback — exactly the kind of failure that would strand a live demo with no explanation.
- Both fixed in commit `b96c8df` (pushed to `main` by the user after a local sandbox SSH auth failure prevented the agent from pushing directly), redeploy confirmed live via the deployed JS bundle before re-running.

### Completion Notes List

- Prerequisites: both apps confirmed already deployed at `https://flovi-challenge.vercel.app` (Story 2.5) and `https://flovi-driver-mobile.vercel.app` (Story 3.5). Two real Google accounts were used (dispatcher + driver), per Task 0. Only one real driver account was available, but the cancellation nonetheless exercised the **reassignment** branch of CAP-12 live (auto-reassigned to seed account "Demo Driver C", which has a nonzero `completed_rides_count`) rather than falling back to revert-to-`unbooked` — the reassignment RPC logic, dispatcher-side status/driver sync, and notification all fired for real, live, even though the reassignment target itself is a seeded profile that can't log in to confirm its own view.
- AC #1: dispatcher created a new request ("Miami, FL → Orlando, FL") on the live dispatcher-web URL; it appeared on the live driver-mobile URL's idle Gigs list with no manual refresh, within a couple of seconds.
- AC #2: driver booked the gig; dispatcher-web's Requests view updated to `Booked` status **and** showed "Driver: Nestor Bracho" live, no refresh — confirmed only after fixing the missing-driver-name bug (see Debug Log).
- AC #3: driver cancelled with the gig scheduled well beyond 24h out; dispatcher-web reflected the reassignment (driver name updated to "Demo Driver C", status stayed `Booked`) and a new Notifications item appeared identifying the request and outcome ("Nestor Bracho cancelled a gig — automatically reassigned to Demo Driver C.") — all with no manual refresh on either side.
- AC #4: the final clean re-run of Tasks 1-3, timed via wall-clock timestamps around the whole sequence, completed in 97 seconds — comfortably inside the 5-minute NFR7 window.
- AC #5: two real bugs found during the rehearsal (missing driver name on request cards; silent save-error swallowing in the create/edit modal) were fixed at source in Story 2.2/2.3's own files (not patched into this story), committed, pushed, redeployed, and the entire Tasks 1-3 sequence was re-run clean end-to-end against the fixed live app before this story was considered complete.
- Test data left live in production for now: two "Booked" requests ("Miami, FL → Orlando, FL" and "Tampa, FL → Jacksonville, FL", both reassigned to "Demo Driver C") remain in the shared Supabase project from this rehearsal. Not cleaned up automatically since deleting/cancelling data wasn't a defined task here — flagged for the user to clear before the actual live demo if desired.

### File List

- flovi/apps/dispatcher-web/src/composables/useRequests.ts (modified — join `profiles` for driver full name; realtime-safe driver-name resolution/cache)
- flovi/apps/dispatcher-web/src/components/RequestCard.vue (modified — render assigned driver's name)
- flovi/apps/dispatcher-web/src/components/RequestModal.vue (modified — surface save errors instead of swallowing them)

## Change Log

- 2026-07-09: Ran the full cross-app realtime rehearsal live against both deployed apps. Found and fixed two Story 2.2/2.3 bugs (missing driver name on request cards; silently swallowed save errors in the request modal) in commit `b96c8df`, redeployed, and re-ran the whole sequence clean — 97 seconds end to end, all five ACs confirmed with no manual refresh anywhere.
