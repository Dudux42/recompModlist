# Widescreen owner request: active-shiny gold star

**Resolved:** returned in `gen1_widescreen_ui` `0.1.0-alpha.14.4`; the active
shiny state draws exactly one vector gold star and all state/privacy fixtures
pass.

## Status

Implemented in `gen1_widescreen_ui` **0.1.0-alpha.14.4**. Provider API v2 and
the portrait/input contract remain unchanged. Consumers requiring the
active-shiny star should use `gen1_widescreen_ui@>=0.1.0-alpha.14.4`.

## Target

- Owner mod: `gen1_widescreen_ui`
- Audited build: `0.1.0-alpha.14.3`
- Consumer: `gen1_widescreen_pokedex` `0.1.0-alpha.4`
- Existing contract: validated `detail.portrait.shinyAvailable` and
  `detail.portrait.shiny`

## Requested presentation-only change

When the main Pokédex detail snapshot has:

```lua
detail.portrait.kind == "pokemon"
and detail.portrait.shinyAvailable == true
and detail.portrait.shiny == true
```

draw a small gold star in the **top-right corner of the right detail panel,
above the sprite**.

Use Widescreen-owned vector geometry or a guaranteed glyph-safe presenter
asset. Do not rely on Pixelify Sans containing a star character, and do not ask
the semantic provider for coordinates, colors, or a new decorative field.

## Visual requirements

- Place the star inside the right panel's safe inset near its top-right corner.
- Keep it visually above the portrait rather than over the Pokemon's face/body.
- Use a gold fill with sufficient contrast against the paper panel; a subtle
  dark outline is acceptable.
- Keep it small enough not to collide with the panel border, species name,
  number, classification, height/weight, entry text, or footer.
- Preserve integer-aligned final-resolution geometry and crisp rendering.
- Do not move, shrink, or reframe the existing portrait solely to fit the star.

## State requirements

- Normal selected portrait: no star.
- Shiny selected portrait: exactly one gold star.
- Second Select toggle back to normal: star disappears immediately.
- Changing species resets with the provider's existing normal state and leaves
  no stale star.
- Unseen, seen/unowned, normal-only owned, provider-error and unknown portrait
  states never show the star.
- Submenu and research screens do not retain or leak the decoration.

## Acceptance tests

- Extend `start_menu_test.lua` to count/identify the star draw only for the
  existing owned-shiny fixture after Select toggles shiny on.
- Assert no star before the toggle and none after toggling back to normal.
- Assert species/privacy/provider-error changes cannot retain it.
- Footer-only `SELECT SHINY`/`SELECT NORMAL` controls remain unchanged.
- Gender glyphs, long-entry focus, pointer/controller input, portrait art
  resolution and all existing provider fixtures continue to pass.

## Return contract

Return the version-bumped flat Widescreen release and exact version. The
Pokédex consumer will raise its dependency floor, bump its release version,
run all affected suites, and package a new flat ZIP.
