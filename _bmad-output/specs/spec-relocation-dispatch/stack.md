# Tech Stack

> Frontend/mobile/hosting are the source's own suggestion ("you may deviate with good reason"), kept as defaults. Backend is **decided** — Supabase, confirmed by the user. SPEC.md's Constraints stay implementation-free per Spec Law; this is where the HOW lives.

| Layer | Choice | Status |
| --- | --- | --- |
| Frontend (dispatcher web) | Vue 3 + Vite + Tailwind CSS | suggested default |
| Mobile (driver app) | Flutter 3 | suggested default |
| Backend/DB | **Supabase** | decided |
| Hosting | Vercel or Netlify (web); Flutter web build for the mobile demo | suggested default |
| AI tools | Cursor, Claude, Copilot — whichever is fastest for the operator | suggested default |

## Why Supabase

CAP-9 (real-time/near-real-time sync) and the CAP-12/CAP-13 cancellation-reassignment-notification loop are the capabilities most at risk under a 4-hour cap. Supabase's built-in realtime subscriptions, row-level auth, and Postgres transactions cover all three with the least custom plumbing: realtime channels for CAP-9/CAP-13, and a transactional check on booking/cancellation for the CAP-7/CAP-12 priority rule (see `state-machines.md`).

