---
baseline_commit: NO_COMMITS_YET
---

# Story 1.1: Profiles Schema & Role-Claiming RPC

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a first-time sign-in user of either app,
I want my dispatcher/driver role permanently recorded the moment I authenticate,
so that the correct app experience is enforced from that point on and no one can hold or flip roles.

## Acceptance Criteria

1. **Given** no project scaffolding exists yet, **when** this story is complete, **then** a monorepo exists at `flovi/` with `apps/dispatcher-web` (scaffolded via `npm create vite` + Vue 3 + Tailwind), `apps/driver-mobile` (scaffolded via `flutter create`), and `supabase/{migrations,functions.sql,policies.sql,seed.sql}` laid out per the architecture's source tree, committed to the public repo (NFR4).
2. **Given** the Supabase project has no `profiles` table yet, **when** this story is complete, **then** a `profiles` table exists with columns `id (uuid PK, references auth.users)`, `role (text)`, `full_name (text)`, `completed_rides_count (int, default 0)`, `is_active (boolean, default true)`, **and** a `SECURITY DEFINER` RPC `claim_role(role text)` exists per AD-2.
3. **Given** a user has no existing `profiles` row, **when** they call `claim_role('dispatcher')` or `claim_role('driver')`, **then** a new `profiles` row is created with the requested role and `full_name` populated from the OAuth identity's `raw_user_meta_data` (Google `full_name`/`name` claim).
4. **Given** a user already has a `profiles` row with a role different from the one requested, **when** they call `claim_role` with the other role, **then** the RPC raises an exception and no role change occurs — one person holds exactly one role, permanently.
5. **Given** `profiles.role` has been set once, **when** any client attempts a direct UPDATE on the `role` column, **then** the write is rejected — no client-facing UPDATE grant exists on that column.
6. **Given** any authenticated user (either role), **when** they SELECT from `profiles`, **then** the read succeeds for all rows (open SELECT policy) — both apps need to resolve `id`/`role`/`full_name`/`completed_rides_count` for display.

## Tasks / Subtasks

