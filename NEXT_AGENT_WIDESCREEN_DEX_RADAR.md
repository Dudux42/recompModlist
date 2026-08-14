# Widescreen Dex Radar — Next-Agent Handoff

Last updated: **2026-08-10**

## 1. Objective

Create a widescreen-native Dex Radar inspired by the installed `dex_radar`
1.1.2 mod. It must show the effective spawn table for the current map without
maintaining or reconstructing its own encounter data.

Non-negotiable requirements:

1. Add `DEX RADAR` to the Widescreen UI Start-menu list.
2. Require Gen1 Widescreen UI as a mandatory dependency.
3. Obtain the displayed table exclusively from our spawn mod's read-only API.
4. Never mark Pokemon seen or owned merely by opening the radar.
5. Never own spawning, encounter rolls, visible entities, or table composition.

Working title: **Kanto Dex Radar**  
Provisional manifest ID: `kanto_dex_radar`  
Initial target version: `0.1.0-alpha.1`

Confirm the public name and ID before release. Do not reuse `dex_radar`, which
belongs to the installed reference mod.

## 2. Mandatory references

Read completely before implementation:

- `MASTER_MOD_GUIDE.md`
- `WILDS_OF_KANTO_MOD_DESIGN.md`
- Current Gen1 Widescreen UI source, manifest, Start-menu presenter, exports,
  and tests
- Current spawn-provider implementation and tests when it exists
- Current HGSS Menu Icons and Shiny System contracts
- Installed reference folder:
  `C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\dex_radar`

The installed reference is MIT licensed. Preserve its notice and license if
code or substantial portions are reused. Treat the installed directory as
read-only and build new editable source elsewhere.

## 3. Audited Dex Radar 1.1.2 baseline

Reference manifest:

- ID `dex_radar`, version `1.1.2`, API 2, category `TOOL`, priority 100.
- No dependencies, conflicts, or special permissions.
- MIT license.

Reference behavior:

- Inserts `DEX RADAR` before `SAVE` in the Start menu.
- Opens through an overworld keyboard hotkey, default `R`.
- Reads grass, water, and fishing registries directly.
- Builds ordered unique species with minimum/maximum levels.
- Shows one header and at most three Pokemon rows on a native 160x144 screen.
- Uses party icons under the active game palette.
- Masks unseen species as `?????` silhouettes and hides their levels/rates.
- Marks owned species and shows a unique owned/total counter.
- Scrolls long map labels and shows an empty state for unsupported maps.
- Does not mutate Pokedex state.

Reference options:

| Option | Default |
|---|---|
| SHOW LEVELS | ON |
| SHOW RATES | ON |
| HOTKEY | ON |
| HOTKEY KEY | R |

Reference exports:

```lua
exports.collect(game, mapId?)
exports.speciesOnMap(game, mapId?)
exports.ownedCount(game, mapId?)
exports.isOwnedOnMap(game, mapId?)
exports.isSeen(game, speciesId)
exports.isOwned(game, speciesId)
```

## 4. Corrections required in our version

Do not reproduce these limitations blindly:

1. Direct registry reads create a second source of truth beside our spawn
   provider.
2. The reference's per-species `RATE##` repeats the habitat encounter trigger
   rate; it is not that species' share of the table.
3. Its fishing collector assumes vanilla shapes and misses some provider or
   per-map tables, including layouts used by Yellow Legacy.
4. The UI is hardcoded to 160x144 and only three visible Pokemon.
5. Party-icon decoding and mirroring are duplicated locally.
6. The hotkey polls `love.keyboard` directly instead of an input action.
7. Empty-table completion returns true; the UI should distinguish `0/0` from a
   completed habitat.

Our radar must display what the spawn system says is effective, including
provider ID and revision for diagnostics.

## 5. Dependencies and conflict

Conceptual manifest requirements:

```json
"dependencies": [
  { "id": "gen1_widescreen_ui", "version": ">= REQUIRED_API_VERSION" },
  { "id": "kanto_living_encounters", "version": ">= REQUIRED_API_VERSION" }
],
"conflicts": ["dex_radar"]
```

