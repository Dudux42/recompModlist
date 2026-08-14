# Gen1 Widescreen UI

Current build: **0.1.0-alpha.14.32**

## Alpha 14.32 Pokemon Storage Provider v1 presenter completion

- Draws an `ACTIVE` badge only when the viewed Box is the active capture Box;
  browsing remains a provider-owned operation and cannot silently change it.
- Adds a visible, pointer-addressable PARTY button with optional
  `selectPartyButton` routing and a backward-compatible `select` fallback.
- Presents held origins, valid empty targets, valid swaps and invalid targets
  with distinct monochrome-safe border/line patterns, including disabled
  grid/Party/popup reasons in the footer.
- Adds optional nicknamed species and gender detail fields with bounded text.
- Repairs Pokemon Storage pointer coordinates at 1x and scaled host sizes; the
  prior boolean multi-return expression could discard the host height and make
  pointer routing exit early.

## Alpha 14.31 Pokemon Storage Provider, PC shiny identity and field levels

- Publishes the fail-closed, one-owner Pokemon Storage Provider API v1 for a
  semantic 5x4 Box grid, six-slot Party drawer, held Pokemon, selected detail,
  popup rows and semantic keyboard/controller/pointer actions. Widescreen owns
  the entire 640x360 presentation; providers retain all navigation and save
  mutations. See `POKEMON_STORAGE_PROVIDER_API_V1.md`.
- Keeps the exact last valid snapshot opaque when a matching provider later
  fails, deduplicates diagnostics, and invalidates presenter caches on owner
  replacement/unregistration.
- Restores the shiny-star asset to the responsive native PC Pokemon detail,
  including native-DV fallback while its action popup is open.
- Keeps the Party selector behind Rare Candy growth messages and presents the
  non-battle stat gains with the same Widescreen level-up panel.
- Adds a generic MOVE POKEMON description to the responsive Bill's-PC root.

## Alpha 14.30 smoother EXP transition

- Pins the HUD to its pre-award EXP position immediately after the engine
  commits the model change, eliminating the one-frame final-value flash before
  the queued animation starts.
- Uses finer full-level timing so the blue fill advances in smaller steps.

## Alpha 14.29 EXP crash fix

- Fixes the EXP-award crash caused by the queue helper resolving a file-local
  clamp function as a missing global under Lua 5.1.
- Adds a smoke test that executes wrapped `BattleState.awardExp`, verifies an
  EXP-animation row is queued, and drives that blocking row to completion.

## Alpha 14.28 battle progression and direct-entry fixes

- Renders female and male symbols as Widescreen vector glyphs in both normal
  dialogue and battle messages, including Nidoran and trainer labels.
- Presents standalone post-capture `DexEntryMenu` states through the responsive
  Pokédex skin instead of falling back to the native Game Boy entry page.
- Animates the player EXP bar as blocking battle-queue segments: a level-bound
  segment completes before the native level-up sound/stat panel flow, and the
  remainder runs after that level's move-learning flow.
- Reflows ROM battle line breaks to the real widescreen message width, keeping
  auto-learned move names visible even when the Pokemon previously knew fewer
  than four moves.
- Removes the redundant `A / B CONTINUE` footer from the level-up stat panel.

## Alpha 14.27 Gen1Recomp 0.1.78 compatibility audit

- Audited the Widescreen class patches and `render.hud`, `battle.overlay`, and
  `input.pointer` hook contracts against Gen1Recomp **0.1.78**.
- Declares the current manifest's explicit `games: ["gen1"]` target. This
  prevents the Gen 1 presentation patches from partially loading over Gold's
  separate Gen 2 screen and world implementations.
- Raises the tested engine floor to `>=0.1.78 <0.2.0`. Provider API v1/v2
  contracts and dependent-mod version floors are otherwise unchanged.
- The complete start/menu/provider/PC test suite and Battle HUD suite pass
  while resolving the 0.1.78 engine modules.

## Alpha 14.26 structured TM/HM detail completion

- Adds the optional Bag Provider API v2 `detail.kind = "machine"` model for
  authoritative MOVE, TYPE, CATEGORY, POWER, ACCURACY, PP and DESCRIPTION
  values. Widescreen performs no move lookup or gameplay calculation.
- Draws every scalar on its own line, uses the existing colored type badge,
  and visually distinguishes bold parameter labels from regular values.
- Treats DESCRIPTION as measured multiline content across all remaining panel
  space. Explicit line breaks are preserved and long sentences such as Bide's
  are no longer shortened by the one-line ellipsis helper.
- Validates bounded structured labels, values, parameter count and type ID.
  Invalid provider data remains opaque and its actionable error is deduplicated.
- Providers emitting this model require `gen1_widescreen_ui >=
  0.1.0-alpha.14.26 <0.2.0`; existing API v2 providers remain compatible.

## Alpha 14.24 PC item-detail classification fix

- Restricts party-Pokemon detail lookup to the explicit `PARTY (DEPOSIT)`
  Pokemon-storage list. `DEPOSIT ITEM` rows can no longer be mistaken for the
  first six party slots, so the item PC consistently shows item descriptions
  instead of Pokemon portraits and stats.

## Alpha 14.23 Pokemon storage interaction repair

- Replaces leaked `<PK><MN>` control tags with readable `POKEMON` labels on
  Withdraw, Deposit and Release without changing the engine's menu actions.
- Keeps a Box/Party Pokemon list visible while its native Withdraw/Deposit/
  Stats/Cancel action menu is presented as a compact bottom-right popup.
- Adds a Battle-Art-aware highlighted-Pokemon portrait, level, HP bar and the
  four Gen 1 stats to the smaller PC detail panel. Boxed Pokemon stats are
  calculated for presentation when the stored record has no party stat block.
- Stops PC ownership at opaque destinations such as Summary, allowing Stats
  from both Withdraw and Deposit to open the established Widescreen Summary.
