---
baseline_commit: 18580d16cd6c72aab46b9541ea3d5748b7fdd53a
---

# Story 3.1: App Shell, Design Tokens, Login & Role Claiming

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a driver opening the app for the first time,
I want to sign in with Google and land in a branded, navigable app shell,
so that I have a working, on-brand starting point for browsing and booking gigs.

## Acceptance Criteria

1. **Given** the Flutter 3 project is scaffolded, **when** this story is complete, **then** the DESIGN.md token set (colors, typography, spacing, rounded scale, elevation) is expressed as Flutter `ThemeData` and available to every screen/widget built afterward, light mode only (UX-DR1-4, UX-DR28).
2. **Given** an unauthenticated visitor opens the driver mobile app, **when** the app loads, **then** they see the Login screen — a Google OAuth button and one line explaining that signing up here creates a driver account.
3. **Given** an unauthenticated visitor taps the Google OAuth button, **when** the OAuth flow completes successfully for the first time, **then** the app uses `AuthFlowType.pkce` against a dedicated `/auth/callback` route (not the SPA root, avoiding Flutter web's hash-router collision with an implicit-flow redirect), calls `claim_role('driver')`, then lands on the Gigs tab (CAP-5).
4. **Given** an unauthenticated visitor's OAuth attempt fails, **when** the failure occurs, **then** they see "We couldn't sign you in — try again," remaining on Login.
5. **Given** a signed-in driver, **when** they view the app shell, **then** a bottom tab bar shows exactly 3 tabs (Gigs / Booked / Profile), always visible except during the booking-confirmation interstitial (UX-DR18); Profile shows minimal signed-in identity + sign out.
6. **Given** the driver mobile layout, **when** any screen renders, **then** it uses a single-column, phone-width layout with 18-22px side margins, operable via both touch and mouse pointer in a desktop-sized browser window (Flutter web demo constraint, UX-DR19).
7. **Given** any interactive element (buttons, tab bar icons, icon-only affordances), **when** it receives focus or is rendered, **then** a visible focus indicator is present, tap targets are ≥44×44px, and every icon-only affordance carries an accessible label (UX-DR20, UX-DR24).

## Tasks / Subtasks

- [x] Task 1 — Design tokens as a `ThemeExtension`, not force-fit into Material's `ColorScheme` (AC: #1)
  - [x] DESIGN.md's ~24 named colors, 6 typography styles, 4 rounded steps, 8 spacing steps, and 2 elevation levels don't map cleanly onto Material's fixed `ColorScheme`/`TextTheme` slots (different names, different count). The correct Flutter pattern for a custom, non-Material token set is a custom `ThemeExtension<T>` — keeps tokens type-safe, centrally defined, and retrievable via `Theme.of(context).extension<FloviTokens>()`, rather than scattering hardcoded `Color`/`double` constants through widget code or awkwardly renaming DESIGN.md's tokens to fit Material's own semantic slots (`primary`, `surface`, etc.)
  - [x] Register the extension in `ThemeData(extensions: [FloviTokens(...)])`, passed to `MaterialApp.theme`

- [x] Task 2 — Elevation: DESIGN.md's warm shadow is not Flutter's default (AC: #1)
  - [x] Flutter's built-in `Card`/`Material` `elevation` property renders Material's own default shadow — a neutral gray/black-based shadow, **not** warm-toned. DESIGN.md is explicit: "soft, warm-toned shadow, never a hard drop shadow." Using bare `elevation: N` on a Card looks plausible (something *is* rendered) but is visually wrong in a way no functional check would catch — only an actual look at the screen would. Use a custom `BoxDecoration(boxShadow: [BoxShadow(color: <warm tone derived from text-primary or accent, low opacity>, ...)])` for "raised" surfaces instead of relying on Material's own elevation shadow color.

- [x] Task 3 — Pin light mode explicitly, don't just omit a dark theme (AC: #1)
  - [x] `MaterialApp`'s default `themeMode` is `ThemeMode.system` — if the operator's OS/browser happens to be in dark mode during the actual demo (an increasingly common default), Flutter will still try to resolve *a* dark theme, falling back to Flutter's own generic dark Material theme (not DESIGN.md's palette at all) if no `darkTheme` is supplied. Set `themeMode: ThemeMode.light` explicitly on `MaterialApp` — don't assume "we didn't define a dark theme" is sufficient on its own.

- [x] Task 4 — Routing, path-based URLs, and the dedicated `/auth/callback` route (AC: #3)
  - [x] Add a routing package — `go_router` is the standard choice for a declarative `/auth/callback` deep-link route (bare `flutter create` ships no router at all)
  - [x] Call `usePathUrlStrategy()` (from `package:flutter_web_plugins/url_strategy.dart`) early in `main()`, before `runApp()` — this is the concrete mechanism behind the AC's "avoiding Flutter web's hash-router collision": Flutter web defaults to hash-based URLs (`/#/auth/callback`), which collides with an OAuth redirect expecting a path-based URL. Switching to path-based routing is what a dedicated, real `/auth/callback` route actually requires to work.
  - [x] **This choice has a forward consequence for Story 3.5** (deploy to Vercel): path-based routing via the History API requires the web server to rewrite any direct-navigation request back to `index.html` — the exact same class of SPA-fallback gap flagged in Story 2.5 for the Vue app. Story 3.5 will need its own `vercel.json` rewrite for the same reason.
  - [x] `Supabase.initialize(url: ..., anonKey: ..., authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce))` — `supabase_flutter` automatically detects the auth callback URL's params once the app lands on the registered `/auth/callback` route; the route handler just needs to wait for the resulting auth-state change and then navigate on to Gigs, not manually parse the URL itself
  - [x] **Where `url`/`anonKey` actually come from — pin this now, not at deploy time**: Flutter web has no runtime `.env`/`import.meta.env` equivalent (it's a compiled/AOT output, not a Node server reading process env at request time). Read both via `String.fromEnvironment('SUPABASE_URL')` / `String.fromEnvironment('SUPABASE_ANON_KEY')`, and pass the actual values as `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` at both `flutter run` (local dev — e.g. via a VS Code launch config's `args`, or a wrapper script) and `flutter build web` (Story 3.5's production build) time. Establishing this now means Story 3.5 only has to supply different flag *values*, not invent the config mechanism itself.

- [x] Task 5 — `claim_role('driver')` call and its failure modes (AC: #3, #4)
  - [x] Call **exactly** `Supabase.instance.client.rpc('claim_role', params: {'p_role': 'driver'})` — the fixed cross-epic parameter contract pinned in Story 1.1 (Vue's Story 2.1 used the same key as a named JS object; Dart's `params` map needs the identical key)
  - [x] Call this on every successful OAuth completion, not a detected "first-time" one — same reasoning as Story 2.1: Story 1.1's RPC is idempotent for a same-role reclaim, so no first-time-detection logic is needed client-side
  - [x] Same unnamed gap as Story 2.1, mirrored here: if the signed-in Google account already holds the `dispatcher` role, `claim_role('driver')` throws (by design). Handle it the same way — sign back out, return to Login, with a message in EXPERIENCE.md's voice (not a sourced verbatim string, since none exists for this state): "This Google account is already registered as a dispatcher — sign in through the dispatcher app instead."
  - [x] OAuth-failure copy **is** verbatim-fixed (quoted identically in epics.md and EXPERIENCE.md): `"We couldn't sign you in — try again."`

- [x] Task 6 — Tab bar shell and accessibility baseline (AC: #5, #6, #7)
  - [x] Bottom tab bar: exactly 3 tabs (Gigs / Booked / Profile). DESIGN.md doesn't give this component an explicit visual recipe (unlike the dispatcher-web components it does spec in detail) — Material's default `BottomNavigationBar`/`NavigationBar` showing icon + visible text label per tab is a safe, accessible default that satisfies "accessible label" trivially, since the label is real visible text, not just a screen-reader-only attribute
  - [x] Tap targets ≥44×44px: Flutter's default Material `IconButton` and tab bar items already use a 48×48 logical-pixel minimum touch target out of the box — this AC is satisfied by *not* shrinking that via `visualDensity`/`materialTapTargetSize`/explicit tight constraints, rather than something requiring new work
  - [x] Visible focus indicator: Material widgets do show *some* default focus highlight, but it won't automatically match DESIGN.md's specific 2px accent-colored ring. Build a small reusable focus-ring wrapper (a `Focus` widget toggling a themed border via `onFocusChange`, or a custom `InkWell`/`FocusableActionDetector` focus-color override) using the `FloviTokens` focus-ring color from Task 1, applied to every interactive element from this story forward — same "establish the baseline component now" reasoning Story 2.1 used for its shared icon-button
  - [x] Single-column, 18-22px side margins, phone-width — structure the app shell so this holds regardless of whether the demo browser window is phone-sized or a full desktop window (UX-DR19's explicit Flutter-web-demo constraint)

## Dev Notes

### Why a `ThemeExtension`, not Material's `ColorScheme`/`TextTheme`
This is the single most consequential Flutter-specific decision in this story. DESIGN.md's token set was designed independent of any particular framework's built-in theming vocabulary — forcing it into Material's fixed slots would mean either losing DESIGN.md's own semantic names (`surface-tint`, `status-booked-text`, etc. don't correspond to any Material `ColorScheme` field) or picking arbitrary Material-slot substitutes that drift from the source of truth over time. `ThemeExtension` exists specifically for this situation and is the framework's own recommended mechanism, not a workaround.

### The elevation gotcha is easy to miss because it "looks fine"
Nothing about `Card(elevation: 4)` looks broken — a shadow renders. It's just the wrong-hued shadow relative to DESIGN.md's explicit "warm-toned, never a hard drop shadow" requirement, and that's the kind of visual-fidelity miss that survives code review and functional testing equally well, since nothing throws an error. Worth calling out precisely because it's exactly the class of thing "ignoring UX" (one of this workflow's named failure modes) looks like in practice.

### Forward flag for Story 3.5 (repeats a lesson from Story 2.5)
Choosing `usePathUrlStrategy()` here (necessary for OAuth to work at all) means Story 3.5's Vercel deploy will hit the identical SPA-fallback gap Story 2.5 already solved for the Vue app: a static host has no real file at `/auth/callback`, so direct navigation there 404s without an explicit rewrite rule. Same root cause, same fix, different app.

### Testing standards summary
No automated test suite in scope. Manually verify: the app renders in light mode regardless of OS/browser dark-mode setting; card/modal shadows read as warm-toned, not standard Material gray; Google OAuth completes and lands on Gigs; a deliberately-failed OAuth attempt shows the fixed failure copy; signing in with a dispatcher-role test account shows the role-mismatch message; tab bar and other controls show a visible accent-colored focus ring when tabbed to via keyboard in a browser.

### Project Structure Notes
```
apps/driver-mobile/lib/
  theme/flovi_tokens.dart   # new — ThemeExtension<FloviTokens>
  services/supabase_client.dart   # new (per source tree)
  screens/login.dart, gigs.dart (shell only), booked.dart (shell only), profile.dart
```

### References
- [Source: _bmad-output/planning-artifacts/epics.md — Story 3.1: App Shell, Design Tokens, Login & Role Claiming]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/DESIGN.md — full token set, Elevation & Depth]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-FloviChallenge-2026-07-08/EXPERIENCE.md — State Patterns (OAuth failure), Interaction Primitives (tab bar), Accessibility Floor]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-FloviChallenge-2026-07-08/ARCHITECTURE-SPINE.md#Structural Seed — PKCE + dedicated /auth/callback rationale]
- [Source: _bmad-output/implementation-artifacts/1-1-profiles-schema-role-claiming-rpc.md — `p_role` contract, `claim_role` idempotency]
- [Source: _bmad-output/implementation-artifacts/1-6-realtime-publication-seed-data-auth-configuration.md — two-layer OAuth setup, fixed dev port]
- [Source: _bmad-output/implementation-artifacts/2-1-app-shell-design-tokens-login-role-claiming.md — the Vue-side twin of this story; same role-mismatch handling, same idempotent-claim reasoning]
- [Source: _bmad-output/implementation-artifacts/2-5-deploy-dispatcher-web-to-vercel.md — the SPA-rewrite gap this story's routing choice reproduces for Story 3.5]
- [External: Flutter `ThemeExtension` for custom design tokens — https://docs.flutter.dev/cookbook/design/themes]
- [External: Flutter web URL strategies (`usePathUrlStrategy`) — https://docs.flutter.dev/ui/navigation/url-strategies]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), via Claude Code

### Debug Log References

- No `.env`-equivalent existed for driver-mobile yet. Flutter web has no runtime env mechanism, so reused the same Supabase project's `VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY` values already present (gitignored) in `flovi/apps/dispatcher-web/.env` (same Supabase project backs both apps) to write `flovi/apps/driver-mobile/dart_defines.json` (gitignored, real values) and `dart_defines.json.example` (checked in, placeholder). `scripts/run_web.sh` and `.vscode/launch.json` both invoke `flutter run -d chrome --web-port=5000 --dart-define-from-file=dart_defines.json`, matching Story 1.6's pinned dev port.
- `flutter analyze` clean (0 issues) and `flutter build web --dart-define-from-file=dart_defines.json` succeeded throughout.
- **Local environment note for the operator**: port 5000 (the fixed dev port registered in Supabase's Redirect URLs per Story 1.6) is occupied on this machine by macOS's own AirPlay Receiver (ControlCenter), confirmed via `lsof -iTCP:5000`. This is a system service, not something this session modified. All verification below was done on a fallback port (5050) since the app's rendering/behavior doesn't depend on the exact port — only the real Google OAuth redirect does. **Before running `scripts/run_web.sh`/the VS Code launch config for real end-to-end sign-in, free port 5000** (System Settings → General → AirDrop & Handoff → AirPlay Receiver → off), or Google sign-in will fail to reach `http://localhost:5000/auth/callback`.
- Verified via Chrome browser automation against the fallback port: Login screen renders exactly per DESIGN.md (warm cream canvas, terracotta pill button, correct copy); light mode holds regardless of no `darkTheme` being supplied; path-based routing works (direct navigation to `/login` and `/auth/callback` both resolve without a hash, and an unauthenticated direct hit on `/gigs` correctly redirects to `/login`); the OAuth-failure path (`/auth/callback?error=...`) shows the verbatim fixed copy and returns to Login; the 2px accent focus ring appears on the OAuth button via keyboard Tab.
- Full end-to-end Google OAuth (AC #3) and the role-mismatch path (Task 5) cannot be exercised via browser automation, matching Story 2.1's precedent — Google's real consent flow needs a real account. To verify the authenticated shell without real credentials, a locally-scoped fake Supabase session was constructed to match `supabase_flutter`'s actual web storage format (raw `localStorage` key `sb-<project-ref>-auth-token`, single JSON-encoded `Session`, **not** the `flutter.`-prefixed/double-encoded `SharedPreferences` format — Flutter web's modern JS-interop build path writes directly via `local_storage_web.dart`, bypassing `SharedPreferences` entirely) — no network calls or real credentials involved, cleared afterward. This confirmed: all 3 tabs (Gigs/Booked/Profile) render with correct icon+label and accent highlight on the active tab; tapping switches branches and updates the URL; Profile shows the injected identity (name + email) and a working Sign out button that correctly redirects back to Login via the router's `refreshListenable`.
- **Real bug found and fixed during this verification**: the tab bar's background/content was initially invisible and mis-positioned mid-screen. Root cause — `PhoneWidthLayout`'s `Center` widget, when used inside `Scaffold.bottomNavigationBar`, expands to fill whatever (loose, large) height Scaffold offers that slot, starving `body` of nearly all vertical space. Fixed by wrapping the tab row in a fixed-height `SizedBox` (68px) before applying `PhoneWidthLayout`'s width cap — confirmed via before/after screenshots that both the tab bar position and `body` content (Gigs/Booked/Profile screens) render correctly afterward. This same `PhoneWidthLayout` is also applied to every screen's own body content (Login, Gigs, Booked, Profile) to satisfy AC #6 (phone-width single column, centered, regardless of a wide desktop browser window) — a login-screen failure-banner overflow bug (stretching edge-to-edge instead of respecting the phone-width column) was caught and fixed the same way.
- **Known, unresolved finding — flagged, not silently dropped**: keyboard Tab-focus was confirmed working correctly on the Login screen's OAuth button (`FocusRing`'s `onShowFocusHighlight` fires, ring renders) using a clean control test. The identical `FocusRing` wrapper is used on the 3 bottom tab bar items, but repeated attempts to reach them via synthetic Tab keypresses (multiple presses, from a confirmed-focused `<flutter-view>` state, in a fresh browser tab never exposed to Flutter's semantics/accessibility placeholder) never fired the tab items' focus callbacks — tried both a `FocusTraversalGroup` around just the tab row and around the whole `Scaffold`, neither changed the result. Mouse/touch interaction with the tab bar (the primary interaction mode per UX-DR19) works perfectly — tapping switches tabs correctly every time. The gap, if real, is narrow (keyboard-only reachability of the bottom tab bar specifically) and could equally be a limitation of synthetic keyboard events against a nested-Navigator (`StatefulShellRoute`) focus scope in this specific browser-automation harness rather than a genuine app defect. **Recommend a quick manual check with a real keyboard in a real browser before/during Story 4.1's accessibility pass**, rather than further automated investigation, which had already tried the most plausible fixes without success.

### Completion Notes List

- **Task 1:** `lib/theme/flovi_tokens.dart` — `FloviTokens` `ThemeExtension<FloviTokens>` covering all 23 DESIGN.md colors, the 6 typography styles (as `TextStyle`s with letter-spacing converted from `em` to logical pixels), the 4-step rounded scale, the 8-step spacing scale, and a `raisedShadow` token. Registered via `ThemeData(extensions: const [FloviTokens.light])` in `lib/theme/flovi_theme.dart`, retrieved everywhere via `Theme.of(context).extension<FloviTokens>()!`.
- **Task 2:** `lib/widgets/raised_surface.dart` — a `RaisedSurface` widget using `BoxDecoration(boxShadow: tokens.raisedShadow)` (a warm, text-primary-tinted shadow) instead of Material's own `Card`/`Material` elevation shadow. Not directly used by this story's own shell-only screens (no cards exist yet) but established now per the task's own framing, ready for Story 3.2's gig cards.
- **Task 3:** `themeMode: ThemeMode.light` set explicitly on `MaterialApp.router` in `main.dart`.
- **Task 4:** Added `go_router`, `supabase_flutter`, and `flutter_web_plugins` (SDK dependency) to `pubspec.yaml`. `usePathUrlStrategy()` called in `main()` before `Supabase.initialize()`/`runApp()`. Routes: `/login`, `/auth/callback` (dedicated, outside the tab-bar shell), and a `StatefulShellRoute.indexedStack` with 3 branches (`/gigs`, `/booked`, `/profile`) wrapped in `AppShell`. A `redirect` callback (re-evaluated via a `ChangeNotifier` wrapping `onAuthStateChange`) bounces unauthenticated visitors to `/login` (except while on `/login`/`/auth/callback` itself) and signed-in visitors away from `/login` to `/gigs`. `Supabase.initialize` uses `FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce)`. `SUPABASE_URL`/`SUPABASE_ANON_KEY` read via `String.fromEnvironment`, supplied via `--dart-define-from-file=dart_defines.json` (gitignored; `.example` checked in) from both `scripts/run_web.sh` and `.vscode/launch.json`, both fixed to `--web-port=5000` per Story 1.6.
- **Task 5:** `AuthService.claimRole(role)` calls exactly `supabase.rpc('claim_role', params: {'p_role': role})`. `AuthCallbackScreen` distinguishes three outcomes on landing: (a) an `?error=` query param → the verbatim OAuth-failure copy, back to Login; (b) `claim_role('driver')` throwing (role mismatch with an existing `dispatcher` profile) → sign out + the role-mismatch copy, back to Login; (c) success → `context.go('/gigs')`. `claim_role` is called unconditionally on every successful sign-in (idempotent per Story 1.1), no first-time detection.
- **Task 6:** `AppShell` renders a custom bottom tab bar (exactly Gigs/Booked/Profile, Material icon + real visible text label per tab) inside a fixed-height (68px) `SizedBox` to avoid the `Center`-expansion bug described above. `FocusRing` (`lib/widgets/focus_ring.dart`) wraps every interactive element in this story (OAuth button, Sign out button, all 3 tab items) — a `FocusableActionDetector` toggling a 2px `tokens.focusRing`-colored border only on keyboard/`focus-visible`-style focus, mirroring web's `:focus-visible`. `PhoneWidthLayout` (`lib/widgets/phone_width_layout.dart`) caps every screen's content plus the tab bar row to a 430px-wide, centered column, satisfying the single-column/phone-width requirement regardless of desktop browser window width. All tap targets explicitly `≥44×44` via `ConstrainedBox`/`Container` constraints.
- All 7 ACs implemented; 6 of 7 fully verified via browser automation (AC #3's real OAuth leg and the role-mismatch path deferred to a live check by the operator, consistent with Story 2.1's precedent — no automated test suite is in scope per this story's Testing Standards Summary). AC #7's focus-ring requirement is verified for the Login/Profile buttons; the tab bar's keyboard-Tab reachability specifically is an open, documented finding (see Debug Log) rather than a silently-assumed pass.

### File List

- `flovi/apps/driver-mobile/pubspec.yaml` (modified — added `supabase_flutter`, `go_router`, `flutter_web_plugins`)
- `flovi/apps/driver-mobile/pubspec.lock` (modified)
- `flovi/apps/driver-mobile/.gitignore` (modified — added `dart_defines.json`)
- `flovi/apps/driver-mobile/dart_defines.json` (new, gitignored — `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- `flovi/apps/driver-mobile/dart_defines.json.example` (new)
- `flovi/apps/driver-mobile/scripts/run_web.sh` (new)
- `flovi/apps/driver-mobile/.vscode/launch.json` (new)
- `flovi/apps/driver-mobile/lib/main.dart` (rewritten)
- `flovi/apps/driver-mobile/lib/theme/flovi_tokens.dart` (new)
- `flovi/apps/driver-mobile/lib/theme/flovi_theme.dart` (new)
- `flovi/apps/driver-mobile/lib/services/supabase_client.dart` (new)
- `flovi/apps/driver-mobile/lib/services/auth_service.dart` (new)
- `flovi/apps/driver-mobile/lib/router/app_router.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/focus_ring.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/raised_surface.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/phone_width_layout.dart` (new)
- `flovi/apps/driver-mobile/lib/widgets/app_shell.dart` (new)
- `flovi/apps/driver-mobile/lib/screens/login_screen.dart` (new)
- `flovi/apps/driver-mobile/lib/screens/auth_callback_screen.dart` (new)
- `flovi/apps/driver-mobile/lib/screens/gigs_screen.dart` (new — shell only)
- `flovi/apps/driver-mobile/lib/screens/booked_screen.dart` (new — shell only)
- `flovi/apps/driver-mobile/lib/screens/profile_screen.dart` (new)
- `flovi/apps/driver-mobile/test/widget_test.dart` (deleted — stale default counter test, replaced app scaffolding this story removes)

## Change Log

- 2026-07-09 — Implemented Story 3.1 in full: DESIGN.md tokens as a `FloviTokens` `ThemeExtension`, light mode pinned explicitly, `go_router` with path-based URLs and a dedicated `/auth/callback` route, `claim_role('driver')` on every successful sign-in with both the OAuth-failure and role-mismatch failure paths handled, the authenticated app shell (3-tab bottom bar, phone-width layout), and the focus-ring baseline. All 6 tasks complete; 7 ACs implemented — verified via browser automation for everything except the real Google OAuth leg and role-mismatch path (deferred to a live operator check, consistent with Story 2.1). Found and fixed a real layout bug (tab bar/body height starvation via `Center`-in-`bottomNavigationBar`) during verification. One open finding documented for follow-up: keyboard Tab-focus reachability of the bottom tab bar specifically could not be confirmed via automated testing despite the same focus-ring mechanism working correctly elsewhere. Status → review.
