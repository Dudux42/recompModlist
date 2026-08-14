# Unified Quality of Life Mod — Next-Agent Handoff

Last updated: **2026-08-10**

## 1. Objective

Create one independently maintained Gen 1 Recomp quality-of-life mod that
unifies the useful behavior of these installed reference mods:

1. `quality_of_life` 1.2.7.
2. `catch_helper` 1.4.0.
3. `exp_share_modes` 1.0.0.

The unified mod must keep each feature independently configurable, eliminate
duplicate ownership, preserve compatibility with the collection's current and
planned mods, and make gameplay-changing rules explicit rather than hiding them
inside visual options.

Working title: **Gen1 Unified Quality of Life**  
Provisional manifest ID: `gen1_quality_of_life`  
Initial target version: `0.1.0-alpha.1`

Confirm the public name and ID before release. Do not reuse any installed
reference manifest ID.

## 2. Read-only reference locations

Study these folders completely before implementation:

```text
C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\quality_of_life
C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\catch_helper
C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\exp_share_modes
```

Also read:

- `MASTER_MOD_GUIDE.md`
- `WILDS_OF_KANTO_MOD_DESIGN.md`
- `NEXT_AGENT_BATTLE_ART_REPLACER.md`
- `NEXT_AGENT_YELLOW_LEGACY_RECREATION.md`
- Current manifests and exports of the four canonical mods

Treat installed mods as reference material. Do not edit or install into their
directories.

## 3. Audited reference behavior

### 3.1 Quality of Life 1.2.7

Manifest ID: `quality_of_life`; priority 100; `engine_internals` permission.

Features:

- Animated in-battle EXP bar.
- Owned-species Poke Ball indicator with Gen 2, red, and grey styles.
- One-, two-, or three-second location banners.
- Easy A-button Cut, Strength, Surf, and fishing interactions.
- Select-button field-move menu for Fly, Teleport, Flash, and Dig.
- Repel shortcut, weakest-first consumption, and optional wear-off prompt.
- Custom nested Quality of Life options screen.
- Classic, wide, and Dramatic Shape battle-overlay adaptations.

Reference options:

| Key | Values/default |
|---|---|
| `qol_exp_bar` | OFF / ON; default OFF |
| `qol_caught_indicator` | OFF / GEN2 / RED / GREY; default OFF |
| `qol_location_banners` | OFF / 1 / 2 / 3 seconds; default OFF |
| `qol_easy_interactions` | OFF / ON; default OFF |
| `qol_cut_grass` | OFF / ON; default OFF |
| `qol_water_interaction` | FISH FIRST / SURF FIRST / FISH ONLY / SURF ONLY; default FISH FIRST |
| `qol_repel_prompt` | OFF / ON; default ON |

Important implementation details:

- A shared battle-overlay service wraps each battle's `draw` method.
- Dramatic Shape integration reaches into its `OverworldBattle.snapHUDs`
  implementation and tracks whether HUD canvases were snapped.
- Location banners wrap each overworld instance's `drawUI` method.
- Easy interactions install shared dispatch tables on
  `OverworldController.handleInput` and `onStepComplete`.
- The custom options screen redirects the manager's `openOptions` method.
- Pixel art is drawn with nearest-neighbor behavior and integer placement.

### 3.2 Catch Helper 1.4.0

Manifest ID: `catch_helper`; priority 120; MIT license; no internal permission.

Features:

- Dynamic owned-species Poke Ball marker anchored after the enemy name.
- Signed X/Y marker offsets.
- Whole-number catch probabilities for Poke, Great, Ultra, or Safari Ball.
- Exact direct enumeration of the stock two-roll Gen 1 catch checks.
- Live use of merged ball/status/species records when available.
- An unconditional gameplay change: Ultra Ball receives `hpFactor = 8`, giving
  it Great Ball's stronger HP factor while retaining its stronger first roll.

Reference options:

| Key | Values/default |
|---|---|
| `show_pokeball` | OFF / ON; default ON |
| `show_catch_text` | OFF / ON; default ON |
| `pokeball_x` | -304 to 304; default 0 |
| `pokeball_y` | -144 to 144; default 0 |

The owned marker overlaps Quality of Life's caught indicator. The unified mod
must have one marker renderer and one option family, not two icons drawn in the
same HUD.

### 3.3 EXP Share Modes 1.0.0

Manifest ID: `exp_share_modes`; priority 140; MIT license;
`engine_internals` permission.

Reference modes:

- `OFF`: living participants only; vanilla EXP.ALL is temporarily ignored.
- `CLASSIC EVEN SPLIT` (default): one full EXP pool divided over every living
  party member.