- Restores the first TextBox/Choice overlay above a PC screen. Empty Box, full
  party, Release, Change Box and Professor Oak PC messages are now visible,
  eliminating the apparent input freeze caused by hidden native dialogue.

## Alpha 14.22 item descriptions, responsive PC and Bag Provider API v2

- Gives the independent vanilla Bag a concise right-panel description for
  every standard Gen 1 item family. Healing/PP amounts, Repel durations,
  status cures, battle items, field tools, fossils, key items and TM/HM move
  names are derived from the engine's canonical IDs and ItemEffects behavior.
  Custom items use their registered description/effect metadata, then a safe
  generic fallback; Widescreen never executes or predicts item effects.
- Converts the complete native PC session to the established responsive
  presentation: Pokemon Center terminal, Bill's Box actions, player item
  storage, Box/item lists, quantities, confirmations and dialogue overlays.
  Native Menu/List/Quantity/Choice updates still own transfers, release,
  saving, item counts, callbacks and all input behavior.
- Publishes Bag Provider API v2 with a validated presenter-owned keyboard
  grid, visible modal focus, physical text/delete/clear routing, semantic key
  activation, pointer parity and screen-aware directional dispatch. API v1
  remains accepted unchanged. Final contract: `BAG_PROVIDER_API_V2.md`.
  Minimum Modern Bag dependency: `gen1_widescreen_ui >=
  0.1.0-alpha.14.22 <0.2.0`.

## Alpha 14.21 extended house transition

- Extends the intro fade-out to three seconds after the existing half-second
  intact-player hold, followed by the existing half-second fully white bridge.
- After native OakSpeech completion reveals the player's house, pushes a
  non-opaque 90-frame transition state that fades white away over 1.5 seconds.
  Because it remains the top stack state, overworld movement and interaction
  cannot receive input until the fade-in completes.
- Pushes the fade-in only after OakSpeech has popped itself, avoiding the
  engine's documented stack-corruption hazard when completion callbacks add a
  state too early.

## Alpha 14.20 vanilla Bag tags and final Oak dialogue

- Removes generic placeholder icon boxes from iconless vanilla Bag rows and
  detail. Provider-owned Modern Bag snapshots retain the visible missing-icon
  fallback required by Bag Provider API v1.
- Stops drawing OakSpeech's ROM-font `shrinkText` replica. The actual Pixelify
  final dialogue remains on screen until its native A acknowledgement; only
  after that callback starts the hold/fade-to-house transition.

## Alpha 14.19 vanilla Bag and intro timing

- Adds an independent Widescreen skin for the engine's vanilla Bag, including
  rows/counts, money, selected-item detail, USE/TOSS, quantity and confirmation
  overlays. Native Bag/ListMenu callbacks remain authoritative for ordering,
  item use, tossing, targeting, battle turns and inventory mutation.
- A registered Bag Provider API v1 owner still takes precedence over the
  vanilla skin, keeping the expanded Modern Bag path separate.
- Extends the New Game closing transition to a half-second intact-player hold,
  a 1.5-second fade and a half-second fully white bridge before OakSpeech's
  native completion into the house.
- Removes only Yellow Legacy's injected `hard_mode_choice` Oak step. Hard Mode
  itself remains available through its Options row.

## Alpha 14.18 fade-to-house and Bag Provider API v1

- Replaces the visible player shrink/walking-sprite handoff with a one-second
  hold-and-fade transition. Red remains intact, the presentation fades fully
  to white, then native OakSpeech completes into the player's house.
- Publishes generic one-owner Bag Provider API v1. Providers supply immutable
  semantic snapshots and action callbacks for field/battle Bag, pockets,
  search, machine filters, move information, item options and confirmation.
- Widescreen owns responsive drawing, focus/scroll presentation,
  keyboard/controller hints, pointer regions, icon rendering and native-layer
  suppression. It does not classify, sort, search, persist or use items.
- Invalid mandatory-provider snapshots produce one deduplicated actionable
  error and an opaque incompatibility page—never a native Bag fallback.
  Missing/corrupt item icons receive a visible category fallback.
- Final contract and schema: `BAG_PROVIDER_API_V1.md`. Minimum dependent-mod
  floor: `gen1_widescreen_ui >= 0.1.0-alpha.14.18 <0.2.0`.

## Alpha 14.17 New Game composition and pacing fixes

- Removes the decorative heading and red rule from the Oak scene, freeing the
  full upper field for the active character or Pokemon artwork.
- Docks a shorter intro-specific dialogue panel four pixels from the bottom.
  Oak's legacy 18-column line, CONT and page controls are reflowed against a
  safe 68-column/two-line budget, keeping text inside the panel while removing
  width-only A-button confirmations.
- Detects the known extracted-data case where Red/Blue player and rival preset
  banks are mislabeled, and swaps only those two stable OakSpeech requests.
  Correct and total-conversion name banks remain untouched.
- Runs the first 29 frames of the player-picture shrink at half speed, making
  the transition into the overworld walking sprite readable without delaying
  the subsequent walk/fade or changing sequence callbacks.

## Alpha 14.16 widescreen New Game opening

- Replaces the 160x144 Professor Oak opening draw pass with the established
  640x360 Widescreen presentation while retaining the engine's native step
  machine, localized text, choices, naming, sounds, music and callbacks.
- Uses exact transparent extractions of the supplied FireRed/LeafGreen Oak,
  Red and rival artwork; these assets are not AI-redrawn.
- Routes Oak's showcased Pokemon through Battle Art Presentation API v1 with
  a stable `oak_speech` animation token. A missing provider, ROM mode, invalid
  result or missing selected asset explicitly falls back to OakSpeech's active
  ROM front sprite and palette.
- Reskins the player/rival naming stage without replacing its native input or
  preset-name behavior. Reveal, wipe and closing shrink timelines remain
  engine-owned.

## Alpha 14.15 FRLG trainer anchor and live throw slide

- Keeps the enemy trainer as one static Dramatic Shape billboard, but raises
  its reported ground anchor from the stock 56px row to the FRLG descriptor's
  64px anchor. All authored pixels therefore remain above the arena plane
  without a duplicate redraw.
