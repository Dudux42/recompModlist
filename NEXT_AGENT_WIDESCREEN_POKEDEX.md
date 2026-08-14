# Next Agent Brief — Widescreen Pokédex

Last updated: **2026-08-10**

## 1. Mission

Create a new Pokédex mod for Invoker's Gen1 Recomp compilation with a
master/detail layout modeled after our Widescreen Pokémon menu:

- **Left panel:** scrollable Pokédex-numbered species list.
- **Right panel:** selected Pokémon's live 2D sprite and Pokédex entry.
- **A on a known species:** open a submenu containing exactly:
  **HABITAT, STATS, LEARNSET, EVOLUTION, CRY**.

The project is a read-only research interface. It must not alter Pokédex flags,
species data, encounters, learnsets, evolutions, cries, saves or ROM data.

Working title: **Widescreen Pokédex**  
Provisional manifest ID: `gen1_widescreen_pokedex`

Gen1 Widescreen UI is a mandatory dependency and the sole presenter. Do not
reuse the installed reference ID `pokedex_plus`.

Read `MASTER_MOD_GUIDE.md` and all overlapping design documents before coding,
especially Yellow Legacy, Wilds of Kanto, Widescreen Dex Radar, Battle Art
Replacer and Widescreen Modern Bag.

## 2. Reference material audited

### Native engine

Read-only files:

- `src/ui/PokedexMenu.lua`
- `src/ui/DexEntryMenu.lua`

Native behavior worth preserving:

- Species are ordered by Pokédex number.
- Unseen species show a hidden name and cannot be opened.
- Seen and owned counts are tracked separately.
- Owned entries use the Poké Ball marker.
- The native entry reads `def.dexEntry` and resolved text from
  `game.data.text`.
- The native sprite resolves through `Sprites.path(..., "front",
  { kind = "dex" })`.
- The native Cry action calls `src.core.Sound.playCry(game.data, species)`.
- The Yellow Game Boy Printer action is a native special feature, but it is not
  part of the user-requested submenu and is outside this first mod's scope.

### Installed Pokédex Plus 1.3.4

Read-only path:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\pokedex_plus`

Audited:

- `manifest.json`
- `main.lua`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`
- Existing tests and exports

Useful reference behavior:

- Reads merged species, encounter, stat, learnset and evolution data.
- Supports mod-added species and regional-style display-number suffixes.
- Scans party/boxes to repair stale caught display state without mutating it.
- Builds Habitat rows with method, levels, time/conditions and chances.
- Uses evolution-method describers when available.
- Shows base stats and total.
- Provides name/type search and an optional reveal-unseen mode.
- Publishes optional Gen1 Modern UI API v1 semantic adapters.

Differences for our project:

- Widescreen is mandatory, not optional.
- No native 160×144 fallback.
- The main screen itself permanently shows sprite plus Pokédex entry.
- A opens only the requested five-option submenu.
- Search, Area Map, DATA, printer and reveal-unseen options are not first-release
  requirements unless the user later requests them.
- Habitat must respect our effective spawn-provider ownership instead of
  maintaining a second competing encounter truth.

Pokédex Plus is MIT-licensed. If its code is copied or substantially reused,
retain its copyright notice and full permission text.

## 3. Ownership boundary

This mod owns:

- Pokédex list/navigation state.
- Read-only seen/owned presentation.
- Construction of immutable species/detail/subscreen models.
- Habitat query/adaptation.
- Base-stat, learnset, TM and evolution read models.
- The callback that requests a cry through the engine.

Widescreen UI owns:

- The 640×360 layout and all drawing.
- Left/right panels, list rows, selection, scrolling and focus.
- Sprite placement, clipping and visual fallback.
- Submenu, Habitat, Stats, Learnset and Evolution presentation.
- Controller, keyboard and pointer/touch hit regions.
- Typography, type badges, stat bars, headers, footers and modal placement.

Other systems retain ownership:

- Engine/save owns seen and owned flags.
- Effective species-data mods own stats, learnsets, compatibility and
  evolutions.
- Spawn/encounter providers own effective habitats.
- Widescreen/Battle Art resolvers own selected 2D portrait art.
- Engine and cry/audio mods own cry resolution and playback.

