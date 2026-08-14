# Gen 1 Recomp Battle Art Replacer — Next-Agent Handoff

> **Scope supersession — 2026-08-11:** Player and human trainer battle-art
> requirements in this older planning brief are superseded by
> `NEXT_AGENT_CHARACTER_SPRITE_REPLACER.md`. Battle Art Replacer owns Pokémon
> battle art only. Do not implement player, NPC, or trainer character art here;
> the released alpha.11 leaves those surfaces ROM-owned.

Last updated: **2026-08-10**

## 1. Objective

Design and implement a standalone battle-art mod for Pokemon Gen 1 Recomp that
provides a consistent replacement system for:

1. Pokemon front sprites.
2. Pokemon back sprites.
3. Opponent trainer sprites.
4. Player battle-intro/back sprites.

The user wants selectable **Generation 1, 2, 3, 4, and 5** art for Pokemon,
trainers, and the player, with **STATIC** and **ANIMATED** presentation options.
The new mod must preserve the useful battle-art behavior of Battle Art Voxel
Fork without inheriting its voxel world, camera, water, terrain, battle-arena,
or other world-rendering responsibilities.

This document is a planning and implementation handoff. Do not install a build
automatically. Deliver a flat release ZIP for manual launcher import.

## 2. Mandatory first reads and reference material

Before changing or creating code, read:

1. `MASTER_MOD_GUIDE.md` in the canonical workspace.
2. The complete read-only study copy of Battle Art Voxel Fork 1.7.6:
   `C:\Users\invok\Documents\Codex\2026-08-08\ok\work\mod_study\BATTLE_ART_VOXEL_FORK-1.7.6`
3. In particular:
   - `manifest.json`
   - `README.md`
   - `lib/BattleArt.lua`
   - `lib/AnimatedBattleArt.lua`
   - all `assets/battle/**/README.md` contracts
   - relevant option-row and hook installation code in `main.lua`
4. The current manifests and public exports of:
   - `gen1_widescreen_ui`
   - `gen1_shiny_system`
   - `hgss_menu_icons`

Treat the study copy and installed mods as read-only reference material. Build
the new mod in a separate editable source directory.

## 3. Critical correction to the premise

Battle Art Voxel Fork 1.7.6 does **not** currently expose a complete symmetric
Generation 1–5 matrix:

- `BATTLE ART`: STATIC / ANIMATED / ROM.
- `ANIM FRONT GEN`: GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5.
- `BACK ART SET`: GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5.
- `TRAINER ART`: only GEN 1 / GEN 2 / GEN 3, and opponent trainers are static.
- `PLAYER ART`: PNG / GEN 1–5 / ASH / GARY / ROM.
- `PLAYER ANIM`: PNG / GEN 1–5 / ASH / GARY / RED / ROM.
- Static Pokemon fronts use one flat `front-static` set rather than a
  generation selector.
- In animated mode, Gen 3 and Gen 5 backs use animation atlases; Gen 1, Gen 2,
  and Gen 4 backs use static PNGs.
- Gen 1 animated fronts are a single-frame compatibility set rather than true
  animation.

Therefore the requested mod is an intentional normalization and expansion of
the existing behavior, not literal option parity. Do not claim animation or
asset completeness that has not been verified.

## 4. Proposed ownership boundary

The new mod should own only battle-art selection, loading, animation, fallback,
and a public 2D portrait resolver. It should not own:

- Overworld geometry, camera, zoom, pitch, collision, voxel rendering, water,
  lighting, terrain extrusion, battle staging, or HUD layout.
- Shiny generation, shiny odds, DVs, persistence, sparkle effects, or the
  master shiny options.
- Party, Summary, Pokedex, or other menu layout.
- Overworld followers or menu icons.

Recommended working identity, subject to manifest audit before implementation:

- Working name: **Gen1 Battle Art Replacer**
- Proposed manifest ID: `gen1_battle_art_replacer`
- Initial version: `0.1.0-alpha.1`
- Category: `GRAPHICS`

Do not reuse the `BATTLE_ART_VOXEL_FORK` manifest ID.

## 5. Target option model

Prefer a small, predictable matrix instead of carrying every historical alias
from the voxel fork.

