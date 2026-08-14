# Widescreen Grid Box contract notes

Version: **0.1.0-alpha.1**

## Required provider

The mod consumes Gen1 Widescreen UI Pokemon Storage Provider API v1:

- provider ID: `gen1_widescreen_ui`;
- API export: `pokemonStorageProviderApiVersion == 1`;
- current dependency floor: `>=0.1.0-alpha.14.31 <0.2.0`;
- owner registration: `gen1_widescreen_grid_box`.

Registration must succeed before `src.ui.BoxMenu.new` is decorated. Failure
leaves the native BoxMenu unchanged. The provider snapshot never exposes the
game, save, party, Boxes or live Pokemon records. Every descriptor and detail
model is rebuilt; only stable scalar identity tokens cross the boundary.

## Snapshot extensions awaiting generic presenter support

The alpha.1 semantic model emits optional fields beyond the documented minimum:

- descriptor `state`: `occupied`, `empty`, `held_origin`, `valid_target`,
  `valid_swap`, or `invalid_target`;
- descriptor `enabled` and `disabledReason`;
- detail `speciesName`, `nicknamed`, and optional `gender`;
- `partyButton={label,selected,enabled,action}`.

Unknown fields are accepted by API v1 validation. Widescreen alpha 14.31 does
not yet present them; see the root-level
`WIDESCREEN_STORAGE_PROVIDER_V1_COMPLETION_REQUEST.md`. If the owner publishes
API v2 instead of a backward-compatible v1 extension, this consumer must bump
its API constant and manifest dependency before release.

## Mutation boundary

All transfer, reorder and swap commits route through `storage_core.lua`.
Pickup stores a live origin identity only inside the transient local state and
does not mutate storage. The transaction validates source identity, dense tail
semantics, counts, capacities, party minimum/maximum and Yellow departure rules
before replacing container contents. Callback failure restores both arrays,
Pokemon stats/HP fields and Yellow happiness/mood fields.

`Stats.calc` is used only on a detached presentation copy. Native
`Stats.ensure` runs on the actual record exactly when a boxed Pokemon enters
the party. Native `PikachuFollower.modifyHappiness(..., "DEPOSITED", mon)` runs
exactly once after a successful party-to-box commit.

CHANGE BOX and Yellow PRINT BOX remain the engine's original menu callbacks;
ordinary browsing changes only `viewedBox`.
