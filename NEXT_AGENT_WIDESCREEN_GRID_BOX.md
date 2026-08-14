# Next Agent Handoff — Widescreen Grid Box

Date: **2026-08-13**

Working name: **Widescreen Grid Box**

Proposed manifest ID: **`gen1_widescreen_grid_box`**

Proposed first version: **`0.1.0-alpha.1`**

Target engine: **Gen1Recomp `>=0.1.83 <0.2.0`**, API 2, explicitly
`"games": ["gen1"]`

Mandatory dependency: **Gen1 Widescreen UI
`>=0.1.0-alpha.14.32 <0.2.0`**. Alpha 14.32 completes Pokemon Storage
Provider API v1 and the Party-button/target-state presenter required here.

> Naming correction: this is a Pokemon Storage System / PC Box mod, not a
> Pokedex mod. Keep “Pokedex” out of its display name, manifest ID, source
> modules and provider contract so it does not collide with
> `gen1_widescreen_pokedex`.

## 1. Goal

Replace Bill's Gen 1 list-based Pokemon storage workflows with a Gen III-style
visual Box interface:

- a 5×4 grid representing all 20 slots of the viewed box on the left;
- static Pokemon icons in occupied cells;
- a right detail panel for the highlighted Pokemon;
- an animated large 2D Pokemon sprite, name, stats and current moves;
- direct Move Pokemon behavior between box cells, boxes and the party;
- a left-side Party drawer with six static-icon slots;
- no Release command anywhere in the modded Bill's PC flow.

The result should feel like the Gen III Pokemon Box while respecting Gen 1's
actual data model, party constraints, Yellow Pikachu behavior and 12×20 box
capacity.

## 2. Required ownership boundary

### This mod owns

- replacing the Gen 1 `BoxMenu.new(game)` root semantic menu;
- the custom storage state machine and immutable provider snapshots;
- viewed-box navigation, cursor state, popups and Party drawer semantics;
- withdraw, deposit, move, reorder and swap validation;
- atomic mutations of `save.boxes` and `save.party`;
- native `Stats.ensure` calls when a boxed Pokemon enters the party;
- Yellow deposit restrictions and deposited-Pikachu happiness calls;
- preserving native CHANGE BOX and Yellow PRINT BOX behavior;
- all failure messages and transaction cancellation.

### Widescreen owns

- every 640×360 draw pass, grid/panel layout, static icon draw, animated detail
  portrait, cursor, held ghost, popup, hit region and input-to-action mapping;
- 2D Battle Art resolution and ROM fallback;
- suppressing the native layer while a valid storage snapshot owns the state.

### The engine owns

- `save.party`, `save.boxes`, `save.currentBox` and normal save persistence;
- the Pokemon/stat data model, Summary screen, cries and sound effects;
- the party maximum, box count/capacity and Yellow follower implementation;
- link/session behavior outside this mod's declared effects.

Do not draw a second widescreen UI from this mod. Do not reach into private
Widescreen tables. If the public storage provider contract is unavailable,
fail closed before replacing native `BoxMenu`, log one actionable error, and
leave the native/Widescreen PC functional.

## 3. Audited references

### Gen1Recomp 0.1.83

Audit the packaged update, not the stale editable checkout:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\updates\gen1recomp-0.1.83.love`

Relevant packaged files:

- `src/ui/BoxMenu.lua`
- `src/pokemon/Boxes.lua`
- `src/pokemon/Party.lua`
- `src/pokemon/Stats.lua`
- `src/world/PikachuFollower.lua`
- `src/ui/SummaryMenu.lua`
- `src/core/Sound.lua`

Verified storage facts:

- `Boxes.COUNT == 12` and `Boxes.CAPACITY == 20`;
- storage is `save.boxes[1..12]`, each a dense Lua array;
- `save.currentBox` is the active capture/deposit box;
- `Boxes.deposit` can overflow a caught Pokemon into the next box with room;
- native withdraw runs `Stats.ensure` before inserting into the party;
- native deposit refuses the last party Pokemon, enforces the Yellow sleeping
  starter guard and calls `modifyHappiness(save, "DEPOSITED", mon)`;
- native CHANGE BOX asks permission, changes `save.currentBox`, writes the save
  and plays the Save sound;
- Yellow PRINT BOX writes the active box list through the native Printer path.

### Installed Advanced Box System 1.1.0

Read-only behavioral reference:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\advanced_box_system`

Useful behavior to recreate independently:

- box browsing from storage workflows;
- read-only temporary stat calculation for imported boxed Pokemon;
- safe box/party swaps even with a full party or one-member party;
- existing `save.boxes`/`save.party` storage rather than a parallel format;
- `Stats.ensure` only when a boxed Pokemon actually enters the party;
- Yellow deposited-Pikachu happiness behavior.

