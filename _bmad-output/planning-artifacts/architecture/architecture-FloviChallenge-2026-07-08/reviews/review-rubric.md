---
name: 'Review — Flovi Relocation-Dispatch Architecture Spine'
type: review
reviews: '../ARCHITECTURE-SPINE.md'
against: 'good-spine checklist (7 items)'
created: '2026-07-08'
verdict: 'PASS with two Should-Fix findings'
---

# Review — ARCHITECTURE-SPINE.md vs. good-spine checklist

Target: `_bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md`
Driving spec: `_bmad-output/specs/spec-relocation-dispatch/SPEC.md` (+ `state-machines.md`, `stack.md`, `challenge-context.md`)
Cross-checked against: `_bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md`

## Overall verdict

The spine is well-formed, sequential, and mostly enforceable. It correctly identifies and locks down four of the five real divergence points (role assignment, single write path, ownership scoping, realtime vocabulary). One of the six ADs (AD-6, the completed-rides priority mechanic) makes a narrower guarantee than its own "Prevents" claim and the spine's stated top priority actually require, and one shared-behavior promise from the Design Paradigm (notification creation "lives exactly once in Postgres") has no backing AD/Rule. Neither is fatal for a 4-hour demo, but both are worth a one-line tightening before build starts.

---

## 1. Real divergence points — fixed, none missed

Covered and enforceable: auth/role assignment (AD-2), write-path/state-machine (AD-3), data visibility/ownership scoping (AD-4), realtime vocabulary (AD-5), naming/status-enum/error-copy conventions (Consistency Conventions table). Error-copy convention spot-checked against `EXPERIENCE.md` line 93 ("Too close to the ride to cancel (within 24h)." ) — verbatim match, good.

**Gap found:** The Design Paradigm section explicitly lists "notification creation" as one of the behaviors that must "live exactly once, in Postgres, never duplicated in Dart or JS" — but no AD actually backs this promise for the `notifications` table. AD-3's UPDATE-grant revocation only covers `relocation_requests.status`/`.driver_id`; AD-4 only addresses `notifications` *read* scoping (`dispatcher_id`-scoped SELECT). There is no stated Rule revoking client-facing INSERT on `notifications`, and no AD names which RPC (presumably `cancel_request_driver`'s reassignment branch) performs the notification INSERT, or that it happens in the same transaction as the reassignment write. A client could, absent an explicit REVOKE, insert a fabricated notification row directly via the SDK. **Severity: Should-fix** — cheap to close (one sentence in AD-3 or AD-4: "client-facing INSERT/UPDATE on `notifications` is revoked; only `cancel_request_driver` writes it, in the same transaction as the reassignment").

No other divergence point looks missed. Minor observation (not a finding): `EXPERIENCE.md` has driver-mobile pre-emptively disable the Cancel button based on its own ≥24h computation — a small piece of client-side duplication of the server's 24h guard (AD-3/`cancel_request_driver`). This is UI-only (the RPC error-copy convention catches any mismatch and still shows the correct banner), so it doesn't corrupt data or diverge the two apps from each other — just flagging that it's a rule computed in two places, one client, one server, for future awareness.

## 2. Every AD's Rule enforceable and actually prevents its stated divergence

AD-1, AD-2, AD-3, AD-4, AD-5 all pass: each Rule is concretely checkable (RPC signatures, GRANT/REVOKE statements, RLS policy predicates, subscription table/column lists) and each directly closes its own Prevents clause.

**Finding (Should-fix, most important in this review):** AD-6's Rule only guarantees that `completed_rides_count` is read inside the same transaction as the write that consumes it — this correctly prevents a *stale-read-across-a-client-round-trip* race, which is what its Prevents clause literally names. But it does not specify the mechanism for the actual cross-transaction tie-break CAP-7 requires: "if two drivers attempt to book the same gig concurrently, the driver with more completed rides is awarded it" (SPEC.md CAP-7). Two genuinely concurrent `book_request` calls are two separate Postgres sessions; reading-inside-your-own-transaction doesn't let session B see session A's in-flight (uncommitted) driver identity to compare ranks. A plain row-lock/optimistic-UPDATE-guard pattern (the obvious enforceable implementation of AD-3) resolves to **first-committer-wins**, not **highest-rank-wins**, for true concurrent arrivals. Achieving the literal spec behavior would require either (a) an explicit "steal if higher-rank" comparison against the current holder on every booking attempt — which has its own UX cost (a driver's confirmed booking can be silently reassigned moments later, in tension with CAP-7's "the winner's gig appears in their booked list"), or (b) accepting first-committer-wins as the demo-scoped approximation, per SPEC.md's own Assumptions ("true sub-second race conditions are unlikely in a live demo"). The spine's own scope line calls this mechanic out as the single most important thing it exists to get right ("the realtime sync contract and the CAP-7/CAP-12 completed-rides priority mechanic above all") — it deserves one explicit sentence naming which of (a)/(b) is intended, rather than leaving the builder to invent one under time pressure. This is not a cross-app divergence risk (the logic lives once, server-side, per AD-1) — it's a risk that the single implementation won't actually satisfy CAP-7/CAP-12's literal success criteria.