Use the actual launcher schema after inspecting current manifests.

Both dependencies should be mandatory:

- This screen is authored only for the 640x360 Widescreen presentation.
- Its only table source is our spawn system. A registry fallback would create
  competing interpretations of what can spawn.

If the final spawn-table owner uses a different ID than the provisional
`kanto_living_encounters`, update the dependency before building anything.

## 6. Ownership boundary

The radar owns only:

- Its Widescreen screen, navigation, and Start-menu registration.
- Optional open-radar input action.
- Read-only spawn-snapshot presentation.
- Seen/owned masking and completion calculations.
- Normal menu-icon resolution for table entries.
- Narrow read-only helper exports.

It does not own:

- Spawn tables, provider priority, weights, composition, or invalidation.
- Native random encounters or fishing mechanics.
- Visible wild entities, density, AI, collision, or battle startup.
- Pokedex mutation, shiny state, followers, or battle art.
- Other Widescreen screens or world rendering.
- World geometry, camera, collision, voxels, or Dramatic Shape behavior.

## 7. Required spawn snapshot contract

The radar calls one spawn export and never reads encounter/fishing registries,
Yellow Legacy, or another provider directly:

```lua
exports.getEffectiveSpawnSnapshot(context)
```

Suggested context:

```lua
{
  schemaVersion = 1,
  game = game,
  mapId = "ROUTE_01", -- optional; current map when omitted
  purpose = "radar",
  includeUnavailable = false,
}
```

Suggested result:

```lua
{
  schemaVersion = 1,
  mapId = "ROUTE_01",
  mapLabel = "ROUTE 1",
  area = "route",
  providerId = "yellow_legacy_spawn_tables",
  providerRevision = 4,
  snapshotRevision = 19,
  sections = {
    {
      id = "land",
      title = "LAND",
      entries = {
        {
          species = "PIDGEY",
          weight = 102,
          chance = 0.40,
          minLevel = 2,
          maxLevel = 4,
          surfaces = { "land" },
          behaviorWeights = { idle = 35, moving = 45, aggressive = 20 },
          ambient = false,
          available = true,
          unavailableReason = nil,
        },
      },
    },
  },
}
```

Contract rules:

- `chance` is the normalized share within its effective section, not the
  engine's per-step encounter trigger rate.
- The spawn mod performs validation, filtering, fallback, and normalization.
- Duplicate species aggregation/preservation follows documented spawn semantics;
  the radar does not invent a merge rule.
- The snapshot is immutable from the radar's perspective.
- Unknown schemas fail with a friendly unavailable state.
- Snapshot calls consume no RNG, create no entities, and mutate no Pokedex or
  provider state.
- `snapshotRevision` changes when the effective display table changes.
- Fishing appears only if the spawn API explicitly supplies a `fish` section.
  The radar never reconstructs fishing independently.

## 8. Widescreen UI integration

The radar is a Widescreen extension, not a native-screen fallback.

Required behavior:

1. Register `DEX RADAR` through a public Widescreen Start-menu/screen API or a
   live `ui.start_menu.items` hook consumed by its presenter.
2. Keep the entry present when Widescreen replaces the native Start menu.
3. Draw on the 640x360 virtual surface using Widescreen typography, panels,
   borders, spacing, and input hints.
4. Never expose the native 160x144 screen beneath transitions or overlays.
5. Return to the Widescreen Start menu with selection preserved.

If the required extension API does not exist, add a small public contract to
Widescreen UI, bump Widescreen and the radar dependency floor together, and run
both test suites.

The radar must be listed in Widescreen UI's documented integration list and
screen roadmap.

## 9. Proposed layout and information

Conceptual 640x360 layout:

