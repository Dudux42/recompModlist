# Gen1 Unified Quality of Life — Phase 0 Audit

Date: **2026-08-10**  
Audited engine: **Gen1Recomp 0.1.71**, API 2, Lua 5.1  
Working identity: **Gen1 Unified Quality of Life** / `gen1_quality_of_life`  
Initial version: **0.1.0-alpha.1**

This report is the mandatory pre-implementation deliverable defined by
`NEXT_AGENT_UNIFIED_QUALITY_OF_LIFE.md`. The public name and manifest ID remain
provisional until the first release candidate.

## 1. Licensing and provenance

| Reference | Finding | Implementation policy |
|---|---|---|
| Catch Helper 1.4.0 | MIT license included; copyright notice says `Copyright (c) 2026`. | Its exact probability-enumeration approach may be reused with the MIT notice retained. |
| EXP Share Modes 1.0.0 | MIT license included; copyright notice says `Copyright (c) 2026`. | Its mode semantics may be reused, but the new engine hook makes its private `enemyMonFainted` wrapper and private StatBox unnecessary. |
| Quality of Life 1.2.7 | No license in the installed package. The upstream repository has no license file or declared repository license as audited on 2026-08-10. | Reimplement behavior independently. Do not copy or redistribute its source, prose, or assets. |
| Gen1Recomp engine | Local packaged 0.1.71 source audited from the user's installed executable. | Use its documented API 2 hooks and registries. Do not package engine source. |

Behavioral inspiration will be credited separately from reused MIT code.

## 2. Hook and ownership map

### Quality of Life 1.2.7

| Feature | Reference ownership | Replacement |
|---|---|---|
| EXP bar and owned marker | Wraps each battle instance's `draw`; special-cases Dramatic Shape's snapped HUD state. | One `battle.overlay` dispatcher with isolated layers. A narrow, version-guarded Dramatic Shape adapter is permitted only for its world-canvas HUD path. |
| Location banner | Wraps each overworld instance's `drawUI`. | `map.entered` state plus the public presentation hook where usable; no world geometry changes. |
| Easy A interactions | Uses public `world.interacted`, plus direct shared dispatch tables for Select and step completion. | Keep `world.interacted`; use one deterministic guarded input dispatcher and `world.stepped` for wear-off detection. |
| Options | Registers screens and replaces `ManagerState.openOptions`. | Register screens and add one public `ui.options.rows` entry. The Mod Manager retains its native schema UI; no ManagerState replacement. |

### Catch Helper 1.4.0

| Feature | Reference ownership | Replacement |
|---|---|---|
| Owned marker | `battle.overlay`, dynamically anchored after the foe name. | Merged into the single owned-marker layer, with style and signed offsets. |
| Catch odds | `battle.overlay`; exact enumeration of stock two-roll checks. | Independent catch-odds layer using the live merged ball/status/species records. Custom `ball.attempt` means unknown odds. |
| Ultra correction | Whole-record `balls:override`. | Public `catch.rate` hook; only Ultra's stock HP factor changes to 8 in CORRECTED mode. Custom attempts remain authoritative. |

### EXP Share Modes 1.0.0

| Feature | Reference ownership | Replacement |
|---|---|---|
| EXP distribution | Permanent wrapper on `BattleState.enemyMonFainted`, temporary inventory removal, copied StatBox. | Public `battle.exp_award` hook and the engine-provided `ctx.applyShare`. No inventory mutation, copied UI, or private continuation patch. |

## 3. Verified engine APIs

The installed 0.1.71 engine exposes these usable public contracts:

- `battle.overlay(battle)` — invoked by classic and native wide battle draws.
- `battle.exp_award(ctx)` — `ctx` includes `battle`, `participants`, `alive`, and the exact native `applyShare` continuation.
- `exp.gain(ctx)` — applied inside every `applyShare`; Yellow Legacy Hard Mode caps therefore also reach Modern bench awards.
- `catch.rate(ball, mon, speciesDef, opts)` — public capture-rule composition point.
- `battle.started`, `battle.ended`, `battle.exp_gained`, and `pokemon.level_up` events.
- `world.interacted`, `world.stepped`, `map.entered`, `map.exited`, and `save.loaded` events.
- `fieldmove.eligibility`, `encounter.fishing`, `render.hud`, and `ui.options.rows` hooks.
- `mod.options:define/get`, `mod.events:on/once`, `mod.hooks:wrap`, `mod.find`, registered screens, content registries, and namespaced exports.