All other Prevents/Rule pairs verified consistent; no other enforceability gaps found.

## 3. Deferred section — safe to punt

All six Deferred items (CI/CD automation, observability/logging/monitoring, multi-environment split, rate limiting, automated test suite, OS-level push) are genuinely low-stakes for a 4-hour single-demo scope and are each explicitly licensed by SPEC.md's own Constraints/Non-goals or Assumptions. None of them touches a mechanism that could cause the two client apps to diverge on a capability. **No issues.**

## 4. Named tech — sanity check only (deep verification owned by another reviewer)

Nothing looks obviously broken, but two entries are worth a closer look by the dedicated tech-currency reviewer: **Vite `^8.1`** — Vite's major-version cadence has historically been much slower than reaching v8 by mid-2026 would imply; worth confirming this isn't a hallucinated jump. **`@supabase/supabase-js` `^2.110`** — plausible (supabase-js ships frequent minor bumps) but the minor number is unusually high; worth a quick confirm. Flutter `3.44`, Tailwind `^4.3`, `supabase_flutter` `^2.12` all look directionally reasonable and unremarkable.

## 5. Capability → Architecture Map coverage

All fourteen capabilities (CAP-1 through CAP-14) are present in the map, each with a "Lives in" location and a "Governed by" AD reference. No gaps, no duplicates. **Pass.**

## 6. Dimension coverage (deployment & environments, infra/provider, operations)

- **Deployment & environments:** decided — Structural Seed section states single Supabase project, no staging/prod split, one Google OAuth client with both apps' redirect URLs allow-listed, anon key safely client-side / service-role key never client-side. Deployment diagram shows two separate Vercel deployments from the one monorepo.
- **Infra/provider strategy:** decided — Supabase (single project: Auth+Postgres+Realtime) and Vercel (both static builds) are named with no open alternative.
- **Operations:** deliberately deferred (observability/monitoring, CI/CD) with an explicit, spec-backed rationale — acceptable, not silent.

No whole dimension is left undecided-and-unacknowledged. Minor gap noted only in passing: the source tree implies two Vercel projects pointing at one monorepo (root-directory-per-app), which is a standard, low-risk Vercel configuration but isn't spelled out as a sentence — not worth a finding, just noting it's inferred rather than stated.

## 7. Structural check

- **Frontmatter:** valid YAML, all expected keys present (`name, type, purpose, altitude, paradigm, scope, status, created, updated, binds, sources, companions`); `binds` lists CAP-1…CAP-14 matching the Capability Map; `sources` all resolve to real files (`SPEC.md`, `stack.md`, `state-machines.md`, `DESIGN.md`, `EXPERIENCE.md` all confirmed to exist). No template placeholders found (grepped for TODO/TBD/FIXME/lorem/`{{`/placeholder — zero hits).
- **Diagrams:** all three Mermaid blocks (component `graph LR`, deployment `graph TB`, `erDiagram`) are syntactically valid, non-empty, and render-able. Minor cosmetic note: in the component diagram, `AUTH` and `RT` nodes inside the `SB` subgraph have no explicit edges (they're informational members of the subgraph, not connected) — not a validity problem, just a slightly sparse diagram.
- **AD numbering:** AD-1 through AD-6, sequential, no duplicates, no gaps. **Pass.**
- **Binds/Prevents/Rule completeness:** every AD has all three fields present. **Minor structural inconsistency:** AD-4 orders its fields as Binds → Rule → Prevents → (extra) "Does not affect", while AD-1/2/3/5/6 all use Binds → Prevents → Rule with no extra field. Content is fine; only the field order/shape is inconsistent. Cosmetic, low priority.

---

## Summary of findings by priority

| # | Finding | Checklist item | Severity |
| --- | --- | --- | --- |
| 1 | AD-6's Rule prevents stale-read races but doesn't specify the actual cross-transaction tie-break mechanism CAP-7/CAP-12 require (first-committer-wins vs. steal-if-higher-rank) — needs one explicit sentence given the spine names this its top priority | 2 | Should-fix |
| 2 | "Notification creation lives exactly once in Postgres" (Design Paradigm) has no backing AD/Rule — no stated REVOKE on client-facing `notifications` INSERT, no named RPC for the write | 1, 2 | Should-fix |
| 3 | AD-4's field order (Binds→Rule→Prevents→extra "Does not affect") is inconsistent with all other ADs (Binds→Prevents→Rule, no extra field) | 7 | Nit |
| 4 | Vite `^8.1` and supabase-js `^2.110` versions look surprisingly high — flag for the dedicated tech-currency reviewer | 4 | Nit / sanity-check only |
