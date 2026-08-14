# Next Agent Brief — Character Sprite Replacer

Last updated: **2026-08-11**

## 1. Mission

Create a standalone character-appearance mod for Invoker's Gen1 Recomp
compilation. One coherent selectable pack must replace:

1. Player overworld sprites.
2. Player battle back and front/presentation sprites.
3. Human overworld NPC sprites.
4. Enemy trainer overworld sprites.
5. Enemy trainer battle portraits.

Working title: **Gen1 Character Sprite Replacer**  
Provisional manifest ID: `gen1_character_sprite_replacer`

### Hard agent ownership boundary

This agent may implement changes only in `gen1_character_sprite_replacer` and
its own tests, extraction tools, release package, provenance, audits, and
handoff documentation. It must not edit Widescreen UI, Dramatic Shape, Battle
Art, or any other mod, and must not add new runtime patches of another mod's
private internals. Public provider/consumer APIs may be used from this mod.

When correct presentation requires another owner to change, write a focused
`*_REQUEST.md` containing the evidence, smallest requested API or behavior,
fallback requirements, and acceptance tests. Give that request to the user for
handoff. Do not implement the foreign-owner change in this task, even if its
repository files are locally available.

This mod owns human appearance only. It must not alter maps, collision,
movement, scripts, trainer parties, AI, battle rules, dialogue, Pokémon art,
followers, visible wild Pokémon, items, or saves.

Read `MASTER_MOD_GUIDE.md` before implementation. The exact packs, source art,
dimensions, and provenance must be supplied or approved by the user; do not
fabricate asset coverage.

### 1.1 Current first-batch implementation

Released source/build: **Gen1 Character Sprite Replacer 0.1.0-alpha.8**
(`gen1_character_sprite_replacer`), with the flat release at
`Releases/gen1_character_sprite_replacer_v0.1.0-alpha.8.zip`.

The user supplied one FireRed/LeafGreen player sheet. Alpha 1 adds a coherent
`CHARACTER SPRITE` selector with `FRLG RED (MALE)`, `FRLG LEAF (FEMALE)`, and
`ROM`. Exact reviewed crops provide 16x32 walking frames, 32x32 bicycle/Surf
frames, 64x64 player front/back art, and a dedicated 64x96 main-menu
presentation asset. Native 2D art is bottom-center anchored to the unchanged
16x16 logical player footprint. The live `player.sprite` seam supplies the
selected front to the intro, Trainer Card, and Hall of Fame and the selected
back to battle/Hall-of-Fame paths. Old Man and Yellow Oak tutorial backs remain
ROM-owned.

Alpha 5 expands walk and bicycle from the engine's six-pose/two-frame cadence
to a twelve-pose layout. The source order is step A, neutral idle, step B;
extraction stores neutral idle first, followed by both steps, for all four
authored directions. A scoped `Player:pose()` wrapper
publishes the selected authored frame only to this mod's role sprites. The
local Dramatic Shape mesh adapter consumes that frame and cancels its legacy
up/down mirror internally; no Dramatic Shape source file is edited.

Alpha 6 adds an independent `ENEMY TRAINERS` selector (`ROM` or
`GEN 3 (FRLG)`). It maps 44 Gen 1 opponent classes to reviewed 64x64 FRLG
fronts and patches only BattleState's public trainer path/palette resolvers.
Professor Oak and Yellow Jessie/James keep ROM art. The same release extracts
five Red and five Leaf player-back throw frames and plays them at 1x during
the opening send-out. Alpha 8 holds the five poses for eight updates each and
synchronizes the trainer-back slide/sendout wait to 40 frames.

This remains an incomplete human-art batch. Overworld NPC and enemy-trainer
walker mappings remain empty, while enemy battle fronts are implemented.
Fishing keeps its
ROM composition because the engine combines a Gen 1 hand tile with a separate
rod while the supplied FRLG frames contain a full inseparable rod. Surfing
Pikachu and Fly remain with their Pokemon/effect owners.

One required owner-side integration remains open:

- `GEN1_WIDESCREEN_UI_CHARACTER_PRESENTATION_REQUEST.md` asks Widescreen to
  consume Character Appearance API v1 for START/title-main-menu/Continue
  portraits. Alpha 1 publishes `resolvePlayerPresentation`, but Widescreen
  0.1.0-alpha.14.6 did not have that consumer seam when re-audited (the latest
  packaged release present at the time was alpha 14.5).
