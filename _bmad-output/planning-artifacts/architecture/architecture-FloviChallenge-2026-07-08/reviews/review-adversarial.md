---
name: 'Adversarial Review — Flovi Relocation-Dispatch Architecture Spine'
type: review
reviews: '../ARCHITECTURE-SPINE.md'
against: 'two-independent-builders divergence stress test'
created: '2026-07-08'
verdict: 'FAIL on two Critical findings; several High/Medium gaps remain that a compliant-to-the-letter build would not catch'
---

# Adversarial Review — ARCHITECTURE-SPINE.md as a two-builder divergence contract

**Premise of this review:** one person builds `apps/dispatcher-web` and `apps/driver-mobile` in separate AI-prompting sessions, days apart, with no shared short-term context between sessions. The spine's only job is to make each session's output compatible with the other's without either session having to re-derive intent. Every finding below is a scenario where **both builders can honestly claim "I followed the AD as written"** and the result is still broken, insecure, or silently incompatible.

Findings the spine already closes well (not re-litigated here): RPC naming/signature fixity (AD-2, AD-3), the four-value status vocabulary and its casing (AD-5), the ban on polling/local caches (AD-5), `created_by` spoof-prevention on insert (AD-4), and dispatcher-vs-driver read scoping *as a stated intent* (AD-4). These are genuinely well-pinned. The findings below are the places the letter of the spine still leaves a gap.

---

## Critical

### 1. SECURITY DEFINER bypasses RLS — none of the four RPCs are required to re-check actor identity

AD-3 names `book_request`, `cancel_request_dispatcher`, `cancel_request_driver`, and `complete_request` as `SECURITY DEFINER` and says each enforces "`state-machines.md`'s transition table." Neither `state-machines.md` nor AD-3/AD-4 ever says the RPC body must verify **who is calling it** against the row (`auth.uid() = driver_id` for the driver RPCs, `auth.uid() = created_by` for `cancel_request_dispatcher`).

This matters because `SECURITY DEFINER` functions execute with the function owner's privileges (in a standard Supabase setup, the migration-owning role, effectively bypassing RLS the same way a table owner or superuser does). Row-Level Security is **not automatically applied inside these functions** — the Consistency Conventions table's own claim ("RLS is the sole authorization layer — never duplicated as app-level permission checks") is true for the direct-SELECT and CAP-4 direct-UPDATE paths, but **false for the four RPC-mediated write paths**, which are exactly the paths AD-3 exists to lock down.

Concrete scenario: session A (dispatcher-web) writes `cancel_request_dispatcher(request_id)` as literally "look up the row, set status = 'cancelled'" — reasonable, since AD-3's Rule text never mentions an ownership check and the Consistency Conventions table just told this builder RLS already handles authorization. Session B (driver-mobile), built days later with no memory of session A's SQL, never has reason to revisit that function. Nothing in the spine would have surfaced the gap to either session. Result: any authenticated dispatcher can cancel *any other dispatcher's* request by calling the RPC directly with a foreign `request_id` — a direct violation of AD-4's core promise, through the one governed-by-AD-4 RPC that the spine itself maps to it (`CAP-10 | cancel_request_dispatcher | AD-3, AD-4`).

The same gap applies to `cancel_request_driver` (any driver could cancel another driver's booking) and `complete_request` (any driver could mark **any** booked gig — not just their own — complete, incrementing an arbitrary driver's `completed_rides_count`). The last one is especially serious: it directly corrupts the CAP-7/CAP-12 priority ranking the spine's own scope line calls out as the single most important mechanic to get right.

**Fix shape:** one sentence in AD-3: "each RPC additionally verifies `auth.uid()` against the row's `driver_id`/`created_by` before mutating, raising an exception otherwise — this check is internal to the function, since `SECURITY DEFINER` execution is not subject to RLS."

---

### 2. RLS policy OR-composition can silently resurrect the shared-pool leak AD-4 was written to prevent

AD-4 states the dispatcher predicate as `created_by = auth.uid()` and, in its "Does not affect" clause, states the driver predicate as `status = 'unbooked' OR driver_id = auth.uid()` — presented as two independent facts about two different roles. Postgres combines multiple **permissive** `SELECT` policies on one table with **OR**. Unless each policy is *also* gated on the caller's own `profiles.role` (e.g., `... AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'dispatcher')`), a dispatcher's session satisfies the *driver* policy's `status = 'unbooked'` clause for every unbooked row in the system, regardless of who created it — because that clause never references the caller's identity at all.

Concrete scenario: session A writes the dispatcher policy exactly as AD-4 states it. Session B (days later, driver-mobile) writes the driver policy exactly as AD-4's "Does not affect" clause states it — reasonably, since that's the literal text. Neither session had reason to look at the interaction between the two `CREATE POLICY` statements, because AD-4 never says they must be mutually exclusive by role. The dispatcher-web app, per the Consistency Conventions ("RLS is the sole authorization layer — never duplicated as app-level permission checks"), is explicitly discouraged from adding its own defensive `.eq('created_by', uid)` client-side filter — so a plain `select * from relocation_requests` in the dispatcher app now returns every dispatcher's unbooked requests, not just its own. This is precisely the "driver global-visibility rule sits next to the dispatcher-scoping rule and gets conflated" scenario this review was asked to hunt for — and it reintroduces the exact cross-dispatcher leak AD-4's own "Prevents" clause names.

