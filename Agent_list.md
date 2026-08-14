# Gen1 Recomp Mod Project — Agent List and Home-to-Work Handoff

Snapshot date: **2026-08-14**

Handoff direction: **Invoker's home PC → Invoker's work PC**

Project root on the home PC:

`C:\Users\invok\OneDrive\Documents\ChatGPT\Gen1 Recomp Mods`

This file is the portable project dashboard. `MASTER_MOD_GUIDE.md` remains the
authority for project-wide rules and ownership. Release manifests and README
files remain the authority for the code actually packaged in a ZIP.

## 1. What “agent” means in this project

Each agent below is a persistent **workstream/ownership role**, usually handled
in its own Codex task. It does not mean a background process will continue to
run after changing computers. Live conversation context, temporary terminals,
installed-mod folders and unsaved development directories must not be assumed
to transfer automatically.

On the work PC, recreate an agent by opening a new task and giving it:

1. this file;
2. `MASTER_MOD_GUIDE.md`;
3. the workstream's handoff/design document;
4. the current release ZIP or a newly extracted editable copy;
5. any owner-routed request explicitly listed for that workstream.

Third-party mods studied as references—Advanced Box System, Dex Radar, Catch
Helper, Exp Share, the original Quality of Life mod, Modern Bag UI, Move
Inspector, Yellow Legacy and Battle Art Voxel Fork—are **not** our agents and
must remain read-only unless the user explicitly changes that instruction.

## 2. Status legend

- **RELEASED:** A canonical ZIP exists. This does not imply final user
  acceptance on every platform or mod combination.
- **EXPERIMENTAL:** A ZIP exists, but broader real-map/in-game validation is
  still important.
- **READY:** The design and provider prerequisites exist; implementation can
  begin.
- **PLANNED:** The handoff exists, but implementation or a required audit has
  not started.
- **ARCHIVED:** Preserved for history; do not resume without user approval.

## 3. Current agent roster

| Agent/workstream | Owner surface | Status | Current artifact | Immediate next action |
|---|---|---|---|---|
| Master / Integration Agent | Architecture, ownership, memory, release retention and handoffs | ACTIVE | `MASTER_MOD_GUIDE.md` | Keep this dashboard and Master synchronized after every release or major decision. |
| Gen1 Widescreen UI Agent | All responsive 640×360 presentation and generic UI provider contracts | RELEASED | `gen1_widescreen_ui` `0.1.0-alpha.14.32` | Treat Storage Provider API v1 as complete; regression-test new consumers without moving their semantics into Widescreen. |
| Widescreen Grid Box Agent | Bill's PC storage navigation and atomic party/box transactions | SOURCE BUILD / RELEASE PENDING | Source `0.1.0-alpha.1`; no Grid Box ZIP yet | Update the source dependency from Widescreen alpha 14.31 to 14.32, run final provider/visual audits, then package. |
| Widescreen Modern Bag Agent | Bag pockets, order/preferences, item icons and semantic Bag provider | RELEASED | `gen1_widescreen_modern_bag` `0.1.0-alpha.5` | Maintain against Bag Provider API v2; no known blocking task. |
| Widescreen Pokédex Agent | Read-only Pokédex navigation and Habitat/Stats/Learnset/Evolution/Cry models | RELEASED | `gen1_widescreen_pokedex` `0.1.0-alpha.7` | Maintain provider compatibility and live Habitat/shiny data; no known blocking task. |
| Widescreen Move Inspector Agent | Immutable highlighted-move semantics | RELEASED | `gen1_widescreen_move_inspector` `0.1.0-alpha.2` | Maintain against Widescreen Battle Move Inspector API v1; never calculate final battle damage. |
| Kanto Dex Radar Agent | Start-menu radar using the effective spawn snapshot | READY | No Radar ZIP yet | Implement from `NEXT_AGENT_WIDESCREEN_DEX_RADAR.md`; consume only Kanto Living Encounters' `getEffectiveSpawnSnapshot`. |
| Unified Quality of Life Agent | Explicit convenience rules, overlays, Catch Helper and EXP modes | RELEASED | `gen1_quality_of_life` `0.1.0-alpha.6` | Continue compatibility testing; preserve independent toggles and vanilla-safe defaults. |
| Battle Art Replacer Agent | Live selectable 2D Pokémon battle/front art and animation | RELEASED | `gen1_battle_art_replacer` `0.1.0-alpha.12` | Maintain provider timing/fallbacks; Pokémon art only, never human or world ownership. |
| Character Sprite Replacer Agent | Player, NPC and enemy-trainer human appearance in overworld/battle | RELEASED | `gen1_character_sprite_replacer` `0.1.0-alpha.8` | Maintain Character Presentation contracts and Dramatic Shape compatibility. |
| HGSS Menu Icons Agent | Normal/shiny static or two-frame menu icon descriptors | RELEASED | `hgss_menu_icons` `0.1.0-alpha.4` | Remain the icon-art owner; consumers decide whether to animate or force frame 1. |
| HGSS Simple Follower Agent | Selected party follower plus independent overworld-sprite provider | RELEASED | `hgss_simple_follower` `0.1.0-alpha.18` | Maintain Overworld Sprite API v1 used by visible wilds; never let consumers take follower-slot ownership. |
| Gen1 Shiny System Agent | Shiny rolls, DVs/state, colors, sparkles and shiny presentation policy | RELEASED | `gen1_shiny_system` `0.1.0-alpha.3` | Maintain Wild Outcome API v1 so visible wild identity and battle identity cannot diverge. |
| Kanto Living Encounters Agent | Visible wild entities, safe cells, AI, pacing and contact battles | EXPERIMENTAL | `kanto_living_encounters` `0.1.0-alpha.4` | Continue real-map/manual audits; it now exports the snapshot needed by Dex Radar. |
| Gen1 Balances Agent | Live encounters/fishing, selected stats/learnsets and additive trade-evolution level paths | RELEASED / VALIDATION PENDING | `gen1_balances` `0.1.0-alpha.2` | Re-run Gate 6 against Kanto Living Encounters alpha 4; the formerly missing live-table adapter now exists. |
| Bill S.S. Ticket Repair Agent | Narrow Bill quest/save repair and Echoes fallback compatibility | RELEASED | `gen1_bill_ss_ticket_repair` `0.1.1` | Maintain only the verified Bill repair; do not absorb general quest behavior. |
| Dramatic Shape Battle Lighting Patch Agent | Neutral lighting for flat battle billboards under Dramatic Shape 1.8.x | RELEASED | `dramatic_shape_battle_shadow_patch` `0.2.0` | Re-audit before allowing Dramatic Shape 1.9.x; fail closed on unknown renderer versions. |
| Yellow Legacy Recreation Agent | Former full Yellow Legacy recreation analysis | ARCHIVED / SUPERSEDED | Planning and gate documents only | Do not resume trainer/move/Hard Mode/rematch/quest scope unless the user explicitly reauthorizes it. |

