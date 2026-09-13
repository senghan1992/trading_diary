# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Individual retail stock investors in Korea (primary) and English-speaking
retail traders. They trade on KOSPI / KOSDAQ / NASDAQ across multiple broker
accounts (KRW and USD) and want a private, local-first diary to record,
review, and learn from every trade. Their working scene is a phone at a desk
or on the move, checking a realized P&L or logging a position against their
broker app, not a portfolio dashboard they stare at all day.

## Product Purpose

A local-first trading journal. Users record buy/sell entries per account,
close positions, review results across time / market / strategy / weekday
dimensions, and capture lessons from winning and losing trades so the next
trade repeats what worked. Success means the diary becomes the user's habit
of record — opening it to log a trade is fast, and reviewing past trades
improves discipline.

## Positioning

Everything is stored on-device (Hive) with no account and no cloud — private
by construction, works offline, and truthful as a personal record. Insights
(win rate, profit factor, streaks, best/worst) are computed locally from the
user's own trades, not fed back into ad targeting.

## Operating Context

- Multi-account: each trade is tagged to a registered account with a brand
  color; the journal can be filtered by account.
- Dual markets with mixed currency (KRW and USD) — sums are shown in the
  dominant market's unit.
- Users record a trade quickly (entry) and later close it (exit + result).
- Dark / light / system theme, Korean or English UI, and a choice of Korean
  (red=up) or Western (green=up) price-color convention.
- Excel/CSV export for those who still reconcile in spreadsheets.

## Capabilities and Constraints

- Flutter (Material 3), local Hive storage, runtime update gate, AdMob
  banner ads (AdMob unit configured; retries on load failure).
- Ships on Android and iOS with one shared Material design language.
- Portrait-locked on phones; tablet/desktop get all orientations with a
  navigation rail and responsive card grids.
- Ad revenue: a single banner appears in the app. It must not interrupt
  content; it currently renders at the top of each tab and reads as an
  unwelcome intrusion.
- Force-update gate and optional "update available" dialog via a remote
  config endpoint.

## Brand Commitments

- Product name "Trading Diary" (거래 일지), current `show_chart` style
  identity and the white native splash: these stay.
- Voice is calm, direct, professional — no gamification or hype.
- Semantic price colors must preserve both the Korean (red=up, blue=down)
  and Western (green=up, red=down) conventions the Settings toggle controls.

## Evidence on Hand

- Real app code and l10n copy (Korean + English) under `lib/`.
- An existing DESIGN.md describing a cold slate/indigo "fintech" palette,
  which the redesign replaces (it does not bind the new world).
- Existing screenshots/assets under `assets/branding/`.
- No testimonials, marketing copy, or press — and none are invented.
- No anonymized user data is available; charts and dashboards are built from
  data already present or generated synthetically and labeled.

## Product Principles

- The log is the habit: recording a trade must be fast and near-frictionless.
- Local and private by construction: nothing on this screen implies a server,
  a login, or analytics.
- Truthful summary: numbers are computed from the user's own journal and are
  never dressed up.
- Clarity beats density: each screen should answer one question at a glance.
- Ad revenue must not compromise the reading experience — advertising lives
  at the quiet edges, never inside the content flow.

## Accessibility & Inclusion

- Both Korean and English copy through the l10n layer; no hard-coded strings.
- WCAG AA text contrast on interactive labels in both themes.
- Minimum ~44dp interactive targets on primary actions.
- The semantic price-color toggle exists so color-blind clarity is a user
  choice, not a fixed assumption.
