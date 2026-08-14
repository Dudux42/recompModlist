# Provider-owner request — full Widescreen Pokédex presenter contract

Date: **2026-08-11**

Status: **Implemented by Gen1 Widescreen UI 0.1.0-alpha.14.0.** API v2,
update-time controller/keyboard dispatch, pointer/touch regions, privacy-safe
master-detail/submenu/research renderers, last-valid failure containment and
normal Battle Art presentation are now provided. API v1 list registration is
retained for compatibility.

## Owning provider

- Mod: **Gen1 Widescreen UI**
- Manifest ID: `gen1_widescreen_ui`
- Audited source version: `0.1.0-alpha.12.4`
- Current surface: `main.lua`, Pokedex Provider API v1
- Current exports: `pokedexProviderApiVersion`,
  `registerPokedexProvider`, `unregisterPokedexProvider`,
  `activePokedexProviderOwner`, and `invokePokedexProviderAction`

## Dependent and blocked use case

- Mod: **Widescreen Pokédex**
- Manifest ID: `gen1_widescreen_pokedex`
- Required UI: a Pokédex-numbered left list and live right detail panel, plus
  the exact `HABITAT`, `STATS`, `LEARNSET`, `EVOLUTION`, `CRY` submenu and four
  read-only research pages.

The dependent mod owns immutable semantic snapshots, navigation state, data
adaptation, privacy, and cry requests. Widescreen must remain the only owner of
640x360 layout, drawing, focus visualization, input mapping, pointer/touch hit
regions, clipping, typography, portrait resolution, and native-draw
suppression.

## Verified blocker

This is based on the current alpha 12.4 source, not an assumption:

1. `validatePokedexSnapshot` validates only `schemaVersion`, `screen`, `rows`,
   `selectedIndex`, and row `label`/`name`.
2. `pokedexPresentation` copies the rows into a generic full-width list model.
   It does not consume `detail`, `submenu`, typed research rows, or any
   screen-specific model.
3. `drawPokedexList` draws a single 600-pixel-wide list. It has no right detail
   panel or research-page renderer.
4. `invokePokedexProviderAction` is exported, but the runtime never calls it;
   only the Widescreen test invokes it directly. Therefore controller/keyboard
   input cannot reach the registered provider through API v1.
5. No provider pointer/touch regions exist.

Consequently, API v1 can show a list fixture but cannot implement the requested
product without a second renderer or private Widescreen patch. Both would
violate the ownership boundary.

## Smallest requested provider-side change

Publish **Pokedex Provider API v2**, preserving v1 behavior for existing test
fixtures if practical. The v2 presenter should:

1. Validate and draw the semantic modes below.
2. Route controller/keyboard and pointer/touch input to registered semantic
   actions.
3. Suppress all native Pokédex layers while a valid v2 provider owns a matched
   state.
4. Force the Widescreen Pokédex option on while a provider is registered, as
   the current code already does.
5. Continue accepting exactly one owner deterministically, allowing the same
   owner to replace itself.
6. Resolve Pokémon portraits at draw time through Widescreen's current live 2D
   presentation policy, using a species-only normal object and purpose
   `pokedex`; never infer shiny state and never flatten Stadium models.

Suggested additional export:

```lua
exports.updatePokedexProviderInput(game, state, dt)
```

The dependent screen's `update` method will call this function. Widescreen then
maps active input to the provider actions, keeping input ownership in the
presenter without requiring Widescreen to know the dependent screen class.
Pointer/touch input may be processed by the same export or by a documented
Widescreen-owned callback path. It must never invoke actions during draw.

Required actions:

```lua
actions = {
  up = fn, down = fn, pageUp = fn, pageDown = fn,
  select = fn, back = fn,
  selectRow = fn, selectSubmenu = fn,
  scroll = fn,
}
```

Unsupported actions must fail safely. Action exceptions must remain isolated
and deduplicated as in v1.

## Snapshot schema semantics

All snapshots are fresh or treated as immutable and must contain no live save,
species, move, item, encounter, or provider tables.

### Main screen

```lua
{
  schemaVersion = 2,
  screen = "pokedex",
  title = "POKEDEX",
  rows = {
    {
      speciesId = "BULBASAUR", number = "001", name = "BULBASAUR",
      seen = true, owned = true, hidden = false,
    },
  },
  selectedIndex = 1,
  selectedSpeciesId = "BULBASAUR",
  counts = { seen = 1, owned = 1, total = 151 },
  detail = {
    speciesId = "BULBASAUR", number = "001", name = "BULBASAUR",
    kind = "SEED POKEMON", entry = "...", seen = true, owned = true,
    height = { feet = 2, inches = 4, metres = 0.7 },
    weight = { pounds = 15.2, kilograms = 6.9 },
    portrait = { kind = "pokemon", speciesId = "BULBASAUR",
                 side = "front", purpose = "pokedex", shiny = false },
  },
  submenu = nil,
}
```