- Applies the engine's live trainer-back horizontal offset at the HUD sprite's
  display scale. Red/Leaf's five throw poses now animate while the trainer
  slides smoothly left and completely exits the screen before sendout.

## Alpha 14.13 responsive level-up report

- Replaces the native level-up stat window during battles with the responsive
  Widescreen panel style while keeping the bottom battle message panel visible.
- Keeps native StatBox input, A/B dismissal, callbacks, sound, move learning
  and battle progression unchanged.
- Shows resulting HP, Attack, Defense, Speed and Special values together with
  explicit green `+N` increases.
- Snapshots the engine's experience result and uses its own `Stats.calc` for
  every reached level. Multi-level gains therefore receive accurate
  intermediate reports instead of repeating only the final delta.
- Rare Candy and other native StatBox callers calculate the same prior-level
  comparison when no battle-experience snapshot exists.

## Alpha 14.14 single-owner trainer throw

- Publishes whether the responsive battle HUD currently owns the player
  trainer-back presentation. Character Sprite Replacer uses this live signal
  to suppress its battle-layer throw copy while Widescreen draws the same
  animation once in the final HUD pass.

## Alpha 14.11 wide NPC dialogue pagination

- Reflows ordinary overworld/NPC dialogue against the actual wide box instead
  of retaining the Game Boy window's 18-column line breaks.
- Converts obsolete native newline/CONT layout markers into normal spacing,
  then fits up to two wide lines per page. This removes A-button continuation
  presses that existed only because the original box was narrow.
- Preserves explicit paragraph/page boundaries, final acknowledgement,
  choices, callbacks, text speed, sounds, auto/stay behavior, and non-world
  dialogue such as battle and menu messages.
- Consumes the Character Sprite Replacer's live player-throw frame when its
  five-frame FRLG send-out animation is active, so the final Widescreen battle
  presenter does not freeze on the static back portrait.

## Alpha 14.10 color Trainer Card portraits

- Applies the engine's `MEWMON` palette to the default ROM player portrait
  instead of incorrectly declaring its grayscale source pixels to be finished
  true-color output.
- Draws every native Gym Leader face beside its badge. Locked slots keep both
  the leader and badge monochrome/dimmed; earned slots color the leader from
  the active trainer palette and show the supplied badge at full color.
- Adds Trainer Card Portrait Provider API v1. A player/NPC art owner can
  register `resolvePlayer` and/or `resolveLeader`, returning an image (or an
  image descriptor with `imagePath`, optional frame dimensions, palette and
  `trueColor`). The existing Character Sprite Replacer player-presentation
  export is consumed automatically.
- Also leaves a forward-compatible call to the Character Sprite Replacer's
  optional `resolveTrainerCardPortrait(subject, context)` export, followed by
  `resolveTrainerBattle(trainerId, "front", context)`, so an NPC pack can
  replace Gym Leader portraits without a Widescreen patch.

### Trainer Card Portrait Provider API v1

Register through Widescreen's exports:

```lua
widescreen.registerTrainerCardPortraitProvider({
  owner = "my_character_pack",
  apiVersion = 1,
  resolvePlayer = function(game, trainerCardState, context)
    return { image = playerImage, trueColor = true }
  end,
  resolveLeader = function(game, trainerCardState, context)
    -- context: kind, badgeIndex, trainerId and owned
    return { image = leaderImages[context.trainerId], trueColor = true }
  end,
})
```

Only one provider owns the surface at a time. Re-registration by the same
owner replaces its callbacks; call
`unregisterTrainerCardPortraitProvider(owner)` when relinquishing ownership.

## Alpha 14.9 Trainer Card proportions

- Expands the upper Trainer Card panel from 112 to 144 design pixels and
  enlarges the trainer portrait, grounding it against the panel's lower edge.
- Compresses the badge panel from 142 to 110 design pixels while retaining the
  complete two-row, eight-badge layout. Acquired badges use full color and
  unacquired badges are dimmed; redundant EARNED/LOCKED text is removed.
- Reduces individual badge art from 48 to 35 design pixels so adjacent badge
  slots and their labels remain distinct.

## Alpha 14.8 real asset roots and grounded battle trainer

- Corrects both custom image requests to include their real package-relative
  paths: `assets/shiny_star.png` and `assets/trainer_badges.png`. Inspection of
  the live loader confirmed that `mod.assets:image(relative)` appends
  `relative` directly to the mod root; the earlier bare names therefore could
  not resolve despite the files being installed correctly.
- Restores the supplied star across Party, Summary, Pokedex and Battle HUD and
  restores the supplied badge artwork for earned and locked Trainer Card slots.
- During the battle introduction only, removes the player's trainer-back art
  from Dramatic Shape's arena billboard and redraws it in the final Widescreen
  HUD pass. Its bottom edge is pinned to the message/command panel boundary.
  The player's Pokemon still returns to the 3D arena after send-out.

## Alpha 14.7 runtime star loader and Trainer Card

- Loads the shared `shiny_star.png` through the launcher's mod-scoped
  `mod.assets:image("assets/shiny_star.png")` API. Successful loads remain
  cached; failures are safe,
  retryable and emit one diagnostic for each distinct failure state instead of
  being silently cached forever.
- Uses Shiny System identity (`isShiny`) for the indicator while leaving art
  selection under `shouldUseShinyArt`. Party, Summary, Pokedex and both Battle
  HUD panels therefore share one bitmap indicator without coupling shiny
  identity to the user's art-display setting.
- Adds a responsive Trainer Card and toggle while preserving the native card's
  update, close controls, stack behavior and save data. Name, money, play time,
  player portrait and all eight Kanto badge slots are visible at once.
- Adds the supplied Kanto badge sprites as an exact transparent 8-cell atlas.
  Earned badges render in full color; locked slots remain visibly disabled.
  Gym Leader portraits are intentionally reserved for a later asset pass.

