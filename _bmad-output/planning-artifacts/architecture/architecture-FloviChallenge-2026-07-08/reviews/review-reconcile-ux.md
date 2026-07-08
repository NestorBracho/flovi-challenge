# Reconciliation Review — Architecture Spine vs. Driving UX Package

**Reviewed doc:** `ARCHITECTURE-SPINE.md`
**Against:** `ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md` + `EXPERIENCE.md` (both `status: final`)
**Check date:** 2026-07-08
**Method:** read all three documents in full; traced each EXPERIENCE.md/DESIGN.md behavior back to the specific AD, entity, or RPC in the spine that would have to carry it. Read-only — no edits made to the spine or either UX file.

**Verdict: mostly aligned, with two real structural gaps and one notable ambiguity.** The realtime contract (AD-5), the RLS/RPC write boundary (AD-3/AD-4/AD-6), and the four-value status enum cleanly support most of EXPERIENCE.md's behaviors — modal validation, empty/cold-load states, the 24h-lock error copy, and the booking-race error signal all check out. But the `notifications` entity is missing columns two of its own required UX behaviors depend on, and the spine never grants read access to the `profiles` data the dispatcher UI must display (driver names). Both are silent gaps — they read as complete in the spine but would surface as build-time bugs, not as documented trade-offs.

---

## 1. Notifications feed — persisted history + its own empty state

**UX requirement:** EXPERIENCE.md IA lists Notifications as a sidebar-reachable feed (not a toast) with its own empty state ("Nothing here yet — you'll see an update if a driver ever cancels with reassignment."). DESIGN.md's Notification item component additionally requires a `text-secondary` **timestamp** on every row, and unread items surface as **a dot on the sidebar nav count badge** — which requires the system to know, per dispatcher, which notifications are unread.

**Spine support:** `notifications` is a real Postgres table (`id`, `request_id`, `dispatcher_id`, `message`), RLS-scoped to the owning dispatcher (AD-4), delivered live via Postgres Changes (AD-5). This structurally satisfies "persisted history across sessions, not just a live toast" — a table survives reloads and logouts; a toast does not. The empty state itself needs nothing extra: an owner-scoped query legitimately returning zero rows is not an error case.

**Gap — HIGH severity:** the `NOTIFICATIONS` entity in Structural Seed has no timestamp column and no read/unread column.
- No `created_at`/`timestamptz`: there's no column to order the feed chronologically (the PK is `gen_random_uuid()`, not sortable by creation order) and no field to back the required `text-secondary` timestamp on each row.
- No `read`/`is_read` (or equivalent): DESIGN.md's "unread items get a dot in the sidebar nav count badge" needs a durable unread/read distinction *per dispatcher, across sessions* (the reviewer's own framing — "persisted history across sessions" — implies the unread count must survive a reload too, not just reset each time the tab opens). Nothing in the spine tracks this, and there's no RPC/UPDATE grant to flip it when a dispatcher views the feed.

Both are needed to build behavior DESIGN.md/EXPERIENCE.md describe as final, not optional. Recommend adding `created_at timestamptz default now()` and a `read boolean default false` (or similar) to `notifications`, plus a narrow client-facing UPDATE grant limited to that one flag (AD-3's write-lock only covers `relocation_requests.status`/`.driver_id`, so this wouldn't conflict with it).

---

## 2. Booking race lost (~2s, aria-live, losing client needs a fast/clear signal)

**UX requirement:** the losing driver sees "No longer available" in place of the Book button for ~2s (announced via `aria-live="polite"`), then the card is removed — distinct in tone/mechanism from the generic "we couldn't reach the server" banner.

