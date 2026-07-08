# Story 3.5: Deploy Driver Mobile to Vercel

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator,
I want the driver mobile app live at a public URL as a Flutter web build,
so that it can be demoed and evaluated without running anything locally, satisfying the non-native-binary deliverable.

## Acceptance Criteria

1. **Given** the driver mobile app is feature-complete through Story 3.4, **when** it is built for production (`flutter build web`), **then** the build succeeds using the production Supabase URL and anon key as environment configuration (no service-role key present anywhere client-side).
2. **Given** the production `build/web` output, **when** it is deployed to Vercel, **then** a live public URL serves the app, and the `/auth/callback` route is included in the Google OAuth client's allow-listed redirect URLs for that production URL (NFR3).
3. **Given** the deployed app at its public URL, **when** a driver signs in and exercises Gigs/Booked, **then** the full Story 3.1-3.4 flow works identically to local — sign-in, browse/book, confirmation, cancel/complete — with the PKCE flow functioning correctly on Flutter web's production build.

## Tasks / Subtasks

- [ ] Task 1 — Vercel has no native Flutter support; configure it manually (AC: #1, #2)
  - [ ] Framework Preset: **"Other"** — Flutter isn't one of Vercel's built-in presets, unlike Vite for the dispatcher app
  - [ ] Root Directory: `apps/driver-mobile` (same monorepo consideration as Story 2.5)
  - [ ] Install Command: clone (or update) the Flutter SDK into the build environment and enable web support, since Vercel's build image doesn't ship Flutter — e.g. `if cd flutter; then git pull && cd ..; else git clone https://github.com/flutter/flutter.git; fi && flutter/bin/flutter config --enable-web`
  - [ ] Output Directory: `build/web`

- [ ] Task 2 — Build-time config via `--dart-define`, using the mechanism Story 3.1 already established (AC: #1)
  - [ ] Story 3.1 was written to read `String.fromEnvironment('SUPABASE_URL')`/`String.fromEnvironment('SUPABASE_ANON_KEY')` specifically so this story only has to supply values, not invent the config path
  - [ ] Build Command: `flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY` — set `SUPABASE_URL`/`SUPABASE_ANON_KEY` as regular Vercel Environment Variables (Project Settings), which the shell build command interpolates into the `--dart-define` flags at build time
  - [ ] Same non-issue as Story 1.6/2.5: "production" Supabase credentials are the same single project used locally — no second project exists, and no service-role key belongs anywhere in this build

- [ ] Task 3 — SPA fallback routing (AC: #2, #3) — the forward consequence flagged in Story 3.1
  - [ ] Add `apps/driver-mobile/vercel.json`:
    ```json
    { "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
    ```
  - [ ] Same root cause as the dispatcher-web app's Story 2.5 (and explicitly predicted in Story 3.1 when `usePathUrlStrategy()` was chosen): path-based routing via the History API needs the host to rewrite direct navigation back to `index.html`, or the OAuth redirect to `/auth/callback` 404s in production while working fine in local dev

- [ ] Task 4 — Register the production redirect URL (AC: #2)
  - [ ] Add (don't replace) `https://<production-domain>/auth/callback` to Supabase's Auth → URL Configuration → Redirect URLs, alongside the dispatcher-web production URL Story 2.5 already added and the local-dev URLs Story 1.6 set up
  - [ ] Use Vercel's stable production domain, not a per-deployment preview URL

- [ ] Task 5 — Live smoke test (AC: #3)
  - [ ] Against the deployed URL: sign in with Google, browse Gigs, book a gig, confirm the interstitial, view Booked, cancel/mark-complete — the full local verification checklist run again against production, since a successful build doesn't prove the deployed app works end-to-end

## Dev Notes

### What I checked and did *not* find: no unique PKCE-in-production-build bug
Worth stating plainly rather than manufacturing a concern: I looked specifically for a Flutter-web-release-build-specific PKCE/deep-link issue distinct from local dev, and found none — the known `supabase_flutter` deep-link issues on record are Android/iOS-specific, not web-specific. The actual risk in this story isn't some exotic release-build auth bug; it's the same mundane SPA-rewrite gap as Story 2.5, just on a different framework's static output. Don't go looking for a more exotic root cause if sign-in fails after this deploy — check the rewrite first.

### Testing standards summary
No automated test suite in scope. Task 5's live smoke test is the actual verification — same principle as Story 2.5: a green build is necessary but not sufficient.

### Project Structure Notes
```
apps/driver-mobile/
  vercel.json   # new — SPA rewrite
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 3.5: Deploy Driver Mobile to Vercel]
- [Source: _bmad-output/implementation-artifacts/3-1-app-shell-design-tokens-login-role-claiming.md — `String.fromEnvironment` config mechanism, the SPA-rewrite prediction this story fulfills]
- [Source: _bmad-output/implementation-artifacts/2-5-deploy-dispatcher-web-to-vercel.md — the twin dispatcher-web deploy story; same OAuth redirect registration pattern, same monorepo Root Directory consideration]
- [Source: _bmad-output/implementation-artifacts/1-6-realtime-publication-seed-data-auth-configuration.md — the two-layer OAuth redirect setup this story adds its production URL to]
- [External: Deploying a Flutter web app to Vercel (no native preset, manual install/build commands) — https://blog.suneeldk.me/deploying-a-flutter-web-app-on-vercel]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
