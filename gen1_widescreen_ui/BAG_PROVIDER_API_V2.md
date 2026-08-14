# Gen1 Widescreen UI — Bag Provider API v2

Base v2 dependency: `gen1_widescreen_ui >= 0.1.0-alpha.14.22 <0.2.0`.

Structured machine-detail dependency: `gen1_widescreen_ui >=
0.1.0-alpha.14.26 <0.2.0`.

API v2 completes the one-owner Bag presenter contract with a validated search
keyboard, visible modal focus, physical text routing and screen-aware
directional actions. API v1 remains available unchanged for existing
providers. The provider owns all inventory-derived semantics and mutations;
Widescreen owns drawing, focus presentation, input translation, pointer hit
regions and native-layer suppression.

## Registration and compatibility

```lua
local ok, reason = widescreen.registerBagProvider({
  owner = "gen1_widescreen_modern_bag",
  apiVersion = 2,
  match = function(state) return state.__modernBag == true end,
  snapshot = function(game, state) return freshImmutableSnapshot end,
  actions = {
    select = fn, back = fn, up = fn, down = fn,
    left = fn, right = fn,
    pocketLeft = fn, pocketRight = fn, pocket = fn,
    search = fn, options = fn, info = fn,
    selectIndex = fn, modalIndex = fn,
    keyboardKey = fn, textInput = fn, delete = fn, clear = fn,
  },
})
```

Exports:

- `bagProviderApiVersion == 2`
- `bagProviderCompatibleApiVersions == { [1]=true, [2]=true }`
- `registerBagProvider(spec)`
- `unregisterBagProvider(owner)`
- `activeBagProviderOwner()`
- `invokeBagProviderAction(actionId, game, state, ...)`
- `updateBagProviderInput(game, state, dt)`
- `routeBagProviderKey(game, state, key)`
- `routeBagProviderText(game, state, text)`

Registration by the same owner replaces its descriptor. A different owner is
rejected deterministically. A registered mandatory provider forces the
Widescreen Bag presenter on.

## Common snapshot

The v1 common schema is retained: stable `screen` and `mode`, pockets,
`selectedPocketId`, canonical item rows, selection/scroll, descriptions,
money, hints and optional semantic actions. Counts and money are finite
non-negative integers. Snapshots must not expose mutable `inventory`, `save`
or `game` tables.

For v2 use `schemaVersion = 2`. Screen-specific additions follow.

## Search keyboard

```lua
search = {
  query = "POTION",
  keyboard = {
    columns = 10,
    selectedIndex = 17,       -- or selectedKeyId
    selectedKeyId = "q",     -- both may be supplied if they agree
    keys = {
      { id="a", label="A", value="A" },
      { id="q", label="Q", value="Q" },
      { id="delete", label="DEL", action="delete" },
      { id="clear", label="CLEAR", action="clear" },
      { id="done", label="DONE", action="done" },
    },
  },
}
```

`id` is stable semantic identity; `label` is presenter text. `value` is the
character/string represented by a text key. `action` identifies special keys.
The provider owns the selected key and query. Controller A and pointer/touch
both call `keyboardKey(id)`; Widescreen does not append text itself.

Physical text input calls `textInput(text)`. Backspace/Delete calls `delete`.
The Delete key may represent either backward-delete according to provider
policy. Ctrl+Backspace and Ctrl+Delete call `clear`. All callbacks are guarded.
The provider is responsible for length limits, normalization, matching and
query persistence.

## Focused modal models

`machineFilter` and `item` models expose `lines`, `rows` or `options` plus a
selected row:

```lua
machineFilter = {
  selectedId = "water", -- or selectedIndex
  rows = {
    { id="all", label="ALL MACHINES" },
    { id="water", label="WATER" },
  },
}

item = {
  selectedIndex = 1,
  options = {
    { id="use", label="USE" },
    { id="cancel", label="CANCEL" },
  },
}
```

The presenter highlights the selected row. Controller A calls `select`;
pointer/touch calls `modalIndex(index)`. These are equivalent semantic paths:
the provider resolves both against its current selected/model state.

## Optional structured machine detail

API v2 item rows may include a presenter-owned structured TM/HM detail:

```lua
detail = {
  kind = "machine",
  typeId = "NORMAL",
  parameters = {
    { label="MOVE", value="Bide" },
    { label="CATEGORY", value="Physical" },
    { label="POWER", value="--" },
    { label="ACCURACY", value="Varies" },
    { label="PP", value="10" },
    { label="DESCRIPTION", value="The user endures attacks for two turns, then strikes back with twice the damage received." },
  },
}
```

The provider strings are authoritative. Widescreen draws the type with its
existing badge helper and performs no move lookup, category inference, formula
or gameplay calculation. Scalar values are one line. `DESCRIPTION` alone is
word-wrapped using measured font widths and all remaining panel height;
embedded line breaks are retained and continuation lines use the full panel
width. Unknown excess content is clipped only after all available lines are
used, never passed through the one-line ellipsis helper.

The model is optional. Providers that emit it must declare the structured
machine-detail dependency floor above. Existing v2 snapshots without `detail`
retain their previous presentation and compatibility floor.

## Screen-aware input

Only `screen == "bag"` maps Left/Right to `pocketLeft`/`pocketRight`.
`search`, `machine_filter`, `item_options` and `item_confirmation` map all four
directions to `up`, `down`, `left`, `right`, allowing provider-owned grid or
modal focus. `move_info` keeps `up`/`down`; Left/Right are routed as
`left`/`right` when offered by the provider.

Start opens `search` from the main Bag. Select calls `options`; Y or keyboard
I calls `info`. A calls `select`, except the v2 search keyboard where it calls
`keyboardKey(selectedKeyId)`. B always calls `back`.

## Failure contract

Registration, matching, snapshots, actions, physical-key routes and pointer
routes are protected. Each distinct failure is logged once. An invalid v2
keyboard/modal schema or provider exception produces one opaque actionable
incompatibility page; native Bag layers remain suppressed. The presenter never
silently downgrades an invalid v2 snapshot to v1.

API v1 providers retain their original schema and action mapping. They do not
receive v2 keyboard, text or focused-modal guarantees.

## Ownership boundary

Widescreen does not classify, sort or search items; persist favorites, pins,
queries or filters; mutate inventory; teach moves; use/toss items; implement
battle rules; or depend on the Modern Bag. The consumer supplies fresh
semantic snapshots and authoritative callbacks for all such behavior.
