# Next Agent Brief — Widescreen Modern Bag

Last updated: **2026-08-11**

## Authoritative implementation override (2026-08-11)

The approved design below supersedes every conflicting parity requirement in
the original audit sections of this document:

- Six pockets only: Medicine, Poke Balls, TM/HM, Battle Items, Key Items and
  Items. Medicine opens by default; unknown items safely fall back to Items.
- No Favorites, pins, search, machine filters, preference persistence or
  automatic sorting.
- SELECT performs vanilla-style manual item swapping and persists the result
  through the engine's `Bag.order`. Manual movement is disabled for TM/HM.
- START explicitly cycles and applies Alphabetical, Type and Quantity sorting
  to the current non-machine pocket. Inventory changes never trigger sorting.
- TM/HM is always HMs numerically first, then TMs numerically.
- Distinct-item capacity and valid finite stacks are expanded to serialization-
  safe limits.
- The right panel supplies plain useful information for every item and machine.
  Contextual availability text is restricted to Battle Items; engine gameplay
  code remains authoritative for actual item use.
- Gen1 Widescreen UI is the sole presenter through Bag Provider API v2,
  requiring `gen1_widescreen_ui >= 0.1.0-alpha.14.25 <0.2.0`.

The active implementation is `gen1_widescreen_modern_bag` version
`0.1.0-alpha.5`. Treat the remaining historical Modern Bag 1.5.2 material as
reference audit only, not as feature requirements.

## 1. Mission

Create a new Bag mod for Invoker's Gen1 Recomp compilation by recreating the
useful behavior of the installed **Modern Bag 1.5.2**, with two deliberate
changes:

1. **Gen1 Widescreen UI is a mandatory dependency and the sole presenter.**
   There is no native 160×144 Bag fallback in this project.
2. **Every supported inventory item has an icon.** The user will provide the
   art. The implementation must define, validate and render the icon set by
   stable item ID.

Working title: **Widescreen Modern Bag**  
Provisional manifest ID: `gen1_widescreen_modern_bag`

The ID and title are provisional until implementation, but do not reuse the
reference ID `modern_bag`.

Read `MASTER_MOD_GUIDE.md` before implementation. Also read the active design
documents whose ownership overlaps this mod, especially Yellow Legacy,
Unified Quality of Life and the Widescreen Dex Radar.

## 2. Reference material audited

Read-only installed reference:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\modern_bag`

Audited files:

- `manifest.json`
- `main.lua`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`
- `tests/modern_bag_test.lua`
- `tests/modern_ui_compat_test.lua`

Reference facts:

- Version `1.5.2`, Mod API 2, content profile, UI category, priority 520.
- It requests `engine_internals`.
- It divides the Bag into seven pockets.
- It adds persistent Favorites and pinned items, temporary manual reordering,
  automatic sorting, general search, TM/HM filters and move information.
- It removes the distinct-item limit and the 99-per-stack limit.
- It decorates the engine's original `BagMenu`, so item actions remain owned by
  the engine.
- Its `gen1_modern_ui` dependency is optional and uses compatibility API v1;
  otherwise it draws at 160×144.
- Its MIT license permits reuse and modification, but the copyright notice and
  permission text must accompany copied or substantially reused code.

Do not modify the installed reference. Build in a separate source directory.

## 3. Required feature parity

The first complete version must preserve all user-facing Modern Bag 1.5.2
behavior unless this brief explicitly changes it.

### 3.1 Pockets

Use this order:

1. `favorites` — virtual collection of favorited items.
2. `medicine` — healing, status, revive, PP, vitamin and Rare Candy items.
3. `balls` — all registered Poké Balls.
4. `machines` — TMs and HMs.
5. `battle` — X items, Dire Hit, Guard Spec. and Poké Doll.
6. `key` — key items and non-tossable items.
7. `other` — stones, Repels, Escape Rope, fossils and safe fallback items.

Open on Medicine. Left/Right changes pocket, including wraparound. Remember a
cursor and scroll position per pocket for the current Bag session. The battle
Bag must use the same pocket model without bypassing battle-specific item
validation.

Classification precedence must be deterministic:

1. Explicit machine metadata.
2. Explicit ball metadata.
3. Explicit project classification override, if the new public API provides
   one.
4. Known canonical categories.
5. Conservative inference from engine fields/effect IDs.
6. Key/non-tossable status.
7. `other` fallback.

Never classify by localized display name. Unknown or malformed definitions go
to `other` and remain usable.

### 3.2 Favorites, pins and ordering

- SELECT opens Item Options: add/remove Favorite, pin/unpin, move item, cancel.
- Favorites and pins persist by canonical item ID.
- A zero-count item disappears but retains its saved Favorite/Pin preference
  and returns with that state when reacquired.
- Pinned items appear above unpinned items in their normal pocket.
- Multiple pinned items retain pin order.
- Favorites retain favorite order.
- Automatic sorting runs when the Bag opens and when the set of positive-count
  item IDs changes.
- Non-machine items sort by normalized display label with item ID as a stable
  tie-breaker. Machines sort HM before TM, then numerically by default.
- Manual Move Item ordering lasts for the current Bag session; reopening
  reapplies automatic sorting. Do not imply that temporary ordering persists.

Show Favorite and Pin status visually in Widescreen. Do not rely only on the
reference's `F`, `P` and `PF` text: use clear iconography or badges plus an
accessible textual state in the semantic model.

### 3.3 Search

- START opens Quick Search outside the machine pocket.
- Search all positive-count inventory items across all pockets.
- Match normalized display name and canonical item ID.
- Empty search returns the whole Bag alphabetically.
- Choosing a result returns to its real pocket with that item selected.
- Preserve controller and keyboard operation and support pointer/touch through
  Widescreen's semantic action system.
- Keep the reference query limit of 12 characters unless a tested Widescreen
  layout supports a larger explicit limit.

Widescreen owns keyboard layout, focus, hit targets and drawing. The Bag mod
owns query state, normalization, result construction and selection callbacks.

### 3.4 TM/HM tools

The machine pocket must provide:

- Search by the contained move's name.
- Type filter.
- Generation I class filter: Physical, Special or Status.
- Sort by machine number, move name, power descending or power ascending.
- Combined filters.
- Move Information with machine code, move name, type, Gen I class, power,
  accuracy, PP and readable effect.
- Y on controller and I on keyboard as the information shortcut, without
  replacing the engine's existing input handlers.

Generation I class rules are type-based. Normal, Fighting, Flying, Poison,
Ground, Rock, Bug and Ghost are Physical; Fire, Water, Grass, Electric,
Psychic, Ice and Dragon are Special; zero-power moves are Status. Read the
effective merged move/type data so balance mods are reflected live.

Pinned machines stay above unpinned machines under every sort mode.

### 3.5 Unlimited inventory

Retain both reference changes:

- Unlimited distinct item types.
- Stack counts above 99.

“Unlimited” means no artificial gameplay cap; values must still be finite,
non-negative integers and must serialize safely. Do not blindly trust
`math.huge` as save data, and do not store it as a count.

Patch the narrowest inventory capacity/addition surfaces supported by the
current engine. Preserve downstream hooks and validators. Invalid IDs,
non-positive quantities and unusual calls must delegate to the original
function. Item removal, use, sale, teaching, throwing, targeting and field
effects remain engine-owned.

Add boundary tests for 99→100, large finite stacks, a new item beyond the
vanilla slot cap, zero/removal, badges, invalid quantities and save/reload.

## 4. Mandatory Widescreen dependency

This is not merely a cosmetic recommendation. The dependency must exist at
both package and runtime levels.

Conceptual manifest requirement:

```json
"dependencies": [
  { "id": "gen1_widescreen_ui", "version": ">= REQUIRED_BAG_API_VERSION" }
]
```

Use the actual launcher schema after inspecting current manifests. The current
Widescreen release (`0.1.0-alpha.7.12`) does not yet publish a Bag presenter
contract, so `REQUIRED_BAG_API_VERSION` cannot honestly be filled in today.
The Widescreen owner must first implement and version that contract. Bump the
Widescreen provider and this consumer's dependency floor together.

Required behavior:

