# Request: restore the shiny-star icon on the responsive PC detail panel

Send this prompt to the agent that owns **Gen1 Widescreen UI**.

---

You own **Gen1 Widescreen UI**, manifest ID `gen1_widescreen_ui`, current
canonical version `0.1.0-alpha.14.30`. Fix the missing shiny-star identity icon
on the responsive Pokemon PC detail panel.

## Verified defect

The user's screenshot shows a shiny Abra rendered correctly in the selected
Box Pokemon detail panel, with the bottom-right WITHDRAW/STATS/CANCEL action
popup open, but no shiny-star icon beside the Pokemon's name.

The defect is isolated to the Widescreen PC presenter:

- `main.lua` already defines `pokemonIsShiny(mon)` and
  `drawShinyStarIcon(x, y, size)`.
- Battle status, Party detail, Summary, and Pokedex presenters already use
  those helpers.
- `PokedexProviderUI.drawPcPokemonDetail` at the current `main.lua:5172`
  resolves and draws the selected Pokemon, name, portrait, level, HP, and
  stats, but never calls either shiny helper.
- The shared bitmap is already shipped as `assets/shiny_star.png` and loaded
  through the mod-scoped asset loader. No new asset or Shiny System export is
  required.
- Gen1 Shiny System `0.1.0-alpha.3` already exposes identity through
  `exports.isShiny(mon)`, while Widescreen's existing `pokemonIsShiny` helper
  safely falls back to `mon.shiny` and `Stats.isShiny(mon.dvs)`.

## Smallest owner-side change

Inside `PokedexProviderUI.drawPcPokemonDetail`:

1. Resolve `local showShiny = pokemonIsShiny(mon)`.
2. Reserve horizontal name space when `showShiny` is true so a long nickname
   cannot overlap the icon.
3. Draw the existing 16px `shiny_star.png` through `drawShinyStarIcon`, aligned
   at the upper-right of the detail panel consistently with Party/Summary.
4. Show the identity icon even while the PC action popup is open; the popup is
   a composited overlay and must not suppress the underlying selected-Pokemon
   identity.

Do not use a font glyph, polygon, or a second asset loader. Preserve nearest
filtering and `PaletteFX.markTrueColor` behavior through the existing helper.

## Ownership and non-goals

- This is a Widescreen presentation fix. Do not edit Gen1 Shiny System.
- Do not change shiny generation, DVs, flags, colors, odds, battle effects, or
  SFX.
- Do not change PC selection, storage mutation, action routing, popup behavior,
  Summary navigation, or native PC semantics.
- Do not change the selected Pokemon portrait resolver or Dramatic Shape
  ownership boundaries.

## Acceptance tests

Extend `gen1_widescreen_ui/tests/start_menu_test.lua` around the existing Box
Pokemon detail/action fixture:

1. A stored Pokemon with `shiny = true` draws exactly one additional
   `shinyStarImage` in the PC detail panel while the action popup is open.
2. A normal stored Pokemon draws no star.
3. A Pokemon recognized only through native shiny DVs also draws the star,
   exercising the existing identity fallback.
4. The existing PC composition and STATS-destination assertions still pass.
5. Existing Party, Summary, Pokedex, and Battle star tests still pass.

Run the exact Lua 5.1 Widescreen suites, rebuild a flat root-only ZIP, audit
entries/duplicates/nesting/manifest version, and retain all existing assets and
licenses. Bump Widescreen beyond `0.1.0-alpha.14.30`; update source header,
manifest, README current-build line, master guide canonical release, and ZIP
name together. Do not install it automatically.

Return changed files, tests/results, new version, flat release ZIP, and hash.

---