- [x] Task 1 — Scaffold the monorepo and make the first commit (AC: #1)
  - [x] Create `flovi/` at repo root (this repo's origin is already `git@github.com:NestorBracho/flovi-challenge.git`, currently zero commits on `main` — this task produces the first commit)
  - [x] `apps/dispatcher-web`: `npm create vite@latest dispatcher-web -- --template vue`, then install Tailwind v4 via `npm install tailwindcss @tailwindcss/vite` — **do not** generate `tailwind.config.js`/PostCSS config (v3 pattern); v4 is CSS-first (see Dev Notes)
  - [x] `apps/driver-mobile`: `flutter create --platforms=web driver-mobile` — pass `--platforms=web` explicitly, don't rely on default platform scaffolding
  - [x] `supabase/`: create `migrations/` (empty dir, first migration added in Task 2), plus empty placeholder files `functions.sql`, `policies.sql`, `seed.sql` — these three are single cumulative files appended to across Stories 1.1–1.6, never split per-story or per-RPC (see Dev Notes)
  - [x] Stage and commit everything as the initial scaffolding commit; do not squash later stories into this commit — NFR4 requires visible incremental history

- [x] Task 2 — `profiles` table migration (AC: #2)
  - [x] New file `supabase/migrations/<timestamp>_create_profiles.sql`
  - [x] Columns exactly as specified in AC #2; `id` FK references `auth.users(id)`; add `CHECK (role IN ('dispatcher','driver'))` on `role` as a defensive guardrail (the only two values any client ever passes, per AD-2)
  - [x] Enable RLS on `profiles` (policies added in Task 4 — do not leave RLS disabled even temporarily once the table is live)

- [x] Task 3 — `claim_role` RPC (AC: #2, #3, #4)
  - [x] Append to `supabase/functions.sql` (do not create a separate file — see Dev Notes on shared files)
  - [x] `SECURITY DEFINER`, and explicitly `SET search_path = public` in the function definition (see Dev Notes — this is a real security requirement, not in the architecture doc)
  - [x] Parameter name is a cross-story API contract — use exactly `p_role` (see Dev Notes: "RPC Parameter Naming Contract")
  - [x] Logic: reject if `auth.uid()` is null; if no existing `profiles` row for the caller, insert one with `role = p_role` and `full_name = COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name')` read from `auth.users` for `id = auth.uid()`; if an existing row has `role = p_role` already, no-op success (idempotent — see Dev Notes); if an existing row has a **different** role, `RAISE EXCEPTION`

- [x] Task 4 — RLS policies for `profiles` (AC: #5, #6)
  - [x] Append to `supabase/policies.sql` (do not create a separate file)
  - [x] One SELECT policy: `USING (true)` for the `authenticated` role
  - [x] Deliberately add **no** INSERT/UPDATE/DELETE policy for `authenticated`/`anon` on `profiles` — with RLS enabled and no such policy, all direct-client writes are denied by default, which is what satisfies AC #5 (see Dev Notes — do not add a self-update policy "to be safe," it isn't needed and would reopen the hole AD-2/AD-6 exist to close)

- [x] Task 5 — Manual verification (AC: all)
  - [x] Apply the migration, `functions.sql`, and `policies.sql` to the live Supabase project (SQL Editor or CLI — see Dev Notes on execution mechanics; no automated test suite is in scope per NFR/non-goals)
  - [x] Call `claim_role('dispatcher')` as a fresh test user with no `profiles` row → row created, `full_name` populated
  - [x] Call `claim_role('dispatcher')` again as the same user → no-op success, no error, no duplicate row
  - [x] Call `claim_role('driver')` as that same (now-dispatcher) user → exception raised, role unchanged
  - [x] Attempt a direct `UPDATE profiles SET role = 'driver' WHERE id = auth.uid()` as an authenticated client (e.g., via `supabase-js` with the anon key, or `curl` against PostgREST) → rejected/no rows affected, re-`SELECT` confirms `role` unchanged
  - [x] `SELECT * FROM profiles` as any authenticated test user → all rows returned

### Review Findings

Adversarial code review of the Epic 1 Supabase contract (2026-07-09). Both fixed in the working tree; each still needs applying to the live project (see the review's deploy checklist).

- [x] [Review][Patch][Low] `profiles` never revoked Supabase's default write privileges [flovi/supabase/migrations/20260708181326_create_profiles.sql] — Supabase auto-grants INSERT/UPDATE/DELETE to `authenticated` on new public tables. profiles was write-locked by RLS default-deny alone (no write policy), so `role`/`completed_rides_count` were not directly exploitable — but that rested solely on no permissive write policy ever being added later, unlike every other table which revokes explicitly. Fixed: added `grant select` + `revoke insert, update, delete on public.profiles from authenticated`.
- [x] [Review][Patch][Low] SECURITY DEFINER `search_path` left `pg_temp` implicitly first (all 5 RPCs) [flovi/supabase/functions.sql] — `set search_path = public` leaves an unlisted `pg_temp` implicitly searched *before* `pg_catalog`, so an unqualified built-in (`now()`, `pg_sleep()`) could in principle be shadowed by a `pg_temp` object under the definer's privileges. Not exploitable via PostgREST (the `authenticated` API role can't create pg_temp objects) — defense-in-depth. Fixed across all 5 RPCs: `set search_path = pg_catalog, public, pg_temp` (pg_catalog pinned first, pg_temp pinned last).

## Dev Notes

**Scope boundary:** This story only builds `claim_role` and the `profiles` table. Story 2.1/3.1 will each write the actual client-side `.rpc('claim_role', ...)` call — get the parameter name right now so those later, independently-built stories don't guess differently.

### RPC Parameter Naming Contract (fix now, cross-story)
`claim_role`'s SQL parameter must be named exactly `p_role` (not `role` — that would collide with/shadow the `profiles.role` column inside the function body and risk ambiguous-column errors). Supabase clients call RPCs with named parameters matching the SQL declaration, so both future call sites must use this exact key:
- Vue (Story 2.1): `supabase.rpc('claim_role', { p_role: 'dispatcher' })`
- Flutter (Story 3.1): `supabase.rpc('claim_role', params: {'p_role': 'driver'})`

### Security: `SET search_path` on `SECURITY DEFINER` functions
Not mentioned in ARCHITECTURE-SPINE.md, but a hard Postgres/Supabase security requirement: any `SECURITY DEFINER` function must pin `SET search_path = public` in its definition, or it's vulnerable to search-path-injection (a malicious `public`-schema object shadowing an unqualified reference the function relies on). Apply this to `claim_role` now — it applies equally to `book_request`/`cancel_request_dispatcher`/`cancel_request_driver`/`complete_request` when those are built in later Epic 1 stories.

### Why no UPDATE policy on `profiles` (don't "improve" this)
AD-4 mentions `role`/`completed_rides_count` are "write-locked," which might read as "add an UPDATE policy that excludes those columns." Don't — no capability in this project ever needs a client-facing UPDATE on `profiles` at all (every write path is a `SECURITY DEFINER` RPC, which bypasses RLS entirely by running as the function owner). The simplest correct implementation is **zero** UPDATE policy on `profiles`, which RLS's default-deny turns into "no client can update any column of any row." Adding a permissive self-update policy "to be safe" would be a real regression — it would let any authenticated user directly overwrite their own `role` or `completed_rides_count`, defeating AD-2 (permanent role) and AD-6 (priority ranking integrity) via a path that doesn't go through the RPCs' checks at all.

### Idempotent reclaim of the same role
No AC explicitly covers calling `claim_role` twice with the *same* role, but Stories 2.1/3.1 only describe calling it "on first sign-in" — if either client's first-time detection isn't perfectly reliable (or simply calls `claim_role` on every login rather than gating it), a same-role reclaim must not error. Only a role **mismatch** raises an exception; a same-role call is a harmless no-op success.

### Execution mechanics for `supabase/migrations`, `functions.sql`, `policies.sql`
The architecture's source tree keeps `functions.sql` and `policies.sql` as flat, cumulative files (not one file per RPC/policy, and not folded into `migrations/`) — Stories 1.2 through 1.5 will each append more to these same two files. There's no CI/CD or local Supabase CLI/Docker setup in scope (explicitly deferred, and would burn time against the 4-hour cap) — the fastest correct path is applying these SQL files directly against the single live hosted Supabase project via the SQL Editor (or `supabase db push`/`psql` if already set up locally), not standing up a full local dev stack. Whichever method is used, the `.sql` files themselves still need to exist and be committed in the repo for NFR4's commit-history requirement — the repo is the source of truth even though execution is manual/direct.

### Tailwind v4 setup (breaking change from v3 — don't use old patterns)
`stack.md`/`ARCHITECTURE-SPINE.md` pin Tailwind `^4.3`. V4 is CSS-first and has no `tailwind.config.js`/PostCSS step by default — do not generate one. Correct v4 + Vite setup: `npm install tailwindcss @tailwindcss/vite`, add the `tailwindcss()` plugin in `vite.config.ts`, and `@import "tailwindcss";` as the only line needed in the main CSS file. (Full design-token wiring into this setup happens in Story 2.1 — this story only needs the scaffold to be v4-correct so 2.1 isn't built on a v3 foundation.)

### Project Structure Notes
Per ARCHITECTURE-SPINE.md's source tree:
```
flovi/
  apps/dispatcher-web/     # Vue 3 + Vite + Tailwind — scaffold only in this story
  apps/driver-mobile/      # Flutter 3, web build target — scaffold only in this story
  supabase/
    migrations/            # this story adds the profiles migration only
    functions.sql          # this story appends claim_role only
    policies.sql            # this story appends the profiles SELECT policy only
    seed.sql                 # placeholder in this story; populated in Story 1.6
```
No conflicts detected — this is a from-scratch scaffold (repo has zero commits; `apps/`, `supabase/` don't exist yet).

### Testing standards summary
No automated test suite is in scope (explicit non-goal, SPEC.md Constraints). Verification for this story is manual RPC calls + direct SELECT/UPDATE attempts against the live Supabase project, per Task 5.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.1: Profiles Schema & Role-Claiming RPC]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-2 — Role assignment is a fixed claim-role RPC call, immutable after first write]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-4 — Dispatcher visibility and mutation are owner-scoped, never a shared pool]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Stack]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Source tree]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#CAP-1, CAP-5]
- [External: Tailwind CSS v4 + Vite install guide — https://tailwindcss.com/docs/installation/using-vite]
- [External: Supabase `SECURITY DEFINER` / `search_path` hardening — https://supabase.com/docs/guides/database/postgres/row-level-security]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- Flutter SDK and Supabase CLI were not present on the dev machine; installed via `brew install --cask flutter` and `brew install supabase/tap/supabase` after user confirmation.
- `flutter create driver-mobile` fails directly ("driver-mobile" is not a valid Dart package name); used `flutter create --platforms=web --project-name=driver_mobile driver-mobile` to keep the directory name matching the architecture source tree while satisfying Dart's package-name rules.
- Manual verification (Task 5) was run directly against the user's live Supabase Postgres instance via `psql`, simulating an authenticated session with `SET ROLE authenticated` + `set_config('request.jwt.claim.sub', ...)` to exercise RLS and `auth.uid()` exactly as PostgREST would. Test user and its `profiles` row were deleted after verification; no residual test data left in the project.

### Completion Notes List

- Root-level scaffold: `flovi/apps/dispatcher-web` (Vite + Vue 3 + Tailwind v4, CSS-first — `@tailwindcss/vite` plugin wired into `vite.config.js`, `@import "tailwindcss";` added to `src/style.css`), `flovi/apps/driver-mobile` (Flutter, web platform only), `flovi/supabase/{migrations,functions.sql,policies.sql,seed.sql}`.
- Added root `.gitignore` (node_modules, build/dist output, Dart tooling artifacts, `_bmad/`, `.claude/`, `.DS_Store`).
- First commit made to `main` (previously zero commits) containing the `flovi/` scaffold plus `docs/` and `_bmad-output/` planning artifacts, per user decision to include planning docs as delivery artifacts (Story 4.2 scope). `_bmad/` (framework installation) and `.claude/` (local agent config) intentionally excluded.
- `profiles` table migration, `claim_role` RPC (SECURITY DEFINER, `search_path=public`, `p_role` parameter per the cross-story naming contract), and the single `profiles` SELECT policy were all written per Dev Notes guidance — no UPDATE/INSERT/DELETE policy added by design.
- Task 5 verification executed against the user's live Supabase project (connection string supplied directly by user for this session only) — all six checks in the task passed on the first attempt: row creation with `full_name` populated, idempotent same-role reclaim, exception on role-mismatch reclaim, direct client `UPDATE` blocked (0 rows affected) by RLS default-deny, and open `SELECT` returning all rows for `authenticated`.
- Did not push the new commit to `origin` — local commit only, per instruction to confirm before pushing shared/remote state.

### File List

- `.gitignore` (new)
- `flovi/apps/dispatcher-web/**` (new — Vite/Vue3 scaffold; Tailwind v4 wiring in `vite.config.js`, `src/style.css`)
- `flovi/apps/driver-mobile/**` (new — Flutter web scaffold, package name `driver_mobile`)
- `flovi/supabase/migrations/20260708181326_create_profiles.sql` (new)
- `flovi/supabase/functions.sql` (new — `claim_role` RPC)
- `flovi/supabase/policies.sql` (new — `profiles` SELECT policy)
- `flovi/supabase/seed.sql` (new — empty placeholder)