Important consequences:

1. The EXP modes no longer require `engine_internals` or a private StatBox.
2. Classic and native wide overlays share one public hook.
3. There is no public Select-action or repel-expired hook in 0.1.71. A single
   guarded OverworldController input adapter is still required for Select;
   wear-off can be observed from `world.stepped` without wrapping
   `onStepComplete`.
4. Dramatic Shape 1.5.5 and Battle Art Voxel Fork 1.7.6 export only their
   internal library loader, not a stable HUD adapter. Their snapped world-HUD
   path therefore needs a narrow optional adapter or a safe classic-UI fallback.

## 4. Final option hierarchy and defaults

All gameplay-changing defaults are vanilla-safe.

### Battle Display

| Option | Values | Default |
|---|---|---|
| EXP BAR | OFF / ON | OFF |
| OWNED INDICATOR | OFF / GEN2 / RED / GREY | OFF |
| CATCH ODDS | OFF / ON | OFF |
| BALL X OFFSET | -304…304 | 0 |
| BALL Y OFFSET | -144…144 | 0 |

### Battle Rules

| Option | Values | Default |
|---|---|---|
| ULTRA BALL RULE | VANILLA / CORRECTED | VANILLA |
| EXP DISTRIBUTION | VANILLA / PARTICIPANTS / ALL EVEN / MODERN 50% | VANILLA |

### World Convenience

| Option | Values | Default |
|---|---|---|
| LOCATION BANNERS | OFF / 1 / 2 / 3 SEC | OFF |
| EASY INTERACTIONS | OFF / ON | OFF |
| CUT GRASS | OFF / ON | OFF |
| WATER ACTION | FISH FIRST / SURF FIRST / FISH ONLY / SURF ONLY | FISH FIRST |
| REPEL PROMPT | OFF / ON | ON |

`VANILLA` EXP calls the engine unchanged, including native EXP.ALL.
`PARTICIPANTS` is the old reference `OFF` behavior, but is named honestly.

## 5. Exact catch fixtures

Fixture: catch rate 45, maximum HP 100. Percentages enumerate every possible
first roll and the exact second-roll chance; the HUD rounds half up to an
integer. `Uv` is vanilla Ultra and `Uc` is corrected Ultra.

| HP | Status | P | G | Uv | Uc |
|---:|---|---:|---:|---:|---:|
| 100 | none | 6 | 11 | 10 | 15 |
| 100 | PAR | 11 | 17 | 18 | 23 |
| 100 | SLP | 16 | 24 | 27 | 32 |
| 50 | none | 12 | 23 | 21 | 30 |
| 50 | PAR | 17 | 29 | 29 | 38 |
| 50 | SLP | 22 | 35 | 38 | 47 |
| 1 | none | 18 | 23 | 30 | 30 |
| 1 | PAR | 23 | 29 | 38 | 38 |
| 1 | SLP | 28 | 35 | 47 | 47 |

Safari fixture: rate 127, max HP 100, HP 50, no status, Safari Ball =
**58.940397%**, displayed as **59%**.

## 6. Exact EXP fixtures

Fixture: defeated species `baseExp=64`, level 10, not trainer, not traded,
three living party members, two participants. Engine order is
`floor(baseExp / split)`, then `floor(* level / 7)`, with minimum one.

| Mode | Awards | Total |
|---|---|---:|
| VANILLA, no EXP.ALL | participants 45 + 45 | 90 |
| VANILLA, with EXP.ALL | participants 22+7 each; bench 7 | 65 |
| PARTICIPANTS | participants 45 + 45 | 90 |
| ALL EVEN | 30 + 30 + 30 | 90 |
| MODERN 50% | participants 45 + 45; bench 45 | 135 |

