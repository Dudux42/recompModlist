# Gen1 Recomp Mod Compilation — Master Agent Guide

Last updated: **2026-08-14**

This is the canonical handoff document for agents working on Invoker's Gen1
Recomp mod compilation. Read it before studying, modifying, packaging, or
creating any mod in this collection.

## 1. Non-negotiable user requirements

1. **Never install a build automatically.** Produce a ZIP and let the user
   import it through the launcher.
2. **Do not alter overworld geometry from UI work.** The widescreen project may
   change UI/HUD presentation, but it must not change the map surface, camera,
   collision, voxel layout, world zoom, or Dramatic Shape geometry.
3. **Use flat/root-only release ZIPs.** The Gen1 Recomp launcher has previously
   thrown stack-overflow/copy-tree errors when importing nested release trees.
4. **Preserve compatibility with Dramatic Shape and Battle Art Voxel Fork.**
   Never flatten Stadium-mode 3D models into UI images. UI portraits are 2D
   only and must use a safe fallback when the selected battle mode is 3D.
5. **Preserve active external art providers.** Menu and summary portraits must
   consult the live battle-art resolver rather than pinning one cached mod.
6. **Use nearest-neighbor filtering for pixel art.** Do not blur icons,
   followers, fonts, borders, or type badges through linear filtering or
   fractional intermediate scaling.
7. **Do not overwrite unrelated user changes.** Installed mods are reference
   material unless the user explicitly asks for installation or direct edits.
8. **Retain attribution and licenses.** ROM-derived art is never accompanied by
   a ROM. Third-party MIT material must keep its license in the package.
9. **Route cross-mod fixes to the owning agent.** If the assigned mod requires
   a fix, export, contract, asset, or behavior change in another mod, do not
   implement that change inside the dependent mod and do not edit the provider
   mod yourself. Provide the user with a ready-to-send prompt for the specific
   provider/owner agent describing the required change. Continue only with
   work that remains valid without crossing that ownership boundary.

### 1.1 Required cross-mod fix prompt

The handoff prompt must be concrete enough for the receiving agent to act
without rediscovering the problem. Include:

1. The owning mod's name, manifest ID, current version, and relevant public API
   or source surface.
2. The dependent mod and the exact blocked use case.
3. Evidence of the problem, including observed behavior, missing contract, or
   failed test; distinguish verified facts from assumptions.
4. The smallest requested provider-side change and its ownership boundary.
5. Explicit non-goals so the receiving agent does not absorb behavior owned by
   the dependent mod.
6. Required API/schema semantics, failure behavior, invalidation/load-order
   rules, and compatibility constraints.
7. Acceptance tests and any required visual/package audit.
8. Version/export changes and the dependency-floor bump the consumer will need.
9. The artifacts the receiving agent should return: changed files, new version,
   tests run, release ZIP if applicable, and the finalized contract details.

Label the dependent work honestly as waiting on that provider change when it
cannot be completed safely. Do not hide the dependency by copying provider
logic, reaching into private tables, or maintaining a second source of truth.

## 2. Canonical releases

The canonical current builds are:

| Mod | Manifest ID | Current version | Release |
|---|---|---:|---|
| Gen1 Widescreen UI | `gen1_widescreen_ui` | `0.1.0-alpha.14.32` | [`Releases/gen1_widescreen_ui_v0.1.0-alpha.14.32.zip`](Releases/gen1_widescreen_ui_v0.1.0-alpha.14.32.zip) |
| Gen1 Bill S.S. Ticket Repair | `gen1_bill_ss_ticket_repair` | `0.1.1` | [`Releases/gen1_bill_ss_ticket_repair_v0.1.1.zip`](Releases/gen1_bill_ss_ticket_repair_v0.1.1.zip) |
| HGSS Menu Icons | `hgss_menu_icons` | `0.1.0-alpha.4` | [`Releases/hgss_menu_icons_v0.1.0-alpha.4.zip`](Releases/hgss_menu_icons_v0.1.0-alpha.4.zip) |
| HGSS Simple Follower | `hgss_simple_follower` | `0.1.0-alpha.18` | [`Releases/hgss_simple_follower_v0.1.0-alpha.18.zip`](Releases/hgss_simple_follower_v0.1.0-alpha.18.zip) |
| Gen1 Shiny System | `gen1_shiny_system` | `0.1.0-alpha.3` | [`Releases/gen1_shiny_system_v0.1.0-alpha.3.zip`](Releases/gen1_shiny_system_v0.1.0-alpha.3.zip) |
| Gen1 Balances | `gen1_balances` | `0.1.0-alpha.2` | [`Releases/gen1_balances_v0.1.0-alpha.2.zip`](Releases/gen1_balances_v0.1.0-alpha.2.zip) |
| Gen1 Battle Art Replacer | `gen1_battle_art_replacer` | `0.1.0-alpha.12` | [`Releases/gen1_battle_art_replacer_v0.1.0-alpha.12.zip`](Releases/gen1_battle_art_replacer_v0.1.0-alpha.12.zip) |
| Gen1 Unified Quality of Life | `gen1_quality_of_life` | `0.1.0-alpha.6` | [`Releases/gen1_quality_of_life_v0.1.0-alpha.6.zip`](Releases/gen1_quality_of_life_v0.1.0-alpha.6.zip) |
| Widescreen Move Inspector | `gen1_widescreen_move_inspector` | `0.1.0-alpha.2` | [`Releases/gen1_widescreen_move_inspector_v0.1.0-alpha.2.zip`](Releases/gen1_widescreen_move_inspector_v0.1.0-alpha.2.zip) |
| Widescreen Pokédex | `gen1_widescreen_pokedex` | `0.1.0-alpha.7` | [`Releases/gen1_widescreen_pokedex_v0.1.0-alpha.7.zip`](Releases/gen1_widescreen_pokedex_v0.1.0-alpha.7.zip) |
| Gen1 Character Sprite Replacer | `gen1_character_sprite_replacer` | `0.1.0-alpha.8` | [`Releases/gen1_character_sprite_replacer_v0.1.0-alpha.8.zip`](Releases/gen1_character_sprite_replacer_v0.1.0-alpha.8.zip) |
| Widescreen Modern Bag | `gen1_widescreen_modern_bag` | `0.1.0-alpha.5` | [`Releases/gen1_widescreen_modern_bag_v0.1.0-alpha.5.zip`](Releases/gen1_widescreen_modern_bag_v0.1.0-alpha.5.zip) |
| Kanto Living Encounters | `kanto_living_encounters` | `0.1.0-alpha.4` | [`Releases/kanto_living_encounters_v0.1.0-alpha.4.zip`](Releases/kanto_living_encounters_v0.1.0-alpha.4.zip) |
| Dramatic Shape Battle Sprite Lighting Patch | `dramatic_shape_battle_shadow_patch` | `0.2.0` | [`Releases/dramatic_shape_battle_shadow_patch_v0.2.0.zip`](Releases/dramatic_shape_battle_shadow_patch_v0.2.0.zip) |