- Widescreen registers a generic semantic Bag presenter.
- The Bag mod supplies models, state and callbacks; it does not draw a parallel
  native Bag.
- Widescreen owns the 640×360 layout, list viewport, detail panel, pocket tabs,
  focus, scrolling, keyboard, modal placement, pointer/touch hit regions,
  fonts and icon drawing.
- The Bag mod owns pockets, classification, inventory-derived rows, Favorites,
  pins, sort/filter/search state and item action delegation.
- The Widescreen mod must not depend on this Bag mod. Dependency direction is
  one-way to avoid a cycle.
- If the manifest dependency is somehow present but the required export/API is
  missing, log one actionable incompatibility error and do not patch BagMenu.
- Never silently expose the reference 160×144 renderer.
- While this Bag mod is enabled, its Bag presentation cannot be independently
  disabled in Widescreen. Either hide/lock that Widescreen option or show an
  explicit dependency warning rather than falling back to native rendering.

### 4.1 Minimum Widescreen presenter contract

Finalize names with the Widescreen owner, but the contract must support at
least:

```lua
registerBagProvider({
  owner = "gen1_widescreen_modern_bag",
  apiVersion = 1,
  match = function(state) ... end,
  model = function(game, state) ... end,
  actions = {
    select = function(game, state) ... end,
    back = function(game, state) ... end,
    pocketLeft = function(game, state) ... end,
    pocketRight = function(game, state) ... end,
    search = function(game, state) ... end,
    tools = function(game, state) ... end,
    info = function(game, state) ... end,
  }
})
```

The semantic model should include:

- Stable screen ID and mode (`field`, `battle`, `search`, `machine_filter`,
  `move_info`, `item_options`).
- Pocket IDs, labels, selected pocket and enabled state.
- Rows with stable item ID, display label, count, selected/enabled state,
  Favorite/Pin state, category and icon descriptor.
- Selected row index/ID, scroll information and contextual description.
- Money when relevant.
- Contextual action labels and input hints.
- Search query/grid/results or machine filter/sort state.
- Move-information fields.
- Explicit native-draw suppression.

Return fresh or treated-as-immutable snapshots. Do not let the presenter mutate
inventory tables directly.

## 5. Item-icon system

The supplied icons belong to this Bag package. Widescreen renders them through
the semantic descriptor; Widescreen must not hardcode a second item-ID map.

### 5.1 Stable identity and mapping

- Resolve icons by the exact canonical item ID from merged `game.data.items`.
- Maintain an explicit `item_icons.lua` mapping instead of deriving filenames
  from display names.
- Normalize only at the mapping/import boundary. Detect case collisions and
  duplicate aliases as build errors.
- Badges and internal records that can never enter inventory are outside the
  visible icon requirement. Document every exclusion.
- Include every base-game item that can appear in the Bag and every planned
  compilation item known at release time, including Yellow Legacy's Crystal
  Tear if it is implemented as an inventory item.

“Icons for all items” cannot safely mean every future third-party item. For an
unknown mod-added ID, render a visible generic icon selected from its resolved
pocket, never a blank cell or crash. The release completeness audit must still
fail for a missing icon belonging to the base game or a declared supported mod.

### 5.2 Asset contract

The user will provide the final art. Before coding the asset loader, inventory
the delivered files and record their actual dimensions, color mode, naming and
license/source status. Do not invent missing art or silently stretch a mixed
set.

Target rendering contract:

- RGBA PNG with transparent background.
- One logical icon per file or a documented, machine-verifiable atlas schema.
- Recommended logical cell: **32×32** on the 640×360 canvas.
- Nearest-neighbor filtering only.
- Integer coordinates and integer scale.
- Preserve aspect ratio and center smaller art within the cell.
- No fractional resampling, blur or per-item magic offsets unless a visual
  audit proves and documents the exception.

If the supplied source dimensions differ, keep the originals and normalize at
draw time or through a reproducible build step. Do not manually edit hundreds
of files without an auditable script.

Because release ZIPs must be flat/root-only, nested `assets/items/...` entries
are prohibited. Use root-level icon files with a collision-safe prefix, or one
root-level atlas plus root-level metadata. Audit the actual ZIP entry list.