```text
+------------------------------------------------------------------+
| DEX RADAR     ROUTE 1                    OWNED 5/8   PROVIDER ... |
+-------------------------------+----------------------------------+
| LAND                          | Selected species                  |
| > PIDGEY       Lv 2-4   40%   | 32x32 normal menu icon           |
|   RATTATA      Lv 2-4   35%   | Name / seen / owned              |
|   NIDORAN F    Lv 3-5   15%   | Level range and spawn chance     |
|   NIDORAN M    Lv 3-5   10%   | Behavior tendency / surface      |
| WATER ...                     | Ambient/unavailable status        |
+-------------------------------+----------------------------------+
| UP/DOWN: SELECT  LEFT/RIGHT: SECTION  B: BACK                    |
+------------------------------------------------------------------+
```

This is a wireframe, not permission to hardcode before inspecting shared
Widescreen components.

Minimum information:

- Map label and section/surface.
- Seen-masked species name and icon.
- Owned mark and unique owned/total count.
- Level range when enabled and seen.
- Normalized spawn chance when enabled and seen.
- Provider/revision in an optional details/debug view.

Optional when supplied safely by the snapshot:

- Dominant idle/moving/aggressive behavior.
- Ambient/non-battleable marker.
- Temporary unavailability reason.

Do not reveal hidden progression requirements unless the spawn API explicitly
marks them safe for player display.

## 10. Pokedex privacy

- Opening, refreshing, navigating, and closing never write seen/owned state.
- Unseen species use `?????` and a silhouette/unknown icon.
- Hide levels, chances, behavior, and conditions for unseen species.
- Seen species reveal identity and table data.
- Owned species add the Poke Ball mark.
- Count each species once across sections unless explicitly labeled otherwise.
- Display `NO SPAWN DATA` for `0/0`; do not imply completion.

Do not add a spoiler/reveal-all mode in the first release unless requested.

## 11. Icon and art rules

- Resolve normal species icons dynamically through the live menu-icon resolver.
- HGSS Menu Icons should work automatically when active.
- A table entry is not a Pokemon instance, so it has no shiny art state.
- Never use a battle atlas or Stadium-mode 3D model for list rows.
- Use nearest-neighbor filtering and integer placement.
- Use a stable rest frame or the shared menu animation cadence.
- Do not duplicate PartyMenu icon decoding when a public resolver exists.

## 12. Navigation and refresh

Required entry point:

- `START -> DEX RADAR` in the Widescreen Start-menu list.

Optional entry point:

- Configurable engine input action/hotkey, coordinated with Unified QOL.

Suggested controls:

- Up/Down selects species.
- Left/Right changes section or page.
- A toggles optional detail view.
- B returns to Start.

Refresh rules:

- Request a snapshot on open.
- Refresh on map change, provider invalidation, relevant progress revision, or
  changed `snapshotRevision`.
- Preserve selection by section/species ID when possible.
- Cache decoded icons, not spawn ownership.
- Invalidate icons after art-provider changes.
- Viewing never consumes spawn RNG or changes refill timing.
- Label the table as applying to new spawns; existing visible entities may
  retain an older snapshot by design.

## 13. Public radar exports

Expose a narrow read-only helper API:

```lua
exports.open(game)
exports.currentSnapshot(game, mapId?)
exports.speciesOnMap(game, mapId?)
exports.ownedCount(game, mapId?)
exports.isOwnedOnMap(game, mapId?)
exports.isSeen(game, speciesId)
exports.isOwned(game, speciesId)
```

`currentSnapshot` delegates to the spawn mod. The radar exposes no provider
registration or table mutation. Empty `isOwnedOnMap` results should return a
no-data status instead of the reference mod's ambiguous empty=true result.

## 14. Project compatibility

- **Kanto Living Encounters/spawn provider:** mandatory data dependency and sole
  table resolver. Radar never creates entities.
- **Yellow Legacy:** patches live encounter data; spawn system resolves it and
  radar sees only the effective snapshot. No direct dependency.
- **HGSS Menu Icons:** optional live normal-icon provider.
- **Shiny System:** no shiny roll or art; table rows are not instances.
- **Simple Follower:** no ownership overlap.
- **Battle Art Replacer:** no battle art in rows; any future detail portrait
  must request a stable 2D Widescreen portrait.
