# Gen1 Widescreen UI — Pokemon Storage Provider v1 Presenter Completion Request

Date: **2026-08-13**

Owner: **Gen1 Widescreen UI** (`gen1_widescreen_ui`)

Current verified version: **0.1.0-alpha.14.31**

Public surface: `pokemonStorageProviderApiVersion = 1`, documented in
`gen1_widescreen_ui/POKEMON_STORAGE_PROVIDER_API_V1.md` and implemented in
`gen1_widescreen_ui/main.lua`.

Blocked consumer: **Widescreen Grid Box** (`gen1_widescreen_grid_box`)
`0.1.0-alpha.1`, which owns dense native storage navigation and transactions
but delegates every 640x360 draw and pointer hit region to Widescreen.

## Verified problem

Registration, snapshot validation, action routing, opacity and basic grid/detail
drawing exist and are usable. However, inspection of alpha 14.31's
`drawPokemonStorageScreen` and `drawStorageDetail` verifies these mismatches
with the accepted request and Grid Box handoff:

1. `snapshot.box.activeIndex` is validated but never rendered, so the required
   `ACTIVE` badge cannot appear and browsing Box 8 is visually ambiguous from
   changing the active capture Box.
2. The v1 renderer has no visible or pointer-addressable `PARTY` button. The
   consumer can expose `partyButton` semantics and controller navigation, but
   Widescreen currently draws and registers hit regions only for grid cells,
   party slots, popup rows and the two box-header halves.
3. Cell/slot `enabled`, `disabledReason`, and consumer semantic target states
   are ignored. Held origin, valid empty transfer, valid occupied swap and
   invalid dense-tail/full/last-party targets therefore look identical.
4. The detail renderer shows nickname/name, type, portrait, level, HP, four
   non-HP stats, moves and status, but has no species-when-nicknamed or gender
   presentation despite the requested detail model.
5. Popup rows dim when `enabled=false`, but `disabledReason` is not shown.

These are verified presenter omissions, not transaction defects. The consumer
already exports stable record tokens, newly built semantic snapshots, the
ACTIVE distinction, target state strings, disabled reasons, `speciesName`,
`nicknamed`, `gender`, and `partyButton`. It does not and must not draw them.

## Smallest owner-side change

Extend the generic Pokemon Storage Provider v1 presenter and its documented
schema to accept and draw:

- `partyButton={label="PARTY",selected,enabled,disabledReason?}` with a
  `select` or dedicated `selectPartyButton` hit action; keep existing required
  actions backward-compatible if possible.
- Optional descriptor `state` values such as `occupied`, `empty`,
  `held_origin`, `valid_target`, `valid_swap`, and `invalid_target`. Draw them
  with shape/pattern/border differences that do not rely on color alone.
- The existing `enabled`/`disabledReason` fields for grid/party targets and
  popup rows, with a concise footer reason for the highlighted disabled target.
- An `ACTIVE` badge whenever `viewedIndex == activeIndex`.
- Optional detail `speciesName`, `nicknamed`, and `gender`; show species only
  when nicknamed and gender only when supplied.

If compatibility policy forbids extending schemaVersion 1, publish
Pokemon Storage Provider API/schema v2 and return the exact new dependency
floor. Do not silently reinterpret browsing as changing `save.currentBox`.

## Ownership boundary and non-goals

Widescreen owns layout, drawing, focus, hit regions, input mapping, static icon
frame enforcement, animated 2D portrait resolution, native-layer suppression
and overlay composition only. Do **not** implement transfers, dense ordering,
party/box limits, Yellow rules, happiness, stats calculation, save writes,
Release, or Grid Box navigation semantics. Do not embed the consumer manifest
ID except in provider diagnostics.

Invalid or later snapshots must retain the last valid opaque view. Provider
replacement/unregister/reload must continue invalidating views, hit regions,
icons and portrait tokens. Stadium/voxel modes must retain the ROM 2D fallback.

## Acceptance tests

1. Render viewed active and inactive Boxes and verify the badge appears only
   for the active one; shoulder browsing must not change active state.
2. Navigate to and click/touch the PARTY button. All input methods must invoke
   the same consumer action and maintain one semantic focus state.
3. Capture held origin, valid empty tail, valid occupied swap and invalid later
   dense-tail/full/last-party targets. Each must be distinguishable in
   monochrome and at 1x scale.
4. Show a nicknamed Pokemon with species and supplied gender; long values must
   remain clipped/wrapped safely.
5. Highlight disabled grid, party and popup targets and show their reason
   without exposing native layers.
6. Re-run all alpha 14.31 storage registration, invalid-snapshot, pointer,
   TextBox/ChoiceBox, Summary and native-PC regression tests.
7. Produce focused 640x360 captures for the grid, held targets, Party drawer
   and disabled popup; audit nearest filtering at integer and non-integer host
   scales.

## Return artifacts

Return changed Widescreen files, finalized schema/action names, updated
contract/manifest/README/source version, exact tests and results, focused audit
images, a new flat root-only Widescreen ZIP, and the exact dependency floor the
Grid Box manifest must require. The consumer will then bump its dependency and
complete Gate 3/4 audits; do not edit the Grid Box mod.
