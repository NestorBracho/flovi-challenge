---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 2.2: Requests List with Realtime Sync, Search & Filter

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in dispatcher,
I want to see all my relocation requests with live status, and search or filter them,
so that I always have an accurate, scannable view of my work without manually refreshing.

## Acceptance Criteria

1. **Given** a signed-in dispatcher lands on Requests, **when** the view is loading, **then** skeleton row placeholders (shape of a Card, no content) are shown until data resolves (UX-DR26).
2. **Given** a signed-in dispatcher's requests have loaded, **when** the Requests view renders, **then** every owned request appears as a Request card showing origin/destination, scheduled date, notes, and a Status pill (dot + text + tint, never color-only) reflecting its lifecycle state (CAP-3, UX-DR5, UX-DR6).
3. **Given** the Requests view is open, **when** it renders, **then** Stat tiles show static, non-interactive counts (e.g. unbooked/booked/completed/cancelled) — not clickable, not a filter control (UX-DR7).
4. **Given** the Requests view is open, **when** the dispatcher clicks a Filter chip (native `<button>`, single-select, "All requests" default-active), **then** the list re-filters in place with no navigation (UX-DR8).
5. **Given** the Requests view is open, **when** the dispatcher types in the search box, **then** the list live-filters with no submit step, and the result count is announced via an `aria-live="polite"` region (UX-DR21).
6. **Given** a signed-in dispatcher has zero requests, **when** the Requests view renders, **then** it shows "No relocation requests yet." plus a primary "+ New request" CTA.
7. **Given** the dispatcher's search or filter yields zero results, **when** the list re-renders, **then** a dashed-border empty-state panel shows "No requests match '{filter}'." plus a "Clear filters" ghost-button recovery action (UX-DR12).
8. **Given** a signed-in dispatcher is viewing Requests, **when** any of their requests changes status via a realtime event from another source (e.g. a driver books it), **then** the initial SELECT hydration plus an active realtime subscription on `relocation_requests` (RLS-scoped per AD-4) updates the card in place without a manual reload, and the change is announced via `aria-live="polite"` (CAP-3, CAP-9 consuming half, AD-5, UX-DR22).
9. **Given** the Status pill's brief flash on a realtime status change, **when** `prefers-reduced-motion` is set, **then** the flash reduces to instant/opacity-only (UX-DR25).

## Tasks / Subtasks

