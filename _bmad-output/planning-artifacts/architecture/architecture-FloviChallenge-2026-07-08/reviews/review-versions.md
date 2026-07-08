# Stack Version Reality-Check — Flovi Relocation-Dispatch

**Reviewed doc:** `ARCHITECTURE-SPINE.md` § Stack
**Check date:** 2026-07-08 (web search, not training-data recall)
**Verdict: Stack table is accurate as of today. One real, unaddressed risk found (Flutter web + Supabase OAuth callback handling); one low-severity note; no dead/renamed/discontinued technologies.**

---

## Row-by-row verification

| Row | Spine claim | Verified current reality | Status |
| --- | --- | --- | --- |
| Vue | ^3.5 (3.6 beta, not used) | Latest stable is 3.5.39 (~13 days old). 3.6.0-beta.17 shipped 2026-06-24, still pre-release, focused on Vapor mode; classic VDOM (what 3.5 line uses) unaffected/unchanged. | **Confirmed accurate.** The "3.6 is beta, deliberately not used" framing is correct and current. |
| Vite | ^8.1 | Vite 8.0 stable shipped 2026-03-12 (Rolldown/Rust bundler now default, "full plugin compatibility" claimed). Latest is 8.1.3 (~5 days old). | **Confirmed accurate and current.** |
| Tailwind CSS | ^4.3 | Latest is 4.3.2, released 2026-06-29. v4.3 adds scrollbar utilities, zoom/tab utilities, container-size queries. | **Confirmed accurate and current.** |
| Flutter | 3.44 (stable channel) | Flutter 3.44 released May 2026 (Google I/O), stable channel. Headline items: Swift Package Manager default for iOS/macOS, Agentic Hot Reload via Dart/Flutter MCP server, embedded-systems wins (Toyota RAV4, LG webOS). | **Confirmed accurate and current.** |
| @supabase/supabase-js | ^2.110 | Latest on npm is 2.110.1, published ~3 hours before this check. | **Confirmed accurate and current** (moving target — pin, don't float, given the release cadence). |
| supabase_flutter | ^2.12 | Latest on pub.dev is 2.12.4, released ~1 month ago. | **Confirmed accurate and current.** |
| Supabase | hosted platform | Platform is live and actively operated. Status history shows normal ops: a Feb 12 2026 us-east-2 outage (3h42m, AWS VPC config issue, resolved), routine early-July 2026 capacity/project-creation incidents (resolved), and a scheduled maintenance window 2026-07-09 03:00–04:00 UTC (tomorrow, right after this project's "created" date). Nothing suggests instability disqualifying it for this project. | **Confirmed exists, confirmed suitable.** Note the 7/9 maintenance window if any demo/deploy work is time-sensitive. |
| Vercel | hosting | Confirmed as an active, current, standard deploy target for both Vite-built SPAs and Flutter web (`build/web`) static output — multiple 2026-dated guides describe deploying Flutter web to Vercel via static-output directory, no framework-detection blockers. | **Confirmed accurate and current.** |

No technology in the table is deprecated, renamed, sunset, or fictional. Nothing required a "can't verify" flag — all eight rows returned direct, dated confirmation.

---

## Fit-for-purpose and compatibility checks

### Vite 8 + Tailwind 4.3 + @vitejs/plugin-vue (dispatcher-web toolchain)
Official `@tailwindcss/vite` support for Vite 8 landed in Tailwind 4.2.2 (2026-03-18), so 4.3.x carries it forward. Standard `vue()` + `tailwindcss()` plugin setup is documented working together with no special-casing. **No incompatibility found** for the plain Vue+Vite stack this project uses.

- Low-severity note: a `@tailwindcss/vite` **type-level** mismatch was reported against **Nuxt** 4.3.1 (nuxt/nuxt#34384) — a rollup-types declaration clash (`viteVersion` missing from `PluginContextMeta`), confirmed cosmetic (runtime unaffected, `tsc --noEmit` clean, fixed via `skipLibCheck` or pinning). **Not applicable** to this project: dispatcher-web is plain Vue+Vite, not Nuxt, so this doesn't apply — flagging only because it surfaced during the Tailwind/Vite compatibility check and a reader might see the same-numbered issue and worry.

### supabase_flutter on Flutter web (driver-mobile) — the check the task specifically asked for
This is the one place I'd push back on the spine as currently written.

**Realtime (Postgres Changes) on Flutter web:** works — it's a standard WebSocket client, platform-agnostic. However, the supabase-flutter GitHub repo has open/recent issues describing realtime streams silently going stale after a period of inactivity (no exception thrown, channel just stops receiving events, doesn't self-recover) and reconnection/token-refresh edge cases (supabase/supabase-flutter#1012, #982). This is a general supabase_flutter realtime reliability caveat, not web-specific, but it directly touches AD-5/AD-6/AD-9's "realtime is the only sync path, no polling fallback" commitment — a long-lived dispatcher/driver session that goes stale with no fallback and no error surfaced is a real risk the spine's "no polling fallback" rule doesn't hedge against.

**OAuth on Flutter web — the sharper issue:** Flutter web's documented, current default routing is **hash-based** (`/#/path`, via `flutter_web_plugins`), and this is unchanged as of the 2026-05-05-updated Flutter docs — there is no indication Flutter is changing this default. Supabase's OAuth implicit-flow callback also returns tokens in a **URL fragment** (`#access_token=...`). Multiple issues (including the very first ever filed against supabase-flutter, "Flutter Web Login," #1) and community threads describe the two hash-mechanisms colliding: Flutter's router consumes/strips the `#` before Supabase's SDK can parse the token out of it, breaking the callback. supabase_flutter has since made **PKCE the default flow "for any authentication involving deep links"** — but the docs and changelog language specifically frame that default around deep links (native app callback), not the plain-browser redirect flow driver-mobile will use as a Flutter **web build**. The docs' own recommended fix for the web case is to explicitly set `authFlowType: AuthFlowType.pkce` in `FlutterAuthClientOptions` at init, and/or to switch to `usePathUrlStrategy()` (History API instead of hash), and/or route the OAuth callback through a dedicated `/auth/callback` path rather than relying on default routing.

**Why this matters for the spine specifically:** AD-2 commits driver-mobile to "calls `claim_role('driver')` immediately after its first OAuth callback" and the deployment diagram ships driver-mobile as a Flutter **web build**, not a native binary — i.e., exactly the configuration where this known Flutter-web/Supabase-OAuth hash collision applies, and exactly the opposite of the native-deep-link case PKCE-by-default was framed to solve. The spine currently says nothing about `authFlowType`, callback route shape, or URL strategy for driver-mobile. This isn't a "wrong technology" problem — supabase_flutter is still the correct, current, actively-maintained choice — but it's a **known, documented gotcha in exactly the untested seam this task asked me to check**, and the spine as written doesn't address it. I'd flag it as a gap to close before/during implementation (pin `AuthFlowType.pkce` explicitly for driver-mobile's Supabase init, and decide/route a fixed OAuth callback path), not as a reason to change the stack.

---

## Summary

- All 8 Stack-table version pins verified current and accurate via web search dated 2026-07-08 (Vue 3.5.39 stable / 3.6 beta, Vite 8.1.3, Tailwind 4.3.2, Flutter 3.44 stable, supabase-js 2.110.1, supabase_flutter 2.12.4, Supabase platform live, Vercel active and Flutter-web-capable).
- No stale, mismatched, deprecated, or unverifiable technology found.
- One real risk to flag back to the architect: Flutter web's default hash-based routing vs. Supabase OAuth's fragment-based callback is a known, recurring compatibility gotcha for exactly this project's driver-mobile-as-web-build configuration; the spine doesn't currently pin `authFlowType`/callback-route handling to avoid it.
- One low-severity, not-applicable note: a Tailwind-4.3.1/Nuxt type-mismatch issue exists upstream but doesn't apply to this project's plain Vue+Vite setup.
- Secondary, general note: supabase_flutter realtime has documented (non-web-specific) staleness/reconnect edge cases relevant to AD-5's "no polling fallback" commitment.
