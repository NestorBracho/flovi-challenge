---
name: Flovi
description: Warm, human relocation-dispatch product. Two surfaces (dispatcher web, driver mobile) sharing one calm, confident visual language.
status: final
updated: 2026-07-08
colors:
  surface-canvas: '#FAF6F0'
  surface-card: '#FFFFFF'
  surface-tint: '#F5EEE3'
  border-subtle: '#EAE0D0'
  border-hairline: '#F0E9DC'
  text-primary: '#3D3630'
  text-secondary: '#786F65'
  text-tertiary: '#B0A697'
  accent: '#BF582A'
  accent-tint: '#F4E1D2'
  focus-ring: '#BF582A'
  status-unbooked: '#D99A2B'
  status-unbooked-text: '#8A5A0A'
  status-unbooked-tint: '#FBEDD1'
  status-booked: '#3E7C8C'
  status-booked-text: '#2A5C68'
  status-booked-tint: '#DEEBEE'
  status-completed: '#5B8C6E'
  status-completed-text: '#3E6B51'
  status-completed-tint: '#E2EEE6'
  status-cancelled: '#B8503D'
  status-cancelled-text: '#8F3D2E'
  status-cancelled-tint: '#F6E1DB'
typography:
  display:
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'
    fontSize: '24px'
    fontWeight: 700
    letterSpacing: '-0.01em'
  heading:
    fontSize: '18px'
    fontWeight: 700
  body:
    fontSize: '14px'
    fontWeight: 500
  body-strong:
    fontSize: '14px'
    fontWeight: 700
  meta:
    fontSize: '12.5px'
    fontWeight: 600
  label:
    fontSize: '11.5px'
    fontWeight: 700
    letterSpacing: '0.03em'
rounded:
  xs: 10px
  sm: 12px
  md: 16px
  lg: 22px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 20px
  '6': 24px
  '7': 32px
  '8': 40px
components:
  button-primary:
    background: '{colors.accent}'
    color: '#FFFFFF'
    rounded: '{rounded.full}'
    paddingY: 11px
    paddingX: 20px
  button-ghost:
    background: '{colors.surface-card}'
    color: '{colors.text-secondary}'
    border: '1px solid {colors.border-subtle}'
    rounded: '{rounded.full}'
  focus-ring:
    color: '{colors.focus-ring}'
    width: 2px
    offset: 2px
  status-pill:
    rounded: '{rounded.full}'
    paddingY: 6px
    paddingX: 13px
  card:
    background: '{colors.surface-card}'
    border: '1px solid {colors.border-hairline}'
    rounded: '{rounded.md}'
  modal:
    background: '{colors.surface-card}'
    rounded: '{rounded.lg}'
  stat-tile:
    background: '{colors.surface-card}'
    border: '1px solid {colors.border-hairline}'
    rounded: '{rounded.md}'
---

> **Canonical contract, paired with `EXPERIENCE.md`.** This DESIGN.md owns *how it looks*; EXPERIENCE.md owns *how it works*. Both win on conflict with any mock, wireframe, or import. Derived from `mockups/direction-warm-approachable.html` (one of three explored directions — operator-grade and bold-energetic were rejected).

## Brand & Style

Flovi is a warm, human register for a product that coordinates real people's moving days — not a ticketing system. Generous whitespace, soft rounded cards, and a single confident terracotta accent read as calm and trustworthy rather than clinical or hyped. The dispatcher surface favors scannable card lists over dense data tables; the driver surface favors a small number of large, confident, unambiguous actions. Nothing decorative competes with the content — the warmth comes from spacing and tone, not ornament.

## Colors

The palette is a warm cream canvas, not sterile white, with one chromatic accent reserved for action.

- **Canvas (`{colors.surface-canvas}`)** — the base background across both apps. Warm, not clinical.
- **Card (`{colors.surface-card}`)** — pure white, used only for raised surfaces (cards, modals, phone screens) so it reads as "lifted" against the canvas.
- **Tint (`{colors.surface-tint}`)** — the input-field / secondary-surface fill, a shade warmer than card white.
- **Border subtle / hairline** — two weights of the same warm-neutral border; `subtle` frames cards, `hairline` divides internal chrome (sidebar, tab bar).
- **Text primary / secondary / tertiary** — a warm near-black for primary content, a warm gray for supporting text (`{colors.text-secondary}`, contrast-checked to clear AA on both canvas and card), and a lighter warm gray (`{colors.text-tertiary}`) reserved for **decorative or redundant** marks only — never the sole rendering of real information (see Do's and Don'ts).
- **Accent (`{colors.accent}`, terracotta) + accent-tint** — the *only* chromatic color used for action: primary buttons, links, the route arrow between origin/destination. Never used decoratively. Nav-item active state uses accent only as a small indicator, never as the label's text color (see Components).
- **`{colors.focus-ring}`** — reuses the accent hue for the one universal focus indicator (see Do's and Don'ts).
- **Four status color families** (unbooked / booked / completed / cancelled), each with three roles: a full-saturation swatch (`status-X`, for small non-text marks like a stat-tile icon or a dot), a **darker `status-X-text`** for anything rendered as legible pill text, and a light `status-X-tint` for pill backgrounds. The full-saturation swatch and the text color are deliberately different shades of the same hue — the saturated version reads well as a small icon/dot but fails contrast as text-on-tint, so pill *text* always uses the `-text` variant, never the raw swatch. All `-text` variants are contrast-checked to clear 4.5:1 against their paired tint at the pill's actual (11.5-12.5px) rendered size. These four families are the only place besides the accent where color carries meaning, and they must stay consistent everywhere a request's status appears (dispatcher list, driver gig card, notifications — see Components for whether notifications render a pill).

