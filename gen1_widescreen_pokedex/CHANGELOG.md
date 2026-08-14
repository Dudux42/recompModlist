# Changelog

## 0.1.0-alpha.7 — 2026-08-11

- Require Widescreen UI alpha 14.7 so the supplied shiny-star bitmap is loaded
  through the launcher's mod-scoped image API in real installations.
- Preserve all existing shiny eligibility, privacy, footer and layout behavior.

## 0.1.0-alpha.6 — 2026-08-11

- Require Widescreen UI alpha 14.6 so the Pokédex active-shiny indicator uses
  the supplied cached bitmap rather than the former vector polygon.
- Preserve all existing shiny eligibility, privacy, footer and layout behavior.

## 0.1.0-alpha.5 — 2026-08-11

- Require Widescreen UI alpha 14.4 for the active-shiny gold star in the
  detail panel's top-right corner.
- Preserve footer-only shiny controls, portrait geometry and privacy behavior.

## 0.1.0-alpha.4 — 2026-08-11

- Add a dedicated learnable-HMs section after learnable TMs, joined through
  structured machine metadata and sorted numerically.
- Require Widescreen UI alpha 14.3 so the shiny control appears only in the
  footer and no duplicate hint is drawn below the portrait.

## 0.1.0-alpha.3 — 2026-08-11

- Require Widescreen UI alpha 14.2 for glyph-safe Pokemon names and validated
  shiny portrait presentation.
- Add a transient Select normal/shiny toggle when the player currently has an
  authoritative shiny of the selected species in the party or PC boxes.
- Reset shiny presentation on species changes and preserve discovery privacy.

## 0.1.0-alpha.2 — 2026-08-11

- Reflow legacy Pokédex line/page controls as spaces so standard entries use
  the full Widescreen text box without unnecessary scrolling.
- Preserve bounded Widescreen scrolling for genuinely oversized modded text.

## 0.1.0-alpha.1 — 2026-08-11

- Implemented the read-only semantic provider, research models, navigation,
  privacy policy, live cry dispatch, and native Habitat fallback.
- Added Lua 5.1 contract tests.
- Integrated with Widescreen Pokedex Provider API v2 from alpha 14.1.
- Verified bounded long-entry focus and scrolling through Widescreen's
  controller and pointer-owned input paths.
