# Story 1.2: Relocation Request Schema, Dispatcher CRUD & Cancellation

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a signed-in dispatcher,
I want to create, view, edit, and cancel my own relocation requests at the database level,
so that the web app has a reliable, correctly-scoped backend to build against.

## Acceptance Criteria

1. **Given** no `relocation_requests` table exists yet, **when** this story is complete, **then** a `relocation_requests` table exists with columns `id (uuid PK)`, `created_by (uuid FK profiles)`, `driver_id (uuid FK profiles, nullable)`, `origin (text)`, `destination (text)`, `scheduled_date (date)`, `notes (text)`, `status (text)`, `created_at (timestamptz)`, `updated_at (timestamptz)`, **and** an INSERT trigger forces `status = 'unbooked'` and `driver_id = NULL` regardless of client-supplied values, and defaults `created_by` server-side to `auth.uid()`.
2. **Given** a signed-in dispatcher, **when** they INSERT a new relocation request (any origin/destination/date/notes, even with a status or driver_id attached), **then** it is created in `unbooked` status, owned by them, with `driver_id NULL` — the trigger overrides any client-supplied status/driver_id/created_by.
3. **Given** a signed-in dispatcher who owns request R, **when** they SELECT or UPDATE non-status columns on R, **then** RLS policy `dispatcher_own` permits it, gated on `role = 'dispatcher'` AND `created_by = auth.uid()`.
4. **Given** a signed-in dispatcher who does not own request R, **when** they attempt to SELECT or UPDATE request R, **then** RLS blocks it — no cross-dispatcher visibility or mutation (AD-4).
5. **Given** a signed-in dispatcher who owns request R in any non-`cancelled` status, including `completed`, **when** they call `cancel_request_dispatcher(R)`, **then** the RPC verifies caller role is `dispatcher` and `created_by = auth.uid()`, then sets `status = 'cancelled'` — succeeds regardless of current status per CAP-10's "at any time" rule.
6. **Given** a signed-in driver (not dispatcher), or a dispatcher who does not own R, **when** they call `cancel_request_dispatcher(R)`, **then** the RPC raises an exception and no change occurs.

## Tasks / Subtasks

- [ ] Task 1 — `relocation_requests` table migration (AC: #1)
  - [ ] New file `supabase/migrations/<timestamp>_create_relocation_requests.sql`, timestamped **after** Story 1.1's profiles migration (this table's `created_by`/`driver_id` FK-reference `profiles(id)`, which must already exist)
  - [ ] Columns exactly as specified in AC #1; `created_at`/`updated_at` default `now()`
  - [ ] `CHECK (status IN ('unbooked','booked','completed','cancelled'))` — the fixed 4-value enum from the state machine, defensive guardrail matching AD-5's "no aliases" rule
  - [ ] `BEFORE INSERT` trigger: force `NEW.status := 'unbooked'`, `NEW.driver_id := NULL`, `NEW.created_by := auth.uid()` unconditionally, regardless of what the client sent in those fields
  - [ ] Add a `BEFORE UPDATE` trigger setting `NEW.updated_at := now()` on every update (not explicitly required by an AC, but the column exists for exactly this and nothing else sets it)
  - [ ] Enable RLS on `relocation_requests`

