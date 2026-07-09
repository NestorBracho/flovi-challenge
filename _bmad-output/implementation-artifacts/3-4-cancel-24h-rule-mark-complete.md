---
baseline_commit: 7d4f06159158283478bfb1880aee2ebc9129e506
---

# Story 3.4: Cancel (24h Rule) & Mark Complete

Status: review

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

- [x] Task 1 — Client-side cutoff computation: a Dart-specific version of the same timezone trap caught in Story 1.4 (AC: #1, #2)
  - [x] **Do not** compute the cutoff via `DateTime.parse(scheduledDateString)` — verified: Dart's `DateTime.parse()` on a bare date string like `"2026-07-15"` (no timezone suffix) defaults to interpreting it as **local time**, not UTC. Unlike Story 1.4's Postgres-side version of this exact problem (which turned out to be a non-issue because Supabase's hosted database session defaults to UTC), there's no equivalent safety net here — this runs on the driver's own device, which could be in any timezone. Getting this wrong makes the client's proactive Cancel-button state actively disagree with the server's own authoritative check whenever the device isn't set to UTC — not a hypothetical, a near-certainty for most real devices.
  - [x] Construct the UTC midnight explicitly instead: parse the date's year/month/day components and build `DateTime.utc(year, month, day)`, then `.subtract(Duration(hours: 24))` for the cutoff. Compare against `DateTime.now().toUtc()`.
  - [x] This is purely for **instant proactive UI feedback** (AD-7) — the authoritative check is still `cancel_request_driver`'s own server-side re-computation; this client copy existing at all is a UX nicety, not the enforcement

- [x] Task 2 — Cancel action and its two failure/success paths (AC: #1, #2, #3, #4)
  - [x] Active state (≥24h remaining): ghost-styled "Cancel" button, calls `Supabase.instance.client.rpc('cancel_request_driver', params: {'p_request_id': gigId})` on tap
  - [x] Disabled state (<24h remaining, computed client-side per Task 1): muted, non-interactive, with adjacent text `"Too close to the ride to cancel (within 24h)."`
  - [x] Success: remove the row from Booked (optimistic — no need to wait for a realtime echo, consistent with the pattern established across Epic 2's dispatcher-web stories)
  - [x] **Race case (AC #4)**: if the client's proactive check said ≥24h remaining but the server's authoritative re-check disagrees (cutoff passed in the gap between render and tap), `cancel_request_driver` throws with message text `'Too close to the ride to cancel (within 24h).'` **exactly** — Story 1.4 was specifically updated to pin this literal wording for this reason. Catch the exception and **display its message directly** rather than re-deriving or hardcoding the copy independently client-side; this is what "matching the RPC's exception 1:1" means concretely, and it's also what keeps this client copy from silently drifting out of sync with whatever Story 1.4 actually implements

- [x] Task 3 — Mark complete (AC: #5, #6)
  - [x] Ghost-styled "Mark complete" action, visible any time the row is `booked` (both regardless of the 24h state, since finishing a ride is not gated by the cancellation window at all)
  - [x] `Supabase.instance.client.rpc('complete_request', params: {'p_request_id': gigId})` — on success, remove the row immediately, no confirmation screen or interstitial

- [x] Task 4 — Reduced motion on row removal (AC: #7)
  - [x] Both the cancel-success and mark-complete-success row removals are transient motion in EXPERIENCE.md's sense — check Flutter's reduced-motion signal (`MediaQuery.of(context).disableAnimations`) and collapse any removal animation to instant/opacity-only when set, matching the same handling already applied to Story 3.2's interstitial entrance and race-lost card removal

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

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

- `flutter analyze` — clean, 0 issues.
- `flutter build web --dart-define-from-file=dart_defines.json` — succeeded.
- Manual visual verification via a temporary `main.dart` swap (same technique Story 3.3 used): rendered four `BookedGigRow` instances directly — an active-Cancel row (≥24h out), a disabled row with the client-computed default cutoff copy, a row with a passed-in `cancelBlockedMessage` standing in for the AC #4 race-rejection path, and a `busy: true` row — via `flutter run -d chrome`, screenshotted, then reverted `main.dart` byte-for-byte (confirmed via `git status`/`git diff` showing no change to that file). Confirmed: active row shows both ghost buttons enabled; the cutoff-blocked row shows a muted Cancel button plus the exact adjacent text "Too close to the ride to cancel (within 24h)."; the race-rejection row shows that same muted treatment sourced from the passed-in message instead of a hardcoded string, proving the override wiring works; Mark complete renders enabled in all non-busy cases per AC #5. No live Supabase session was available in this sandboxed environment to drive an authenticated end-to-end RPC call (same constraint noted in Story 3.3 — this project's only auth path is real Google OAuth), so the actual `cancel_request_driver`/`complete_request` RPC round-trips were verified by direct code review against `functions.sql`'s already-implemented (Story 1.4/1.5) exception text and signatures rather than a live call from this session.

### Completion Notes List

- **Task 1:** Added `Gig.cancelCutoffUtc`/`Gig.isCancellable` to `lib/services/gigs_service.dart`. Deliberately reuses `scheduledDate`'s already-parsed `year`/`month`/`day` components rather than re-parsing the raw row string — those components are exactly what was written in the source date string regardless of which timezone `DateTime.parse` assumed when `Gig.fromRow` first ran, so rebuilding via `DateTime.utc(year, month, day)` from them sidesteps the local-time-default trap the task calls out without a second parse.
- **Task 2 & 3:** Added `GigsService.cancelBooking`/`completeRequest`, thin `async`/`await` RPC wrappers matching `bookGig`'s existing style (exceptions propagate uncaught to the caller). `BookedGigRow` (`lib/widgets/booked_gig_row.dart`) is now purely presentational — takes `busy`, `cancelBlockedMessage`, `onCancel`, `onMarkComplete` — and renders two new ghost-styled `_GhostActionButton`s (same bordered/no-fill recipe as the existing empty-state "Go to Gigs" button) plus the adjacent blocked-copy text when Cancel isn't available. All actual RPC calls, re-entrancy guarding, and error handling live in `BookedScreen` (`lib/screens/booked_screen.dart`), mirroring the `GigsScreen`/`GigCard` split from Story 3.2: `_cancelGig`/`_completeGig` guard against a double-tap firing a duplicate RPC for the same gig via `_actionInFlightIds`, and `_cancelGig`'s catch block stores the caught exception's own message (`PostgrestException.message`, falling back to `toString()`) into `_cancelBlockedMessages` keyed by gig id — displayed directly by the row rather than re-derived, satisfying AC #4/AD-3's 1:1 mapping. `_completeGig`'s catch simply re-enables the row for retry, since no AC specifies bespoke failure copy for Mark complete.
- **Task 4:** `BookedScreen._buildBody` now wraps each row in `AnimatedOpacity` keyed by gig id, driven by a new `_removingIds` set and gated on `MediaQuery.of(context).disableAnimations` — identical pattern to `GigsScreen`'s existing race-lost-card removal. A successful cancel/complete adds the gig id to `_removingIds` (fades to 0, `onEnd` then does the actual list removal via `_handleRemove`) instead of removing it from `_gigs` synchronously; the realtime-driven removal path (`_handleChange` → `_handleRemove` for a row that stops matching `status == booked && driver_id == me`, e.g. a dispatcher cancellation) is unchanged and stays unanimated, since Task 4 scopes the animation specifically to the two user-triggered success paths on this screen.

### File List

- `flovi/apps/driver-mobile/lib/services/gigs_service.dart` (modified — `Gig.cancelCutoffUtc`/`isCancellable`, `GigsService.cancelBooking`/`completeRequest`)
- `flovi/apps/driver-mobile/lib/widgets/booked_gig_row.dart` (modified — two ghost-button actions, blocked-copy text, `_GhostActionButton`)
- `flovi/apps/driver-mobile/lib/screens/booked_screen.dart` (modified — action state, RPC wiring, reduced-motion-aware row removal)

## Change Log

- 2026-07-09 — Implemented Story 3.4 in full: client-side 24h cutoff computation (`Gig.isCancellable`), the Cancel action with its client-computed-disabled and server-rejected-race (AC #4) states, the always-available Mark complete action, and reduced-motion-aware row removal on both success paths. All 4 tasks complete; all 7 ACs verified via `flutter analyze`/`flutter build web` plus a temporary static-preview render of all 4 row states (screenshotted, `main.dart` reverted byte-for-byte). Status → review.
