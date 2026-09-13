# Design System — The Ledger

A premium, calm financial journal. Warm paper surfaces, deep evergreen
actions, and brass emphasis — built so the user's own numbers are the
loudest thing on screen. Replaces the previous cold slate/indigo system.

## 1. Visual Theme & Atmosphere

The app reads like a crafted financial instrument you can trust, not a
dashboard you tolerate. Light mode is warm ivory paper with deep warm-ink
text; dark mode is restful ink-green (never pitch black) for nightly
review. Every surface is calm by default: cards sit on barely-there
double shadows, hairlines are warm, and the evergreen accent appears only
where the user acts.

**Key Characteristics:**
- Warm ivory paper ground (`#F6F4ED`) with crisp white cards
- Deep evergreen (`#1E5B45`) as the single action color
- Brass/gold (`#A68A3C`) for premium emphasis (calendar markers, wins)
- Ink text (`#182019`) with sage muted tones (`#5E6A60`)
- Generous 14–24px radii; buttons rounded but never pill
- Soft, directionally-lit double shadows
- Semantics tuned for WCAG AA on paper: green `#0E8345`, red `#C94040`

## 2. Color Palette & Roles

### Light Mode
| Token | Hex | Role |
|---|---|---|
| `bg` | `#F6F4ED` | Warm ivory scaffold |
| `card` | `#FFFFFF` | Crisp paper cards & sheets |
| `surface` | `#ECE9DF` | Warm sand — input wells, chips |
| `border` | `#E4DFD2` | Warm hairlines |
| `text` | `#182019` | Deep warm ink — primary text |
| `textMuted` | `#5E6A60` | Sage — secondary text |
| `accent` | `#1E5B45` | Deep evergreen — actions |
| `accentStrong` | `#164736` | Pressed state |
| `accentSubtle` | `8% evergreen` | Selected washes |
| `royalBlue` | `#2E6F8E` | Steel-blue secondary |
| `gold` | `#A68A3C` | Brass — premium emphasis |

### Dark Mode
| Token | Hex | Role |
|---|---|---|
| `bg` | `#0E1310` | Deep ink-green scaffold |
| `card` | `#181F1A` | Ledger-green cards |
| `surface` | `#222B24` | Chips & input wells |
| `border` | `#2A342C` | Hairlines |
| `text` | `#EDF1E8` | Warm paper white |
| `textMuted` | `#96A195` | Sage |
| `accent` | `#74CE9B` | Bright evergreen — actions |
| `accentStrong` | `#8BDDB1` | Pressed state |
| `royalBlue` | `#79B6D9` | Steel-blue secondary |
| `gold` | `#D6B678` | Brass |

### Semantic (shared)
- `green` `#0E8345` / `red` `#C94040` — price sentiment; the Korean
  (red=up, blue=down) vs Western (green=up, red=down) convention remains
  a user choice in Settings via `ThemeProvider.upColor/downColor`.
- `orange` `#D98A28` — warnings, holding-period accent.
- Calendar markers: `#1FA368` win, `#E05555` loss, `#8A6D2A` open/notes.

## 3. Typography Rules

Single workhorse family across the app (platform default, weights 500–800),
with tight negative tracking on headings so numbers and Korean glyphs read
cleanly.

| Role | Size | Weight | Notes |
|---|---|---|---|
| App bar title | 22 | 800 | `-0.4` tracking |
| Hero figure | 36 | 800 | `-0.8` tracking, `1.05` height |
| Section title | 17 | 800 | `-0.3` tracking |
| Card title | 16 | 700 | |
| Body | 14–16 | 400 | `1.5` height |
| Caption / meta | 11–13 | 500–600 | muted sage |

Section micro-labels (uppercase 11px) were retired — they were hard to
read. Section headers are now 17px ink titles.

## 4. Component Stylings

### Buttons
- **Primary**: evergreen fill, white text `#1E5B45`/`#FFFFFF`, 14px radius,
  15px w700, no elevation.
- **Outlined**: 1.2px evergreen at 50% alpha, 14px radius.
- **Destructive / success**: semantic fills (`error`, `success`).

### Cards
- White (light) / ledger-green (dark), 1px warm hairline, 18px radius.
- Elevation: two-layer soft shadow
  (`rgba(32,27,16,0.07)` 20px blur @ (0,10) + `0.04` 5px @ (0,2));
  dark mode uses heavier blacker shadows.

### Navigation
- **Phone**: `NavigationBar` — 68px tall, pill indicator in evergreen wash,
  selected labels w800 evergreen, unselected muted sage.
- **Tablet/desktop**: matching `NavigationRail`, 72px collapsed / 220px
  extended, same selected/unselected treatment.
- **Ad footer**: a single quiet slot pinned to the bottom of the shell —
  directly above the nav bar on phones, below the content column on
  rails. Content screens never mount their own ad.

### Inputs
- Filled warm-sand wells, no border until focus (1.5px evergreen).

## 5. Layout Principles

- 4px rhythm (`AppSpacing`), cards at 16–24px padding.
- Radii: 10 / 14 / 18 / 24 / pill.
- Two-column grids only at tablet width (`isExpandedOrUp`) — home sections
  and journal cards never squeeze below ~250px cells.
- Hero gradient: evergreen `#244A37` → deep ink-green `#123A2A`.

## 6. Depth & Elevation
- Card: `rgba(32,27,16,0.07) 0px 10px 20px` + `rgba(32,27,16,0.04) 0px 2px 5px`
- Hero: `accentStrong @ 30%, 0px 10px 24px`

## 7. Do's and Don'ts

### Do
- Use evergreen for the one action on a screen.
- Let P&L numbers carry the color weight (deep green/red, w700–800).
- Keep empty states instructive — first-run card invites the first trade.
- Keep the ad footer quiet and pinned to the bottom edge.

### Don't
- Don't place advertising inside content flow or above the fold.
- Don't scatter accent colors — one accent per screen, semantic colors
  only for price sentiment and status.
- Don't use 11px uppercase micro-labels for section names.
- Don't return to cold slate/indigo tones; warmth is the brand.

## 8. Responsive Behavior
Breakpoints (logical dp): compact < 600 · medium 600–839 · expanded
840–1199 · large ≥ 1200. Phones stay portrait; tablets/desktop unlock all
orientations. Content capped at 720/960/1200dp per size class.

## 9. Testing the system
`test/ui_layout_regression_test.dart` pins the no-overflow guarantee at all
four size classes (light + dark), the ad-footer placement, and the palette
contract. `test/app_theme_accent_test.dart` pins the token hex values.