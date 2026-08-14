# Optional upstream request: enhanced Character Appearance billboard descriptors in Dramatic Shape

Date: **2026-08-11**

## Owning mod

- Name: **Dramatic Shape Voxel Mod**
- Manifest ID: `DRAMATIC_SHAPE`
- Current version audited: `1.8.0`
- Manifest API: 2
- Relevant installed source surfaces: `lib/SpriteBillboards.lua` and `lib/VoxelScene.lua`.
- Current public behavior used by character sprites: live `SpriteRenderer:resolveImage()` plus the renderer's Gen 1 `STAND`/`WALK` frame tables. No enhanced frame-dimension/anchor contract is exposed.

## Dependent mod and blocked use case

- Name: **Gen1 Character Sprite Replacer**
- Manifest ID: `gen1_character_sprite_replacer`
- Current provider version: `0.1.0-alpha.8`
- Blocked use case: render FRLG Red/Leaf overworld player frames at their authored 16x32 walking size and 32x32 bicycle/Surf size while collision, cell position, interaction range, movement, camera, maps, and logical footprint remain 16x16.

## Verified evidence

In Dramatic Shape 1.8.0:

- `lib/SpriteBillboards.lua` describes and builds "One flat 16x16 quad".
- `buildCard(def, frame)` uses `fy = frame * 16`, clamps against `fy + 16`, uses horizontal UVs `0..16`, and emits vertices spanning `0..16` by `0..16`.
- `lib/VoxelScene.lua` anchors billboard matrices around hardcoded `px + 8`, `py + 8`, then translates by `-8`.
- `frameFor` correctly shares the engine's pose tables, but has no way to apply a descriptor's frame height, visible width, ground anchor, or logical footprint.

Therefore a 16x192 sheet containing six 16x32 frames selects half-frames, and a 32x192 sheet is both UV-cropped and represented by 16x16 geometry. This is verified from current source, not inferred from filenames.

Observed in-game evidence: under the unsupported voxel path, Surf showed a
separately displaced mount/player layer plus a red horizontal fragment from an
incorrectly sampled player-frame band. Character Sprite Replacer alpha 2 now
guarded this by using ROM overworld renderers while `voxel` was active. Alpha 3
supersedes that limitation with the scoped local adapter described below.

Status update: alpha 5 now carries a scoped consumer-side mesh/pose adapter inside
the Character Sprite Replacer, installed through Dramatic Shape's existing
exported module loader. It handles this mod's own descriptors without editing
Dramatic Shape files and retains ROM fallback if installation fails. This
request is therefore optional upstream API cleanup, not a blocker for alpha 5.

## Smallest requested owner-side change

Teach Dramatic Shape's sprite billboard, shadow, ghost, and relevant cache paths to consume optional dimensions/anchors already carried by the live `sprite.def` supplied by the Character Sprite Replacer:

```lua
{
  frameW = 16 or 32,
  frameH = 32,
  frameWidth = 16 or 32,   -- compatibility alias during contract freeze
  frameHeight = 32,
  frames = 12,
  layout = "frlg-twelve-pose",
  anchorX = 8 or 16,
  anchorY = 32,
  logicalFootprintW = 16,
  logicalFootprintH = 16,
  trueColor = true,
  characterAppearanceApiVersion = 1,
  characterAppearanceOwner = "gen1_character_sprite_replacer",
}
```

Requested resolution rules:

1. Default missing dimensions to the current 16x16 behavior exactly.
2. Slice UVs using `frame * frameH`, `frameW`, and `frameH` against the live resolved texture.
3. Size visible billboard geometry to `frameW` x `frameH`.
4. Pivot/ground at descriptor `anchorX`, `anchorY`, mapped to the same logical cell feet used today; wider art extends around the 16x16 footprint and taller art grows upward.
5. Keep pose selection and right/step mirroring exactly as today.
6. Use the same geometry/UV/anchor calculation for solid billboards, sun shadows, drop-shadow fallback, and inverted-depth player ghost so silhouettes do not drift.
7. Include dimensions/anchors in billboard cache keys. Asset or provider invalidation must discard stale meshes.

If the owner prefers a versioned exported registration API instead of reading `sprite.def`, return the finalized schema and registration/invalidation calls. The dependent mod can adopt that public contract in its next version.

## Non-goals

- Do not change camera, voxel terrain, map geometry, collision, movement, logical coordinates, interaction range, y-sort authority, battle staging, Stadium models, or save state.
- Do not move character-pack selection or asset ownership into Dramatic Shape.
- Do not scale every sprite globally. Enhanced behavior applies only when the optional descriptor is present and valid.
- Do not edit the Character Sprite Replacer or duplicate its assets.
- Do not use the existing follower proxy-sheet workaround as the finalized contract; that preserves normalized UV selection by shrinking 32x32 art onto 16x16 geometry and does not satisfy authored enhanced dimensions/grounding.

## Failure and compatibility behavior

- Invalid/missing descriptor fields must fall back to the exact current 16x16 path and warn at most once per owner/path.
- Missing/corrupt enhanced textures must retain Dramatic Shape's existing safe fallback behavior.
- ROM and every ordinary NPC sprite without a descriptor must be pixel/geometry equivalent to 1.8.0.
- True-color behavior must continue through the live `resolveImage()` seam.
- Option changes Red -> Leaf -> ROM must not retain stale meshes or dimensions.

## Acceptance tests

1. Baseline 16x16 ROM player/NPC screenshots are unchanged in all Dramatic Shape modes.
2. FRLG 16x32 walk frames show complete head-to-feet art, grounded on the original cell, in down/up/left/right idle and walk phases.
3. FRLG 32x32 bicycle and Surf frames show complete art centered on the same 16x16 logical footprint.
4. Right-facing mirrors left; alternating up/down steps consume distinct
   authored A/B frames instead of mirroring one frame.
5. Grass occlusion, doors, ledges, y-sort, shadows, ghost/silhouette, map connections, warps, first person, third person, diorama tilt levels, and VR-compatible billboard behavior remain aligned.
6. Collision, player coordinates, movement speed, camera, and map geometry are unchanged.
7. Red -> Leaf -> ROM option changes rebuild/invalidate geometry cleanly.
8. Provider absent, descriptor absent, malformed descriptor, and missing asset all fall back safely.
9. Add focused automated fixtures to `tests/dramatic_shape_test.lua` and produce audit screenshots for walk, bike, Surf, grass, ledge, and at least two camera modes.
10. Build and audit the normal Dramatic Shape release artifact without installing it.

## Version and return artifacts

- Publish a new Dramatic Shape version (expected at least `1.8.1`, subject to owner versioning).
- Return changed files, final schema/API, cache and invalidation rules, tests run, visual audits, version, and release ZIP if that project distributes one.
- The Character Sprite Replacer will set its optional dependency floor to the released compatible version after the contract is finalized.

Do not install the build automatically.