- `MODERN PROGRESSIVE`: participants divide the normal full pool while living
  nonparticipants divide a separate 50% pool, yielding approximately 1.5x
  total EXP.

Fainted Pokemon receive no EXP. The mod temporarily removes `EXP_ALL` from the
inventory during distribution so its own rule is the only active owner. It
wraps `BattleState.enemyMonFainted`, preserves participant messages, adds bench
messages, reproduces a native-style stat box, handles move learning and
happiness, and emits `battle.exp_gained` for bench awards.

Critical naming issue: the reference's `OFF` mode is not completely vanilla
when the player owns EXP.ALL; it actively ignores that item.

## 4. Product and ownership boundary

The unified mod owns only opt-in convenience and information features:

- Battle EXP bar.
- Owned-species indicator.
- Catch-probability display.
- Optional Ultra Ball correction.
- Configurable EXP distribution.
- Location banners.
- Easy contextual field interactions.
- Repel shortcut and renewal prompt.
- Its own responsive options hierarchy and migration of legacy settings.

It does not own:

- Battle, menu, Summary, Pokedex, Bag, or dialogue layout as a whole.
- Pokemon/trainer/player battle art.
- Shiny state, odds, recoloring, or sparkle effects.
- Followers or visible wild entities.
- Encounter-table contents or native encounter probability.
- Yellow Legacy level caps, moves, species data, or trainer teams.
- World geometry, camera, collision, voxels, or Dramatic Shape rendering.

## 5. Recommended unified option model

Use one top-level `QUALITY OF LIFE` screen with narrow submenus.

### Battle Display

| Option | Values | Recommended default |
|---|---|---|
| EXP BAR | OFF / ON | OFF |
| OWNED INDICATOR | OFF / GEN2 / RED / GREY | OFF |
| CATCH ODDS | OFF / ON | OFF |
| BALL X OFFSET | signed integer | 0 |
| BALL Y OFFSET | signed integer | 0 |

The owned indicator combines Quality of Life's styles with Catch Helper's
dynamic name anchor and offsets.

### Battle Rules

| Option | Values | Recommended default |
|---|---|---|
| ULTRA BALL RULE | VANILLA / CORRECTED | VANILLA |
| EXP DISTRIBUTION | VANILLA / PARTICIPANTS / ALL EVEN / MODERN 50% | VANILLA |

Definitions:

- `VANILLA`: do not interfere with engine distribution, including EXP.ALL.
- `PARTICIPANTS`: reference EXP Share `OFF`; living participants only and
  EXP.ALL ignored.
- `ALL EVEN`: reference Classic Even Split; one full pool across all living
  party members.
- `MODERN 50%`: participants receive the normal full pool and living bench
  Pokemon split a separate half pool.

Adding a true `VANILLA` mode is necessary. A setting called OFF should not
silently disable a legitimate vanilla key item. Preserve the old mode through
migration by mapping legacy `off` to `PARTICIPANTS`.

Gameplay-safe defaults are recommended because installing a QOL package should
not silently change catch odds or party leveling. The user may choose different
release defaults later, but the README must state them prominently.

### World Convenience

| Option | Values | Recommended default |
|---|---|---|
| LOCATION BANNERS | OFF / 1 / 2 / 3 SEC | OFF |
| EASY INTERACTIONS | OFF / ON | OFF |
| CUT GRASS | OFF / ON | OFF |
| WATER ACTION | FISH FIRST / SURF FIRST / FISH ONLY / SURF ONLY | FISH FIRST |
| REPEL PROMPT | OFF / ON | ON |

Fly, Teleport, Flash, Dig, and Repel remain in the Select shortcut while Easy
Interactions is enabled. Strength, Cut, Surf, and fishing use the contextual A
path without taking ownership from NPC or visible-wild interaction.

## 6. Unified battle-overlay architecture

Create one overlay dispatcher and register the EXP bar, owned marker, and catch
odds as independent layers. Do not wrap `battle.draw` separately per feature.

Preferred flow:

```text
battle.overlay public hook
  -> resolve current layout context
  -> classic / wide / Dramatic Shape adapter
  -> draw EXP bar
  -> draw owned marker
  -> draw catch odds
  -> restore canvas, shader, color, scissor, and transform
```

Requirements:

- Draw after the base HUD but before later modal UI where appropriate.
- Respect battle shake, HUD shake, intro slide, send-out, faint, Safari, ghost,
  demo, trainer, and naming phases.
- Use the Widescreen UI's live presentation surface when it owns the battle
  HUD in the future.