**Spine support — good:** `book_request` is `SECURITY DEFINER` (CAP-7, AD-1/AD-3/AD-6), and per Consistency Conventions, RPC failures raise a Postgres exception whose message the client maps 1:1 to fixed copy. Because this is a synchronous RPC response rather than a wait-for-realtime round trip, the losing driver learns the outcome directly on the call's return — fast by construction, and inherently distinguishable from a transport-level network failure (which never gets far enough to receive a Postgres exception at all). The ~2s hold-then-remove and the `aria-live` announcement are correctly pure client-side concerns layered on top of that signal; the spine doesn't need to (and doesn't) model them, and doesn't wrongly push them onto the backend.

**Minor gap — LOW severity:** unlike the 24h-cancel-lock message, which Consistency Conventions quotes verbatim ("Too close to the ride to cancel (within 24h)."), the spine never quotes the specific exception text `book_request` should raise when the row is no longer `unbooked` at call time. Worth adding for the same reason the 24h message was called out — so the RPC's raised text and the client's rendered "No longer available" copy are guaranteed to match 1:1 rather than being independently invented per app during implementation.

**Note only, not a UX-vs-architecture mismatch:** EXPERIENCE.md Flow 2 states "the winning driver is whoever has more completed rides," and AD-6 says the tie-break "read[s] `completed_rides_count` inside the same transaction" as the write. For a genuinely simultaneous double-tap, ordinary row-level locking resolves by *commit order*, not by comparing the two callers' `completed_rides_count` against each other — the second transaction simply finds the row already `booked` and fails, without ever evaluating who "should" have won. AD-6's language describes a well-defined comparison for CAP-12 (one row, many *candidate* drivers to rank), but for CAP-7's true two-caller race there's no shared decision point for a rank comparison to happen inside. This is a pre-existing tension in the tie-break's own definition rather than something the spine's write boundary got wrong — flagging for awareness, not blocking.

---

## 3. 24h cancellation lock + exact disabled-state messaging

**UX requirement:** Booked-gig row shows "Cancel" only when ≥24h remains before the scheduled date; otherwise a muted/disabled label with the exact text "Too close to the ride to cancel (within 24h)." — rendered proactively (the control itself is disabled, not just rejected after a tap).

**Spine support — good on the message:** Consistency Conventions quotes this exact string as the fixed RPC-failure copy, and CAP-11 explicitly names `cancel_request_driver`'s "24h guard."

**Gap — MEDIUM severity:** `relocation_requests.scheduled_date` is a `date`, explicitly with **no time-of-day** ("`scheduled_date` is a `date` (no time-of-day)" — Consistency Conventions). A 24-**hour** cutoff cannot be computed unambiguously against a bare calendar date: the spine never states what instant "the scheduled date" resolves to for the comparison (midnight local? midnight UTC? end of day? some assumed pickup time?). This matters in two compounding ways:
- The UX wants the Cancel control disabled *proactively*, client-side, before any RPC call — driver-mobile needs to compute this boundary itself from `scheduled_date` alone. Without a pinned formula, that computation is underspecified.
- Whatever formula driver-mobile picks for the button's disabled state must exactly match whatever formula `cancel_request_driver` uses server-side to accept/reject the call — otherwise the button can show "enabled" while the RPC still rejects, or vice versa, which is precisely the kind of two-implementations-of-one-rule drift AD-1 exists to prevent.

Recommend the spine pin the exact boundary expression once (e.g., treat `scheduled_date` as midnight in some fixed timezone, `scheduled_date::timestamptz - now() >= interval '24 hours'`) so both the driver-mobile render logic and the RPC guard implement the identical rule — or add time-of-day to the column if the real product needs a true 24-hour countdown rather than a calendar-day one.

---

## 4. Driver-cancel → reassignment: dispatcher's status pill AND driver name updating live

**UX requirement (EXPERIENCE.md Flow 3):** "the request's status briefly reflects the reassignment and its driver name updates from Marcus to Priya — no page reload." More broadly, any booked request card is implied to show its assigned driver's name at all times, not just during a live reassignment.

**Status pill — fine, no gap.** `relocation_requests.status` changes are delivered directly to the dispatcher via the AD-5 realtime subscription on a row the dispatcher already has RLS visibility into (`created_by`, which never changes on reassignment).

**Gap — HIGH severity:** the spine never grants a dispatcher (or anyone) read access to another user's `profiles.full_name`. AD-4 only defines RLS scoping for `relocation_requests` (owner = `created_by`) and `notifications` (scoped via the request's `created_by`); it says nothing about a `profiles` SELECT policy. AD-2 only addresses `profiles.role` being immutable after first write. If `profiles` RLS defaults to the typical "only your own row" shape, the dispatcher app has no way to resolve `relocation_requests.driver_id` (a bare uuid) into a displayable name — not only during the live-reassignment moment Flow 3 describes, but for *every* booked request's card, any time a driver is shown at all (CAP-3/CAP-8). This would silently break a constantly-visible piece of UI, not just the reassignment edge case.

(The Notifications *message* text itself is unaffected either way — `cancel_request_driver` runs `SECURITY DEFINER`, so it can resolve any profile server-side and bake the name directly into the stored `message` string, e.g. "...reassigned to Priya Nair." That path needs no client-facing profiles grant.)

