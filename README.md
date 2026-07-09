# Flovi — Relocation Dispatch Demo

Two connected apps sharing one Supabase backend: a **dispatcher web app** for creating and tracking relocation requests, and a **driver mobile app** for browsing and booking them — built for the Flovi AI Build Challenge (4-hour cap, AI-generated code only).

## Live

- **Dispatcher web:** https://flovi-challenge.vercel.app
- **Driver mobile:** https://flovi-driver-mobile.vercel.app

Sign-in is Google OAuth only, on both apps — the account you sign up with permanently claims either the dispatcher or driver role and cannot switch. Seeded demo accounts in the database exist for UI variety and priority-ranking competition only; they have no real Google identity behind them and **cannot sign in** — use a real Google account on each app.

## What it does

- **Dispatcher:** create/edit/cancel relocation requests, see live status as drivers act on them, get notified when a driver cancellation triggers an automatic reassignment.
- **Driver:** browse unbooked gigs, book one in a tap with a fair concurrent-booking priority rule (highest completed-rides count wins), cancel with ≥24h notice, mark a gig complete.
- **Both directions sync live** — no manual refresh anywhere — via Supabase Realtime, RLS-scoped per user.

Full capability list: [`_bmad-output/specs/spec-relocation-dispatch/SPEC.md`](_bmad-output/specs/spec-relocation-dispatch/SPEC.md).

## Architecture

```
flovi/
  apps/dispatcher-web/   # Vue 3 + Vite + Tailwind CSS
  apps/driver-mobile/    # Flutter 3 (web build)
  supabase/
    migrations/          # schema
    functions.sql        # SECURITY DEFINER RPCs (claim_role, book_request, cancel_*, complete_request)
    policies.sql          # RLS policies
    seed.sql               # demo data
```

One shared Supabase project is the only backend — no custom server. Every state transition (booking, cancellation, completion) goes through a `SECURITY DEFINER` RPC that independently re-checks the caller, rather than relying on client-trusted writes. Realtime is scoped to exactly `relocation_requests` and `notifications`, gated by RLS at delivery time. Details and the reasoning behind each of these choices: [`_bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md`](_bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md).

## Running locally

Both apps point at the same live Supabase project — there's no local Supabase stack to stand up.

**Dispatcher web:**
```bash
cd flovi/apps/dispatcher-web
npm install
cp .env.example .env   # fill in VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY
npm run dev            # serves on :5173 (fixed — registered in Supabase's OAuth redirect allow-list)
```

**Driver mobile:**
```bash
cd flovi/apps/driver-mobile
flutter pub get
cp dart_defines.json.example dart_defines.json   # fill in SUPABASE_URL / SUPABASE_ANON_KEY
./scripts/run_web.sh   # flutter run -d chrome --web-port=5000 (fixed — same reason as above)
```

Neither `.env` nor `dart_defines.json` is committed. Only the Supabase **anon** key is ever used client-side — the service-role key has no legitimate use in this architecture and is never referenced anywhere in this repo.

## Backend

Schema, RPCs, and policies live as plain `.sql` files under `flovi/supabase/` and are applied directly against the hosted Supabase project (SQL Editor / CLI) — no migration-runner CI is in scope for a 4-hour build. See each Epic 1 story file under `_bmad-output/implementation-artifacts/` for the reasoning behind specific choices (e.g. why the booking-priority mechanic needs a two-step client call, or why RLS alone isn't enough to lock down `profiles`).

## Delivery artifacts

This challenge grades prompting, product judgment, debugging, delivery, and reflection — not just the running code:

- [`PROMPT_LOG.md`](PROMPT_LOG.md) — key prompts across the build, what came back, what was changed and why
- [`REFLECTION.md`](REFLECTION.md) — written reflection (structured around the presentation questions)
- [`SUBMISSION_CHECKLIST.md`](SUBMISSION_CHECKLIST.md) — live URLs, repo link, and delivery logistics
- [`_bmad-output/implementation-artifacts/`](_bmad-output/implementation-artifacts/) — every story's full spec, task breakdown, and dev record (the raw material the prompt log is curated from)