**Fix shape:** state explicitly that each policy's predicate is additionally gated on the caller's own role, or collapse both into one combined policy per table that switches on `profiles.role`.

---

## High

### 3. INSERT-time spoofing of `status`/`driver_id` is not closed — only UPDATE is

AD-3's Rule revokes "client-facing UPDATE grant" on `status`/`driver_id`. It says nothing about INSERT. The Capability Map lists CAP-2 (request creation) as a direct client `relocation_requests` INSERT — not an RPC. AD-4 separately guarantees only that `created_by` can't be spoofed on insert; it never mentions `status`/`driver_id`. A column-level `REVOKE UPDATE` does not touch `INSERT` privilege in Postgres — these are independent grants. A dispatcher-web build that is 100% compliant with AD-3/AD-4 as written could ship a create-request form whose payload includes (accidentally, or because the AI scaffolded a generic "insert all form fields" call) `status: 'booked', driver_id: <uuid>` — and nothing in the spine's stated grants/constraints stops that write from succeeding, completely bypassing `book_request` and AD-6's priority check.

**Fix shape:** one line — "the INSERT policy/CHECK constraint additionally forces `status = 'unbooked'` and `driver_id IS NULL` on client-initiated inserts, independent of the UPDATE-grant revoke."

### 4. `profiles.full_name` has no stated writer, no stated source key — yet the UX depends on it being correct