The vanilla EXP.ALL total of 65 is intentional engine behavior: its second
pass inherits the participant division. Headline pool percentages are
approximate because the engine floors before multipliers and enforces a
minimum award of one. Trainer and traded multipliers remain inside
`ctx.applyShare`; the suite will lock their floor order separately.

## 7. Legacy migration

| Legacy source | Unified target |
|---|---|
| `quality_of_life.qol_exp_bar` | `expBar` |
| `quality_of_life.qol_caught_indicator` | `ownedIndicator` |
| `quality_of_life.qol_location_banners` | `locationBanners` |
| `quality_of_life.qol_easy_interactions` | `easyInteractions` |
| `quality_of_life.qol_cut_grass` | `cutGrass` |
| `quality_of_life.qol_water_interaction` | `waterAction` |
| `quality_of_life.qol_repel_prompt` | `repelPrompt` |
| `catch_helper.show_catch_text` | `catchOdds` |
| `catch_helper.pokeball_x/y` | `ballXOffset` / `ballYOffset` |
| `catch_helper.show_pokeball` | `ownedIndicator=gen2`, only without explicit QOL indicator |
| `exp_share_modes.mode=off` | `expDistribution=participants` |
| `exp_share_modes.mode=classic` | `expDistribution=all_even` |
| `exp_share_modes.mode=modern` | `expDistribution=modern_50` |

Migration runs only when the unified bucket has no user settings, never
deletes legacy data, never infers the Ultra correction, and skips while any
conflicting reference mod is enabled.

## 8. Manifest and compatibility plan

- Conflicts: `quality_of_life`, `catch_helper`, `exp_share_modes`.
- No mandatory dependencies.
- Optional integrations: `gen1_widescreen_ui`, `DRAMATIC_SHAPE`,
  `BATTLE_ART_VOXEL_FORK`, `gen1_shiny_system`, `hgss_menu_icons`,
  `hgss_simple_follower`, `overworld_wild_spawns`, and
  `yellow_legacy_changes`.
- Widescreen: use the live battle surface and public options/presentation
  hooks; never alter renderer size or world composition.
- Dramatic Shape/Battle Art: use only HUD placement state; never art, camera,
  terrain, geometry, collision, or voxel ownership.
- Wilds: act only after `world.interacted` reports `none`; visible entities and
  followers therefore win interaction priority.
- Yellow Legacy: all custom awards call the engine `applyShare`, which in turn
  calls the public `exp.gain` cap hook.
- Shiny/icons/follower/Battle Art: no owned registries or state overlap.

## 9. Lua 5.1 baseline

Executed with `F:\Games\gen1recomp-win64\lua51.dll` through the collection's
`run_lua51_test.py`:

- `gen1_widescreen_ui/tests/start_menu_test.lua` — PASS
- `hgss_menu_icons_mod/tests/icon_mod_test.lua` — PASS
- `hgss_simple_follower/tests/simple_follower_test.lua` — PASS
- `gen1_shiny_system/tests/shiny_system_test.lua` — PASS

## 10. Alpha 1 verification result

`gen1_quality_of_life/tests/unified_qol_test.lua` now passes under the shipped
Lua 5.1 DLL. It covers entrypoint loading, one-hook ownership, catch fixtures
and error restoration, six growth curves, level-cap/multi-level EXP animation,
recipient plans and hook delegation, migration/conflict rules, graphics-state
isolation, field priority/rod/Repel/Strength behavior, and location fallback,
suppression, duplicate timing and save resets.

The five canonical regression suites pass, including Widescreen's Battle HUD
test. A focused schematic classic/wide/voxel audit is retained under
`visual_audits`; the real-font, palette, Dramatic Shape and launcher import
pass remains an explicit user-side in-game test.

Release `gen1_quality_of_life_v0.1.0-alpha.1.zip` contains 10 root entries,
zero duplicates and zero nested paths. It was not installed automatically.

## 11. Alpha 2 scope correction

At the user's direction, alpha 2 removes the EXP bar completely because
Widescreen already owns that presentation. The former four-mode EXP selector
is replaced by one disabled-by-default `EXP SHARE` toggle. When enabled,
participants retain the normal full-pool split and every other living party
member independently receives a half share (`applyShare(..., 2, false)`). One
combined `Remaining POKEMON received EXP!` message replaces per-recipient
gained-EXP lines; native level-up, move, stat and evolution flows remain live.

