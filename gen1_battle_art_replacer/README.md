# Gen1 Battle Art Replacer

Current build: **0.1.0-alpha.12**

This release replaces front battle art for all 151 Gen 1 Pokemon with a
selectable Pokemon Red, Blue, Yellow, Crystal, FireRed/LeafGreen, Emerald,
Platinum, HeartGold/SoulSilver, or Gen 5 collection. It supports still
presentation and front-only animation, including matching normal and shiny art.

## Options

- `BATTLE ART: STATIC` uses the selected collection's still image.
- `BATTLE ART: ANIMATED` plays authored Gen 5/Crystal timing or the supplied
  Platinum, HGSS, and Emerald sheets' two front poses on a provider-owned
  500 ms-per-frame cadence.
  FRLG, Red, Blue, and Yellow safely remain on their selected still image.
- `POKEMON ART: GEN 5` selects Black/White-era fronts.
- `POKEMON ART: GEN 4 PLATINUM` (`gen4Platinum`) selects Platinum fronts.
- `POKEMON ART: GEN 4 HGSS` (`gen4HGSS`) selects HeartGold/SoulSilver fronts.
- `POKEMON ART: GEN 3 EMERALD` (`gen3Emerald`) selects Emerald fronts.
- `POKEMON ART: GEN 3 FRLG` (`gen3FRLG`) selects FireRed/LeafGreen fronts.
- `POKEMON ART: GEN 2 CRYSTAL` (`gen2Crystal`) selects Crystal fronts.
- `POKEMON ART: GEN 1 RED` (`gen1Red`) selects international Red art.
- `POKEMON ART: GEN 1 BLUE` (`Gen1Blue`) selects international Blue art.
- `POKEMON ART: GEN 1 YELLOW` (`Gen1Yellow`) selects Yellow art.
- `POKEMON ART: ROM` bypasses all replacements.

International Pokemon Red and Blue use the same front-sprite drawings, so the
Red and Blue options intentionally share one authentic Red/Blue file set. They
remain separate settings so a saved configuration can name the game edition
the player wants.

Alpha 4 replaces background-color heuristics with the source collection's
exact binary transparency masks for every Red/Blue and Yellow sprite. This
removes enclosed white background pockets without erasing legitimate white
details such as Mankey's body.

Alpha 6 rebuilds every normal and shiny Gen 5 still/animation from the exact
Black/White animated GIF frames. Their authored durations are preserved
directly. Shiny Scyther's different canvas/frame contract is represented by its
own metadata descriptor.

Alpha 8 repairs fully enclosed one-to-three-pixel holes caused when a GIF's
transparent palette index is also used as a shade inside the drawing. Each
pixel is restored with that GIF index's own RGB value in both normal and shiny
frames. Larger authored openings and background-connected transparency remain
untouched.

Alpha 9 adds normal and shiny HeartGold/SoulSilver art extracted from the
user-supplied first-generation battle sheet. Only the two front-facing cells
are used; back-facing cells, labels, and gender/form headings are excluded.
The labeled corrected Kabuto front panel replaces Kabuto's original cells.
STATIC uses front frame 1 and
ANIMATED loops front frames 1 and 2 at 500 ms each. The sheet contains poses
but no ROM timing data, so this cadence is provider-authored rather than
claimed as an original HGSS duration sequence.

Alpha 10 trims the unused outer matte shared by every HGSS species' normal,
shiny, and two animation poses. This preserves frame alignment while allowing
UI consumers to size the visible Pokemon instead of an empty 80x80 cell. It
also corrects Dramatic Shape's player-front scale path so a provider front no
longer inherits the native 2x back-sprite scale. FRLG normal/shiny front art is
added for all 151 species. Only the sheet's full-size front row is imported;
back cells, header thumbnails, and gender/form indicators are excluded.

Alpha 11 adds normal and shiny Emerald fronts for all 151 species from the two
user-supplied sheets. Each species' two consecutive 64x64 front poses are
preserved and share one tight aligned crop. STATIC uses pose 1; ANIMATED loops
both poses at 500 ms each. The sheets provide poses but no timing metadata, so
the cadence is provider-authored rather than claimed as an original Emerald
duration sequence.

Alpha 12 adds normal/shiny Crystal and Platinum front art for all 151 species.
Crystal animation uses the canonical per-frame sequence and durations while
retaining the supplied sheet's RGB art wherever the sources agree; incompatible
reference drawings fall back to transparency derived from the supplied sheet.
Platinum STATIC uses front pose 1 and ANIMATED alternates its two supplied front
poses at 500 ms each. Platinum back cells and every redundant female section
are excluded; Nidoran Female and Nidoran Male remain their distinct species.

## Animation and fallbacks

Gen 5, Crystal, Platinum, HGSS, and Emerald atlas cells are decoded into individual
nearest-filtered images. Gen 5 durations come from source-authored metadata;
Platinum, HGSS, and Emerald use their documented two-frame provider cadence. Portrait
consumers receive the stable neutral still, never an atlas.