- Dramatic Shape 1.8.0 still lacks a public enhanced-character contract, but
  it is no longer a release blocker. Alpha 6 installs a narrowly scoped
  consumer-side adapter through Dramatic Shape's exported module loader. It
  intercepts only this mod's Character Appearance API v1 definitions and
  builds correctly sliced/anchored 16x32 and 32x32 solid, shadow, and ghost
  meshes. ROM, NPC, follower, and other-mod calls retain their original
  functions. `DRAMATIC_SHAPE_ENHANCED_CHARACTER_REQUEST.md` is now an optional
  upstream-contract proposal rather than required dependent work.

Do not claim Widescreen main-menu presentation complete until its owner change
is released, integrated, and tested. The extraction is reproducible through
`gen1_character_sprite_replacer/tools/extract_frlg_player_batch.py` and
`extract_frlg_trainers_batch.py`; current focused audits are
`visual_audits/gen1_character_sprite_replacer_alpha5_ordered_cycle.png` and
`visual_audits/gen1_character_sprite_replacer_alpha6_trainers_throw.png`.

## 2. Ownership decision

The released **Gen1 Battle Art Replacer 0.1.0-alpha.11** currently owns Pokémon
front battle art only. Its README explicitly leaves Pokémon backs, opponent
trainers, and player battle art ROM-owned.

From this point forward:

- Battle Art Replacer owns Pokémon battle art.
- Character Sprite Replacer owns player and human NPC/trainer art across
  overworld and battle contexts.
- They coexist unless a future version crosses that boundary.
- Trainer/player requirements in the older Battle Art planning brief are
  superseded by this document.

This is one coordinated human-character provider, not a second Pokémon-art mod.

## 3. Engine surfaces audited

### 3.1 Overworld registry

`game.data.sprites` records expose `image`, `frames`, `walker`, `trueColor`, and
optional `paletteSource`. The current `SpriteRenderer` assumes a **16×96**
six-frame walking sheet:

1. Stand down.
2. Stand up.
3. Stand left.
4. Walk down.
5. Walk up.
6. Walk left.

Each frame is 16×16. Right-facing is a horizontal flip of left; up/down steps
also use flips. Some non-walkers use one or three frames.

### 3.2 Player roles

Current `field.playerSprites` distinguishes at least `walk`, `surf`,
`surfPikachu`, `bike`, and `fly`. Fishing uses separate pose art and must also
be audited. Replacing only `SPRITE_RED` is incomplete.

Current `field.playerPics` distinguishes:

- `back` — normal battle back/send-out art.
- `front` — intro, Trainer Card, and Hall of Fame front.
- `demoBack` — Old Man tutorial.
- `oakBack` — Yellow Professor Oak special battle position.

Replace the normal player front/back. Never substitute the player into Old Man
or Oak roles; those need their own mapped art or ROM fallback.

### 3.3 NPC and trainer overworld objects

Map objects reference sprite IDs. Many trainers and non-trainers share generic
overworld sheets, and trainer class is not necessarily encoded by sprite ID.

- Global sprite-ID replacement is valid for a generic NPC role.
- Class-specific trainer art may require registering a new sprite ID and
  changing only the `sprite` field of verified trainer map objects.
- Preserve object ID, coordinates, facing, movement, script, trainer header,
  flags, collision, and event state exactly.
- Never replace a whole map object merely to change art.

### 3.4 Trainer battle portraits

`game.data.trainers[trainerClass].pic` owns the opponent image; `basePic` may
share another class's portrait, and `paletteSource` may carry palette
provenance. Patch only appearance fields through the supported registry/public
resolver. Parties, money, AI, themes, and identity remain untouched.

Player battle/front art resolves through the engine's live `player.sprite`
path. Use that supported seam or structured field data so battle, intro,
Trainer Card, Hall of Fame, native UI, and compatible consumers stay coherent.

## 4. Character scope

Required:

- Player walk, bike, Surf, fishing, and verified special poses.
- Named and generic human NPCs.
- Human enemy trainer map sprites.
- All used enemy trainer battle classes.
- Player front and battle back.

Excluded unless explicitly approved:

- Pokémon followers and visible wild Pokémon.
- Pikachu follower/emotion art.
- Poké Balls, fossils, boulders, trees, signs, vehicles, and effects.
- Fly bird/Surf mount creature art when separable from player art.
- Pokémon battle fronts/backs and Stadium models.

Audit every live sprite ID as human, nonhuman, or unknown. Do not classify by
filename alone; unknown records keep their ROM/default art.

## 5. Pack/options model

Use one coherent selector:

```text
CHARACTER PACK: ROM / <REAL PACK NAME> / ...
```

- One pack applies matching player, NPC, and trainer art together.
- `ROM` bypasses all replacements.
- Missing art falls back to that same subject's ROM/default art.
- Never fall sideways to another character, class, or pack.
- Never expose empty Generation 1–5 selector slots without complete real art.
- Pack changes invalidate caches and rebuild live world instances at a verified
  safe boundary.
- If switching during a battle transition is unsafe, queue it until the next
  map/battle boundary rather than corrupting the active state.

Independent category toggles can be considered later; coherent pack selection
and honest local fallback come first.

## 6. Asset gates

### 6.1 Native-compatible first release

The safest first release uses the native logical contract:

- Walkers: 16×96 RGBA, six aligned 16×16 frames.
- Verified dimensions for one/three-frame human roles.
- Transparent background or audited palette-index-0 conversion.
- Nearest-neighbor filtering and integer placement.
- Consistent feet/ground anchor.
- No anti-aliased semi-transparent edges unless using an audited true-color
  path.

Do not silently downsample larger supplied art. Conversion must be scripted,
reproducible, visually audited, and approved.

### 6.2 Enhanced-size gate

32×32 or larger later-generation frames are not drop-in assets. The current
renderer slices 16×16 cells, while grass occlusion, y-sorting, and external
render pipelines assume native geometry.

Enhanced support requires a versioned descriptor:

```lua
{
  image = "...",
  frameW = 32,
  frameH = 32,
  frameCount = 12,
  layout = "frlg-twelve-pose",
  anchorX = 16,
  anchorY = 28,
  logicalFootprintW = 16,
  logicalFootprintH = 16,
  trueColor = true,
}
```

Visible art may extend beyond the cell, but collision, interaction range,
movement, and map position remain 16×16 logical behavior. Placement is
feet/ground anchored, never center-scaled.

If Dramatic Shape or another presenter needs a provider-side change, do not
edit it from this project. Stop at that boundary and give the user the exact
owner-agent prompt required by Master Guide section 1.1. Native-size support
may proceed independently.

### 6.3 Battle assets

Inventory supplied dimensions before freezing loaders. Each descriptor records
subject ID/role, path, dimensions, bottom anchor, palette/true-color behavior,
animation metadata, and provenance.

Battle portraits are static initially unless authentic frames and timings are
provided. Do not fake animation by bobbing, stretching, or alternating
unrelated images.

## 7. Explicit mappings and completeness

Use reviewable files, not filename guessing:

```text
character_packs.lua
overworld_sprite_map.lua
trainer_class_map.lua
trainer_object_map.lua
player_role_map.lua
```

Stable identities come from engine IDs, never display names.

Generate an auditable trainer crosswalk with map ID, object ID/index, original
sprite ID, trainer class/identity, replacement sprite ID, and provenance.
Script-driven trainers require explicit verification. Per-object patches must
prove that only the sprite reference changed.

Report completeness separately:

- Used human sprite IDs: dedicated/fallback/excluded.
- Used trainer classes: battle portrait and verified map mapping.
- Player roles: walk/bike/surf/fishing/front/back and special cases.

A pack is not complete merely because every supplied file loaded; audit against
every live consumer.

## 8. Provider API

Expose versioned read-only resolution:

```lua
exports.characterAppearanceApiVersion = 1
exports.activePack()
exports.resolvePlayerOverworld(role, context)
exports.resolveNpcOverworld(spriteId, context)
exports.resolveTrainerOverworld(trainerClass, context)
exports.resolveTrainerBattle(trainerClass, context)
exports.resolvePlayerBattle(role, context) -- front/back
exports.invalidate()
exports.auditCoverage(game)
```

Recommended descriptor:

```lua
{
  owner = "gen1_character_sprite_replacer",
  packId = "example_pack",
  subjectId = "OPP_BROCK",
  role = "trainer_battle",
  imagePath = "...",
  trueColor = true,
  frameW = 64,
  frameH = 64,
  frames = 1,
  anchor = "bottom-center",
  fallback = false,
}
```