- Use Dramatic Shape's public adapter/export if available. Reaching into
  `OverworldBattle.snapHUDs` is a last resort and must be version-guarded.
- Draw exactly one owned marker.
- Use nearest-neighbor filtering and integer final placement.
- Restore graphics state even when one overlay errors.
- Disable only the failing overlay, not the entire battle UI.

### Owned marker

- Snapshot whether the encounter species was owned when the battle began.
- Show only for eligible wild/Safari encounters.
- Anchor using actual rendered font width or glyph metrics, not raw byte count.
- Avoid collision with level/status text for long names.
- Apply signed offsets after automatic anchoring.
- Preserve Gen2, red, and grey styles.
- Mark true-color pixels correctly under active palettes.

### Catch odds

- Display whole-number percentages.
- P/G/U for normal wild battles and S for Safari.
- Use the battle's effective merged ball definition, species catch rate,
  current HP, status catch bonus, and Safari rate.
- Enumerate the exact engine checks or call a stable engine probability helper
  if one exists.
- Unsupported custom `ball.attempt` implementations display unknown rather than
  inventing a probability.
- This display must never consume a ball, mutate inventory, roll capture, or
  modify the save.

### Ultra Ball correction

- Treat this as a separate gameplay rule, not part of `CATCH ODDS`.
- VANILLA leaves the merged Ultra Ball record untouched.
- CORRECTED changes only the minimum fields needed for `hpFactor = 8` behavior.
- Prefer a patch over a whole-record override so toss animation and compatible
  third-party fields survive.
- HUD calculation and actual capture behavior must read the same effective
  record.
- Document and test priority against other ball-mechanics mods.

## 7. EXP distribution architecture

Use one idempotent dispatcher around the engine's EXP-recipient routine. Avoid
copying private battle UI unless no public continuation API exists.

Requirements for all modes:

- Fainted Pokemon receive no EXP.
- Preserve trainer and traded bonuses.
- Preserve stat EXP, happiness, level-up sound/messages, stat screen, move
  learning, evolution scheduling, event emissions, and battle continuation.
- Restore temporary participant/inventory/continuation state on both success
  and error.
- Do not permanently remove or consume EXP.ALL.
- Read the selected mode for each defeated opponent or clearly document a
  restart requirement.
- Install once across reloads and fall back to vanilla if the mod is disabled.

Mode formulas:

```text
VANILLA:
  call engine unchanged

PARTICIPANTS:
  recipients = living participants
  pool = 100%
  ignore EXP.ALL during this award only

ALL EVEN:
  recipients = all living party Pokemon
  pool = 100%
  divide evenly
  ignore EXP.ALL during this award only

MODERN 50%:
  participant recipients split 100% pool
  living nonparticipants split separate 50% pool
  ignore EXP.ALL during this award only
```

Rounding and minimum-one behavior must be measured against the engine, then
locked in tests. Report if actual total EXP differs from the headline formula.

Do not build a fixed 160x144 private StatBox if the engine can display the
standard stat window. Any fallback presenter must support classic and
widescreen UI without altering world geometry.

## 8. Easy-interaction architecture

Preserve the reference behavior while improving dispatcher determinism:

- NPC/script interactions have priority over QOL actions.
- Visible wild contact/interactions have priority over Cut/Surf/fishing.
- A-button Strength activates only for genuine pushable boulders.
- Cut may target bushes automatically; grass cutting follows its own option.
- Fishing uses the strongest owned rod.
- Repels are consumed weakest first: Repel, Super Repel, Max Repel.
- Fishing is unavailable while already surfing unless the engine explicitly
  supports it.
- Select shortcut appears only when an eligible action exists.
- Dig is excluded from Agatha's room and restricted to valid tilesets/maps.
- Fly and Teleport require outside eligibility and a party user.
- Flash applies only in a dark area with a party user.
- Repel renewal waits until the wear-off message is acknowledged.

Replace unordered `pairs()` dispatcher iteration with deterministic priority
or a public hook chain. Every wrapper must be idempotent and removable/fail-open
across hot reload.

## 9. Location-banner architecture

- Resolve the live town-map/location label, then map label, then sanitized map
  ID fallback.
- Suppress the Rock Tunnel Poke Center false-positive as the reference does.
- Do not repeat a banner when adjacent maps share the same displayed location.
- Reset state correctly across save/game changes.
- Use a presentation-layer overlay rather than permanently replacing an
  overworld instance's `drawUI` when a public overlay hook exists.
- Scale correctly in classic, widescreen, and Dramatic Shape views without
  modifying the world camera or geometry.

## 10. Legacy option migration

