# Story 2.1: App Shell, Design Tokens, Login & Role Claiming

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a dispatcher opening the app for the first time,
I want to sign in with Google and land in a branded, navigable app shell,
so that I have a working, on-brand starting point for everything else I need to do.

## Acceptance Criteria

1. **Given** the Vue 3 + Vite + Tailwind project is scaffolded, **when** this story is complete, **then** the DESIGN.md token set (colors, typography, spacing, rounded scale, elevation) is wired into the Tailwind config and available to every component built afterward (UX-DR1-4).
2. **Given** an unauthenticated visitor opens the dispatcher web app, **when** the app loads, **then** they see the Login view — a Google OAuth button and one line explaining that signing up here creates a dispatcher account.
3. **Given** an unauthenticated visitor clicks the Google OAuth button, **when** the OAuth flow completes successfully for the first time, **then** the app calls `claim_role('dispatcher')`, then redirects to the Requests view (CAP-1).
4. **Given** an unauthenticated visitor's OAuth attempt fails, **when** the failure occurs, **then** they see "We couldn't sign you in — try again," remaining on Login (non-blocking, distinct from the generic post-auth network banner).
5. **Given** a signed-in dispatcher, **when** they view the app shell, **then** a fixed 220px sidebar shows Requests, Notifications, and an Account footer item (signed-in identity + sign out), with an accent-tint background and left-edge indicator on the active item (never accent-colored label text).
6. **Given** the dispatcher web app is viewed below the 1024px width floor, **when** the viewport is measured, **then** a "best viewed on a larger screen" notice is shown instead of a responsive reflow (UX-DR13).
7. **Given** any interactive element in the shell (nav items, the OAuth button), **when** it receives keyboard focus, **then** a 2px accent-colored focus ring with 2px offset is visible (UX-DR20).
8. **Given** a keyboard user on the dispatcher web app, **when** they tab through the page, **then** a skip-to-content affordance or `<main>`/`<nav>` landmark structure lets them bypass re-tabbing the sidebar on every navigation (UX-DR14).
9. **Given** any interactive control on the dispatcher web app, **when** it renders, **then** its hit area is ≥32×32px, and every icon-only affordance built anywhere in this epic (the modal ✕, chevrons, etc.) carries an accessible label (UX-DR24) — **this baseline applies to every subsequent story in this epic**.

## Tasks / Subtasks

- [ ] Task 1 — Wire DESIGN.md's tokens into Tailwind v4 (AC: #1)
  - [ ] Colors: for every entry under DESIGN.md's `colors:` frontmatter (24 total — surfaces, borders, text, accent, focus-ring, and the four status families), add `--color-{name}: {hex};` to the `@theme` block in the main CSS file (e.g. `--color-surface-canvas: #FAF6F0; --color-accent: #BF582A; --color-status-unbooked-text: #8A5A0A;` ...). This generates `bg-{name}`/`text-{name}`/`border-{name}` utilities directly from DESIGN.md's own names — no renaming needed.
  - [ ] Typography: for each of the 6 named styles (display, heading, body, body-strong, meta, label), define as a **paired** theme entry so one utility class carries size + weight + tracking together — e.g. `--text-display: 24px; --text-display--font-weight: 700; --text-display--letter-spacing: -0.01em;` — giving a single `text-display` class rather than combining `text-[24px] font-bold tracking-tight` by hand everywhere. Apply the same pattern for heading/body/body-strong/meta/label (see Dev Notes for the full list of pairs needed).
  - [ ] Rounded: `--radius-xs: 10px; --radius-sm: 12px; --radius-md: 16px; --radius-lg: 22px;` — `rounded-full` needs no override, Tailwind's built-in already matches (9999px).
  - [ ] Spacing: **do not** override Tailwind's built-in numbered spacing scale (`--spacing-7`, `--spacing-8`, etc.) — see Dev Notes for why steps 7 and 8 specifically would silently collide with Tailwind's own defaults. Define DESIGN.md's 8-step scale under distinctly-named theme keys instead (e.g. `--spacing-flovi-1` through `--spacing-flovi-8`), used as `p-flovi-6`, `gap-flovi-3`, etc.
  - [ ] Elevation: define the two shadow levels (flat = none, raised = soft warm-toned shadow) as a reusable utility/class — DESIGN.md specifies the raised shadow is warm-toned and soft, explicitly never a hard black drop shadow