### 5.3 Resolver and cache contract

Expose a narrow read-only API, with final names versioned:

```lua
exports.itemIconApiVersion = 1
exports.resolveItemIcon(itemId) -- descriptor or fallback descriptor
exports.hasDedicatedItemIcon(itemId)
exports.auditItemIcons(game)    -- missing, excluded, fallback, duplicate data
exports.invalidateItemIconCache()
```

Recommended descriptor:

```lua
{
  itemId = "SUPER_POTION",
  imagePath = ".../bag_item_super_potion.png",
  sourceW = 32,
  sourceH = 32,
  fallback = false,
  category = "medicine"
}
```

Cache decoded images by resolved descriptor/path, not by display name. Provide
cache invalidation for mod reloads and icon-set changes. A bad/missing PNG must
degrade to the visible category fallback and emit a deduplicated warning.

### 5.4 Icon placement

- Show the icon on every normal Bag row, Favorites row and search result.
- Keep the selected item's icon permanently visible in the detail panel.
- Show an appropriate icon on Item Options and item-use confirmation overlays
  where the semantic model identifies the item.
- TM/HM rows use their item icon; move type badges are separate presentation
  data and do not replace the item icon.
- Favorite/Pin markers must not overlap the item icon, quantity or selection
  cursor.
- Long counts above 99 must not collide with the icon or item name.

## 6. Compatibility with the compilation

### 6.1 Yellow Legacy recreation

- Classify new key items from live metadata or an explicit registered override.
- Add a dedicated icon for Crystal Tear if it enters the inventory.
- Do not duplicate Yellow Legacy item effects, Hard Mode restrictions, shop
  rules or quest state.
- Search/sort and move information must reflect Yellow Legacy's effective
  merged names and move data.

### 6.2 Unified Quality of Life

- QOL owns Repel prompting, fishing shortcuts, Catch Helper and EXP policy.
- This Bag may present current inventory state and invoke the original item
  action, but it must not reimplement those mechanics.
- If QOL blocks or redirects an item action, preserve that result by delegation.

### 6.3 Reusable Machines and other item-behavior mods

- Do not consume or restore TMs locally.
- Read live machine metadata and delegate teaching/consumption.
- Preserve wrapper chains: never assume this mod is the only `Bag.add` or
  `BagMenu.new` decorator.
- Test both load orders where another supported mod decorates BagMenu.

### 6.4 Widescreen Dex Radar and spawn mod

No data dependency or shared state. They share only Widescreen's generic
presentation layer. Do not read encounter tables from the Bag.

### 6.5 Art, Shiny, follower and world mods

No ownership overlap. Item icons are not Pokémon battle art, shiny art,
followers or overworld sprites. Do not touch world camera, map geometry,
collision, voxel rendering or battle models.

## 7. Conflict and migration policy

Declare a conflict with `modern_bag`; enabling both would duplicate BagMenu,
ordering and capacity ownership. Also inspect the live installed mod set before
release for any other mod that owns pockets, Favorites/pins or inventory caps.

Use namespaced save keys. Suggested schema:

```lua
preferences = {
  schemaVersion = 1,
  favorites = { "POTION", ... },
  pinned = { "BICYCLE", ... },
  machineSort = "NUMBER"
}
```

Do not automatically import the reference mod's save namespace unless the
launcher provides safe read-only access and the user explicitly wants a
migration. Never delete another mod's saved data.

## 8. Proposed package

Root-only contents, subject to the supplied icon format:

```text
manifest.json
main.lua
item_icons.lua
README.md
CHANGELOG.md
LICENSE
bag_item_*.png
```

If an atlas is preferable:

```text
manifest.json
main.lua
item_icons.lua
item_icons.png
item_icons.json
README.md
CHANGELOG.md
LICENSE
```

Do not include both layouts without a reason. Do not include source ROM data.
Retain the reference MIT notice if any reference implementation is copied or
substantially reused, and record the provenance/license of the supplied icons.

## 9. Required tests

### 9.1 Lua behavior tests