Its `LICENSE` contains no explicit redistribution or derivative-work grant.
Treat it as behavioral reference only: do not copy its Lua, documentation or
assets. Implement from the engine contracts and this specification.

## 4. Root Bill's PC menu

Replace the native Pokemon-storage root items with this exact semantic order:

1. `WITHDRAW POKEMON`
2. `DEPOSIT POKEMON`
3. `MOVE POKEMON`
4. `CHANGE BOX`
5. `PRINT BOX` — Yellow only
6. `SEE YA!`

Remove `RELEASE POKEMON`; do not hide a Release action in another popup or
shortcut. `MOVE POKEMON` replaces it in the root flow. Keep the menu silent in
the same places as native Bill's PC.

CHANGE BOX and PRINT BOX should call or faithfully preserve the native 0.1.83
behavior rather than duplicating a second persistence/printer system. Root
CHANGE BOX is the only operation that changes `save.currentBox`; browsing a
box in a grid changes only the screen's `viewedBox`.

That distinction is intentional: merely inspecting Box 8 must not silently
redirect future caught Pokemon away from the active box. Display an `ACTIVE`
badge on the current box. The user can leave and use CHANGE BOX when they want
to change it, preserving Gen 1's save-confirmation rule.

## 5. Shared 640×360 presentation model

### Header

- title/mode at upper left;
- `BOX nn` centered above the grid;
- occupancy `n/20` and an `ACTIVE` badge when applicable;
- shoulder-button arrows for previous/next viewed box.

### Left grid

- 5 columns × 4 rows = 20 visible cells, with no scrolling;
- each occupied cell shows one static icon and a clear selected border;
- force icon frame 1 even when HGSS Menu Icons or another provider supplies an
  animated descriptor;
- empty cells have a visible slot shape but no placeholder Pokemon art;
- nearest-neighbor filtering and integer positioning only;
- selected, held-origin, valid-target, invalid-target and empty states must be
  distinguishable without relying on color alone.

### Right detail panel

For the highlighted occupied slot show:

- nickname/name, species name when nicknamed, level, gender if available and
  status;
- one animated live 2D front portrait;
- HP current/max;
- HP, Attack, Defense, Speed and Special;
- up to four move names with current/max PP and an empty-slot label where
  useful;
- optional type badges if the existing Widescreen helper can provide them
  without expanding the provider contract.

The large portrait must use Battle Art Presentation API v1 through Widescreen,
with purpose `pc_box_detail` and a stable per-Pokemon token. Never flatten a
Stadium/voxel model; use the normal ROM 2D front fallback.

Imported boxed Pokemon may not have `mon.stats`. Build the detail model from a
temporary read-only calculation (`Stats.calc` on a presentation copy or an
equivalent verified engine helper). Merely highlighting or opening Stats must
not write cached stats into the boxed save record.

### Footer

Always show concise live controls. At minimum:

- `A SELECT`
- `B BACK` or `B CANCEL` while holding
- `L/R BOX`
- the Party command when Move mode exposes it.

Keyboard and pointer/touch equivalents must route to the same provider
actions; they must not maintain a second navigation state.

## 6. Workflows

### 6.1 Withdraw Pokemon

Open the grid on `save.currentBox` as the initial viewed box. Box shoulders may
browse all 12 boxes without changing the active box.

Pressing A on an occupied cell opens a right-side popup that may overlap the
detail panel, with exactly:

1. `WITHDRAW`
2. `STATS`
3. `EXIT`

`WITHDRAW`:

- refuses when the party already contains six Pokemon;
- atomically removes the selected boxed record, compacts the dense box array,
  runs `Stats.ensure` for the actual record, and appends it to the party;
- plays the native cry/message behavior where practical;
- refreshes selection to the nearest remaining cell.

`STATS` pushes the engine Summary screen for a safe presentation copy when the
boxed record lacks cached stats. Returning must restore the same grid, viewed
box and selected slot. `EXIT` and B close the popup without mutation.

Empty boxes are browseable. A on an empty cell does nothing except an optional
short footer hint; it must not open an empty popup.

### 6.2 Deposit Pokemon

Open the Party drawer with the current box as the initial destination. Show
all six party slots using static icons; unused tail slots remain visibly empty.
Selecting an occupied party slot opens:

1. `DEPOSIT`
2. `STATS`
3. `EXIT`

`DEPOSIT` appends the Pokemon to the viewed box and removes it from the party,
subject to:

- the viewed box has fewer than 20 Pokemon;
- at least one Pokemon remains in the party;
- Yellow's native sleeping/following-disabled starter Pikachu guard;
- the native `DEPOSITED` happiness call after a successful party-to-box move.

Stats and Exit behave as in Withdraw. Shoulder browsing changes the
destination preview, not `save.currentBox`.

### 6.3 Move Pokemon

