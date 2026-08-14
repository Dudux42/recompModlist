# Widescreen owner request: use supplied shiny-star icon

**Resolved after call-site correction:** `gen1_widescreen_ui`
`0.1.0-alpha.14.6` packages the supplied derivative and the Pokédex now draws
that cached bitmap.

## Target

- Owner mod: `gen1_widescreen_ui`
- Audited build: `0.1.0-alpha.14.4`
- Consumer: `gen1_widescreen_pokedex` `0.1.0-alpha.5`
- Supplied source asset:
  `request_assets/pokedex_shiny_star_source.png`
- Source SHA-256:
  `867AF3A090984A450C3BBCDA700A42AF2A420A9732740FB32E9E9AD62B3B8898`

## Verified asset properties

- PNG, RGBA, 1536×1024
- Transparent background (`alpha = 0` at all four corners)
- Visible-alpha bounds: `(348, 86) .. (1248, 952)`
- Visible source size: `900×866`
- Maximum recorded alpha: `254`

The black area shown by some viewers is transparency, not a black background.

## Requested presentation-only change

Replace the alpha 14.4 vector star drawn by `drawPokedexShinyStar` with the
attached pixel-art star icon. Keep the existing validated display condition,
positioning intent and privacy rules unchanged.

1. Copy a lossless crop or display-ready nearest-neighbor derivative into the
   Widescreen asset tree as `assets/pokedex_shiny_star.png`. The derivative must
   come only from the supplied visible pixels; do not redraw or generate a
   different star.
2. Alternatively, preserve the original source asset and draw only its
   `(348, 86, 900, 866)` visible region through a `Quad`. Do not scale the full
   transparent 1536×1024 canvas as if it were the star bounds.
3. Resolve it through `mod.assets:path("pokedex_shiny_star.png")` and the normal
   `Assets.image` path. Cache the immutable UI image instead of loading it every
   frame.
4. Set nearest-neighbor filtering and draw at integer-aligned final-resolution
   coordinates. Reset the draw color to opaque white so the bitmap's supplied
   gold/orange/white palette is not tinted.
5. Fit it cleanly in the existing top-right safe area above the sprite. Preserve
   aspect ratio, portrait geometry, panel border, footer, text and entry layout.
6. Include the asset in the version-bumped Widescreen release ZIP and document
   it as a user-supplied UI asset. Do not put the asset in the Pokédex consumer.

## State requirements

Retain the alpha 14.4 condition exactly: the icon appears only for a valid,
owned, non-hidden, active shiny Pokemon portrait with no submenu/provider fault.
Normal, toggle-off, species-change, unseen, seen/unowned, submenu, research and
provider-error states must display no star.

## Acceptance tests

- The active-shiny fixture resolves and draws `pokedex_shiny_star.png` exactly
  once at the expected top-right region.
- The vector fallback is not used during a valid packaged run.
- Normal/toggle-off/species-change/privacy/submenu/provider-error fixtures draw
  the asset zero times.
- Missing/corrupt asset handling is isolated and diagnosed without crashing;
  it must not expose a stale image from another state.
- Footer-only Select controls, shiny toggling, gender glyphs, long-entry focus,
  portrait art resolution and provider validation remain unchanged.
- The release archive audit explicitly confirms the PNG is present.

## Return contract

Return the version-bumped Widescreen release and exact version. The Pokédex
consumer will raise its dependency floor, bump its release, run all affected
suites, and package a new flat release ZIP.
