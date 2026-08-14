# Provider-agent request: HGSS Overworld Sprite API v1

Send this prompt to the agent that owns **HGSS Simple Follower**.

---

You own **HGSS Simple Follower**, manifest ID `hgss_simple_follower`, current
canonical version `0.1.0-alpha.17`. Please add the smallest public art/runtime
contract needed by the separate `kanto_living_encounters` mod.

## Blocked use case

Kanto Living Encounters owns visible wild entity creation, AI, occupancy,
spawn pacing, and contact battles. It must render independent HGSS overworld
Pokémon using the sheets already owned and packaged by HGSS Simple Follower,
without counting those entities as followers or accessing private provider
paths/tables.

## Verified evidence

In alpha 17 `main.lua`, `assetPath`, `proxyPath`, `followerImage`, image caches,
the `FollowerSprite` class, frame mappings, and Dramatic Shape mesh adapter are
all private locals. Public exports are limited to `activeMon`, `select`, `stop`,
`tick`, `monKey`, `spriteSize`, and `restore`. There is no supported way for a
consumer to construct an independent Pokémon overworld renderer. Copying the
302 normal/shiny sheets or reaching into private file paths would violate the
project's provider ownership rule.

## Smallest requested provider-side change

Publish **HGSS Overworld Sprite API v1**:

```lua
mod.exports.overworldSpriteApiVersion = 1

local sprite = mod.exports.createOverworldSprite(monOrSpecies, {
  owner = "kanto_living_encounters",
  role = "wild",
})
```

On success, return a fresh independent renderer compatible with the engine's
NPC `sprite` surface:

```lua
{
  def = {
    id = "SPRITE_HGSS_OVERWORLD_PROVIDER", -- already registered by provider
    image = providerOwnedProxyPath,
    frames = 6,
    walker = true,
    trueColor = true,
    frameWidth = 32,
    frameHeight = 32,
    hgssOverworldSprite = true,
  },
  draw = function(self, px, py, camX, camY, facing, walkPhase, stepFlip) ... end,
  resolveImage = function(self) ... end,
}
```

The returned object must have independent animation/image identity. The
definition ID must already exist in the provider's sprite registry before a
consumer calls `NPC.new`; consumers must not dynamically register or patch the
provider definition. Accept a full Pokémon object so normal/shiny selection
uses the provider's current Shiny System/public flag/native-DV rules. A species
string may be accepted as a normal-art convenience.

Return `nil, reason` for invalid species or unavailable artwork. Do not silently
substitute Charmander for a missing requested species: visible wilds must be
skipped rather than displayed as the wrong Pokémon. Images must remain cached,
nearest-filtered, clamp-wrapped, 32×192, and hot-reload invalidated by the
provider.

Extend the provider-owned Dramatic Shape/Battle Art Voxel mesh seam so objects
whose definition carries `hgssOverworldSprite = true` receive the same centered
32×32, ground-anchored billboard treatment as the party follower. Exactly one
body must render in flat and voxel modes.

Load-order semantics: exports must exist as soon as the provider initializes.
Existing image invalidation must affect future `createOverworldSprite` calls
and already-created renderers must remain safe to draw. The consumer will retry
after `mods.loaded` and map setup.

## Non-goals

- Do not create, move, count, collide, despawn, or battle visible wild entities.
- Do not change follower selection, failover, trail, interaction, or ownership.
- Do not add encounter-table or spawn-density logic.
- Do not add shiny rolls; only resolve art from the supplied Pokémon state.
- Do not make Kanto Living Encounters' entities `hgssSimpleFollower` entities.

## Acceptance tests

1. All 151 normal and shiny species return the correct 32×192 sheet and six
   32×32 frames; invalid species return `nil, reason`.
2. Two renderer instances animate independently and never mutate follower
   state.
3. Full Pokémon objects select shiny art using Shiny System, explicit flags,
   and native shiny DVs as currently required.
4. The registered definition ID is usable by `NPC.new` before the consumer
   assigns the returned renderer.
5. Flat mode and Dramatic Shape/Battle Art Voxel each render exactly one body,
   centered and ground-anchored with nearest filtering.
6. Existing `simple_follower_test.lua` continues to pass, plus a new public-API
   test and a focused normal/shiny/voxel visual audit.
7. Build and audit a flat release ZIP with all existing assets and attribution.

## Version and returned artifacts

Bump HGSS Simple Follower to at least `0.1.0-alpha.18`; update manifest,
README current-build line, source header, tests, and ZIP name together. Kanto
Living Encounters will require
`hgss_simple_follower@>=0.1.0-alpha.18 <0.2.0`.

Return changed files, finalized API semantics, tests run/results, visual audit,
new version, and the flat release ZIP. Do not install it automatically.

---