When open, `submenu` contains `selectedIndex` and exactly these ordered action
rows: `habitat`, `stats`, `learnset`, `evolution`, `cry`. `cry` is an action and
must leave the submenu open.

Unseen detail uses an explicit unknown portrait descriptor and contains no
name, kind, entry, icon, evolution target, type, or research data. Seen but
unowned detail may show name and normal portrait but receives the ownership
gate text from the provider.

### Research modes

Support these exact `screen` values:

- `pokedex_habitat`
- `pokedex_stats`
- `pokedex_learnset`
- `pokedex_evolution`

Each includes `speciesId`, `number`, `name`, `selectedIndex`, `scroll`, and
typed `rows`. It may include `{ gated = true, message = "..." }` for a
seen-but-unowned entry. Empty states are explicit typed/message rows.

Expected typed fields:

- Habitat: `mapId`, `mapName`, `method`, `minLevel`, `maxLevel`,
  `slotChance`, optional `stepChance`, `conditions`.
- Stats: type IDs plus HP, Attack, Defense, Speed, Special and total numeric
  values; malformed values are displayed as an em dash, never zero.
- Learnset: section rows and move rows containing level/TM label, move ID/name,
  type ID, and optional power/accuracy/PP.
- Evolution: target ID/name or hidden placeholder plus method text.

Widescreen must wrap entry text by rendered width, provide bounded scrolling
when needed, render numeric stat values even when bars are present, and keep
all pixel art nearest-filtered at integer positions.

## Failure, invalidation, and compatibility

- Missing or incompatible v2 registration leaves the native destination
  untouched; no half-converted screen is opened.
- Invalid snapshots log one actionable error and close or preserve the last
  valid provider screen according to a documented rule. They must not expose a
  native layer beneath an active provider.
- Re-registration/load-order behavior must match the existing one-owner
  contract.
- Portraits are resolved every presentation through current Widescreen/Battle
  Art policy, with stable per-state/species tokens for animation continuity.
- The change must not alter world geometry, camera, collision, battle staging,
  save data, Pokédex flags, or engine content registries.
- Widescreen must not depend on `gen1_widescreen_pokedex` or hardcode its
  manifest ID.
- No Pokédex+ adapter is requested.

## Non-goals

- Do not build species, habitat, stat, learnset, TM, evolution, privacy, or cry
  logic in Widescreen.
- Do not mutate Pokédex progression.
- Do not add search, Area Map, printer, reveal-all, or move teaching.
- Do not change any provider mod or world/encounter behavior.

## Acceptance tests

1. A generic v2 fixture renders list and right detail simultaneously.
2. Unseen fixture never resolves or draws identifying art/text.
3. Seen/unowned and owned fixtures render their distinct privacy states.
4. Input dispatch covers up/down/page/select/back and the exact submenu order.
5. `CRY` action is dispatched without closing the submenu.
6. Every research mode renders typed rows, long lists scroll, and empty/gated
   modes remain explicit.
7. Pointer/touch row selection and submenu activation call the same actions as
   controller/keyboard input.
8. Provider registration forces the Widescreen Pokédex option on.
9. Competing owners, provider exceptions, and invalid schemas are isolated.
10. Native Pokédex rendering remains unchanged when no v2 provider is active.
11. Battle Art static/animated and ROM fallback are exercised with normal
    species-only art; no shiny or Stadium flattening occurs.
12. Existing START, Party, Summary, title, Options, Manager, Load Report and
    Battle HUD tests still pass.

Perform a visual audit at 1080p, 1440p, 4K, and the supported narrow fallback
for main privacy states, open submenu, all research modes, long entry text, and
long lists.

## Version and returned artifacts

- Bump `gen1_widescreen_ui` to a new non-overwriting version.
- Publish `pokedexProviderApiVersion = 2` and document the final contract.
- The dependent mod will set its mandatory dependency floor to that exact first
  v2 release.
- Return changed files, final schema/action names, version, tests run, visual
  audit artifacts, and a flat root-only Widescreen release ZIP. Do not install
  the ZIP.