Avoid: a second chromatic accent, gradients, saturated fills outside the status-pill/accent system, using a status's full-saturation swatch as text color.

## Typography

System font stack throughout (no custom typeface). Two standard weight steps only — `600` and `700` — since system fonts reliably expose these without a variable-font load; `display` (24px/700) and `heading` (18px/700, modal/dialog titles) carry the weight of hierarchy since color is reserved for status/action. `body` (14px/500) is the default; `body-strong` (14px/700) marks primary values inside a row (a route, a name) against `text-secondary` supporting detail. `label` (11.5px/700, uppercase, tracked) marks field labels and section headers. `meta` (12.5px/600) is for dates, counts, and timestamps — timestamps and counts are real information, so they use `text-secondary`, never `text-tertiary`.

## Layout & Spacing

Scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40px. Cards and list rows use 12-16px internal padding; the gap *between* cards in a list is consistently 12px; the gap between major page regions (header → stat row → filter chips → list) is 20-24px. Dispatcher web: a fixed 220px sidebar + fluid main column, desktop-first with a hard floor at 1024px — below that width the app shows a "best viewed on a larger screen" notice rather than attempting a responsive reflow (this is a stated constraint, not an oversight). Driver mobile: single column, 18-22px side margins, bottom tab bar always visible except on the full-screen booking-confirmation interstitial.

## Elevation & Depth

Two levels only: **flat** (canvas, sidebar, tab bar — no shadow) and **raised** (cards, modals, the phone frame itself — a soft, warm-toned shadow, never a hard drop shadow). Modals additionally get a soft dark overlay (`{colors.text-primary}` at 35% opacity) rather than a pure-black scrim, staying in the warm palette even in its neutral moments.

## Shapes

`{rounded.xs}` (10px) for small square marks (the brand mark). `{rounded.sm}` (12px) for inputs and nav items. `{rounded.md}` (16px) for cards — request cards, gig cards, stat tiles. `{rounded.lg}` (22px) for modals, the largest surface. `{rounded.full}` for every button, pill, chip, and the search field — the pill shape is reserved for interactive or status-bearing elements, never for passive containers.

## Components

- **Button, primary** (`{components.button-primary}`) — accent fill, white text (contrast-checked at 4.52:1), full-rounded. The one loud element per screen (new request, book this gig, save).
- **Button, ghost** (`{components.button-ghost}`) — white fill, subtle border, secondary text color. Cancel / secondary actions.
- **Focus ring** (`{components.focus-ring}`) — a 2px accent-colored outline, 2px offset, applied to *every* interactive element (buttons, chips, inputs, the modal's ✕, sidebar nav items, tab bar icons) on focus. Not optional and not limited to the modal — this is the app's only visible-focus mechanism, since a from-scratch Tailwind build strips the native outline by default.
- **Status pill** (`{components.status-pill}`) — full-rounded, a small solid dot (uses the full-saturation `status-X` swatch) + label (uses `status-X-text`), background = that status's tint. Three redundant cues (dot + text + tint), never color-only.
- **Card** (`{components.card}`) — the base shape for request cards and gig cards; white on hairline border, soft shadow.
- **Stat tile** (`{components.stat-tile}`) — same shape family as Card but visually non-interactive (no hover/press state, no focus ring) — a static count display, not a filter control (see EXPERIENCE.md to avoid confusing it with Filter chip).
- **Modal — New/Edit Request** (`{components.modal}`) — centered, 420px, used on the dispatcher web app only (driver mobile uses full-screen interstitials instead, never a centered modal — modals don't fit one-handed mobile use).
- **Booking confirmation** — full-screen interstitial (driver mobile only, never a modal): large check-icon in `status-completed-tint`/`status-completed`, heading, a `Card`-styled summary of the route/date/notes, single full-width primary button through to Booked gigs.
- **Notification item** — plain text row, no status pill (see Do's and Don'ts) — bold request route + plain-weight description of what happened, `text-secondary` timestamp. Unread items get a small accent-colored dot in the sidebar nav count badge, not on the row itself.
- **Booked-gig row** — inherits `Card`; adds a right-aligned action area showing either "Cancel" (`button-ghost`, only when ≥24h remains) or a muted disabled label explaining the 24h lock, plus a "Mark complete" (`button-ghost`) action, both visible only while the gig is in `booked` status.
- **Filter chip** — full-rounded, white/border when inactive, solid `text-primary` fill when active (deliberately *not* the accent color, so the accent stays reserved for calls-to-action).
- **Sidebar nav item** — 12px-rounded row, accent-tint background when active; label text stays `text-primary` (never accent-colored, to avoid a low-contrast tinted-background-plus-hued-text pairing); the accent hue appears only as a small left-edge indicator bar and the count badge.
- **Empty-state panel** — dashed border (not solid), icon circle in `surface-tint`, single ghost-button recovery action. Signals "nothing here yet," visually distinct from an error.

## Do's and Don'ts

| Do | Don't |
| --- | --- |
| One accent color, reserved for action | A second chromatic color for "flair" |
| Status meaning carried by pill background + dot + text (three redundant cues) | Color-only status indication |
| A status's `-text` variant for any pill text | A status's full-saturation swatch as text (fails contrast on its own tint) |
| `text-tertiary` for decorative/redundant marks only | `text-tertiary` as the sole rendering of real information (timestamps, counts use `text-secondary`) |
| A visible focus ring on every interactive element | Relying on a framework's default (Tailwind strips it) |
| Full-screen interstitial for driver mobile confirmations | A centered modal on mobile |
| Dashed border for empty states | Reusing the solid-border card style for "nothing here" |
| Soft, warm-toned shadows | Hard black drop shadows or skeuomorphic bevels |
| Card lists for the dispatcher's request feed | Dense multi-column data tables |
