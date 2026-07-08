# Story 2.3: Create & Edit Request via Modal

Status: ready-for-dev

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

- [ ] Task 1 — Build the modal on native `<dialog>`, not a hand-rolled div (AC: #3, #4)
  - [ ] Use `<dialog>` + `showModal()`/`close()` rather than a custom `position: fixed` overlay div with manual keydown-based focus trapping. Verified: `showModal()` marks the rest of the page `inert` and natively cycles Tab/Shift+Tab only among the dialog's own focusable elements — this satisfies AC #4 directly, with far less code and far fewer edge cases than a hand-rolled trap (missed dynamically-added focusable elements, forgotten Shift+Tab wraparound, etc. are exactly the class of bug a hand-rolled trap tends to have).
  - [ ] Escape-to-close and the overlay/`::backdrop` are both native to `<dialog>` — but backdrop-*click*-to-close still needs one manual check: a click on the backdrop bubbles to the `<dialog>` element itself (since it fills the viewport when shown), so compare `event.target === dialogEl` (true only when the click landed on the backdrop, not on the card content nested inside) to decide whether to call `close()`
  - [ ] Explicitly capture `document.activeElement` before calling `showModal()` and restore focus to it after `close()` — don't rely on the browser to do this implicitly, behavior here isn't universally guaranteed across all close paths

- [ ] Task 2 — Two distinct initial-focus behaviors (AC: #1, #2)
  - [ ] Create mode: focus the Origin input after `showModal()`
  - [ ] Edit mode: focus the **modal heading**, not any form field — give the heading `tabindex="-1"` (headings aren't natively focusable) and call `.focus()` on it explicitly after `showModal()`. This asymmetry is deliberate, not an inconsistency to "fix" — it's easy to wire both modes to the same first-field focus by habit; don't.

- [ ] Task 3 — Validation (AC: #5)
  - [ ] Required: Origin, Destination, Scheduled date. Notes is free-text and optional (nothing in any capability requires it, and epics.md's "e.g. Origin" phrasing implies Origin is one example among the actually-required set, not the only one)
  - [ ] On Save with any required field blank: inline error text directly under each invalid field (icon + text, not color-only), `aria-describedby` linking field → error, focus moves to the **first** invalid field, modal stays open, entered values are preserved (don't clear the form on a failed validation attempt)

- [ ] Task 4 — Create/Edit persistence and list update (AC: #6, #7)
  - [ ] Both are **direct client-side table operations, not RPCs** — Story 1.2 designed this table's create/edit path as a plain RLS-gated `INSERT`/`UPDATE`, unlike the state-transition operations (booking, cancelling, completing) which go through `SECURITY DEFINER` RPCs. Create: `.from('relocation_requests').insert({ origin, destination, scheduled_date, notes }).select().single()` (`created_by`/`status`/`driver_id` are forced server-side by Story 1.2's trigger — don't send them). Edit: `.from('relocation_requests').update({ origin, destination, scheduled_date, notes }).eq('id', requestId).select().single()` — these are **exactly** the four columns Story 1.2's column-level `GRANT UPDATE(...)` allows the client to touch; this alignment isn't a coincidence, it's why this modal only ever edits these four fields.
  - [ ] Update local list state directly from the insert/update call's own returned row — **don't wait for the realtime echo** of this same change as the primary feedback mechanism. Story 2.2's realtime subscription will also receive this exact change (the dispatcher's own write satisfies their own RLS), so make the local merge idempotent (key by `id`, update-in-place rather than blind-append) — the realtime echo arriving a moment later is then a harmless no-op, not a duplicate. Relying solely on realtime round-trip latency for "the card updates immediately" risks a visible stutter if the channel has any hiccup at that exact moment — a real risk during a live demo, since this exact moment (an edit landing instantly) is Flow 1's scripted climax.

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

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
