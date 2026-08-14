# Gen1 Widescreen UI — Bag Provider API v1

This compatibility contract remains supported. New providers that need the
search keyboard, physical text input or selected modal focus should use
[`BAG_PROVIDER_API_V2.md`](BAG_PROVIDER_API_V2.md).

Minimum provider dependency: `gen1_widescreen_ui >= 0.1.0-alpha.14.18 <0.2.0`.

The provider owns inventory-derived semantics and callbacks. Widescreen owns
all 640×360 drawing, responsive/narrow layout, focus, scrolling, input hints,
pointer regions, icons and suppression of provider-owned native layers.

## Registration

```lua
local ok, reason = widescreen.registerBagProvider({
  owner = "gen1_widescreen_modern_bag",
  apiVersion = 1,
  match = function(state) return state.__modernBag == true end,
  snapshot = function(game, state) return freshSnapshot end,
  actions = {
    select = fn, back = fn, up = fn, down = fn,
    pocketLeft = fn, pocketRight = fn, pocket = fn,
    search = fn, options = fn, info = fn,
    selectIndex = fn, modalIndex = fn,
  },
})
```

Exports:

- `bagProviderApiVersion == 1`
- `registerBagProvider(spec)`
- `unregisterBagProvider(owner)`
- `activeBagProviderOwner()`
- `invokeBagProviderAction(actionId, game, state, ...)`
- `updateBagProviderInput(game, state, dt)`

Registration by the same owner replaces its descriptor. A different owner is
rejected deterministically. While registered, the Widescreen Bag option is
forced on.

## Snapshot schema

Every `snapshot()` call returns a fresh/read-only semantic table:

```lua
{
  schemaVersion = 1,
  screen = "bag", -- bag/search/machine_filter/move_info/item_options/item_confirmation
  mode = "field", -- field/battle
  title = "BAG",
  pockets = {
    { id="medicine", label="MEDICINE", enabled=true },
  },
  selectedPocketId = "medicine",
  rows = {
    {
      itemId="POTION", label="POTION", count=4, enabled=true,
      favorite=false, pinned=false, category="medicine",
      description="Restores HP.",
      icon={ image=image }, -- or imagePath/path; omission uses visible fallback
    },
  },
  selectedIndex = 1,
  scroll = 0,
  description = "Optional selected-row description override.",
  money = 2541,
  hints = "A SELECT   B BACK   L/R POCKET",
  actions = { { id="select", label="USE" } },

  -- Required only by the matching modal screen:
  search = { query="POT", lines={"POTION"} },
  machineFilter = { lines={"TYPE: WATER", "SORT: NUMBER"} },
  move = { lines={"WATER", "POWER 40", "PP 25"} },
  item = { lines={"USE", "FAVORITE", "PIN", "CANCEL"} },
}
```

Rows are keyed by canonical `itemId`; counts and money must be finite,
non-negative integers. Pocket IDs and row IDs must be unique. Snapshots must
not expose live `inventory`, `save` or `game` tables. Widescreen never sorts,
classifies, searches, persists or mutates provider data.

## Input/action mapping

- A → `select`
- B → `back`
- Up/Down → `up`/`down`
- Left/Right → `pocketLeft`/`pocketRight`
- Start → `search`
- Select → `options`
- Y or keyboard I → `info`
- Pocket tab pointer → `pocket(id)`
- Row pointer → `selectIndex(index)`
- Modal row pointer → `modalIndex(index)`

The provider decides what each action means for the current stable `screen`.
Item effects, confirmation semantics and inventory mutation remain outside
Widescreen.

## Failure contract

Provider calls are protected. Distinct failures are logged once. If an owned
Bag snapshot is invalid or throws, Widescreen draws an opaque actionable
incompatibility page and never reveals the native Bag beneath it. Missing or
corrupt icons render a visible category fallback and log one deduplicated
diagnostic.