Do not patch world geometry, encounter rolls, sprites, audio definitions or
Pokédex progression.

## 4. Main screen

### 4.1 Left species panel

Build the list from every valid record in merged `game.data.pokemon` that has a
usable unique internal Pokédex identity.

Each row should expose:

- Display number.
- Variant suffix when provided by verified metadata.
- Species name or hidden placeholder.
- Seen state.
- Owned/caught state.
- Stable species ID.
- Optional live menu-icon descriptor when known and permitted by privacy.

Sort deterministically by:

1. Display Pokédex number.
2. Variant order/suffix.
3. Unique internal number.
4. Species ID.

Support the installed-reference convention only when those fields exist:

- `dexDisplay`
- `dexVariant`
- `dexVariantOrder`

Do not assign duplicate internal dex numbers or mutate species definitions to
create visual variants.

All list navigation must support key repeat, controller/keyboard input,
pointer/touch selection and a stable selected species when the data revision
changes. Show SEEN and OWN totals without crowding the list.

### 4.2 Right detail panel

For the selected permitted species, show:

- Large live 2D front sprite.
- Display Pokédex number and species name.
- Pokédex classification/kind when available.
- Pokédex entry text.
- Seen/owned marker as useful context.

Height and weight may be shown if space allows and the native ownership/privacy
rule permits them, but they must not displace the requested sprite or entry.

Entry text requirements:

- Resolve the active species definition's `dexEntry`.
- Resolve its text ID through the active merged text registry.
- Honor the current game version's entry.
- Normalize engine control codes (`\v`, `\f`, explicit newlines) for the
  Widescreen text component without changing the underlying string.
- Wrap by rendered width, not raw character count.
- Never clip or silently discard the final lines; use a bounded scroll region
  only if a validated modded entry cannot fit.
- Missing/malformed text produces `DATA UNAVAILABLE`, not a crash.

Moving the cursor updates the right panel immediately. It must not play the cry
automatically.

## 5. Discovery/privacy policy

Preserve native Pokédex progression by default:

- **Unseen:** show number and `?????`; no identifying sprite, icon, entry or
  submenu. Use a neutral silhouette/unknown image.
- **Seen, not owned:** show name and sprite. Keep the full entry/height/weight
  hidden if the active game's native rule requires ownership; show
  `DATA UNKNOWN — CATCH THIS POKÉMON`.
- **Owned:** show full requested detail and all five submenu actions.

Habitat visibility for seen-but-not-owned species is a design choice that must
be checked against the intended vanilla policy before coding. Safe initial
rule: the submenu is available for seen species, but full research pages can
show an explicit ownership gate. Do not silently reveal unseen species through
Habitat names, icons, search results, evolution links or TM lists.

If the user later requests a reveal-all mode, make it an explicit option with
clear spoiler wording. Do not inherit Pokédex Plus's default reveal-unseen
behavior without approval.

Party/PC scanning may treat an actually possessed species as owned for display
when imported save flags are stale, but must not write or “repair” Pokédex save
flags. The engine remains the progression authority.

## 6. A-button submenu

Pressing A on an eligible selected Pokémon opens a Widescreen side panel/modal
without exposing native UI beneath it. The order is fixed:

1. `HABITAT`
2. `STATS`
3. `LEARNSET`
4. `EVOLUTION`
5. `CRY`

B closes the submenu and returns focus to the same species row. Subscreens
return to the same submenu item and retain their scroll positions for the
current Pokédex session.

CRY is an action, not a screen. It keeps the submenu open and may be replayed
after the previous cry completes or according to the engine's normal audio
policy. Do not add overlapping uncontrolled audio sources.

## 7. Habitat

Habitat answers: **Where can this species currently be caught in the effective
game configuration?** It must not confuse evolution, gifts or trades with wild
capture locations.

Each Habitat row should contain, when available:

- Human-readable map/area name.
- Encounter method: grass, cave, Surf, Old/Good/Super Rod, static, or provider
  method.
- Minimum and maximum level.
- Slot/conditional chance.
- Estimated per-step chance only when it is mathematically defined and clearly
  labeled.
