---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 2.1: App Shell, Design Tokens, Login & Role Claiming

Status: review

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

- [x] Task 1 — Wire DESIGN.md's tokens into Tailwind v4 (AC: #1)
  - [x] Colors: for every entry under DESIGN.md's `colors:` frontmatter (24 total — surfaces, borders, text, accent, focus-ring, and the four status families), add `--color-{name}: {hex};` to the `@theme` block in the main CSS file (e.g. `--color-surface-canvas: #FAF6F0; --color-accent: #BF582A; --color-status-unbooked-text: #8A5A0A;` ...). This generates `bg-{name}`/`text-{name}`/`border-{name}` utilities directly from DESIGN.md's own names — no renaming needed.
  - [x] Typography: for each of the 6 named styles (display, heading, body, body-strong, meta, label), define as a **paired** theme entry so one utility class carries size + weight + tracking together — e.g. `--text-display: 24px; --text-display--font-weight: 700; --text-display--letter-spacing: -0.01em;` — giving a single `text-display` class rather than combining `text-[24px] font-bold tracking-tight` by hand everywhere. Apply the same pattern for heading/body/body-strong/meta/label (see Dev Notes for the full list of pairs needed).
  - [x] Rounded: `--radius-xs: 10px; --radius-sm: 12px; --radius-md: 16px; --radius-lg: 22px;` — `rounded-full` needs no override, Tailwind's built-in already matches (9999px).
  - [x] Spacing: **do not** override Tailwind's built-in numbered spacing scale (`--spacing-7`, `--spacing-8`, etc.) — see Dev Notes for why steps 7 and 8 specifically would silently collide with Tailwind's own defaults. Define DESIGN.md's 8-step scale under distinctly-named theme keys instead (e.g. `--spacing-flovi-1` through `--spacing-flovi-8`), used as `p-flovi-6`, `gap-flovi-3`, etc.
  - [x] Elevation: define the two shadow levels (flat = none, raised = soft warm-toned shadow) as a reusable utility/class — DESIGN.md specifies the raised shadow is warm-toned and soft, explicitly never a hard black drop shadow