- Seven pockets, default pocket and wraparound.
- Canonical and modded classification, including unknown fallback.
- Automatic sort, HM/TM order, per-pocket cursor restoration.
- Favorites/pins persistence across zero count and reacquisition.
- Temporary manual move behavior.
- General search normalization and jump-to-pocket.
- TM/HM name/type/class filters, all sort modes and move details.
- Gen I physical/special/status classification.
- Field Bag and battle Bag item-action delegation.
- Y/I binding chains original handlers.
- Unlimited slots/stacks and serialization boundaries.
- Coexistence with supported Bag/item wrappers in both load orders.

### 9.2 Dependency/contract tests

- Manifest rejects absent or too-old Widescreen UI.
- Runtime contract mismatch leaves BagMenu unpatched and reports one clear
  error.
- Successful registration suppresses native draw for all Bag-owned screens.
- Widescreen-disabled Bag presentation cannot expose the native Bag.
- Semantic models contain no live mutable inventory references.
- Keyboard, controller and pointer/touch actions call the same behavior.

### 9.3 Icon tests

- Enumerate all merged inventory-capable items.
- Dedicated icon coverage passes for base game and declared supported mods.
- Every mapping points to an existing decodable RGBA PNG/valid atlas region.
- Detect duplicate mappings, filename case collisions and undocumented
  exclusions.
- Unknown third-party item uses the correct visible fallback.
- Missing/corrupt dedicated icon warns once and uses fallback.
- Nearest filtering and cache invalidation are verified.

### 9.4 Visual matrix

Capture at least:

- Each of seven pockets, empty and populated.
- Long item names and counts of 1, 99, 100 and a large finite value.
- Favorite, pinned and combined status.
- General search keyboard/results.
- TM/HM filters and Move Information.
- Item Options modal.
- Battle Bag.
- Pointer hover/focus and controller focus.
- 16:9 target and the narrowest supported Widescreen fallback.
- Missing-icon fallback.

Check clipping, icon sharpness, tab legibility, text baselines, action-hint
collisions and the absence of native 160×144 layers.

### 9.5 Package audit

- Flat ZIP with root-only entries.
- Unique manifest ID and correct version/dependency floor.
- Conflict with `modern_bag`.
- Required permissions are no broader than the implementation needs.
- README documents Widescreen as mandatory and lists supported icon coverage.
- License/provenance files included.
- Import manually through the launcher; never auto-install.

## 10. Implementation order

1. Read the master guide and overlapping design documents.
2. Inspect the current Widescreen source, manifest and tests.
3. Design and land the generic Widescreen Bag presenter/API first.
4. Bump Widescreen and choose the real dependency floor.
5. Re-audit the current engine Bag/BagMenu implementation and supported
   item-behavior wrappers.
6. Implement Bag semantics without native drawing.
7. Inventory the user-supplied icon files and freeze their mapping/provenance.
8. Implement the icon resolver, fallbacks, audit and Widescreen rendering.
9. Add persistence, search, TM/HM tools and unlimited capacity with tests.
10. Run behavior, dependency, icon, load-order and visual audits.
11. Build a new flat ZIP in `Releases`; do not install it.

## 11. Decisions that must be verified before coding

1. Exact Widescreen Bag presenter API and version floor.
2. Final manifest ID and display name.
3. Actual dimensions, naming and provenance/license of the supplied icons.
4. Exact base-game inventory-capable item registry in the current engine.
5. Which planned mod-added items exist at the first release.
6. Whether the current engine safely serializes very large finite stack counts.
7. Supported load-order behavior with Reusable Machines and any other Bag
   decorators present in the user's mod list.

Do not guess these values in production code. Record the verified answers in
the README and tests.

## 12. Definition of done

The project is complete only when:

- Widescreen UI is an enforced package/runtime dependency.
- Every Bag-related screen is drawn through Widescreen with no native fallback.
- Modern Bag 1.5.2 behavior listed in this brief is preserved.
- Item effects and external gameplay rules still delegate to their owners.
- Every base/declared-supported inventory item has a verified dedicated icon.
- Unknown future items have visible category fallbacks.
- All behavior, dependency, compatibility, icon and visual tests pass.
- The release ZIP is flat, licensed, versioned and not auto-installed.