- Time/period and progression requirements supplied by the effective provider.
- Edition/provider provenance for diagnostics, not necessarily normal UI.

Group duplicate slots for the same area/method/condition and calculate their
combined probability correctly. Sort by map order/name, then method, condition
and level.

### 7.1 Data-resolution chain

1. If `kanto_living_encounters` is active and exposes a compatible immutable
   species-habitat query, use it as the sole effective source.
2. Otherwise scan the merged engine encounter registry read-only.
3. If neither source can describe habitats, show `NO WILD HABITAT RECORDED`.

Request this future spawn export rather than iterating current-map snapshots:

```lua
exports.getSpeciesHabitatSnapshot(speciesId, context)
```

Recommended result:

```lua
{
  schemaVersion = 1,
  speciesId = "PIKACHU",
  providerId = "yellow_legacy_spawn_tables",
  providerRevision = 4,
  snapshotRevision = 12,
  habitats = {
    {
      mapId = "VIRIDIAN_FOREST",
      mapName = "VIRIDIAN FOREST",
      method = "grass",
      minLevel = 3,
      maxLevel = 5,
      slotChance = 5.0,
      stepChance = 0.49,
      conditions = {},
    }
  }
}
```

The query must consume no RNG, create no visible entity, mutate no provider
table and mark no Pokédex state. Cache by provider/data/progression revision,
not forever by species ID.

Do not make the spawn mod mandatory for the entire Pokédex. Widescreen is the
only mandatory dependency. The fallback keeps the Pokédex useful in a vanilla
or Yellow Legacy-only configuration while the provider path reflects custom
effective tables when Wilds/spawn control is active.

Static encounters can be displayed only from structured live data or a
versioned provider export. Do not embed a handwritten list of legendary/static
locations that can become false under Yellow Legacy or other content mods.

## 8. Stats

Read the selected species' effective merged base stats and types.

Show:

- Type badge or badges.
- Base HP.
- Base Attack.
- Base Defense.
- Base Speed.
- Base Special.
- Base-stat total using the five Generation I stats.

Use full labels and optional comparison bars, but always print numeric values.
Bars must share one documented scale and cannot imply that base stats are the
selected Pokémon's current calculated stats.

Do not add Special Attack/Special Defense unless the active engine schema truly
uses a post-Gen-I split. Yellow Legacy changes should appear automatically from
merged species data.

Malformed/missing values display `—` and produce a deduplicated diagnostic;
they must not be silently converted to a plausible zero in the UI.

## 9. Learnset

Use one scrollable Widescreen screen with three ordered sections:

### LEVEL-UP MOVES

For every effective `def.learnset` record:

- Level (`START` for level 1/start moves when appropriate).
- Move name.
- Type badge.
- Optional compact power/accuracy/PP detail if it fits without harming the
  primary requirement.

Sort by level, preserving source order for same-level entries unless the engine
defines another ordering. Do not alphabetize same-level moves and thereby alter
their meaningful learn order. Validate move IDs; invalid records show a safe
diagnostic row or are skipped with a counted warning.

### LEARNABLE TMs

After the final level-up row, show every currently learnable **TM**:

- TM code/number.
- Contained move name.
- Type badge.

Resolve TMs by joining the species' effective TM/HM compatibility data with the
effective merged item/machine registry. Sort numerically by TM number. Do not
assume item IDs or display names encode the number if structured machine
metadata exists.

### LEARNABLE HMs

The user subsequently requested HM coverage. Show compatible HMs in their own
section after TMs, using the same structured machine join and numeric ordering.
If no compatible TM or HM exists, show the corresponding explicit
`NO LEARNABLE TMs` or `NO LEARNABLE HMs` row.

Reusable Machines may change consumption but not compatibility; do not modify
or teach moves from this screen. Selecting a move may open a read-only detail
panel only if implemented through Widescreen's shared semantic components.

## 10. Evolution

Display every outgoing evolution in the selected species' effective
`evolutions` records.

For each branch show:

- Target species name, respecting discovery privacy.
- Method.
- Level for level evolution.
- Required stone/item for item evolution.
- Trade or other custom method description when applicable.

