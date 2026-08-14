# Widescreen owner request: gender glyphs and caught-shiny portrait toggle

**Resolved:** returned in `gen1_widescreen_ui` `0.1.0-alpha.14.2`; the
Widescreen contract suite and consumer integration tests pass.

Status: **Implemented by Gen1 Widescreen UI 0.1.0-alpha.14.2.** The compatible
contract remains Provider API v2; consumers using `shinyAvailable`, `shiny`
and `toggleShiny` must require Widescreen `>=0.1.0-alpha.14.2`.

## Target

- Owner mod: `gen1_widescreen_ui`
- Audited build: `0.1.0-alpha.14.1`
- Consumer: `gen1_widescreen_pokedex` `0.1.0-alpha.2`
- Shiny authority: `gen1_shiny_system` `0.1.0-alpha.2`

## Verified defects/blockers

### Gender symbols

The provider supplies the live merged species names, including `NIDORAN♀` and
`NIDORAN♂`. Pixelify Sans renders U+2640/U+2642 as missing-glyph boxes in the
provider list/detail presentation. This is a font/rendering defect; replacing
the symbols with `F`/`M` in semantic data is not acceptable.

### Shiny portrait

The requested behavior is: **Press Select to toggle normal/shiny Pokédex art,
but only when the player currently possesses a shiny of that species.**

Widescreen alpha 14.1 currently prevents this at three boundaries:

1. `validatePokedexSnapshot` requires `detail.portrait.shiny ~= false` to be
   false (lines 4063-4071 reject a shiny portrait).
2. `drawProviderPokemonPortrait` discards portrait state and constructs
   `local mon = { species = portrait.speciesId, shiny = false }`
   (lines 1016-1020).
3. `updatePokedexProviderInput` reserves Select for long-entry focus and does
   not dispatch a semantic Select/toggle action to the provider
   (lines 3448-3488).

## Requested owner-scoped contract extension

Keep fonts, coordinates, drawing, raw input and focus in Widescreen. Extend the
existing v2 contract compatibly (or version-bump it if validation semantics
require that) with:

```lua
detail.portrait = {
  kind = "pokemon",
  speciesId = "PIDGEY",
  side = "front",
  purpose = "pokedex",
  shinyAvailable = true, -- provider's live possession verdict
  shiny = false,         -- provider's transient selected presentation
}

actions.toggleShiny = function(game, state) ... end
```

Requirements:

1. Accept boolean `shinyAvailable` and `shiny` only for seen, non-hidden
   Pokemon portraits. Require `shiny == false` when `shinyAvailable ~= true`.
2. Pass the validated `portrait.shiny` into the synthetic portrait mon. Do not
   pass party identity, DVs or a specific caught Pokemon into art providers.
3. Continue resolving art through the existing live Battle Art/Shiny System
   path with purpose `pokedex`; do not add a second recoloring implementation.
4. Dispatch Select to `toggleShiny` when the provider advertises it for the
   current snapshot. Show a small presenter-owned `SELECT: SHINY` or
   `SELECT: NORMAL` hint only when available.
5. A species-selection change must deterministically return to normal unless
   the provider snapshot explicitly says otherwise.
6. Unseen and seen/unowned rows must never expose shiny availability.
7. Preserve bounded long-entry access. Select-to-shiny must not make the final
   lines of a long modded entry unreachable by controller. Define and test a
   second unambiguous focus gesture/path when both `shinyAvailable` and a long
   entry are present; pointer entry focus alone is insufficient.

## Gender-glyph presentation requirement

Add a glyph-capable fallback for U+2640 and U+2642, or draw matching
presenter-owned symbols while measuring/truncating the composite label
correctly. Both symbols must render in:

- normal and selected Pokédex list rows;
- the right-side detail name;
- any shared Widescreen label path used for live Pokemon names.

Do not mutate provider strings, substitute missing-glyph boxes, or replace the
symbols with ASCII letters.

## Consumer-side implementation after return

The Pokédex provider will:

1. Add `gen1_shiny_system` as an optional dependency.
2. Query its live public `hasShinyState(mon)` export across `save.party`, every
   `save.boxes` box, and legacy `save.box`; it will not infer from Pokédex owned
   flags and will not persist a second shiny registry.
3. Set `shinyAvailable` only when a matching currently possessed Pokemon is
   authoritatively shiny.
4. Keep a transient per-screen toggle and expose `actions.toggleShiny`.
5. Reset the toggle on species changes and never mutate the save or Pokemon.

If Shiny System is absent/incompatible or its query throws, availability is
false and Select retains its ordinary Widescreen behavior.

## Acceptance tests

- `NIDORAN♀` and `NIDORAN♂` render their actual symbols, not boxes, in selected
  and unselected rows and in detail.
- No truncation regression occurs around either multi-byte code point.
- A party shiny and a boxed shiny each enable the hint/toggle for their species.
- A normal-only owned species, seen/unowned species and unseen species do not.
- Select changes the validated snapshot to `portrait.shiny = true`; a second
  toggle returns to normal.
- Changing species resets to normal and cannot leak availability/identity.
- Shiny System absence, disabled color presentation and thrown provider calls
  fail safely through the existing normal art path.
- Battle Art static/animated/fallback resolution remains live and purpose-safe.
- A fixture combining shiny availability with an eight-line entry can still
  reach its final line using controller input.
- Existing Widescreen and Pokédex provider suites remain green.

## Return contract

Return a version-bumped flat Widescreen ZIP and the exact provider contract
version/floor. The Pokédex consumer will then implement its portion, bump its
own version, run all affected suites, and package a new flat release ZIP.
