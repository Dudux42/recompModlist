# Wilds of Kanto Mechanics Recreation — Mod Design and Handoff

Last updated: **2026-08-10**

This document defines a focused Gen1 Recomp mod that recreates the visible
overworld Pokémon mechanics associated with Wilds of Kanto while preserving
classic step-based encounters. It is a design specification, not permission to
copy or redistribute the original mod's code or assets.

Working title: **Kanto Living Encounters**  
Provisional manifest ID: `kanto_living_encounters`  
Current target version: `0.1.0-alpha.4`

The final public name and ID must be checked for conflicts before the first
release. Do not reuse `overworld_wild_spawns`, because that ID belongs to Wilds
of Kanto and would make the launcher treat this project as the same mod.

## 1. Product goal

Make wild Pokémon visible and reactive in the overworld without removing the
original Gen 1 encounter loop.

The player should be able to:

- See wild Pokémon occupying valid overworld cells.
- Walk into a visible Pokémon to begin an encounter.
- Continue receiving classic random encounters in grass, caves, and water.
- Find a small number of Pokémon in cities and towns.
- Recognize different behavioral patterns: idle, roam, and aggressive.
- Install a future spawn-control mod that supplies encounter tables without
  replacing this mod's entity, AI, rendering, or battle systems.

The intended result is coexistence, not replacement: visible encounters add
information and life to the world, while grass and other native random
encounters preserve uncertainty and the original game's pacing.

## 2. Ownership boundary

This mod owns only:

- Visible wild entity creation, maintenance, and removal.
- Spawn-cell validation and occupancy.
- Surface and area classification.
- Visible-spawn density and refill timing.
- Idle, roam, and aggressive behavior state machines.
- Contact detection and exactly-once battle startup.
- Resolution of spawn data through the provider contract in section 8.
- A fallback adapter for the game's native encounter tables.
- Optional integration with the shared shiny-state API.

This mod does **not** own:

- Classic random-encounter probability or suppression.
- Party followers or follower selection.
- Map geometry, collision maps, camera, voxels, world scale, or water layout.
- Pokémon battle sprites, menu icons, or UI portraits.
- Catch rates, battle rules, experience, or species data.
- Long-term spawn-table curation once a dedicated provider is installed.

The existing `hgss_simple_follower` mod remains the sole owner of the selected
party follower. A wild entity must never be counted as a follower, and follower
entities must never consume the wild-spawn quota.

## 3. Non-negotiable behavior

### 3.1 Classic encounters remain available

The mod must not suppress or replace the engine's native random-encounter roll.
Grass encounters remain enabled by default and operate independently of visible
spawns. The same rule applies to native cave and water encounter rolls.

The implementation must not hook `encounter.roll` merely to return false. If a
diagnostic hook is needed, it must pass the original result through unchanged.

Turning visible spawns off must leave classic encounters completely unchanged.
Failure to initialize visible spawns must also fall back to an untouched native
encounter system.

### 3.2 One visible entity, one battle

A visible Pokémon can begin a battle only once. Its lifecycle is:

```text
SPAWNING -> AVAILABLE -> ENCOUNTER_STARTING -> IN_BATTLE -> REMOVED
```

Collision, tile-step, and behavior updates may all observe contact, but only an
atomic transition from `AVAILABLE` to `ENCOUNTER_STARTING` may queue a battle.
The entity must be removed from occupancy and rendering before the battle is
queued. A failed queue must not generate duplicate battles.

### 3.3 No world mutation

Spawn eligibility reads map geometry but never edits it. Wild Pokémon use
existing walkable/water cells and the engine's normal collision rules. The mod
must not teleport the player, carve paths, alter collision, or change Dramatic
Shape geometry.

### 3.4 Deterministic safety before visual richness

If a sprite is missing, use a documented fallback or skip that spawn. Never
create an invisible battle collider. If surface classification, encounter data,
or rendering is unavailable, preserve classic encounters and report a concise
diagnostic instead of partially taking ownership.