The unified mod should provide a one-time, testable migration when its own
settings are absent and old settings remain in `options.modOptions`.

Suggested mapping:

```text
quality_of_life.qol_exp_bar             -> expBar
quality_of_life.qol_caught_indicator    -> ownedIndicator
quality_of_life.qol_location_banners    -> locationBanners
quality_of_life.qol_easy_interactions   -> easyInteractions
quality_of_life.qol_cut_grass           -> cutGrass
quality_of_life.qol_water_interaction   -> waterAction
quality_of_life.qol_repel_prompt        -> repelPrompt

catch_helper.show_catch_text            -> catchOdds
catch_helper.pokeball_x                  -> ballXOffset
catch_helper.pokeball_y                  -> ballYOffset
catch_helper.show_pokeball               -> ownedIndicator only when no
                                            explicit QOL indicator exists

exp_share_modes.mode=off                 -> PARTICIPANTS
exp_share_modes.mode=classic             -> ALL EVEN
exp_share_modes.mode=modern              -> MODERN 50%
```

The reference Catch Helper's Ultra correction has no option. Do not infer that
the user wants the correction merely because an old options bucket exists.
Prompt/document the decision or default it to VANILLA.

Migration rules:

- Run once per save/options profile.
- New unified settings always win.
- Never delete legacy option buckets automatically.
- Log what was migrated without exposing unrelated save data.
- Do not migrate while an old conflicting mod is enabled.

## 11. Compatibility with the project

### Gen1 Widescreen UI

- Central presentation integration.
- The unified QOL options screen and battle overlays must support its current
  and future presenter APIs.
- Do not hardcode a replacement world renderer or change `Renderer:setUISize`
  in a way that affects world composition.

### Dramatic Shape / Battle Art Voxel Fork

- Compatible through a narrow optional HUD-placement adapter.
- Do not touch terrain, camera, collision, world zoom, voxel geometry, or art
  selection.
- Test snapped and unsnapped HUD states and 3D battles on/off.

### Gen1 Shiny System

- Compatible; no ownership overlap.
- Catch odds use species/HP/status only and must not reroll shiny state.
- Owned marker is per encounter species and independent of shiny presentation.

### HGSS Menu Icons and Simple Follower

- Compatible; no registry or follower ownership.
- EXP distribution may level/evolve follower Pokemon through normal engine
  flows; verify the follower refreshes only after those flows complete.

### Kanto Living Encounters

- Easy interactions must not swallow contact with visible wild entities.
- Repel renewal continues to control native `repelSteps`; whether repels affect
  visible wilds remains owned by the visible-wild design and must not be
  silently decided here.
- Fishing uses the live encounter tables supplied by Yellow Legacy or other
  content mods.

### Yellow Legacy Ruleset

- EXP awards in every custom mode must pass through Yellow Legacy Hard Mode's
  `exp.gain` cap hook, including Modern 50% bench awards.
- Hard Mode's temporary Set-style wrapper and the EXP dispatcher both touch the
  enemy-fainted flow; test both load orders and repeated `game.ready` events.
- Hard Mode item blocking must remain authoritative over the Repel shortcut in
  battle; world Repel use remains allowed.
- Yellow Legacy's modified fishing tables must remain live.

### Battle Art Replacer

- Compatible; QOL overlays must not resolve or cache Pokemon battle art.
- Long/animated art must not obscure catch text or HUD anchors.

### All Pokemon Catchable 151

- Separate content/encounter availability mod. Do not absorb it into this QOL
  project without an explicit user request.
- Catch odds and owned markers should naturally work with its species tables.

## 12. Manifest dependencies and conflicts

Proposed manifest behavior:

- No mandatory dependency on Widescreen, Dramatic Shape, Shiny System, Wilds,
  Yellow Legacy, follower, icons, or battle art.
- Optional integrations only where stable public exports are consumed.
- Declare conflicts with:
  - `quality_of_life`
  - `catch_helper`
  - `exp_share_modes`
- Do not conflict with `all_pokemon_catchable_151_mod`.

The new mod replaces the three reference owners and must never be enabled with
them, or duplicate overlays and EXP/catch-rule ownership will result.

## 13. Licensing and attribution

- Catch Helper and EXP Share Modes ship under MIT. Retain their MIT license and
  copyright notice if their code or substantial portions are reused.
- The installed Quality of Life package contains no license file. Verify its
  upstream license before copying code, UI text, or implementation details.
- Behavior may be recreated independently, but unlicensed source must not be
  repackaged merely because it is locally installed.
- Credit all three reference projects and distinguish behavioral inspiration
  from copied licensed code.

## 14. Required tests

