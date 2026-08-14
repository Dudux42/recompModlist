# Gen1 Battle Art Replacer — Alpha 2 feasibility and release report

Date: **2026-08-10**

## Evidence-backed scope decision

The supplied `pokemon_white2_front_spritesheets/gen1` collection contains 151
normal and 151 shiny **front-facing articulated component sheets**. Each file
is 1024x512 and requires White 2's NMCR/NMAR composition data; it is not a
frame strip and cannot be drawn directly. No supplied back, opponent-trainer,
or player collection exists.

Battle Art Voxel Fork 1.7.6 was audited read-only. Its Gen 5 data provides a
validated composed front-atlas definition for every Gen 1 species, including
cell width/height, frame count, columns, and durations. The study copy also
contains all 151 corresponding normal composed atlases. Its battle-art code
applies images directly to battler sprite fields during the voxel pipeline's
per-frame update; that occurs after the engine's public `pokemon.sprite`
resolver.

Therefore alpha 2 ships a narrow, truthful subset: stable Gen 5 neutral front
frames for all 151 species, plus matching shiny frames. It does not claim
animation, back art, trainer art, player art, or voxel-fork coexistence.

## Availability matrix

| Category | Normal | Shiny | Animated in alpha 2 | Fallback |
|---|---|---|---|---|
| Gen 5 Pokemon fronts, Dex 001-151 | Complete | Complete | No | ROM |
| Gen 5 Pokemon backs | Not supplied | Not supplied | No | ROM |
| Opponent trainers | Not supplied | N/A | No | ROM |
| Player intro/back | Not supplied | N/A | No | ROM |
| Generations 1-4 selections | Not supplied for this task | Not supplied | No | ROM/not offered |

The 151 normal neutral frames are cropped from frame zero of the validated
local Gen 5 atlases. Each shiny frame is recolored through the matching
normal/shiny White 2 component-sheet palette pair. Exact RGB coverage was
74.2277%; the remaining values were conversion-rounding differences with mean
nearest-palette distance 0.281, 95th percentile 1.414, and maximum 1.732 on a
0-255 RGB scale. Within-species normal-to-shiny palette ambiguity was only
0.004669% of component-sheet samples. These values are consistent with
one-channel ±1 conversion rounding and negligible duplicate-color overlap,
not an inferred cross-species palette.

## Option and provider contract

Alpha 2 intentionally exposes one row:

- `POKEMON ART: GEN 5 / ROM`, default `GEN 5`.

The broader global `STATIC / ANIMATED / ROM` choice remains deferred until an
animation clock can run independently of a world-render pipeline and genuine
assets exist for each offered category. Offering empty Gen 1-4 choices would
be misleading.

Public exports:

```lua
exports.resolvePokemonImage(game, mon, side, purpose)
exports.resolvePokemonPath(data, mon, side)
exports.resolveTrainerImage(game, trainerClass, purpose)
exports.resolvePlayerImage(game, purpose)
exports.mode()
exports.isAnimated()
exports.invalidate()
```

The Pokemon resolver returns a stable 2D still for `front`; unsupported sides
return `nil` so the caller preserves its existing provider or ROM result.
Shiny selection prefers `gen1_shiny_system.exports.shouldUseShinyArt(mon)` and
otherwise supports both `mon.shiny` and `Stats.isShiny(mon.dvs)`.

## Ownership and compatibility

```text
Gen1 Shiny System
  decides whether shiny presentation is enabled
            |
            v
Gen1 Battle Art Replacer
  resolves Gen 5 normal/shiny front path or returns nil
       |                         |
       v                         v
pokemon.sprite battle hook    Widescreen live portrait resolver
       |
       v
engine battler / ROM fallback
```

The mod remains incompatible with `BATTLE_ART_VOXEL_FORK`, which contains a
separate battle-art owner that overwrites the same battler fields after
`pokemon.sprite` resolves.

It is compatible with the separate `DRAMATIC_SHAPE` 1.8.0 release. Dramatic
Shape normally consumes the battler images produced by the public resolver.
For its special player `FRONT SPRITES` view, alpha 2 queries the exported
`OverworldBattle.wantsFront()` contract and supplies the same Gen 5 front art.
Dramatic Shape retains camera, world placement, sprite metrics, battle staging,
backs, Stadium models, and its entire render pipeline.

## Flat asset contract

All 302 assets are root-level files:

```text
pokemon_static_gen5_front_001.png
pokemon_static_gen5_front_001_shiny.png
...
pokemon_static_gen5_front_151.png
pokemon_static_gen5_front_151_shiny.png
```

The release has 305 unique root entries: manifest, Lua entry, README, 151
normal PNGs, and 151 shiny PNGs. No archive entry contains `/`.

## Verification

- Exact Lua 5.1: `battle_art_replacer_test.lua` passed.
- The provider test covers Dramatic Shape's normal enemy path, player-front
  substitution, first staged frame, ROM back preservation, and shiny player
  front selection.
- Exact Lua 5.1: Widescreen `start_menu_test.lua` passed with the new live
  provider integration.
- Exact Lua 5.1: Widescreen `battle_hud_test.lua` passed.
- All 151 normal/shiny mappings, dimensions, transparency, non-empty bounds,
  and pair differences passed automated validation.
- The 151-pair contact sheet was inspected visually.
- Both release archives were audited for root manifest/entry, unique names,
  flat paths, entry count, and filename/manifest version agreement.

Final in-game launcher testing remains the user's step. The build was not
installed automatically.