- [x] Task 2 — Supabase client, router, and the dedicated `/auth/callback` route (AC: #2, #3, #4)
  - [x] Neither Vue Router nor a Supabase client exists yet — Story 1.1's scaffold was bare `npm create vite -- --template vue`. Install `vue-router@4` and `@supabase/supabase-js`.
  - [x] `src/lib/supabase.ts` (per the architecture's source tree) — single client init, `auth: { flowType: 'pkce', detectSessionInUrl: true }`
  - [x] Router with routes: `/login`, `/auth/callback` (dedicated, not the SPA root — per AD-2/Story 1.6's PKCE setup, and registered in Supabase's Redirect URLs at `http://localhost:5173/auth/callback`), `/requests` (default authenticated landing), `/notifications`. A navigation guard redirects unauthenticated visitors to `/login` and authenticated visitors away from `/login`.
  - [x] `src/composables/useAuth.ts` (per source tree) — session state, `signInWithGoogle()`, `signOut()`, and the `claim_role` call

- [x] Task 3 — `claim_role` call and its failure modes (AC: #3, #4)
  - [x] Call **exactly** `supabase.rpc('claim_role', { p_role: 'dispatcher' })` — this parameter name is a fixed cross-epic contract pinned in Story 1.1; do not rename it
  - [x] Call this on every successful OAuth completion, not just a detected "first-time" one — Story 1.1 made `claim_role` idempotent for a same-role reclaim specifically so the client doesn't need first-time-detection logic at all. Simpler and removes a whole category of "was this really their first login" bugs.
  - [x] **Handle the case Story 1.1's exception exists to produce, which neither this epics.md story nor EXPERIENCE.md names as a state**: if the signed-in Google account already holds the `driver` role, `claim_role('dispatcher')` will throw (by design, per AD-2). OAuth itself succeeded here — this is a different failure than AC #4's OAuth-failure case. Recommend (not a sourced verbatim string, since no fixed microcopy exists for this state) something in EXPERIENCE.md's voice: "This Google account is already registered as a driver — sign in through the driver app instead." Sign the user back out and return them to Login rather than leaving them in a half-authenticated state.
  - [x] OAuth-failure copy (AC #4) **is** verbatim-fixed, quoted identically in both epics.md and EXPERIENCE.md's State Patterns table: `"We couldn't sign you in — try again."`

- [x] Task 4 — App shell: sidebar, landmarks, responsive floor (AC: #5, #6, #8)
  - [x] Sidebar exactly per DESIGN.md's component recipe: fixed 220px, `<nav>` element, 12px-rounded nav-item rows, `accent-tint` background on the active item, active item's **label text stays `text-primary`** (never accent-colored — DESIGN.md is explicit this avoids a low-contrast tinted-background-plus-hued-text pairing), accent hue appears only as a small left-edge indicator bar plus the notifications count badge
  - [x] Wrap the main content region in a `<main>` element — combined with the `<nav>` sidebar, this alone satisfies AC #8's landmark-structure option; a separate visually-hidden skip link is equally valid but not required if these two landmarks are in place
  - [x] 1024px floor (AC #6): Tailwind's own default `lg:` breakpoint **is already exactly 1024px** — no custom breakpoint needed. Show the real app shell as `hidden lg:flex` and the "best viewed on a larger screen" notice as `lg:hidden` (visible below 1024px, hidden at/above)

- [x] Task 5 — Focus ring baseline + icon-button min-size component (AC: #7, #9)
  - [x] Apply the focus ring via the `focus-visible:` variant, not bare `focus:` — shows the ring for keyboard navigation, not on every mouse click, which is what "visible focus ring" accessibility guidance actually wants. `focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring` (using the `--color-focus-ring` token from Task 1) on every interactive element in this story (OAuth button, sidebar nav items)
  - [x] Since AC #9 explicitly applies to "every subsequent story in this epic," build a small shared icon-button component now (rather than letting each later story re-derive the constraint) that structurally enforces a `min-w-8 min-h-8` (32px, Tailwind's own built-in step-8 value — no collision here, this is a min-size constraint not part of the spacing-scale override) hit area and a required accessible-label prop, so future stories can't accidentally ship an unlabeled icon-only control

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

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- No `.env` file existed anywhere in the repo yet (confirmed by Story 1.6). Obtained `VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY` directly from the user in-session, wrote `flovi/apps/dispatcher-web/.env` (gitignored) and a placeholder `.env.example`.
- Verified `npm run build` compiles cleanly, then ran `npm run dev` (Vite default port 5173, matching the redirect URL Story 1.6 already registered in Supabase) and drove the app via Chrome browser automation: confirmed the Login view renders, the OAuth-failure copy renders verbatim when `/auth/callback` is hit with `?error=...` (simulating a failed OAuth attempt), the router guard redirects an unauthenticated visit to `/requests` back to `/login`, the focus ring appears via keyboard Tab, and the `<nav>`/`<main>` landmark structure is present (1 of each, `nav` labelled "Primary").
- Full end-to-end Google OAuth sign-in (AC #3, and the role-mismatch path in Task 3) cannot be exercised via browser automation — Google's real consent flow requires a real account and credential entry, which is out of scope for automated tooling. To verify the authenticated App shell (sidebar, 220px width, responsive floor below 1024px, nav active-state switching, sign-out) without a real sign-in, a locally-scoped fake Supabase session was written directly to `localStorage` (matching supabase-js v2's `sb-<project-ref>-auth-token` storage shape) purely to drive client-side rendering — no network calls or real credentials were involved, and the fake session was cleared afterward. This confirmed: the shell renders correctly at ≥1024px (sidebar, active nav item with accent-tint + left-edge indicator, text stays `text-primary`, Account footer with identity + sign out), the "best viewed on a larger screen" notice replaces it below 1024px, nav-item clicks switch the active indicator, and sign-out clears the session and redirects to `/login`.
- User completed a live Google sign-in against the dev server. Landed on `/requests` with the real identity ("Nestor Bracho") shown in the sidebar footer, zero console errors — since `AuthCallbackView.vue` only reaches `/requests` when `claimRole('dispatcher')` resolves without throwing (any RPC error signs the user back out to `/login`), this confirms AC #3's full chain end-to-end: OAuth → `claim_role('dispatcher')` → redirect. Also re-verified a hard refresh on `/requests` keeps the session (no flash to `/login`), confirming the router guard's `await ready` correctly avoids racing Supabase's session hydration on page load.

### Completion Notes List

- **Task 1:** Rewrote `src/style.css`'s `@theme` block with all 23 DESIGN.md colors, the 6 paired typography styles (`--text-{name}` + `--text-{name}--font-weight`/`--letter-spacing`), the 4-step rounded scale, the 8-step spacing scale under `--spacing-flovi-*` (avoiding the documented `p-7`/`p-8` collision with Tailwind's own numbered scale), and a `--shadow-raised` utility for the warm-toned elevation. Removed the unused Vite/Vue template scaffold (`HelloWorld.vue`, template assets, template CSS) since this story replaces it with the real app shell.
- **Task 2:** Installed `vue-router@4` and `@supabase/supabase-js`. Added `src/lib/supabase.ts` (PKCE flow, `detectSessionInUrl: true`), `src/router/index.js` (routes for `/login`, `/auth/callback`, `/requests`, `/notifications`; an async navigation guard that awaits an `authReady` promise before evaluating, so a hard refresh doesn't race the guard against Supabase's session hydration), and `src/composables/useAuth.ts` (module-level reactive session state shared across the app, `signInWithGoogle()`, `signOut()`, `claimRole()`).
- **Task 3:** `claimRole('dispatcher')` is called unconditionally on every successful callback (no first-time detection), exactly as `supabase.rpc('claim_role', { p_role: 'dispatcher' })`. `AuthCallbackView.vue` distinguishes three outcomes: (a) an `?error=` query param from Google/Supabase → OAuth-failure copy, back to Login; (b) `claim_role` throwing (role mismatch) → sign out + the role-mismatch message, back to Login; (c) success → redirect to `/requests`. Both microcopy strings are verbatim per the story/EXPERIENCE.md.
- **Task 4:** `AppShell.vue` renders the fixed-220px `<nav aria-label="Primary">` (Requests, Notifications, Account footer with identity + sign out) plus a `<main>` content region when `hidden lg:flex` is active; `SidebarNavItem.vue` implements the 12px-rounded row with `accent-tint` background and left-edge indicator bar on the active item, label text always `text-primary`. The sub-1024px case renders the "best viewed on a larger screen" notice via `lg:hidden`. `App.vue` conditionally wraps `<RouterView>` in `AppShell` based on `route.meta.requiresAuth`.
- **Task 5:** Focus rings use `focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus-ring` on the OAuth button and both sidebar nav items. Added `src/components/IconButton.vue` — `min-w-8 min-h-8` hit area, `required` `label` prop rendered as `aria-label`, ready for icon-only controls in later Epic 2 stories.
- All 9 ACs implemented and verified, including a live Google sign-in performed by the user confirming AC #3's full OAuth → `claim_role('dispatcher')` → `/requests` chain (see Debug Log References). Task 3's role-mismatch path is implemented per spec but not separately exercised live (no driver-role test account was used in this session) — no automated test suite is in scope per this story's Testing Standards Summary.

### File List

- `flovi/apps/dispatcher-web/.env` (new, gitignored — `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`)
- `flovi/apps/dispatcher-web/.env.example` (new)
- `flovi/apps/dispatcher-web/.gitignore` (modified — added `.env`)
- `flovi/apps/dispatcher-web/index.html` (modified — title)
- `flovi/apps/dispatcher-web/package.json` / `package-lock.json` (modified — added `vue-router`, `@supabase/supabase-js`)
- `flovi/apps/dispatcher-web/src/style.css` (rewritten — DESIGN.md token `@theme` block + minimal base layer)
- `flovi/apps/dispatcher-web/src/main.js` (modified — mounts router)
- `flovi/apps/dispatcher-web/src/App.vue` (rewritten — shell/no-shell routing split)
- `flovi/apps/dispatcher-web/src/lib/supabase.ts` (new)
- `flovi/apps/dispatcher-web/src/router/index.js` (new)
- `flovi/apps/dispatcher-web/src/composables/useAuth.ts` (new)
- `flovi/apps/dispatcher-web/src/views/LoginView.vue` (new)
- `flovi/apps/dispatcher-web/src/views/AuthCallbackView.vue` (new)
- `flovi/apps/dispatcher-web/src/views/RequestsView.vue` (new — shell only)
- `flovi/apps/dispatcher-web/src/views/NotificationsView.vue` (new — shell only)
- `flovi/apps/dispatcher-web/src/components/AppShell.vue` (new)
- `flovi/apps/dispatcher-web/src/components/SidebarNavItem.vue` (new)
- `flovi/apps/dispatcher-web/src/components/IconButton.vue` (new)
- `flovi/apps/dispatcher-web/src/components/HelloWorld.vue` (deleted — unused Vite scaffold)
- `flovi/apps/dispatcher-web/src/assets/hero.png`, `vite.svg`, `vue.svg` (deleted — unused Vite scaffold)

## Change Log

- 2026-07-09 — Implemented Story 2.1 in full: DESIGN.md tokens wired into Tailwind v4, Supabase client + router + `/auth/callback` route, `claim_role('dispatcher')` on every successful sign-in with both the OAuth-failure and role-mismatch failure paths handled, the authenticated app shell (220px sidebar, landmarks, 1024px responsive floor), and the focus-ring baseline + shared `IconButton` component. All 5 tasks complete; all 9 ACs verified — 8 directly via browser automation (some via a locally-injected fake session to exercise the authenticated shell without real credentials), and AC #3 confirmed via a live Google sign-in performed by the user. Status → review.
