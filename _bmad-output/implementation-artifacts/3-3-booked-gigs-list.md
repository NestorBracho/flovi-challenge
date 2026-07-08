# Story 3.3: Booked Gigs List

Status: ready-for-dev

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

- [ ] Task 1 — Reuse Story 3.2's subscription, don't duplicate it (AC: #1, #2, #4)
  - [ ] Booked and Gigs both read the *same* `relocation_requests` table under the *same* `driver_visibility` RLS policy — they only differ in which client-side status filter they apply. Don't open a second independent realtime channel on the same table for this view; derive Booked's filtered list from the single shared subscription/state Story 3.2 established, the same "lift the subscription above the single view that needs it" reasoning already used for the dispatcher app's notifications badge (Story 2.4)
  - [ ] Client-side filter for this view specifically: `status == 'booked' AND driver_id == currentUserId`. **This must exclude `completed` rows explicitly** — `driver_visibility`'s RLS keeps a driver's own completed rides visible to them regardless of status (ownership never changes), so the row stays reachable via the shared subscription; it's this view's own filter that has to drop it, not RLS. (Story 3.4's "Mark complete" removes a row from Booked by transitioning its status away from `booked` — this filter is what makes that removal actually take effect on screen.)

- [ ] Task 2 — Status pill and Empty-state panel: first built in Flutter here (AC: #1, #3)
  - [ ] Neither component existed yet before this story (Story 3.2's Gig card only needed a single "Book this gig" action, no status ambiguity since a gig is unbooked by definition). Build both now as reusable widgets, driven by Story 3.1's `ThemeExtension` status tokens (`status-booked`/`status-booked-text`/`status-booked-tint`, etc.) — same visual recipe as the dispatcher web app's versions, independently implemented per AD-1, not shared code between the two apps
  - [ ] Status pill: dot (full-saturation swatch) + label (the `-text` variant) + tint background — three redundant cues, never color-only. Build it generically for all 4 states even though this specific view's filter (Task 1) means it will only ever actually render the `booked` state in practice — it's the same reusable component Story 3.4 continues to rely on
  - [ ] Empty-state panel: dashed border, icon circle in the tint surface color, single ghost-button recovery action — here, "You haven't booked anything yet." + a link back to the Gigs tab

- [ ] Task 3 — Skeleton loading (AC: #2)
  - [ ] Same skeleton treatment as Story 3.2's Gigs view — shape of a Card, no content, shown only during the initial load

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

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