The main `Releases` directory retains at most the latest three semantic
versions of each mod. Older ZIPs are moved, not deleted, to
`Releases/Old versions`.

### 2.1 Verified Gen1Recomp baseline

The installed update audited on 2026-08-13 is **Gen1Recomp 0.1.83**, packaged
at:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\updates\gen1recomp-0.1.83.love`

Its packaged `src/core/Version.lua` reports mod API 2, link protocol 2, save
format 4, cache generation `rom-cache-v5`, payload host `love`, and shell
contract 1. Treat the packaged update as the runtime source of truth: an
editable engine checkout may retain an older release stamp and must not be
used to infer the installed build number.

The engine contains separate Gen 1 and Gen 2 game surfaces. Every project
manifest must explicitly declare `"games": ["gen1"]` unless the mod has been
independently implemented and tested for Gold/Silver. A broad engine version
range is not evidence of Gen 2 compatibility.

Widescreen alpha 14.29 fixed the early EXP-animation `clamp` binding defect
observed under 0.1.83; canonical alpha 14.32 retains that repair and completes
the Pokemon Storage Provider API v1 presenter requested in
`WIDESCREEN_STORAGE_PROVIDER_V1_COMPLETION_REQUEST.md`.

The former development workspace and editable source tree is currently:

`C:\Users\invok\Documents\Codex\2026-08-08\ok`

The canonical release/documentation workspace is:

`C:\Users\invok\OneDrive\Documents\ChatGPT\Gen1 Recomp Mods`

If the development path is unavailable in a future session, extract the
current release ZIPs into a new task-specific development directory. Never
edit or build inside the launcher's installed-mod directory.

## 3. Architecture and dependency policy

The Widescreen UI is the central **presentation integration layer**, but the
art and follower packages remain useful independently.

```text
gen1_widescreen_ui
├── optionally consumes hgss_menu_icons descriptors
└── exposes widescreen party/summary portrait behavior

gen1_shiny_system
├── requires gen1_widescreen_ui
├── optionally integrates hgss_menu_icons
└── optionally integrates hgss_simple_follower

hgss_menu_icons
├── works in the stock Party menu
├── integrates with gen1_widescreen_ui
└── consults gen1_shiny_system when present

hgss_simple_follower
├── owns only one selected party follower
├── works without the UI mod
└── consults gen1_shiny_system when present

gen1_quality_of_life
├── works without the other canonical mods
├── optionally adapts to Widescreen and snapped voxel HUDs
└── owns only explicit overlays, rules, banners and field shortcuts

gen1_widescreen_move_inspector
├── requires gen1_widescreen_ui
├── provides immutable highlighted-move semantics only
└── never draws or changes battle mechanics

gen1_widescreen_grid_box (planned)
├── requires a provider-capable gen1_widescreen_ui release
├── owns storage navigation and atomic party/box transactions
├── removes Release and adds Move Pokemon in Bill's PC
└── delegates every grid, icon, portrait and popup draw to Widescreen
```

`gen1_battle_art_replacer` owns only 2D battle-art resolution, Gen 5/Platinum/HGSS/Emerald/Crystal front
animation, and ROM fallback. It optionally consumes `gen1_shiny_system`
presentation state and exposes both stable still portraits and versioned live
2D presentations to UI consumers.

Current mandatory dependencies:

- `gen1_shiny_system` requires `gen1_widescreen_ui >= 0.1.0-alpha.7.12`.
- `gen1_widescreen_move_inspector` requires
  `gen1_widescreen_ui >= 0.1.0-alpha.9 <0.2.0`.

All other relationships above are optional integrations. Do not silently turn
them into mandatory dependencies. If a shared public contract changes, bump
both the provider and affected consumers and update manifest version ranges.

## 4. Public integration contracts

### 4.1 Shiny state

Every consumer must support both forms of shiny state:

1. Explicit compatibility flag: `mon.shiny == true`.
2. Native Gen 2 DV rule: `Stats.isShiny(mon.dvs)`.

When `gen1_shiny_system` is installed, consumers should prefer its exports:

```lua
exports.isShiny(mon)                 -- logical shiny state + master toggle
exports.hasShinyState(mon)           -- flag/DV state without presentation toggle
exports.shouldUseShinyArt(mon)       -- master + SHINY COLORS + shiny state
exports.colorsEnabled()
exports.introEnabled()
exports.rateKey()
exports.rollShiny(rng)
exports.makeShinyDVs(rng)
exports.applyShiny(mon, data, dvs)
exports.battleImage(game, mon, side)
exports.drawFollowerSparkles(mon, x, y, width, height)
```

Visible-wild consumers requiring spawn/battle identity use Wild Outcome API v1:

```lua
assert(exports.wildOutcomeApiVersion == 1)
local outcome = exports.reserveWildOutcome(optionalRng)
local opts = exports.wildBattleOptions(outcome)
local battle = BattleState.newWild(game, species, level, opts)
```

The outcome exposes a read-only `shiny` boolean. The provider snapshots valid
shiny DVs or an explicit miss at reservation time, consumes the outcome once,
and performs no second rate roll at battle construction. Foreign, altered,
stale, and reused reservations are deterministically rejected. Calls without
provider options keep the ordinary wild wrapper behavior.

Do not make a consumer rely exclusively on `mon.shiny` or exclusively on DVs.
The installed third-party shiny mod exposed exactly why both are necessary.

### 4.2 Battle Art Presentation API v1

Battle Art Replacer alpha 9 is the sole authority for the selected 2D Pokemon
art collection, STATIC/ANIMATED mode, Gen 5/Platinum/HGSS/Emerald/Crystal/FRLG shiny selection, atlas decoding,
authored frame timing, nearest filtering and cache invalidation. UI consumers
must not decode or time its atlases independently.

```lua
battleArt.exports.presentationApiVersion = 1

