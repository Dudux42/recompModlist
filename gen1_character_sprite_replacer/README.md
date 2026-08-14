# Gen1 Character Sprite Replacer

Current build: **0.1.0-alpha.8**

The player appearance selector provides:

- `FRLG RED (MALE)`
- `FRLG LEAF (FEMALE)`
- `ROM`

It also provides an independent `ENEMY TRAINERS` selector:

- `ROM`
- `GEN 3 (FRLG)`

The male/female labels describe the selected visual character. The mod does not change player name, save identity, gender semantics, collision, movement, scripts, parties, battle rules, or world geometry.

## Implemented surfaces

- Native 2D walking and bicycle animation using the neutral center-column idle,
  both authored FRLG step frames, and all four authored directions, plus
  standard Surf composition.
- New-game/Oak-intro player front through the engine's live `player.sprite` seam.
- Trainer Card player front.
- Hall of Fame player front and player-back sweep.
- Normal player battle back/send-out presentation.
- Five-frame FRLG Red/Leaf player throw animation during the opening battle
  send-out, with a smooth 40-frame synchronized trainer-back slide. When the
  Widescreen battle HUD is active, that presenter owns the single visible copy.
- Mapped FRLG enemy trainer portraits for 44 Gen 1 opponent classes,
  including rivals, Gym Leaders, and the Elite Four. They remain static and
  use the engine's original single battle placement.
- Versioned Character Appearance API v1, including a dedicated main-menu presentation descriptor.
- Same-subject ROM fallback for missing assets and explicit `ROM` mode.

Trainer Card, Hall of Fame, intro, and battle use the same selected Red or Leaf pack. Old Man and Yellow Professor Oak tutorial backs remain ROM-owned.

## Honest first-batch fallbacks and blockers

- Fishing keeps the ROM player pose. The engine builds fishing from an 8px Gen 1 hand tile plus a separate rod effect, while this supplied FRLG sheet contains full, inseparable rods. Compositing it directly would double or sever the rod.
- Surfing Pikachu and Fly bird art remain ROM-owned because they are Pokemon/nonhuman effects.
- Overworld NPCs and enemy-trainer overworld walkers remain ROM-owned.
- Professor Oak and Yellow's special Jessie/James portrait remain ROM-owned
  because the supplied sheet has no direct matching front portrait.
- Widescreen's responsive START/title main-menu presenters do not yet consume a player-character provider. The mod publishes `resolvePlayerPresentation`, and the exact owner request is in `GEN1_WIDESCREEN_UI_CHARACTER_PRESENTATION_REQUEST.md`.
- Dramatic Shape 1.8.0 hardcodes 16x16 billboard geometry, UV steps, and the
  legacy two-frame walk cadence. Alpha 5 installs a scoped runtime adapter
  from this mod for Character Appearance API v1 definitions only. It supplies
  correct frame UVs, the correctly ordered idle/step frames and all four
  authored walk/bicycle directions, 16x32/32x32
  visible geometry, bottom anchoring, mirroring, shadows, and ghost silhouettes
  without editing Dramatic Shape files or affecting ROM/NPC sprites. If the
  adapter cannot be installed, the safe alpha 2 ROM-overworld fallback remains.

## Public API

```lua
exports.characterAppearanceApiVersion = 1
exports.activePack()
exports.resolvePlayerOverworld(role, context)
exports.resolveNpcOverworld(spriteId, context)
exports.resolveTrainerOverworld(trainerClass, context)
exports.resolveTrainerBattle(trainerClass, context)
exports.resolvePlayerBattle(role, context)
exports.resolvePlayerPresentation(role, context)
exports.invalidate()
exports.auditCoverage(game)
```

Resolvers return `nil` for ROM mode, unsupported roles, or missing art. Descriptors include the asset path, frame dimensions/count, ground anchor, logical 16x16 footprint, pack ID, role, and visual-gender label.

## Installation

Import the versioned ZIP through the Gen1 Recomp launcher. Do not unpack it into the installed Mods directory manually. The archive is flat: every entry is at ZIP root.

## License and provenance

Code is MIT licensed. Game-derived images are not covered by the MIT license; see `ASSET_PROVENANCE.md`. No ROM is included.
