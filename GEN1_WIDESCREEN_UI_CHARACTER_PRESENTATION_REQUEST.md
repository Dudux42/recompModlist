# Request: consume Character Appearance API v1 in Widescreen player menus

Date: **2026-08-11**

## Owning mod

- Name: **Gen1 Widescreen UI**
- Manifest ID: `gen1_widescreen_ui`
- Current editable version re-audited: `0.1.0-alpha.14.6` (the latest release
  present during this request was alpha 14.5).
- Relevant source: `main.lua`, especially the responsive START presenter, `drawTitleMenu`, and `drawContinueInfo`.
- Current API: manifest API 2. There is no public player-character presentation consumer at these surfaces.

## Dependent mod and blocked use case

- Name: **Gen1 Character Sprite Replacer**
- Manifest ID: `gen1_character_sprite_replacer`
- Current provider version: `0.1.0-alpha.3` (API v1 remains compatible with alpha 1).
- Blocked requirement: the selected FRLG Red/Leaf character must appear consistently in the in-game Widescreen START menu and the title/main-menu Continue presentation. Selection and asset ownership must remain in the Character Sprite Replacer; Widescreen must retain drawing, layout, clipping, and focus ownership.

## Verified evidence

- `gen1_widescreen_ui/main.lua` draws the responsive START presenter directly and suppresses the native START draw while enabled.
- `drawContinueInfo` currently shows text rows for PLAYER, BADGES, POKEDEX, and TIME but resolves no player-character image.
- `drawTitleMenu` likewise has no player-character resolver or portrait slot.
- The Character Sprite Replacer publishes `characterAppearanceApiVersion = 1` and `resolvePlayerPresentation(role, context)`. It returns `nil` in ROM mode and a read-only descriptor for an active pack.

These are verified facts from the current source. The desired portrait layout is a new Widescreen presentation choice, not existing behavior.

## Smallest requested owner-side change

Add an optional Character Appearance API v1 consumer to Widescreen's responsive player-facing menu presenters:

```lua
local provider = mod.find and mod:find("gen1_character_sprite_replacer")
local exports = provider and provider.exports
if exports and exports.characterAppearanceApiVersion == 1 then
  local descriptor = exports.resolvePlayerPresentation(role, {
    game = game,
    save = game and game.save,
    purpose = role,
  })
end
```

Required roles:

- `start_menu` for the converted in-game START screen.
- `main_menu` for the title menu.
- `continue` for the Continue-info page.

The provider currently maps all three to its dedicated 64x96 `main_menu` image. Widescreen should load/draw the returned `imagePath`, preserve aspect ratio, use nearest filtering, and bottom-center it inside a bounded player-portrait region. If layout pressure makes one title subpage unsafe, document that decision explicitly rather than overlapping menu rows.

## Descriptor semantics

```lua
{
  owner = "gen1_character_sprite_replacer",
  apiVersion = 1,
  packId = "frlg_red" or "frlg_leaf",
  subjectId = "PLAYER",
  role = "main_menu",
  imagePath = "...",
  trueColor = true,
  frameW = 64,
  frameH = 96,
  frameCount = 1,
  layout = "static",
  anchorX = 32,
  anchorY = 96,
  logicalFootprintW = 16,
  logicalFootprintH = 16,
  fallback = false,
  genderPresentation = "male" or "female",
}
```

- Treat the descriptor as immutable.
- `nil`, missing provider, unsupported API, missing/corrupt image, or provider error means the existing Widescreen layout remains unchanged.
- Never substitute another character or another pack.
- Re-resolve at draw time or key caches by `packId` plus path. Provider invalidation/option changes must not leave a stale portrait.
- Guard provider calls and deduplicate warnings so an optional integration cannot break the base menu.

## Non-goals

- Do not move character selection or gender semantics into Widescreen.
- Do not patch overworld rendering, collision, camera, maps, battle presentation, Trainer Card, or Hall of Fame.
- Do not decode the original source sheet or duplicate Character Sprite Replacer assets.
- Do not change menu callbacks, input, focus, row ordering, native fallback behavior, or save data.
- Do not make the Character Sprite Replacer mandatory.

## Compatibility and failure rules

- Preserve the 640x360 final-resolution presenter and responsive narrower fallback.
- Preserve existing dialogue composition over START/title screens.
- Preserve all current Battle Art title-Pokemon behavior; the player portrait is separate and must not displace the title Pokemon resolver.
- Use integer final placement and nearest-neighbor filtering.
- ROM mode must look exactly like current Widescreen behavior unless Widescreen deliberately adds a ROM player portrait from an engine-supported seam; do not fabricate one.

## Acceptance tests

1. Provider absent: START, title menu, and Continue page match current behavior.
2. Provider returns `nil`/ROM: current behavior remains.
3. FRLG Red and Leaf each render the correct main-menu asset, aspect ratio intact, bottom anchored, without overlapping text, cursor, footer, or dialogue.
4. Switching Red -> Leaf -> ROM invalidates/re-resolves without a restart or stale image.
5. Provider throws or returns malformed data: warning is isolated and menus remain usable.
6. Test at 640x360 and the existing narrower fallback sizes.
7. Re-run `gen1_widescreen_ui/tests/start_menu_test.lua` plus new provider-present/provider-absent fixtures.
8. Produce focused audit screenshots for START, title menu, and Continue with both characters.
9. Build and audit the standard flat Widescreen ZIP.

## Version and return artifacts

- Bump Widescreen to a new version after `0.1.0-alpha.14.6`; use the owner's actual next version.
- Add `gen1_character_sprite_replacer@>=0.1.0-alpha.1 <0.2.0` as an optional dependency if the manifest contract requires declaring optional consumers.
- The Character Sprite Replacer will then raise its optional Widescreen floor to the released consumer version.
- Return changed files, finalized portrait-region/layout behavior, exact API assumptions, tests run, visual audits, new version, and the flat release ZIP.

Do not install either mod automatically.