local presentation = battleArt.exports.resolvePokemonPresentation(
  game,
  mon,
  "front",
  {
    purpose = "title", -- title, pokedex, party, summary, or another string
    token = stableConsumerOwnedTable,
    now = optionalMonotonicTimeInSeconds,
  }
)
```

It returns `nil` for ROM mode, unsupported sides, unknown Pokemon, or missing
assets. A successful result is:

```lua
{
  image = loveImage,
  trueColor = true,
  animated = boolean,
  mode = "static" or "animated",
  artSet = string,
  frameIndex = optionalNumber,
}
```

Resolution rules:

- Gen 5 + ANIMATED returns the current genuine decoded frame using authored
  durations; an atlas is never returned directly.
- Gen 5 + STATIC returns the selected normal/shiny neutral still.
- HGSS + ANIMATED returns the selected normal/shiny two-frame front sequence
  on the provider-owned 500 ms cadence. HGSS + STATIC returns front frame 1.
  The supplied sheet contains poses but no original timing data; do not call
  the HGSS cadence ROM-authored.
- Platinum + ANIMATED returns the selected normal/shiny two-frame front
  sequence on the provider-owned 500 ms cadence; STATIC returns front frame 1.
  Back cells and redundant female sections are never exposed.
- FRLG returns its selected normal/shiny front still in both modes with
  `animated = false`; the source sheet supplies no animation frames.
- Emerald + ANIMATED returns its selected normal/shiny two-pose front sequence
  at the documented provider-owned 500 ms cadence; STATIC returns pose 1.
- Crystal + ANIMATED returns its decoded normal/shiny front sequence using the
  per-species duration table; STATIC returns frame 1. Its final back cell is
  excluded from every asset.
- Gen 5 normal and shiny assets repair only fully enclosed one-to-three-pixel
  holes caused by GIF transparency-index collisions, using the source GIF's
  own keyed RGB. Larger authored openings and background-connected alpha are
  preserved.
- Red, Blue and Yellow return the selected cartridge still even when the mode
  is ANIMATED, with `animated = false`; motion is never fabricated.
- Only 2D front art is supported. Back art and Dramatic Shape/Stadium models
  remain outside this API.
- Battle Art Replacer registers its true-color stills and decoded animation
  frames with Dramatic Shape's `BattlePics` compatibility seam. Dramatic Shape
  skips native Gen 1 paper-white restoration only for those owned images, so
  intentional enclosed gaps remain transparent on every frame. ROM sprites
  remain eligible for Dramatic Shape's restoration.
- Full Pokemon and lightweight `{ species = "PSYDUCK" }` objects are accepted.
  Shiny Gen 5, HGSS, Emerald, or FRLG art is used only when the supplied object is shiny under the
  Shiny System/public flag/native-DV rules.
- `context.token` is a stable consumer-owned table. Token state is weak-keyed;
  a stable token continues its timeline and separate tokens remain independent.
- `context.now` prevents draw-count-based timing and duplicate advancement. If
  omitted, the provider uses a safe monotonic clock.
- Species, shiny, collection and relevant option changes reset that token.
  Option/asset invalidation clears provider presentation state and image caches.
- Returned images always use nearest-neighbor filtering.

Legacy consumers may continue using `resolvePokemonImage`,
`resolvePokemonPath`, `mode`, `isAnimated`, and `invalidate`. The legacy image
resolver remains a stable neutral portrait.

### 4.3 Menu icon descriptor

HGSS Menu Icons registers one descriptor per species:

```lua
{
  image = ".../icon_NNN.png",
  shinyImage = ".../shiny_icon_NNN.png",
  frames = 2,
  hgssMenuIcon = true,
}
```

Each sheet is **32×64 RGBA**:

- `(0,0)-(31,31)`: animation frame 1.
- `(0,32)-(31,63)`: animation frame 2.

The widescreen renderer must select `shinyImage` per Pokémon, not globally per
species. Two party Pokémon of the same species may have different shiny state.

### 4.4 HGSS follower assets

The follower renderer uses:

- `follower_NNN.png`: normal **32×192 RGBA** sheet.
- `shiny_NNN.png`: shiny **32×192 RGBA** sheet.
- `proxy_NNN.png`: compatibility proxy used for billboard measurement.

The six native 32×32 frames are standing/walking views. The visible art is
anchored to the ground while collision remains the stock 16×16 entity footprint.

Follower behavior is deliberately narrow:

- The Party submenu selects one follower.
- A fainted follower is replaced by the first healthy party member from top
  to bottom.
- If all party members faint, the follower is hidden.
- No PokePC, Followers EX, or Wilds follower ownership is used.

HGSS Simple Follower alpha 18 also publishes Overworld Sprite API v1 for
independent provider consumers:

```lua
exports.overworldSpriteApiVersion = 1
exports.overworldSpriteDefinitionId = "SPRITE_HGSS_OVERWORLD_PROVIDER"
local sprite, reason = exports.createOverworldSprite(monOrSpecies, {
  owner = "consumer_manifest_id",
  role = "wild",
})
```

The registered definition is available before consumer NPC construction and
carries `hgssOverworldSprite = true`. Successful calls return a fresh
NPC-compatible six-frame renderer backed by the correct cached 32x192 normal
or shiny sheet. Full Pokemon objects use Shiny System/public flag/native-DV
state; species strings request normal art. Images are nearest-filtered,
clamp-wrapped and stable for the renderer lifetime. Invalid species, missing
art, invalid dimensions or invalid owner/role options return `nil, reason` and
never substitute another Pokemon. Provider cache invalidation affects future
calls while existing renderers remain safe. Dramatic Shape and Battle Art
Voxel Fork apply one centered, ground-anchored 32px billboard to the public
marker. Consumers own every entity, animation input, collision, AI, spawn and
battle decision and must never apply `hgssSimpleFollower` to those entities.

### 4.5 Widescreen UI boundary

The Widescreen UI presents converted screens on a **640×360 virtual surface**
and scales that presentation to the output window. The world continues using
its original logical geometry.

Never introduce any of the following into this mod:

- `Renderer:setUISize` changes that affect world composition.
- Camera, map, collision, voxel-height, world zoom, or tilt changes.
- A replacement world renderer.

Current converted scope (release `0.1.0-alpha.14.32`):

1. START menu.
2. Party screen and action panel.
3. Two-page Pokémon Summary/Stats screen.
4. Battle status HUD, messages, command menu, Safari/Old Man commands,
   move selection, Mimic selection and the level-up report. The level-up
   modal retains the bottom message panel and displays resulting
   HP/Attack/Defense/Speed/Special values with exact per-level `+N` gains;
   native StatBox input and progression remain engine-owned.
5. Independent presentation-only native Pokédex skin and generic Pokedex
   Provider API v2, with v1 list compatibility. Existing native code retains
   navigation, data, actions and progression ownership when no provider is
   active. There is no Pokédex+ compatibility path.
6. Title page from the first boot frame, main menu, Continue save summary and
   Load Report. Native title
   animation, menu callbacks, save validation, scrolling and dismissal retain
   behavioral ownership. The first interactive title Pokemon is Charizard,
   Blastoise or Pikachu for Red, Blue or Yellow; later choices are random,
   non-repeating Gen 1 species with a 1-in-64 provider-routed shiny chance.
   Raw title and Pokedex art is recolored through the
   active engine palette at final resolution; true-color title Pokemon retain
   their source colors. Unused logo/ribbon canvas is color-keyed, exact version
   slices are centered, and the original title draw is fully covered while
   Widescreen owns presentation. Load Report gives every mod-change statement
   its own row.
7. Responsive native Options presenter with eight visible rows at 640x360,
   selection-centered scrolling, and a left contextual value/help panel.
   Engine and mod-injected row callbacks retain behavioral ownership.
8. Responsive Mod Manager and per-mod schema options, including profiles,
   errors, permissions, pending changes and Manager-owned overlays. Title
   Pokémon consume `gen1_battle_art_replacer` when available and retain the
   engine title sprite as the explicit fallback. Enabled rows carry green
   checkmarks and disabled rows red X marks. Title, native Pokedex, Party,
   Summary and the public 2D portrait helper consume Battle Art Presentation
   API v1 with stable provider-owned animation tokens. Legacy Battle Art is
   consulted only when the standalone Presentation API is unavailable.
9. Responsive native dialogue and YES/NO choices. Widescreen owns the
   final-resolution draw pass and, for ordinary overworld/NPC text, reflows
   ROM line/CONT layout markers to a 56-column, two-line page budget. This
   removes width-only A presses while explicit paragraph pages remain gated.
   Native `TextBox`/`ChoiceBox` updates keep text speed, sounds, input,
   choices and callbacks. Dialogue
   composes over converted Title, START, Load Report, Options/Mod Manager,
   Party, Summary, Pokedex and Battle screens without reviving their 160x144
   fallback. World geometry is unchanged.
10. Full Pokedex Provider API v2 presentation: numbered list/right detail,
    exact five-row submenu, Habitat/Stats/Learnset/Evolution research modes,
    controller/keyboard update dispatch, pointer/touch hit regions, privacy
    gates, bounded long-list and five-line entry viewports, normal live Battle
    Art portraits, measured female/male glyphs, validated owned-shiny portrait
    toggles with footer-only controls and a presenter-owned active-shiny gold
    star, bounded entry focus and clickable scroll arrows.
    The dependent provider owns immutable semantic snapshots and callbacks;
    Widescreen owns all drawing, focus and input mapping. Invalid snapshots
    retain the last valid opaque provider view and never expose native layers.
11. Shared true-color shiny indicators: the supplied pixel-star asset appears
    in the Party detail panel, Summary identity panel and beside both player
    and enemy Battle HUD names. The installed Shiny System is authoritative;
    explicit/native shiny state is used only when that provider is absent.
12. Responsive Evolution movie. The engine retains timing, cancellation,
    mutation, cry, move-learning and callback ownership. Widescreen mirrors the
    original accelerating old/new cadence using Battle Art Presentation API v1
    and stable animation tokens, then falls back to the active ROM front sprite
    whenever the provider is absent, in ROM mode, or declines the request.
13. Responsive Trainer Card. Native input and save behavior remain engine-owned;
    Widescreen presents name, money, time, a correctly palette-colored ROM
    player portrait and all eight Kanto badge slots using the supplied
    transparent badge atlas. Each slot includes its native Gym Leader portrait:
    locked slots are monochrome, while earned leaders use their active trainer
    palette. Trainer Card Portrait Provider API v1, plus the Character Sprite
    Replacer presentation bridge, lets the player/NPC art owner replace player
    and leader portraits without transferring Trainer Card layout ownership.
14. Mod-scoped shared-image loading. `shiny_star.png` is loaded through
    `mod.assets:image("assets/shiny_star.png")`, cached only after success,
    retried after failure and
    diagnosed once per distinct failure state. Indicator identity comes from
    Shiny System `isShiny`; art selection remains independently controlled by
    `shouldUseShinyArt`.
15. Dramatic Shape battle-intro grounding. While the player's trainer-back pic
    is active, Widescreen removes only that arena billboard and redraws the same
    resolved image in the final HUD pass with its feet pinned to the bottom
    message/command panel. Pokemon billboards remain arena-owned after send-out.
16. Responsive New Game opening. Widescreen replaces only OakSpeech and its
    associated NamingScreen draw passes with a 640x360 composition using the
    supplied FRLG Oak, Red and rival art. OakSpeech remains authoritative for
    localized dialogue, reveal/shrink timing, cries, music, naming, callbacks
    and save mutation. The demonstration Pokemon consumes Battle Art
    Presentation API v1 with purpose `oak_speech` and a stable token; any
    unavailable or invalid provider result falls back to the native ROM image.
    The intro-specific bottom dialogue panel repaginates obsolete narrow-box
    controls to a safe 68-column/two-line budget. Swapped English Red/Blue
    preset banks are corrected only when detected. The visible shrink is
    replaced by an intact-player hold and fade before native completion into
    the player's house.
17. Bag Provider API v2, with v1 compatibility. A single mandatory semantic provider supplies fresh
    field/battle Bag, pocket, search, machine-filter, move-info, item-options
    and confirmation snapshots plus callbacks. Widescreen owns all responsive
    drawing, focus/scroll presentation, hints, pointer targets, icons and
    owned native-layer suppression. Invalid provider output remains opaque and
    reports one actionable error. Widescreen never owns Bag classification,
    inventory mutation, persistence, sorting/search or item effects. Contract:
    `gen1_widescreen_ui/BAG_PROVIDER_API_V2.md`; dependency floor
    `>= 0.1.0-alpha.14.22 <0.2.0`. V2 adds validated search-keyboard grids,
    physical text/delete/clear routing, visible modal focus and screen-aware
    directional actions while retaining v1 unchanged.
18. Independent vanilla Bag skin. In the absence of a provider, Widescreen
    presents the engine's native `kind=bag` list, detail, money, USE/TOSS,
    quantity and confirmation layers. Native Bag/ListMenu behavior remains the
    sole owner of item effects, ordering, targeting, battle turns and inventory
    mutation. Registered Bag API providers retain precedence. The New Game
    close uses a longer hold/fade/white bridge and filters only the injected
    Yellow Legacy `hard_mode_choice`; Hard Mode remains available in Options.
    Iconless vanilla rows do not show provider fallback tags. Oak's final
    Pixelify dialogue remains visible until native A acknowledgement; the
    removed ROM-font replica can no longer appear before the fade.
    The closing fade-out lasts three seconds; after native completion, a
    1.5-second non-opaque fade-in state overlays the house and blocks
    overworld control until it pops.
19. Concise vanilla item descriptions and responsive native PC presentation.
    Standard item text follows the canonical engine IDs and ItemEffects
    behavior; TM/HM descriptions resolve the live registered move. Custom
    items prefer registered description/effect metadata. The complete native
    PC session—terminal chooser, Bill's storage, player item storage, lists,
    quantities, confirmations and dialogue—is presented at widescreen
    resolution while all transfers, release/save behavior and callbacks remain
    engine-owned. Alpha 14.23 adds readable Pokemon-storage labels, a compact
    highlighted-Pokemon Battle-Art/stat panel, and a bottom-right action popup.
    PC presentation must stop at opaque destinations such as Summary, while
    native TextBox/Choice overlays above a PC root must remain visible; this
    ownership boundary prevents broken Stats actions and apparent freezes on
    empty/full storage, release/change-box and Professor Oak PC prompts.

### 4.6 Battle HUD Overlay API v1

Widescreen alpha 11.1 publishes a multi-owner, draw-only overlay contract.
Providers receive the actual enemy-panel rectangle, rendered-name metrics,
active Pixelify Sans fonts, palette, and panel helper. Gen1 Unified Quality of
Life alpha 4 uses this contract for its caught marker and attached catch-odds
footer. Provider failures are isolated from the base Battle HUD.

### 4.7 Pokedex Provider API v2

Widescreen alpha 14.7 publishes the complete generic one-owner presenter
contract consumed by `gen1_widescreen_pokedex`:

```lua
widescreen.exports.registerPokedexProvider({
  owner = "gen1_widescreen_pokedex",
  apiVersion = 2,
  match = function(state) return ownsState end,
  snapshot = function(game, state) return immutableSchemaV2Snapshot end,
  actions = {
    up = fn, down = fn, pageUp = fn, pageDown = fn,
    select = fn, back = fn, selectRow = fn,
    selectSubmenu = fn, scroll = fn,
    toggleShiny = optionalFn,
  },
})
```

It also publishes `unregisterPokedexProvider`,
`activePokedexProviderOwner`, guarded `invokePokedexProviderAction`, and
`updatePokedexProviderInput(game, state, dt)`. Schema v2 supports `pokedex`,
`pokedex_habitat`, `pokedex_stats`, `pokedex_learnset` and
`pokedex_evolution`. Widescreen owns master-detail/submenu/research drawing,
focus, bounded long-entry scrolling, gender glyphs, validated owned-shiny
portrait presentation, controller/keyboard mapping and
pointer/touch regions. The provider owns only immutable data/navigation
snapshots and callbacks. Competing owners, invalid data and exceptions are
isolated; v1 list fixtures remain accepted.

### 4.8 Battle Move Inspector API v1

Widescreen alpha 9.1 retains alpha 9's generic one-provider contract:

```lua
widescreen.exports.registerBattleMoveInspector({
  owner = "compatible_mod_id",
  apiVersion = 1,
  snapshot = function(battle) return immutableSnapshotOrNil end,
})
```

It validates schema v1, rejects competing owners deterministically, allows the
same owner to replace itself, deduplicates provider failures and falls back to
the basic move panel. A registered provider forces the Widescreen Battle HUD
on with one explicit warning if its saved toggle is off. Mimic remains on the
basic detail panel.

### 4.9 Widescreen UI ownership and roadmap

The agent assigned to this project owns **only** `gen1_widescreen_ui`.
It may consume public contracts from Menu Icons, Shiny System, Battle Art and
Follower, but it must not modify those provider mods directly. If a provider
change is required, document the requested contract and hand it to that mod's
owner.

Implementation order:

0. **Stabilize the converted foundation.** Keep START, Party, action overlays,
   both Summary pages, title flow, Load Report and Battle HUD regression-tested. Eliminate every
   native-menu fallback reachable from those screens before expanding scope.
1. **Modern UI API v1 compatibility presenter.** Publish semantic,
   resolution-independent hooks for Start-menu entries, Options rows,
   contextual help and modal/choice overlays. Consumers provide data and
   callbacks; Widescreen owns layout, focus, scrolling and drawing. Preserve
   the existing portrait exports and document all public contracts.
2. **Options and contextual help (presentation implemented in Alpha 12.1).**
   More visible rows, a dedicated parameter panel, semantic third-party rows,
   and safe scrolling are implemented. The remaining work is the public Modern
   UI row/help contract for mods that want richer descriptions or parameters.
3. **Dialogue and global-font completion (dialogue implemented in Alpha
   13.0; wide NPC pagination in Alpha 14.11).** Native TextBox and YES/NO
   ChoiceBox use the crisp font pipeline and integer final-resolution
   placement. Ordinary overworld text now fills the wide two-line page and
   removes obsolete CONT presses while preserving explicit paragraphs.
   Continue auditing specialized native widgets that do not use these classes.
4. **Widescreen Pokédex presenter (implemented through Alpha 14.7).** The native
   skin remains presentation-only when no provider is active. Provider API v2
   supplies the requested left-list/right-detail view, exact Habitat, Stats,
   Learnset, Evolution and Cry submenu, four research renderers and
   update/pointer input routing, bounded long-entry focus/scrolling, glyph-safe
   Pokemon names and validated owned-shiny portrait toggles with footer-only
   control hints and the shared active-shiny bitmap star. The released
   separate Widescreen-dependent mod owns semantic data/navigation and is
   specified in `NEXT_AGENT_WIDESCREEN_POKEDEX.md`. There is no Pokédex+
   integration.
5. **Bag presenter contract (implemented through Alpha 14.22).** Bag Provider API
   v2 supplies Widescreen list/detail layout, pocket tabs, search/filter
   models, item detail/modals, visible provider icons/fallbacks and contextual
   actions. The separate mandatory Widescreen-dependent Bag mod owns inventory
   semantics and is specified in `NEXT_AGENT_WIDESCREEN_MODERN_BAG.md`.
   Final schema: `gen1_widescreen_ui/BAG_PROVIDER_API_V2.md`; dependency floor
   `>= 0.1.0-alpha.14.22 <0.2.0`. V1 remains compatible.
6. **Release-candidate audit.** Test every transition and overlay at 16:9 and
   narrower fallback sizes; audit controller/keyboard input, clipping, native
   fallback exposure, optional-provider absence and launcher packaging.

The Widescreen Dex Radar is **not** part of this roadmap's implementation
scope. It is a separate Widescreen-dependent mod described in
`NEXT_AGENT_WIDESCREEN_DEX_RADAR.md`. Widescreen owns only the Start-menu and
presentation APIs that allow that mod to integrate without patching UI
internals.

The Widescreen Move Inspector is implemented as a separate mandatory
Widescreen-dependent mod. Widescreen owns its rendering and generic provider
contract; the inspector owns only live immutable move semantics.

The native Pokédex has an independent presentation-only skin. Pokédex+ is not
supported or consulted. Provider API v2 presents master/detail and research
snapshots from the dedicated Pokédex mod without taking ownership of its data
or navigation. Bag Provider API v2 (with v1 compatibility) now defines the presentation boundary; the
dedicated Modern Bag mod still owns and must implement all Bag semantics.

## 5. Mod-specific behavior

### Gen1 Widescreen UI

- Requires Gen1Recomp `>=0.1.78 <0.2.0` and explicitly targets `games:
  ["gen1"]`; it must not partially run against Gold's separate Gen 2 UI.
- Uses Pixelify Sans with nearest-neighbor filtering and integer positioning.
- Keeps all six party members visible.
- Uses side panels instead of covering the party list.
- Party details show types, HP/EXP bars, four Gen 1 stats and moves.
- Summary has two pages, type badges, move-type badges, HP and EXP bars.
- Party/Summary portraits use live 2D Battle Art when available.
- Stadium-mode 3D art falls back to a valid 2D portrait.
- Message/choice overlays remain over the widescreen Party presentation rather
  than exposing the native 160×144 menu underneath.
- Battle HUD uses one 640×360 final-resolution presenter for enemy/player
  status, player HP/EXP, messages, commands, Safari/Old Man flows, the 2×2
  move grid and Mimic. Dramatic Shape retains ownership of its arena, camera,
  battlers, animations and Stadium models.
- Battle Move Inspector API v1 extends the existing 2×2 panel without a second
  overlay and preserves alpha 8.2 grid navigation and both snapped-HUD provider
  adapters.

### Gen1 Bill S.S. Ticket Repair

- Is deliberately separate from Widescreen because it repairs gameplay/save
  state, not presentation.
- Targets the shared Red/Blue/Yellow Bill event in Gen1Recomp 0.1.78.
- Reconstructs human Bill after an interrupted cell-separator callback and
  restores a missing completed-event ticket only when it is absent from both
  the Bag and item PC and the S.S. Anne has not departed.
- Version 0.1.1 intercepts only Echoes Beyond the Fog 2.2.0's broken
  `fog:base_bill_chat` fallback when the engine-owned Bill handler is a script
  row list. It executes that list through the active ScriptRunner while
  preserving Echoes' quest branches and function-shaped fallbacks.
- Does not replace Bill's normal dialogue or auto-complete an unstarted quest.

### Widescreen Move Inspector

- Reads highlighted move/PP, current battler types and merged move/type-chart
  data afresh on every normal move-selection presentation.
- Separates base, status, fixed and special-formula power; labels Swift as
  always-hit and never claims a final damage preview.
- Reports ordinary STAB only where the engine's normal damage path applies.
- Uses `TYPE CHART` wording for status/fixed/special moves because fixed damage
  and Super Fang skip Gen 1 type effectiveness while OHKO still checks immunity.
- Conflicts with the original `move_inspector` and performs no drawing or hook.

### Gen1 Battle Art Replacer

- Alpha 6 provides selectable Red, Blue, Yellow and Gen 5 fronts for all 151
  Gen 1 Pokemon, with STATIC/ANIMATED selection and genuine timed Gen 5 frames.
- Alpha 9 adds normal/shiny HGSS fronts for all 151. Only the two blue-matte
  front cells are extracted from each base male/unisex panel; green-matte back
  cells are excluded. The labeled corrected Kabuto front panel replaces the
  sequential Kabuto cells. STATIC uses pose 1;
  ANIMATED alternates the two supplied poses at 500 ms per frame.
- Alpha 10 removes unused HGSS outer matte with one shared per-species crop,
  preserving alignment across normal/shiny poses. It also adds all 151
  normal/shiny FRLG fronts from the supplied sheet. Full-size backs, header
  thumbnails, female/gender variants, and non-Gen-1 extras are excluded;
  Nidoran Female and Nidoran Male remain separate species. FRLG remains static
  under ANIMATED. A narrowly scoped scale bridge prevents provider fronts in
  Dramatic Shape's player back slot from inheriting native 2x back scaling;
  ROM backs and Dramatic Shape geometry/camera remain untouched.
- Alpha 11 adds all 151 normal/shiny Emerald fronts. Only the two consecutive
  front poses per species are imported from the separate normal/shiny sheets;
  footer/empty cells are excluded. STATIC uses pose 1 and ANIMATED uses a
  provider-owned 500 ms two-frame cadence because the sheets have no timing
  metadata. No redundant female/gender asset is packaged.
- Alpha 12 adds all 151 normal/shiny Crystal and Platinum fronts. Crystal uses
  per-species frame timing and excludes each row's final back cell. Platinum
  uses its two supplied front poses at 500 ms each; adaptive exact matte keying
  handles its mixed Diamond/Pearl reuse cells. Platinum backs and redundant
  female sections are excluded.
- Includes normal and per-instance shiny Gen 5 art derived from the supplied
  White 2 component-sheet palette pairs; backs, trainers and player art remain
  ROM-owned.
- Exposes Presentation API v1 for exact live 2D UI art plus the legacy stable
  portrait exports. It never changes world geometry, battle staging, camera,
  collision or HUD layout.
- Integrates Dramatic Shape 1.8.0 through its normal battler images and its
  exported `OverworldBattle.wantsFront()` contract without changing 3D staging.
- Continues to conflict with `BATTLE_ART_VOXEL_FORK`, which separately owns
  and overwrites the same battle-art fields.

### HGSS Menu Icons

- Contains all 151 normal and all 151 shiny two-frame HGSS-style icons.
- Normal icons were decoded from the user's HeartGold ROM.
- Shiny icons were palette-derived, audited against Gen 5 shiny references,
  and manually corrected where palette-only transfer was insufficient.
- It conflicts with `new_icons` and `unique_menu_icons` because those mods own
  the same icon registry.

### HGSS Simple Follower

- Contains all 151 normal and shiny HGSS overworld sheets.
- Normal and shiny mapping, direction, species identity and grounding were
  audited across all 151 Pokémon.
- It conflicts with PokePC Followers, Followers EX and the obsolete HGSS
  overworld sprite-pack prototype.
- Wilds may remain installed, but its follower count must not take ownership
  of the same party follower.
- Alpha 18 publishes HGSS Overworld Sprite API v1 so independent consumers can
  create normal/shiny six-frame renderers without copying assets or becoming
  followers. The provider owns art, caching, filtering and voxel billboard
  compatibility only; consumers retain all entity and gameplay ownership.

### Gen1 Shiny System

User-facing options match the established shiny interface:

- SHINY POKEMON.
- SHINY RATE: OFF, 1/8192, 1/4096, 1/1024, 1/512, 1/100, 1/10, 100%.
- SHINY COLORS.
- SHINY INTRO.
- DEBUG OW.

It owns wild shiny rolls, valid Gen 2 shiny DVs, persistent flags, 2D battle
recoloring, battle sparkle/SFX, and the shared consumer API.

Alpha 3 is authoritative over Dramatic Shape 1.8.x's overlapping shiny
generator through its exported companion namespace. Dramatic Shape retains
ownership of 3D models and model-sized effects, but its in-game shiny-rate row
controls the Shiny System rate and its 3D shiny presentation follows the Shiny
System master/color/intro state. Its generic Mod Manager page may still show a
legacy `shinyOdds` field because Dramatic Shape exposes no schema-removal API;
that field is runtime-inert while the adapter is active.

It conflicts with the third-party `SHINY_POKEMON` mod. Never enable both: they
would both wrap wild creation and battle presentation.

The official Crystal palette table is reused under the included MIT license.

Wild Outcome API v1 lets Kanto Living Encounters reserve visible shiny metadata
once and reuse the exact result in the contact battle. Shiny System retains all
shiny generation and presentation ownership; the consumer owns its entity art,
lifetime, collision, and encounter flow.

## 6. Packaging rules

Release ZIPs must contain files directly at archive root. Never wrap the mod in
an extra directory.

Expected current archive structure/counts:

| Mod | Root entries | Important contents |
|---|---:|---|
| Widescreen UI | 8 | manifest, main, README, party-icon atlas, shiny-star bitmap, trainer-badge atlas, font, font license |
| Menu Icons | 305 | manifest, main, README, 151 normal + 151 shiny sheets |
| Simple Follower | 456 | manifest, main, README, 151 normal + 151 shiny + 151 proxies |
| Shiny System | 5 | manifest, main, README, palette table, MIT license |
| Battle Art Replacer | 3630 | manifest, main, README, provenance, two animation metadata files, 3,624 Pokemon PNGs |
| Unified Quality of Life | 11 | manifest, 8 Lua modules, README, third-party licenses |
| Widescreen Move Inspector | 5 | manifest, main, README, changelog, MIT license |
| Widescreen Pokédex | 5 | manifest, main, README, changelog, MIT license |
| Character Sprite Replacer | 82 | manifest, main, mappings, docs/licenses, 2 extraction reports, 67 FRLG player/trainer PNGs, 2 owner requests |

Before handing off a ZIP, verify:

- `manifest.json` and its declared `entry` exist at root.
- The filename version exactly matches the manifest version.
- No duplicate archive entries.
- No entry contains `/` unless a future launcher version is explicitly proven
  safe and the user approves changing this policy.
- PNG dimensions and expected asset counts are correct.
- Required license files are present.
- The ZIP was not copied into an installed Mods directory.

Launcher troubleshooting:

- A partial extraction or stack-overflow error may be stale launcher state.
- Remove the older installed version, import the intended ZIP, then fully
  restart the launcher.
- Confirm the version shown by the launcher; never assume replacement worked.

## 7. Testing requirements

Use the exact Lua 5.1 runtime shipped with Gen1 Recomp when possible. The
development tree currently provides this runner:

`gen1_widescreen_ui/tests/run_lua51_test.py`

Current smoke/integration tests:

- `gen1_widescreen_ui/tests/start_menu_test.lua`
- `gen1_widescreen_ui/tests/battle_hud_test.lua`
- `gen1_widescreen_move_inspector/tests/move_inspector_test.lua`
- `hgss_menu_icons_mod/tests/icon_mod_test.lua`
- `hgss_simple_follower/tests/simple_follower_test.lua`
- `hgss_simple_follower/tests/overworld_sprite_api_test.lua`
- `gen1_shiny_system/tests/shiny_system_test.lua`
- `gen1_shiny_system/tests/wild_outcome_api_test.lua`
- `gen1_battle_art_replacer/tests/battle_art_replacer_test.lua`
- `gen1_character_sprite_replacer/tests/character_sprite_replacer_test.lua`

Minimum verification for every relevant change:

1. Run the modified mod's test.
2. Run every consumer/provider integration test affected by its public API.
3. Build the flat ZIP.
4. Audit archive entries, duplicates, nesting and manifest version.
5. For image changes, render a focused audit PNG and inspect it visually.
6. For all-species assets, validate all 151 mappings—not only the screenshot
   example—and preserve alpha/silhouette unless geometry is intentionally fixed.

Tests are necessary but not sufficient. The user performs the final in-game
launcher test because Dramatic Shape, Battle Art and launcher import behavior
cannot be fully reproduced by isolated Lua mocks.

## 8. Versioning and release retention

- Every user-visible or compatibility change receives a new version.
- Update the manifest, README current-build line, source header and ZIP name
  together.
- Update dependency ranges when a consumer needs a new provider contract.
- Do not overwrite the filename of a previously delivered version.
- During requested cleanup, keep the latest three semantic-versioned ZIPs for
  each mod in `Releases` and move older versions to `Releases/Old versions`.
  A mod with fewer than three releases keeps all of them. Never compare
  prerelease versions lexicographically when numeric identifiers differ.
- Never delete editable source, user screenshots, ROM-derived source assets or
  licenses merely because an old release ZIP is superseded.

## 9. New-mod checklist for future agents

Before implementation:

1. Read this document completely.
2. Inspect the current canonical manifests and integration exports.
3. Study relevant installed mods read-only for compatibility contracts.
4. Define one narrow ownership boundary for the new mod.
5. Decide whether Widescreen UI integration is mandatory or optional.
6. Identify conflicts where two mods would own the same registry/hook/state.

During implementation:

1. Keep UI logic separate from world geometry.
2. Prefer dynamic draw-time resolution for mod-selectable assets.
3. Use explicit flags plus native engine state for compatibility.
4. Cache decoded images, but invalidate caches after option/asset changes.
5. Avoid species-specific exceptions unless a visual audit proves they are
   necessary; document every exception.
6. Add a Lua 5.1 test for the new ownership boundary and integrations.
7. If another mod must change, stop at that ownership boundary and give the
   user the complete provider-agent prompt required by section 1.1.

Before delivery:

1. Bump versions and dependency ranges.
2. Run tests.
3. Build and audit a flat ZIP.
4. Create visual audits where appropriate.
5. Put the final ZIP in `Releases`.
6. Do **not** install it.
7. Report exact files, versions, tests and any remaining limitation honestly.

## 10. Active future-mod design documents

The following root-level documents are part of the project's durable planning
memory and must be read when their ownership surfaces overlap a new task:

- `WILDS_OF_KANTO_MOD_DESIGN.md` — focused visible-wild recreation under the
  working identity `kanto_living_encounters`. It preserves classic random
  encounters, owns visible wild entities/AI/contact battles only, remains
  separate from followers and world geometry, and exposes a future
  spawn-table-provider contract.
- `NEXT_AGENT_BATTLE_ART_REPLACER.md` — standalone Gen 1–5 Pokemon/trainer/player
  battle-art provider plan with static, animated, and ROM fallback behavior.
- `BALANCES_MOD_PLAN.md` — active focused plan for `gen1_balances`. It owns
  live encounter/fishing tables plus Yellow Legacy-derived base-stat and
  learnset changes, and preserves trade evolutions while adding level paths.
  It explicitly excludes the former full-recreation scope.
- `NEXT_AGENT_YELLOW_LEGACY_RECREATION.md` — archived source-audit handoff for
  the superseded full Yellow Legacy recreation. Do not implement its trainer,
  move, Hard Mode, rematch, or quest scope unless the user reauthorizes it.
- `NEXT_AGENT_UNIFIED_QUALITY_OF_LIFE.md` — implementation brief for the
  released Unified QOL alpha: later-gen overlays and field shortcuts, Catch
  Helper odds/owned marker/optional Ultra correction, and selectable EXP
  distribution modes.
- `NEXT_AGENT_WIDESCREEN_DEX_RADAR.md` — Widescreen-dependent Start-menu radar
  that displays the effective table exclusively through the spawn mod's
  immutable snapshot API.
- `NEXT_AGENT_WIDESCREEN_MODERN_BAG.md` — mandatory Widescreen Bag recreation
  implementing six pockets: Medicine, Poke Balls, TM/HM, Battle Items, Key
  Items and Items. It excludes Favorites, pins, search and automatic sorting;
  SELECT performs persistent vanilla-style movement, START explicitly cycles
  Alphabetical/Type/Quantity sorting outside the fixed HM-first/TM-second
  numerical machine pocket, and it provides unlimited capacity, plain
  right-panel information and dedicated icons with visible fallbacks.
  `GEN1_WIDESCREEN_UI_STRUCTURED_MACHINE_DETAIL_REQUEST.md` is the owner-routed
  request implemented by Widescreen Alpha 14.26: bold, line-separated TM/HM
  parameters, the shared type badge, and measured multiline DESCRIPTION text.
  Bag providers emitting this optional model require
  `gen1_widescreen_ui >=0.1.0-alpha.14.26 <0.2.0`; the Bag mod must not
  implement or overlay that presenter itself.
- `NEXT_AGENT_WIDESCREEN_MOVE_INSPECTOR.md` — mandatory Widescreen Battle HUD
  extension that reports live highlighted-move type, PP, power, accuracy,
  type-chart matchup and STAB without changing battle mechanics.
- `NEXT_AGENT_WIDESCREEN_POKEDEX.md` — mandatory Widescreen Pokédex with a
  left species list, right live 2D sprite/entry panel, and Habitat, Stats,
  Learnset, Evolution and live-provider Cry actions.
- `NEXT_AGENT_WIDESCREEN_GRID_BOX.md` — mandatory Widescreen Gen III-style
  Pokemon Storage System: a fixed 5×4 box grid, static icons, animated detail
  portrait, Withdraw/Deposit workflows, atomic Move Pokemon operations and a
  six-slot Party drawer. It removes Release, preserves native CHANGE BOX and
  Yellow PRINT BOX, retains dense native storage, and never changes the active
  box merely by browsing.
- `GEN1_WIDESCREEN_UI_STORAGE_PROVIDER_REQUEST.md` and
  `WIDESCREEN_STORAGE_PROVIDER_V1_COMPLETION_REQUEST.md` — owner-routed prerequisite
  for the Grid Box, completed by Widescreen alpha 14.32. The generic,
  one-owner Pokemon Storage Provider API v1 accepts immutable semantic
  snapshots while Widescreen owns the 640x360 grid, Party drawer, detail,
  popup, input mapping, native suppression and last-valid fail-closed view.
  Grid Box must require `gen1_widescreen_ui >=0.1.0-alpha.14.32 <0.2.0` and
  must not draw or patch Widescreen private tables.
- `NEXT_AGENT_CHARACTER_SPRITE_REPLACER.md` — standalone coherent human
  character pack for player overworld/front/back art, human NPC overworld art,
  and enemy trainer overworld/battle portraits, with strict ROM fallback and
  no gameplay or world-geometry ownership.

Cross-project ownership rule: Gen1 Balances owns its live encounter and
fishing data; Kanto Living Encounters consumes the effective live encounter
tables through its native adapter but owns visible entities, spawn pacing, AI,
and contact battles. Balances must not register a competing visible-spawn
provider. Gen1 Shiny System exclusively owns shiny rolls, DV/state writes,
colors, sparkles, and presentation; Balances performs none of those actions;
the Battle Art Replacer owns only Pokémon 2D battle art; Widescreen UI remains the presentation
integration layer; HGSS Simple Follower remains the sole party-follower owner.
The unified Quality of Life mod owns optional informational overlays and
convenience controls only; its Ultra Ball and EXP rule changes must remain
explicit, independently selectable, and vanilla-safe. The Widescreen Modern
Bag owns inventory organization, Bag preferences and item-icon resolution;
Widescreen owns all Bag drawing; item effects remain with the engine or their
respective gameplay mod.
The Widescreen Move Inspector owns only the immutable highlighted-move
information snapshot; Widescreen owns its Battle HUD presentation and the
engine remains the authority for actual move resolution and damage.
The Widescreen Pokédex owns read-only Pokédex navigation and research models;
Widescreen owns all drawing; the engine owns discovery flags and cries; live
content and spawn providers remain authoritative for the displayed data.
The Widescreen Grid Box owns Bill's storage navigation, validation and atomic
mutations of the engine's existing dense `save.boxes`/`save.party` records.
Widescreen owns its grid, Party drawer, static icons, animated 2D detail and
popup presentation. The engine owns storage persistence, stats calculation,
Summary, current-box save behavior and Yellow follower rules. Advanced Box
System conflicts because it owns the same `BoxMenu` and transfer surfaces.
The Character Sprite Replacer owns human player/NPC/trainer appearance across
overworld and battle contexts. The Battle Art Replacer owns Pokémon battle art
only; followers and visible wild Pokémon keep their existing owners.
