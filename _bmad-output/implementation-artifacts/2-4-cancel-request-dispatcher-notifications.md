---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 2.4: Cancel Request & Dispatcher Notifications

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in dispatcher,
I want to cancel a request regardless of its status, and get notified when a driver cancellation triggers a reassignment,
so that I can call off a request any time and stay informed without watching the app constantly.

## Acceptance Criteria

1. **Given** a signed-in dispatcher owns a request in any non-`cancelled` status, **when** they click "Cancel" on that Request card, **then** a lightweight inline confirm appears (no separate confirmation modal); confirming calls `cancel_request_dispatcher` and the card's Status pill updates to `cancelled` in place (CAP-10, UX-DR6).
2. **Given** a signed-in dispatcher opens Notifications, **when** the page loads, **then** it lists Notification items (plain text row, no status pill) — bold request route + plain-weight description of what happened + `text-secondary` timestamp, newest first (UX-DR11).
3. **Given** a signed-in dispatcher has zero notifications, **when** the Notifications view renders, **then** it shows "Nothing here yet — you'll see an update if a driver ever cancels with reassignment." (UX-DR12).
4. **Given** a driver cancellation on one of the dispatcher's requests triggers CAP-12's auto-reassignment (produced by Epic 3, but observable here via the `notifications` realtime subscription), **when** the resulting `notifications` row arrives, **then** a new item appears in the Notifications feed without a manual refresh, and the sidebar's unread-count badge increments (CAP-13, AD-5).
5. **Given** the dispatcher opens the Notifications page with unread items present, **when** the page is viewed, **then** the visible unread items are marked read (`read_at` set) and the sidebar badge count updates accordingly.

## Tasks / Subtasks