- [ ] Task 2 — Supabase client, router, and the dedicated `/auth/callback` route (AC: #2, #3, #4)
  - [ ] Neither Vue Router nor a Supabase client exists yet — Story 1.1's scaffold was bare `npm create vite -- --template vue`. Install `vue-router@4` and `@supabase/supabase-js`.
  - [ ] `src/lib/supabase.ts` (per the architecture's source tree) — single client init, `auth: { flowType: 'pkce', detectSessionInUrl: true }`
  - [ ] Router with routes: `/login`, `/auth/callback` (dedicated, not the SPA root — per AD-2/Story 1.6's PKCE setup, and registered in Supabase's Redirect URLs at `http://localhost:5173/auth/callback`), `/requests` (default authenticated landing), `/notifications`. A navigation guard redirects unauthenticated visitors to `/login` and authenticated visitors away from `/login`.
  - [ ] `src/composables/useAuth.ts` (per source tree) — session state, `signInWithGoogle()`, `signOut()`, and the `claim_role` call

- [ ] Task 3 — `claim_role` call and its failure modes (AC: #3, #4)
  - [ ] Call **exactly** `supabase.rpc('claim_role', { p_role: 'dispatcher' })` — this parameter name is a fixed cross-epic contract pinned in Story 1.1; do not rename it
  - [ ] Call this on every successful OAuth completion, not just a detected "first-time" one — Story 1.1 made `claim_role` idempotent for a same-role reclaim specifically so the client doesn't need first-time-detection logic at all. Simpler and removes a whole category of "was this really their first login" bugs.
  - [ ] **Handle the case Story 1.1's exception exists to produce, which neither this epics.md story nor EXPERIENCE.md names as a state**: if the signed-in Google account already holds the `driver` role, `claim_role('dispatcher')` will throw (by design, per AD-2). OAuth itself succeeded here — this is a different failure than AC #4's OAuth-failure case. Recommend (not a sourced verbatim string, since no fixed microcopy exists for this state) something in EXPERIENCE.md's voice: "This Google account is already registered as a driver — sign in through the driver app instead." Sign the user back out and return them to Login rather than leaving them in a half-authenticated state.
  - [ ] OAuth-failure copy (AC #4) **is** verbatim-fixed, quoted identically in both epics.md and EXPERIENCE.md's State Patterns table: `"We couldn't sign you in — try again."`

- [ ] Task 4 — App shell: sidebar, landmarks, responsive floor (AC: #5, #6, #8)
  - [ ] Sidebar exactly per DESIGN.md's component recipe: fixed 220px, `<nav>` element, 12px-rounded nav-item rows, `accent-tint` background on the active item, active item's **label text stays `text-primary`** (never accent-colored — DESIGN.md is explicit this avoids a low-contrast tinted-background-plus-hued-text pairing), accent hue appears only as a small left-edge indicator bar plus the notifications count badge
  - [ ] Wrap the main content region in a `<main>` element — combined with the `<nav>` sidebar, this alone satisfies AC #8's landmark-structure option; a separate visually-hidden skip link is equally valid but not required if these two landmarks are in place
  - [ ] 1024px floor (AC #6): Tailwind's own default `lg:` breakpoint **is already exactly 1024px** — no custom breakpoint needed. Show the real app shell as `hidden lg:flex` and the "best viewed on a larger screen" notice as `lg:hidden` (visible below 1024px, hidden at/above)

- [ ] Task 5 — Focus ring baseline + icon-button min-size component (AC: #7, #9)
  - [ ] Apply the focus ring via the `focus-visible:` variant, not bare `focus:` — shows the ring for keyboard navigation, not on every mouse click, which is what "visible focus ring" accessibility guidance actually wants. `focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring` (using the `--color-focus-ring` token from Task 1) on every interactive element in this story (OAuth button, sidebar nav items)
  - [ ] Since AC #9 explicitly applies to "every subsequent story in this epic," build a small shared icon-button component now (rather than letting each later story re-derive the constraint) that structurally enforces a `min-w-8 min-h-8` (32px, Tailwind's own built-in step-8 value — no collision here, this is a min-size constraint not part of the spacing-scale override) hit area and a required accessible-label prop, so future stories can't accidentally ship an unlabeled icon-only control

## Dev Notes

### The spacing-scale collision (verified, not guessed)
DESIGN.md's 8-step scale is 4/8/12/16/20/24/32/40px. Tailwind v4's own built-in numbered spacing scale (`p-1`...`p-8`, derived from its `0.25rem` base unit) produces steps 1–6 that happen to be **identical** to DESIGN.md's (4,8,12,16,20,24px — no override needed there), but its own `p-7` = 28px and `p-8` = 32px, while DESIGN.md's 7th and 8th steps are 32px and 40px respectively. Using bare `p-7`/`p-8` anywhere would silently apply the *wrong*, slightly-smaller Tailwind default instead of DESIGN.md's intended larger gaps — a subtle, hard-to-notice-by-eye mismatch rather than an obvious break. Defining the full scale under distinct custom keys (Task 1) avoids the ambiguity entirely rather than gambling on whether Tailwind v4 supports overriding some numbered keys while leaving others computed from the base multiplier.

### Full typography pairing list (Task 1)
| Style | size | weight | extra |
| --- | --- | --- | --- |
| display | 24px | 700 | letter-spacing -0.01em |
| heading | 18px | 700 | — |
| body | 14px | 500 | — |
| body-strong | 14px | 700 | — |
| meta | 12.5px | 600 | — |
| label | 11.5px | 700 | letter-spacing 0.03em, uppercase applied separately (`uppercase` utility — theme pairing doesn't cover text-transform) |

### Why `claim_role` is called unconditionally, not gated on "is this a new user"
This was a deliberate design choice made in Story 1.1, not something this story needs to re-derive: making the RPC idempotent for a same-role reclaim means the client can call it after *every* successful sign-in with no first-time-detection logic at all. Building client-side "is this really their first login" detection here would be solving a problem Story 1.1 already solved server-side — don't duplicate it.

### The role-mismatch UX gap (flagged, not sourced)
Unlike Story 1.4's notification microcopy (pulled verbatim from EXPERIENCE.md), there is no fixed copy anywhere for "a driver-registered Google account tried to sign into the dispatcher app." This is a real scenario worth handling deliberately rather than leaving as an unhandled thrown exception — it's exactly the kind of thing likely to actually happen once during rehearsal (the operator signing into the wrong app with the wrong test Google account) if not handled gracefully now. The recommended copy above is a reasoned inference in EXPERIENCE.md's established voice (plain sentence, no urgency), not a verbatim requirement.

### Previous/Cross-Epic Story Intelligence
- Story 1.1 pinned the `claim_role(p_role, ...)` contract — this story is the first actual caller of it; get the parameter name exactly right (`p_role`, not `role`).
- Story 1.6 already registered `http://localhost:5173/auth/callback` in Supabase's Redirect URLs and configured the Google provider — this story's dev-server port must stay the Vite default (5173) to match what was already registered, or the redirect will fail with a mismatch.
- No commits exist yet in this repo as of this story's creation — Epic 1 and this story may be implemented in either order relative to each other, but this story's runtime behavior depends entirely on Epic 1's backend actually existing when tested.

### Testing standards summary
No automated test suite in scope. Manually verify: Login view renders for an unauthenticated visitor; Google OAuth completes and lands on Requests; a deliberately-failed OAuth attempt shows the fixed failure copy; signing in with a driver-role test account on this app shows the role-mismatch message instead of a raw error; the shell collapses to the "best viewed on a larger screen" notice below 1024px; tabbing through the page shows a visible focus ring on every interactive element and reaches `<main>` without excessive re-tabbing through the sidebar.

### Project Structure Notes
```
apps/dispatcher-web/
  src/
    lib/supabase.ts        # new — single client init
    composables/useAuth.ts # new
    views/                 # Login, Requests (shell only for now), Notifications (shell only for now)
    components/            # shared IconButton (Task 5), sidebar nav item
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 2.1: App Shell, Design Tokens, Login & Role Claiming]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — full token set, Sidebar nav item / Focus ring components]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — State Patterns (OAuth failure copy), Voice and Tone]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Source tree, Stack]
- [Source: _bmad-output/implementation-artifacts/1-1-profiles-schema-role-claiming-rpc.md — `p_role` contract, `claim_role` idempotency]
- [Source: _bmad-output/implementation-artifacts/1-6-realtime-publication-seed-data-auth-configuration.md — registered local-dev redirect URL, two-layer OAuth setup]
- [External: Tailwind CSS v4 theme variables (`--color-*`, `--text-*` paired properties, `--radius-*`) — https://tailwindcss.com/docs/theme]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