| Option row | Values | Required behavior |
|---|---|---|
| `BATTLE ART` | STATIC / ANIMATED / ROM | Global mode. ROM disables all replacements cleanly. |
| `POKEMON ART` | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 | Selects one coherent generation for both Pokemon fronts and backs. |
| `TRAINER ART` | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 | Selects opponent trainer art without silently mixing generations. |
| `PLAYER ART` | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 / ROM | Selects the player intro/back collection. |

Design rule: the selected `POKEMON ART` generation must drive **both front and
back art**. This avoids the mismatched-generation battles permitted by separate
front/back selectors in the reference fork. If independent front/back choices
are later requested, add them only as an explicitly documented advanced mode.

`ANIMATED` means “use an authentic animation for the selected category and
generation when a validated animation contract exists.” It must never mean
stretching a static image, displaying an atlas as one large image, or inventing
frames. When an authentic animation is unavailable or invalid, fall back to
the selected generation's static art, then to ROM.

Before freezing the UI, verify whether the user intends `STATIC` / `ANIMATED`
to apply globally or independently to Pokemon, trainers, and player. The table
above assumes one global mode because that matches the reference mod's primary
control and keeps the options manageable.

## 6. Required resolver and fallback behavior

Use deterministic, category-local fallback chains:

### Pokemon front or back

1. Selected generation's matching shiny animated/static asset, when shiny art
   is enabled and the Pokemon is shiny.
2. Selected generation's normal animated asset.
3. Selected generation's matching shiny static asset, when applicable.
4. Selected generation's normal static asset.
5. Unmodified ROM sprite.

Do not fall sideways into another generation.

### Opponent trainer

1. Selected generation's validated animated trainer asset, if animated mode
   supports it.
2. Selected generation's static trainer asset.
3. Matching ROM trainer portrait.

Do not substitute a different trainer class or generation.

### Player

1. Selected generation's validated animated player intro, when available.
2. Selected generation's static player sprite.
3. ROM player portrait.

Scripted Oak/Old Man/demo portraits need explicit tests and must not be
accidentally replaced by the normal player selection.

Missing, unreadable, malformed, or unsupported files must produce a safe
fallback, not a crash or a full sprite-sheet draw.

## 7. Proposed asset contract

Use generation-specific paths for every category. This is a proposed clean
contract; confirm launcher/API path behavior before locking it:

```text
assets/battle/
  pokemon/
    static/gen1/front/<species>.png
    static/gen1/back/<species>.png
    ... gen2 through gen5 ...
    animated/gen1/front/<species>.png
    animated/gen1/back/<species>.png
    ... gen2 through gen5 ...
    shiny/static/gen1/front/<species>.png
    shiny/static/gen1/back/<species>.png
    ...
    shiny/animated/gen1/front/<species>.png
    shiny/animated/gen1/back/<species>.png
    ...
  trainers/
    static/gen1/<trainer-class>.png
    ... gen2 through gen5 ...
    animated/gen1/<trainer-class>.png
    ... gen2 through gen5 ...
  player/
    static/gen1.png
    ... gen2 through gen5 ...
    animated/gen1.png
    ... gen2 through gen5 ...
```

If the launcher still requires root-only archives with no `/` entries, this
directory model cannot be shipped directly. The master guide's current
packaging policy says release ZIP entries must not contain `/`. The next agent
must resolve this conflict before implementation by choosing one of these safe
approaches:

1. Flatten all assets into root-level filenames with encoded category, mode,
   generation, side, and species/class; or
2. Obtain explicit proof and user approval that nested archive entries are now
   safe.

Default to **flat filenames** unless the user approves otherwise. A possible
flat scheme is:

```text
pokemon_static_gen3_front_bulbasaur.png
pokemon_animated_gen5_back_bulbasaur.png
trainer_static_gen4_youngster.png
player_animated_gen2.png
```

Keep a single canonical species-slug table. Preserve special filenames such as
`farfetchd`, `mr-mime`, `nidoran-f`, and `nidoran-m`, and audit all 151 species.

## 8. Animation contract investigation

Do not assume a common atlas layout across generations. Record for each
category/generation:

- Source format and provenance.
- Canvas size.
- Frame count and frame rectangles.
- Frame duration/timeline.
- Looping or one-shot behavior.
- Neutral/reference frame.
- Ground/foot anchor.
- Front/back facing direction and mirroring rule.
- Shiny asset availability.
- Whether gender/form variants exist and how Gen 1 species choose among them.