## 4. Area classes and density

Every map is classified into one primary area class for visible-spawn density:

| Area class | Typical maps | Amount option target |
|---|---|---:|
| Route | Routes, forests, outdoor wild areas | Few 2–4; Regular 5–8; Many 9–12 |
| Cave | Caves, towers, indoor encounter maps | Few 2–4; Regular 5–8; Many 9–12 |
| Water | Surfable water regions | Few 2–4; Regular 5–8; Many 9–12 |
| Town | Cities and towns | Few 2–4; Regular 5–8; Many 9–12 |
| Unsupported | Buildings and maps with no safe source | 0 |

The selected range is a target, not permission to weaken safety validation.
Small, crowded, or disconnected maps may show fewer Pokémon when they do not
contain enough safe cells. A minimum must never force a spawn onto an invalid
cell.

### 4.1 City and town rules

Town Pokémon are visible flavor entities, not a new step-based town
encounter system. The mod must not invent random encounter rolls on pavement.

Town Pokémon are cosmetic unless their selected behavior is `aggressive`.
All town Pokémon can be interacted with: they face the player and play their
species cry, and that interaction never starts a battle. Idle and roaming town
Pokémon never initiate a battle even on same-tile contact. Aggressive town
Pokémon may notice and rush the player and are the only catchable town spawns.

Valid city cells must:

- Be outdoors and walkable.
- Avoid doors, warps, scripted trigger cells, signs, ledges, and map exits.
- Avoid NPCs, the player, the follower, and other visible wilds.
- Maintain at least three cells of initial distance from the player.
- Prefer edges, vegetation, water borders, and open plazas over doorways.

If a city lacks its own table, the native fallback may derive a conservative
pool from explicitly configured neighboring routes. It must not guess neighbors
from map-name strings alone. If no explicit adjacency data exists, spawn zero
city Pokémon until a provider supplies a table.

This conservative fallback is important: borrowing species from an arbitrary
route can create ecologically wrong encounters and progression leaks.

### 4.2 Route rules

Route land spawns prefer valid encounter grass and connected walkable regions.
They may wander out of a grass cell only when the resolved table entry and map
policy allow it. They must not cross warps, ledges, solid tiles, or region
boundaries.

### 4.3 Cave rules

Cave spawns use the map's cave/indoor encounter table, which may be stored in
the engine's grass-table format. Only reachable walkable cells are eligible by
default. Decorative but unreachable cave platforms are excluded.

### 4.4 Water rules

Water spawns use water encounter data and valid connected water cells. They may
idle, move, or chase within water, but may not cross onto land unless a future
explicit amphibious movement contract is introduced. That feature is outside
the initial release.

## 5. Spawn lifecycle and pacing

On map entry:

1. Classify the area and collect safe eligible cells.
2. Resolve the effective spawn table through section 8.
3. Compute connected regions and per-region quotas.
4. Fill the selected safe target on map entry.
5. Refill gradually as entities expire or battles refresh the map.

Recommended pacing defaults:

- Refill check: every 8 player steps.
- Maximum new entities per refill: 1 in cities, 2 elsewhere.
- Minimum player distance at spawn: 3 cells.
- Minimum separation between wilds: 3 cells.
- Ordinary lifetime: 90 seconds.
- Despawn distance: approximately 22 cells, bounded by map dimensions.
- Never despawn an aggressive Pokémon during an active chase.
- Shiny Pokémon ignore lifetime and distance despawning and persist until
  encounter or map exit.
- Entering a battle clears ordinary visible spawns and allows a fresh refill
  after battle; unrelated shiny entities remain on that map.

The entity must store a resolved encounter snapshot:

```lua
{
  id = "map-id:serial",
  mapId = "...",
  species = 25,
  level = 8,
  shiny = false,
  surface = "route",
  behavior = "roam",
  battleable = true,
  sourceProvider = "native",
  sourceRevision = 1,
  state = "AVAILABLE",
}
```

Changing a provider table must affect new spawns. Existing entities retain
their snapshot until encounter or despawn; changing their species in place
would make the visible sprite disagree with the battle result.

## 6. Behavior model

The public behavior vocabulary is deliberately small:

| Behavior | Player-visible pattern |
|---|---|
| `idle` | Stays mostly in place and occasionally takes one random legal step. |
| `roam` | Wanders through a bounded connected region with pauses. |
| `aggressive` | Detects the player, signals, then chases to initiate contact. |

Behavior selection is data-driven per table entry. A table can provide weights
instead of forcing every member of a species to act identically:

```lua
behaviorWeights = {
  idle = 50,
  roam = 35,
  aggressive = 15,
}
```

This allows a species to have a recognizable tendency while retaining natural
variation. When no weights are supplied, use area defaults:

| Area | Idle | Roam | Aggressive |
|---|---:|---:|---:|
| Route | 39.375 | 50.625 | 10 |
| Cave | 39.375 | 50.625 | 10 |
| Water | 39.375 | 50.625 | 10 |
| Requested dungeon | 39.375 | 50.625 | 10 |
| Town | 41.5625 | 53.4375 | 5 |

Each area's non-aggressive probability is distributed across Idle and Roam in
the original 35:45 ratio. Disabling aggressive Pokémon renormalizes the
remaining weights.

### 6.1 Idle

- Usually remains on its reserved cell.
- Every 5–10 seconds, attempts one random legal adjacent step; if none exists,
  it may only change facing.
- May play a short idle animation or cry subject to cooldown.
- Does not path toward the player.
- Contact begins a battle outside towns; in towns, only aggressive entities are
  battleable.

### 6.2 Roam

- Chooses a reachable destination within its home connected region.
- Moves one grid cell at a time using atomic occupancy reservations.
- Pauses between short movement bursts.
- Never enters a warp, occupied cell, forbidden surface, or scripted trigger.
- Pauses when no legal move is available.
- Does not chase the player.

### 6.3 Aggressive

Recommended state machine:

```text
UNAWARE -> ALERT_DELAY -> CHASING -> SEARCHING -> RETURNING
                    \-> ENCOUNTER_STARTING
```

- Detects the player within a default four-cell sight radius.
- Requires compatible region/surface reachability, not distance alone.
- Creating any aggressive spawn starts a shared 30-second grace period.
  Unengaged aggressive Pokémon remain still and cannot detect the player until
  it expires, preventing multiple newly populated entities from chain-rushing.
  The player can still deliberately initiate same-cell contact during grace.
- Shows a brief alert before moving.
- Repaths one cell at a time and respects normal occupancy.
- Starts a battle on contact through the single lifecycle gate.
- Searches briefly after losing a path or sight.
- Returns toward its home region or becomes roaming when the chase ends.
- Never steps through walls, warps, NPCs, followers, or other wild entities.

Line-of-sight may be introduced after the basic reachable-radius version is
stable. A superficially smarter ray cast is not useful if it disagrees with
the engine's actual movement graph.

### 6.4 Species-specific patterns

Species tendencies should live in data, not in AI code. The initial fallback
may define a small set of audited profiles such as `timid`, `calm`, `roaming`,
and `territorial`, then assign species to profiles. The future spawn provider
may override the behavior weights per map and entry.

Do not infer aggression from battle stats alone. High Attack does not establish
overworld temperament, and hidden heuristics would be difficult for a table mod
to predict or override.

## 7. Encounter-table model

The effective table returned to the spawn system uses a normalized structure:

```lua
{
  schemaVersion = 1,
  mapId = "ROUTE_01",
  area = "route",
  revision = 4,
  entries = {
    {
      species = 19,
      weight = 102,
      minLevel = 2,
      maxLevel = 4,
      surfaces = { "land" },
      behaviorWeights = {
        idle = 35,
        roam = 50,
        aggressive = 15,
      },
      battleable = true,
    },
  },
}
```

Rules:

- `species` is required and must resolve to a valid game species.
- `weight` must be a positive finite number.
- Levels must be valid integers with `minLevel <= maxLevel`.
- Unsupported surfaces are rejected rather than silently remapped.
- Unknown fields are ignored for forward compatibility.
- Invalid entries are skipped with diagnostics; an entirely invalid provider
  result falls back to the next provider or the native adapter.
- The native fallback preserves the game's slot weights and level data.
- Visible and classic encounters may draw from the same native table, but they
  perform independent rolls.

## 8. Future spawn-controller hook

The future spawn-control mod supplies data. It must not create entities, hook
collision, start battles, or suppress classic encounters through this API.

### 8.1 Registration exports

The visible-spawn mod should export:

```lua
exports.registerSpawnProvider(providerId, priority, resolver)
exports.unregisterSpawnProvider(providerId)
exports.invalidateSpawnTables(reason)
exports.resolveSpawnTable(context)       -- diagnostic/public normalized result
exports.getSpawnProviderStatus()         -- provider IDs, priority, last error
exports.getEffectiveSpawnSnapshot(context) -- immutable UI/diagnostic snapshot
```

Contract:

- `providerId` is a stable unique string.
- Higher numeric `priority` resolves first.
- Duplicate IDs replace only the previous registration with the same ID.
- `resolver(context)` returns `nil` when it does not own that context.
- A valid returned table is authoritative for that context.
- Provider errors are isolated with `pcall`; the next provider is tried.
- The built-in native adapter always has the lowest priority.
- Registration must work regardless of mod load order.

To handle load order, the future provider should attempt registration on load
and again on a public `world.loaded` or mod-ready event. This mod should emit:

```lua
mod.events:emit("kanto_living_encounters.provider_api_ready", {
  schemaVersion = 1,
})
```

The exact engine event facility must be verified during implementation. Do not
invent an event API if Gen1 Recomp exposes registration only through exports;
in that case, provide a documented retry function instead.

`getEffectiveSpawnSnapshot(context)` is the required read-only contract for the
dependent Widescreen Dex Radar. It returns the already validated effective
provider result grouped into display sections, including normalized per-entry
chance, level range, surfaces, battleable/behavior metadata, provider ID and
revision, and a snapshot revision. It must not consume RNG, create entities,
mutate provider tables, or mark Pokedex state. The radar must never bypass this
export to read native encounter or fishing registries directly.

### 8.2 Resolver context

```lua
{
  schemaVersion = 1,
  gameVersion = "...",
  gameEdition = "red",       -- red | blue | yellow
  mapId = "ROUTE_01",
  area = "route",            -- route | cave | water | city
  encounterKind = "grass",   -- grass | water | city
  playerProgress = {
    badges = 0,
    flags = {},               -- read-only snapshot or documented query facade
  },
  nativeTable = { ... },      -- normalized copy; never mutable engine data
}
```

The provider must treat the context as read-only. The visible-spawn mod should
cache resolutions by provider, map, edition, relevant progress revision, and
provider revision. Cache invalidation occurs on map entry, save load, provider
registration/removal, explicit invalidation, and documented progression events.

### 8.3 Provider result and future evolution

Version 1 uses full replacement for the selected context. Avoid implicit merge
semantics in the first release: merging weighted tables from multiple owners is
ambiguous and makes rarity difficult to reason about.

A future schema may add explicit operations such as `replace`, `append`, or
`remove`, but that requires a schema-version bump and deterministic composition
rules. Unknown schema versions must be rejected cleanly.

### 8.4 Example provider