## Alpha 14.6 Pokédex bitmap correction and evolution screen

- Corrects the remaining Pokédex shiny call site to draw the packaged
  `shiny_star.png` bitmap. The obsolete polygon renderer and its misleading
  polygon-counter fixture are removed; all shiny-state privacy and footer
  behavior is unchanged.
- Adds a responsive Evolution screen and option. Native evolution update,
  timing, B cancellation, species application, cry, move learning and TextBox
  callbacks remain engine-owned; Widescreen replaces only the draw pass.
- Alternates the old and evolved forms on the engine's original accelerating
  cadence. Both forms use Battle Art Presentation API v1 with stable
  per-state/species tokens, including animated 2D art and shiny identity.
- When the standalone or legacy Battle Art provider is unavailable, set to
  ROM, or declines the request, the evolution screen resolves the engine's
  active ROM front sprite. Completion dialogue stays on the new Widescreen
  background instead of exposing the 160×144 screen.

## Alpha 14.5 shared shiny indicators

- Adds the supplied gold pixel-star asset to the top-right of the Party detail
  panel and Summary identity panel whenever their current Pokemon is shiny.
- Draws a smaller copy immediately after each shiny Pokemon's rendered name in
  the player and enemy Battle HUD panels. Name measurement and the level column
  remain collision-safe.
- Uses `gen1_shiny_system.shouldUseShinyArt` as the authority when available,
  then falls back to explicit `mon.shiny` or the engine DV test. The icon is
  marked true-color so active palette effects cannot turn it monochrome.
- Keeps the existing Provider API v2 Pokedex vector star and all public APIs
  unchanged.

## Alpha 14.4 active-shiny Pokedex star

- Draws one small, outlined gold vector star at the safe top-right of the
  Pokedex detail panel only while its validated owned portrait is actively
  showing shiny art. No font glyph or provider-supplied decorative data is
  used.
- Removes the star immediately when toggling back to normal or changing to a
  normal species. Unknown, unseen, seen/unowned, normal-only, submenu,
  research and provider-fault states cannot retain or leak it.
- Keeps footer-only Select controls, portrait geometry, long-entry focus,
  privacy rules and Provider API v2 unchanged. Consumers requiring the star
  should depend on Widescreen **0.1.0-alpha.14.4 or newer**.

## Alpha 14.3 footer-only Pokedex shiny control

- Removes the duplicate inline `SELECT: SHINY` / `SELECT: NORMAL` hint from
  beneath the Pokedex portrait. The contextual `SELECT SHINY` / `SELECT NORMAL`
  control remains in the Widescreen footer.
- Keeps Select toggling, portrait geometry, privacy validation, long-entry
  Start focus and Provider API v2 unchanged. Consumers that require the
  footer-only presentation should depend on Widescreen **0.1.0-alpha.14.3 or
  newer**.
- Extends the provider regression fixture to reject both inline colon-form
  labels while confirming the footer control and normal/shiny toggle path.

## Alpha 14.2 gender/shiny Pokedex and randomized title Pokemon

- Extends Provider API v2 compatibly with optional boolean
  `detail.portrait.shinyAvailable` and `detail.portrait.shiny`, plus the optional
  `toggleShiny` action. The API number remains **2**; consumers using these
  fields require Widescreen **0.1.0-alpha.14.2 or newer**.
- Accepts shiny presentation only for seen, non-hidden, owned detail snapshots.
  `shiny = true` requires `shinyAvailable = true`, and availability requires a
  registered `toggleShiny` action. Unseen and seen/unowned snapshots cannot
  advertise it.
- Sends only `{ species, shiny }` through the existing live Battle Art/Shiny
  System portrait path with purpose `pokedex`. It never receives party
  identity, DVs, a caught Pokemon object or a second recoloring path.
- `SELECT` toggles normal/shiny when available. If that entry is also long,
  `START` enters the bounded text viewport; its existing scrolling and pointer
  controls remain reachable. Contextual hints appear only when availability is
  validated.
- Draws U+2640 female and U+2642 male as measured presenter-owned vector glyphs
  because Pixelify Sans lacks both characters. Provider strings remain UTF-8
  and unchanged; the glyph-aware truncation path is shared by Pokedex, Party,
  Summary and Battle Pokemon names.
- Starts the title on the correct normal box mascot: Charizard for Red,
  Blastoise for Blue and Pikachu for Yellow. Later Pokemon are random,
  non-repeating selections from valid Gen 1 species data and retain the exact
  outgoing/pause/incoming movement. Each new selection has a **1-in-64** shiny
  presentation chance through the active Battle Art/Shiny System path.
- Yellow keeps its original boot-only Pikachu drop/cry sequence; randomized
  cycling begins only once its interactive title loop is active.

## Alpha 14.1 bounded Pokedex entry scrolling

- Replaces the fixed five-line truncation in Provider API v2's main detail
  panel with a bounded five-line viewport, making every wrapped description
  line reachable regardless of localization or modded entry length.
- Stores transient viewport state per provider state and selected species.
  Selecting a different species starts at its first line, and snapshot changes
  clamp the offset so stale positions can never index outside the entry.
- Uses the Game Boy `SELECT` action to enter a dedicated description focus
  without stealing ordinary species-list or submenu navigation. While focused,
  Up/Down scroll one line, Left/Right scroll five, and A/B/START/SELECT exits.
- Draws contextual upper/lower arrows only when undisplayed lines exist.
  Clicking the description or either arrow enters the same presenter-owned
  focus/scroll path; no coordinates, fonts or raw input enter the provider.
- Adds an eight-line regression fixture covering the first and final lines,
  both clamps, pointer scrolling, focus isolation, short entries and species
  changes. Provider API v2 and its semantic action contract are unchanged.

## Alpha 14.0 Pokedex Provider API v2

- Publishes `pokedexProviderApiVersion = 2` and the complete one-owner semantic
  presenter requested by `gen1_widescreen_pokedex`. API v1 registration and
  list fixtures remain accepted for compatibility; all new dependent work must
  target v2.
