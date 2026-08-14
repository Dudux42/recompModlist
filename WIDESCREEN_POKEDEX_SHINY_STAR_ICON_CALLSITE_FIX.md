# Widescreen owner correction: Pokédex still draws the vector star

**Resolved:** returned in `gen1_widescreen_ui` `0.1.0-alpha.14.6`; the Pokédex
call site uses `drawShinyStarIcon` and its fixtures count bitmap image draws.

## Status

Implemented in `gen1_widescreen_ui` **0.1.0-alpha.14.6**. The Pokédex now uses
the packaged bitmap call site and bitmap draw fixture; the obsolete vector
renderer is removed. Provider API v2 remains unchanged, and consumers requiring
this correction should use `gen1_widescreen_ui@>=0.1.0-alpha.14.6`.

## Target

- Returned build: `gen1_widescreen_ui` `0.1.0-alpha.14.5`
- Packaged asset: `assets/shiny_star.png` (`32×31`, 1559 bytes)
- Consumer remains: `gen1_widescreen_pokedex` `0.1.0-alpha.5`

## Verified missed requirement

Alpha 14.5 correctly packages and caches the supplied bitmap and introduces:

```lua
drawShinyStarIcon(x, y, size)
```

Party, Summary and Battle HUD use that function. The Pokédex does not. Its
active-shiny branch still calls the alpha 14.4 vector renderer:

```lua
drawPokedexShinyStar(detailX + detailW - 19, detailY + 18)
```

at `main.lua:1284`. The old `drawPokedexShinyStar` polygon function remains at
lines 991-1007.

The Pokédex regression fixture also still counts the gold vector polygon in
`pokedexShinyStarDraws` rather than counting draws of `shinyStarImage`. Thus the
tests currently certify the wrong renderer.

## Required narrow correction

1. Replace the Pokédex call with `drawShinyStarIcon(...)`, positioned in the
   same top-right safe area above the sprite. Use a preserved-aspect-ratio size
   appropriate for the 32×31 display asset and integer-aligned coordinates.
2. Remove `drawPokedexShinyStar` if no other call remains. No vector star should
   be used during a valid packaged run.
3. Keep the existing active-shiny predicate exactly unchanged.
4. Keep the packaged `assets/shiny_star.png`, cached `Assets.image` path,
   nearest filtering, true-color marking, portrait geometry and footer controls
   unchanged.

## Required test correction

Update the Pokédex shiny fixture to assert changes in `shinyStarImageDraws`, the
counter incremented when `love.graphics.draw` receives `shinyStarImage`.

- Normal before toggle: no bitmap draw.
- Select shiny on: exactly one bitmap draw.
- Species change: no additional bitmap draw.
- Return to active shiny fixture: one additional bitmap draw.
- Toggle normal/submenu/unseen/unowned/provider error: no bitmap draw.
- Assert the old gold-polygon counter does not increase, or delete that obsolete
  test instrumentation after removing the vector renderer.

## Return contract

Return another version-bumped Widescreen ZIP. Do not describe alpha 14.5 as
fulfilling the Pokédex icon request: it packages the asset but leaves the
Pokédex on the vector call site. The Pokédex consumer will raise its dependency
floor and release only after this correction passes.
