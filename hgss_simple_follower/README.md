# HGSS Simple Follower

Current build: **0.1.0-alpha.18**

This standalone mod does one job: it lets one healthy party Pokemon follow the
player using the supplied 32x32 Pokemon HeartGold/SoulSilver overworld art.
The native art is presented on a 32px visual card so followers match
the player's apparent size without changing collision or map geometry.
New builds replace older wrappers in both Dramatic Shape and Battle Art Voxel
Fork during a live mod reload, so the active overworld pipeline receives the
same centered 32px card.
The Gen1 Shiny System directly selects the matching HGSS shiny overworld
palette and supplies its lightweight sparkle effect. Without that mod, Gen 2
shiny DVs and the compatibility `mon.shiny` flag still work automatically.
Every normal and shiny animation frame is grounded inside its transparent
32x32 canvas, placing its lowest opaque pixel on the card's foot baseline.
The release ZIP is flat so the launcher never recursively copies asset trees.

## HGSS Overworld Sprite API v1

Alpha 18 publishes the provider-owned art/runtime contract used by independent
overworld systems such as Kanto Living Encounters:

```lua
assert(follower.exports.overworldSpriteApiVersion == 1)

local sprite, reason = follower.exports.createOverworldSprite(monOrSpecies, {
  owner = "kanto_living_encounters",
  role = "wild",
})
```

`monOrSpecies` may be a full Pokemon object or a Gen 1 species string. Full
objects select normal/shiny art through Gen1 Shiny System when available, then
the explicit `mon.shiny` flag and native Gen 2 DV rule. A species string is a
normal-art convenience. `options.owner` is required and `options.role`
defaults to `overworld`.

Each successful call returns a fresh independent NPC-compatible renderer with
six 32x32 frames, a stable 32x192 nearest-filtered/clamp-wrapped image, and a
definition carrying `hgssOverworldSprite = true`. The already-registered
definition ID is also published as `overworldSpriteDefinitionId`; consumers
may pass it to `NPC.new` before assigning the returned renderer. Invalid Gen 1
species, unavailable artwork, bad dimensions, or invalid options return
`nil, reason`. Missing art never substitutes another Pokemon.

The provider shares decoded image objects through its cache, while renderer
tables, definitions and frame quads remain independent. Asset reload clears
future resolution caches; renderers already in the world retain a safe image
reference. Dramatic Shape and Battle Art Voxel Fork recognize the public
definition marker and apply the same centered, ground-anchored 32px billboard
seam as the party follower.

This API supplies appearance only. It never creates, moves, counts, collides,
despawns, rolls, or battles wild entities, and it never adds the
`hgssSimpleFollower` ownership tag to consumer objects.

## Party menu

Open `POKEMON`, select a healthy party member, and choose `FOLLOW`.
Select the current follower again and choose `STOP FOLLOWING` to dismiss it.

If the follower faints or leaves the party, the mod selects the first healthy
party Pokemon from slot 1 downward. If the whole party is fainted, the follower
is hidden until a healthy party member is available.

## Compatibility and setup

- No mandatory mod dependencies.
- Red, Blue, and Yellow are supported.
- Dramatic Shape and Battle Art Voxel Fork are optional. Both receive a
  centered 32px billboard. A matching 16x96 UV proxy prevents partial-frame
  fragments if either stock path is used.
- Disable/uninstall `PokePCFollowers_VoxelMerge`, `FOLLOWERS_EX`, and the older
  `HGSS Overworld Sprite Pack`; they own overlapping follower or sprite paths.
- Wilds of Kanto may stay enabled, but set its `Followers` count to `0` while
  using this version. Wild encounter behavior is otherwise untouched.
- Shiny followers are detected through the game's `Stats.isShiny` rule; the
  separate Shiny Pokemon mod may still control encounters, sparkles and battle
  presentation, but is not required for the follower's shiny colors.

The follower is hidden while biking, surfing, or fishing and returns afterward.
It is passable and does not change map collision or world geometry.
When both characters are standing, the follower turns with the player so the
directional HGSS poses remain visually coherent.
On an area transition, the follower uses only the tile directly behind the
player. Doorway and map-edge collision does not suppress it because the
follower entity is passable. Seamless map connections are synchronized after
the engine rebases the player into the cross-map step, including temporary
coordinates just outside the destination map. It never substitutes a side or
front tile. In the flat renderer, its 32px card is ordered behind the trainer.

## Artwork credit

Pokemon HeartGold/SoulSilver Gen 1 overworld sheet ripped by **Dragoon** for
**The Spriters Resource**. The supplied sheet requests credit.

The alternate shiny palettes were decoded from the user's own US HeartGold ROM
(`/a/0/8/1`, palette `tsure_poke1`) and converted to six-frame PNG sheets by
the included local extraction tool. Because HGSS inserts forms into this
archive, each species is matched against the supplied normal sprite silhouette
rather than assumed to occupy a simple National-Dex offset. The ROM itself is
not included.

The publish audit verifies 151 unique archive entries, all 906 normal/shiny
frame pairs, six non-empty frames per sheet, identical paired silhouettes and
a grounded row-31 foot baseline. `assets/follower_audit_contact_sheet.png`
provides the corresponding visual National-Dex review.

Pokemon and Pokemon HeartGold/SoulSilver are properties of Nintendo, Game
Freak, and The Pokemon Company. This is a non-commercial compatibility mod.
