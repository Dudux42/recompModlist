# Dramatic Shape Battle Sprite Lighting Patch

Current build: **0.2.0**

This is an independent compatibility mod for **Dramatic Shape Voxel Mod
1.8.x**. It keeps flat Pokemon battle sprites at the same source colors shown
in menus and prevents diagonal light/dark bands at certain camera angles.

This project is not affiliated with or an official release of Dramatic Shape.
It does not redistribute or modify Dramatic Shape's files.

## Why battle sprites were darker than menu sprites

The Battle Art Replacer supplies the same true-color image to both surfaces.
Widescreen menus draw it with a neutral white multiplier. Dramatic Shape puts
the battle image on a quad inside its 3D scene, whose shader multiplies every
pixel by `dayTint` and shadow-map lighting. The source PNG is therefore
correct; the difference is introduced during the arena draw.

## What caused the shadow artifact?

Dramatic Shape places each 2D Pokemon picture on a paper-thin quad inside its
3D arena. The quad is submitted to the shadow map so its alpha silhouette can
cast a correctly shaped shadow onto the floor. During the lit arena pass, the
same quad also samples that shadow map.

A zero-thickness surface can then compare against its own recorded depth.
Finite shadow-map resolution, filtering, camera-relative billboard rotation,
and depth bias sometimes make adjacent fragments disagree about whether they
are lit. The result is diagonal moire-like self-shadow banding. The Pokemon
PNG and its shiny palette are not corrupt; higher-contrast colors merely make
the lighting error easier to see.

## What the patch changes

The patch uses Dramatic Shape's exported companion-module namespace and wraps
its `Voxel3D.draw` function. It identifies the exact mesh returned by
`BattleBillboard.mesh()` and temporarily sets the active scene shader's
`sunDark` value to zero and `dayTint` to neutral white only while that mesh is
drawn. Both uniforms are restored immediately afterward.

This separation is important:

- Pokemon cards no longer **receive** shadow-map lighting, eliminating their
  self-shadow bands.
- Pokemon cards no longer receive the scene's time-of-day color multiplier,
  so their pixels match the same art in Party, Summary, and other menus.
- Pokemon still **cast** their alpha-cutout silhouettes onto the arena because
  Dramatic Shape performs that work through the separate `ShadowMap.draw`
  path.
- Terrain, buildings, overworld characters, water, Stadium models, the arena
  camera, depth testing, sprite animation, and global shadow bias are not
  changed.
- Time-of-day tinting remains active on the arena and every other world
  surface. Battle hit flashes and sprite animation remain active.

The tradeoff is that a world object cannot cast a shadow across the surface of
a flat Pokemon card. In a staged battle view this is substantially less
visible than unstable self-shadow stripes, and it avoids weakening shadows or
creating detached shadows everywhere else in the world.

## Compatibility and safety

- Supported consumer: Dramatic Shape `>=1.8.0 <1.9.0`.
- The manifest declares Dramatic Shape as a dependency and loads this patch at
  a higher priority.
- Runtime module and version checks fail closed: if the expected 1.8.x surface
  is missing, the patch logs a warning and changes nothing.
- Installation is idempotent across a normal hot reload; the patch replaces
  its own earlier wrapper rather than stacking wrappers.
- No options or save data are added.

Future Dramatic Shape versions may change this renderer or fix the issue
upstream. The version guard intentionally refuses to patch 1.9.x or later
until that version is inspected.

## Installation

1. Install and enable Dramatic Shape 1.8.x.
2. Place the release ZIP in the same Gen1Recomp mod location used for other
   content mods, or install the unpacked folder during development.
3. Enable **Dramatic Shape Battle Sprite Lighting Patch**.
4. Keep Dramatic Shape's `SHADOWS` setting enabled and enter a battle.

To confirm the fix, compare a Pokemon in Party/Summary with the same art in an
arena battle, then orbit the battle camera through an angle that previously
produced diagonal bands. Its source colors should match the menu and remain
clean while its cast shadow continues to appear on the arena floor.

## Removal

Disable or remove this companion mod. It makes no persistent changes, so no
save migration or cleanup is necessary.