Open the box grid with no popup. A on an occupied box cell picks up that
Pokemon. Do not mutate the save at pickup time. Store a transient origin
descriptor (`box`/`party`, container number and index), a stable identity token
and the presentation copy. Mark the origin visibly.

While holding:

- A on an empty valid destination transfers the Pokemon atomically;
- A on an occupied destination atomically swaps the two Pokemon and ends the
  hold, matching the requested “switches them” behavior;
- B cancels and restores the exact pre-pickup state because no mutation has
  yet occurred;
- shoulder buttons may browse another box while retaining the held Pokemon;
- exiting the state, provider loss, reload or validation failure cancels the
  transient hold with no save mutation.

#### Moving inside one box

Gen1Recomp stores boxes as dense arrays. Do not create nil holes: `ipairs`,
box counts, imports and native logic assume dense ordering.

- occupied-to-occupied swaps the two array entries;
- dropping on the first empty tail cell moves the record to the end after
  compaction;
- later empty tail cells are not distinct persistent locations and should be
  disabled as drop targets unless the implementation can map them to a clear
  dense-order operation.

This is the one intentional difference from a true sparse Gen III PC. A
parallel slot-layout save table is out of scope because it creates a second
source of truth and can desynchronize imported/native saves.

#### Moving across boxes

- empty destination: remove from the source array, then append to the target;
- occupied destination: swap records across arrays without changing either
  count;
- a full target allows swaps but not an added transfer;
- use a validate-then-commit transaction so no error can strand a Pokemon.

#### Party button and drawer

Place a `PARTY` button at the bottom-left of the grid. It exists in Move mode.
Moving down from the bottom grid row reaches it; A opens a left-side drawer
with six fixed party slots and static icons.

- A on an occupied party slot picks up that Pokemon using the same deferred
  transaction model;
- when holding a party Pokemon, moving right closes the drawer and returns
  focus to the box grid while retaining the held Pokemon;
- a held box Pokemon may be dropped into an empty party slot when the party
  has fewer than six, or swapped with an occupied party Pokemon;
- a held party Pokemon may be dropped into box space only if doing so will not
  leave the party empty; a one-member party may still swap with a boxed
  Pokemon because party size remains one;
- any Pokemon entering the party from a box must receive `Stats.ensure`;
- any Pokemon leaving the party for a box must pass the Yellow starter guard
  and receive the native `DEPOSITED` happiness treatment after commit.

If no Pokemon is held, moving right or pressing B closes the Party drawer and
restores the previous grid cell. Pointer/touch selection must follow the same
rules.

## 7. Transaction and identity safety

Centralize all mutations in one storage transaction module. It should accept
an origin and destination, validate current container identity/counts, build
the result, and commit only after every rule passes.

Required invariants after every operation:

1. Total Pokemon across party plus all boxes is unchanged.
2. Party count is 1–6.
3. Every box count is 0–20.
4. All box arrays and the party remain dense.
5. No record is duplicated or lost; use table identity in tests where safe and
   stable record fingerprints where reloads clone tables.
6. The active `save.currentBox` changes only through native CHANGE BOX.
7. A rejected or cancelled action leaves a deep comparison of the storage
   state unchanged.
8. Box-only inspection never mutates stats or other Pokemon fields.

Do not write a save after every move. Match native behavior: mutate the live
save in memory and allow normal game saving, while preserving native CHANGE
BOX's explicit write. Do not introduce a shadow save or recovery file.

## 8. State and provider shape

Keep a dedicated state class, for example `GridBoxState`, with fields such as:

```lua
{
  mode = "withdraw" | "deposit" | "move",
  viewedBox = 1,
  region = "grid" | "party_button" | "party" | "popup",
  gridIndex = 1,
  partyIndex = 1,
  popupIndex = 1,
  partyOpen = false,
  held = nil, -- transient descriptor; never the only copy of a Pokemon
  footer = nil,
}
```

Register with Widescreen only after verifying the finalized Storage Provider
API version. Snapshots must be newly built semantic values and must not expose
callbacks inside the data model. All mutations route through named provider
actions. Keep controller autorepeat/update logic in the semantic state or the
documented contract, not in a private Widescreen hook.

## 9. Manifest and compatibility

Suggested manifest shape after the provider release exists:

```json
{
  "id": "gen1_widescreen_grid_box",
  "name": "Widescreen Grid Box",
  "version": "0.1.0-alpha.1",
  "entry": "main.lua",
  "api": 2,
  "profile": "content",
  "game_version": ">=0.1.83 <0.2.0",
  "games": ["gen1"],
  "category": "UI",
  "priority": 10300,
  "permissions": ["engine_internals"],
  "dependencies": [
    "gen1_widescreen_ui@>=0.1.0-alpha.14.32 <0.2.0"
  ],
  "conflicts": ["advanced_box_system"],
  "affects_link": true
}
```