Recommend the spine add an explicit RLS SELECT policy for `profiles` (e.g., any authenticated user may read `id`/`full_name`/`role` for all profiles — low-risk at this demo's scale) or expose driver names via a narrow view/RPC instead of a raw table grant.

---

## 5. Modal validation/focus behavior — purely client-side?

**Checked against:** EXPERIENCE.md's Component Patterns and Accessibility Floor for the New/Edit Request modal — required-field validation, inline error text, focus-to-first-invalid-field, `aria-describedby`, focus trap, Escape/overlay/Save/Cancel dismissal, focus return to the triggering element.

**Finding: aligned, no gap.** This is correctly absent from the spine. The Capability Map ties CAP-2/CAP-4 only to the underlying data operation (`relocation_requests` INSERT / RLS-gated UPDATE on non-status columns), never to validation or focus logic, and the "RPC failures map to fixed copy" convention is scoped to genuine mutation failures raised by the four state-transition RPCs (AD-3) — not to pre-submission field validation, which never needs to touch the backend at all. The spine does not wrongly imply backend involvement in modal validation/focus; it stays silent on a topic that is correctly, entirely a front-end concern.

(Optional, not a gap: the spine could additionally note `origin`/`destination`/`scheduled_date` as `NOT NULL` at the DB level, as defense-in-depth against a client bug bypassing modal validation — but EXPERIENCE.md doesn't require this, and its absence isn't a UX-support gap.)

---

## 6. Empty-state / cold-load state distinctions

**UX requirement:** distinguish "still loading" (skeleton rows), "no data yet" (confirmed zero rows, no filter applied), and "zero results after filter" (raw list non-empty, filtered view empty) — across Requests, Gigs, Booked, and Notifications.

**Finding: aligned, with one wording ambiguity worth tightening (MEDIUM).** All three states are legitimately derivable client-side: a `loading` boolean before the first fetch/subscription resolves, then a row-count check on the raw fetched list, then a separate row-count check on the client-side-filtered subset (EXPERIENCE.md's Search box and Filter chips both filter an already-loaded list in place, not via a server-side query per keystroke). Supabase returns a well-formed empty array for zero matching rows, not an error, so nothing here requires new backend capability.

One thing worth tightening: AD-5 states "No app-local derived-state cache and no polling fallback — realtime is the only sync path." Read literally, this could be misread as forbidding an initial `SELECT` to hydrate a list before subscribing — but Postgres Changes only streams *changes going forward* from subscription time; it does not replay pre-existing rows. A client built strictly to that literal wording (subscribe-only, no initial fetch) would show every list as permanently empty until the next write — including the demo's own seeded data — which would directly break the "no data yet" vs. "still loading" distinction this section is checking. This is very likely just imprecise wording (the rule almost certainly means to ban *polling as an ongoing sync mechanism*, not the one-time hydration fetch every realtime-subscribed list needs), but it's worth the spine saying explicitly: "each list does one initial `SELECT` to hydrate, then subscribes for ongoing changes" — so no implementer reads AD-5 as banning that fetch.

---

## DESIGN.md structural check — status color system vs. spine's status enum

**Finding: fully aligned, no gap.** DESIGN.md's four status color families (`status-unbooked`, `status-booked`, `status-completed`, `status-cancelled`, each with a swatch/`-text`/`-tint` triple) match name-for-name and in the same order the spine's AD-5 enum (`unbooked` / `booked` / `completed` / `cancelled`, lowercase, no aliases). No drift, no missing/extra state, no casing mismatch — a clean 1:1 correspondence.

---

## Summary of findings, ranked

1. **HIGH — `notifications` is missing `created_at` (no way to order the feed or render the required per-row timestamp) and any read/unread tracking (no way to back the sidebar unread-count dot).** Both are behaviors DESIGN.md/EXPERIENCE.md describe as final.
2. **HIGH — no RLS SELECT policy is specified for `profiles`, so the dispatcher app has no way to resolve a `driver_id` into a displayable name** — needed for every booked request card, not only the live-reassignment moment in Flow 3.
3. **MEDIUM — the 24h cancellation boundary is unspecified given a date-only `scheduled_date` column**, risking disagreement between the driver-mobile client's proactive render-time check and `cancel_request_driver`'s server-side enforcement.
4. **MEDIUM — AD-5's "realtime is the only sync path" wording could be misread as banning the initial hydration `SELECT` every list needs**, since Postgres Changes cannot replay pre-existing rows; worth one clarifying sentence.
5. **LOW — the exact exception message for a lost booking race ("No longer available") isn't quoted in the spine**, unlike the 24h-lock message, which is quoted verbatim.
6. **Note only, no action needed — CAP-7's "driver with more completed rides wins" framing isn't mechanically well-defined for a truly simultaneous two-caller race under simple row-locking**, since the second caller's transaction never gets a chance to compare counts against the first; a pre-existing tension in the tie-break's own definition, not something the spine's write boundary introduced.

**Confirmed aligned (no gaps found):**
- Modal validation/focus behavior is correctly kept purely client-side; the spine does not imply backend involvement anywhere.
- Empty-state / cold-load / filtered-zero distinctions are all achievable client-side with the current data model (aside from the AD-5 wording note above).
- DESIGN.md's four-status-color system matches the spine's status enum exactly — names, order, casing.
- The `notifications` table's existence as a real, persisted Postgres table (vs. a live-only toast) correctly satisfies "history across sessions" structurally, independent of the missing-columns finding above.
