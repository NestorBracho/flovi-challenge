# Story 3.1: App Shell, Design Tokens, Login & Role Claiming

Status: ready-for-dev

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

- [ ] Task 1 — Design tokens as a `ThemeExtension`, not force-fit into Material's `ColorScheme` (AC: #1)
  - [ ] DESIGN.md's ~24 named colors, 6 typography styles, 4 rounded steps, 8 spacing steps, and 2 elevation levels don't map cleanly onto Material's fixed `ColorScheme`/`TextTheme` slots (different names, different count). The correct Flutter pattern for a custom, non-Material token set is a custom `ThemeExtension<T>` — keeps tokens type-safe, centrally defined, and retrievable via `Theme.of(context).extension<FloviTokens>()`, rather than scattering hardcoded `Color`/`double` constants through widget code or awkwardly renaming DESIGN.md's tokens to fit Material's own semantic slots (`primary`, `surface`, etc.)
  - [ ] Register the extension in `ThemeData(extensions: [FloviTokens(...)])`, passed to `MaterialApp.theme`

- [ ] Task 2 — Elevation: DESIGN.md's warm shadow is not Flutter's default (AC: #1)
  - [ ] Flutter's built-in `Card`/`Material` `elevation` property renders Material's own default shadow — a neutral gray/black-based shadow, **not** warm-toned. DESIGN.md is explicit: "soft, warm-toned shadow, never a hard drop shadow." Using bare `elevation: N` on a Card looks plausible (something *is* rendered) but is visually wrong in a way no functional check would catch — only an actual look at the screen would. Use a custom `BoxDecoration(boxShadow: [BoxShadow(color: <warm tone derived from text-primary or accent, low opacity>, ...)])` for "raised" surfaces instead of relying on Material's own elevation shadow color.

- [ ] Task 3 — Pin light mode explicitly, don't just omit a dark theme (AC: #1)
  - [ ] `MaterialApp`'s default `themeMode` is `ThemeMode.system` — if the operator's OS/browser happens to be in dark mode during the actual demo (an increasingly common default), Flutter will still try to resolve *a* dark theme, falling back to Flutter's own generic dark Material theme (not DESIGN.md's palette at all) if no `darkTheme` is supplied. Set `themeMode: ThemeMode.light` explicitly on `MaterialApp` — don't assume "we didn't define a dark theme" is sufficient on its own.

- [ ] Task 4 — Routing, path-based URLs, and the dedicated `/auth/callback` route (AC: #3)
  - [ ] Add a routing package — `go_router` is the standard choice for a declarative `/auth/callback` deep-link route (bare `flutter create` ships no router at all)
  - [ ] Call `usePathUrlStrategy()` (from `package:flutter_web_plugins/url_strategy.dart`) early in `main()`, before `runApp()` — this is the concrete mechanism behind the AC's "avoiding Flutter web's hash-router collision": Flutter web defaults to hash-based URLs (`/#/auth/callback`), which collides with an OAuth redirect expecting a path-based URL. Switching to path-based routing is what a dedicated, real `/auth/callback` route actually requires to work.
  - [ ] **This choice has a forward consequence for Story 3.5** (deploy to Vercel): path-based routing via the History API requires the web server to rewrite any direct-navigation request back to `index.html` — the exact same class of SPA-fallback gap flagged in Story 2.5 for the Vue app. Story 3.5 will need its own `vercel.json` rewrite for the same reason.
  - [ ] `Supabase.initialize(url: ..., anonKey: ..., authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce))` — `supabase_flutter` automatically detects the auth callback URL's params once the app lands on the registered `/auth/callback` route; the route handler just needs to wait for the resulting auth-state change and then navigate on to Gigs, not manually parse the URL itself
  - [ ] **Where `url`/`anonKey` actually come from — pin this now, not at deploy time**: Flutter web has no runtime `.env`/`import.meta.env` equivalent (it's a compiled/AOT output, not a Node server reading process env at request time). Read both via `String.fromEnvironment('SUPABASE_URL')` / `String.fromEnvironment('SUPABASE_ANON_KEY')`, and pass the actual values as `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` at both `flutter run` (local dev — e.g. via a VS Code launch config's `args`, or a wrapper script) and `flutter build web` (Story 3.5's production build) time. Establishing this now means Story 3.5 only has to supply different flag *values*, not invent the config mechanism itself.

- [ ] Task 5 — `claim_role('driver')` call and its failure modes (AC: #3, #4)
  - [ ] Call **exactly** `Supabase.instance.client.rpc('claim_role', params: {'p_role': 'driver'})` — the fixed cross-epic parameter contract pinned in Story 1.1 (Vue's Story 2.1 used the same key as a named JS object; Dart's `params` map needs the identical key)
  - [ ] Call this on every successful OAuth completion, not a detected "first-time" one — same reasoning as Story 2.1: Story 1.1's RPC is idempotent for a same-role reclaim, so no first-time-detection logic is needed client-side
  - [ ] Same unnamed gap as Story 2.1, mirrored here: if the signed-in Google account already holds the `dispatcher` role, `claim_role('driver')` throws (by design). Handle it the same way — sign back out, return to Login, with a message in EXPERIENCE.md's voice (not a sourced verbatim string, since none exists for this state): "This Google account is already registered as a dispatcher — sign in through the dispatcher app instead."
  - [ ] OAuth-failure copy **is** verbatim-fixed (quoted identically in epics.md and EXPERIENCE.md): `"We couldn't sign you in — try again."`

- [ ] Task 6 — Tab bar shell and accessibility baseline (AC: #5, #6, #7)
  - [ ] Bottom tab bar: exactly 3 tabs (Gigs / Booked / Profile). DESIGN.md doesn't give this component an explicit visual recipe (unlike the dispatcher-web components it does spec in detail) — Material's default `BottomNavigationBar`/`NavigationBar` showing icon + visible text label per tab is a safe, accessible default that satisfies "accessible label" trivially, since the label is real visible text, not just a screen-reader-only attribute
  - [ ] Tap targets ≥44×44px: Flutter's default Material `IconButton` and tab bar items already use a 48×48 logical-pixel minimum touch target out of the box — this AC is satisfied by *not* shrinking that via `visualDensity`/`materialTapTargetSize`/explicit tight constraints, rather than something requiring new work
  - [ ] Visible focus indicator: Material widgets do show *some* default focus highlight, but it won't automatically match DESIGN.md's specific 2px accent-colored ring. Build a small reusable focus-ring wrapper (a `Focus` widget toggling a themed border via `onFocusChange`, or a custom `InkWell`/`FocusableActionDetector` focus-color override) using the `FloviTokens` focus-ring color from Task 1, applied to every interactive element from this story forward — same "establish the baseline component now" reasoning Story 2.1 used for its shared icon-button
  - [ ] Single-column, 18-22px side margins, phone-width — structure the app shell so this holds regardless of whether the demo browser window is phone-sized or a full desktop window (UX-DR19's explicit Flutter-web-demo constraint)

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

_To be filled by dev agent during implementation._

### Debug Log References

### Completion Notes List

### File List
