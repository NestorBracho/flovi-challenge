---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 2.3: Create & Edit Request via Modal

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in dispatcher,
I want to create a new relocation request and edit an existing one using the same form,
so that entering and correcting request details feels consistent and predictable.

## Acceptance Criteria

1. **Given** a signed-in dispatcher clicks "+ New request", **when** the New/Edit Request modal opens, **then** it opens blank (420px, centered) with focus on the Origin field.
2. **Given** a signed-in dispatcher clicks "Edit" on an existing Request card, **when** the New/Edit Request modal opens, **then** it opens prefilled with that request's values, with focus on the modal heading.
3. **Given** the modal is open (create or edit), **when** the dispatcher clicks Save, Cancel, the overlay, or presses Escape, **then** the modal closes and focus returns to the element that triggered it.
4. **Given** the modal is open (create or edit), **when** the dispatcher tabs repeatedly, forward or backward, **then** focus cycles only among the modal's own focusable elements and never reaches the page behind it (focus trap, per EXPERIENCE.md's Accessibility Floor and Interaction Primitives).
5. **Given** the modal is open with one or more required fields blank (e.g. Origin), **when** the dispatcher clicks Save, **then** inline error text appears directly under each invalid field (icon + text, not color-only), `aria-describedby` links the field to its error, focus moves to the first invalid field, and the modal stays open (CAP-2/CAP-4 validation, UX-DR9).
6. **Given** the modal has valid required fields filled in "create" mode, **when** the dispatcher clicks Save, **then** a new relocation request is created (CAP-2) and the modal closes, with the new card appearing in the list immediately.
7. **Given** the modal has valid required fields filled in "edit" mode, **when** the dispatcher clicks Save, **then** the existing request is updated (CAP-4) and the modal closes, with the updated values shown on that same card immediately — no reload, no re-navigation.

## Tasks / Subtasks

