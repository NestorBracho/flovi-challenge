---
baseline_commit: 8156635488846a926831f34c9217625920246611
---

# Story 1.6: Realtime Publication, Seed Data & Auth Configuration

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator preparing both apps to build against a live backend,
I want realtime sync enabled on the right tables, demo accounts seeded, and Google OAuth configured for both apps,
so that Epic 2 and Epic 3 can start against a fully working, demoable backend from day one.

## Acceptance Criteria

1. **Given** the `relocation_requests` and `notifications` tables exist, **when** this story is complete, **then** both tables are added to the Postgres Changes realtime publication, and no other tables are included (AD-5).
2. **Given** a fresh Supabase project, **when** `seed.sql` runs, **then** demo `profiles` rows exist covering both roles (at least 2 dispatchers, 3+ drivers with varying `completed_rides_count` so the priority rule is demoable) plus a few seed `relocation_requests` across different statuses (unbooked/booked/completed) so Epic 2 can demo status-pill variety without Epic 3 existing yet.
3. **Given** the Supabase Auth configuration, **when** this story is complete, **then** one Google OAuth client is configured with both apps' `/auth/callback` URLs allow-listed, with both apps expected to use `AuthFlowType.pkce`.
4. **Given** the anon key and service-role key, **when** client bundles are prepared, **then** only the anon key is ever baked into a client bundle; the service-role key is never referenced client-side.

## Tasks / Subtasks