Fallbacks never switch sideways into another art set:

1. matching Gen 5, Platinum, HGSS, Emerald, Crystal, or FRLG shiny animation/still when shiny presentation is active;
2. selected set's normal animation or still;
3. the active ROM sprite.

FRLG provides authentic normal and shiny stills. Generation 1 has no native
shiny sprites, so Red, Blue, and Yellow retain their
normal selected art for a shiny Pokemon; the separate Shiny System still owns
shiny state and sparkle presentation.

Back sprites, opponent trainers, and player battle-intro art remain ROM-owned.
The player receives a selected front only when Dramatic Shape's `FRONT SPRITES`
view explicitly requests one.

## Compatibility

The mod is compatible with Dramatic Shape 1.8.0 through its exported
`OverworldBattle.wantsFront()` contract and leaves its camera, placement,
models, battle staging, and rendering untouched. It remains incompatible with
`BATTLE_ART_VOXEL_FORK`, which owns the same battle-art fields.

When Dramatic Shape requests a player front through the engine's original back
slot, the provider routes only its own replacement image through the normal
front-image scale. This prevents a 2x back scale from enlarging that front;
ROM backs and Dramatic Shape's perspective, camera, and geometry are unchanged.

Every provider-owned still and decoded animation frame is registered as
true-color art with Dramatic Shape's `BattlePics` compatibility seam. Dramatic
Shape therefore skips its native Gen 1 paper-white restoration only for those
images, preserving intentional enclosed transparency (including Mankey's tail
opening) on every frame. ROM sprites still use Dramatic Shape's restoration.

Changing either option invalidates still and animation caches. Switches and
Transform are re-evaluated from the current battler Pokemon on each update.

## Presentation API v1

UI mods can request the exact live 2D presentation selected by this provider:

```lua
provider.exports.presentationApiVersion = 1

local presentation = provider.exports.resolvePokemonPresentation(
  game,
  mon,
  "front",
  {
    purpose = "title", -- title, pokedex, party, summary, or another string
    token = stableConsumerOwnedTable,
    now = optionalMonotonicTimeInSeconds,
  }
)
```

The function returns `nil` for ROM mode, unsupported sides, unknown Pokemon,
or missing/malformed assets. Otherwise it returns:

```lua
{
  image = loveImage,
  trueColor = true,
  animated = boolean,
  mode = "static" or "animated",
  artSet = string,
  frameIndex = optionalNumber,
}
```

Contract details:

- Gen 5 + `ANIMATED` returns the current decoded atlas frame using the
  species' authored frame durations. It never returns the atlas itself.
- Gen 5 + `STATIC` returns the neutral still selected by normal/shiny state.
- HGSS + `ANIMATED` returns one of the two supplied front poses on the
  provider-owned 500 ms cadence; HGSS + `STATIC` returns front pose 1.
- HGSS normal/shiny selection follows the same per-Pokemon shiny rules as Gen 5.
- Platinum + `ANIMATED` returns its two supplied normal/shiny front poses at
  500 ms each; `STATIC` returns pose 1.
- Emerald + `ANIMATED` returns one of its two supplied normal/shiny front poses
  on the provider-owned 500 ms cadence; `STATIC` returns pose 1.
- Crystal + `ANIMATED` returns the current decoded normal/shiny front frame
  using its per-species duration table; `STATIC` returns its first frame.
- FRLG returns its selected normal/shiny front still in both modes. Red, Blue,
  and Yellow return their selected cartridge still in both modes;
  under `ANIMATED`, `mode` remains `"animated"` while `animated` is `false`.
- Only `side == "front"` is supported. The API never resolves Dramatic Shape
  or Stadium models and never assumes ownership of back sprites.
- `mon` may be a full Pokemon or a lightweight `{ species = "PSYDUCK" }`.
  Shiny art is selected only when the supplied object itself carries valid
  Shiny System, explicit-flag, or native-DV shiny state.
- A stable table in `context.token` owns one animation timeline. Reusing it
  continues playback; different tokens animate independently. Token state is
  weak-keyed so an abandoned UI screen can be collected.
- `context.now` is preferred. Without it, the provider uses LÖVE's monotonic
  timer and safely falls back to `os.clock`. Repeating the same timestamp does
  not advance twice.
- Changing species, shiny state, collection, or presentation mode resets the
  token safely. Option and asset invalidation clear all UI animation state.
- Every returned still and decoded frame uses nearest-neighbor filtering.

Legacy consumers may continue using `resolvePokemonImage`,
`resolvePokemonPath`, `mode`, `isAnimated`, and `invalidate`. The legacy image
resolver intentionally remains a stable neutral portrait.

## Asset provenance

See `ASSET_PROVENANCE.md`. No ROM is included. Pokemon artwork remains
copyright The Pokemon Company; this package is intended for the user's private
mod setup.

## Packaging

The release ZIP is flat: the manifest, Lua files, documentation, metadata, and
PNGs are all at archive root. Import it manually through the Gen1 Recomp
launcher; the build is not installed automatically.
