# Changelog

## 0.1.0-alpha.5

- Replaced the redundant TM/HM `EFFECT` row with a `DESCRIPTION` row.
- Added concise player-facing explanations for all 50 Gen 1 TMs and five HMs,
  including multi-turn, recoil, fixed-damage, field-use and status mechanics.
- Used Generation I behavior where it differs from later games.

## 0.1.0-alpha.4

- Restored the provider-owned structured TM/HM payload for Widescreen UI
  alpha 14.25: bold labels, regular values, one parameter per line and a
  colored type badge.
- Retained dedicated descriptions for all 70 supported item roles.

## 0.1.0-alpha.3

- Added concise individual descriptions for all five supported Poke Balls.
- Documented the requested structured TM/HM presentation in an external
  Widescreen-owner handoff without modifying the presenter.
- Removed enclosed orange sheet matte from TM, HM, Escape Rope and every other
  affected icon while preserving neighboring sprite colors.

## 0.1.0-alpha.2

- Replaced the inherited seven-pocket plan with six original pockets.
- Removed Favorites, pins, search, filters, preference persistence, and every
  automatic-sorting path.
- Added explicit START sorting: Alphabetical, Type, and Quantity.
- Added persistent vanilla-style SELECT swapping through `Bag.order`.
- Locked TM/HM to HMs-first numerical order followed by numerical TMs.
- Added plain-language right-panel item, machine, and battle availability data.
- Built and audited 70 individual icons plus shared TM/HM icons.
- Retained safe large finite stacks and engine-owned item actions.
- Migrated to Bag Provider API v2 for visible, validated modal focus and
  screen-aware input routing.

## 0.1.0-alpha.1

- Added the initial provider and inventory-semantic foundation.
