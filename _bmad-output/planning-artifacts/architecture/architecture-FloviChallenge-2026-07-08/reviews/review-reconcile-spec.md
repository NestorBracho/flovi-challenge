# Reconciliation Review — ARCHITECTURE-SPINE.md vs. SPEC package

**Subject:** `architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md`
**Against:** `specs/spec-relocation-dispatch/{SPEC.md, stack.md, state-machines.md, challenge-context.md}`
**Mode:** read-only reconciliation, no edits made to any input file.

## Verdict

**Has gaps.** Coverage of the 14 capabilities is structurally complete (all CAP-1..14 appear in `binds:` and in the Capability → Architecture Map), and several specifically-risky items called out by the SPEC package *are* handled well (see "Confirmed correct" below). But five findings below represent real ambiguities or contradictions that a builder relying solely on the spine could get wrong, plus one interpretive call worth flagging even though it's explicitly labeled adopted.

---

## Findings (ranked by severity)

### 1. [HIGH] 24h cancellation guard is unimplementable as specified — hour-precision rule vs. a date-only column

- **SPEC:** CAP-11 requires the guard to fire at an hour boundary: "provided at least 24 hours remain before the scheduled date"; state-machines.md: "Driver attempts to cancel within 24h of the ride" → blocked.
- **Spine:** Consistency Conventions table declares `scheduled_date` is a `date` (no time-of-day) — a deliberate, explicit architectural choice.
- **Gap:** Nowhere does the spine reconcile these two facts. A "24 hours before the scheduled date" cutoff is only meaningful against a timestamp; with a date-only column, "24 hours before" is ambiguous (24h before midnight of that date? before some assumed appointment time? measured in whole calendar days instead?). AD-3 just says `cancel_request_driver` enforces "state-machines.md's transition table" — it never states the actual cutoff formula (e.g., `now() >= scheduled_date::timestamptz - interval '24 hours'`, which implicitly treats the ride as occurring at midnight UTC — a debatable assumption in itself). This is exactly the kind of assumption that should have become an explicit `[ADOPTED]` rule and wasn't.
- **Risk:** An implementer could build the guard against whole calendar days ("cancel allowed only if today < scheduled_date - 1 day") which behaves differently from a true 24-hour rolling window, especially near midnight — a plausible, demo-visible bug.

### 2. [MEDIUM-HIGH] CAP-10's "cancel at any time, regardless of status" is not reconciled with state-machines.md's transition table, which has no `completed → cancelled` row

- **SPEC:** CAP-10 intent is explicit: dispatcher "cancels an existing relocation request **at any time, regardless of its current status**." state-machines.md's notes column repeats, verbatim, on both the `unbooked→cancelled` and `booked→cancelled` rows: "Dispatcher can cancel from any state, any time" — but the table only actually enumerates two source states (`unbooked`, `booked`) transitioning to `cancelled`. There is no `completed → cancelled` row, and no row at all for cancelling an already-`cancelled` request.
- **Spine:** AD-3 states `cancel_request_dispatcher` enforces "state-machines.md's transition table" with no additional clarification.
- **Gap:** If `cancel_request_dispatcher` is implemented literally against the enumerated table rows (a reasonable reading of "enforcing the transition table"), it will reject cancellation of a `completed` request — directly contradicting CAP-10's "regardless of its current status." The spine should have added an `[ADOPTED]` rule resolving this ambiguity (the same way AD-4 explicitly resolved the CAP-3/CAP-13 tension) but didn't.

### 3. [MEDIUM] CAP-12's "reverts to unbooked if none available" branch never appears as spine prose — only reachable by indirect pointer

- **SPEC:** Both CAP-12's success line and state-machines.md's `booked → unbooked...` row spell out the no-eligible-driver fallback explicitly: "...or reverts to `unbooked` if none is available."
- **Spine:** The Capability → Architecture Map row for CAP-12 just says "`cancel_request_driver` RPC (reassignment branch) | AD-3, AD-6." AD-6 — the rule the spine itself dedicates to this exact mechanic — discusses transactional consistency of the "reassignment search" but never once mentions the no-driver-found outcome. The only place this branch is reachable from is AD-3's generic "each enforcing state-machines.md's transition table" clause, i.e., by reference only, never restated.
- **Risk:** Low-to-medium on its own (the companion doc still contains it), but it is precisely the kind of specific branch an AD-structured summary silently drops, per the review brief's own example — worth an explicit one-line callout in AD-6 or AD-3 rather than relying entirely on the reader following the reference.

### 4. [MEDIUM] "Active driver" — the pool CAP-12/state-machines.md reassignment draws from — has no schema representation and no ADOPTED definition

- **SPEC:** CAP-12's success line and state-machines.md both gate reassignment on "the **active** driver with the highest completed-rides count." SPEC.md's Assumptions section repeats "active drivers" as the reassignment pool.
- **Spine:** The `PROFILES` entity (Structural Seed → Core entities) has exactly four columns: `id`, `role`, `full_name`, `completed_rides_count`. There is no `is_active`/`status`/`last_seen` column or anything else that could distinguish an "active" driver from an inactive one.
- **Gap:** The spine silently assumes "active driver" == "any row with `role = 'driver'`" but never states this as an `[ADOPTED]` rule. This is exactly the kind of assumption the review brief calls out as easy to drop — the SPEC package uses "active" as a load-bearing qualifier three separate times, and the spine's schema has nothing to hang it on.