## 4. Agent details and durable handoffs

### 4.1 Master / Integration Agent

Read first:

- `Agent_list.md`
- `MASTER_MOD_GUIDE.md`

Responsibilities:

- enforce ownership boundaries and route cross-mod fixes to the owning agent;
- keep installed mods read-only;
- keep releases flat/root-only and never install builds automatically;
- preserve the latest three releases per mod during user-requested cleanup;
- update current versions, dependencies, completed prerequisites and plans;
- verify claims against the current ZIP and installed engine payload.

The verified engine baseline is Gen1Recomp **0.1.83**, API 2, save format 4.
The project is Gen 1-only unless an individual mod explicitly implements and
tests Gold/Silver.

### 4.2 Gen1 Widescreen UI Agent

Current release:

`Releases/gen1_widescreen_ui_v0.1.0-alpha.14.32.zip`

Major completed provider surfaces include Battle Move Inspector, Pokédex,
Bag, Trainer Card portraits, battle/world overlays and Pokemon Storage.
Alpha 14.32 completes Pokemon Storage Provider API v1 with:

- 5×4 Box grid and six-slot Party drawer presentation;
- ACTIVE-box badge;
- visible/clickable PARTY button;
- held-origin, valid-target, swap and invalid-target states;
- static icon-frame enforcement and animated 2D detail portraits;
- fail-closed last-valid snapshots and pointer/controller/keyboard routing.

Completed/historical owner requests:

- `GEN1_WIDESCREEN_UI_STRUCTURED_MACHINE_DETAIL_REQUEST.md`
- `GEN1_WIDESCREEN_UI_PC_SHINY_STAR_REQUEST.md`
- `GEN1_WIDESCREEN_UI_STORAGE_PROVIDER_REQUEST.md`
- `WIDESCREEN_STORAGE_PROVIDER_V1_COMPLETION_REQUEST.md`

Do not ask this agent to implement Grid Box transactions, Bag organization,
Pokédex data, Move Inspector calculations or storage save mutations.

### 4.3 Widescreen Grid Box Agent — next primary build

Read:

- `NEXT_AGENT_WIDESCREEN_GRID_BOX.md`
- `GEN1_WIDESCREEN_UI_STORAGE_PROVIDER_REQUEST.md`
- `WIDESCREEN_STORAGE_PROVIDER_V1_COMPLETION_REQUEST.md`
- Widescreen alpha 14.32's `POKEMON_STORAGE_PROVIDER_API_V1.md`

