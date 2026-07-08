# Story 2.2: Requests List with Realtime Sync, Search & Filter

Status: ready-for-dev

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

- [ ] Task 1 — `useRequests` composable: hydration + realtime (AC: #1, #8)
  - [ ] New `src/composables/useRequests.ts` (per source tree). Initial hydration: `.select('id, origin, destination, scheduled_date, notes, status, driver_id, created_at, updated_at')` — **name columns explicitly, do not use `select('*')`**. This isn't stylistic: Story 1.2 flagged in advance that Supabase's Column Level Security feature disallows the wildcard operator on a table that has any column-level privilege configured for the querying role, and Story 1.2 already put a column-level `REVOKE`/`GRANT` on this exact table (for `UPDATE`). Confirm behavior against the live project either way, but there's no reason to risk it when explicit columns cost nothing.
  - [ ] Realtime: one channel subscribed to Postgres Changes on `relocation_requests`, handling **all three** of INSERT/UPDATE/DELETE — even though this story's own AC #8 only exercises UPDATE (a driver books/reassigns/cancels elsewhere), Story 2.3's "new card appears in the list immediately" on create depends on this same subscription also handling INSERT. Build it complete now rather than UPDATE-only just because that's the only case this specific story's ACs exercise.
  - [ ] RLS (`dispatcher_own`, from Story 1.2) already scopes both the initial SELECT and the realtime stream to the signed-in dispatcher's own rows — no client-side `.eq('created_by', ...)` filter needed or wanted

- [ ] Task 2 — Request card, Status pill, skeleton loading (AC: #1, #2)
  - [ ] Status pill component (first built here — Story 2.1 only built the shell/login): full-rounded, solid dot using the `status-{state}` token, label text using `status-{state}-text`, background `status-{state}-tint` — three redundant cues per DESIGN.md, never color-only
  - [ ] Request card: origin, destination, scheduled date, notes, Status pill. **Edit and Cancel actions are explicitly out of scope for this story** — they're Story 2.3 (modal) and Story 2.4 (cancel) — don't build placeholder buttons with no-op handlers now; add them when those stories land
  - [ ] Skeleton rows: same Card shape, no content, shown only during the initial load — not re-shown on realtime updates to an already-loaded list

- [ ] Task 3 — Stat tiles, Filter chips, Search (AC: #3, #4, #5)
  - [ ] Stat tiles compute their counts from the **full unfiltered** local dataset, not whatever the search/filter currently narrows the visible list to — they're a stable overview, not a live reflection of the current view. Since they should derive from the same reactive list `useRequests` maintains, this falls out naturally as long as they're not accidentally computed from a filtered/derived array instead of the source list.
  - [ ] Filter chips: native `<button>` elements, single-select, "All requests" default-active. **Active-chip styling is a solid `text-primary` fill, not the accent color** — DESIGN.md is explicit that accent is reserved for calls-to-action, and a filter chip's active state deliberately avoids it (an easy default assumption to get backwards, since "active = accent color" is a common pattern elsewhere).
  - [ ] Search: client-side filtering against the already-loaded local list (origin/destination/notes text match) — no server round-trip per keystroke, this is demo-scale data. Live-filter, no submit step, result count announced via `aria-live="polite"`.

- [ ] Task 4 — Empty states (AC: #6, #7)
  - [ ] Zero requests at all: "No relocation requests yet." + primary "+ New request" CTA
  - [ ] Search/filter yields zero results: dashed-border empty-state panel. The exact message pattern is sourced from EXPERIENCE.md's Voice and Tone table, not paraphrased: `"No requests match '{search term}'."` (its literal worked example there is `"No requests match 'Providence, RI'."`) — interpolate the active search term (or the active filter chip's label if no search term is set and the filter alone produced zero results) + a "Clear filters" ghost-button recovery action

- [ ] Task 5 — Realtime announcement + reduced motion (AC: #8, #9)
  - [ ] Use **two separate** visually-hidden `aria-live="polite"` regions — one for search-result-count changes (AC #5/UX-DR21), one for realtime status-change announcements (AC #8/UX-DR22). Sharing a single region risks two unrelated announcements firing near-simultaneously and reading as one confusing jumble to a screen-reader user.
  - [ ] Status-pill "brief flash" on a realtime change: implement as a CSS transition; wrap it in `@media (prefers-reduced-motion: reduce)` so it collapses to an instant/opacity-only swap for users with that preference set, per UX-DR25

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

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
