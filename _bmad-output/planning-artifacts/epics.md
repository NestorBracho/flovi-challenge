---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/specs/spec-relocation-dispatch/SPEC.md
  - _bmad-output/specs/spec-relocation-dispatch/stack.md
  - _bmad-output/specs/spec-relocation-dispatch/state-machines.md
  - _bmad-output/specs/spec-relocation-dispatch/challenge-context.md
  - _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md
---

# Flovi Relocation-Dispatch - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Flovi relocation-dispatch demo, decomposing SPEC.md's 14 capabilities (CAP-1 through CAP-14, standing in for a PRD's FR list), the Constraints-derived NFR-equivalents, the ARCHITECTURE-SPINE.md invariants (AD-1 through AD-7), and the DESIGN.md/EXPERIENCE.md UX contract into implementable stories for a solo, AI-generated-code-only build against a 4-hour hard cap.

## Requirements Inventory

### Functional Requirements

*(Source: SPEC.md Capabilities. CAP-N numbering is preserved verbatim rather than renumbered to FR-N, since the architecture spine and UX spine both cite CAP-N directly — renumbering would break traceability.)*

- **CAP-1**: Dispatcher signs in via Google OAuth through the dispatcher web app; first sign-in persists the account with `role=dispatcher` and lands in the authenticated dispatcher dashboard.
- **CAP-2**: Signed-in dispatcher creates a new relocation request (origin, destination, date, notes); submitting persists it in `unbooked` state, visible in the list immediately.
- **CAP-3**: Signed-in dispatcher views all their relocation requests with a status badge per request, reflecting lifecycle state and updating without manual reload.
- **CAP-4**: Signed-in dispatcher edits fields of an existing relocation request; saving persists the change and shows it in the list immediately.
- **CAP-5**: Driver signs in via Google OAuth through the driver mobile app; first sign-in persists the account with `role=driver` and lands on the available-gigs screen.
- **CAP-6**: Signed-in driver browses relocation gigs in `unbooked` state; a newly created dispatcher request appears without an app restart.
- **CAP-7**: Signed-in driver books an available gig in one tap and receives confirmation; on concurrent booking attempts, the driver with more completed rides wins, the other sees it as no longer available (priority rule shared with CAP-12).
- **CAP-8**: Signed-in driver views only the gigs they have personally booked, with current status.
- **CAP-9**: Changes in either app (new request, edit, booking, cancellation, reassignment) propagate to the other app within seconds, without manual refresh on either side.
- **CAP-10**: Signed-in dispatcher cancels an existing relocation request at any time regardless of current status; cancelling sets `cancelled`, removes it from driver views, and reflects immediately in the dispatcher's list.
- **CAP-11**: Signed-in driver cancels a booked gig only if ≥24h remain before the scheduled date; a within-24h attempt is blocked with a clear message; ≥24h cancellation releases the gig for automatic reassignment (CAP-12).
- **CAP-12**: When a driver cancels with valid notice, the system automatically re-books the gig to the eligible driver with the highest completed-rides count (excluding the canceller), or reverts to `unbooked` if none is available — same priority rule as CAP-7.
- **CAP-13**: Dispatcher is notified in-app, without manual refresh, when a driver cancellation and automatic reassignment occurs for one of their requests (reuses CAP-9's realtime channel).
- **CAP-14**: Signed-in driver marks a booked gig as `completed`; this increments that driver's completed-rides count (feeding the CAP-7/CAP-12 priority ranking) and removes it from active booked gigs.

### NonFunctional Requirements

*(Source: SPEC.md Constraints — this project has no separate NFR numbering, per bmad-spec convention; these are the NFR-equivalents.)*

- **NFR1**: Zero lines of hand-written code — every file must be AI-generated.
- **NFR2**: 4-hour hard cap from start to published URLs.
- **NFR3**: Both apps must be live and accessible on the internet, not just running locally.
- **NFR4**: Source lives in a publicly visible repository (GitHub/GitLab) with commit history showing the project's evolution.
- **NFR5**: Visual design must read as modern and polished, not a bare tutorial app.
- **NFR6**: A prompt log (written or recorded) must be produced, capturing key prompts, what came back, and what was changed and why.
- **NFR7**: Must be demoable end-to-end in a 5-minute walkthrough as if showing a real customer.
- **NFR8**: A written reflection is required — what worked, what broke, where AI got in the way.

**Non-goals (explicit, from SPEC.md — boundary-setting, not a source of stories):** app-store publishing/native binaries (a hosted Flutter web build or APK-run instructions satisfy the mobile deliverable); code quality/architecture elegance/test coverage are not evaluation targets; dispatcher manually assigning a request to a specific driver (drivers self-select; reassignment is system-automatic); payments/invoicing, driver ratings, in-app chat, multi-tenant/admin management.

### Additional Requirements

*(Source: ARCHITECTURE-SPINE.md. No starter/greenfield template is specified beyond the stack choice and source-tree layout below — Epic 1 Story 1 should scaffold the monorepo directly, not pull an external starter.)*

- **AD-1** — No custom backend service exists; both apps are presentation-only, calling Supabase directly (`@supabase/supabase-js` / `supabase_flutter`) for Auth, RPCs, and Realtime. Any rule shared across both apps lives exactly once, in Postgres.
- **AD-2** — `claim_role` is the single, fixed `SECURITY DEFINER` RPC for role assignment (dispatcher-web always calls `claim_role('dispatcher')`; driver-mobile always calls `claim_role('driver')`), immutable after first write; a mismatched re-claim raises an exception rather than flipping the role.
- **AD-3** — All state transitions go through four `SECURITY DEFINER` RPCs (`book_request`, `cancel_request_dispatcher`, `cancel_request_driver`, `complete_request`), each independently verifying caller role/ownership via `auth.uid()` as its first statement. `relocation_requests.status`/`.driver_id` carry no client-facing UPDATE grant; an INSERT trigger forces `status='unbooked'`, `driver_id=NULL` regardless of client input. `cancel_request_dispatcher` permits cancelling from any non-`cancelled` status (including `completed`), per CAP-10's "any time" wording.
- **AD-4** — RLS policies on `relocation_requests`/`notifications` are role-gated (not just predicate-gated) to prevent cross-role permissive-policy leakage: `dispatcher_own` (own rows only), `driver_visibility` (unbooked OR own). `profiles` has an open SELECT policy for authenticated users; only `role` and `completed_rides_count` are write-locked.
- **AD-5** — Both apps subscribe to Postgres Changes on exactly two tables (`relocation_requests`, `notifications`) using identical column names and the fixed four-value status enum. Each app performs one initial `SELECT` to hydrate on load/reconnect (not a polling fallback) — visibility on both the initial read and the realtime stream is governed by the same RLS policies (AD-4).
- **AD-6** — `book_request` resolves the CAP-7 tie-break via a short-lived `booking_bids` table + ~300ms bid window + `SELECT...FOR UPDATE`, assigning the highest-`completed_rides_count` bidder; every bidder's RPC return value tells the client whether it won (drives the "no longer available" UX). `cancel_request_driver`'s CAP-12 reassignment ranks the active driver pool (`profiles.is_active`) by `completed_rides_count DESC` in its own locked transaction, no bid window needed. `completed_rides_count` increments only inside `complete_request`.
- **AD-7** — The 24h-cutoff formula (`cutoff := scheduled_date @ 00:00 UTC − 24h`) is computed identically on both clients (instant UI feedback) and re-checked authoritatively server-side inside `cancel_request_driver`.
- **Infra/deployment** — Single Supabase project (Auth+Postgres+Realtime), no staging/prod split. One Google OAuth client with both apps' redirect URLs allow-listed. Both clients use `AuthFlowType.pkce` with a dedicated `/auth/callback` route (not the SPA root) — avoids Flutter web's default hash-router colliding with an implicit-flow OAuth redirect. Anon key is safe client-side (RLS-protected); service-role key is never used client-side. Hosting: Vercel for both the Vue build and the Flutter `build/web` static output.
- **Data setup** — Migrations for `profiles`, `relocation_requests`, `notifications`, `booking_bids`; `seed.sql` with demo dispatcher/driver accounts for the 4-hour-cap demo.
- **Source tree / repo shape** — One monorepo (`flovi/`), one public repo: `apps/dispatcher-web` (Vue 3 + Vite + Tailwind), `apps/driver-mobile` (Flutter 3), `supabase/{migrations, functions.sql, policies.sql, seed.sql}`. Neither app depends on the other, directly or via a private API.
- **Deferred (explicitly out of scope for epics/stories, per ARCHITECTURE-SPINE.md's own Deferred section)**: CI/CD automation, observability/logging/monitoring, multi-environment split, rate limiting/abuse protection on RPCs, automated test suite, OS-level push notifications, a driver active/inactive toggle UI, and the exact "mark notifications read" trigger mechanism (schema supports it; behavior is an implementation-time detail, not an architectural invariant).

### UX Design Requirements

*(Source: DESIGN.md + EXPERIENCE.md, the bmad-ux spine pair. Both are `status: final`, discovered as a matched pair — no conflicts, no partial-handoff gap.)*

**Design tokens & shared visual system:**
- **UX-DR1**: Implement the full color token set (surface-canvas/card/tint, border-subtle/hairline, text-primary/secondary/tertiary, accent + accent-tint, focus-ring, and the four status families — unbooked/booked/completed/cancelled — each with a full-saturation swatch, a darker `-text` variant, and a light `-tint`) consistently across both apps.
- **UX-DR2**: Implement the typography token set (display 24px/700, heading 18px/700, body 14px/500, body-strong 14px/700, meta 12.5px/600, label 11.5px/700 uppercase-tracked) on the system font stack — no custom typeface load.
- **UX-DR3**: Implement the spacing scale (4/8/12/16/20/24/32/40px) and rounded-corner scale (xs 10px / sm 12px / md 16px / lg 22px / full) per DESIGN.md.
- **UX-DR4**: Implement the two-level elevation system — flat (canvas, sidebar, tab bar, no shadow) and raised (cards, modals, phone frame; soft warm-toned shadow, never a hard drop shadow).

**Dispatcher web components:**
- **UX-DR5**: Build the Status pill component (dot + text + tint, three redundant cues, never color-only) shared across both apps for the 4-state lifecycle.
- **UX-DR6**: Build the Request card component — "Edit" opens the New/Edit modal prefilled (CAP-4); "Cancel" available regardless of current status via a lightweight inline confirm, no separate confirmation modal (CAP-10).
- **UX-DR7**: Build the Stat tile component — static count display only, non-interactive (no hover/press/focus state), not a filter control.
- **UX-DR8**: Build the Filter chip component — native `<button>` elements, single-select, "All requests" default-active, re-filters the list in place with no navigation.
- **UX-DR9**: Build the New/Edit Request modal — shared create/edit, 420px centered; create opens with focus on Origin, edit opens with focus on the modal heading; dismiss via Save/Cancel/overlay-click/Escape with focus returned to the triggering element; inline required-field validation (icon + text, `aria-describedby`, focus moves to first invalid field, modal stays open on error).
- **UX-DR10**: Build the Sidebar nav item component — 12px-rounded row, accent-tint background when active, label stays `text-primary` (never accent-colored), accent hue appears only as a small left-edge indicator + count badge.
- **UX-DR11**: Build the Notification item component — plain text row, no status pill; bold request route + plain-weight description of what happened + `text-secondary` timestamp.
- **UX-DR12**: Build the Empty-state panel component (dashed border, icon circle in `surface-tint`, single ghost-button recovery action), reused across all zero/filtered-zero list states.
- **UX-DR13**: Implement the dispatcher web desktop-first layout — fixed 220px sidebar + fluid main column, hard floor at 1024px; below that width, show a "best viewed on a larger screen" notice instead of attempting a responsive reflow.
- **UX-DR14**: Implement a skip-to-content affordance or `<main>`/`<nav>` landmark structure on dispatcher web so keyboard users don't re-tab the sidebar on every navigation.

**Driver mobile components:**
- **UX-DR15**: Build the Gig card component — one primary action only ("Book this gig"), no secondary actions on the browse card.
- **UX-DR16**: Build the Booking confirmation full-screen interstitial (never a modal) — check-icon in `status-completed-tint`/`status-completed`, heading, Card-styled route/date/notes summary, single full-width primary button through to Booked gigs.
- **UX-DR17**: Build the Booked-gig row component (inherits Card) — right-aligned action area shows "Cancel" (ghost, only when ≥24h remains) or a muted disabled explanation otherwise, plus "Mark complete" (ghost), both visible only while `booked`.
- **UX-DR18**: Build the driver Tab bar — exactly 3 tabs (Gigs / Booked / Profile), always visible except during the booking-confirmation interstitial.
- **UX-DR19**: Implement the driver mobile single-column layout (18-22px side margins, phone-width) operable via both touch and mouse pointer in a desktop-sized browser window (Flutter web demo constraint — `[ASSUMPTION]` per EXPERIENCE.md).

**Cross-cutting interaction & accessibility:**
- **UX-DR20**: Implement the universal 2px accent-colored focus ring (2px offset) on every interactive element in both apps (buttons, chips, inputs, modal ✕, sidebar nav items, tab bar icons) — must explicitly override Tailwind's default outline-strip.
- **UX-DR21**: Implement the dispatcher Requests search box — live-filter, no submit step, result-count changes announced via `aria-live="polite"`.
- **UX-DR22**: Implement `aria-live="polite"` announcements on both apps for realtime-arriving status changes (booked, reassigned, cancelled) so non-visual users learn of sync events without watching the screen.
- **UX-DR23**: Implement the "Booking race lost" treatment on driver Gigs — card shows "No longer available" (aria-live announced) for ~2s in place of the Book button, then is removed from the list.
- **UX-DR24**: Enforce tap-target minimums (≥44×44px driver mobile, ≥32px dispatcher web controls) and accessible labels on every icon-only affordance (chevrons, modal ✕, tab bar icons).
- **UX-DR25**: Honor `prefers-reduced-motion` — all transient motion (status-pill flash, interstitial entrance, race-lost card removal) reduces to instant/opacity-only.
- **UX-DR26**: Implement skeleton-row loading states (shape of a Card, no content) identically across the Requests, Gigs, and Booked list surfaces during cold load.
- **UX-DR27**: Implement the fixed microcopy for every named state verbatim per EXPERIENCE.md's State Patterns and Voice/Tone tables (OAuth failure; 5 distinct empty-states; modal validation error; booking race lost; cancellation blocked <24h; mark-complete result; cancelled-by-dispatcher; driver-cancel→reassignment; network/sync error banner) — plain complete sentences, no exclamation marks, no urgency language.
- **UX-DR28**: Light mode only — no dark mode implementation (explicit `[ASSUMPTION]`, not a gap).

### FR Coverage Map

*(Cross-cutting NFRs threaded through every story, not epic-specific: NFR1 — zero hand-written code; NFR2 — 4-hour project timebox; NFR5 — visual polish, governed by the UX-DR components each app epic builds.)*

| Requirement | Epic | Notes |
| --- | --- | --- |
| CAP-1 | Epic 2 | Dispatcher OAuth + role persistence |
| CAP-2 | Epic 2 | Create request |
| CAP-3 | Epic 2 | List + realtime status |
| CAP-4 | Epic 2 | Edit request |
| CAP-5 | Epic 3 | Driver OAuth + role persistence |
| CAP-6 | Epic 3 | Browse unbooked gigs + realtime |
| CAP-7 | Epic 3 | Book gig, priority tie-break (AD-6) |
| CAP-8 | Epic 3 | View booked gigs |
| CAP-9 | Epic 2 + Epic 3 | Dispatcher-consuming half (Epic 2) / driver-producing half (Epic 3); full loop verified in Epic 4 |
| CAP-10 | Epic 2 | Cancel request (any status) |
| CAP-11 | Epic 3 | Cancel with 24h rule (AD-7) |
| CAP-12 | Epic 3 | Auto-reassignment (AD-6) |
| CAP-13 | Epic 2 + Epic 3 | Display half (Epic 2) / trigger half (Epic 3); full loop verified in Epic 4 |
| CAP-14 | Epic 3 | Mark complete, increments priority count |
| AD-1 – AD-7 | Epic 1 | Backend contract implementing all shared invariants |
| NFR3 (live on internet) | Epic 2 + Epic 3 | Each app's own final deploy story |
| NFR4 (public repo, commit history) | Epic 1 → Epic 4 | Continuous from first commit; confirmed at Epic 4 |
| NFR6 (prompt log) | Epic 4 | |
| NFR7 (5-min demoable) | Epic 4 | Cross-app end-to-end verification |
| NFR8 (written reflection) | Epic 4 | |
| UX-DR1-4 (design tokens) | Epic 2 + Epic 3 | Each app implements its own token system independently — no shared package between apps (per AD-1) |
| UX-DR5 (status pill) | Epic 2 + Epic 3 | Independently implemented in both apps' own stack — shown on the dispatcher Request card and the driver Booked-gig row |
| UX-DR6-11, UX-DR13-14 (dispatcher-only components/a11y) | Epic 2 | |
| UX-DR12 (empty-state panel) | Epic 2 + Epic 3 | Independently implemented in both apps — dispatcher zero-requests/filtered-zero, driver zero-booked-gigs |
| UX-DR15-19 (driver components) | Epic 3 | |
| UX-DR20-26, UX-DR28 (cross-cutting interaction/a11y) | Epic 2 + Epic 3 | Implemented independently in each app's own stack |
| UX-DR27 (fixed microcopy) | Epic 2 + Epic 3 | Per-surface, as each state is built |

## Epic List

### Epic 1: Shared Supabase Backend Contract
Stand up the single Postgres/Supabase backend — schema, RLS policies, the 5 SECURITY DEFINER RPCs, realtime-ready tables, and seed data — implementing AD-1 through AD-7 so every rule shared across both independently-built client apps (role assignment, the state machine, the completed-rides priority tie-break, auto-reassignment, the 24h-cutoff formula) exists exactly once and cannot diverge between clients. No CAP is demoable end-to-end from this epic alone (no client exists yet), but it enables all of CAP-1 through CAP-14. This epic intentionally trades away epic-level end-user value for architectural safety: AD-1 mandates that every cross-app rule live exactly once, in Postgres, rather than risk the independently-built Vue and Flutter clients silently diverging under the 4-hour, zero-hand-written-code constraint — building the shared contract first is a deliberate sequencing choice, not an oversight.
**Requirements covered:** AD-1, AD-2, AD-3, AD-4, AD-5, AD-6, AD-7 (enables CAP-1 – CAP-14)

### Epic 2: Dispatcher Web App (Vue)
A signed-in dispatcher can create, view, edit, and cancel relocation requests; see status update live as drivers act on them; and get notified in-app when a driver cancellation triggers automatic reassignment. Fully standalone and demoable against Epic 1's backend and seed data alone — does not require Epic 3 to exist or function.
**FRs covered:** CAP-1, CAP-2, CAP-3, CAP-4, CAP-9 (dispatcher-consuming half), CAP-10, CAP-13 (display half)
**Also covers:** NFR3 (own deploy story), UX-DR1-4 (own token implementation), UX-DR5-14, UX-DR20-28 (dispatcher-relevant cross-cutting items)

### Epic 3: Driver Mobile App (Flutter)
A signed-in driver can browse live available gigs, book one in one tap with the completed-rides priority tie-break, view their booked gigs, cancel with the 24h notice rule, trigger automatic reassignment to another driver, and mark a gig complete. Fully standalone and demoable against Epic 1's backend alone — does not require Epic 2 to exist or function.
**FRs covered:** CAP-5, CAP-6, CAP-7, CAP-8, CAP-9 (driver-producing half), CAP-11, CAP-12, CAP-13 (trigger half), CAP-14
**Also covers:** NFR3 (own deploy story), UX-DR1-4 (own token implementation), UX-DR5, UX-DR12 (own instances of status pill and empty-state panel), UX-DR15-19, UX-DR20-26, UX-DR28 (driver-relevant cross-cutting items)

### Epic 4: Cross-App Demo Readiness & Delivery
Verify the full two-way realtime loop (CAP-9, CAP-13) actually works end-to-end once both apps are live and deployed, and produce the delivery artifacts the challenge requires: a public repo with visible commit history, a prompt log, and a written reflection. Depends on Epic 1, Epic 2, and Epic 3 all being complete.
**Requirements covered:** NFR4, NFR6, NFR7, NFR8; verification of CAP-9 and CAP-13's cross-app behavior

---

## Epic 1: Shared Supabase Backend Contract

Stand up the single Postgres/Supabase backend — schema, RLS policies, the 5 SECURITY DEFINER RPCs, realtime-ready tables, and seed data — implementing AD-1 through AD-7 so every rule shared across both independently-built client apps exists exactly once and cannot diverge between clients.

### Story 1.1: Profiles Schema & Role-Claiming RPC

As a first-time sign-in user of either app,
I want my dispatcher/driver role permanently recorded the moment I authenticate,
So that the correct app experience is enforced from that point on and no one can hold or flip roles.

**Acceptance Criteria:**

**Given** no project scaffolding exists yet
**When** this story is complete
**Then** a monorepo exists at `flovi/` with `apps/dispatcher-web` (scaffolded via `npm create vite` + Vue 3 + Tailwind), `apps/driver-mobile` (scaffolded via `flutter create`), and `supabase/{migrations,functions.sql,policies.sql,seed.sql}` laid out per ARCHITECTURE-SPINE.md's Source Tree, committed to the public repo (NFR4)

**Given** the Supabase project has no `profiles` table yet
**When** this story is complete
**Then** a `profiles` table exists with columns `id (uuid PK, references auth.users)`, `role (text)`, `full_name (text)`, `completed_rides_count (int, default 0)`, `is_active (boolean, default true)`
**And** a `SECURITY DEFINER` RPC `claim_role(role text)` exists per AD-2

**Given** a user has no existing `profiles` row
**When** they call `claim_role('dispatcher')` or `claim_role('driver')`
**Then** a new `profiles` row is created with the requested role and `full_name` populated from the OAuth identity's `raw_user_meta_data` (Google `full_name`/`name` claim)

**Given** a user already has a `profiles` row with a role different from the one requested
**When** they call `claim_role` with the other role
**Then** the RPC raises an exception and no role change occurs — one person holds exactly one role, permanently

**Given** `profiles.role` has been set once
**When** any client attempts a direct UPDATE on the `role` column
**Then** the write is rejected — no client-facing UPDATE grant exists on that column

**Given** any authenticated user (either role)
**When** they SELECT from `profiles`
**Then** the read succeeds for all rows (open SELECT policy) — both apps need to resolve `id`/`role`/`full_name`/`completed_rides_count` for display

### Story 1.2: Relocation Request Schema, Dispatcher CRUD & Cancellation

As a signed-in dispatcher,
I want to create, view, edit, and cancel my own relocation requests at the database level,
So that the web app has a reliable, correctly-scoped backend to build against.

**Acceptance Criteria:**

**Given** no `relocation_requests` table exists yet
**When** this story is complete
**Then** a `relocation_requests` table exists with columns `id (uuid PK)`, `created_by (uuid FK profiles)`, `driver_id (uuid FK profiles, nullable)`, `origin (text)`, `destination (text)`, `scheduled_date (date)`, `notes (text)`, `status (text)`, `created_at (timestamptz)`, `updated_at (timestamptz)`
**And** an INSERT trigger forces `status = 'unbooked'` and `driver_id = NULL` regardless of client-supplied values, and defaults `created_by` server-side to `auth.uid()`

**Given** a signed-in dispatcher
**When** they INSERT a new relocation request (any origin/destination/date/notes, even with a status or driver_id attached)
**Then** it is created in `unbooked` status, owned by them, with `driver_id NULL` — the trigger overrides any client-supplied status/driver_id/created_by

**Given** a signed-in dispatcher who owns request R
**When** they SELECT or UPDATE non-status columns on R
**Then** RLS policy `dispatcher_own` permits it, gated on `role = 'dispatcher'` AND `created_by = auth.uid()`

**Given** a signed-in dispatcher who does not own request R
**When** they attempt to SELECT or UPDATE request R
**Then** RLS blocks it — no cross-dispatcher visibility or mutation (AD-4)

**Given** a signed-in dispatcher who owns request R in any non-`cancelled` status, including `completed`
**When** they call `cancel_request_dispatcher(R)`
**Then** the RPC verifies caller role is `dispatcher` and `created_by = auth.uid()`, then sets `status = 'cancelled'` — succeeds regardless of current status per CAP-10's "at any time" rule

**Given** a signed-in driver (not dispatcher), or a dispatcher who does not own R
**When** they call `cancel_request_dispatcher(R)`
**Then** the RPC raises an exception and no change occurs

### Story 1.3: Driver Visibility & Booking Priority Mechanic

As a signed-in driver,
I want to see only unbooked gigs (plus my own), and book one with a fair priority rule if others try at the same time,
So that the highest-priority driver reliably wins concurrent booking attempts.

**Acceptance Criteria:**

**Given** the `relocation_requests` table and RLS from Story 1.2 exist
**When** this story is complete
**Then** RLS policy `driver_visibility` permits a driver to SELECT rows where `role = 'driver'` AND (`status = 'unbooked'` OR `driver_id = auth.uid()`)

**Given** a signed-in driver
**When** they SELECT from `relocation_requests`
**Then** they see all `unbooked` requests plus any request currently assigned to them, and nothing else — no other driver's booked/completed/cancelled rows

**Given** no `booking_bids` table exists yet
**When** this story is complete
**Then** a `booking_bids` table exists (`id`, `request_id FK`, `driver_id FK`, `bid_at timestamptz`) and a `SECURITY DEFINER` RPC `book_request(request_id)` exists

**Given** a signed-in driver calls `book_request(R)` where R is `unbooked`
**When** the RPC runs
**Then** it (1) inserts a `booking_bids` row for the caller, (2) waits ~300ms for concurrent bids, (3) takes `SELECT ... FOR UPDATE` on R, (4) if R is still `unbooked`, assigns `driver_id`/`status='booked'` to whichever bidder in the window has the highest `completed_rides_count` (earliest `bid_at` breaks an exact tie), (5) returns to each caller whether they were the assigned winner

**Given** two drivers with different `completed_rides_count` call `book_request(R)` within the same ~300ms window
**When** the RPC resolves
**Then** the higher-`completed_rides_count` driver is assigned R and their call returns "won"; the other's call returns "did not win" and R is no longer `unbooked`

**Given** a signed-in driver calls `book_request(R)` where R is already `booked`, `completed`, or `cancelled`
**When** the RPC runs
**Then** it raises an exception / returns a not-available result, with no state change

**Given** a caller whose role is not `driver`
**When** they call `book_request(R)`
**Then** the RPC raises an exception

### Story 1.4: Driver Cancellation, 24h Cutoff, Auto-Reassignment & Notifications

As a signed-in driver,
I want to cancel a gig I've booked only with enough notice, and have it automatically reassigned so the dispatcher isn't left stuck,
So that late cancellations don't strand a scheduled ride and dispatchers learn about the change without doing anything.

**Acceptance Criteria:**

**Given** a signed-in driver owns booked request R with `now() < cutoff`, where `cutoff := (scheduled_date::timestamptz AT TIME ZONE 'UTC') - interval '24 hours'` (AD-7)
**When** they call `cancel_request_driver(R)`
**Then** the RPC verifies caller role `driver` and `driver_id = auth.uid()`, confirms `now() < cutoff`, ranks active drivers (`is_active = true`) by `completed_rides_count DESC` excluding the caller, and assigns R to the top-ranked driver if one exists (status stays `booked`, `driver_id` updated) — else sets `status = 'unbooked'`, `driver_id = NULL`

**Given** a signed-in driver owns booked request R with `now() >= cutoff`
**When** they call `cancel_request_driver(R)`
**Then** the RPC raises an exception / returns a blocked result, and R's status/driver_id are unchanged

**Given** a valid cancellation reassigns R to a new driver, or reverts it to `unbooked`
**When** the reassignment/revert completes
**Then** a `notifications` row is inserted with `request_id = R`, `dispatcher_id` = R's `created_by`, and a message identifying the request, that the original driver cancelled, and who was reassigned (or that it returned to the available pool if no eligible driver existed)

**Given** no `notifications` table exists yet
**When** this story is complete
**Then** a `notifications` table exists (`id`, `request_id FK`, `dispatcher_id FK`, `message text`, `created_at timestamptz`, `read_at timestamptz nullable`) with RLS scoping visibility to `dispatcher_id = auth.uid()`

**Given** a caller who is not R's assigned driver, or whose role is not `driver`
**When** they call `cancel_request_driver(R)`
**Then** the RPC raises an exception, with no state change

### Story 1.5: Ride Completion & Priority Count Increment

As a signed-in driver,
I want to mark a booked gig as completed,
So that the ride is closed out and my completed-rides count goes up for future priority ranking.

**Acceptance Criteria:**

**Given** a signed-in driver owns booked request R
**When** they call `complete_request(R)`
**Then** the RPC verifies caller role `driver` and `driver_id = auth.uid()`, sets `status = 'completed'`, and increments that driver's `profiles.completed_rides_count` by 1 inside the same transaction

**Given** a caller who is not R's assigned driver, or R is not currently `booked`
**When** they call `complete_request(R)`
**Then** the RPC raises an exception, with no state change and no increment

**Given** a driver has completed N rides via this RPC
**When** they are later evaluated in a `book_request` bid window (Story 1.3) or a `cancel_request_driver` reassignment (Story 1.4)
**Then** their updated `completed_rides_count` is what gets read — proving the count actually feeds the priority mechanic end-to-end

### Story 1.6: Realtime Publication, Seed Data & Auth Configuration

As the operator preparing both apps to build against a live backend,
I want realtime sync enabled on the right tables, demo accounts seeded, and Google OAuth configured for both apps,
So that Epic 2 and Epic 3 can start against a fully working, demoable backend from day one.

**Acceptance Criteria:**

**Given** the `relocation_requests` and `notifications` tables exist
**When** this story is complete
**Then** both tables are added to the Postgres Changes realtime publication, and no other tables are included (AD-5)

**Given** a fresh Supabase project
**When** `seed.sql` runs
**Then** demo `profiles` rows exist covering both roles (at least 2 dispatchers, 3+ drivers with varying `completed_rides_count` so the priority rule is demoable) plus a few seed `relocation_requests` across different statuses (unbooked/booked/completed) so Epic 2 can demo status-pill variety without Epic 3 existing yet

**Given** the Supabase Auth configuration
**When** this story is complete
**Then** one Google OAuth client is configured with both apps' `/auth/callback` URLs allow-listed, with both apps expected to use `AuthFlowType.pkce`

**Given** the anon key and service-role key
**When** client bundles are prepared
**Then** only the anon key is ever baked into a client bundle; the service-role key is never referenced client-side

---

## Epic 2: Dispatcher Web App (Vue)

A signed-in dispatcher can create, view, edit, and cancel relocation requests; see status update live as drivers act on them; and get notified in-app when a driver cancellation triggers automatic reassignment. Fully standalone and demoable against Epic 1's backend and seed data alone.

### Story 2.1: App Shell, Design Tokens, Login & Role Claiming

As a dispatcher opening the app for the first time,
I want to sign in with Google and land in a branded, navigable app shell,
So that I have a working, on-brand starting point for everything else I need to do.

**Acceptance Criteria:**

**Given** the Vue 3 + Vite + Tailwind project is scaffolded
**When** this story is complete
**Then** the DESIGN.md token set (colors, typography, spacing, rounded scale, elevation) is wired into the Tailwind config and available to every component built afterward (UX-DR1-4)

**Given** an unauthenticated visitor opens the dispatcher web app
**When** the app loads
**Then** they see the Login view — a Google OAuth button and one line explaining that signing up here creates a dispatcher account

**Given** an unauthenticated visitor clicks the Google OAuth button
**When** the OAuth flow completes successfully for the first time
**Then** the app calls `claim_role('dispatcher')`, then redirects to the Requests view (CAP-1)

**Given** an unauthenticated visitor's OAuth attempt fails
**When** the failure occurs
**Then** they see "We couldn't sign you in — try again," remaining on Login (non-blocking, distinct from the generic post-auth network banner)

**Given** a signed-in dispatcher
**When** they view the app shell
**Then** a fixed 220px sidebar shows Requests, Notifications, and an Account footer item (signed-in identity + sign out), with an accent-tint background and left-edge indicator on the active item (never accent-colored label text)

**Given** the dispatcher web app is viewed below the 1024px width floor
**When** the viewport is measured
**Then** a "best viewed on a larger screen" notice is shown instead of a responsive reflow (UX-DR13)

**Given** any interactive element in the shell (nav items, the OAuth button)
**When** it receives keyboard focus
**Then** a 2px accent-colored focus ring with 2px offset is visible (UX-DR20)

**Given** a keyboard user on the dispatcher web app
**When** they tab through the page
**Then** a skip-to-content affordance or `<main>`/`<nav>` landmark structure lets them bypass re-tabbing the sidebar on every navigation (UX-DR14)

**Given** any interactive control on the dispatcher web app
**When** it renders
**Then** its hit area is ≥32×32px, and every icon-only affordance built anywhere in this epic (the modal ✕, chevrons, etc.) carries an accessible label (UX-DR24) — this baseline applies to every subsequent story in this epic

### Story 2.2: Requests List with Realtime Sync, Search & Filter

As a signed-in dispatcher,
I want to see all my relocation requests with live status, and search or filter them,
So that I always have an accurate, scannable view of my work without manually refreshing.

**Acceptance Criteria:**

**Given** a signed-in dispatcher lands on Requests
**When** the view is loading
**Then** skeleton row placeholders (shape of a Card, no content) are shown until data resolves (UX-DR26)

**Given** a signed-in dispatcher's requests have loaded
**When** the Requests view renders
**Then** every owned request appears as a Request card showing origin/destination, scheduled date, notes, and a Status pill (dot + text + tint, never color-only) reflecting its lifecycle state (CAP-3, UX-DR5, UX-DR6)

**Given** the Requests view is open
**When** it renders
**Then** Stat tiles show static, non-interactive counts (e.g. unbooked/booked/completed/cancelled) — not clickable, not a filter control (UX-DR7)

**Given** the Requests view is open
**When** the dispatcher clicks a Filter chip (native `<button>`, single-select, "All requests" default-active)
**Then** the list re-filters in place with no navigation (UX-DR8)

**Given** the Requests view is open
**When** the dispatcher types in the search box
**Then** the list live-filters with no submit step, and the result count is announced via an `aria-live="polite"` region (UX-DR21)

**Given** a signed-in dispatcher has zero requests
**When** the Requests view renders
**Then** it shows "No relocation requests yet." plus a primary "+ New request" CTA

**Given** the dispatcher's search or filter yields zero results
**When** the list re-renders
**Then** a dashed-border empty-state panel shows "No requests match '{filter}'." plus a "Clear filters" ghost-button recovery action (UX-DR12)

**Given** a signed-in dispatcher is viewing Requests
**When** any of their requests changes status via a realtime event from another source (e.g. a driver books it)
**Then** the initial SELECT hydration plus an active realtime subscription on `relocation_requests` (RLS-scoped per AD-4) updates the card in place without a manual reload, and the change is announced via `aria-live="polite"` (CAP-3, CAP-9 consuming half, AD-5, UX-DR22)

**Given** the Status pill's brief flash on a realtime status change
**When** `prefers-reduced-motion` is set
**Then** the flash reduces to instant/opacity-only (UX-DR25)

### Story 2.3: Create & Edit Request via Modal

As a signed-in dispatcher,
I want to create a new relocation request and edit an existing one using the same form,
So that entering and correcting request details feels consistent and predictable.

**Acceptance Criteria:**

**Given** a signed-in dispatcher clicks "+ New request"
**When** the New/Edit Request modal opens
**Then** it opens blank (420px, centered) with focus on the Origin field

**Given** a signed-in dispatcher clicks "Edit" on an existing Request card
**When** the New/Edit Request modal opens
**Then** it opens prefilled with that request's values, with focus on the modal heading

**Given** the modal is open (create or edit)
**When** the dispatcher clicks Save, Cancel, the overlay, or presses Escape
**Then** the modal closes and focus returns to the element that triggered it

**Given** the modal is open (create or edit)
**When** the dispatcher tabs repeatedly, forward or backward
**Then** focus cycles only among the modal's own focusable elements and never reaches the page behind it (focus trap, per EXPERIENCE.md's Accessibility Floor and Interaction Primitives)

**Given** the modal is open with one or more required fields blank (e.g. Origin)
**When** the dispatcher clicks Save
**Then** inline error text appears directly under each invalid field (icon + text, not color-only), `aria-describedby` links the field to its error, focus moves to the first invalid field, and the modal stays open (CAP-2/CAP-4 validation, UX-DR9)

**Given** the modal has valid required fields filled in "create" mode
**When** the dispatcher clicks Save
**Then** a new relocation request is created (CAP-2) and the modal closes, with the new card appearing in the list immediately

**Given** the modal has valid required fields filled in "edit" mode
**When** the dispatcher clicks Save
**Then** the existing request is updated (CAP-4) and the modal closes, with the updated values shown on that same card immediately — no reload, no re-navigation

### Story 2.4: Cancel Request & Dispatcher Notifications

As a signed-in dispatcher,
I want to cancel a request regardless of its status, and get notified when a driver cancellation triggers a reassignment,
So that I can call off a request any time and stay informed without watching the app constantly.

**Acceptance Criteria:**

**Given** a signed-in dispatcher owns a request in any non-`cancelled` status
**When** they click "Cancel" on that Request card
**Then** a lightweight inline confirm appears (no separate confirmation modal); confirming calls `cancel_request_dispatcher` and the card's Status pill updates to `cancelled` in place (CAP-10, UX-DR6)

**Given** a signed-in dispatcher opens Notifications
**When** the page loads
**Then** it lists Notification items (plain text row, no status pill) — bold request route + plain-weight description of what happened + `text-secondary` timestamp, newest first (UX-DR11)

**Given** a signed-in dispatcher has zero notifications
**When** the Notifications view renders
**Then** it shows "Nothing here yet — you'll see an update if a driver ever cancels with reassignment." (UX-DR12)

**Given** a driver cancellation on one of the dispatcher's requests triggers CAP-12's auto-reassignment (produced by Epic 3, but observable here via the `notifications` realtime subscription)
**When** the resulting `notifications` row arrives
**Then** a new item appears in the Notifications feed without a manual refresh, and the sidebar's unread-count badge increments (CAP-13, AD-5)

**Given** the dispatcher opens the Notifications page with unread items present
**When** the page is viewed
**Then** the visible unread items are marked read (`read_at` set) and the sidebar badge count updates accordingly

### Story 2.5: Deploy Dispatcher Web to Vercel

As the operator,
I want the dispatcher web app live at a public URL,
So that it can be demoed and evaluated without running anything locally.

**Acceptance Criteria:**

**Given** the dispatcher web app is feature-complete through Story 2.4
**When** it is built for production
**Then** the build succeeds using the production Supabase URL and anon key as environment variables (no service-role key present anywhere client-side)

**Given** the production build
**When** it is deployed to Vercel
**Then** a live public URL serves the app, and the `/auth/callback` route is included in the Google OAuth client's allow-listed redirect URLs for that production URL (NFR3)

**Given** the deployed app at its public URL
**When** a dispatcher signs in and exercises Requests/Notifications
**Then** the full Story 2.1-2.4 flow works identically to local — sign-in, create/edit/cancel, realtime updates, notifications

---

## Epic 3: Driver Mobile App (Flutter)

A signed-in driver can browse live available gigs, book one in one tap with the completed-rides priority tie-break, view their booked gigs, cancel with the 24h notice rule, trigger automatic reassignment to another driver, and mark a gig complete. Fully standalone and demoable against Epic 1's backend alone.

### Story 3.1: App Shell, Design Tokens, Login & Role Claiming

As a driver opening the app for the first time,
I want to sign in with Google and land in a branded, navigable app shell,
So that I have a working, on-brand starting point for browsing and booking gigs.

**Acceptance Criteria:**

**Given** the Flutter 3 project is scaffolded
**When** this story is complete
**Then** the DESIGN.md token set (colors, typography, spacing, rounded scale, elevation) is expressed as Flutter `ThemeData` and available to every screen/widget built afterward, light mode only (UX-DR1-4, UX-DR28)

**Given** an unauthenticated visitor opens the driver mobile app
**When** the app loads
**Then** they see the Login screen — a Google OAuth button and one line explaining that signing up here creates a driver account

**Given** an unauthenticated visitor taps the Google OAuth button
**When** the OAuth flow completes successfully for the first time
**Then** the app uses `AuthFlowType.pkce` against a dedicated `/auth/callback` route (not the SPA root, avoiding Flutter web's hash-router collision with an implicit-flow redirect), calls `claim_role('driver')`, then lands on the Gigs tab (CAP-5)

**Given** an unauthenticated visitor's OAuth attempt fails
**When** the failure occurs
**Then** they see "We couldn't sign you in — try again," remaining on Login

**Given** a signed-in driver
**When** they view the app shell
**Then** a bottom tab bar shows exactly 3 tabs (Gigs / Booked / Profile), always visible except during the booking-confirmation interstitial (UX-DR18); Profile shows minimal signed-in identity + sign out

**Given** the driver mobile layout
**When** any screen renders
**Then** it uses a single-column, phone-width layout with 18-22px side margins, operable via both touch and mouse pointer in a desktop-sized browser window (Flutter web demo constraint, UX-DR19)

**Given** any interactive element (buttons, tab bar icons, icon-only affordances)
**When** it receives focus or is rendered
**Then** a visible focus indicator is present, tap targets are ≥44×44px, and every icon-only affordance carries an accessible label (UX-DR20, UX-DR24)

### Story 3.2: Gigs List, Realtime Sync, Booking & Confirmation

As a signed-in driver,
I want to browse available gigs that update live, book one in a single tap, and see unambiguous confirmation that it worked,
So that I can quickly and confidently claim relocation work as it becomes available, fairly against other drivers.

**Acceptance Criteria:**

**Given** a signed-in driver lands on Gigs
**When** the view is loading
**Then** skeleton row placeholders (shape of a Card, no content) are shown until data resolves (UX-DR26)

**Given** a signed-in driver's gigs have loaded
**When** the Gigs view renders
**Then** every `unbooked` request visible to them (per `driver_visibility` RLS) appears as a Gig card with one primary action, "Book this gig," and no secondary actions (CAP-6, UX-DR15)

**Given** a signed-in driver has zero available gigs
**When** the Gigs view renders
**Then** it shows "No gigs available right now — check back soon." with no CTA

**Given** a signed-in driver is viewing Gigs
**When** a dispatcher creates a new request elsewhere
**Then** the initial SELECT hydration plus an active realtime subscription on `relocation_requests` shows the new gig without an app restart or manual refresh (CAP-6, CAP-9 producing half, AD-5)

**Given** a signed-in driver taps "Book this gig" on an available gig
**When** the `book_request` RPC call resolves as a win
**Then** a full-screen booking confirmation interstitial appears (never a modal) — a check-icon in `status-completed-tint`/`status-completed`, a heading, a Card-styled summary of the route/date/notes, and a single full-width primary button through to Booked gigs (CAP-7, UX-DR16)

**Given** a signed-in driver taps "Book this gig" but another driver's concurrent bid wins (higher `completed_rides_count`)
**When** the `book_request` RPC call resolves as a loss
**Then** the card shows "No longer available" in place of the Book button for ~2 seconds, announced via `aria-live="polite"`, then the card is removed from the list — no confirmation screen, no false commitment (UX-DR22, UX-DR23)

### Story 3.3: Booked Gigs List

As a signed-in driver,
I want a clear view of everything I've currently got booked,
So that I always know what I'm committed to without having to remember which gigs I claimed.

**Acceptance Criteria:**

**Given** a signed-in driver taps through the booking confirmation from Story 3.2
**When** they land on Booked
**Then** the just-booked gig appears there via a Booked-gig row (route/date/notes, and a Status pill — dot + text + tint, never color-only, the same 4-state lifecycle component as the dispatcher app's pill, independently implemented in Flutter per AD-1) (CAP-8, UX-DR5)

**Given** a signed-in driver's booked gigs have loaded
**When** the Booked view renders
**Then** skeleton loading is shown identically to Gigs during cold load (UX-DR26), and every currently-booked gig for that driver appears, and nothing else (CAP-8)

**Given** a signed-in driver has zero booked gigs
**When** the Booked view renders
**Then** a dashed-border empty-state panel shows "You haven't booked anything yet." plus a ghost-button link back to Gigs, using the same Empty-state panel component pattern as the dispatcher app, independently implemented in Flutter (UX-DR12)

**Given** a signed-in driver is viewing Booked
**When** one of their booked gigs is cancelled by the dispatcher elsewhere
**Then** the initial SELECT hydration plus an active realtime subscription removes it from Booked instantly, with no manual reload (CAP-9 producing half, CAP-10 cross-app effect, AD-5)

### Story 3.4: Cancel (24h Rule) & Mark Complete

As a signed-in driver,
I want to cancel a booked gig only when I have enough notice, and mark a finished gig complete,
So that I can back out responsibly without stranding a ride, and keep my completed-rides count accurate.

**Acceptance Criteria:**

**Given** a Booked-gig row for a gig with `now() < cutoff` (client-computed via the same `scheduled_date @ 00:00 UTC − 24h` formula as AD-7, for instant feedback)
**When** the row renders
**Then** it shows an active "Cancel" (ghost) action

**Given** a Booked-gig row for a gig with `now() >= cutoff`
**When** the row renders
**Then** the Cancel control is disabled/muted with adjacent text "Too close to the ride to cancel (within 24h)." (CAP-11)

**Given** a signed-in driver taps "Cancel" on a gig with ≥24h remaining
**When** the `cancel_request_driver` RPC call succeeds
**Then** the row is removed from Booked (the server-side reassignment and dispatcher notification happen per Epic 1 Story 1.4, observable in Epic 2 Story 2.4) (CAP-11, CAP-12 trigger half)

**Given** a signed-in driver's cancellation is rejected server-side (e.g. a race where cutoff passed between render and tap)
**When** the RPC call returns the blocked result
**Then** the row stays in Booked and the same "too close to cancel" messaging is shown, matching the RPC's exception 1:1 (AD-7's authoritative server-side re-check)

**Given** a Booked-gig row for a gig currently `booked`
**When** the row renders
**Then** it also shows a "Mark complete" (ghost) action, available any time the gig is `booked`

**Given** a signed-in driver taps "Mark complete"
**When** the `complete_request` RPC call succeeds
**Then** the row is removed from Booked immediately, with no separate confirmation screen (CAP-14)

**Given** any transient motion on this screen (row removal after cancel/complete)
**When** `prefers-reduced-motion` is set
**Then** the removal reduces to instant/opacity-only (UX-DR25)

### Story 3.5: Deploy Driver Mobile to Vercel

As the operator,
I want the driver mobile app live at a public URL as a Flutter web build,
So that it can be demoed and evaluated without running anything locally, satisfying the non-native-binary deliverable.

**Acceptance Criteria:**

**Given** the driver mobile app is feature-complete through Story 3.4
**When** it is built for production (`flutter build web`)
**Then** the build succeeds using the production Supabase URL and anon key as environment configuration (no service-role key present anywhere client-side)

**Given** the production `build/web` output
**When** it is deployed to Vercel
**Then** a live public URL serves the app, and the `/auth/callback` route is included in the Google OAuth client's allow-listed redirect URLs for that production URL (NFR3)

**Given** the deployed app at its public URL
**When** a driver signs in and exercises Gigs/Booked
**Then** the full Story 3.1-3.4 flow works identically to local — sign-in, browse/book, confirmation, cancel/complete — with the PKCE flow functioning correctly on Flutter web's production build

---

## Epic 4: Cross-App Demo Readiness & Delivery

Verify the full two-way realtime loop (CAP-9, CAP-13) actually works end-to-end once both apps are live and deployed, and produce the delivery artifacts the challenge requires. Depends on Epic 1, Epic 2, and Epic 3 all being complete.

### Story 4.1: Cross-App End-to-End Realtime Verification

As the operator preparing to present the demo,
I want to prove the full dispatcher↔driver realtime loop works against both live, deployed apps,
So that the 5-minute walkthrough is a proven, rehearsed flow rather than an untested hope.

**Acceptance Criteria:**

**Given** both apps are deployed at their public URLs (Story 2.5, Story 3.5)
**When** a dispatcher creates a new relocation request on the live dispatcher-web URL
**Then** it appears on the live driver-mobile URL's Gigs list within seconds, with no manual refresh (CAP-9 dispatcher→driver direction, Key Flow 2)

**Given** the driver books that gig on the live driver-mobile URL
**When** the booking succeeds
**Then** the live dispatcher-web URL's Requests view reflects the `booked` status and assigned driver within seconds, with no manual refresh (CAP-9 driver→dispatcher direction)

**Given** the driver cancels that booked gig with ≥24h notice on the live driver-mobile URL
**When** the cancellation succeeds
**Then** the gig is auto-reassigned (or reverts to unbooked) within seconds, and a new item appears in the live dispatcher-web URL's Notifications feed identifying the request and what happened, with no manual refresh on either side (CAP-12, CAP-13, Key Flow 3)

**Given** the full verification pass above ran without needing a manual refresh anywhere
**When** it's timed as a rehearsal
**Then** it completes within a 5-minute walkthrough window, confirming NFR7 — this run is the demo rehearsal, not a separate exercise

**Given** any step in this verification fails or exceeds the seconds-scale sync expectation
**When** the failure is diagnosed
**Then** it is fixed at its source (Epic 1 RPC/RLS/realtime config, or the relevant Epic 2/3 story) and this story is re-run to confirm before being considered complete

### Story 4.2: Repo, Prompt Log & Reflection Delivery Artifacts

As the operator submitting the challenge,
I want the public repo, prompt log, and written reflection all in order,
So that the submission meets every delivery constraint in SPEC.md, not just the working software.

**Acceptance Criteria:**

**Given** the repository used across Epics 1-3
**When** its visibility and history are checked
**Then** it is publicly visible (GitHub/GitLab) and its commit history shows incremental commits reflecting the project's evolution — not one squashed initial commit (NFR4)

**Given** the prompts used throughout the build
**When** the prompt log is compiled
**Then** it captures key prompts, what came back, and what was changed and why, in written or recorded form (NFR6)

**Given** the completed build across all four epics
**When** the written reflection is authored
**Then** it honestly and specifically addresses what worked, what broke, and where AI got in the way — not a generic "AI is amazing" statement (NFR8)

**Given** the challenge's submission logistics (`challenge-context.md`)
**When** delivery is finalized
**Then** live URLs and the repo link are ready to send at least 1 hour before the presentation slot, with prompt log and reflection ready to walk through if asked