### 5. [LOW-MEDIUM] The completed-rides tie-break's actual concurrency mechanism is under-specified relative to how central the spine claims it is

- **Spine's own scope line** (frontmatter) names "the realtime sync contract and the CAP-7/CAP-12 completed-rides priority mechanic **above all**" as the thing this document exists to protect. AD-6's rule is: read `completed_rides_count` "inside the same transaction that performs the resulting status/driver_id write."
- **Gap:** Standard row-level locking (e.g., `UPDATE relocation_requests SET status='booked', driver_id=... WHERE id=... AND status='unbooked'`) resolves two concurrent `book_request` calls by **lock-acquisition order**, not by comparing the two drivers' completed-rides counts — the two transactions never see each other's candidate driver at all under normal SQL isolation. Actually implementing "the driver with more completed rides wins" under true concurrency requires either a compare-and-steal step after the loser detects the row is already taken, or serializing both attempts through a single arbitration point — neither of which AD-6 mentions. As written, AD-6 could be satisfied by a naive first-lock-wins `book_request` that never compares counts, silently failing CAP-7's actual success criterion under real concurrency (as opposed to the far more common demo case: two sequential clicks, where the rule is moot anyway).

### 6. [WORTH FLAGGING, not necessarily a defect] AD-4's owner-scoping of CAP-3 is a genuine textual contradiction of SPEC.md, even though labeled intentional

- **SPEC:** CAP-3 says, verbatim, dispatcher "views **all** relocation requests" and the list "renders **every** request" — no ownership qualifier anywhere in CAP-3's intent/success text. CAP-10 similarly says dispatcher "cancels an existing relocation request at any time" with no ownership qualifier.
- **Spine:** AD-4 reinterprets both as scoped to `created_by = auth.uid()`, justified by reconciling CAP-3 against CAP-13's phrase "one of *their* requests." It's explicitly tagged `[ADOPTED]` and "adopted from user correction," so this may already reflect an out-of-band stakeholder decision this reviewer can't see.
- **Why flag anyway:** Taken from the SPEC package alone, "one of their requests" in CAP-13 is equally readable as "the request whose creating-dispatcher should be notified" (i.e., targeting *notification delivery*, not *list visibility*) — a shared-board reading of CAP-3 (all dispatchers see the whole board, like CAP-6's shared driver gig pool) is at least as plausible as AD-4's owner-scoped reading, and arguably more natural for a dispatch coordination tool. Since this measurably shrinks CAP-3's and CAP-10's literal scope, it's worth a final confirmation pass against whatever "user correction" AD-4 references, in case the correction only ever addressed CAP-13 and not CAP-3/CAP-10 by name.

---

## Confirmed correct (explicitly checked, no gap found)

- **"Publicly visible repository" singularity (Constraints):** Spine correctly reads SPEC.md's "a publicly visible repository" as singular and converts it into an explicit rule — "Repo layout is **one monorepo**, not two separate repos" (Consistency Conventions row + source tree comment "one monorepo, one public GitHub/GitLab repo"). No gap.
- **24h-block error copy:** The exact blocked-cancellation message is carried through into the Consistency Conventions row ("Too close to the ride to cancel (within 24h)."), matching state-machines.md's blocked-transition row.
- **Non-goal — no dispatcher-picks-driver feature:** Not explicitly restated as a non-goal in the spine's Deferred section, but structurally enforced: no RPC accepts a dispatcher-supplied target driver, and `driver_id` has no client-facing UPDATE grant at all (AD-3). Effectively unbuildable by construction — acceptable.
- **Non-goals (app-store publishing, test suite, payments/ratings/chat/multi-tenant):** All correctly reflected or structurally absent; Deferred section explicitly cites "Automated test suite — explicitly a non-goal per SPEC.md."
- **Assumptions 1, 3, 4** (seed accounts + app-of-signup role governs new signups; DB-transactional tie-break not a distributed queue; "completed" is a manual driver action) are all captured, via AD-2, AD-6, and the CAP-14 mapping respectively.
- **All 14 capabilities** appear in `binds:` and in the Capability → Architecture Map — no capability was dropped outright.
- **Stack deviations** (Vercel-only vs. stack.md's "Vercel or Netlify") are within stack.md's explicitly stated "you may deviate with good reason" latitude — not a contradiction.

## Not evaluated (out of scope for this pass)

- `DESIGN.md` / `EXPERIENCE.md` (UX companion sources cited by the spine) were not re-read for this pass — the task scoped this reconciliation to the SPEC package only. The "modern and polished" visual-design constraint and the exact wording of banner/inline copy are presumably owned there rather than by the spine.
- `docs/brief.md` (SPEC.md's own upstream source, for narrative rationale only) was not consulted; not needed for a SPEC-vs-spine reconciliation.
