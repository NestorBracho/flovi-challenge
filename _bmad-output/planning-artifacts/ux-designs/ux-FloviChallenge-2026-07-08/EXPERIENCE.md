---
name: Flovi
status: final
sources:
  - ../../../specs/spec-relocation-dispatch/SPEC.md
  - ../../../specs/spec-relocation-dispatch/state-machines.md
  - ../../../specs/spec-relocation-dispatch/stack.md
updated: 2026-07-08
---

# Flovi — Experience Spine

> Paired with `DESIGN.md` (visual identity). This spine owns behavior, IA, states, and flows. Both files win on conflict with any mock, wireframe, or import. Capability IDs (CAP-N) mirror `SPEC.md` verbatim.

## Foundation

Two surfaces, one backend (Supabase, per `stack.md`): a **dispatcher web app** (desktop-first, hard floor at 1024px — below that, a "best viewed on a larger screen" notice, no responsive reflow attempted; no named UI system, custom Tailwind build against `DESIGN.md` tokens) and a **driver mobile app** (Flutter, phone-width single column). `DESIGN.md` is the shared visual identity reference for both.

`[ASSUMPTION]` The driver app is demoed via a Flutter **web build** (per `stack.md`'s hosting decision), so its layout is touch-first but must remain fully operable with a mouse pointer in a desktop browser window sized to a phone viewport. Flutter web renders to a fixed layout canvas that does not reflow with OS-level dynamic type — browser zoom is the supported text-scaling path; OS dynamic type is not respected. This is a stated trade-off, not a silent gap.

`[ASSUMPTION]` Light mode only — dark mode isn't requested anywhere in the source material.

## Information Architecture

**Dispatcher web**

| Surface | Reached from | Purpose |
| --- | --- | --- |
| Login | Cold open, unauthenticated | Google OAuth sign-in; signup here persists role=dispatcher (CAP-1) |
| Requests | Post-login default | List all requests with status, stat tiles, search, filter chips (CAP-3); create (CAP-2), edit (CAP-4), and cancel (CAP-10) all originate here |
| Notifications | Sidebar nav item | Feed of driver-cancellation → auto-reassignment events (CAP-13) |
| Account (sidebar footer) | Avatar/name in sidebar | `[ASSUMPTION]` Signed-in identity + sign out — minimal, not a designed settings area |

**Driver mobile**

| Surface | Reached from | Purpose |
| --- | --- | --- |
| Login | Cold open, unauthenticated | Google OAuth sign-in; signup here persists role=driver (CAP-5) |
| Gigs | Post-login default, tab bar | List unbooked gigs (CAP-6); tap to book (CAP-7); updates live as dispatchers create requests (CAP-9) |
| Booking confirmation | After "Book this gig" | Full-screen interstitial confirming the booking |
| Booked | Tab bar | View booked gigs (CAP-8); cancel with ≥24h notice (CAP-11); mark complete (CAP-14) |
| Profile | Tab bar | `[ASSUMPTION]` Signed-in identity + sign out — minimal, not a designed settings area |

`[NOTE]` The explored direction mock also showed dispatcher-side "Drivers" and "Settings" nav items. Neither is backed by a SPEC capability (no driver-roster or settings capability exists) — both are dropped from this IA rather than carried forward as invented scope. Flag if you actually want a driver-roster view; that would be a new capability, not a UX-only addition.

→ Composition reference: `mockups/direction-warm-approachable.html` — depicts the dispatcher Requests list (stat tiles, filter chips, request cards across all 4 statuses), the New/Edit Request modal, an empty-state (search-zero-results) panel, the driver Gigs browse screen, and the driver booking-confirmation interstitial. Spine wins on conflict.

## Voice and Tone

Microcopy only — brand voice lives in `DESIGN.md.Brand & Style`.

| Do | Don't |
| --- | --- |
| "Book this gig." | "Snag this gig now! 🎉" |
| "You're booked." | "Woohoo, you got it!" |
| "We couldn't reach the server — try again." | "Oops! Something went wrong :(" |
| "No requests match 'Providence, RI'." | "Nothing found lol" |
| Plain, complete sentences, no exclamation marks | Streak/urgency language ("Hurry, only 1 left!") |

## Component Patterns

Behavioral. Visual specs live in `DESIGN.md.Components`.

| Component | Use | Behavioral rules |
| --- | --- | --- |
| Request card | Dispatcher Requests | Click "Edit" opens the edit modal prefilled (CAP-4). Click "Cancel" (available regardless of current status, any time) sets the request to `cancelled` after a lightweight inline confirm — no separate confirmation modal (CAP-10). |
| Status pill | Both apps, anywhere a request/gig appears | Reflects the 4-state lifecycle (`state-machines.md`); never the only cue — dot + text + tint always together. |
| Stat tile | Dispatcher Requests | Static count display only, not clickable — does not double as a filter (that's Filter chip's job). |
| Modal — New/Edit Request | Dispatcher | Same modal for create and edit; create starts blank with focus on the Origin field on open, edit prefills with focus on the modal heading. Closes on Save, Cancel, overlay click, or Escape (focus returns to the triggering element). Required-field validation on Save: invalid fields show inline error text directly under the field (non-color icon + text, not color-only), focus moves to the first invalid field, and the modal stays open. |
| Filter chip | Dispatcher Requests | Native `<button>` elements, single-select; "All requests" is default-active; switching chips re-filters the list in place, no navigation. |
| Gig card | Driver Gigs | One primary action only: "Book this gig." No secondary actions on the browse card itself. |
| Booking confirmation | Driver, post-book | Full-screen interstitial (never a modal/toast) — one-tap booking deserves an unambiguous, undismissable-by-accident confirmation. |
| Booked-gig row | Driver Booked | Shows "Cancel" only when ≥24h remains before the scheduled date (CAP-11); shows a muted, non-interactive explanation ("Too close to the ride to cancel") otherwise. "Mark complete" (CAP-14) is available any time the gig is `booked`; tapping it removes the row from Booked and is the action that increments this driver's completed-rides count. |
| Notification item | Dispatcher Notifications | Plain text row, no status pill (see `DESIGN.md`) — one line: which request, that a driver cancelled, who was auto-reassigned (or "returned to available pool" if nobody was eligible). |
| Search box | Dispatcher Requests | Live-filters the visible list, no submit step; the result count updates in an `aria-live="polite"` region so the change is announced, not just visually rendered. |
| Tab bar | Driver, all 3 driver surfaces | Exactly 3 tabs (Gigs / Booked / Profile); always visible except during the booking-confirmation interstitial. |
| Empty-state panel | Any list with zero/filtered-zero results | Dashed border, icon circle, one ghost-button recovery action (e.g. "Clear filters"). |

## State Patterns

| State | Surface | Treatment |
| --- | --- | --- |
| Cold load | Requests, Gigs, Booked | Skeleton row placeholders (shape of a Card, no content) while data resolves; identical treatment across all three list surfaces. |
| Cold open, unauthenticated | Login (both apps) | Google OAuth button, one line explaining what signing up here does ("Sign up here as a dispatcher/driver"). |
| OAuth failure | Login (both apps) | "We couldn't sign you in — try again." Non-blocking, stays on Login. Distinct from the generic post-auth network banner. |
| Empty — no requests yet | Requests | "No relocation requests yet." + primary "+ New request" CTA. |
| Empty — filtered to zero | Requests | Dashed empty-state panel: "No requests match '{filter}'." + "Clear filters." |
| Empty — no gigs available | Gigs | "No gigs available right now — check back soon." No CTA (nothing to do). |
| Empty — no booked gigs | Booked | "You haven't booked anything yet." + link back to Gigs. |
| Empty — no notifications yet | Notifications | "Nothing here yet — you'll see an update if a driver ever cancels with reassignment." |
| Modal validation error | Modal — New/Edit Request | Inline error text under each invalid field (icon + text, not color-only); focus moves to first invalid field; modal stays open. |
| Booking race lost | Gigs | Gig card shows "No longer available" in place of the Book button for ~2s (announced via `aria-live="polite"` so screen-reader users learn the attempt failed, not just sighted users), then the card is removed from the list. |
| Cancellation blocked (<24h) | Booked | Cancel control renders disabled/muted with adjacent text: "Too close to the ride to cancel (within 24h)." (CAP-11) |
| Mark-complete result | Booked | Row is removed from Booked immediately on tap; no separate confirmation screen (the action itself is low-stakes and reversible only in the sense that it's just a status update). |
| Cancelled by dispatcher | Requests, Gigs, Booked | Request moves to `cancelled` and disappears from any driver-facing view (Gigs if still unbooked, Booked if it had a driver) instantly via realtime sync (CAP-10, CAP-9). |
| Driver-cancel → reassignment | Requests, Notifications | Status pill briefly shows `unbooked` then updates to `booked` (new driver name) without reload; a new item appears in Notifications (CAP-12, CAP-13). |
| Network/sync error | Either app, post-auth | Non-blocking. A single dismissible banner: "We couldn't reach the server — try again." Never blocks viewing already-loaded data. |

## Interaction Primitives

- Tap/click to act — no drag, no swipe gestures, no long-press.
- Modal (dispatcher only): dismiss via Save, Cancel, overlay click, or Escape; traps focus while open. Never used on driver mobile — full-screen interstitials instead.
- Filter chips: native buttons, single-select, click/tap to switch, no multi-select.
- Search box: live-filters the visible list; no submit step; result-count change is announced via `aria-live`.
- Tab bar (driver): exactly 3 tabs (Gigs / Booked / Profile), always visible except during the booking-confirmation interstitial.
- All transient motion (status-pill flash, interstitial entrance, race-lost card removal) reduces to instant/opacity-only when `prefers-reduced-motion` is set.
- **Banned:** carousels, swipe-to-delete, hero animations on cold open, badge-count gamification beyond the functional Notifications counter.

## Accessibility Floor

Behavioral. Visual contrast lives in `DESIGN.md` (status-pill text variants and body text colors are contrast-checked to clear WCAG AA at their actual rendered sizes).

- Status is never color-only: pill = dot + text + background tint, always together (serves colorblind users), on both apps and in any future Notifications pill (see `DESIGN.md` — Notifications currently render as plain text, no pill, so this doesn't apply there yet).
- Visible focus ring (`DESIGN.md.components.focus-ring`) on every interactive element — buttons, chips, inputs, the modal ✕, sidebar nav items, tab bar icons — not just the modal.
- Modal traps focus while open; focus lands on the first field on open (create) or the modal heading (edit); Escape closes; focus returns to the triggering element on close.
- Required-field validation on the New/Edit Request modal: inline error text under the field (icon + text, never color-only), `aria-describedby` linking the field to its error, focus moves to the first invalid field on a failed save.
- Tap targets ≥ 44×44px on driver mobile; ≥ 32px hit area on dispatcher web controls.
- All icon-only affordances (chevrons, the modal ✕, tab bar icons) carry an accessible label.
- Status changes arriving via realtime sync are announced to screen readers via `aria-live="polite"` regions on **both** apps — a dispatcher shouldn't need to be looking at the screen to learn a request just got booked, and a driver shouldn't need to be looking at the screen to learn they lost a booking race (the card swap/removal in "Booking race lost" is announced, not silent).
- Search result-count changes are announced via `aria-live="polite"`.
- `prefers-reduced-motion` honored: transitions/animations reduce to instant or opacity-only.
- Text scaling: browser zoom is the supported path on both apps; the Flutter web driver app does not respect OS-level dynamic type (stated limitation, not a silent gap — see Foundation).
- Dispatcher web: a skip-to-content affordance or `<main>`/`<nav>` landmark structure so keyboard users don't re-tab the sidebar on every navigation.

## Inspiration & Anti-patterns

- **Lifted from calm modern SaaS dashboards (Linear-adjacent):** card-list-over-data-table for the dispatcher Requests view — scannable without feeling like a spreadsheet.
- **Lifted from warm consumer marketplace apps:** the gig-card format on driver mobile — one clear photo-less card, one action, no clutter.
- **Rejected — dense ops/control-room register (the `operator-grade` direction):** too clinical for a product framed around "real people's moving days," per the chosen direction's own rationale.
- **Rejected — hyped gig-economy urgency language (the `bold-energetic` direction's register):** conflicts with the calm, trustworthy voice this product wants, especially on the dispatcher side.

## Key Flows

### Flow 1 — Dispatcher creates and edits a request (Elena, dispatcher, Monday morning)

1. Elena signs in with Google on the dispatcher web app; first-time sign-in here persists her as `role=dispatcher` (CAP-1).
2. She lands on Requests — 18 requests, stat tiles show 6 unbooked (CAP-3).
3. She clicks "+ New request," fills origin ("Fremont, Seattle"), destination ("Ballard, WA"), date, and a note about street parking, and saves (CAP-2).
4. The next morning she notices the note is incomplete — she clicks "Edit" on that same card, the modal reopens prefilled, she appends "no elevator" to the notes, and saves (CAP-4).
5. **Climax:** the request's card updates in place with the new notes text — no reload, no re-navigation, proof the edit landed.

Failure: a save with a blank Origin field shows an inline error under that field and keeps the modal open.

### Flow 2 — Driver browses and books a gig, live from the dispatcher's own action (Marcus, driver, between deliveries)

1. Marcus signs in with Google on the driver app; first-time sign-in here persists him as `role=driver` (CAP-5).
2. He lands on Gigs — 3 open near Seattle (CAP-6).
3. Moments later, a dispatcher (Elena, elsewhere) creates a new request — it appears live on Marcus's Gigs list without him refreshing or restarting the app (CAP-9, dispatcher→driver direction).
4. He taps "Book this gig" on that same new request (CAP-7).
5. **Climax:** a full-screen confirmation appears — "You're booked" — with the route, date, and notes restated, so there's no ambiguity about what he just committed to.
6. He taps "View my booked gigs" and sees it listed there (CAP-8).

Failure: if another driver's booking lands first, Marcus instead sees "No longer available" on that card (announced for screen readers, not just visual) within ~2 seconds and the card drops from his list — no confirmation screen, no false commitment. The winning driver is whoever has more completed rides.

### Flow 3 — Driver cancels with notice, dispatcher stays uninterrupted (Marcus cancels; Priya, a higher-priority driver, is auto-assigned; Elena is notified)

1. Marcus opens Booked and cancels a gig scheduled 3 days out — well past the 24h floor, so the Cancel action is active (CAP-11).
2. The system immediately looks for another eligible driver, ranked by completed-rides count, and finds Priya (CAP-12).
3. The gig reassigns to Priya — it now appears in her Booked list without her having browsed for it.
4. On Elena's dispatcher view, the request's status briefly reflects the reassignment and its driver name updates from Marcus to Priya — no page reload (CAP-9, driver→dispatcher direction).
5. **Climax:** a new item appears in Elena's Notifications feed: "Marcus cancelled a gig — automatically reassigned to Priya Nair." (CAP-13) Elena's day continues uninterrupted; she never had to manually re-dispatch anything.

Failure: if Marcus instead tries to cancel a gig scheduled in 10 hours, the Cancel control is disabled/muted with "Too close to the ride to cancel (within 24h)" — no cancellation, no reassignment.

Edge case: if no other driver is eligible, the request instead reverts to `unbooked` and reappears in the general Gigs pool — Elena's notification reads "returned to the available pool" instead of naming a new driver.

### Flow 4 — A ride finishes, and a different request is called off outright (Priya marks a gig complete; Elena cancels an unrelated request)

1. Priya finishes a relocation she booked earlier and opens Booked; the gig is still listed there.
2. She taps "Mark complete" (CAP-14). The row disappears from her Booked list immediately, and her completed-rides count increments by one — the same count that decided the race in Flow 2 and the reassignment in Flow 3.
3. Separately, Elena reviews her Requests list and finds one that the customer called off entirely — a request that's still `unbooked`, with no driver ever assigned.
4. She clicks "Cancel" on that card (CAP-10) — available regardless of the request's current status — and confirms inline.
5. **Climax:** the card's status pill updates to `cancelled` in place, and (had a driver already been assigned) it would simultaneously vanish from that driver's Gigs or Booked list via the same realtime channel — dispatcher-side cancellation reaches both apps exactly like every other status change.