- Draws the v2 `pokedex` master-detail screen with a numbered left list, live
  right detail, explicit unseen/seen-unowned/owned privacy, counts, wrapped
  entry text and the exact HABITAT/STATS/LEARNSET/EVOLUTION/CRY submenu.
- Draws typed `pokedex_habitat`, `pokedex_stats`, `pokedex_learnset` and
  `pokedex_evolution` research snapshots, including explicit empty/gated rows,
  bounded long-list viewports, numeric stats, type badges and em dashes for
  malformed stat values.
- Adds `updatePokedexProviderInput(game, state, dt)`. It maps B/START, A,
  directions and left/right paging to `back`, `select`, `up`, `down`,
  `pageUp` and `pageDown` during the provider state's update—not during draw.
- Routes mouse/touch list selection and submenu activation through
  Widescreen-owned final-resolution hit regions and the same `selectRow` and
  `selectSubmenu` callbacks. CRY remains a provider action and the presenter
  never closes its submenu itself.
- Validates the five v2 screen schemas and isolates action/snapshot failures.
  Invalid data preserves the last valid immutable view; if no valid view has
  existed, an opaque provider-error view is shown, never a native layer.
- Resolves only a normal species portrait at draw time through the current
  Battle Art policy, using stable per-state/species animation tokens. Hidden
  entries never request art, shiny state is never inferred, and Stadium models
  are never flattened.
- Keeps native Pokedex rendering unchanged with no registered provider and
  forces the Widescreen Pokedex option while either v1 or v2 owns a state.

### Provider API v2 contract

Required actions are `up`, `down`, `pageUp`, `pageDown`, `select`, `back`,
`selectRow`, `selectSubmenu`, and `scroll`. Unsupported actions fail safely;
provider exceptions are logged once per unique failure. `toggleShiny` is an
optional action required only when `detail.portrait.shinyAvailable == true`.

Supported schema-v2 `screen` values are `pokedex`, `pokedex_habitat`,
`pokedex_stats`, `pokedex_learnset`, and `pokedex_evolution`. The main snapshot
supplies rows, selection, counts, privacy-safe detail and the optional exact
five-row submenu. Research snapshots supply species identity, selection,
scroll and mode-specific typed rows. Widescreen reads these snapshots as
immutable and never receives live save/content tables.

Failure policy: after a provider state matches, invalid/throwing snapshots
retain that state's last valid snapshot. Before its first valid snapshot,
Widescreen displays an opaque non-identifying error page. Unregistering or
same-owner re-registration clears cached views, hit regions and errors.

## Alpha 13.0 responsive dialogue

- Replaces the remaining native `TextBox` draw pass with the same crisp,
  integer-positioned Pixelify Sans presentation used by the converted menus.
  The panel docks to the real bottom edge at widescreen and taller aspect
  ratios without changing the world viewport, camera, map or collision.
- Restyles native YES/NO choices with the established dark selection row and
  red focus rail. Anchored choices sit above their dialogue; bare choices dock
  independently at the lower-right edge.
- Leaves the engine's `TextBox:update` and `ChoiceBox:update` methods intact.
  Text speed, held-A/B acceleration, `\n`/`\v`/`\f` behavior, page delays,
  blinking prompts, sounds, callbacks, default-NO state and input ownership
  therefore remain native.
- Preserves the native retained-line scroll animation in the replacement draw
  pass and derives visible text from the engine's glyph count, avoiding byte
  cuts in multibyte characters.
- Keeps responsive Title, START, Load Report, Options/Mod Manager, Party,
  Summary, Pokedex and Battle presentation underneath their dialogue instead
  of exposing an old 160x144 fallback.
- Adds `WIDESCREEN DIALOGUE BOXES`; disabling it restores native dialogue on
  unconverted screens. Converted screens retain their existing responsive
  overlay composition so their suppressed native background cannot reappear.

## Alpha 12.4 unified Battle Art presentation

- Consumes `gen1_battle_art_replacer` alpha 5 Presentation API v1 dynamically
  for every converted Pokemon-art surface: cycling Title sprites, native
  Pokedex entries, Party details, both Summary pages, and the public 2D
  portrait helper used by future Widescreen screens.
- Gives each screen/species or Pokemon/purpose pair a stable weakly-held token,
  allowing genuine Gen 5 animations to retain their authored provider-owned
  timeline without Widescreen decoding or timing an atlas.
- Honors the provider's selected STATIC/ANIMATED mode, Gen 5/Red/Blue/Yellow
  collection, per-instance shiny art and ROM fallback. A provider-owned nil
  returns to the screen's native image and never leaks into the obsolete Voxel
  animation path.
- Retains the stable-image API and Battle Art Voxel path only when Presentation
  API v1 is unavailable, preserving compatibility with older optional setups.

## Alpha 12.3 title animation and Manager state marks

- Moves the resting title Pokemon 15% of its art slot toward the trainer while
  retaining the exact vanilla frame-stepped exit, pause and entrance motion.
- Prefers Battle Art Voxel's live `AnimatedBattleArt` atlas/timing when that
  legacy provider is installed and explicitly set to ANIMATED. The standalone
  `gen1_battle_art_replacer` currently exposes stable still portraits only, so
  its selected image is used when no live animation is selected; missing
  provider art still falls back to the engine title sprite.
- Adds an explicit green checkmark to every enabled Mod Manager row and a red
  X to every disabled row. Selection and staged-change glyphs remain separate,
  and `ManagerState` remains authoritative for enable/toggle behavior.

## Alpha 12.2 Mod Manager and title Battle Art

- Extends Widescreen presentation to the Mod Manager's Mods, Profiles, Errors,
  Details, Permissions and Pending Changes screens while retaining its native
  navigation, staging, dependency resolution, profiles and restart behavior.
- Converts per-mod `options_schema` pages to the same right-list/left-context
  layout as the main Options screen. Live values, number/text activators,
  reset-default actions and no-restart saving remain owned by `ManagerState`.
