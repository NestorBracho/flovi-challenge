# Story 3.2: Gigs List, Realtime Sync, Booking & Confirmation

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in driver,
I want to browse available gigs that update live, book one in a single tap, and see unambiguous confirmation that it worked,
so that I can quickly and confidently claim relocation work as it becomes available, fairly against other drivers.

## Acceptance Criteria

1. **Given** a signed-in driver lands on Gigs, **when** the view is loading, **then** skeleton row placeholders (shape of a Card, no content) are shown until data resolves (UX-DR26).
2. **Given** a signed-in driver's gigs have loaded, **when** the Gigs view renders, **then** every `unbooked` request visible to them (per `driver_visibility` RLS) appears as a Gig card with one primary action, "Book this gig," and no secondary actions (CAP-6, UX-DR15).
3. **Given** a signed-in driver has zero available gigs, **when** the Gigs view renders, **then** it shows "No gigs available right now — check back soon." with no CTA.
4. **Given** a signed-in driver is viewing Gigs, **when** a dispatcher creates a new request elsewhere, **then** the initial SELECT hydration plus an active realtime subscription on `relocation_requests` shows the new gig without an app restart or manual refresh (CAP-6, CAP-9 producing half, AD-5).
5. **Given** a signed-in driver taps "Book this gig" on an available gig, **when** the `book_request` RPC call resolves as a win, **then** a full-screen booking confirmation interstitial appears (never a modal) — a check-icon in `status-completed-tint`/`status-completed`, a heading, a Card-styled summary of the route/date/notes, and a single full-width primary button through to Booked gigs (CAP-7, UX-DR16).
6. **Given** a signed-in driver taps "Book this gig" but another driver's concurrent bid wins (higher `completed_rides_count`), **when** the `book_request` RPC call resolves as a loss, **then** the card shows "No longer available" in place of the Book button for ~2 seconds, announced via `aria-live="polite"`, then the card is removed from the list — no confirmation screen, no false commitment (UX-DR22, UX-DR23).

## Tasks / Subtasks