- [x] Task 1 — Realtime publication (AC: #1)
  - [x] `ALTER PUBLICATION supabase_realtime ADD TABLE public.relocation_requests, public.notifications;` (Supabase hosted projects already have a `supabase_realtime` publication provisioned by default — don't create a new one)
  - [x] Confirm `profiles` and `booking_bids` are **not** added — AD-5 is explicit that only these two tables are in the realtime contract

- [x] Task 2 — Google OAuth: the two-layer redirect setup (AC: #3)
  - [x] Create (or reuse) one Google Cloud Console OAuth 2.0 Client. Its **Authorized redirect URIs** gets exactly **one** entry: Supabase's own fixed callback, `https://<project-ref>.supabase.co/auth/v1/callback` — this is Supabase's endpoint, not either app's. Do **not** put the apps' `/auth/callback` URLs here — see Dev Notes, this is the single easiest way to get this wrong.
  - [x] In Supabase Dashboard → Authentication → Providers → Google: paste that Client ID + Secret, enable the provider
  - [x] In Supabase Dashboard → Authentication → URL Configuration → Redirect URLs: add **both apps' local-dev** `/auth/callback` URLs now (this is the allow-list the apps' own `redirectTo` values must appear on) — `http://localhost:5173/auth/callback` (Vite's default port) and a **fixed** driver-mobile dev URL (see next subtask)
  - [x] Pick and fix a stable port for Flutter web dev now — e.g. always launch with `flutter run -d chrome --web-port=5000` — and register `http://localhost:5000/auth/callback` in the same Redirect URLs list. Flutter web's dev server otherwise picks a random port per run, which would silently break the registered redirect URL every single dev session if left unfixed.
  - [x] Leave a note for Stories 2.5/3.5: their production Vercel URLs' `/auth/callback` must be **added** to this same Supabase Redirect URLs list (not replace the local-dev ones) once each app is deployed

- [x] Task 3 — Seed data (AC: #2)
  - [x] **Do not** hand-write `INSERT INTO auth.users (...)` rows directly in `seed.sql` — `profiles.id` is FK'd to `auth.users(id)`, but raw SQL inserts into `auth.users` are not a safe/supported pattern against a hosted (non-local) Supabase project (missing `auth.identities` rows, internal trigger/constraint fragility). Instead: create ~5 real auth users first via the Supabase Dashboard's "Add user" (Authentication → Users) or the Admin API (`supabase.auth.admin.createUser({ email, email_confirm: true })`), capture the returned UUIDs, then reference those literal UUIDs in `seed.sql`'s `profiles`/`relocation_requests` inserts.
  - [x] `seed.sql`: `INSERT INTO profiles (id, role, full_name, completed_rides_count) VALUES` for 2 dispatchers and 3+ drivers with **varying** `completed_rides_count` (e.g., 0, 3, 7) so the priority rule has something to rank
  - [x] `seed.sql`: `INSERT INTO relocation_requests (created_by, origin, destination, scheduled_date, notes) VALUES ...` for a handful of rows spanning unbooked/booked/completed. **This will not work as a single INSERT** — Story 1.2's `BEFORE INSERT` trigger unconditionally forces `status = 'unbooked'`/`driver_id = NULL` regardless of what the INSERT specifies (that's correct behavior for real client inserts, but it also neutralizes seed data). Follow every INSERT that needs a non-`unbooked` seed row with a separate `UPDATE relocation_requests SET status = '...', driver_id = '...' WHERE id = <the just-inserted row>` — this works because `seed.sql` runs via the SQL Editor as a privileged role, not as `authenticated`, so Story 1.2's column-level `REVOKE UPDATE ... FROM authenticated` doesn't apply to this session.
  - [x] **Document plainly (in this story's completion notes, and ideally as a comment atop `seed.sql`) that these seeded accounts can never actually sign in** — there's no real Google identity behind a Dashboard-created auth user, and CAP-1/CAP-5's *only* sign-in method is Google OAuth (no email/password flow exists anywhere in this project). The seeded data exists purely to populate the UI with variety and give the priority mechanic existing competitors to rank against — see Dev Notes for what this means for the actual demo.

- [x] Task 4 — Key hygiene (AC: #4)
  - [x] Confirm both apps' env config (`.env`/build-time config for Vite and Flutter) references only the Supabase URL + anon key
  - [x] Confirm the service-role key appears nowhere in the repo at all — there's no legitimate place for it to live in this architecture (AD-1: no custom backend service exists; both apps are pure client bundles), so this is a non-issue as long as no one pastes it into a client env file out of habit

- [x] Task 5 — Verification (AC: all)
  - [x] Confirm the realtime publication change via `SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';` → exactly `relocation_requests` and `notifications`
  - [x] Run `seed.sql` against the live project, confirm the expected row counts and status variety land correctly (including that the INSERT-then-UPDATE actually produces `booked`/`completed` rows, not silently-reverted `unbooked` ones)
  - [x] Full end-to-end OAuth verification (an actual sign-in completing through both layers) can't fully happen yet — no login screen exists until Stories 2.1/3.1. This story's verification is limited to confirming the dashboard/console configuration is saved correctly; treat Stories 2.1/3.1 as the real proof this worked.

### Review Findings

Adversarial code review of the Epic 1 Supabase contract (2026-07-09). Fixed in the working tree; no live action needed (project is already seeded — the fix only hardens future runs).

- [x] [Review][Patch][Low] `seed.sql` relied on `set_config(..., true)` being transaction-scoped without an explicit transaction [flovi/supabase/seed.sql] — the transaction-local (`is_local => true`) jwt-claim `set_config` calls only stay in scope for the following inserts if all statements share one transaction. Verified working via the Supabase SQL Editor (which sends the script as a single query), but it would break if run statement-by-statement / autocommit (`created_by := auth.uid()` → NULL → not-null violation). Fixed: wrapped the whole seed in `begin; … commit;` (also makes it atomic).

## Dev Notes

### Seeded accounts are decorative, not something you can "log in as" — plan the actual demo around this now
This is worth internalizing before Story 4.1's rehearsal, not discovering it there. Because Google OAuth is the *only* auth path (no email/password anywhere in this spec), and seeded `auth.users` rows have no real Google identity behind them, **nobody can ever actually sign in as "Demo Dispatcher 1" or "Demo Driver A."** The seed data's job is narrower than it sounds: it gives the Requests list status-pill variety before Epic 3 exists (AC #2's stated purpose), and it gives the priority mechanic pre-existing competitors with different `completed_rides_count` values to rank against once a real driver logs in. **For the actual live demo — especially Flow 2/3's concurrent-booking and reassignment moments — the operator needs 2–3 of their own real Google accounts** (personal + a secondary account, or two browser profiles signed into different real Google identities) to play the competing-drivers role live. Surface this to the operator now so it's arranged well before the 4-hour clock is an issue, not during Story 4.1's rehearsal.

### The two-layer OAuth redirect setup — the most common way to break Google sign-in
There are two *different* "redirect URL" settings, easy to conflate:
- **Google Cloud Console's "Authorized redirect URIs"** controls where *Google* is willing to send the user back to after they authenticate. This must be Supabase's own endpoint (`https://<project-ref>.supabase.co/auth/v1/callback`) — never either app's URL directly.
- **Supabase's own "Redirect URLs" allow-list** (Auth → URL Configuration) controls where *Supabase* is willing to forward the user on to afterward, into your actual app. This is where both apps' `/auth/callback` URLs belong (local-dev now, production added later by Stories 2.5/3.5).
Putting the apps' URLs in the Google Console step instead of (or in addition to being needed in) the Supabase step is the single most common way this breaks, producing a `redirect_uri_mismatch` error from Google that has nothing to do with anything either app's code does — worth knowing that up front if it comes up while debugging Stories 2.1/3.1's login screens later.

### Why Flutter web's dev port needs to be pinned now
`flutter run -d chrome` assigns a random port per invocation unless told otherwise. An OAuth redirect URI is an exact-match allow-list entry — a random port every session means re-registering the Supabase Redirect URL constantly, or (worse) it silently fails mid-build with no obvious cause. Fixing it once now (`--web-port=5000`, or whatever the dev agent building Story 3.1 prefers, as long as it's consistent) avoids this becoming a recurring, confusing interruption later.

### The seed-data vs. INSERT-trigger conflict
Story 1.2's `BEFORE INSERT` trigger on `relocation_requests` unconditionally overwrites `status`/`driver_id` to `unbooked`/`NULL` — correct and required for real client inserts (AC #2 of that story), but it also silently neutralizes any non-`unbooked` seed row in a plain INSERT. The INSERT-then-UPDATE approach in Task 3 works around this without touching the trigger, because `seed.sql` executed via the SQL Editor runs with full table privileges, unaffected by the column-level `REVOKE` that only targets the `authenticated` role.

### Testing standards summary
No automated test suite in scope. This story's own verification is partial by nature (Task 5) — the real proof that OAuth configuration landed correctly is Stories 2.1/3.1 actually completing a sign-in.

### Project Structure Notes
```
supabase/
  seed.sql   # profiles + relocation_requests only — auth users are created out-of-band via Dashboard/Admin API, not raw SQL, and their UUIDs are pasted in as literal constants here
```
No new migration file in this story — no new schema, only publication/seed/config changes.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.6: Realtime Publication, Seed Data & Auth Configuration]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-5 — One realtime contract, one shared vocabulary]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Structural Seed — Deployment & environments, PKCE + dedicated /auth/callback rationale]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#Assumptions — "Database is seeded with a handful of test dispatcher and driver accounts at initialization for demo convenience"]
- [Source: _bmad-output/implementation-artifacts/1-2-relocation-request-schema-dispatcher-crud-cancellation.md — the BEFORE INSERT trigger this story's seed data must work around]
- [External: Supabase seeding auth.users directly is unsafe/unsupported outside local dev — https://github.com/orgs/supabase/discussions/1323]
- [External: Google Cloud Console vs. Supabase redirect URL distinction — https://supabase.com/docs/guides/auth/social-login/auth-google]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5)

### Debug Log References

- Executed all live-project steps via Chrome browser automation against the Supabase Dashboard (project `flovi-challenge`, ref `vruhkfrlwqdznowukwio`) and Google Cloud Console (project `api-project-331353254024`), both already owned/logged-into by the operator. No credentials were entered by the agent at any point — the operator signed into Google/Supabase themselves, created the 5 demo `auth.users` accounts themselves via the Dashboard's "Add user" form (password field), and pasted the Google OAuth Client Secret into Supabase's provider config themselves. The agent handled all non-secret navigation, field entry, and SQL execution.

### Completion Notes List

- **Task 1 (realtime publication):** Ran `ALTER PUBLICATION supabase_realtime ADD TABLE public.relocation_requests, public.notifications;` directly via the Supabase SQL Editor against the live project (no migration file, per this story's Project Structure Notes — publication changes aren't schema). Verified via `pg_publication_tables`: baseline was 0 tables in the publication; after the ALTER, exactly `notifications` and `relocation_requests` are present — `profiles` and `booking_bids` are correctly absent (AD-5, AC #1 satisfied).
- **Task 2 (Google OAuth):** Created one Google Cloud Console OAuth 2.0 Client (Web application type, project `api-project-331353254024`, reused rather than a fresh GCP project) with its Authorized redirect URIs set to exactly one entry — `https://vruhkfrlwqdznowukwio.supabase.co/auth/v1/callback` (Supabase's own fixed endpoint, not either app's URL — the Dev Notes' "most common way to break this" was avoided). The OAuth consent screen was configured first (required prerequisite, wasn't previously set up on this GCP project) as External audience, since the operator's demo plan requires multiple personal Google accounts rather than a single Workspace org. Pasted the resulting Client ID into Supabase Dashboard → Authentication → Providers → Google (agent-entered, non-sensitive) and enabled the provider; the Client Secret was pasted by the operator directly (agent does not handle secrets/tokens). Added both apps' local-dev callback URLs to Supabase's Redirect URLs allow-list: `http://localhost:5173/auth/callback` (Vite default port) and `http://localhost:5000/auth/callback` (fixed Flutter web dev port per this story's Dev Notes — Story 3.1 must launch with `flutter run -d chrome --web-port=5000` to match). AC #3 satisfied at the configuration level; full end-to-end sign-in is deferred to Stories 2.1/3.1 as this story's own scope anticipates. **Note for Stories 2.5/3.5:** once each app deploys to Vercel, its production `/auth/callback` URL must be *added* to this same Supabase Redirect URLs list (not replace the local-dev entries).
- **Task 3 (seed data):** Created 5 real `auth.users` accounts via Supabase Dashboard → Authentication → Users → "Add user" (operator-entered password, auto-confirmed) — `demo.dispatcher1@flovi.test`, `demo.dispatcher2@flovi.test`, `demo.drivera@flovi.test`, `demo.driverb@flovi.test`, `demo.driverc@flovi.test`. Captured their UUIDs via SQL Editor and hardcoded them as literal constants in `flovi/supabase/seed.sql`. **Important discovery beyond what the story anticipated:** the `relocation_requests_before_insert` trigger (Story 1.2) sets `created_by := auth.uid()` unconditionally, and `auth.uid()` resolves to `NULL` when a script runs as the `postgres` role in the SQL Editor (no JWT) — this fails the column's NOT NULL constraint even for a plain unbooked insert, not just the booked/completed rows the story's Dev Notes anticipated needing an INSERT-then-UPDATE workaround for. Fixed by calling `select set_config('request.jwt.claim.sub', '<dispatcher-uuid>', true);` immediately before each relocation_requests insert, simulating the intended dispatcher as caller — the same technique Stories 1.4/1.5 used for `auth.uid()` simulation during verification. `seed.sql` now documents this inline. Ran the corrected script against the live project: 5 profiles (2 dispatchers at 0 rides, 3 drivers at 0/3/7 completed rides) and 5 relocation_requests (2 unbooked, 2 booked, 1 completed) landed exactly as designed, confirmed via `GROUP BY status` and a full profiles query. **These seeded accounts can never actually sign in** — Google OAuth is the only auth path in this project and none of these `auth.users` rows have a real Google identity behind them; this is documented atop `seed.sql` itself and reiterated here per the story's explicit instruction. For the actual live demo, the operator needs 2–3 of their own real Google accounts to play the competing-drivers role (see Dev Notes).
- **Task 4 (key hygiene):** Grepped the full repo for `service_role`/`SERVICE_ROLE` — zero matches. No `.env*` files exist anywhere in the repo yet (both `dispatcher-web` and `driver-mobile` are still unmodified framework scaffolds; Epics 2/3 haven't started), so there is currently no client bundle to audit for key placement — this task is trivially satisfied now, and the real check happens when Stories 2.1/3.1 introduce env config.
- **Task 5 (verification):** Covered inline above — realtime publication confirmed via direct query, seed data row counts/status variety confirmed via direct query, OAuth dashboard/console configuration confirmed saved (Google provider shows "Enabled" in Supabase, redirect URIs saved on both sides). Full end-to-end OAuth sign-in is out of this story's scope per its own Task 5 wording.

### File List

- `flovi/supabase/seed.sql` (rewritten — profiles + relocation_requests seed data, with `set_config`-based `auth.uid()` simulation to satisfy the `created_by` trigger)
- Live Supabase project changes (not repo files): `supabase_realtime` publication now includes `relocation_requests` + `notifications`; 5 `auth.users`/`profiles` rows + 5 `relocation_requests` rows seeded; Google OAuth provider enabled with Client ID/Secret; Redirect URLs allow-list updated with both apps' local-dev callback URLs
- Live Google Cloud Console changes (not repo files): OAuth consent screen configured (External audience) on the `api-project-331353254024` project; one Web application OAuth 2.0 Client created (`FloviChallenge Supabase`) with Supabase's callback as its sole Authorized redirect URI

## Change Log

- 2026-07-09 — Implemented Story 1.6 in full: realtime publication now covers exactly `relocation_requests`/`notifications`; Google OAuth configured end-to-end (Google Cloud Console client + Supabase provider + Redirect URLs allow-list); `seed.sql` rewritten with 5 real auth users, 5 profiles, and 5 relocation_requests across all three statuses, including a fix for an `auth.uid()`/`created_by` trigger interaction not anticipated in the original task breakdown. Key hygiene confirmed clean (no service-role key in repo; no env files exist yet). All 5 tasks complete; all 4 ACs verified against the live project to the extent this story's own scope allows. Status → review.