- Restyles Manager confirmation/notice overlays instead of leaving a classic
  160x144 modal over the responsive screen.
- Resolves cycling title Pokémon through `gen1_battle_art_replacer` first.
  A disabled provider, ROM mode, missing species or missing asset returns nil
  and automatically preserves the engine's original title sprite.
- Preserves the exact vanilla frame-stepped title transition from Alpha 11.3.4.

## Alpha 12.1 responsive Options menu

- Rebuilds the native Options screen as a responsive final-resolution page
  without replacing its update method, row callbacks, save writes or input.
- Shows eight rows at 640x360 instead of four, with responsive capacity at
  taller resolutions and safe selection-centered scrolling for long mod lists.
- Places the options list on the right and a contextual panel on the left with
  the selected value, adjustment arrows, control hint and concise explanation.
- Reads the engine's live semantic row descriptors, so injected mod rows keep
  their labels, values, `step` callbacks and `activate` callbacks. Unknown mod
  rows receive safe generic help instead of being filtered or reconstructed.
- Adds a `WIDESCREEN OPTIONS MENU` toggle; disabling it restores the captured
  native draw immediately.

## Alpha 11.3.4 exact vanilla title transition

- Replaces the smooth simultaneous cross-slide with Red/Blue's original
  frame-stepped `TitleScroll_Out` and `TitleScroll_In` velocity tables.
- Holds the Pokemon for 200 frames, accelerates the old sprite off the left,
  leaves the original one-frame blank pause (plus the five-frame starter-ball
  wait), then decelerates the next sprite in from 120 pixels to the right.
- Scales the original pixel distances for the Widescreen title composition,
  keeps the native state synchronized for the correct START cry, and preserves
  the Alpha 11.3.3 Battle Art and Alpha 11.3.1 World HUD provider APIs.

## Alpha 11.3.3 battle-art provider integration

- Resolves Party and Summary portraits from the live
  `gen1_battle_art_replacer` 2D provider before consulting legacy Battle Art
  Voxel Fork modules.
- Requests a stable portrait frame and preserves ROM/provider fallback when
  the standalone provider has no art for the requested side.

## Alpha 11.3.2 title Pokemon slide transition

- Recreates the original title motion when the displayed Pokemon changes: the
  current sprite slides left while the next sprite enters from the right.
- Follows native random title changes while `TitleState` is active and keeps
  the existing four-second presentation cycle while the main menu covers it.
- Preserves true-color sprites, active palette resolution, native input and
  the Alpha 11.3.1 World HUD Overlay API.

## Alpha 11.3.1 World HUD overlay API

- Adds a multi-owner, draw-only `worldHudOverlayApiVersion = 1` contract.
- Providers receive the responsive visible width/height, active Pixelify Sans
  fonts, Widescreen palette, and the real paper/ink/shadow panel renderer.
- Gen1 Unified Quality of Life uses the contract for its centered location
  banner, so the banner matches Widescreen chrome exactly.
- Provider failures are isolated and cannot disable the base Widescreen UI.

## Alpha 11.3 first-frame title and report readability

- Owns the standalone `TitleState` from its first rendered frame, so boot no
  longer exposes the original 160x144 title before the Widescreen page.
- Keeps native START/A behavior: the Widescreen title page is shown first and
  its responsive menu appears when the native state opens that menu.
- Enlarges and centers the logo, draws Blue/Red version ribbons from their
  exact original source slices, and color-keys unused light canvas pixels so
  no white asset rectangles remain.
- Honors the engine's true-color marker for cycling title Pokemon; true-color
  replacement art keeps its source colors while raw DMG assets use the active
  title/species palette.
- Formats the compact mod-difference notice as one readable statement per row
  in Load Report.

## Alpha 11.2 title fidelity and live color

- Applies the engine's active title/species palette shader when final-pass UI
  draws raw logo, version, trainer, title-Pokemon and Pokedex portrait sheets;
  these assets no longer revert to black and white.
- Keeps the title card above its version ribbon, with the cycling Pokemon on
  the left and trainer on the right in separate grounded slots.
- Advances the displayed title Pokemon every four seconds while the menu is
  open without consuming gameplay RNG or replacing native menu input.
- Suppresses the original 160x144 title-menu draw whenever the Widescreen Main
  Menu owns presentation. Full-screen paper layers are now opaque, preventing
  old menu or Pokedex pixels from showing through.

## Alpha 11 title flow and Load Report

- Rebuilds the title main menu as a responsive full-window composition using
  the active game's existing logo, version, trainer and title-Pokemon assets.
- Restyles CONTINUE, NEW GAME, OPTION and EXIT GAME without changing their
  native callbacks or modded `ui.title_menu.items` rows.
- Replaces the CONTINUE save summary with readable Player, Badges, Pokedex and
  Time rows while preserving A-confirm and B-back behavior.
- Rebuilds Load Report from its read-only validation report at screen width,
  with clear sections, scrolling state, continuation controls and no save
  mutation.
- Main-menu animation/input and Load Report scrolling/dismissal remain owned by
  their native state classes.

## Alpha 10.1 independent Pokedex correction

- Recognizes the native Pokedex directly from its engine ListMenu identity and
  title, so the Widescreen presentation works without Pokedex+ and remains
  reliable when constructor load order prevents marker injection.
- Removes all Pokedex+ lookup, model consumption and compatibility behavior.
- Publishes generic Pokedex Provider API v1 for the planned
  `gen1_widescreen_pokedex` mod: register, unregister, active-owner lookup and
  guarded semantic action dispatch.
- Validates immutable schema-v1 snapshots and accepts exactly one provider
  owner. Invalid providers fall back safely without replacing native data.

## Alpha 10 presentation-only Pokedex foundation

- Restyles the native Pokedex list, option menus and entry page with the same
  cream, charcoal, red-accent, panel and typography system as the other
  converted screens.
- Leaves all navigation, discovery flags, DATA, CRY, AREA, search, habitat,
  stats, evolution and move callbacks with their existing owner.
