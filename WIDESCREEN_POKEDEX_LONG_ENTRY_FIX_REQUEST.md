# Widescreen owner request: bounded Pokédex entry scrolling

**Resolved:** returned in `gen1_widescreen_ui` `0.1.0-alpha.14.1`; both the
Widescreen and consumer regression suites pass.

Status: **Implemented by Gen1 Widescreen UI 0.1.0-alpha.14.1.** The API v2
schema and semantic action contract remain unchanged; the bounded entry
viewport, focus, controller/keyboard mapping and pointer affordances are owned
entirely by the Widescreen presenter.

## Target

- Owner mod: `gen1_widescreen_ui`
- Audited returned build: `0.1.0-alpha.14.0`
- Consumer: `gen1_widescreen_pokedex` (`Pokedex Provider API v2`)

## Verified defect

The v2 presenter wraps `detail.entry`, but `drawPokedexProviderMain` draws only
the first five lines:

```lua
local lines = wrapRenderedText(fonts.small, entry, detailW - 38)
for i = 1, math.min(5, #lines) do
  g.print(lines[i], detailX + 18, detailY + 151 + (i - 1) * 18)
end
```

In `gen1_widescreen_ui/main.lua` alpha 14.0 this is at lines 1082-1085.
There is no entry-text scroll state or input route, so line six and later are
silently discarded. This violates the Pokédex handoff requirement that the
final entry lines remain reachable in a bounded scroll region.

## Requested owner-scoped change

Keep all layout, focus, input and drawing ownership in Widescreen. Add a
bounded five-line viewport for the wrapped main-entry text and make every line
reachable. The smallest acceptable contract extension is:

1. Store transient entry scroll per provider state and selected species.
2. Clamp it to `0 .. max(0, #wrappedLines - 5)` whenever the snapshot changes.
3. Establish an explicit focus/input path for the detail entry that does not
   steal normal species-list or submenu navigation. Controller/keyboard must be
   sufficient; pointer wheel or clickable affordances should use the same path.
4. Draw five lines starting at the clamped offset and show a visible scroll
   affordance whenever undisplayed lines remain above or below.
5. Clear or restore the offset deterministically when selection changes; do
   not allow one species' offset to hide the beginning of another entry.
6. Keep the semantic provider free of coordinates, fonts, clipping and raw
   input polling.

If API v2 needs new semantic actions or focus metadata, validate them in the
contract and expose them through the existing guarded action/input dispatch.
Do not solve this by raising the fixed line cap: modded/localized entries can
still exceed any such cap.

## Acceptance tests

- A fixture entry wrapping to at least eight lines opens at line one.
- The user can reach and visibly read the final line.
- Scrolling is clamped at both ends and never indexes outside the wrapped text.
- A short entry remains unchanged and has no misleading scroll affordance.
- Changing species cannot inherit an invalid or hidden starting offset.
- Species-list selection, the five-row submenu, research-page navigation, Back,
  controller/keyboard input and pointer hit regions continue to work.
- Seen/unowned and unseen privacy behavior remains unchanged.
- Existing `start_menu_test.lua` passes with a regression fixture for the long
  entry.

## Return contract

Please return a version-bumped flat Widescreen release ZIP and the exact new
version. The Pokédex provider will raise its dependency floor to that version,
run both suites, and only then create its own release ZIP.
