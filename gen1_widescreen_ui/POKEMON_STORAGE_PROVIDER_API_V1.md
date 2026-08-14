# Pokemon Storage Provider API v1

Gen1 Widescreen UI publishes a one-owner, fail-closed presentation contract
for dedicated Pokemon storage implementations. Widescreen draws the complete
640x360 interface and routes semantic input; the provider owns navigation,
validation, transfers, releases, Box selection and every save mutation.

## Registration

```lua
local ok, reason = widescreen.exports.registerPokemonStorageProvider({
  owner = "gen1_widescreen_grid_box",
  apiVersion = 1,
  match = function(state) return state.isGridBox == true end,
  snapshot = function(game, state) return state:immutableSnapshot() end,
  actions = {
    up=fn, down=fn, left=fn, right=fn,
    previousBox=fn, nextBox=fn, select=fn, back=fn,
    selectCell=fn, selectPartySlot=fn, selectPopup=fn,
    selectPartyButton=optionalFn,
    update=optionalFn,
  },
})
```

Exports:

- `pokemonStorageProviderApiVersion = 1`
- `registerPokemonStorageProvider(spec)`
- `unregisterPokemonStorageProvider(owner)`
- `activePokemonStorageProviderOwner()`
- `invokePokemonStorageProviderAction(actionId, game, state, ...)`
- `updatePokemonStorageProviderInput(game, state, dt)`
- `routePokemonStorageProviderKey(game, state, key)`
- `routePokemonStorageProviderPointer(game, state, event)`

The same owner may atomically replace its registration. A competing owner,
unsupported version, malformed descriptor or incomplete mandatory action set
returns `nil, reason`. Only the active owner may unregister.

## Immutable snapshot schema

Every snapshot has `schemaVersion=1` and a `screen` of `withdraw`, `deposit`,
`move`, `party`, `popup`, or `stats`.

- `box={viewedIndex=1..12,activeIndex=1..12,occupancy=0..20,capacity=20,name?}`
- `grid={columns=5,rows=4,selectedIndex=1..20,cells={20 descriptors}}`
- `party={open=boolean,selectedIndex=1..6,slots={6 descriptors}}`
- `partyButton={label="PARTY",selected?,enabled?,disabledReason?}` is optional.
- `selectedRegion="grid"|"partyButton"|"party"|"popup"`
- `held` is an optional presentation-only Pokemon descriptor.
- `detail` supplies `identityToken`, `speciesId`, `name`, optional
  `speciesName`, `nicknamed`, and `gender`, then `level`, `hp`,
  `maxHp`, optional `status`, `stats={hp,attack,defense,speed,special}`,
  one or two `types`, up to four `moves={name,pp,maxPp,type?}`, `shiny?`, and
  an optional read-only `presentation` copy used only for art resolution.
- `popup={title?,selectedIndex,rows={{id,label,enabled?,disabledReason?}}}`
- `title`, `footer`, `statusText`, and `hints` are optional presentation text.

A populated grid/Party/held descriptor supplies `identityToken`, `speciesId`,
`name`, optional `enabled`, `disabledReason`, `shiny`, a static `icon`
descriptor, and optional read-only `presentation`. Any populated or empty target
may provide `state="occupied"|"empty"|"held_origin"|"valid_target"|
"valid_swap"|"invalid_target"`. An empty slot is `{empty=true}` plus any
optional target fields. Widescreen renders every semantic state with a distinct
border/corner/line pattern, so meaning does not depend on color. Providers must
not expose `save`, `boxes`, `inventory`, `game`, or another mutable backing
store.

`box.viewedIndex == box.activeIndex` draws the `ACTIVE` badge. Browsing with
`previousBox`/`nextBox` never changes `activeIndex` in the presenter; only the
provider may change the active capture Box. A highlighted disabled grid cell,
Party slot, PARTY button, or popup row displays its `disabledReason` in the
footer. Long detail labels are clipped to their assigned bounds. `speciesName`
is shown only when `nicknamed=true`; `gender` accepts `male`/`female`, `M`/`F`,
the corresponding symbol, or provider display text.

Pointer/touch activation of `partyButton` invokes `selectPartyButton` when the
provider supplies it. For backwards compatibility, Widescreen falls back to
the required focus-aware `select` action when that optional action is absent.
Keyboard/controller A continues to use the single semantic `select` action, so
the provider remains the sole focus and navigation authority.

## Ownership and failure behavior

Widescreen forces icon frame 1, while the selected portrait uses Battle Art
Presentation API v1 with a stable identity token and ROM 2D fallback. Stadium
and voxel modes are never flattened. TextBox and ChoiceBox compose above the
grid; Summary remains an opaque destination.

For a matching state, native drawing is suppressed. A later invalid snapshot
retains that exact state's last valid opaque view and displays a deduplicated,
actionable provider error. Registration, replacement, unregistration and mod
reload invalidate views, hit regions, icon references and portrait tokens.

Minimum consumer dependency for the completed presenter fields:
`gen1_widescreen_ui >= 0.1.0-alpha.14.32 < 0.2.0`.