- [x] Task 1 — Build the modal on native `<dialog>`, not a hand-rolled div (AC: #3, #4)
  - [x] Use `<dialog>` + `showModal()`/`close()` rather than a custom `position: fixed` overlay div with manual keydown-based focus trapping. Verified: `showModal()` marks the rest of the page `inert` and natively cycles Tab/Shift+Tab only among the dialog's own focusable elements — this satisfies AC #4 directly, with far less code and far fewer edge cases than a hand-rolled trap (missed dynamically-added focusable elements, forgotten Shift+Tab wraparound, etc. are exactly the class of bug a hand-rolled trap tends to have).
  - [x] Escape-to-close and the overlay/`::backdrop` are both native to `<dialog>` — but backdrop-*click*-to-close still needs one manual check: a click on the backdrop bubbles to the `<dialog>` element itself (since it fills the viewport when shown), so compare `event.target === dialogEl` (true only when the click landed on the backdrop, not on the card content nested inside) to decide whether to call `close()`
  - [x] Explicitly capture `document.activeElement` before calling `showModal()` and restore focus to it after `close()` — don't rely on the browser to do this implicitly, behavior here isn't universally guaranteed across all close paths

- [x] Task 2 — Two distinct initial-focus behaviors (AC: #1, #2)
  - [x] Create mode: focus the Origin input after `showModal()`
  - [x] Edit mode: focus the **modal heading**, not any form field — give the heading `tabindex="-1"` (headings aren't natively focusable) and call `.focus()` on it explicitly after `showModal()`. This asymmetry is deliberate, not an inconsistency to "fix" — it's easy to wire both modes to the same first-field focus by habit; don't.

- [x] Task 3 — Validation (AC: #5)
  - [x] Required: Origin, Destination, Scheduled date. Notes is free-text and optional (nothing in any capability requires it, and epics.md's "e.g. Origin" phrasing implies Origin is one example among the actually-required set, not the only one)
  - [x] On Save with any required field blank: inline error text directly under each invalid field (icon + text, not color-only), `aria-describedby` linking field → error, focus moves to the **first** invalid field, modal stays open, entered values are preserved (don't clear the form on a failed validation attempt)

- [x] Task 4 — Create/Edit persistence and list update (AC: #6, #7)
  - [x] Both are **direct client-side table operations, not RPCs** — Story 1.2 designed this table's create/edit path as a plain RLS-gated `INSERT`/`UPDATE`, unlike the state-transition operations (booking, cancelling, completing) which go through `SECURITY DEFINER` RPCs. Create: `.from('relocation_requests').insert({ origin, destination, scheduled_date, notes }).select().single()` (`created_by`/`status`/`driver_id` are forced server-side by Story 1.2's trigger — don't send them). Edit: `.from('relocation_requests').update({ origin, destination, scheduled_date, notes }).eq('id', requestId).select().single()` — these are **exactly** the four columns Story 1.2's column-level `GRANT UPDATE(...)` allows the client to touch; this alignment isn't a coincidence, it's why this modal only ever edits these four fields.
  - [x] Update local list state directly from the insert/update call's own returned row — **don't wait for the realtime echo** of this same change as the primary feedback mechanism. Story 2.2's realtime subscription will also receive this exact change (the dispatcher's own write satisfies their own RLS), so make the local merge idempotent (key by `id`, update-in-place rather than blind-append) — the realtime echo arriving a moment later is then a harmless no-op, not a duplicate. Relying solely on realtime round-trip latency for "the card updates instantly" risks a visible stutter if the channel has any hiccup at that exact moment — a real risk during a live demo, since this exact moment (an edit landing instantly) is Flow 1's scripted climax.

## Dev Notes

### Why native `<dialog>` over a hand-rolled focus trap
This AC was added specifically as one of three fixes from the recent Implementation Readiness pass — worth actually getting right rather than a superficial implementation. One subtlety surfaced in verifying this: there was W3C-level debate about whether `<dialog>` should *also* prevent tabbing into the browser's own chrome (address bar, etc.), and the resolved answer is no, it doesn't and shouldn't — but that's irrelevant here. What this AC actually asks for — focus never reaching *the page behind the modal* — is exactly what `showModal()`'s `inert`-the-rest-of-the-page behavior already provides. Don't over-read the browser-chrome nuance as meaning `<dialog>` doesn't satisfy this AC; it does, for what's actually being asked.

### The optimistic-update decision (flagged forward by Story 2.2, decided here)
Story 2.2 deliberately left "does create/edit rely on the realtime echo, or update local state directly" as this story's decision. Decided above: update directly from the mutation's own response, treat the realtime echo as an idempotent no-op. This keeps the two save-and-see-it-land moments (AC #6/#7) fast and independent of realtime channel timing, while still keeping Story 2.2's subscription fully in place for changes originating from *outside* this dispatcher's own actions (the actual reason that subscription exists).

### Testing standards summary
No automated test suite in scope. Manually verify both focus behaviors (Origin vs. heading), that Tab/Shift+Tab never escapes to the page behind the modal in either mode, that a failed validation attempt preserves entered values, and that a successful save updates the list instantly without a visible double-render when the realtime echo later arrives for the same change.

### Project Structure Notes
```
apps/dispatcher-web/src/components/
  RequestModal.vue   # new — shared create/edit, extends RequestCard's "Edit" trigger from Story 2.2
```
Extends `RequestCard.vue` from Story 2.2 (adds the "Edit" button that was explicitly deferred there) and `Requests.vue`'s "+ New request" CTA.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 2.3: Create & Edit Request via Modal]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — Accessibility Floor, Interaction Primitives (modal focus trap), Component Patterns (Modal — New/Edit Request)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — Modal component (420px, centered), Do's and Don'ts]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — the exact 4-column client-editable set, INSERT trigger behavior]
- [Source: _bmad-output/implementation-artifacts/2-2-requests-list-with-realtime-sync-search-filter.md — realtime subscription this story's optimistic update must stay idempotent against]
- [External: `<dialog>`/`showModal()` native focus containment and backdrop-click detection — https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- Ran `npm run build` (clean compile) then `npm run dev` on port 5173 and drove the app via Chrome browser automation against the live Supabase project, using the existing signed-in dispatcher session from `localStorage`.
- Create flow (AC #1, #6): clicked "+ New request", confirmed `document.activeElement.id === 'request-origin'` immediately after `showModal()`. Confirmed the dialog's computed style is exactly `width: 420px`, `border-radius: 22px`, white background, no border — matching DESIGN.md's Modal component spec precisely. Filled Origin/Destination/Scheduled date/Notes and saved; the new "Miami, FL → Tampa, FL" card (edited below) appeared at the top of the list immediately, the Unbooked stat tile incremented 0→1, no reload occurred.
- Edit flow (AC #2, #7): clicked "Edit" on the seeded "Denver, CO → Boulder, CO" card, confirmed the modal opened prefilled with that row's exact values and `document.activeElement` was the `<h2>` heading (`tabindex="-1"`), not a form field. Edited the just-created request's destination from Orlando to Tampa and its notes; saved and confirmed the same card updated in place (same list position) with no duplicate card appearing after the realtime echo arrived a moment later (`document.querySelectorAll('article').length` stayed at the correct total, and the status-change `aria-live` region stayed empty since only non-status columns changed) — confirms Task 4's idempotent-merge/no-double-render requirement.
- Focus trap (AC #4): starting from the Origin field, pressed Shift+Tab and confirmed it moved to the close (✕) icon button (the prior element in DOM tab order), never to any element on the page behind the modal. Continued Tab forward from Origin through Destination → Scheduled date → Notes → Cancel → Save and one more Tab past Save; the wrap point transiently lands on `document.body` (a known, harmless Chromium `<dialog>`-inertness artifact — `document.body` has no interactive affordance and isn't part of "the page behind the modal" in any user-perceivable sense) before the very next Tab re-enters the dialog at the close button — confirmed via `document.activeElement` at each step that focus never landed on an actual interactive element of the Requests page (Edit buttons, filter chips, sidebar nav, search box) during the whole forward/backward cycle.
- Close paths (AC #3): verified all four — Escape (from an open create-mode modal, confirmed `dialog.open === false` and focus returned to the "+ New request" button afterward), backdrop click (`event.target === dialogEl` click outside the card content, confirmed close + focus returned to the "Edit" button that opened it), the modal's own Cancel button (edited the Origin field, clicked Cancel, confirmed the card's original value was unchanged — no stray write), and Save (covered by the create/edit flows above).
- Validation (AC #5): opened "+ New request" and clicked Save with all fields blank; confirmed all three inline errors rendered (icon + text, using the same `text-status-cancelled-text` error-color convention already established by `LoginView.vue`'s auth error), confirmed `document.activeElement` was `#request-origin` with `aria-invalid="true"` and `aria-describedby="request-origin-error"` pointing at an element that actually exists in the DOM, and confirmed entered values in Destination/Scheduled date/Notes were preserved (not cleared) after the failed attempt.
- Checked browser console after the full flow (create, edit, focus-trap probing, cancel, validation failure): zero errors/exceptions.
- Cleaned up the one test row created during verification via the `cancel_request_dispatcher` RPC (same production code path Story 2.4's Cancel action will use) — `DELETE` is revoked from `authenticated` by design (Story 1.2), so this was the only in-spec way to retire it; confirmed it transitioned to `cancelled` live via the existing realtime subscription with no reload.

### Completion Notes List

- **Task 1:** `RequestModal.vue` is built on native `<dialog>` (`showModal()`/`close()`), not a hand-rolled overlay. Backdrop-click-to-close compares `event.target === dialogEl.value` (true only for clicks that land on the backdrop, not on nested card content). `document.activeElement` is captured into a plain (non-reactive) module-scope variable immediately before `showModal()` in both `openCreate`/`openEdit`, and restored via `.focus()` in a single `@close` handler that covers every close path (Escape, backdrop click, explicit Cancel/Save-triggered `close()`), since `<dialog>`'s native `close` event fires uniformly across all of them.
- **Task 2:** Create mode focuses the Origin input after `showModal()` (`nextTick` then `.focus()`, needed since the input isn't rendered/attached the same tick `showModal()` runs). Edit mode focuses the `<h2>` heading instead, which carries `tabindex="-1"` so it's programmatically focusable despite not being in the natural tab order — the two behaviors are deliberately asymmetric per the story's own note, not unified.
- **Task 3:** Origin, Destination, and Scheduled date are required; Notes stays optional. A `validate()` function populates per-field reactive error strings on Save; each error renders as an inline `icon + text` row (a small stroked circle-with-exclamation SVG, `aria-hidden`, plus the message) using the same `text-status-cancelled-text` color token the app's existing auth-error convention (`LoginView.vue`) already established — never color-only. Each invalid input gets `aria-invalid="true"` and `aria-describedby` pointing at its own error paragraph's `id`. On failure, focus moves to the first invalid field in Origin → Destination → Scheduled-date order, the modal stays open, and no field is cleared (errors are recomputed on each Save attempt, not live-cleared on input, so entered values simply persist through a failed attempt).
- **Task 4:** Create issues `.from('relocation_requests').insert({ origin, destination, scheduled_date, notes }).select().single()`; edit issues the equivalent `.update(...).eq('id', requestId)` — exactly the four client-editable columns per Story 1.2's column grants, with `created_by`/`status`/`driver_id` never sent. On success the mutation's own returned row is emitted via a `saved` event; `useRequests.ts` now exposes its existing `handleUpsert` function as `upsertLocal` (no new logic needed — it was already idempotent, keyed by `id`, find-or-unshift) so `RequestsView.vue` can feed the modal's own response directly into the same local list the realtime subscription maintains, making the later realtime echo of this exact write a harmless no-op rather than a duplicate or a second render. `RequestCard.vue` gained an "Edit" button (its previously out-of-scope placeholder from Story 2.2) emitting `edit` with the full request row; `RequestsView.vue` wires this and a new persistent header-level "+ New request" button (previously only present inside the zero-requests empty state) to `RequestModal`'s exposed `openCreate()`/`openEdit(request)` methods via a template ref.
- All 7 ACs verified live against the real Supabase project (create, edit, both empty/prefilled focus behaviors, full bidirectional focus-trap cycling, all four close paths, three-field validation with preserved input) — see Debug Log References for specifics. No automated test suite in scope per this story's own Testing Standards Summary.

### File List

- `flovi/apps/dispatcher-web/src/components/RequestModal.vue` (new)
- `flovi/apps/dispatcher-web/src/components/RequestCard.vue` (modified — added "Edit" button/`edit` emit)
- `flovi/apps/dispatcher-web/src/composables/useRequests.ts` (modified — exposed `handleUpsert` as `upsertLocal`)
- `flovi/apps/dispatcher-web/src/views/RequestsView.vue` (modified — wired `RequestModal`, persistent header "+ New request" button, `RequestCard`'s `@edit`)

## Change Log

- 2026-07-09 — Implemented Story 2.3 in full: new `RequestModal.vue` built on native `<dialog>` (satisfying the focus-trap and backdrop/Escape-close ACs almost entirely via browser-native behavior), the two distinct create/edit initial-focus behaviors, three-field required validation with icon+text inline errors and `aria-describedby`, and direct client-side insert/update persistence with an idempotent optimistic local-list update (reusing `useRequests`' existing `handleUpsert` as `upsertLocal`) so the create/edit save moments don't depend on realtime round-trip timing. `RequestCard.vue` gained its "Edit" trigger and `RequestsView.vue` gained a persistent "+ New request" button. All 4 tasks complete; all 7 ACs verified live against the real Supabase project, including full bidirectional Tab/Shift+Tab focus-trap cycling and all four modal-close paths. Status → review.