- [ ] Task 2 — Column-scoped privileges (AC: #1, #2, #3)
  - [ ] `GRANT SELECT, INSERT ON relocation_requests TO authenticated;` — full-row SELECT/INSERT (the BEFORE INSERT trigger neutralizes dangerous INSERT values, so INSERT does **not** need column restriction — see Dev Notes, this is a deliberate contrast with Task 3)
  - [ ] `REVOKE UPDATE ON relocation_requests FROM authenticated;` then `GRANT UPDATE (origin, destination, scheduled_date, notes) ON relocation_requests TO authenticated;` — column-level UPDATE grant covering only the CAP-4-editable fields; `status`/`driver_id`/`created_by`/`id`/timestamps stay off-limits to direct client UPDATE (see Dev Notes — this is the mechanism, not a trigger, and it's different from Story 1.1's "no UPDATE policy at all" approach because here *some* columns must remain client-editable)
  - [ ] Do not grant DELETE to `authenticated` at all — no capability ever deletes a request

- [ ] Task 3 — `dispatcher_own` RLS policy (AC: #3, #4)
  - [ ] Append to `supabase/policies.sql` (same cumulative file Story 1.1 started — do not create a new file)
  - [ ] One `FOR ALL` policy named `dispatcher_own`: `USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'dispatcher' AND created_by = auth.uid())`, same expression as `WITH CHECK`
  - [ ] This is the *only* RLS policy this story adds — `driver_visibility` is Story 1.3's scope; until 1.3 runs, drivers see zero rows from this table via RLS, which is expected (Epic 3 doesn't build against this until Epic 1 is fully done anyway)

- [ ] Task 4 — `cancel_request_dispatcher` RPC (AC: #5, #6)
  - [ ] Append to `supabase/functions.sql` (same cumulative file as `claim_role`)
  - [ ] `SECURITY DEFINER`, `SET search_path = public` (same requirement established in Story 1.1 — applies to every RPC in this project)
  - [ ] Parameter name: `p_request_id uuid` — pinned cross-story contract, see Dev Notes ("RPC Parameter Naming Contract, continued")
  - [ ] Logic: verify `auth.uid()` resolves to a `profiles` row with `role = 'dispatcher'`; verify the target row's `created_by = auth.uid()`; if either check fails, `RAISE EXCEPTION`; if the target row's `status = 'cancelled'` already, treat as a harmless no-op (idempotent, same reasoning as Story 1.1's same-role reclaim — no AC requires erroring on a double-cancel); otherwise `UPDATE relocation_requests SET status = 'cancelled' WHERE id = p_request_id` — this UPDATE runs as the function owner, so it is **not** blocked by Task 2's column-level lockdown (see Dev Notes)

- [ ] Task 5 — Manual verification (AC: all)
  - [ ] Apply the migration, plus the new `functions.sql`/`policies.sql` contents, to the live Supabase project
  - [ ] As dispatcher A: INSERT a request including a spoofed `status: 'booked'` and `driver_id` → confirm row lands as `unbooked`/`driver_id NULL`/`created_by = A`
  - [ ] As dispatcher A: direct `UPDATE relocation_requests SET notes = 'x' WHERE id = <own row>` → succeeds; direct `UPDATE ... SET status = 'cancelled' WHERE id = <own row>` → rejected with a column-permission error (not silently ignored)
  - [ ] As dispatcher B: attempt SELECT/UPDATE on dispatcher A's row → RLS blocks both
  - [ ] As dispatcher A: call `cancel_request_dispatcher` on a `completed` row they own → succeeds, status becomes `cancelled`
  - [ ] As a driver test account (or a dispatcher who doesn't own the row): call `cancel_request_dispatcher` on dispatcher A's row → exception raised, no change

## Dev Notes

**Builds directly on Story 1.1's shared files and conventions** — this story appends to the same `supabase/functions.sql`/`policies.sql` Story 1.1 started, and reuses its `SECURITY DEFINER` + `SET search_path = public` pattern and its `p_`-prefixed RPC parameter naming convention. If Story 1.1 hasn't actually been implemented yet when this story is picked up, implement both together in the order they're numbered (1.1's migration/functions/policies must exist first — this table FK-references `profiles`).

### Why INSERT and UPDATE get different lockdown mechanisms
This is the key design decision in this story, and it's easy to get wrong by copying Story 1.1's pattern uncritically:
- **INSERT** (Task 2): grant it broadly, no column restriction. A legitimate client only ever sends `origin`/`destination`/`scheduled_date`/`notes`, but AC #2 explicitly requires tolerating a client that *also* sends `status`/`driver_id` — the BEFORE INSERT trigger silently overwrites those to safe values instead of the statement failing. If you column-REVOKE `status`/`driver_id` from INSERT the way you'd REVOKE them from UPDATE, a client that includes those keys in its insert payload gets a hard permission-denied error instead of a silently-corrected row — that breaks AC #2's actual tolerance requirement.
- **UPDATE** (Task 2): the opposite — column-REVOKE is exactly the enforcement mechanism, because unlike INSERT there's no "trigger silently fixes it" expectation for UPDATE. AC #3 says dispatcher can update "non-status columns"; there is no BEFORE UPDATE trigger that resets `status` back if a client changes it, so without the column-level REVOKE, a direct client UPDATE to `status` would just succeed — which would let any dispatcher bypass `cancel_request_dispatcher`/CAP-3's RPC-only state-machine invariant (AD-3) entirely.

### Column-level privileges + RLS — confirmed Supabase-supported pattern
RLS is row-level only; it has no concept of "this column is off-limits." Postgres's own column-level `GRANT`/`REVOKE` is the correct, standard tool for this, and it composes cleanly with RLS: `REVOKE UPDATE ON relocation_requests FROM authenticated; GRANT UPDATE (origin, destination, scheduled_date, notes) ON relocation_requests TO authenticated;` — Postgres checks column privileges first (fails outright with a permission error if a restricted column is in the `SET` list) and only then evaluates the RLS `USING`/`WITH CHECK` predicates for the columns you *do* have access to. This is a documented Supabase feature ("Column Level Security"), not a workaround — the plain SQL `GRANT`/`REVOKE` works regardless of whether you also toggle Supabase Studio's dashboard UI for it (that UI is just a visual wrapper; a migration-file `GRANT`/`REVOKE` is sufficient on its own).
**Forward-looking gotcha for Story 2.2 (Requests list)**: Supabase's own docs warn that a role with column-restricted privileges on a table cannot use `select('*')` against it — the client's future `.select()` call against `relocation_requests` should name columns explicitly rather than wildcard, even though this story only restricts UPDATE (not SELECT), to avoid surprises.

### RPC Parameter Naming Contract, continued
Story 1.1 pinned `claim_role(p_role text)`. This story pins `cancel_request_dispatcher(p_request_id uuid)`. **Recommend the same `p_request_id` name be reused for `book_request`, `cancel_request_driver`, and `complete_request` when Stories 1.3–1.5 build them** — consistency here means Epic 2/Epic 3's client code (built independently, possibly much later) only has to remember one convention. Do not name the parameter `id` or `request_id` — `relocation_requests`'s own PK column is literally `id`, and `notifications`/`booking_bids` (Stories 1.3/1.4) have a column literally called `request_id`; either name risks an ambiguous-column-reference error inside the function body or confusing inconsistency once those tables exist. Client call site (Story 2.4): `supabase.rpc('cancel_request_dispatcher', { p_request_id: requestId })`.

### Why the RPC's own UPDATE isn't blocked by Task 2's REVOKE
`cancel_request_dispatcher` is `SECURITY DEFINER`, so its statements execute with the function *owner's* privileges (typically a superuser/owner role), not the calling client's `authenticated` role — Task 2's column-level REVOKE only restricts what `authenticated` can do via direct table access (e.g., PostgREST), not what a SECURITY DEFINER function can do internally. This is the same bypass mechanism AD-3 describes for why each RPC must independently check the caller via `auth.uid()` rather than relying on privileges/RLS to protect it.

### Testing standards summary
No automated test suite in scope (SPEC.md non-goal). Verify manually per Task 5 — direct SQL/RPC calls against the live project with at least two dispatcher test accounts (seed data with multiple dispatchers doesn't exist until Story 1.6, so use ad-hoc test accounts or manually-inserted `profiles` rows for this story's verification).

### Project Structure Notes
```
supabase/
  migrations/
    <ts1>_create_profiles.sql              # Story 1.1
    <ts2>_create_relocation_requests.sql    # this story — ts2 > ts1
  functions.sql   # append cancel_request_dispatcher after claim_role
  policies.sql    # append dispatcher_own after the profiles SELECT policy
```
No conflicts — `relocation_requests` doesn't exist yet; this is additive.

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.2: Relocation Request Schema, Dispatcher CRUD & Cancellation]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-3 — Single write path for every state transition, self-checked at the RPC]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#AD-4 — Dispatcher visibility and mutation are owner-scoped, never a shared pool]
- [Source: _bmad-output/specs/spec-relocation-dispatch/state-machines.md — Transitions table, `unbooked → cancelled` / `booked → cancelled`]
- [Source: _bmad-output/specs/spec-relocation-dispatch/SPEC.md#CAP-2, CAP-3, CAP-4, CAP-10]
- [Source: _bmad-output/implementation-artifacts/1-1-profiles-schema-role-claiming-rpc.md — shared-file conventions, `p_`-prefix RPC parameter pattern, `SET search_path` requirement]
- [External: Supabase Column Level Security — https://supabase.com/docs/guides/database/postgres/column-level-security]

## Dev Agent Record

### Agent Model Used

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
