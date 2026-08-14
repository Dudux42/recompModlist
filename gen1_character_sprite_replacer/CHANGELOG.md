# Changelog

## 0.1.0-alpha.8 - 2026-08-11

- Restored mapped enemy trainers to the engine's single static draw, removing
  the duplicate introduced by alpha 7's attempted arena lift.
- Added an explicit live ownership handshake with Widescreen so the player
  throw is drawn once rather than in both the arena and final HUD passes.
- Slowed the five throw poses to eight updates each, reduced slide motion to
  two pixels per update, and extended the sendout wait to 40 frames so the
  Pokemon appears only after the smoother animation completes.

## 0.1.0-alpha.7 - 2026-08-11

- Lifted mapped FRLG enemy trainer portraits one source pixel above the battle
  arena plane, preventing Dramatic Shape depth clipping at their lowest row.
- Slowed the five-frame player throw from four to five updates per pose and
  synchronized the opening trainer slide/wait to 25 frames so every pose
  remains visible.

## 0.1.0-alpha.6 - 2026-08-11

- Added an independent `ENEMY TRAINERS` option with `ROM` and
  `GEN 3 (FRLG)` choices.
- Added reviewed 64x64 FRLG portraits for 44 directly mapped Gen 1 enemy
  classes, including all rivals, Gym Leaders, and Elite Four members.
- Preserved ROM portraits for unsupported Professor Oak and Yellow's special
  Jessie/James pair instead of guessing replacements.
- Added five-frame, native-resolution Red and Leaf throwing animations during
  the existing opening player send-out slide in classic and widescreen battle.
- Registered 1x battle scaling for the supplied 64x64 player backs/throw poses.
- Added reproducible trainer extraction, hashes, focused tests, and a visual audit.

## 0.1.0-alpha.5 - 2026-08-11

- Corrected the FRLG source-column interpretation: the sheet is ordered
  `step A | neutral idle | step B`, so idle now comes from the center column.
- Preserved the supplied right-facing row instead of mirroring the left row;
  walk and bicycle sheets now contain twelve poses (four directions x three).
- Updated native and scoped Dramatic Shape pose selection, including internal
  cancellation of Dramatic Shape's legacy right-facing matrix mirror.
- Added an expanded extraction audit that displays every retained pose.

## 0.1.0-alpha.4 - 2026-08-11

- Extracted and packaged the third authored FRLG walk and bicycle pose for
  Red and Leaf; those roles now use nine-pose sheets instead of six-pose sheets.
- Replaced the legacy mirrored two-frame cadence with stand, step A, and
  distinct step B frames in the native 2D renderer.
- Added a player-pose bridge scoped to this mod's role sprites so Dramatic
  Shape consumes the same authored frame without any edit to Dramatic Shape.
- Compensated internally for Dramatic Shape's legacy up/down step mirror while
  preserving right-facing mirroring and all unrelated sprite behavior.
- Added regression coverage and a focused three-frame visual extraction audit.

## 0.1.0-alpha.3 - 2026-08-11

- Added a consumer-side Dramatic Shape 1.8.0 billboard adapter inside this mod; no Dramatic Shape files are edited.
- Scoped interception strictly to `gen1_character_sprite_replacer` Character Appearance API v1 definitions.
- Added authored frame-width/height UV slicing, 16x32 and 32x32 billboard geometry, bottom/center anchors, and shared solid/shadow/ghost meshes.
- Preserved original Dramatic Shape behavior for ROM sprites, NPCs, followers, other mods, invalid descriptors, and missing assets.
- Retained automatic ROM overworld fallback if the adapter cannot be installed.

## 0.1.0-alpha.2 - 2026-08-11

- Fixed corrupted/split overworld rendering when Dramatic Shape voxel mode sampled enhanced FRLG sheets with hardcoded 16x16 UVs.
- Added an active-pipeline compatibility guard: unsupported Dramatic Shape voxel presentation now uses each role's exact ROM renderer instead of emitting partial FRLG frame bands.
- Kept Red/Leaf front/back resolution active for Trainer Card, Hall of Fame, intro, and battle while the overworld safely falls back.
- Preserved enhanced FRLG dimensions in the native 2D overworld path.

## 0.1.0-alpha.1 - 2026-08-11

- Added selectable ROM, FRLG Red (male), and FRLG Leaf (female) appearances.
- Added exact, reproducibly extracted Red/Leaf walk, bike, Surf, front, back, and main-menu assets.
- Added native 2D enhanced-size player rendering with a fixed 16x16 logical footprint and bottom-center anchoring.
- Added live player front/back resolution for intro, Trainer Card, Hall of Fame, and battle.
- Added Character Appearance API v1 and explicit local ROM fallbacks.
- Documented fishing, Surfing Pikachu, Fly, NPC, and trainer exclusions for this first batch.
- Added owner-agent requests for Widescreen main-menu consumption and Dramatic Shape enhanced billboard support.