Resolvers return `nil` for ROM mode or missing/unsupported art so the normal
engine chain continues. Cache by descriptor/path and pack revision; invalidate
on pack, asset, or provider reload. Refresh all live player/NPC instances
consistently—never leave one map half old/half new.

## 9. Presentation invariants

- Nearest filtering and integer world placement.
- Preserve aspect ratio for battle portraits.
- Ground/feet anchor character art.
- Preserve native facing and walk cadence.
- Respect the engine's left-to-right flip contract; do not mirror asymmetric
  text/emblems incorrectly.
- True-color art bypasses ROM palette recoloring; indexed/DMG art keeps its
  verified palette path.
- Preserve tall grass, doors, ledges, Surf, fishing, cutscenes, and y-sorting.
- Never alter hitboxes or compensate for art size by moving entities.

## 10. Player requirements

Keep one appearance consistent across walking, bicycle, Surf/Surfing Pikachu
composition, fishing, ledge hops, spins, warps, scripted movement, battle
send-out/back, new-game/Oak intro front, Trainer Card, and Hall of Fame.

Do not change player identity/name, collision, position, facing, speed, input,
party, or gender semantics. Old Man and Oak tutorial backs are separate roles.

## 11. NPC/trainer requirements

- Generic NPC art follows stable sprite-role IDs.
- Named overrides require explicit mapping.
- Battle portraits follow trainer class/identity, not overworld filename.
- Paired trainer art should be visually consistent where real paired assets
  exist.
- Sight, exclamation marks, approach movement, defeated state, rematches, and
  scripts remain unchanged.
- Nurse, clerk, professor, rival, leaders, Elite Four, Rockets, and other story
  characters require explicit audit rows.
- Non-trainers never gain trainer behavior because their art resembles one.

## 12. Compatibility

### Battle Art Replacer

Compatible by category: Pokémon versus humans. If a future Battle Art version
starts replacing trainer/player art, stop and send its agent a prompt to remove
or formally delegate the overlap before continuing.

### Widescreen UI

Optional consumer, not mandatory. Widescreen should use the live engine/player/
trainer resolver or this API. If a verified screen caches a hardcoded portrait,
do not patch Widescreen here; provide the user a Widescreen-agent prompt for the
smallest resolver/invalidation change and version bump.

### Dramatic Shape

Do not touch its geometry, camera, voxels, battle staging, or models. Native
16×16 replacements should flow through `SpriteRenderer:resolveImage()`; test
that seam. Enhanced sizes require a documented descriptor/UV/anchor contract
from its owner, requested through a cross-mod prompt.

### Yellow Legacy

It owns trainer identity, parties, rematches, and content. Read effective
trainer/map data and change art only. New classes fall back until mapped.

### Followers, Wilds, Shiny, NPC Bubbles

Do not replace Pokémon/follower/wild/shiny art. Preserve NPC identity and draw
order for bubbles. Enhanced art may expose an optional head anchor; if the
bubble owner must change, send its agent a prompt rather than editing it.

`affects_link` may be false only after proving this mod changes presentation
alone. Do not render every linked player as the local selected character
without an explicit multiplayer-avatar policy.

## 13. Conflicts

Conflict only with verified mods owning the same player roles, NPC sprite
records, trainer portraits, or player front/back path. Do not conflict with
Pokémon-only Battle Art, menu icons, followers, spawn mods, or pure UI
consumers. Base decisions on hook/registry ownership, not similar names.

## 14. Packaging and provenance

Flat/root-only package:

```text
manifest.json
main.lua
character_packs.lua
overworld_sprite_map.lua
trainer_class_map.lua
trainer_object_map.lua
player_role_map.lua
README.md
CHANGELOG.md
LICENSE
ASSET_PROVENANCE.md
character_*.png
```

If file count is unsafe, use root-level atlases only after proving all native
and Dramatic Shape consumers can resolve atlas regions. Do not add nested ZIP
entries.

For every asset record source/game or artist, extraction path, transformations,
permission/license, output file, and mapped engine identity. Include no ROM and
preserve all third-party notices.

## 15. Required tests

### Coverage/data

