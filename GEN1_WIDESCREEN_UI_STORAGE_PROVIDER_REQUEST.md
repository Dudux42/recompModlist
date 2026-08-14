# Gen1 Widescreen UI — Pokemon Storage Provider Request

Date: **2026-08-13**

Owner: **Gen1 Widescreen UI** (`gen1_widescreen_ui`)

Current audited release: **0.1.0-alpha.14.30**

Consumers blocked: **Widescreen Grid Box** (`gen1_widescreen_grid_box`) and
any later dedicated Pokemon-storage implementation.

This is a provider-owner request under `MASTER_MOD_GUIDE.md` section 1.1. The
Grid Box agent must not implement these changes inside its own mod or patch
Widescreen's private tables.

## 1. Verified engine baseline

The installed update payload is:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\updates\gen1recomp-0.1.83.love`

Its packaged `src/core/Version.lua` reports:

- engine `0.1.83`;
- mod API `2`;
- link protocol `2`;
- save format `4`;
- ROM cache `rom-cache-v5`;
- payload host `love` and shell contract `1`.

The packaged Gen 1 storage contract remains `12` boxes of `20` Pokemon in
`save.boxes`, with `save.currentBox` and `save.party`. Native `BoxMenu` still
offers WITHDRAW, DEPOSIT, RELEASE, CHANGE BOX, Yellow PRINT BOX and SEE YA.

## 2. Resolved prerequisite — early `clamp` binding

### Evidence

The installed `gen1_widescreen_ui` alpha 14.28 produced:

```text
mods/gen1_widescreen_ui/main.lua:55: attempt to call global 'clamp' (a nil value)
gitCommit=8e4d5b68 loveNxTag=11.5-nx1 buildVersion=0.1.83 os=Windows
```

`PokedexProviderUI.queueExpAnimation` is defined at line 48 and calls `clamp`
at lines 55–56. The local `clamp` declaration does not appear until line 520.
Under Lua lexical scoping, the earlier closure therefore resolves a global
named `clamp`, not that later local function. This is a Widescreen defect
exposed during a 0.1.83 run; do not describe it as a verified engine defect.

### Resolution audit

Widescreen alpha 14.29 replaced those two early calls with self-contained
`math.max`/`math.min` bounds and added a smoke test. Alpha 14.30 retains that
repair while refining EXP timing. The canonical alpha 14.30 ZIP has therefore
resolved this prerequisite; do not redo it as part of the Storage API work.

### Acceptance tests

1. Static test proves no function defined before the local binding resolves
   `clamp` globally.
2. Run the EXP/level-up presentation path on Gen1Recomp 0.1.83 with Unified
   QOL enabled; no `clamp` error is written.
3. Existing EXP animation sequencing and final ratios are unchanged.

## 3. Required change — Pokemon Storage Provider API v1

### Current limitation

Widescreen alpha 14.30 owns responsive PC presentation by recognizing native
`Menu` and `ListMenu` shapes. Its Pokemon detail lookup recognizes only native
`PARTY (DEPOSIT)` and `BOX n (WITHDRAW|RELEASE)` lists. A dedicated grid state
is intentionally treated as an opaque destination, so it cannot be rendered
without either patching Widescreen internals or adding a public provider
contract. The latter is the required architecture.

### Requested public surface

Publish a one-owner, fail-closed contract analogous to the existing Pokedex
and Bag provider APIs:

```lua
widescreen.exports.pokemonStorageProviderApiVersion = 1

widescreen.exports.registerPokemonStorageProvider({
  owner = "gen1_widescreen_grid_box",
  apiVersion = 1,
  match = function(state) return ownsState end,
  snapshot = function(game, state) return immutableSnapshot end,
  actions = {
    up = fn, down = fn, left = fn, right = fn,
    previousBox = fn, nextBox = fn,
    select = fn, back = fn,
    selectCell = fn, selectPartySlot = fn,
    selectPopup = fn, update = optionalFn,
  },
})