Status: **source alpha 1 exists; release completion is ready**. The prior
Widescreen blocker is resolved, but the source manifest/README still name
alpha 14.31 and must be updated to the finalized alpha 14.32 floor before
packaging.

Accepted design decisions:

- project name is Widescreen Grid Box, not Pokédex;
- Bill's PC root is Withdraw, Deposit, Move Pokemon, Change Box, Yellow Print
  Box, See Ya; Release is removed;
- 20 visual cells are backed by Gen1Recomp's dense arrays, not persistent
  sparse holes or a parallel save format;
- browsing another box does not change `save.currentBox`; native Change Box
  remains the explicit active-box/save operation;
- pickup is non-mutating until a validated atomic drop/swap commits;
- B/provider loss/reload cancels safely without losing a Pokémon;
- static icons use frame 1; the right detail portrait may animate;
- Advanced Box System conflicts and is behavioral reference only.

First implementation gate: build and test the pure transaction module before
creating the UI state.

### 4.4 Kanto Dex Radar Agent — second ready build

Read:

- `NEXT_AGENT_WIDESCREEN_DEX_RADAR.md`
- `WILDS_OF_KANTO_MOD_DESIGN.md`
- current Kanto Living Encounters and Widescreen contracts

Status: **ready to implement**. Kanto Living Encounters alpha 4 exports:

- `resolveSpawnTable`
- `getSpawnSnapshot`
- `getEffectiveSpawnSnapshot`
- `invalidateSpawnTables`

The Radar must use `getEffectiveSpawnSnapshot`; it must not read encounter or
fishing registries directly, consume RNG, create visible entities, or mark a
species seen/owned. Confirm the public name and final manifest ID before its
first release.

### 4.5 Kanto Living Encounters and Balances Agents

Kanto Living Encounters alpha 4 is an experimental visible-wild implementation
that preserves classic random encounters. It requires Follower alpha 18 and
Shiny System alpha 3, consumes live encounter tables, and conflicts with the
original Wilds of Kanto (`overworld_wild_spawns`).

Balances alpha 2 passed gates 1–5 and 7, including 187/187 checks. Its Gate 6
was waiting for the visible-spawn live-table adapter. Kanto alpha 4 now reads
`Game.data.encounters`, so Gate 6 should be performed next and the plan updated
with actual results.

Relevant files:

- `WILDS_OF_KANTO_MOD_DESIGN.md`
- `BALANCES_MOD_PLAN.md`
- `BALANCES_ENCOUNTER_TABLE.md`
- `GEN1_SHINY_SYSTEM_WILD_OUTCOME_API_REQUEST.md`
- `HGSS_SIMPLE_FOLLOWER_OVERWORLD_SPRITE_API_REQUEST.md`

### 4.6 Released UI/content agents

Use these handoffs when maintaining the corresponding release:

- `NEXT_AGENT_WIDESCREEN_MODERN_BAG.md`
- `NEXT_AGENT_WIDESCREEN_POKEDEX.md`
- `NEXT_AGENT_WIDESCREEN_MOVE_INSPECTOR.md`
- `NEXT_AGENT_UNIFIED_QUALITY_OF_LIFE.md`
- `NEXT_AGENT_BATTLE_ART_REPLACER.md`
- `NEXT_AGENT_CHARACTER_SPRITE_REPLACER.md`

Several documents began as pre-release plans and contain historical initial
version numbers. The latest ZIP manifest/README overrides those old proposed
numbers. Do not regress a released mod to the initial version in its plan.

### 4.7 Archived Yellow Legacy Agent

The broad recreation is superseded. Preserve these only as research history:

- `NEXT_AGENT_YELLOW_LEGACY_RECREATION.md`
- `YELLOW_LEGACY_GATE0_EVIDENCE.md`
- `YELLOW_LEGACY_GATE1_RESULTS.md`
- `YELLOW_LEGACY_GATE2_CHANGE_LIST.md`
- `YELLOW_LEGACY_RULESET_PLAN.md`

Only the explicitly selected Balances data and narrow Bill repair remain
active descendants of that research.

## 5. Current project priorities

Recommended order on the work PC:

1. **Verify the handoff**: confirm OneDrive finished syncing this root and all
   expected release ZIPs.
2. **Implement Widescreen Grid Box** using Widescreen alpha 14.32's completed
   storage presenter.
3. **Implement Kanto Dex Radar** using Kanto Living Encounters alpha 4's
   effective-spawn snapshot.
4. **Close Balances Gate 6** against Kanto Living Encounters alpha 4.
5. **Continue Kanto Living Encounters manual audits** on routes, caves, water,
   towns, chase transitions, Dramatic Shape and long sessions with classic
   encounters still active.