### Overlay tests

- EXP bar progress for every growth curve, level cap, level-up, and multi-level
  gain.
- Owned marker Off/Gen2/Red/Grey, long names, offsets, and owned-at-start state.
- Catch odds for full HP, 1 HP, every status bonus, Safari, zero/high catch
  rates, and each stock ball.
- Catch display and actual Ultra Ball odds agree in both rule modes.
- Classic, wide, Dramatic Shape, palette/inverted modes, shake, intro, faint,
  menu, and modal overlays.
- Graphics state is restored after normal draw and injected errors.

### EXP tests

- VANILLA preserves EXP.ALL behavior exactly.
- PARTICIPANTS, ALL EVEN, and MODERN 50% recipient sets and totals.
- Fainted Pokemon excluded.
- Participant fallback when flags are empty.
- Trainer/traded bonuses, rounding, minimum one, Stat EXP, happiness, messages,
  stat screen, move learning, evolution, and event emission.
- Temporary state restored after errors.
- Hot reload installs one dispatcher only.
- Yellow Legacy Hard Mode caps every recipient, including Modern bench awards.

### Field tests

- NPC, sign, script, follower, and visible-wild interactions win priority.
- Cut bush/grass option combinations.
- Strength on valid and invalid targets.
- All four water-action modes with rod-only, Surf-only, both, neither, and
  already-surfing states.
- Strongest rod selection.
- Fly/Teleport/Flash/Dig eligibility and cancellation.
- Weakest-first Repel selection and exact inventory decrement.
- Wear-off prompt order, No response, no inventory, and chained text boxes.
- Location label fallback, suppression, duplicate names, timing, and save/map
  transitions.

### Migration and integration tests

- Each legacy option mapping and precedence rule.
- No migration when unified settings already exist.
- No legacy bucket deletion.
- Conflict declarations.
- Widescreen, Dramatic Shape, Shiny, follower, Wilds, Yellow Legacy, and Battle
  Art integration smoke tests.

## 15. Implementation sequence

### Phase 0 — Engine and license audit

1. Verify upstream licenses.
2. Identify current public overlay, options, interaction, EXP, and ball-content
   APIs.
3. Capture baseline screenshots and numeric catch/EXP fixtures.
4. Decide final defaults with the user.

### Phase 1 — Options and overlay foundation

1. Create flat modular source layout and manifest.
2. Implement responsive nested options and legacy migration.
3. Implement one overlay dispatcher with classic/wide/voxel adapters.
4. Add EXP bar, unified owned indicator, and catch odds.

### Phase 2 — Explicit gameplay rules

1. Add Vanilla/Corrected Ultra Ball rule.
2. Add four EXP distribution modes, starting with true Vanilla.
3. Verify Hard Mode cap integration before enabling non-vanilla defaults.

### Phase 3 — World convenience

1. Add location banners through a public overlay path.
2. Add deterministic easy-interaction and step dispatchers.
3. Test Wilds/follower/NPC interaction priority and live fishing tables.

### Phase 4 — Release

1. Run unit, integration, and focused visual tests.
2. Produce classic/wide/voxel audit images.
3. Build a flat root-only ZIP.
4. Audit manifest, entry, version, duplicates, licenses, and README.
5. Place the ZIP in `Releases`.
6. Do not install it.

## 16. Required first deliverable from the next agent

Before implementation, provide:

1. Verified upstream license findings.
2. A hook/ownership map of all three reference mods.
3. The current engine public APIs that can replace direct monkey-patches.
4. The final option hierarchy and explicit default recommendations.
5. Exact catch-probability and EXP-distribution fixtures.
6. A legacy migration table and conflict manifest plan.
7. A compatibility plan for Widescreen, Dramatic Shape, Wilds, Yellow Legacy,
   Shiny, follower, icons, and Battle Art.
8. A Lua 5.1 test plan and baseline results.

Do not begin by concatenating the three `main.lua` files. Consolidate ownership,
then reproduce behavior behind one coherent API and one options system.

## 17. Release checklist

- All gameplay changes are explicit and independently toggleable.
- True Vanilla EXP and Vanilla Ultra Ball modes are verified.
- Only one owned marker and one EXP dispatcher exist.
- Classic, wide, and Dramatic Shape rendering inspected visually.
- Native encounters, Wilds ownership, followers, shiny logic, and world geometry
  remain untouched.
- Legacy option migration tested.
- Required MIT and other verified licenses included.
- Manifest conflicts with all three superseded mods.
- Version updated in manifest, README, source header, and ZIP filename.
- Flat ZIP placed in `Releases` and not installed automatically.