widescreen.exports.unregisterPokemonStorageProvider(owner)
widescreen.exports.activePokemonStorageProviderOwner()
widescreen.exports.invokePokemonStorageProviderAction(...)
```

The existing responsive Bill's-PC root also needs a generic context entry for
`MOVE POKEMON` (for example, “Rearrange Pokemon within Boxes or the party.”).
Root-menu callbacks and row order remain provider/engine semantics; this is
only the description shown by Widescreen when that live row is highlighted.

Names may be refined, but the finalized names and schema must be documented in
the Widescreen package. Registration must reject invalid specs, duplicate
owners and unsupported API versions with `nil, reason`. Unregistration must
only remove the matching owner. Provider failures must be isolated and logged
once per distinct failure state.

### Snapshot semantics required by the consumer

The provider needs to express:

- screen/mode: `withdraw`, `deposit`, `move`, `party`, `popup`, or `stats`;
- 12-box navigation: viewed box, active box, occupancy and capacity;
- a fixed 5-column by 4-row grid of 20 cells;
- selected region/cell and a presentation-only held-Pokemon descriptor;
- six party slots and whether the party drawer is open;
- a selected Pokemon detail model: name, species, level, HP/status, five Gen 1
  stats, types and up to four moves with PP;
- popup labels, selected popup index and disabled reasons;
- footer/status text and controller/keyboard hints;
- stable identity/animation tokens and static-icon descriptors;
- enabled/disabled state and optional pointer hit-region actions.

The snapshot must not grant Widescreen authority to mutate `save.party`,
`save.boxes`, Pokemon records, current-box state, happiness or cached stats.
It may carry a read-only presentation copy containing the individual fields
needed for shiny-aware art resolution; it must not require Widescreen to
retain or alter the live save record.

### Presentation ownership

Widescreen owns:

- all 640×360 drawing, scaling, panels, focus, hit regions and input mapping;
- a left 5×4 grid and a right detail panel;
- static Pokemon icons (force frame 1 even when an icon provider is animated);
- the selected Pokemon's animated 2D portrait through Battle Art Presentation
  API v1, with a stable token and ROM 2D fallback;
- the left-side six-slot Party drawer, held-Pokemon ghost and right-side popup;
- suppressing the native 160×144 layer only while a valid provider snapshot
  owns the state;
- safe composition of native TextBox/ChoiceBox and Summary screens above it.

The storage provider owns navigation semantics, popup semantics, validation
and every mutation. Widescreen must never infer or execute a transfer.

### Failure and invalidation rules

1. A valid matching state is opaque: never draw the native storage layer
   beneath it.
2. If a later snapshot is temporarily invalid, retain the last valid snapshot
   for that exact state and expose an actionable error; do not leak native
   content through the grid.
3. If registration never succeeds, the custom mod must fail closed before it
   replaces native `BoxMenu`; ordinary Widescreen/native storage stays usable.
4. Provider registration/unregistration and mod reload must invalidate cached
   views, hit regions, icons and portrait tokens belonging to that owner.
5. Stadium/voxel modes must never be flattened into this 2D UI. Use the normal
   Widescreen ROM-image fallback when a provider declines 2D art.

### Non-goals

Do not implement storage transactions, box ordering, party limits, Yellow
Pikachu rules, current-box selection, save writes, release behavior, stats
calculation or the Grid Box state machine in Widescreen. Do not embed Grid Box
labels or manifest IDs in generic drawing code beyond provider diagnostics.

### Provider acceptance tests

1. Register, reject malformed/duplicate owners, render, invoke every action,
   unregister and re-register without stale state.
2. Render 0, 1, 19 and 20 Pokemon; six party slots; long names; four moves;
   status; missing icon; missing battle art; normal and shiny individuals.
3. Confirm icon descriptors remain static while the large portrait animates.
4. Confirm mouse/touch and controller focus select the same semantic target.
5. Confirm TextBox/ChoiceBox appear above the grid and Summary fully owns its
   destination without a native-PC flash.
6. Confirm invalid snapshots retain the last valid opaque view and log once.
7. Confirm ordinary native PC and item-PC presentation is unchanged when no
   storage provider matches.
8. Confirm Red, Blue and Yellow on Gen1Recomp 0.1.83; Yellow PRINT BOX remains
   a native root action outside the provider screen.
9. Confirm a live root containing MOVE POKEMON shows the new context text and
   no removed RELEASE row or stale release warning is synthesized by the
   presenter.

## 4. Version and returned artifacts

This is a new public feature, so bump Widescreen from alpha 14.30 to a new,
never-overwritten release. Return:

- changed source and contract documentation;
- finalized API/schema names and compatibility version;
- updated manifest/README/source headers;
- tests and their exact results;
- a focused 640×360 audit image for grid, Party drawer and popup states;
- a flat root-only release ZIP;
- the exact minimum Widescreen version the Grid Box manifest must require.