`claim_role(role)` (AD-2) takes exactly one argument and "inserts the caller's `profiles` row only if one doesn't exist." Nothing says it populates `full_name`, and nothing says from which OAuth-metadata key (`user_metadata.full_name` vs `.name` vs `given_name`/`family_name` concatenation — all plausible depending on how the Google provider's claims get mapped by Supabase Auth). Yet `EXPERIENCE.md`'s Flow 3 requires the dispatcher notification to render the reassigned driver's name verbatim ("...automatically reassigned to Priya Nair"), which can only come from `profiles.full_name` read by whichever RPC (`cancel_request_driver`) constructs that message. If the session that writes `claim_role` doesn't populate `full_name` (nothing told it to), the notification silently renders a blank or null name — a defect that only surfaces during the CAP-12 reassignment flow, likely late in the build, in the other app's session.

**Fix shape:** name the source expression in AD-2 or the Core Entities section, e.g. "`claim_role` sets `full_name` from `auth.users.raw_user_meta_data->>'full_name'` at insert time."

### 5. `claim_role`'s behavior on a role conflict is completely unspecified — the exact scenario this review was asked to check

AD-2 guarantees role is immutable once set, but never says what happens to the **call** when a user who already has a profile (with one role) triggers `claim_role('<other role>')` by opening the other app. Silent no-op success? Exception? Nothing in `SPEC.md`, `state-machines.md`, or the spine addresses it, and `EXPERIENCE.md`'s Login state table only defines an "OAuth failure" treatment, not a "wrong role" one. If it's a silent no-op (consistent with "inserts... only if one doesn't exist"), the calling app has no signal to avoid landing the user on its own home screen (CAP-1/CAP-5's success criteria assume the claim always succeeds and always lands the user in-app) — so a `role='dispatcher'` user who opens driver-mobile would land on the Gigs screen while their `profiles.role` is still `'dispatcher'`. Combined with Finding #1 (no role check inside the RPCs) and Finding #2 (no role-gating in RLS), this user could actually book/cancel/complete gigs despite never holding the driver role, corrupting the CAP-7/CAP-12 priority pool with a "driver" whose `completed_rides_count` semantics were never intended to apply to them.

**Fix shape:** state the resolution explicitly — e.g., "`claim_role` raises an exception if the caller already has a different role; the calling app shows a fixed 'This account is already registered as a {role}' message and does not proceed past Login."

---

## Medium

### 6. `scheduled_date` (DATE, no time-of-day) parses to *different calendar dates* in Vue vs. Flutter for the same wire value

The Consistency Conventions pin the wire format (`date`, PostgREST/ISO 8601 default) but not client-side parsing behavior. A bare date string like `"2026-07-10"` is interpreted by JavaScript's `Date` constructor as **UTC midnight**, but by Dart's `DateTime.parse` as **local midnight** (Dart's documented behavior when no offset is present). In any timezone with a negative UTC offset (e.g., US Pacific), rendering that same value with each platform's native date APIs can show the request as scheduled on 2026-07-09 in one app and 2026-07-10 in the other — for the identical row. This is a well-known, easy-to-miss cross-platform gotcha that two independently-prompted sessions have no reason to catch, since each app "correctly" uses its own platform's idiomatic date parsing.

### 7. The ≥24h cancellation cutoff has no defined time-of-day anchor

CAP-11/`state-machines.md` require "≥24 hours before the scheduled date," but `scheduled_date` carries no time component. Nothing states what moment the cutoff is measured against (midnight start-of-day, end-of-day, a fixed assumed pickup time). This is computed twice: once inside `cancel_request_driver` (server, authoritative) and once client-side in driver-mobile to gray out the Cancel button pre-emptively (per `EXPERIENCE.md`'s Booked-gig-row spec). If the two computations use different anchors, the button's enabled/disabled state can disagree with what the RPC actually allows — confusing, though not data-corrupting, since the RPC remains authoritative and the error-copy convention catches the mismatch after the fact.

### 8. Driver-side realtime visibility can't be expressed as a Postgres Changes `filter=`, and the spine doesn't say what to do instead

AD-5 pins the two subscribed tables and the status vocabulary, but not the subscribe-time filter strategy. The dispatcher predicate (`created_by = auth.uid()`) is a simple equality and trivially supports a `filter=created_by=eq.<uid>` clause. The driver predicate (`status = 'unbooked' OR driver_id = auth.uid()`) is a two-column OR, which Supabase Realtime's `filter` parameter cannot express as a single clause. This forces the driver-mobile session into a genuinely different pattern — subscribe unfiltered and re-check every incoming payload client-side, or trust RLS's realtime enforcement completely — and the spine never surfaces this asymmetry or says which approach is required. A driver-mobile build that skips the client-side re-check and simply trusts RLS is one Realtime/RLS edge case away from momentarily rendering another driver's booked row (a known category of Supabase RLS+Realtime rough edge, worse if Finding #2's policy gap is also present).

### 9. The "map RPC exception message 1:1" contract is fragile and almost entirely unenumerated

Only one exact exception string is pinned ("Too close to the ride to cancel (within 24h)."). Every other failure mode — losing the CAP-7 booking race, double-completing a gig, cancelling an already-cancelled request — needs its own exact wording, matched verbatim (or by substring) between whatever string the Postgres function raises and whatever the client string-matches against to pick the correct UI treatment (e.g., the specific "No longer available" race-lost card vs. the generic "We couldn't reach the server" banner). Nothing enumerates this catalog. Two sessions days apart, one writing the SQL `RAISE EXCEPTION` text and the other writing the Dart/JS catch-and-map logic, can trivially drift on wording (e.g., "This gig is no longer available" vs. a client checking for "No longer available") and silently fall through to the wrong, generic error treatment.

---

## Low

### 10. No `created_at`/ordering column on `relocation_requests` or `notifications`

The Core Entities ERD has no timestamp column on either table. `EXPERIENCE.md` calls Notifications a "feed" (implying chronological order), which can't be derived from `scheduled_date` (the ride's date, not the cancellation event's date) or from a UUID PK. Each session has to invent an ordering column independently; nothing pins its name or that it exists at all.

### 11. "Functional Notifications counter" implies unread-state the schema doesn't have

`EXPERIENCE.md`'s Interaction Primitives reference "the functional Notifications counter" as distinct from decorative badge gamification — implying it tracks unseen items — but the `notifications` table has no `read`/`seen` column. Ambiguous whether the counter is "unread count" (schema gap) or "lifetime total" (no gap, but a different, unstated product decision). Lower-severity than the cross-app findings above since only the dispatcher-web app touches this table.

### 12. `status`/`role` typed `text` in the ERD despite being called an "enum" throughout the prose

If migrated as `text` + `CHECK` (as the ERD literally shows) rather than a native Postgres `ENUM` type, Supabase's generated TypeScript types will surface these columns as plain `string`, not a strict union — a minor type-safety difference from what a builder skimming "four-value status enum" might expect from `supabase gen types typescript`. Cosmetic; doesn't affect runtime behavior since both apps compare against the same literal strings either way.

---

## Summary table

| # | Finding | Severity | Category |
| --- | --- | --- | --- |
| 1 | RPCs never required to verify caller identity; SECURITY DEFINER bypasses RLS | Critical | State-mutation path |
| 2 | RLS OR-composition can leak the shared pool across dispatchers | Critical | RLS/ownership boundary |
| 3 | INSERT path can set `status`/`driver_id` directly — only UPDATE grant is revoked | High | State-mutation path |
| 4 | `profiles.full_name` — no writer, no source key stated | High | Shared-data shape / ownership |
| 5 | `claim_role` cross-role conflict behavior unspecified | High | claim_role ambiguity |
| 6 | `scheduled_date` parses to different calendar dates in JS vs. Dart | Medium | Shared-data shape |
| 7 | 24h cutoff has no time-of-day anchor | Medium | Shared-data shape |
| 8 | Driver realtime OR-predicate not expressible as Realtime `filter=` | Medium | Realtime contract |
| 9 | RPC exception-message catalog mostly unenumerated | Medium | State-mutation path |
| 10 | No `created_at` column on `relocation_requests`/`notifications` | Low | Shared-data shape |
| 11 | Notification "unread counter" implies a column that doesn't exist | Low | Two owners / entity gap |
| 12 | `text` vs native `ENUM` typing affects generated-types strictness | Nit | Shared-data shape |