- Publishes no new Pokedex gameplay behavior. The planned dedicated Widescreen
  Pokedex mod remains responsible for future layout and functionality changes.

## Alpha 9.1 full-height battle anchoring

- Battle HUD panels now use the full visible window height while preserving
  the world's uniform scale and geometry.
- The enemy panel anchors to the real top edge, and command, message, and move
  panels anchor to the real bottom edge on 4:3 displays.
- Voxel battle HUD providers are patched at battle creation, before their
  private native-HUD snapshot is captured, with a first-overlay fallback for
  unusual load orders.
- 16:9 presentation is unchanged, and the Alpha 9 Move Inspector contract is
  retained.

## Alpha 11.1 Battle HUD overlay API

- Exposes a multi-owner, draw-only `battleHudOverlayApiVersion = 1` contract.
- Registered overlays receive the actual enemy-panel rectangle, the rendered
  name and its measured width, the active Pixelify Sans font set, and the HUD
  palette/panel helper.
- Providers are isolated and disabled after a draw failure, so an optional
  overlay cannot take down the base Battle HUD.
- Gen1 Unified Quality of Life uses this contract to attach its catch display
  to the enemy status panel without guessing screen coordinates.

## Alpha 9 Move Inspector provider API

- Publishes generic Battle Move Inspector API v1 through
  `registerBattleMoveInspector`, `unregisterBattleMoveInspector`, and
  `activeBattleMoveInspectorOwner`.
- Accepts one immutable semantic snapshot provider at a time. Re-registering
  the same owner replaces it safely; a different owner is rejected.
- Validates every snapshot, deduplicates provider errors, and keeps the basic
  move panel usable if a provider fails.
- Extends the existing 2x2 move panel with type, PP, power, accuracy, type-chart
  matchup, STAB, and disabled state when a compatible provider is active.
- Keeps Mimic on the basic detail panel because its copied move has no verified
  target/user semantics at selection time.
- A registered provider forces WIDESCREEN BATTLE HUD on. If its saved toggle is
  off, Widescreen logs one explicit warning and ignores that setting until the
  provider is removed.

Provider contract:

```lua
local ok, reason = widescreen.exports.registerBattleMoveInspector({
  owner = "compatible_mod_id",
  apiVersion = 1,
  snapshot = function(battle)
    return immutableSchemaV1SnapshotOrNil
  end,
})
```

Widescreen never discovers providers by manifest ID and never calls a provider
outside normal `moveSelect` presentation.

## Alpha 8.2 provider and grid corrections

- Suppresses captured native HUD layers from both Dramatic Shape and Battle
  Art Voxel Fork; either provider may own the active 3D battle pipeline.
- Docks the player status panel immediately above the bottom command panel,
  right-aligns both, and keeps the enemy status panel in the upper-left. During
  move selection it lifts above the taller inspector panel to prevent overlap.
- Up/Down changes grid rows while preserving the column. Left/Right changes
  columns while preserving the row, for both normal moves and Mimic.

## Alpha 8.1 battle HUD corrections

- Installs the Dramatic Shape adapter before its world-composition pass, so
  the captured native status HUD is no longer visible behind Widescreen.
- Reduces status, command, message and move-panel dimensions and typography.
- Restores horizontal 2x2 move-grid navigation while retaining the classic
  battlefield layer used to suppress native battle chrome.

## Alpha 8 battle HUD

- Adds a final-resolution 640x360 Battle HUD with enemy/player status panels,
  exact player HP, status conditions and a blue current-level EXP bar.
- Replaces battle messages, the FIGHT/POKEMON/BAG/RUN prompt, Safari commands,
  the scripted Old Man prompt, the 2x2 move menu and Mimic selection.
- The move panel shows live PP, disabled/swap state and the same color-coded
  type badges used by Party and Summary.
- Dramatic Shape integration suppresses only its native snapped HUD and glass
  panels. Its arena, camera, battlers, animations, Stadium models and world
  composition remain untouched.
- Disabling WIDESCREEN BATTLE HUD restores the engine's selected battle layout
  and Dramatic Shape's native HUD presentation.

## Alpha 7.12 direct shiny-system integration

- Party icons and 2D detail/summary portraits consult the shared Gen1 Shiny
  System at draw time, so its master/color options apply without stale caches.

## Alpha 7.11 Shiny Pokemon flag compatibility

- Party icons now honor the explicit `mon.shiny` flag used by the installed
  Shiny Pokemon mod as well as the engine's native shiny-DV calculation.

## Alpha 7.10 shiny icon compatibility

- Standard 32x64 icon descriptors may now provide a `shinyImage` sheet.
- The widescreen party list selects that sheet using the engine's native
  shiny-DV check, matching the standalone HGSS Menu Icons mod.

## Alpha 7.9 icon-provider compatibility

- The widescreen party screen now prefers an active standard 32x64 icon
  descriptor, allowing the standalone `hgss_menu_icons` mod to replace its
  row artwork.
- If no compatible icon provider is active, the existing bundled HGSS atlas
  remains the fallback. The widescreen UI therefore has no new mandatory
  dependency.

## Alpha 7.6 party icons

- The widescreen party screen now bundles its own animated true-colour HGSS
  icons for all 151 Pokemon. It no longer depends on `new_icons`, Wilds, or a
  follower mod to supply its six row icons.
- The icons are stored in one atlas, avoiding the launcher's large-file-count
  import failure.
- The release archive is intentionally flat: no recursive asset directories
  are exposed to Gen1Recomp's fragile ZIP copy routine.

## Alpha 7.5 sprite-quality compatibility

- Modern 32x32 party icons are drawn at native detail on the widescreen
  surface instead of being reduced to the stock 16x16 icon canvas first.
- Overworld follower rendering belongs exclusively to the standalone follower
  mod. The widescreen package no longer patches Wilds or Dramatic Shape.