Use `game.data.evolution_methods[method].describe` when the active method
provides a safe describer. Otherwise support verified structured fallbacks for
`LEVEL`, `ITEM`, `TRADE` and clearly labeled custom/special methods.

Do not reduce all evolution methods to only level or stone: Yellow Legacy or
another mod may use trade, friendship-like, location or custom requirements.
Never invent an item or level when data is incomplete.

Final-stage species show `NO FURTHER EVOLUTION`. Branched evolutions show every
branch. Pre-evolution/incoming chains are outside the requested first-release
screen; add them only if the user expands scope.

## 11. Cry resolution

CRY must call the engine's live public path:

```lua
require("src.core.Sound").playCry(game.data, speciesId)
```

This is essential because it:

- Reads the active merged cry/audio definitions.
- Honors mods that patch the cry registry or wrap the public playback function.
- Preserves Yellow Pikachu PCM behavior where applicable.
- Falls back to the engine/ROM-derived default cry when no mod replaces it.

Do not resolve raw WAV paths, synthesize a second cry, cache a `SoundData`
independently or bypass a replacement mod by reading ROM data directly.

Call the live function at action time, not a cached function reference captured
before other mods load. Handle missing/invalid cry definitions gracefully with
one diagnostic and no crash.

## 12. Sprite resolution

Because the requested screen should resemble our Widescreen Pokémon menu, use
Widescreen's live 2D portrait resolver rather than maintaining a second sprite
stack.

Priority:

1. Active Shiny/Battle Art-compatible Widescreen 2D resolver where appropriate
   for a species-only Pokédex portrait.
2. Engine `pokemon.sprite`/`Sprites.path(..., "front", { kind = "dex" })`
   result.
3. Visible unknown/placeholder image.

A Pokédex species entry has no individual DVs, so it must not be rendered shiny
merely because the user owns a shiny specimen. Use the normal species art unless
a future explicit Pokédex-form contract says otherwise.

Animated Battle Art may animate through its own resolver if Widescreen supports
species-only previews safely. Static art remains static. Stadium 3D models have
no valid 2D Pokédex equivalent; fall back to the selected Battle Art 2D image or
engine ROM front sprite. Never flatten a 3D model.

Resolve at draw/open time and invalidate caches when the active art provider or
its generation option changes. Use nearest-neighbor filtering and aspect-aware
fit without species-specific offsets unless a visual audit proves one necessary.

## 13. Mandatory Widescreen contract

Conceptual manifest dependency:

```json
"dependencies": [
  "gen1_widescreen_ui@>=REQUIRED_POKEDEX_API_VERSION"
]
```

Widescreen alpha 10.1 provides an independent native Pokédex skin and generic
Pokedex Provider API v1. It does not consult or support Pokédex+. The provider
contract below is now available through `registerPokedexProvider`,
`unregisterPokedexProvider`, `activePokedexProviderOwner`, and
`invokePokedexProviderAction`; extend its validated snapshot/presenter modes as
the dedicated master/detail screens are implemented rather than adding a
second drawing path.

Minimum generic registration shape:

```lua
widescreen.registerPokedexProvider({
  owner = "gen1_widescreen_pokedex",
  apiVersion = 1,
  match = function(state) ... end,
  snapshot = function(game, state) ... end,
  actions = {
    select = function(game, state) ... end,
    back = function(game, state) ... end,
    up = function(game, state) ... end,
    down = function(game, state) ... end,
    pageUp = function(game, state) ... end,
    pageDown = function(game, state) ... end,
    submenuSelect = function(game, state, actionId) ... end,
  }
})
```

Requirements:

- Widescreen must not depend on this mod.
- One active Pokédex provider is accepted deterministically.
- Snapshots are validated and treated as immutable.
- Native draw is suppressed for main screen, submenu and every requested
  subpage.
- Missing/incompatible runtime API leaves the vanilla destination untouched and
  logs one actionable error; it must not install a half-converted Pokédex.
- While this mod is enabled, its Widescreen Pokédex presenter cannot be
  independently disabled into a native fallback.
- Registration is generic, not a hardcoded check for this manifest ID.