- [ ] Task 1 — The booking call sequence: **this is the single most important thing in this story to get exactly right** (AC: #5, #6)
  - [ ] Story 1.3 designed `book_request` assuming the client performs a **two-step sequence**, not one RPC call: (1) `await supabase.from('booking_bids').insert({ request_id: gigId, driver_id: currentUserId })`, then immediately (2) `const won = await supabase.rpc('book_request', { p_request_id: gigId })`. **Calling `book_request` alone, without the preceding direct bid insert, silently breaks the entire priority tie-break** — not loudly, not with an error, just by making whoever happens to call the RPC first the de-facto winner regardless of `completed_rides_count`, since `book_request`'s own decision logic only sees bids that were already independently committed to the table before it started its 300ms sleep.
  - [ ] `book_request` returns a **boolean** (`true` = this caller is the assigned driver, `false` = not). Branch directly on this return value — do not infer win/loss from any subsequent realtime event (see Dev Notes for why this isn't just a latency optimization, it's required)
  - [ ] `won === true`: navigate to the full-screen booking confirmation interstitial (Task 3)
  - [ ] `won === false`: the "No longer available" treatment on this same card (Task 4)
  - [ ] If the bid insert itself fails (network error before the RPC is even called), treat as the generic network/sync error banner — do not proceed to call `book_request` at all

- [ ] Task 2 — Gigs list: skeleton, card, zero-state, realtime (AC: #1, #2, #3, #4)
  - [ ] Skeleton rows (Card shape, no content) during initial load only
  - [ ] Gig card: origin/destination/date/notes, **one** primary action ("Book this gig"), no secondary actions on the browse card itself
  - [ ] Zero gigs: `"No gigs available right now — check back soon."` — no CTA (there's nothing actionable for the driver to do)
  - [ ] Realtime subscription on `relocation_requests`, filtered locally to `status === 'unbooked'` for display — handle INSERT (new dispatcher-created request appears) and UPDATE (a gig's status changes, e.g. because *this* driver's own book action just succeeded, or a reassignment reopened something to `unbooked` — Story 1.4's revert path)

- [ ] Task 3 — Booking confirmation interstitial (AC: #5)
  - [ ] Full-screen route, **not** a modal/dialog — DESIGN.md is explicit driver-mobile never uses a centered modal, full-screen interstitials only. Per Story 3.1, the tab bar must be hidden while this is showing (UX-DR18) — implement as a route pushed outside/on top of the tab-bar shell, not a screen nested inside one of the 3 tabs.
  - [ ] Check-icon in `status-completed-tint`/`status-completed` (reuse the status color tokens from Story 3.1's `ThemeExtension`, not new hardcoded colors), heading, Card-styled route/date/notes summary, single full-width primary button navigating to the Booked tab
  - [ ] The interstitial's entrance is one of EXPERIENCE.md's three named transient-motion cases requiring `prefers-reduced-motion` handling (alongside the status-pill flash and the race-lost card removal below) — collapse any entrance animation to instant/opacity-only under that preference

- [ ] Task 4 — "No longer available" treatment (AC: #6)
  - [ ] On `won === false`: replace the Book button with "No longer available" text in place, for ~2 seconds, announced via `aria-live="polite"` the moment it appears (not just visually shown) — screen-reader users need to learn the attempt failed without watching the screen
  - [ ] After ~2s, remove the card from the list. If the removal itself is animated, it's the third of EXPERIENCE.md's named reduced-motion cases — collapse to instant/opacity-only under that preference

## Dev Notes

### Why the acting driver's own RPC response — not realtime — is required, not just faster
This deserves more emphasis than "it's a nicer UX." Verified directly: Supabase Realtime evaluates each subscriber's RLS at delivery time — if an UPDATE changes a row in a way that makes it no longer match a subscriber's RLS-visible set, **that subscriber receives no event at all for that change, not even a synthetic delete.** `driver_visibility`'s policy is `status = 'unbooked' OR driver_id = auth.uid()` — the instant this gig transitions to `booked` with someone *else's* `driver_id`, that predicate goes false for both (a) the driver whose bid just lost and (b) every other driver who never bid on it at all. **The losing driver's own realtime subscription will never receive any event telling them this row changed** — the only way they find out is the direct return value of their own `book_request` call, which is exactly why Task 1 branches on that return value directly rather than waiting on the subscription.

### The corollary: third-party (never-bid) drivers can see a briefly-stale gig, and that's an accepted trade-off, not a bug to chase
A driver who never tapped "Book" on a gig that someone else then won has no RPC response of their own to correct their view, and per the above, no realtime event will arrive either — their card can remain visible until they either attempt to book it themselves (which self-corrects immediately, since the RPC will then correctly return `false`) or the app is refreshed. AD-5 explicitly rules out polling as a substitute for realtime, so building a periodic re-fetch workaround here would cut against the architecture's own stated principle for a demo-scale limitation that isn't part of any scripted flow anyway (EXPERIENCE.md's Flow 2 only involves the two directly-competing drivers, both of whom get a correct, immediate answer via their own RPC call). Worth knowing this is a real, understood characteristic of the system rather than discovering it mid-rehearsal and treating it as a regression to fix.

### Testing standards summary
No automated test suite in scope. The two-step booking sequence (Task 1) is worth testing deliberately with two accounts of different `completed_rides_count`, mirroring Story 1.3's own manual verification — this is the second and last place in the whole project that mechanism is exercised, and it's the client half of it.

### Project Structure Notes
```
apps/driver-mobile/lib/
  screens/gigs.dart, booking_confirmation.dart
  widgets/gig_card.dart
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 3.2: Gigs List, Realtime Sync, Booking & Confirmation]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — Booking confirmation component, Do's and Don'ts (no modal on mobile)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — State Patterns (booking race lost), Interaction Primitives (reduced-motion cases), Flow 2]
- [Source: _bmad-output/implementation-artifacts/1-3-driver-visibility-booking-priority-mechanic.md — the two-step client contract this story implements, `book_request`'s boolean return]
- [Source: _bmad-output/implementation-artifacts/3-1-app-shell-design-tokens-login-role-claiming.md — `ThemeExtension` status colors, tab-bar shell the interstitial sits outside of]
- [External: Supabase Realtime + RLS — rows invisible after an UPDATE produce no event — https://github.com/orgs/supabase/discussions/12471]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