Release `gen1_quality_of_life_v0.1.0-alpha.2.zip` contains 10 root entries,
zero duplicates and zero nested paths. Its packaged EXP module contains no EXP
bar renderer and does contain the combined summary path. It was not installed
automatically.

## 12. Alpha 3 HM/TM expansion

Alpha 3 adds two enabled-by-default, independently toggleable systems:

- `FIELD HMS`: HM acquisition (Bag, PC, or canonical acquisition flag)
  replaces taught-move and badge eligibility. The Start menu owns one HMs
  screen; Cut, Surf, Strength, automatic cave Flash, manual Flash/Fly and
  plain-Town-Map Fly all confirm through Yes/No prompts. Individual Pokemon
  submenu HM actions are suppressed while this owner is enabled.
- `REUSABLE TMS`: native successful TM teaching is converted from `learn` to
  `learnkept`. Bag acquisition rejects duplicate TMs across Bag and PC, marts
  cap quantity at one, Game Corner prize selection rejects owned TMs, PC
  withdrawal moves the unique copy transactionally, and old stacks normalize
  to one on load.

Public hooks own HM eligibility and Start/party-menu insertion. Narrow,
idempotent engine-internal adapters are required for plain Town Map A-selection,
TM result conversion, global Bag acquisition, mart quantity and PC withdrawal.

## 13. Alpha 4 enemy-HUD integration

Alpha 4 reduces the former four-style ownership selector to one
`CAUGHT INDICATOR` toggle. Its only presentation is a red Poke Ball beside the
rendered wild-enemy name; trainer Pokemon are excluded. The manual X/Y offset
options are removed from the schema and UI. Legacy style values migrate to the
enabled toggle, while obsolete offsets remain inert only for rollback safety.

Catch odds no longer use the custom 3x5 block glyphs. Widescreen UI alpha
11.1 exposes Battle HUD Overlay API v1, providing the real enemy-panel/name
layout and active Pixelify Sans fonts. QoL registers a draw-only provider and
renders catch odds in a footer attached to that panel. The native fallback
uses the engine battle font and the enemy HUD's established origin.

The QoL, Widescreen Start/Battle HUD, and Move Inspector Lua 5.1 suites pass.
The alpha 4 QoL archive retains 11 root entries and the alpha 11.2 Widescreen
archive retains its canonical manifest/main/README/assets structure. Neither
release was installed automatically.

## 14. Alpha 5 fixed field and capture rules

At the user's direction, alpha 5 removes Easy Interactions in full: no fishing
arbitration, grass cutting, Select dispatcher, Teleport/Dig shortcuts, or
water-action option remains. Field HM interaction is the single contextual
owner: water always prompts Surf, real Cut targets prompt Cut, and ordinary
tall grass is ignored. Repel renewal remains independently toggleable.

The Ultra Ball selector is also retired. Stock Ultra Balls permanently use
the corrected HP factor 8; third-party custom attempt functions remain
authoritative. Obsolete alpha 1-4 option keys stay inert for rollback, and the
migration marker advances to version 5.

Location banners now draw in final physical screen-space, centered at the top
at 125% of the normal 640x360 presentation scale. This prevents 3D camera or
world-viewport transforms from pinning the label to the left edge. The Lua 5.1
QoL, Widescreen Start/Battle HUD, and Move Inspector suites pass.

## 15. Alpha 6 Widescreen location-banner ownership

Widescreen UI alpha 11.3.1 adds World HUD Overlay API v1, a multi-owner,
draw-only contract that provides responsive view dimensions, Pixelify Sans
fonts, the active Widescreen palette and its real paper/ink/shadow panel
renderer. Provider failures are isolated from the base UI.

QoL alpha 6 registers its location banner through that contract. The name is
centered in a 48-unit Widescreen panel at the top of the visible screen. The
former engine-font final-screen renderer remains only as a fallback when
Widescreen is absent. Both coordinated archives were built without modifying
an installed mod.