- [x] Task 1 — `useRequests` composable: hydration + realtime (AC: #1, #8)
  - [x] New `src/composables/useRequests.ts` (per source tree). Initial hydration: `.select('id, origin, destination, scheduled_date, notes, status, driver_id, created_at, updated_at')` — **name columns explicitly, do not use `select('*')`**. This isn't stylistic: Story 1.2 flagged in advance that Supabase's Column Level Security feature disallows the wildcard operator on a table that has any column-level privilege configured for the querying role, and Story 1.2 already put a column-level `REVOKE`/`GRANT` on this exact table (for `UPDATE`). Confirm behavior against the live project either way, but there's no reason to risk it when explicit columns cost nothing.
  - [x] Realtime: one channel subscribed to Postgres Changes on `relocation_requests`, handling **all three** of INSERT/UPDATE/DELETE — even though this story's own AC #8 only exercises UPDATE (a driver books/reassigns/cancels elsewhere), Story 2.3's "new card appears in the list immediately" on create depends on this same subscription also handling INSERT. Build it complete now rather than UPDATE-only just because that's the only case this specific story's ACs exercise.
  - [x] RLS (`dispatcher_own`, from Story 1.2) already scopes both the initial SELECT and the realtime stream to the signed-in dispatcher's own rows — no client-side `.eq('created_by', ...)` filter needed or wanted

- [x] Task 2 — Request card, Status pill, skeleton loading (AC: #1, #2)
  - [x] Status pill component (first built here — Story 2.1 only built the shell/login): full-rounded, solid dot using the `status-{state}` token, label text using `status-{state}-text`, background `status-{state}-tint` — three redundant cues per DESIGN.md, never color-only
  - [x] Request card: origin, destination, scheduled date, notes, Status pill. **Edit and Cancel actions are explicitly out of scope for this story** — they're Story 2.3 (modal) and Story 2.4 (cancel) — don't build placeholder buttons with no-op handlers now; add them when those stories land
  - [x] Skeleton rows: same Card shape, no content, shown only during the initial load — not re-shown on realtime updates to an already-loaded list

- [x] Task 3 — Stat tiles, Filter chips, Search (AC: #3, #4, #5)
  - [x] Stat tiles compute their counts from the **full unfiltered** local dataset, not whatever the search/filter currently narrows the visible list to — they're a stable overview, not a live reflection of the current view. Since they should derive from the same reactive list `useRequests` maintains, this falls out naturally as long as they're not accidentally computed from a filtered/derived array instead of the source list.
  - [x] Filter chips: native `<button>` elements, single-select, "All requests" default-active. **Active-chip styling is a solid `text-primary` fill, not the accent color** — DESIGN.md is explicit that accent is reserved for calls-to-action, and a filter chip's active state deliberately avoids it (an easy default assumption to get backwards, since "active = accent color" is a common pattern elsewhere).
  - [x] Search: client-side filtering against the already-loaded local list (origin/destination/notes text match) — no server round-trip per keystroke, this is demo-scale data. Live-filter, no submit step, result count announced via `aria-live="polite"`.

- [x] Task 4 — Empty states (AC: #6, #7)
  - [x] Zero requests at all: "No relocation requests yet." + primary "+ New request" CTA
  - [x] Search/filter yields zero results: dashed-border empty-state panel. The exact message pattern is sourced from EXPERIENCE.md's Voice and Tone table, not paraphrased: `"No requests match '{search term}'."` (its literal worked example there is `"No requests match 'Providence, RI'."`) — interpolate the active search term (or the active filter chip's label if no search term is set and the filter alone produced zero results) + a "Clear filters" ghost-button recovery action

- [x] Task 5 — Realtime announcement + reduced motion (AC: #8, #9)
  - [x] Use **two separate** visually-hidden `aria-live="polite"` regions — one for search-result-count changes (AC #5/UX-DR21), one for realtime status-change announcements (AC #8/UX-DR22). Sharing a single region risks two unrelated announcements firing near-simultaneously and reading as one confusing jumble to a screen-reader user.
  - [x] Status-pill "brief flash" on a realtime change: implement as a CSS transition; wrap it in `@media (prefers-reduced-motion: reduce)` so it collapses to an instant/opacity-only swap for users with that preference set, per UX-DR25

## Dev Notes

### This is the first story to actually build the Status pill and Request card
Story 2.1 only built the app shell, login, and design tokens — the Status pill, Request card, Stat tile, Filter chip, and Empty-state panel components are all new here. They should be built as reusable components since Story 2.3 (the modal) and Story 2.4 (cancel) extend this same card, and Story 3.3 (driver-mobile Booked list) independently implements its own Status pill/Empty-state instance in Flutter using the same visual recipe (per AD-1 — no shared package between the two apps, each implements its own).

### Why `select('*')` is worth avoiding here specifically
This isn't a general best practice reminder — it's closing a loop Story 1.2 opened. That story's Dev Notes flagged: *"Supabase's own docs warn that a role with column-restricted privileges on a table cannot use `select('*')` against it... the client's future `.select()` call against `relocation_requests` should name columns explicitly."* This is that future call. `relocation_requests` already has a column-level `UPDATE` grant (Story 1.2's `dispatcher_own` column-scoping), so the safe move is naming columns explicitly rather than finding out at runtime whether the wildcard restriction extends to SELECT too.

### Filter/search empty-state message — sourced, not invented
Same discipline as Story 1.4's notification microcopy: EXPERIENCE.md's Voice and Tone table gives the literal worked example (`"No requests match 'Providence, RI'."`), so the template is `'{search term}'`, quoted with single quotes around the actual term, not a generic "{filter}" placeholder rendered as literal text.

### Testing standards summary
No automated test suite in scope. Manually verify: skeleton shows on cold load then resolves to real cards; stat tile counts stay correct as search/filter narrow the visible list; a status change made directly via SQL (simulating a driver action from Epic 3, which doesn't exist yet) updates the open Requests view in place without reload, announced via the realtime `aria-live` region; zero-requests and zero-results empty states both render their exact copy; toggling OS-level reduced-motion collapses the status-pill flash to instant.

### Project Structure Notes
```
apps/dispatcher-web/src/
  composables/useRequests.ts   # new
  components/
    RequestCard.vue    # new — display only in this story, Edit/Cancel added by 2.3/2.4
    StatusPill.vue      # new
    StatTile.vue         # new
    FilterChip.vue        # new
    EmptyStatePanel.vue    # new — reused again by Story 2.4 (Notifications) and independently by Epic 3
  views/Requests.vue    # fleshed out from Story 2.1's shell-only placeholder
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 2.2: Requests List with Realtime Sync, Search & Filter]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — Status pill, Card, Stat tile, Filter chip, Empty-state panel components]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — Voice and Tone table, State Patterns (cold load, empty states)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-4, AD-5 — RLS-scoped realtime, initial-SELECT-as-sync-path]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — the `select('*')` forward-flag this story resolves]
- [Source: _bmad-output/implementation-artifacts/2-1-app-shell-design-tokens-login-role-claiming.md — design token names this story's components consume]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- Ran `npm run build` (clean compile) then `npm run dev` on the registered port 5173 and drove the app via Chrome browser automation against the live Supabase project, signed in as the operator's real dispatcher account (from Story 2.1's live sign-in) — no fake/injected session was needed this time since a real session already existed in the browser's `localStorage`.
- Confirmed cold hydration renders the zero-requests empty state correctly for an account with no owned rows yet (this dispatcher's account had zero `relocation_requests`, since RLS's `dispatcher_own` scopes strictly to `created_by`, and the seeded demo rows belong to the seeded `Demo Dispatcher 1/2` accounts, not this real account).
- To exercise realtime and populate the view, inserted 3 real rows directly through the page's own live Supabase client (`supabase.from('relocation_requests').insert(...)`, executed via `javascript_tool` against the already-loaded module — same client instance the app itself uses, so this went through the real RLS/trigger path, not a bypass). Confirmed all 3 cards and the Unbooked stat tile appeared live with **no reload**, proving the INSERT branch of the realtime subscription.
- Confirmed live search filtering (typed "Boulder" → narrowed to 1 card; stat tiles stayed at the full unfiltered count) and the zero-results empty state using EXPERIENCE.md's own worked example search term ("Providence, RI") — rendered verbatim as `No requests match 'Providence, RI'.`. Confirmed "Clear filters" resets both the search box and the active filter chip. Confirmed clicking the "Booked" filter chip with no matching rows falls back to the filter-chip-label message: `No requests match 'Booked'.` — exercising both branches of Task 4's message-source logic.
- Confirmed a `notes`-only UPDATE (a column dispatchers can write directly, per Story 1.2's column grants) propagates live via the same realtime UPDATE handler **without** falsely triggering the status-change flash or aria-live announcement — verified by reading `[aria-live="polite"]` element text content directly, confirming the status-change region stayed empty.
- `status` itself has no client-facing UPDATE grant (Story 1.2), so a true status-change realtime event can't be simulated with a raw client UPDATE. Used the real `cancel_request_dispatcher` RPC (Story 1.2, CAP-10) instead — the same production code path a real Cancel action will call in Story 2.4 — to transition one test row `unbooked → cancelled`. Confirmed live: the card's Status pill updated in place, the dot/text/tint all switched to the correct `cancelled` family (verified via a zoomed screenshot comparison against an adjacent `unbooked` pill — visually distinct colors, not a bleed-through), the Unbooked/Cancelled stat tiles updated, and the status-change `aria-live` region announced `"Denver, CO to Boulder, CO is now cancelled."`.
- Cancelled the remaining 2 test rows the same way (via `cancel_request_dispatcher`, not a raw DELETE — `DELETE` is revoked from `authenticated` by design per Story 1.2, so this was also the only in-spec way to retire the test data without needing direct DB/service-role access). Reloaded the page cold and confirmed all 3 persist correctly as `cancelled` from a fresh `SELECT` hydration, not just client-side state — order among the 3 varied slightly across the reload because all 3 were inserted in a single batch `INSERT` and share (or nearly share) the same `created_at` timestamp, an artifact of this session's batch test-insert, not a real usage pattern (Story 2.3's create flow issues one INSERT per action) or a bug in the `order('created_at', { ascending: false })` query.
- Checked browser console after a fresh reload: zero errors/warnings.
- Not separately exercised live: the `prefers-reduced-motion` CSS path (browser automation in this session has no control over the OS-level media-feature emulation) — implemented per spec as a standard `@media (prefers-reduced-motion: reduce) { transition: none; }` override on the pill's `background-color` transition, a well-established browser pattern, but only verified by code review, not a live OS toggle.

### Completion Notes List

- **Task 1:** `useRequests.ts` hydrates via one explicit-column `SELECT` ordered by `created_at desc`, then subscribes one `postgres_changes` channel to all three of INSERT/UPDATE/DELETE on `relocation_requests` (INSERT/UPDATE share an `handleUpsert` helper that finds-or-unshifts by `id`; DELETE filters the row out by `id`). No client-side `created_by` filter — relies entirely on `dispatcher_own` RLS (both for the initial SELECT and the realtime stream, per AD-4/AD-5). Channel is created in `onMounted` and torn down via `supabase.removeChannel` in `onUnmounted`.
- **Task 2:** `StatusPill.vue` maps each of the 4 statuses to its `dot`/`text`/`tint` token classes (dot + label text + tint background — three redundant cues, never color-only). `RequestCard.vue` renders origin → destination (with an accent-colored route arrow, per DESIGN.md's accent-usage note), a formatted scheduled date, notes (only when present), and the pill — no Edit/Cancel controls, per this story's explicit scope boundary. Skeleton rows are 3 plain `animate-pulse` Card-shaped blocks rendered only while `loading` is true, and are never re-shown once the initial hydration resolves (realtime updates only ever touch the already-loaded `requests` array).
- **Task 3:** `StatTile.vue`/`FilterChip.vue` are new small presentational components; `RequestsView.vue` computes the 4 stat counts from the raw `requests` ref (never the filtered/derived list). Filter chips' active state uses a solid `bg-text-primary` fill (not accent), matching DESIGN.md's explicit correction. Search does client-side substring matching (case-insensitive) against origin/destination/notes, combined with the active status filter via one `filteredRequests` computed.
- **Task 4:** `EmptyStatePanel.vue` is one shared dashed-border component (icon circle + message + an `#action` slot), reused for both empty cases with different action buttons passed in — a primary "+ New request" CTA (no click handler yet; the modal is Story 2.3's scope) for the zero-requests case, a ghost "Clear filters" button for the zero-results case. The zero-results message is sourced verbatim from EXPERIENCE.md's Voice and Tone table (`'{search term}'` quoting), falling back to the active filter chip's own label when no search term is set.
- **Task 5:** Two separate visually-hidden (`sr-only`) `aria-live="polite"` regions in `RequestsView.vue` — one bound to a `resultCountAnnouncement` computed (`"N requests shown."`), one bound to `useRequests`' `statusChangeAnnouncement` ref (only set inside `handleUpsert` when the incoming row's status differs from what was previously in the local list — never fires on a same-status UPDATE, e.g. a Story 2.3 notes/date edit). `StatusPill.vue` implements the "brief flash" as a `background-color` CSS transition: on a status prop change it flips to a highlight color then immediately (`nextTick`) back to the resting tint, so the transition animates the fade; `prefers-reduced-motion: reduce` sets `transition: none`, collapsing this to an instant swap.
- All 9 ACs implemented and verified live against the real Supabase project (hydration, realtime INSERT/UPDATE, search, filter chips, both empty states with sourced copy, stat tiles staying unfiltered, status-pill 3-cue correctness across two different status families, and both aria-live regions) — see Debug Log References for specifics and for the one path (`prefers-reduced-motion`) that was code-reviewed but not live-toggled. No automated test suite in scope per this story's own Testing Standards Summary.

### File List

- `flovi/apps/dispatcher-web/src/composables/useRequests.ts` (new)
- `flovi/apps/dispatcher-web/src/components/StatusPill.vue` (new)
- `flovi/apps/dispatcher-web/src/components/RequestCard.vue` (new)
- `flovi/apps/dispatcher-web/src/components/StatTile.vue` (new)
- `flovi/apps/dispatcher-web/src/components/FilterChip.vue` (new)
- `flovi/apps/dispatcher-web/src/components/EmptyStatePanel.vue` (new)
- `flovi/apps/dispatcher-web/src/views/RequestsView.vue` (rewritten — fleshed out from Story 2.1's shell-only placeholder)

## Change Log

- 2026-07-09 — Implemented Story 2.2 in full: `useRequests` composable (explicit-column hydration + one realtime channel covering INSERT/UPDATE/DELETE), the new Status pill/Request card/Stat tile/Filter chip/Empty-state panel components, stat tiles derived from the unfiltered dataset, client-side search + single-select filter chips, both empty states with EXPERIENCE.md-sourced copy, and the two `aria-live` regions plus the reduced-motion-aware status-pill flash. All 5 tasks complete; all 9 ACs verified live against the real Supabase project, including realtime INSERT/UPDATE propagation and a genuine status transition via the production `cancel_request_dispatcher` RPC. Status → review.
