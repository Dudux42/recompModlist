# Widescreen owner request: remove duplicate inline shiny hint

**Resolved:** returned in `gen1_widescreen_ui` `0.1.0-alpha.14.3`; the inline
hint is removed, the footer control remains, and affected tests pass.

## Status

Implemented in `gen1_widescreen_ui` **0.1.0-alpha.14.3**. Provider API v2 and
its semantic action contract are unchanged. Consumers requiring this
footer-only presentation should use `gen1_widescreen_ui@>=0.1.0-alpha.14.3`.

## Target

- Owner mod: `gen1_widescreen_ui`
- Audited build: `0.1.0-alpha.14.2`
- Consumer: `gen1_widescreen_pokedex` next build `0.1.0-alpha.4`

## Requested presentation-only change

The main Pokédex detail panel currently draws `SELECT: SHINY` or
`SELECT: NORMAL` directly below the portrait (`main.lua` alpha 14.2 lines
1226-1234). The same action is already described in the Widescreen footer at
lines 1313-1318.

Remove only the inline portrait-panel hint:

```lua
if detail.portrait.shinyAvailable == true then
  ...
  g.print(shinyHint, ...)
  ...
end
```

Keep the footer text and all Select behavior unchanged. Do not move the footer
inside the detail panel, alter portrait geometry, change Provider API v2, or
remove `shinyAvailable`/`shiny` validation.

## Acceptance tests

- No `SELECT: SHINY`/`SELECT: NORMAL` text is drawn below or over the sprite.
- The bottom Widescreen footer still displays `SELECT SHINY` or
  `SELECT NORMAL` when available.
- Select still toggles the portrait through `actions.toggleShiny`.
- Long-entry focus, including the shiny-plus-long-entry Start gesture, remains
  unchanged.
- Normal-only, seen/unowned and unseen species show no shiny control hint.
- Existing gender-glyph, portrait, privacy, input and research fixtures pass.

## Return contract

Return the version-bumped Widescreen release and exact version. The Pokédex
consumer will raise its dependency floor, finalize its HM learnset addition,
run all affected suites, and package a new flat ZIP.