The provider may replace the native START-menu Pokédex callback while preserving
the row's ordering and other mods' Start-menu changes. Declare a conflict with
other full Pokédex replacements rather than stacking destinations or screens.

## 14. Recommended semantic models

Main snapshot:

```lua
{
  schemaVersion = 1,
  screen = "pokedex",
  rows = {
    {
      speciesId = "BULBASAUR",
      number = "001",
      name = "BULBASAUR",
      seen = true,
      owned = true,
      hidden = false,
      icon = iconDescriptorOrNil,
    }
  },
  selectedIndex = 1,
  selectedSpeciesId = "BULBASAUR",
  counts = { seen = 12, owned = 6, total = 151 },
  detail = {
    number = "001",
    name = "BULBASAUR",
    kind = "SEED POKÉMON",
    entry = "A strange seed was planted...",
    portrait = portraitDescriptorOrHandle,
    seen = true,
    owned = true,
  },
  submenu = nil,
}
```

Subscreens should use explicit mode IDs and typed rows:

- `pokedex_habitat`
- `pokedex_stats`
- `pokedex_learnset`
- `pokedex_evolution`

Never expose live save, encounter, species, move, item or provider tables in a
snapshot.

## 15. Compatibility requirements

### Yellow Legacy

- Read its effective merged base stats, level-up learnsets, TM compatibility,
  evolution records and encounter changes.
- Do not depend directly on Yellow Legacy or copy its tables.
- Habitat must reflect the active edition/table provider.

### Wilds of Kanto / spawn provider

- Prefer its versioned species-habitat snapshot when present.
- Do not consume RNG, create entities or read the provider's private tables.
- Pokédex viewing must never change visible spawns or random encounters.

### Widescreen Dex Radar

Both are read-only consumers of effective habitat/encounter information, but
they have different scopes: Radar shows the current map; Pokédex Habitat shows
all effective locations for one known species. Share provider contracts, not
mutable caches or UI screens.

### Battle Art Replacer and Shiny System

Use Widescreen's live normal 2D portrait policy. Do not select shiny art without
an individual Pokémon shiny state and never flatten Stadium models.

### Widescreen Modern Bag

Learnable TM rows may reuse generic type/move components, but Pokédex does not
read Bag inventory, Favorites or item-icon state and cannot teach a TM.

### Unified QOL, Move Inspector, followers and world mods

No ownership overlap. Do not add Catch Helper data, battle matchup prediction,
followers, world entities, camera changes or geometry changes.

## 16. Conflict and save policy

Declare conflicts with at least:

- `pokedex_plus`
- Any other verified full replacement of the native Pokédex destination or
  screen family.

Do not conflict with read-only data/art/audio providers merely because they
change content shown by the Pokédex.

The first release should require no persistent mod save data beyond optional UI
preferences. Cursor/submenu positions may be session state. Never write seen or
owned flags. If options are later added, namespace and version their schema.

## 17. Proposed flat package

```text
manifest.json
main.lua
README.md
CHANGELOG.md
LICENSE
```

No bundled Pokémon sprites, cries, encounter tables or Yellow Legacy data.
Those remain live provider/engine data. Use root-only release ZIP entries and
retain all required MIT notices for reused reference material.

## 18. Required tests

### Main screen and privacy

- Dex ordering, variant suffix ordering and mod-added species.
- Unseen, seen and owned row/detail states.
- No sprite/icon/name leak for unseen species.
- Party/PC owned-display recovery does not mutate save flags.
- Seen/owned totals.
- Cursor/page movement, key repeat and stable selection.
- Long names, numbers beyond three digits and missing definitions.
- Entry control-code normalization and long-text scrolling/wrapping.
- A opens the five options in the exact requested order.
- B restores the correct list/submenu focus.

### Habitat

- Provider snapshot is preferred when compatible.
- Provider absent uses merged engine encounters.
- Provider error/version mismatch follows the documented safe fallback.
- Grass/cave/Surf/rod/static structured methods.
- Duplicate-slot aggregation, level range and chance math.
- Edition/condition/time variants.
- No habitat produces an explicit empty state.
- Query consumes no RNG and mutates no provider/Pokédex state.

### Stats