The reference fork already contains multiple decoders and special cases. Reuse
ideas only after checking license and provenance; do not blindly copy code or
assets. A normalized internal descriptor should hide source-format differences:

```lua
{
  image = image,
  frames = { ... },
  durations = { ... },
  loop = true,
  anchorX = 0,
  anchorY = 0,
  generation = "gen5",
  side = "front",
  animated = true,
}
```

Animation should use stable logical anchors so frame-by-frame opaque-bound
changes do not cancel authored motion or make sprites bounce unintentionally.

## 9. Shiny-system integration

The new mod must support both shiny-state forms:

1. `mon.shiny == true`.
2. `Stats.isShiny(mon.dvs)`.

When `gen1_shiny_system` is present, prefer its public exports, especially:

- `exports.hasShinyState(mon)` for underlying state.
- `exports.shouldUseShinyArt(mon)` for presentation choice.
- `exports.battleImage(game, mon, side)` only after auditing how ownership and
  recursion should work with the new provider.

Do not create a circular resolver where the shiny system calls the battle-art
provider and the provider immediately calls the shiny system's `battleImage`
again. Define one owner for base art and one layer for shiny presentation.

Shiny selection is per Pokemon instance, never per species. Two Pokemon of the
same species may have different shiny state.

## 10. Widescreen UI and public provider API

The Widescreen UI must continue resolving live 2D art at draw time rather than
pinning a cached provider. The new mod should expose a narrow provider API after
the current UI contract is inspected. Suggested semantics:

```lua
exports.resolvePokemonImage(game, mon, side, purpose)
exports.resolveTrainerImage(game, trainerClass, purpose)
exports.resolvePlayerImage(game, purpose)
exports.mode()
exports.isAnimated()
exports.invalidate()
```

`purpose` should distinguish at least `battle` from `portrait`. Menu/Summary
portraits must receive a stable **2D still frame**, never an animation atlas or
a 3D world object. A reasonable portrait rule is the animation's neutral frame,
falling back through static selected-generation art to ROM.

Changing any art option must invalidate relevant caches immediately so live
menus and the next battle use the newly selected provider.

## 11. Compatibility with Dramatic Shape and Battle Art Voxel Fork

This is the highest-risk architecture decision.

The standalone replacer should ideally act as a **2D art provider**, while
Dramatic Shape remains responsible for world geometry and battle staging.
However, Battle Art Voxel Fork 1.7.6 internally owns several of the same battle
sprite fields and animation paths and does not obviously expose a stable public
provider contract. Installing both without coordination may create hook-order,
cache, placement, animation, or double-replacement bugs.

Before implementation, trace and document:

1. Every hook/wrapper that replaces Pokemon, trainer, or player art.
2. Whether the voxel fork can consume an external resolver dynamically.
3. Whether priority ordering can make the standalone provider authoritative
   without breaking world placement/metrics.
4. Whether a small optional adapter is sufficient.
5. Whether the two mods must temporarily declare a conflict.

Do not claim compatibility based only on both mods loading. Test actual battles
with voxel battles on/off, front/back player views, static/animated art, trainer
intros, Transform, faint/switch sequences, and ROM fallbacks.

If true coexistence requires editing the third-party voxel fork, stop and
present the user with the exact required contract change. Do not silently fork
or overwrite the installed mod.

## 12. Licensing and asset provenance

Code architecture and asset acquisition are separate workstreams.

- Do not package ROMs or ROM fragments beyond what is legally permitted for
  user-derived local assets.
- Do not copy third-party sprite collections until their licenses and
  redistribution terms are verified.
- Keep attribution and licenses alongside any redistributable material.
- If assets must be extracted from user-owned games, ship import/conversion
  tooling and documentation rather than extracted copyrighted collections.
- Record provenance per generation and per category. “Found online” is not a
  sufficient provenance record.

The complete Gen 1–5 trainer matrix is especially likely to have gaps or
inconsistent class mappings. Do not fill gaps with visually similar but
incorrect trainers without explicit documentation and user approval.

## 13. Implementation phases

### Phase 0 — Research and feasibility report