6. **Normalize manifest game targets on future releases**. Only current
   Widescreen and Bill Repair ZIPs explicitly declare `games: ["gen1"]`;
   several older canonical manifests rely on the engine's legacy Gen 1
   default. They are not proven Gold/Silver-compatible and should gain the
   explicit target when next versioned—never by overwriting an old ZIP.

## 6. Known bookkeeping and cleanup items

- The Master table has been corrected to Kanto Living Encounters alpha 4.
- The Grid Box handoff now has the finalized Widescreen dependency floor
  `>=0.1.0-alpha.14.32 <0.2.0`; the old `PROVIDER_RELEASE` placeholder is gone.
- `Releases` currently contains Kanto Living Encounters alpha 1–4. The normal
  latest-three policy means alpha 1 should be moved to `Releases/Old versions`
  during the next explicit cleanup. Do not delete it.
- Widescreen alpha 14.30–14.32 are the three current retained versions.
- Release files are authoritative even if an older paragraph in a planning
  document still names a prior alpha.

## 7. What transfers through OneDrive—and what does not

Expected to transfer if OneDrive is fully synchronized:

- this project root;
- all Markdown memory/handoff files;
- `Releases` and `Releases/Old versions`;
- any editable source directory stored inside this project root.

Do **not** assume these home-PC paths transfer:

- installed mods:
  `C:\Users\invok\AppData\Roaming\pokemon-love2d\mods`;
- Gen1Recomp update payloads under the AppData save directory;
- saves, options, logs and ROM caches under AppData;
- the former editable source tree:
  `C:\Users\invok\Documents\Codex\2026-08-08\ok`;
- temporary Codex terminals, task-local context or uncommitted files outside
  the OneDrive project root.

Installed mod folders are references, not canonical editable sources. On the
work PC, install/import the desired canonical ZIPs through Gen1Recomp's
launcher. Do not edit the installed copies. If development source did not
sync, extract the latest ZIP into a new task-specific development directory.

If the same playthrough is needed at work, separately back up and transfer the
appropriate `pokemon-love2d\saves` content only after closing the game. Keep a
recoverable copy and do not overwrite a newer work-PC save blindly.

ROM files and ROM-derived caches are not part of this mod repository. Import a
legally obtained ROM again on the work PC as required; never package it in a
mod ZIP or OneDrive release folder.

## 8. Work-PC resume checklist

1. Wait for OneDrive to report that the project root is fully available
   offline.
2. Confirm these files exist:
   `Agent_list.md`, `MASTER_MOD_GUIDE.md`, the selected `NEXT_AGENT_*.md`, and
   the latest relevant release ZIP.
3. Install/run Gen1Recomp 0.1.83 or re-audit and update the baseline if a newer
   engine is intentionally used.
4. Import the required current mods through the launcher; never auto-copy a
   build into the installed-mod directory from an agent.
5. Reacquire or manually transfer any third-party reference mod that the task
   genuinely needs to inspect. Preserve its license and keep it read-only.
6. Create a fresh editable development directory outside the installed-mod
   folder, ideally inside the synced project root if both computers must see
   the source.
7. Read the Master guide completely before making changes.
8. Verify the current manifest/version from the ZIP, not from an old prompt.
9. Run tests with the work PC's actual Lua/Gen1Recomp environment before
   packaging.
10. Build a new flat, root-only ZIP with a new version; do not overwrite any
    delivered archive.
11. Update `MASTER_MOD_GUIDE.md` and this file after delivery.

## 9. Copyable resume prompts

### Master Agent prompt

```text
You are the Master Agent for my Gen1 Recomp mod compilation on my work PC.
Read Agent_list.md and MASTER_MOD_GUIDE.md completely before acting. Treat
release ZIP manifests/READMEs as the code-version source of truth, keep
installed mods read-only, enforce cross-mod ownership, and never install a
build automatically. First audit the synced files and report any mismatch;
then continue from the priorities in Agent_list.md.
```

### Workstream Agent prompt

```text
You are the [WORKSTREAM NAME] Agent for my Gen1 Recomp mod compilation. Read
MASTER_MOD_GUIDE.md, Agent_list.md, and [RELEVANT HANDOFF]. Inspect the latest
relevant release ZIP and public provider contracts before editing. Own only
the surface assigned to this workstream. If another mod must change, stop at
that boundary and produce the provider-owner prompt required by the Master
guide. Work in an editable source directory, never in the installed-mod
folder, and do not install the resulting ZIP automatically.
```

## 10. Snapshot warning

This file records the project as of 2026-08-14. On returning to the home PC,
compare versions and modification times before copying anything back. If work
continued on both computers, merge the documentation and editable source
deliberately; do not let OneDrive conflict resolution silently choose between
two different mod releases with the same filename.
