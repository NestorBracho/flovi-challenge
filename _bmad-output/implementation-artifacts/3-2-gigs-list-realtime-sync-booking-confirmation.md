---
baseline_commit: 18580d16cd6c72aab46b9541ea3d5748b7fdd53a
---

# Story 3.2: Gigs List, Realtime Sync, Booking & Confirmation

Status: review

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

- [x] Task 1 — The booking call sequence: **this is the single most important thing in this story to get exactly right** (AC: #5, #6)
  - [x] Story 1.3 designed `book_request` assuming the client performs a **two-step sequence**, not one RPC call: (1) `await supabase.from('booking_bids').insert({ request_id: gigId, driver_id: currentUserId })`, then immediately (2) `const won = await supabase.rpc('book_request', { p_request_id: gigId })`. **Calling `book_request` alone, without the preceding direct bid insert, silently breaks the entire priority tie-break** — not loudly, not with an error, just by making whoever happens to call the RPC first the de-facto winner regardless of `completed_rides_count`, since `book_request`'s own decision logic only sees bids that were already independently committed to the table before it started its 300ms sleep.
  - [x] `book_request` returns a **boolean** (`true` = this caller is the assigned driver, `false` = not). Branch directly on this return value — do not infer win/loss from any subsequent realtime event (see Dev Notes for why this isn't just a latency optimization, it's required)
  - [x] `won === true`: navigate to the full-screen booking confirmation interstitial (Task 3)
  - [x] `won === false`: the "No longer available" treatment on this same card (Task 4)
  - [x] If the bid insert itself fails (network error before the RPC is even called), treat as the generic network/sync error banner — do not proceed to call `book_request` at all

- [x] Task 2 — Gigs list: skeleton, card, zero-state, realtime (AC: #1, #2, #3, #4)
  - [x] Skeleton rows (Card shape, no content) during initial load only
  - [x] Gig card: origin/destination/date/notes, **one** primary action ("Book this gig"), no secondary actions on the browse card itself
  - [x] Zero gigs: `"No gigs available right now — check back soon."` — no CTA (there's nothing actionable for the driver to do)
  - [x] Realtime subscription on `relocation_requests`, filtered locally to `status === 'unbooked'` for display — handle INSERT (new dispatcher-created request appears) and UPDATE (a gig's status changes, e.g. because *this* driver's own book action just succeeded, or a reassignment reopened something to `unbooked` — Story 1.4's revert path)

- [x] Task 3 — Booking confirmation interstitial (AC: #5)
  - [x] Full-screen route, **not** a modal/dialog — DESIGN.md is explicit driver-mobile never uses a centered modal, full-screen interstitials only. Per Story 3.1, the tab bar must be hidden while this is showing (UX-DR18) — implement as a route pushed outside/on top of the tab-bar shell, not a screen nested inside one of the 3 tabs.
  - [x] Check-icon in `status-completed-tint`/`status-completed` (reuse the status color tokens from Story 3.1's `ThemeExtension`, not new hardcoded colors), heading, Card-styled route/date/notes summary, single full-width primary button navigating to the Booked tab
  - [x] The interstitial's entrance is one of EXPERIENCE.md's three named transient-motion cases requiring `prefers-reduced-motion` handling (alongside the status-pill flash and the race-lost card removal below) — collapse any entrance animation to instant/opacity-only under that preference

- [x] Task 4 — "No longer available" treatment (AC: #6)
  - [x] On `won === false`: replace the Book button with "No longer available" text in place, for ~2 seconds, announced via `aria-live="polite"` the moment it appears (not just visually shown) — screen-reader users need to learn the attempt failed without watching the screen
  - [x] After ~2s, remove the card from the list. If the removal itself is animated, it's the third of EXPERIENCE.md's named reduced-motion cases — collapse to instant/opacity-only under that preference

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

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- Verified the two-step booking sequence's tie-break logic directly against the live Supabase project via a user-supplied temporary `psql` connection (deleted after use), mirroring Story 1.3's own manual-verification approach — this is the second and last place in the project that mechanism is exercised, and the Dev Notes explicitly called out deliberate testing with two accounts of different `completed_rides_count`. Seeded a throwaway `unbooked` request, then fired two backgrounded `psql` sessions simulating Demo Driver B (`completed_rides_count = 3`) and Demo Driver C (`= 7`) each performing the *exact* client sequence `GigsService.bookGig` issues (a standalone `booking_bids` INSERT as its own autocommitted statement, immediately followed by a separate `book_request` RPC call — not wrapped in one transaction, which is what makes the priority window actually work per Story 1.3's Dev Notes). Result: Driver C won regardless of call order, Driver B's call correctly returned `false`, `booking_bids` was cleared to 0 rows, a repeat call from the loser returned `false` with no state change, and a dispatcher-role caller was correctly rejected. All test data and the connection string were deleted afterward.
- Full end-to-end browser verification against the live Supabase project: the operator (Nestor) completed real Google OAuth sign-in as a driver (his existing account previously held the `dispatcher` role from Story 2.x testing — with his explicit confirmation, its `profiles` row and 5 dependent already-cancelled test `relocation_requests` rows were deleted so `claim_role('driver')` could succeed fresh; his `auth.users` identity was left untouched). Verified live: Gigs cards render origin/destination/date/notes correctly from real seeded data, "Book this gig" triggers a real `booking_bids` insert + `book_request` call, a win navigates to the confirmation interstitial (exact copy, check icon, route/date/notes summary, "View my booked gigs"), the booked gig disappears from Gigs in real time via the realtime UPDATE handler, and "View my booked gigs" lands on the Booked tab with the tab bar correctly restored. Also incidentally captured the skeleton-row loading state (AC #1) rendering correctly on a tab revisit.
- **Real, non-trivial bug found and fixed during verification**: the first live click worked, but repeated automated re-tests (and, on closer analysis, would eventually have hit real users too, since it reproduced identically against a genuine `flutter build web` production bundle served statically with no debug tooling attached) showed the app intermittently stuck on `/gigs` after a *successful* win — `book_request` correctly returned `true` and the DB was correctly updated, but the confirmation screen never took over. Root-caused via targeted instrumentation to a `go_router` interaction: `context.push('/booking-confirmation', ...)` layers the confirmation page on top of the `StatefulShellRoute`, but any subsequent `refreshListenable` notification (the router's auth-stream listener re-fired on *every* stream event, including a background `tokenRefreshed`/duplicate `initialSession` once the session aged past its first few minutes) causes GoRouter to recompute its route match list from the shell branch's own location and silently drop the pushed page. Fixed two ways: (1) `_GoRouterRefreshStream` now only calls `notifyListeners()` on an actual signed-in/signed-out transition, not on every stream event; (2) `GigsScreen._bookGig` now navigates via `context.go('/booking-confirmation', ...)` instead of `push`, making the confirmation route unambiguously the router's current location rather than a layered page — this was the fix that actually resolved it, confirmed via multiple repeat bookings against a real `flutter build web` production build with no debug/DWDS service attached (ruling out a dev-mode-only cause). Also added: `main.dart` now builds `GoRouter` once as a static field instead of inline in `build()` (a separate, pre-existing footgun noted along the way — go_router's own docs call out constructing the router inside `build()` as the standard mistake), and `_bookGig` gained a re-entrancy guard plus no longer briefly re-enables the Book button before navigating away on a win, closing a window where a replayed tap could double-dispatch a booking attempt.
- `flutter analyze` clean (0 issues) throughout; `flutter build web --dart-define-from-file=dart_defines.json` succeeds. Local dev/testing used port 5050 (fallback) rather than the registered port 5000, which remains occupied on this machine by macOS's AirPlay Receiver per Story 3.1's precedent — real Google OAuth on port 5050 is outside Supabase's Redirect URLs allow-list, so the operator drove the actual sign-in step manually while port 5000 stays blocked locally; this doesn't affect the fix itself, which was confirmed against the real production bundle.

### Completion Notes List

- **Task 1:** `GigsService.bookGig` (`lib/services/gigs_service.dart`) implements the client's two-step contract exactly: a standalone `booking_bids` insert (its own statement, not wrapped with the RPC call) immediately followed by `book_request`, returning the RPC's boolean directly. `GigsScreen._bookGig` branches only on that return value — `won == true` navigates to the confirmation route; `won == false` drives Task 4's in-place treatment; an exception from the insert (or the RPC) shows the generic `"We couldn't reach the server — try again."` banner without any further action, since the insert throwing prevents the RPC line from ever executing.
- **Task 2:** `GigsScreen` (`lib/screens/gigs_screen.dart`) hydrates via an explicit-column, `status = 'unbooked'`-filtered SELECT, then subscribes one realtime channel (`GigsService.subscribe`) to INSERT + UPDATE on `relocation_requests` (no DELETE handler — the schema never hard-deletes). The callback branches purely on the incoming row's `status`: `unbooked` upserts into the local list (covers a new dispatcher-created gig and Story 1.4's revert-to-unbooked path), anything else removes it (covers this driver's own winning booking going live). `GigCard`/`GigCardSkeleton` (`lib/widgets/gig_card.dart`) render the Card-shaped skeleton, the origin→destination/date/notes card with the single "Book this gig" action, and the zero-state text with no CTA.
- **Task 3:** `BookingConfirmationScreen` (`lib/screens/booking_confirmation_screen.dart`) is a top-level `GoRoute` (`/booking-confirmation`) declared as a sibling of, not nested inside, the `StatefulShellRoute` — so it renders outside `AppShell` and the tab bar is hidden for free. Reuses `RaisedSurface`/`FocusRing`/`FloviTokens` status-completed colors from Story 3.1; heading is the verbatim `"You're booked."` copy and the button is `"View my booked gigs"` per EXPERIENCE.md's Flow 2. Entrance fades in via `AnimatedOpacity` gated on `MediaQuery.of(context).disableAnimations` (Flutter web's wiring of `prefers-reduced-motion`), collapsing to `Duration.zero` under that preference.
- **Task 4:** `GigCardStatus.unavailable` swaps the Book button for `"No longer available"` inside a `Semantics(liveRegion: true, ...)` wrapper so it's announced the moment it appears, not just shown. After a 2-second `Future.delayed`, the card fades out via the same reduced-motion-aware `AnimatedOpacity` pattern as Task 3's entrance, finalizing removal from the list in `onEnd`.
- All 6 tasks complete; all 6 ACs implemented and verified live against the real Supabase project and a genuine production `flutter build web` bundle, including a full winning-booking flow with the operator's own real account and a live, code-level-verified re-confirmation of the concurrent-tiebreak mechanism via direct DB testing. The race-lost ("No longer available") path (AC #6) was verified by code review and the underlying RPC-level loser-branch behavior (confirmed live in the DB test's loser call), but not re-driven through the live UI with a second real concurrent driver in this session — flagging this the same way Story 3.1 flagged its own unverified-live gaps, rather than silently assuming full UI coverage.

### File List

- `flovi/apps/driver-mobile/lib/main.dart` (modified — `GoRouter` built once as a static field instead of inline in `build()`)
- `flovi/apps/driver-mobile/lib/router/app_router.dart` (modified — added `/booking-confirmation` top-level route; `_GoRouterRefreshStream` now only notifies on an actual signed-in/signed-out transition)
- `flovi/apps/driver-mobile/lib/services/gigs_service.dart` (new — `Gig` model, hydration, realtime subscription, two-step booking sequence)
- `flovi/apps/driver-mobile/lib/screens/gigs_screen.dart` (rewritten — skeleton/card/zero-state/realtime list, booking dispatch, race-lost handling)
- `flovi/apps/driver-mobile/lib/screens/booking_confirmation_screen.dart` (new — full-screen booking confirmation interstitial)
- `flovi/apps/driver-mobile/lib/widgets/gig_card.dart` (new — `GigCard`, `GigCardStatus`, `GigCardSkeleton`)

## Change Log

- 2026-07-09 — Implemented Story 3.2 in full: the two-step booking sequence (`GigsService.bookGig`), the Gigs browse list (skeleton/card/zero-state/realtime), the full-screen booking-confirmation interstitial, and the race-lost "No longer available" treatment. All 4 tasks complete; all 6 ACs implemented. Verified live against the real Supabase project: the concurrent-tiebreak mechanism via a temporary direct-DB test (two simulated drivers, exact client call sequence, correct winner/loser/cleanup), and a full real-account booking flow through the browser (Gigs → book → confirmation → Booked). Found and fixed a genuine `go_router` bug during verification — a background auth-stream event (token refresh) was silently dropping the pushed confirmation route back to `/gigs`; fixed by switching that navigation to `context.go()` and by making the router's auth-stream listener only refresh on real sign-in/out transitions, both confirmed against a real production `flutter build web` bundle, not just dev mode. Status → review.