- [x] Task 1 — Inline cancel confirm, not a modal (AC: #1)
  - [x] "Cancel" on a Request card reveals a lightweight inline confirm **within the card itself** (e.g. the Cancel button toggles to a "Cancel this request? [Yes] [No]" affordance in place) — **do not reuse Story 2.3's `<dialog>`/`showModal()` pattern here**. That's a deliberately different, heavier UI pattern reserved for the New/Edit form; UX-DR6 is explicit this is a *lightweight inline* confirm, no separate confirmation modal.
  - [x] On confirm: `supabase.rpc('cancel_request_dispatcher', { p_request_id: requestId })` — parameter name is the fixed contract from Story 1.2, not `id` or `request_id`
  - [x] This RPC has no defined return payload (unlike `book_request`'s boolean win/lose) — on a call that doesn't throw, optimistically set that card's local `status` to `'cancelled'` directly (the client already knows the outcome; no need to wait for the realtime echo of this single-field change). On an unexpected exception, fall back to the generic network/sync error banner ("We couldn't reach the server — try again.") rather than a bespoke message — this path should essentially never fire in normal use, since the UI only ever shows Cancel on the dispatcher's own cards

- [x] Task 2 — Notifications list with the route join (AC: #2, #3)
  - [x] **This story does the join Story 1.4 deliberately deferred.** Story 1.4's `notifications.message` column holds only the plain-weight "what happened" sentence (e.g. *"Marcus cancelled a gig — automatically reassigned to Priya Nair."*) — the bold route prefix UX-DR11 calls for comes from joining back to the request. Use PostgREST's embedded-resource select to do it in one query: `.from('notifications').select('id, message, created_at, read_at, relocation_requests(origin, destination)').order('created_at', { ascending: false })`. This join is always permitted under the dispatcher's own RLS, since a notification's `dispatcher_id` and its underlying request's `created_by` are the same dispatcher by construction (Story 1.4's design).
  - [x] Render: **bold** `{origin} → {destination}` + plain-weight `message` + `text-secondary` timestamp, newest first, no status pill on the row itself (per DESIGN.md's Notification item recipe)
  - [x] Zero notifications: exact copy — `"Nothing here yet — you'll see an update if a driver ever cancels with reassignment."` (quoted identically in both epics.md and EXPERIENCE.md's State Patterns table — genuinely fixed, not paraphrased)

- [x] Task 3 — Lift the notifications subscription above the Notifications view (AC: #4)
  - [x] The sidebar's unread-count badge (built into Story 2.1's shell, but **not populated with a live count until now** — that behavior is this story's AC #4, not 2.1's) must update **even while the dispatcher is on the Requests view**, not just while the Notifications page happens to be mounted. This means the realtime subscription on `notifications` — and the unread-count state it drives — cannot live scoped to the Notifications view component; it needs to be established once at the app-shell / root layout level (alongside `useAuth`) and stay alive across navigation, with both the sidebar badge and the Notifications page reading from that same shared source rather than each maintaining their own separate subscription.
  - [x] On INSERT: prepend the new notification (after doing its own route-join fetch, or by re-querying) to the top of the list if the Notifications view happens to be open, and increment the badge count regardless of which view is currently active

- [x] Task 4 — Mark-as-read (AC: #5)
  - [x] Direct client-side UPDATE, not an RPC — Story 1.4 set this up in advance specifically for this story: `.from('notifications').update({ read_at: new Date().toISOString() }).is('read_at', null)` (RLS scopes it to the caller's own rows automatically; the column-level grant on `notifications` restricts this to touching only `read_at`, nothing else)
  - [x] Run this once when the Notifications page mounts, covering all currently-unread rows (no pagination exists in this app, so "visible" and "all unread" are the same set) — update the local badge count to match afterward

## Dev Notes

### Why the inline confirm can't just reuse Story 2.3's dialog
It would be the path of least resistance to wire "Cancel" to the same `<dialog>` component just built — resist that. UX-DR6/EXPERIENCE.md's Request card pattern is explicit that cancellation is a *lightweight inline* confirm, not a modal; these are two intentionally different interaction weights for two intentionally different levels of consequence (editing fields vs. a single confirm-or-not action).

### The route join is a debt this story is repaying, not a new decision
Flagging this again because it's easy to miss if this story is picked up without reading Story 1.4's own notes: that story's message template *deliberately* excludes the route, on the assumption that whichever story renders the Notifications feed would join back to get it. This is that story.

### The subscription-scoping mistake to avoid
It's tempting to build the notifications subscription entirely inside the Notifications view component, since that's the only place AC #2/#3/#5 are directly observed. But AC #4 requires the sidebar badge to increment *live*, and the sidebar is visible on every page, including Requests — so the subscription has to outlive any single view. This is the same category of mistake Story 2.2 warned against for its own realtime scope (don't build only what today's test exercises), applied one level higher in the component tree here.

### Testing standards summary
No automated test suite in scope. Manually verify: cancelling a `completed` request succeeds (CAP-10's "any status" rule, inherited unchanged from Story 1.2's RPC); the inline confirm never opens a `<dialog>`; a notification inserted directly via SQL (simulating Epic 3's not-yet-built trigger) appears live in the feed *and* increments the sidebar badge while sitting on the Requests view, not just while Notifications is open; opening Notifications clears the badge.

### Project Structure Notes
```
apps/dispatcher-web/src/
  composables/useNotifications.ts   # new — lifted to app-shell scope, not view-scoped
  components/
    RequestCard.vue      # extended — adds the inline cancel confirm (Edit was added in 2.3)
    NotificationItem.vue  # new
  views/Notifications.vue  # fleshed out from Story 2.1's shell-only placeholder
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 2.4: Cancel Request & Dispatcher Notifications]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — Notification item component]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — State Patterns (empty notifications, network error), Component Patterns (Request card cancel)]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — `cancel_request_dispatcher(p_request_id)` contract]
- [Source: _bmad-output/implementation-artifacts/1-4-driver-cancellation-24h-cutoff-auto-reassignment-notifications.md — message template split (route join deferred to this story), the forward-built `read_at` UPDATE grant]
- [Source: _bmad-output/implementation-artifacts/2-3-create-edit-request-via-modal.md — the `<dialog>` pattern this story deliberately does not reuse]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

None — no automated test suite in scope for this story. Verified manually against the live `flovi-challenge` Supabase project via the running dev server and the Supabase SQL Editor (see Completion Notes).

### Completion Notes List

- Task 1: Added inline cancel confirm state (`confirmingCancel`, `cancelling`, `cancelError`) to `RequestCard.vue`. The Cancel button toggles in place to "Cancel this request? No / Yes" — no `<dialog>` involved. Confirm calls `supabase.rpc('cancel_request_dispatcher', { p_request_id })`; on success emits `cancelled` with `{ ...request, status: 'cancelled' }`, which `RequestsView.vue` feeds into the existing `upsertLocal` from `useRequests` (same pattern already used for `RequestModal`'s `saved` event) — the subsequent realtime UPDATE echo is a no-op overwrite. On RPC error, shows the generic "We couldn't reach the server — try again." inline error text (styled like `LoginView`'s `authError`), matching EXPERIENCE.md's network/sync error copy.
- Task 2/3: Added `composables/useNotifications.ts` as a module-level singleton (same pattern as `useAuth.ts`) so the `notifications`/`unreadCount` state and the realtime channel are shared across the whole app rather than per-component. `init()` is guarded to run once and is triggered by calling `useNotifications()` from `AppShell.vue` (alongside `useAuth`), so the subscription starts once at the authenticated app-shell level and survives navigation between Requests and Notifications. Added `NotificationItem.vue` (bold route + plain message + `text-secondary` timestamp, no status pill) and fleshed out `NotificationsView.vue` (loading skeleton, exact-copy empty state via `EmptyStatePanel`, list). Extended `SidebarNavItem.vue` with an optional `badge` prop rendering a small accent pill next to the label; `AppShell.vue` passes `unreadCount` into the Notifications nav item.
- Task 4: `useNotifications.ts`'s `markAllRead()` runs the exact client-side UPDATE the story specifies (`.update({ read_at: ... }).is('read_at', null)`, RLS/column-grant scoped), called from `NotificationsView.vue`'s `onMounted`, and zeroes the shared `unreadCount` afterward so the sidebar badge clears immediately.
- Manual verification (per story Testing standards, done against the live Supabase project + `npm run dev`):
  - Created a fresh `unbooked` request, clicked Cancel → inline confirm appeared (no dialog) → Yes → card optimistically flipped to `Cancelled`, stat tiles updated.
  - Set a request to `completed` via SQL and cancelled it from the UI to confirm CAP-10's "any status" rule holds through the UI layer, not just the RPC.
  - Inserted a `notifications` row directly via SQL (simulating Epic 3's not-yet-built driver-cancellation trigger) while sitting on the Requests view — sidebar badge incremented to "1" live, with no manual refresh.
  - Navigated to Notifications — the row rendered per the exact recipe (bold route, plain message, secondary timestamp), the badge cleared, and confirmed in the DB that `read_at` was set.
  - Confirmed the zero-notifications empty state renders the exact required copy before any notification existed.
  - Cleaned up all test rows created during manual verification (test requests + test notification) after confirming.
  - `npm run build` passes with no errors.

### File List

- `flovi/apps/dispatcher-web/src/components/RequestCard.vue` (modified — inline cancel confirm)
- `flovi/apps/dispatcher-web/src/views/RequestsView.vue` (modified — wires `RequestCard`'s `cancelled` event to `upsertLocal`)
- `flovi/apps/dispatcher-web/src/composables/useNotifications.ts` (new — app-shell-scoped notifications state/subscription)
- `flovi/apps/dispatcher-web/src/components/AppShell.vue` (modified — establishes `useNotifications` at shell scope, passes badge count)
- `flovi/apps/dispatcher-web/src/components/SidebarNavItem.vue` (modified — optional unread-count `badge` prop)
- `flovi/apps/dispatcher-web/src/components/NotificationItem.vue` (new — notification row component)
- `flovi/apps/dispatcher-web/src/views/NotificationsView.vue` (modified — fleshed out from Story 2.1's placeholder)

## Change Log

- 2026-07-09: Implemented Story 2.4 — inline dispatcher cancel confirm on Request cards, app-shell-scoped notifications composable with realtime subscription and live sidebar unread badge, Notifications feed with the route join, and mark-as-read on view mount. Manually verified against the live Supabase project (all 5 ACs); no regressions to Stories 2.1–2.3 flows observed.