This package returns to the last confirmed-working alpha 7 baseline and adds
the widescreen Summary/Stats and dialogue-overlap changes. It
replaces the START, Pokemon party, two-page stat-screen and battle-HUD
presentation while
leaving Gen1Recomp's native menu logic and Dramatic Shape's world renderer
intact.

## Current scope

- 640x360 virtual 16:9 layout rendered at final window resolution.
- Responsive integer-perfect scaling at 1080p, 1440p, and 4K.
- Native START menu input, callbacks, cursor persistence, and mod-added rows.
- Independent presentation scrolling so more entries fit on screen.
- Bundled Pixelify Sans UI font, including its SIL Open Font License.
- Pixelify Sans sizes aligned to a 16/12-unit pixel grid for crisper 1080p
  rasterization with nearest-neighbor filtering and integer positioning.
- 22-unit START-menu row rhythm and a two-pass label renderer, preventing
  selection bands from painting over text in adjacent rows.
- Widescreen Pokemon party list with all six members visible, HP bars,
  TM/HM compatibility labels, selected-mon details, and a dedicated action
  panel that never opens over the party list.
- The selected-mon detail panel first consults
  `game.mods.exports.BATTLE_ART_VOXEL_FORK.lib`: STATIC uses that mod's
  `BattleArt.image`, while ANIMATED uses its `AnimatedBattleArt` atlas decoder
  and selected generation. ROM or missing art falls back to
  `Sprites.path(..., "front", { kind = "battle" })`.
- ANIMATED Battle Art advances through the mod's own atlas frames and duration
  metadata in the Pokemon menu. The shared 2D portrait resolver/drawer is
  exported for every subsequent converted UI screen; it deliberately never
  attempts to flatten Dramatic Shape Stadium models.
- The portrait is unframed, long Pokemon names use the smaller UI font when
  necessary, and the quick-info panel shows HP, level, ATK, DEF, SPD, SPC and
  four move names without PP.
- The quick-info panel also shows the selected Pokemon's color-coded type
  capsules and an unlabeled blue current-level EXP bar beneath its HP bar.
- Compact-panel battle portraits receive a bounded aspect-aware size boost,
  improving wide silhouettes such as Kadabra without species-specific rules;
  the move list is compressed slightly so its fourth row clears the border.
- Party icons are still drawn through `PartyMenu.drawIcon`, preserving icon
  replacements and follower-mod draw hooks.
- Non-opaque states above PartyMenu (follower confirmations, field-move
  messages, YES/NO choices and visual overlays) are composed over the
  widescreen presenter. Opaque destinations still replace Party normally.
  This removes the former native-menu fallback path rather than special-casing
  only FOLLOW.
- The original `SummaryMenu` constructor is wrapped once, so every normal
  entry path (Party, PC/Box, scripts, and mod callers) opens the same responsive
  two-page stat screen. Page one shows identity, animated/static 2D Battle Art,
  HP, status, types and the four Gen 1 stats; page two shows experience and all
  four moves with PP.
- Species and move types use compact color-coded capsules for all eighteen
  modern type names. The experience page includes a blue bar calculated from
  the active species growth curve and the current level's exact EXP bounds.
- Widescreen Party and Summary messages suppress the original 160x144
  TextBox/ChoiceBox draw and recompose those overlays in the 640x360 UI. This
  removes the duplicate dialogue that previously remained visible below the
  converted screen.
- The Widescreen Battle HUD keeps battle simulation, timing and input native,
  but draws one final-resolution presentation for status, messages, commands
  and moves. Intro/fainted party markers, Safari, Old Man and Mimic states are
  included instead of falling back to the native HUD.
- No `Renderer:setUISize`, `render.compose`, camera, zoom, voxel, or tilt
  modifications.

## Bundled font

Pixelify Sans is Copyright 2021 The Pixelify Sans Project Authors and is
redistributed under the SIL Open Font License 1.1. Its license is included at
`assets/fonts/pixelify_sans/OFL.txt`.

## Compatibility notes

The Gen 3 Inspired UI mod also replaces the START, Pokemon and battle screens. This
prototype uses instance-level presentation suppression so only one final-pass
presenter is visible. For the cleanest configuration, disable Gen 3 Inspired
UI's **OVERWORLD MENUS**, **POKEMON MENU** and **BATTLE UI** options while
testing this build. Two mods must not own the same final battle presenter.

Battle Art Voxel's STATIC front source is
`assets/battle/front-static/<species>.png`. Its ANIMATED source is the selected
`assets/battle/front-animated/<generation>` collection plus the mod's metadata.
The integration uses the mod's exported loaders rather than reconstructing
those paths, preserving its shiny, transparency, palette and fallback rules.
Dramatic Shape's 2D-3D arenas continue to use these battler images. STADIUM
mode uses live 3D model packs and therefore has no 2D front-image equivalent;
the panel uses the selected Battle Art image or engine front sprite in that
case instead of attempting to flatten a model.

## Planned conversion order

0. START, Party, action overlays and both Summary pages (implemented)
1. Battle HUD, command menu and move selection (implemented in Alpha 8)
2. Independent native Pokedex styling and Provider API v2 (implemented in
   Alpha 14.0; v1 list compatibility retained)
3. Title main menu, Continue summary and Load Report (implemented in Alpha 11)
4. Options and contextual help (implemented in Alpha 12.1)
5. Dialogue and remaining global-font migration (dialogue implemented in
   Alpha 13.0; specialized native widgets remain for later conversion)
6. Full transition, fallback, input and resolution audit

The native Pokedex receives an independent presentation skin and there is no
Pokedex+ compatibility path. The dedicated Pokedex mod now has the complete
Provider API v2 layout/input contract needed to supply master-detail and
research semantics without drawing. Bag Provider API v2 is now implemented
with v1 compatibility;
the dedicated gameplay mod supplies immutable inventory semantics and
callbacks while Widescreen remains the sole presenter.

The Widescreen Dex Radar is a separate dependent mod. This project owns the
semantic Start-menu/presentation API it consumes, but not its encounter data
or radar screen implementation.