- Enumerate every sprite ID as human/nonhuman/unknown.
- Enumerate every player role, used trainer class, and trainer map object.
- Detect missing files, duplicate mappings, case collisions, and unused art.
- Produce dedicated/fallback/excluded counts.

### Overworld

- Six-frame order, right flip, walk/idle/bike/surf/fishing.
- Player collision, position, speed, and movement unchanged.
- Global generic NPC and verified per-trainer mapping.
- Per-object override changes only `sprite`.
- NPC scripts/movement and trainer sight/battle/defeated flow unchanged.
- Pack switch/reload refreshes every live renderer coherently.
- Nonhuman objects, followers, and wild Pokémon untouched.
- Palette-indexed and true-color modes.

### Battle/UI

- Every used trainer class gets its own replacement or own ROM fallback.
- Player front/back are consistent across battle, intro, Trainer Card, and Hall
  of Fame.
- Old Man/Oak backs remain separate.
- Trainer parties, AI, money, and themes are byte/field equivalent.
- Pokémon Battle Art retains Pokémon ownership.
- Missing/corrupt art warns once and falls back locally.

### Load-order/visual

Test with and without Battle Art Replacer, Widescreen, Dramatic Shape modes,
Yellow Legacy, NPC Bubbles, follower, and Wilds mods in relevant load orders.

Capture player directions and roles; indoor/outdoor NPCs across palettes;
generic trainers, rival, leaders, Elite Four, Rockets; encounter approach and
battle intro; player back/front/Card/Hall of Fame; ROM fallbacks; and Dramatic
Shape modes. Check anchoring, transparency, clipping, occlusion, direction,
identity consistency, and absence of geometry changes.

## 16. Required cross-mod prompts when blocked

For enhanced sprites blocked by Dramatic Shape, the user prompt must identify
its exact version/API and evidence of 16×16 UV assumptions; request consumption
of versioned frame dimensions, layout, ground anchor, and logical footprint;
exclude camera/collision/map/movement changes; require 16×16 fallback, 32×32
grounding, facing, walk, grass, y-sort, and all-mode tests; and request changed
files, schema, version, tests, and release ZIP.

For a Widescreen screen bypassing live character art, identify the exact cached
path; request live provider resolution with ROM fallback and pack-revision
invalidation; keep selection in this mod and drawing in Widescreen; require
screen tests, version bump, and finalized contract details.

Never edit the other mod from this project.

## 17. Implementation order

1. Audit engine, maps, sprite registry, trainer records, and player roles for
   each supported edition.
2. Inventory supplied art and build provenance/dimension matrices.
3. Choose native or enhanced-size Gate; never mix silently.
4. Freeze mappings and exclusions.
5. Implement ROM mode, pack selection, and subject-local fallback.
6. Implement player roles and generic NPC registry replacements.
7. Implement verified per-trainer object sprite changes.
8. Extend the Alpha 6 enemy-trainer battle resolution only when new supplied
   art has an exact mapped class; player battle fronts/backs and throw frames
   are already implemented.
9. Publish resolver/revision/coverage APIs.
10. Run data, unit, load-order, and visual audits.
11. Stop at any cross-mod boundary and provide the required owner-agent prompt.
12. Build a versioned flat ZIP in `Releases`; never install automatically.

## 18. Decisions required before coding

1. Final manifest ID/title.
2. Actual packs/generations/styles and provenance.
3. Native 16×16 versus enhanced overworld frames.
4. Complete player roles, including fishing/Surf composition.
5. Named NPC unique art versus role-based art.
6. Mapping policy when classes share an overworld sprite.
7. Static versus authentically animated battle portraits.
8. Verified conflicting replacement mods.

Do not guess these in production.

## 19. Definition of done

- One pack consistently covers player overworld/battle, human NPCs, and trainer
  overworld/battle art.
- ROM mode and same-subject fallback work without sideways substitution.
- Every player role, human sprite ID, trainer class, and trainer object is
  audited or explicitly excluded.
- No geometry, collision, movement, script, trainer party, AI, battle rule, or
  save state changes.
- Pokémon art, followers, wilds, and Stadium models stay with their owners.
- External consumers use verified public/live seams.
- Cross-mod blockers produce owner-agent prompts, not unauthorized edits.
- Tests and visual audits pass.
- The release ZIP is flat, licensed, versioned, and not auto-installed.