```lua
local function resolveKantoTable(ctx)
  if ctx.area == "city" and ctx.mapId == "VIRIDIAN_CITY" then
    return {
      schemaVersion = 1,
      mapId = ctx.mapId,
      area = ctx.area,
      revision = 1,
      entries = {
        {
          species = 19,
          weight = 70,
          minLevel = 2,
          maxLevel = 3,
          surfaces = { "land" },
          behaviorWeights = { idle = 60, roam = 35, aggressive = 5 },
        },
        {
          species = 16,
          weight = 30,
          minLevel = 2,
          maxLevel = 3,
          surfaces = { "land" },
          behaviorWeights = { idle = 45, roam = 55, aggressive = 0 },
        },
      },
    }
  end
  return nil
end

wildsExports.registerSpawnProvider(
  "future_spawn_controller",
  100,
  resolveKantoTable
)
```

## 9. Rendering and art integration

- Use nearest-neighbor filtering and integer placement for pixel art.
- Use native world entities/billboards where possible so Dramatic Shape owns
  depth, occlusion, grass, and shadows.
- Never draw a second Pokémon body over a successful voxel billboard.
- Keep sprite image identity stable for the lifetime of an entity.
- Wild sprites must not come from `hgss_menu_icons`; menu sheets have a
  different purpose and frame contract.
- Resolve overworld sprite assets through HGSS Simple Follower's public
  Overworld Sprite API. Do not copy its sheets or access private paths.

HGSS Simple Follower is the required art provider but remains the sole owner of
the selected party follower. Every wild entity receives an independent sprite
renderer and never carries the follower ownership tag or consumes its slot.

Gen1 Shiny System is required and exclusively owns each shiny roll, valid DVs,
state, colors, and presentation. Visible creation reserves one provider outcome
and the later contact battle must consume that exact outcome without rerolling.

## 10. Suggested options

Keep the first public option surface small:

| Option | Values | Default |
|---|---|---|
| Visible Pokémon | On / Off | On |
| Aggressive Pokémon | Yes / No | Yes |
| Amount | Few (2–4) / Regular (5–8) / Many (9–12) | Regular |
| Town Pokémon | On / Off | On |
| Debug Overlay | On / Off | Off |

There is intentionally no `Random Encounters` option in this mod. Native
encounters stay available, and a visible-spawn mod should not become the owner
of the base game's encounter toggle.

There are no independent Idle/Roam toggles in the initial build. The single
aggressive toggle removes aggressive selection and renormalizes Idle/Roam.

## 11. Compatibility rules

- **Wilds of Kanto:** conflict. Both mods own visible wild entities, AI,
  collision, and encounter startup. They must not be enabled together.
- **HGSS Simple Follower:** required art provider through Overworld Sprite API
  v1. Follower entity tags, selection, occupancy, and ownership remain separate.
- **Gen1 Shiny System:** required through Wild Outcome API v1 so overworld and
  battle shiny state cannot diverge.
- **Gen1 Balances:** optional. This mod reads the engine's effective live
  encounter registry, so Balances wins automatically when installed and
  vanilla data is used otherwise.
- **Dramatic Shape:** compatible through native world billboard contracts; no
  geometry or camera changes.
- **Spawn-control mod:** optional provider only, using section 8.
- **Mods changing native encounter tables:** compatible by default because the
  native adapter resolves the live table at map entry rather than caching a
  bundled copy.

The manifest must declare a conflict with the actual Wilds of Kanto manifest ID
`overworld_wild_spawns`. Optional integrations must not become mandatory
dependencies unless a future implementation truly cannot operate without them.

## 12. Failure handling

The system must fail open toward vanilla behavior:

- Provider missing: use the live native table.
- Provider returns `nil`: try the next provider, then native.
- Provider throws or returns invalid data: record the error and fall back.
- No valid table: spawn no visible Pokémon on that map.
- No eligible cells: spawn none; do not relax into warps or collisions.
- Renderer unavailable: remove/skip the entity; never leave an invisible
  collider.