- Five Gen I base stats and correct total.
- Single and dual types.
- Yellow Legacy/modded values appear live.
- Missing/malformed values show `—`, not misleading zeroes.

### Learnset/TMs/HMs

- Level order and stable same-level source order.
- Start/level-1 labeling.
- Level-up section always precedes TMs.
- Effective TM compatibility joined through structured machine metadata.
- TM numeric order.
- HMs follow TMs in their own section and use structured numeric ordering.
- Invalid/missing move or machine data is handled safely.
- Screen cannot teach or mutate moves.

### Evolution

- Level, stone/item, trade, custom and branched evolution records.
- No-further-evolution state.
- Target privacy for unseen species.
- Evolution-method describer errors are isolated.

### Cry and sprite providers

- Cry calls live `Sound.playCry` at action time.
- Replaced cry is honored.
- No replacement uses engine/ROM default.
- Missing cry fails safely.
- Live static/animated normal 2D portrait selection.
- Art-provider option change invalidates the portrait.
- Stadium mode uses valid 2D fallback.
- No shiny art chosen from species identity alone.

### Widescreen dependency/presentation

- Missing/too-old Widescreen blocks activation.
- Missing runtime contract leaves native Pokédex untouched and warns once.
- Successful provider registration suppresses native drawing for every screen.
- Keyboard, controller and pointer actions share behavior.
- Competing Pokédex provider/replacement is rejected deterministically.
- Widescreen option state cannot expose a native layer while the mod is active.

## 19. Visual audit matrix

Capture:

- Unseen, seen and owned main-detail states.
- Long and multi-paragraph Pokédex entries.
- Submenu open over the master/detail layout.
- Habitat with no rows, few rows and many rows.
- Stats with one and two types.
- Learnset with short/long level lists and many TMs.
- Branched, stone, level, trade and no evolution.
- Default ROM portrait, Battle Art static, animated and Stadium fallback.
- 1080p, 1440p, 4K and narrow supported fallback.
- Controller focus and pointer hover.

Verify exactly one presenter, crisp nearest-neighbor art, no clipped entry text,
no overlapping panels, readable type badges, stable focus and no privacy leaks.

## 20. Implementation order

1. Read the master guide and overlapping design documents.
2. Re-audit current engine schemas, PokedexMenu, DexEntryMenu, Sound and sprite
   resolution.
3. Design and land Widescreen's generic Pokédex provider/presenter contract.
4. Bump Widescreen and finalize the mandatory dependency floor.
5. Implement immutable main/detail snapshots and discovery privacy.
6. Implement submenu state and Stats/Learnset/Evolution models.
7. Add the spawn provider's species-habitat export, plus native merged fallback.
8. Wire Cry through the live engine function and portraits through Widescreen.
9. Run unit, contract, integration and visual audits.
10. Build a licensed, versioned, flat ZIP in `Releases`; do not install it.

## 21. Decisions to verify before coding

1. Final manifest ID and display title.
2. Exact Widescreen Pokédex API and version floor.
3. Whether submenu research pages require seen or owned state.
4. Whether height/weight should appear in the permanent right panel.
5. Final spawn-provider species-habitat schema and fallback semantics.
6. Exact representation of TM compatibility in the current effective data.
7. Whether animated Battle Art supports a species-only preview safely.
8. All installed full Pokédex replacements that require manifest conflicts.

Do not guess these values in production code. Record verified decisions in the
README and tests.

## 22. Definition of done

- The main screen has the requested left species list and right sprite/entry
  panel on Widescreen's 640×360 surface.
- A opens exactly Habitat, Stats, Learnset, Evolution and Cry.
- Habitat reflects effective live capture locations without owning encounters.
- Stats uses live five-stat Generation I base data.
- Learnset shows level-up moves followed by separate learnable TM and HM
  sections.
- Evolution reports every outgoing level/item/trade/custom branch honestly.
- Cry honors active replacements and otherwise uses the engine/ROM default.
- Sprite resolution follows Widescreen's live normal 2D policy.
- Discovery privacy is preserved and viewing never mutates progression.
- Widescreen is mandatory and no native Pokédex layer is exposed.
- Tests and visual audits pass.
- The release ZIP is flat, licensed, versioned and not auto-installed.
