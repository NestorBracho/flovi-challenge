---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 2.5: Deploy Dispatcher Web to Vercel

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator,
I want the dispatcher web app live at a public URL,
so that it can be demoed and evaluated without running anything locally.

## Acceptance Criteria

1. **Given** the dispatcher web app is feature-complete through Story 2.4, **when** it is built for production, **then** the build succeeds using the production Supabase URL and anon key as environment variables (no service-role key present anywhere client-side).
2. **Given** the production build, **when** it is deployed to Vercel, **then** a live public URL serves the app, and the `/auth/callback` route is included in the Google OAuth client's allow-listed redirect URLs for that production URL (NFR3).
3. **Given** the deployed app at its public URL, **when** a dispatcher signs in and exercises Requests/Notifications, **then** the full Story 2.1-2.4 flow works identically to local — sign-in, create/edit/cancel, realtime updates, notifications.

## Tasks / Subtasks

- [x] Task 1 — Environment variables (AC: #1)
  - [x] "Production" Supabase URL/anon key are **the same values used locally** — this project has a single Supabase project with no staging/prod split (per the architecture's Structural Seed section). Don't go looking for or provisioning a second project; there isn't one.
  - [x] Vite only exposes env vars to client code that are prefixed `VITE_` (e.g. `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) — anything without that prefix is silently unavailable in the built bundle, not an error. Set these exact names in Vercel's Project Settings → Environment Variables, matching whatever names `src/lib/supabase.ts` (Story 2.1) actually reads via `import.meta.env`.
  - [x] Confirm no service-role key is set as a Vercel env var at all — there's no legitimate use for it here (same non-issue noted in Story 1.6: this architecture has no server-side code, only client bundles)

- [x] Task 2 — Vercel project configuration for the monorepo (AC: #2)
  - [x] This is a monorepo (`flovi/apps/dispatcher-web`, `apps/driver-mobile`, `supabase/`) — Vercel's **Root Directory** setting must be set to `apps/dispatcher-web`, not the repo root, or Vercel won't find a buildable project there at all. (Root Directory is constrained: the build can't read anything outside that folder via `../` — a non-issue here, since neither app depends on the other or on anything in `supabase/` at build time.)
  - [x] Framework preset: Vite. Build command / output directory should be auto-detected (`vite build` / `dist`) once Root Directory is set correctly

- [x] Task 3 — SPA fallback routing (AC: #2, #3) — **the critical, easy-to-miss piece**
  - [x] Add `apps/dispatcher-web/vercel.json` (inside the app's own root, alongside its `package.json` — not the monorepo's true root, since Vercel treats the configured Root Directory as its effective project root):
    ```json
    { "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
    ```
  - [x] **Why this matters specifically for this app**: Vite's local dev server automatically serves `index.html` for any client-side route, which masks a real problem — a bare static deploy has no actual file at `/auth/callback` or `/requests`, so Vercel returns a 404 for any direct hit on those paths unless this rewrite is in place. This isn't a hypothetical edge case here: it's the **OAuth redirect path itself**. Google/Supabase redirects the browser straight to `https://<prod-url>/auth/callback` as a fresh navigation (not a client-side route change), so without this rewrite, sign-in would 404 in production while working perfectly in local dev — precisely the kind of gap that only surfaces after deploying, not before.

- [x] Task 4 — Register the production redirect URL (AC: #2)
  - [x] Add (do **not** replace) `https://<production-domain>/auth/callback` to Supabase's Auth → URL Configuration → Redirect URLs — Story 1.6 already put the local-dev URLs there and explicitly left this addition for this story
  - [x] Use Vercel's **stable production domain** (`https://<project-name>.vercel.app`, assigned once and unchanging), not a per-deployment preview URL (those change on every push and would need re-registering constantly)

- [x] Task 5 — Live smoke test (AC: #3)
  - [x] Against the deployed URL, not local: sign in with Google, create a request, edit it, cancel it, open Notifications, and (if Epic 1/3 are far enough along) confirm a realtime status change reflects live — the same checklist as local verification, run again against production because a successful build is not proof the deployed app actually works end-to-end

## Dev Notes

### The one thing in this story that actually breaks quietly if missed
Everything else here (env vars, Root Directory) fails loudly — a missing env var breaks the build or produces an obvious runtime error; a wrong Root Directory fails the deploy outright. The SPA-rewrite omission is the one that doesn't: the build succeeds, the site loads fine at its root URL, and everything looks deployed correctly — right up until someone actually clicks "Sign in with Google" and gets bounced to a 404 instead of back into the app. This is exactly the gap AC #3 exists to catch ("works identically to local"), and exactly why it's listed as its own AC rather than assumed from AC #2 alone.

### Testing standards summary
No automated test suite in scope. Task 5's smoke test against the live URL is the actual verification for this story — a green Vercel build is necessary but not sufficient.

### Project Structure Notes
```
apps/dispatcher-web/
  vercel.json   # new — SPA rewrite, lives here (Vercel's Root Directory), not at the monorepo root
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 2.5: Deploy Dispatcher Web to Vercel]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Structural Seed — single Supabase project, Vercel hosting]
- [Source: _bmad-output/implementation-artifacts/1-6-realtime-publication-seed-data-auth-configuration.md — the two-layer OAuth redirect setup this story adds its production URL to]
- [Source: _bmad-output/implementation-artifacts/2-1-app-shell-design-tokens-login-role-claiming.md — the `/auth/callback` route and Supabase client env var names this story must match]
- [External: Vercel SPA rewrite fix for client-side routing 404s — https://community.vercel.com/t/404-on-refresh-direct-access-for-spa-subpaths-vercel-deployment/12593]
- [External: Vercel monorepo Root Directory configuration — https://vercel.com/docs/monorepos]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5

### Debug Log References

- `npm run build` in `flovi/apps/dispatcher-web` succeeded locally with the production Supabase env values before touching Vercel (confirms AC #1 independent of the platform build).
- Vercel deployment `flovi-challenge-5lv8ptyxy-nestorbrachos-projects.vercel.app` (production alias `flovi-challenge.vercel.app`) built successfully from commit `18580d1` on `main`.

### Completion Notes List

- Actual repo layout has an extra `flovi/` segment the story text didn't anticipate: Vercel's **Root Directory** was set to `flovi/apps/dispatcher-web`, not `apps/dispatcher-web` as written in Task 2. Framework preset (Vite) and build/output settings auto-detected correctly once that was set.
- A large backlog of already-implemented, previously-uncommitted work (Stories 1.2–2.4 across backend schema and dispatcher-web) had to be committed and pushed before Vercel's GitHub-import flow could see the code at all — done in commit `18580d1` per explicit user direction, as a prerequisite for this story rather than as part of its own scope.
- Deployment was performed interactively via the Vercel and Supabase dashboards (browser automation), not CLI, per user preference — GitHub App install, env var entry, and the Supabase redirect URL addition were each confirmed with the user before executing since they touch external accounts/OAuth grants.
- Live smoke test on `https://flovi-challenge.vercel.app`: Google sign-in → `/requests` (confirms the `vercel.json` SPA rewrite fixes the `/auth/callback` 404 risk called out in Dev Notes), create/edit/cancel a request all worked against the same Supabase project used locally, Notifications view rendered (empty state — no driver-side cancellation has occurred yet). Cross-app realtime verification (driver cancels → dispatcher notification) is not yet testable since Epic 3 (driver-mobile) hasn't been built, consistent with the story's own "(if Epic 1/3 are far enough along)" caveat — deferred to Epic 4's cross-app verification story.

### File List

- `flovi/apps/dispatcher-web/vercel.json` (new)
- Vercel project `flovi-challenge`: Root Directory `flovi/apps/dispatcher-web`, env vars `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` (Production + Preview scopes)
- Supabase Auth → URL Configuration → Redirect URLs: added `https://flovi-challenge.vercel.app/auth/callback`

## Change Log

- 2026-07-09: Deployed dispatcher-web to Vercel at `https://flovi-challenge.vercel.app`. Added `vercel.json` SPA rewrite, configured Vercel project (Root Directory, env vars), registered the production OAuth redirect URL in Supabase, and verified the full sign-in/create/edit/cancel/notifications flow live against production. Also committed and pushed the previously-uncommitted backlog of Stories 1.2–2.4 work, which was a prerequisite for Vercel's GitHub import to see the current code.
