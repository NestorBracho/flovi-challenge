---
baseline_commit: 7d4f06159158283478bfb1880aee2ebc9129e506
---

# Story 3.3: Booked Gigs List

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want a clear view of everything I've currently got booked,
so that I always know what I'm committed to without having to remember which gigs I claimed.

## Acceptance Criteria

1. **Given** a signed-in driver taps through the booking confirmation from Story 3.2, **when** they land on Booked, **then** the just-booked gig appears there via a Booked-gig row (route/date/notes, and a Status pill — dot + text + tint, never color-only, the same 4-state lifecycle component as the dispatcher app's pill, independently implemented in Flutter per AD-1) (CAP-8, UX-DR5).
2. **Given** a signed-in driver's booked gigs have loaded, **when** the Booked view renders, **then** skeleton loading is shown identically to Gigs during cold load (UX-DR26), and every currently-booked gig for that driver appears, and nothing else (CAP-8).
3. **Given** a signed-in driver has zero booked gigs, **when** the Booked view renders, **then** a dashed-border empty-state panel shows "You haven't booked anything yet." plus a ghost-button link back to Gigs, using the same Empty-state panel component pattern as the dispatcher app, independently implemented in Flutter (UX-DR12).
4. **Given** a signed-in driver is viewing Booked, **when** one of their booked gigs is cancelled by the dispatcher elsewhere, **then** the initial SELECT hydration plus an active realtime subscription removes it from Booked instantly, with no manual reload (CAP-9 producing half, CAP-10 cross-app effect, AD-5).

## Tasks / Subtasks

- [x] Task 1 — Reuse Story 3.2's subscription, don't duplicate it (AC: #1, #2, #4)
  - [x] Booked and Gigs both read the *same* `relocation_requests` table under the *same* `driver_visibility` RLS policy — they only differ in which client-side status filter they apply. Don't open a second independent realtime channel on the same table for this view; derive Booked's filtered list from the single shared subscription/state Story 3.2 established, the same "lift the subscription above the single view that needs it" reasoning already used for the dispatcher app's notifications badge (Story 2.4)
  - [x] Client-side filter for this view specifically: `status == 'booked' AND driver_id == currentUserId`. **This must exclude `completed` rows explicitly** — `driver_visibility`'s RLS keeps a driver's own completed rides visible to them regardless of status (ownership never changes), so the row stays reachable via the shared subscription; it's this view's own filter that has to drop it, not RLS. (Story 3.4's "Mark complete" removes a row from Booked by transitioning its status away from `booked` — this filter is what makes that removal actually take effect on screen.)

- [x] Task 2 — Status pill and Empty-state panel: first built in Flutter here (AC: #1, #3)
  - [x] Neither component existed yet before this story (Story 3.2's Gig card only needed a single "Book this gig" action, no status ambiguity since a gig is unbooked by definition). Build both now as reusable widgets, driven by Story 3.1's `ThemeExtension` status tokens (`status-booked`/`status-booked-text`/`status-booked-tint`, etc.) — same visual recipe as the dispatcher web app's versions, independently implemented per AD-1, not shared code between the two apps
  - [x] Status pill: dot (full-saturation swatch) + label (the `-text` variant) + tint background — three redundant cues, never color-only. Build it generically for all 4 states even though this specific view's filter (Task 1) means it will only ever actually render the `booked` state in practice — it's the same reusable component Story 3.4 continues to rely on
  - [x] Empty-state panel: dashed border, icon circle in the tint surface color, single ghost-button recovery action — here, "You haven't booked anything yet." + a link back to the Gigs tab

- [x] Task 3 — Skeleton loading (AC: #2)
  - [x] Same skeleton treatment as Story 3.2's Gigs view — shape of a Card, no content, shown only during the initial load

## Dev Notes

### Why this view filters out `completed` even though RLS still shows it
`driver_visibility`'s policy is `status = 'unbooked' OR driver_id = auth.uid()` — once a row is assigned to a driver, the second clause keeps it visible to that driver forever, regardless of what status it later reaches. That's correct and necessary (a driver needs to keep seeing their own `completed` history for other purposes), but it means RLS alone doesn't distinguish "currently booked" from "history" — this view's own client-side filter is what does that. This is the same category of lesson Story 3.2 established (RLS grants row-level access; the view's own filter decides what's actually shown for its specific purpose), applied to a different filter predicate here.

### One shared subscription, two filtered views
Story 3.2 and this story both read `relocation_requests` under the same policy — building a second independent subscription here would work, but it's wasteful (two WebSocket channels doing the same job) and risks the two views drifting out of sync with each other if their event-handling logic isn't identical. Deriving both from one shared source avoids that by construction.

### Testing standards summary
No automated test suite in scope. Manually verify: booking a gig (Story 3.2) lands it here immediately with the correct pill; a directly-SQL-cancelled booked gig (simulating Epic 2's dispatcher action) disappears from this view live; zero booked gigs shows the exact empty-state copy.

### Project Structure Notes
```
apps/driver-mobile/lib/
  widgets/status_pill.dart, booked_gig_row.dart, empty_state_panel.dart   # new
  screens/booked.dart   # fleshed out from Story 3.1's shell placeholder
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 3.3: Booked Gigs List]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — Status pill, Booked-gig row, Empty-state panel components]
- [Source: _bmad-output/implementation-artifacts/3-1-app-shell-design-tokens-login-role-claiming.md — `ThemeExtension` status tokens this story's pill consumes]
- [Source: _bmad-output/implementation-artifacts/3-2-gigs-list-realtime-sync-booking-confirmation.md — the shared realtime subscription this story derives from rather than duplicating]
- [Source: _bmad-output/implementation-artifacts/1-5-ride-completion-priority-count-increment.md — `complete_request` removes a row from active booked gigs, which this view's filter must actually reflect]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

- `flutter analyze` — clean, 0 issues (one intermediate run surfaced 3 `unused_element_parameter` warnings on `_DashedRoundedRectPainter`'s unused customization params; resolved by inlining the constants since no caller varied them).
- `flutter build web --dart-define-from-file=dart_defines.json` — succeeded.
- Manual browser verification (Chrome, `flutter run -d chrome --web-port=5001`): app boots, Supabase initializes, unauthenticated redirect to `/login` works, no console errors. This project's only auth path is real Google OAuth (`seed.sql` confirms seeded demo accounts "can never actually sign in") so an end-to-end authenticated booking→Booked→realtime-cancel trace could not be driven from this session; that full loop is Story 4.1's cross-app verification pass and otherwise needs the operator's own Google-authenticated session per `seed.sql`'s Dev Notes.
- To still validate the new visual components against a real render (not just code review), temporarily swapped `main.dart`'s entrypoint for a static preview rendering all 4 `StatusPill` states, a `BookedGigRow`, and the `EmptyStatePanel` with its ghost-button action outside the auth flow, screenshotted it, then reverted `main.dart` byte-for-byte (confirmed via `git diff` showing no change to that file). Dashed border, dot+text+tint pill recipe, and row layout all rendered as intended.

### Completion Notes List

- **Task 1:** `GigsService` (`lib/services/gigs_service.dart`) now multiplexes ONE realtime channel (`relocation-requests-changes`) across every caller instead of Story 3.2's single-purpose `gigs-changes` channel — `subscribe({onChange})` registers a raw-row callback, fans out each INSERT/UPDATE payload to every registered listener, and only tears down the channel once the last listener unsubscribes (Gigs and Booked are both kept alive simultaneously by GoRouter's `StatefulShellRoute.indexedStack`, so one screen unmounting must not cut the other's feed). Each caller now does its own upsert-vs-remove branch on the raw row against its own predicate — `GigsScreen` on `status == 'unbooked'` (unchanged behavior from Story 3.2, just relocated from the service into the screen), `BookedScreen` on `status == 'booked' && driver_id == me`. Added `Gig.driverId` and `fetchBookedGigs(driverId)` (server-side `status = booked AND driver_id = me` filter — RLS alone would also surface this driver's `completed`/`cancelled` history, so the view's own query narrows it, the same split Story 3.2 established for Gigs). `GigsScreen`'s existing booking/race-handling logic (`_bookingIds`/`_unavailableIds`/`_removingIds`, the "No longer available" 2s in-place text) is untouched.
- **Task 2:** `StatusPill` (`lib/widgets/status_pill.dart`) — dot (8px, full-saturation token) + label (`-text` token) + tint background pill, built generically for all 4 lifecycle states off a `switch` on the raw status string, matching the dispatcher-web `StatusPill.vue` recipe (dot/text/tint token triad) independently in Flutter. `EmptyStatePanel` (`lib/widgets/empty_state_panel.dart`) — dashed-border panel (a small `CustomPainter` since Flutter's `BorderStyle` has no dashed option and pulling in a package for one border style wasn't warranted), 48px icon circle in `surfaceTint`, message, optional action slot — matches dispatcher-web's `EmptyStatePanel.vue` layout. `BookedGigRow` (`lib/widgets/booked_gig_row.dart`) — same origin/destination/date/notes card layout as `GigCard`, `StatusPill` in place of the action area (no action on this row until Story 3.4 adds cancel/mark-complete).
- **Task 3:** `BookedScreen` (`lib/screens/booked_screen.dart`) fleshed out from Story 3.1's shell placeholder: hydrates via `fetchBookedGigs(currentUserId)`, subscribes to the shared channel, shows the same 3-item `GigCardSkeleton` list Gigs uses during `_loading` (AC #2), an `EmptyStatePanel` with the exact "You haven't booked anything yet." copy plus a bordered ghost-button `context.go('/gigs')` action when the list is empty (AC #3), and a `BookedGigRow` list otherwise (AC #1). Realtime removal (AC #4) falls out of the same predicate used for upsert: a row that stops matching `status == booked && driver_id == me` (dispatcher cancellation, or Story 3.4's future mark-complete) is removed from the list instantly via `setState`, no manual reload.

### File List

- `flovi/apps/driver-mobile/lib/services/gigs_service.dart` (modified)
- `flovi/apps/driver-mobile/lib/screens/gigs_screen.dart` (modified)
- `flovi/apps/driver-mobile/lib/screens/booked_screen.dart` (modified)
- `flovi/apps/driver-mobile/lib/widgets/status_pill.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/empty_state_panel.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/booked_gig_row.dart` (new)

## Change Log

- 2026-07-09 — Implemented Story 3.3 in full: refactored `GigsService`'s realtime subscription from Story 3.2's single-purpose channel into a multiplexed shared channel so Gigs and Booked derive from one `relocation_requests` WebSocket subscription instead of two; added `StatusPill`, `EmptyStatePanel` (dashed border via a small `CustomPainter`), and `BookedGigRow` widgets; fleshed out `BookedScreen` with hydration, skeleton loading, empty state, and realtime sync. All 3 tasks complete; all 4 ACs implemented. `flutter analyze` clean, `flutter build web` succeeds. Verified the new widgets render correctly (dashed border, dot+text+tint pills for all 4 states, row layout) via a temporary isolated preview outside the auth flow, since this project's only auth path is real Google OAuth and no seeded account can actually sign in (`seed.sql`) — a full authenticated cross-app realtime trace is deferred to the operator or Story 4.1. Status → review.