- Battle queue failure: clear pending ownership safely and leave native random
  encounters intact.

Debug output should identify the chosen provider, table revision, area class,
eligible-cell count, target count, active entities, and last rejection reason.

## 13. Testing requirements

Use the exact Lua 5.1 runtime shipped with Gen1 Recomp when possible.

Minimum unit and integration coverage:

1. Native grass encounters are never suppressed with visible spawns on or off.
2. Route, cave, water, city, and unsupported maps classify correctly.
3. City target and cap remain below every supported wild-area class at all
   public density settings.
4. Invalid cells, warps, triggers, NPCs, followers, and occupied cells are
   rejected.
5. Idle Pokémon never path toward the player.
6. Moving Pokémon stay inside their connected home region.
7. Aggressive Pokémon respect collision and begin exactly one battle.
8. Town interaction faces the Pokémon toward the player and plays its cry
   without starting a battle. Idle and roaming town entities never initiate a
   battle; aggressive town entities may do so through proximity/contact.
9. Provider priority, `nil`, errors, invalid schemas, replacement, and
   unregister behavior work deterministically.
10. Provider changes affect new entities without mutating existing snapshots.
11. The native adapter reads live encounter data modified by another mod.
12. Missing art never leaves an invisible collider.
13. Wild entities remain separate from `hgss_simple_follower` ownership.
14. Shiny state supports explicit flags and native DV state when integrated.
15. Flat and Dramatic Shape rendering each show exactly one Pokémon body.

Manual tests must cover at least:

- One long route.
- One small route.
- One cave with disconnected scenery.
- One surf area.
- Two cities of different sizes.
- A city with no provider table.
- Map transitions during a chase.
- Save load and option changes.
- A contact occurring on the same update as a movement step.
- Coexistence with classic grass encounters over an extended play session.

## 14. Implementation sequence

1. Create manifest, options, module layout, and Lua 5.1 test harness.
2. Implement lifecycle, occupancy, map cleanup, and exactly-once battles.
3. Implement native table normalization and provider registry.
4. Implement surface/area classification and safe-cell collection.
5. Implement density, connected regions, initial spawning, refill, and despawn.
6. Implement idle, roam, and aggressive state machines.
7. Add sparse city spawning and explicit adjacency fallback data.
8. Add native/voxel-safe rendering and focused visual audits.
9. Add optional shiny integration without follower ownership.
10. Run all affected integration tests and package a flat release ZIP.

## 15. Release checklist

- Read `MASTER_MOD_GUIDE.md` before implementation and packaging.
- Confirm the final manifest ID and conflict declarations.
- Verify classic encounters remain active.
- Run this mod's tests plus follower and shiny integration tests.
- Visually inspect flat and Dramatic Shape rendering.
- Audit provider fallback and city density on real maps.
- Include attribution and licenses for every reused code or art source.
- Update manifest, README, source header, and ZIP filename together.
- Build a flat/root-only ZIP with no nested paths or duplicate entries.
- Put the ZIP in `Releases`.
- Do not install the build automatically.

## 16. Open decisions before implementation

These decisions require engine inspection or user playtesting rather than an
unsupported assumption:

1. Final public name and manifest ID.
2. Final provider implementations for HGSS Overworld Sprite API v1 and Gen1
   Shiny Wild Outcome API v1.
3. Which city cells can be recognized semantically without hardcoded map data.
4. The curated city adjacency list and initial city species tables.
5. Real-map validation of scripted trigger cells that cannot be identified
   semantically from public map surfaces.
6. Whether visible contact encounters should influence repels; classic random
   repel behavior must remain unchanged regardless.

Town interaction behavior is now decided: every town Pokémon faces the player
and cries when interacted with, without starting a battle from that action.
Only aggressive town Pokémon are battleable through proximity/contact; idle
and roaming town Pokémon remain cosmetic.