The provider dependency floor is finalized at alpha 14.32. Confirm load order
using the real loader rather than assuming priority direction. Add conflicts
for any discovered mod that replaces
`src.ui.BoxMenu` or owns the same storage actions. Do not claim compatibility
with `gen1_modern_ui` unless tested; the mandatory renderer is Widescreen.

This mod should naturally consume active Widescreen/Battle Art/Menu Icon/Shiny
providers through Widescreen. It must not require or directly query those
optional providers unless a missing public semantic field makes that
unavoidable. Route such a need to the owning agent.

## 10. Explicit non-goals

- Release Pokemon.
- Held items or Move Items; Gen 1 has no held-item system.
- wallpapers, box renaming, markings, multi-select, search or sorting.
- increasing 12 boxes or 20-Pokemon capacity.
- changing capture overflow behavior or encounter tables.
- changing Pokemon stats, moves, DVs, experience or shiny state.
- persistent sparse holes or a parallel storage format.
- Gen 2 Gold/Silver storage support.
- world geometry, camera, voxel staging or battle behavior.
- copying Advanced Box System code/assets.

## 11. Implementation gates

### Gate 0 — provider and engine audit

- Read `MASTER_MOD_GUIDE.md` completely.
- Confirm the installed Gen1Recomp payload version and re-audit the packaged
  storage files if it is newer than 0.1.83.
- Obtain the Widescreen provider release and contract documentation.
- Confirm Widescreen's clamp fix passes before integration testing.
- Inspect every enabled storage-owner manifest and finalize conflicts.

### Gate 1 — pure transaction module

Implement and test transfer/swap/reorder logic without UI. Do not proceed
until all invariants and Yellow edge cases pass.

### Gate 2 — semantic state and native root

Replace only Bill's Pokemon-storage root, preserve CHANGE BOX/PRINT BOX, and
verify all controller flows under a mock provider.

### Gate 3 — Widescreen integration

Register the provider, render every required state, validate icon/portrait
fallbacks and confirm native layers never leak.

### Gate 4 — package and in-game audit

Run Red, Blue and Yellow on 0.1.83 with the canonical mod stack, then build a
flat root-only ZIP. Do not install it automatically.

## 12. Required tests

At minimum cover:

- root row order and total absence of Release;
- 0/1/19/20 Pokemon grids and all 12 viewed boxes;
- static icon frame enforcement plus animated detail portrait token stability;
- long nickname, missing icon/art, shiny/normal, status and four-move detail;
- Withdraw into party sizes 1, 5 and 6;
- Deposit from party sizes 1, 2 and 6 into boxes sized 19 and 20;
- same-box reorder and swap; cross-box transfer and swap; full-box rejection;
- party-to-box, box-to-party and party/box swap with parties sized 1, 5 and 6;
- Yellow starter rejection and exactly-once deposited happiness application;
- `Stats.ensure` exactly when a boxed Pokemon enters party, never on highlight;
- B cancellation at popup, held grid, Party drawer and root levels;
- provider unregister/reload while holding, with no mutation or lost Pokemon;
- Summary round-trip to the same cursor/viewed box;
- `save.currentBox` unchanged by browsing and changed/saved by CHANGE BOX;
- Yellow PRINT BOX still prints the active box;
- controller, keyboard and pointer/touch parity;
- native/Widescreen PC remains functional when provider registration fails;
- coexistence with Widescreen Pokédex, Modern Bag, Unified QOL, Shiny System,
  Battle Art Replacer, Menu Icons, followers and Dramatic Shape.

Every mutation test should compare the complete before/after Pokemon multiset
and assert party/box bounds and dense arrays.

## 13. Visual audit set

Produce and inspect focused 640×360 captures for:

1. full 20-slot box with right detail;
2. partially filled box with empty tail slots;
3. Withdraw popup overlapping the right panel;
4. Move mode holding a Pokemon over empty and occupied targets;
5. Party drawer with six Pokemon and with empty tail slots;
6. cross-box held state and ACTIVE badge distinction;
7. missing icon/Battle Art fallback;
8. native TextBox error over the provider and Summary destination ownership.

Audit at 1× and representative integer/non-integer host scales for clipping,
blur, cursor visibility, long labels and readable PP/stat values.

## 14. Delivery requirements

Return:

- editable source tree;
- manifest, README, contract notes and an explicit license;
- transaction and provider integration tests with exact results;
- visual audit images;
- a flat `gen1_widescreen_grid_box_v0.1.0-alpha.1.zip` in `Releases`;
- archive audit confirming no enclosing folder, duplicate files or copied
  Advanced Box System material;
- exact Widescreen dependency floor and all remaining limitations.

Do not install the ZIP. If another mod needs a change, stop at its ownership
boundary and create the complete provider-agent prompt required by
`MASTER_MOD_GUIDE.md` section 1.1.