- **Unified QOL:** coordinate hotkeys and reuse shared Widescreen components.
- **Dramatic Shape:** UI only; never alter camera, geometry, collision, voxels,
  or battle staging.
- **Installed Dex Radar:** conflict; never enable both.

## 15. Failure handling

- Missing/incompatible mandatory dependency: launcher blocks enablement.
- Snapshot API missing despite dependency: show an incompatible-version message;
  never read registries as fallback.
- Provider error: display the spawn system's safe diagnostic/fallback result.
- Unknown schema: `SPAWN DATA UPDATE REQUIRED`.
- Empty/unsupported table: `NO SPAWN DATA`.
- Missing icon: visible placeholder.
- Unknown species: mask/skip safely and log diagnostics.
- Hotkey collision: disable optional hotkey; Start entry remains.

Never crash the Start menu or expose the native menu beneath Widescreen UI.

## 16. Required tests

Use the exact Lua 5.1 runtime shipped with Gen1 Recomp when possible.

Data and privacy:

- Snapshot schema, provider/revision, normalization, duplicates, and area types.
- Radar never reads encounter/fishing registries directly.
- Radar consumes no RNG and mutates no snapshot/provider/Pokedex state.
- Unseen, seen, owned, unique counts, and no-data behavior.

UI:

- Start-menu presence and ordering.
- Dependency version enforcement.
- 640x360 layout at multiple output sizes/aspect ratios.
- Long labels; zero, one, and many sections/entries.
- Selection preservation after refresh.
- Keyboard/controller navigation and clean B return.
- Optional hotkey only during valid overworld state.
- Nearest-neighbor normal/HGSS icon rendering.
- No native 160x144 flash.

Integration:

- Native spawn fallback.
- Yellow Legacy tables through the spawn system.
- Higher-priority future spawn provider.
- Kanto Living Encounters active while radar opens/closes.
- Widescreen Start/Party/Summary remain intact.
- Unified QOL hotkey coexistence.
- Dramatic Shape world remains unchanged.

Create visual audits for route, cave, water, city, unseen-heavy, fully-owned,
no-data, and long-list screens.

## 17. Implementation sequence

1. Inspect/finalize Widescreen extension and spawn snapshot contracts.
2. Add snapshot export/provider revision/chance tests to the spawn mod.
3. Finalize IDs and dependency floors.
4. Register the Widescreen Start entry and build the 640x360 shell.
5. Add snapshot validation, sections, levels, chances, privacy, and icons.
6. Add revision refresh, selection preservation, optional input action, and
   read-only exports.
7. Run radar, Widescreen, spawn, and integration tests.
8. Render focused visual audits.
9. Bump provider/consumer versions and dependency floors together.
10. Build a flat root-only ZIP in `Releases`; do not install it.

## 18. Required first deliverable from the next agent

Before radar implementation, provide:

1. Current Widescreen Start-menu/screen extension contract.
2. Final spawn snapshot schema with examples for each area type.
3. Exact manifest IDs and dependency version floors.
4. Widescreen component/wireframe plan.
5. Chance normalization and duplicate-entry semantics.
6. Seen/owned privacy and empty-table semantics.
7. Hotkey/input collision policy.
8. Lua 5.1 unit, integration, and visual test plan.

Do not port the native 160x144 draw loop first. Establish shared Widescreen and
spawn contracts, then build the presentation.

## 19. Release checklist

- Mandatory Widescreen and spawn dependencies declared.
- Radar listed in Widescreen integration documentation and Start menu.
- No direct encounter/fishing registry reads.
- Displayed chances match effective provider weights.
- Pokedex remains unchanged by viewing.
- Nearest-neighbor/integer icon placement.
- No world geometry/camera changes.
- Conflict with `dex_radar` declared.
- Required MIT attribution/license included.
- Manifest, README, source header, dependencies, and ZIP version agree.
- Flat ZIP placed in `Releases` and not installed automatically.