1. Audit the reference fork's art hooks, settings, animation decoders, metrics,
   file formats, class maps, and fallbacks.
2. Audit Gen1 Recomp's current public hook/API surface.
3. Audit current Widescreen UI and Shiny System contracts.
4. Build a Gen 1–5 availability/provenance matrix for Pokemon fronts, Pokemon
   backs, trainers, and player art in static and animated forms.
5. Resolve standalone-versus-adapter architecture and conflict policy.
6. Present gaps and decisions honestly before bulk asset work.

### Phase 1 — Resolver skeleton

1. Create the manifest, settings, slug map, flat asset naming scheme, cache,
   validation, and ROM fallback.
2. Implement static Pokemon front/back selection for all five generation slots,
   even if development fixtures initially cover only a few species.
3. Implement static trainer and player selectors.
4. Expose the public 2D provider API.
5. Add Lua 5.1 unit tests with synthetic images/fixtures.

### Phase 2 — Animation

1. Add format-specific decoders behind normalized descriptors.
2. Implement genuine animations where validated.
3. Implement selected-generation static fallback everywhere else.
4. Verify timing, anchors, mirroring, hit flash, switch/faint behavior, and
   one-shot player intros.

### Phase 3 — Integrations

1. Integrate per-instance shiny resolution without circular calls.
2. Integrate live Widescreen UI portraits using neutral 2D frames.
3. Validate Dramatic Shape/Battle Art Voxel Fork coexistence or declare an
   honest temporary conflict.

### Phase 4 — Complete assets and release

1. Validate all 151 Pokemon for every included front/back set.
2. Validate every mapped Gen 1 trainer class for each included trainer set.
3. Validate all five player selections.
4. Generate contact sheets/audit PNGs and inspect them visually.
5. Run all provider/consumer tests.
6. Build and audit a flat ZIP.
7. Place the ZIP in `Releases`; do not install it.

## 14. Minimum test matrix

Automated tests must cover:

- Option persistence and all legal values.
- ROM mode bypasses every replacement.
- Pokemon generation selection controls both front and back.
- Correct side orientation and no accidental double mirroring.
- Static mode never interprets an atlas.
- Animated mode accepts valid descriptors and rejects malformed ones.
- Missing animated asset falls to same-generation static, then ROM.
- Missing trainer class falls to ROM, not another generation/class.
- Missing player animation falls to same-generation static, then ROM.
- Cache invalidation after every option change.
- Both shiny-state representations and per-instance shiny selection.
- Two same-species Pokemon with different shiny states.
- Portrait requests return a still 2D image, not an atlas/3D object.
- Trainer intro, player intro, wild battle, trainer battle, switch, faint,
  Transform, Safari/demo/scripted battles, and battle exit.
- Coexistence tests with Widescreen UI, Shiny System, and Dramatic Shape/Battle
  Art Voxel Fork where supported.

Use the exact Lua 5.1 runtime shipped with Gen1 Recomp when possible. Reuse the
existing test runner pattern from:

`C:\Users\invok\Documents\Codex\2026-08-08\ok\gen1_widescreen_ui\tests\run_lua51_test.py`

## 15. Packaging and release gates

Follow `MASTER_MOD_GUIDE.md` exactly:

- Flat/root-only ZIP.
- `manifest.json` and declared entry at archive root.
- No duplicate entries.
- ZIP filename version equals manifest version.
- No nested paths unless explicitly proven safe and approved.
- Expected asset counts and PNG dimensions validated.
- Required README, attribution, and license files included.
- Never copy/install the ZIP into the launcher's Mods directory.

Every user-visible or compatibility change requires a version bump in the
manifest, README current-build line, source header, and ZIP filename.

## 16. Required first deliverable from the next agent

Do not begin by bulk-copying assets. First produce a concise feasibility report
containing:

1. The complete current option/behavior audit of Battle Art Voxel Fork 1.7.6.
2. A Generation 1–5 asset and animation availability/provenance matrix.
3. The proposed final option rows and defaults.
4. The hook ownership diagram and compatibility decision.
5. The flat filename/metadata contract.
6. Known gaps, legal/licensing constraints, and what will fall back to static
   or ROM.
7. A phased implementation and test plan.

Only after those points are evidence-backed should implementation begin.
