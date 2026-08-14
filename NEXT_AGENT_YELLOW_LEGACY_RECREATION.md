# Yellow Legacy Ruleset Recreation — Archived Full-Scope Handoff

> Superseded on 2026-08-11 by `BALANCES_MOD_PLAN.md`. The active mod is
> `gen1_balances`, limited to live encounters/fishing, Yellow Legacy-derived
> stats and learnsets, and additive level alternatives that preserve trade
> evolutions. Do not implement the broader scope below without new user
> authorization.

Last updated: **2026-08-10**

## 1. Objective

Recreate the behavior of the installed `yellow_legacy_changes` 1.10.3 mod as
an independently maintained mod for this Gen 1 Recomp collection. Preserve its
gameplay results while designing its ownership and integrations around the
collection's other current and planned mods.

This is not permission to overwrite, edit, or repackage the installed mod.
Study it read-only, verify provenance and licensing, build new editable source
in a separate development directory, and deliver a flat ZIP for manual launcher
import.

Working title: **Gen1 Yellow Legacy Ruleset**  
Provisional manifest ID: `gen1_yellow_legacy_ruleset`  
Initial target version: `0.1.0-alpha.1`

Confirm the public name and ID before release. Never reuse
`yellow_legacy_changes`, because that ID belongs to the installed reference mod.

## 2. Mandatory first reads

Read these documents completely before implementation:

1. `MASTER_MOD_GUIDE.md`.
2. `WILDS_OF_KANTO_MOD_DESIGN.md`.
3. `NEXT_AGENT_BATTLE_ART_REPLACER.md`.
4. The current manifests and public exports of the four canonical mods.
5. The installed reference mod at:
   `C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\yellow_legacy_changes`

The installed reference contains:

- `manifest.json`
- `main.lua`
- `learnsets.lua`
- `trainers.lua`
- `rematches.lua`
- `hardmode.lua`
- `crystal_tear.lua`
- `README.md`
- `CHANGELOG.md`
- `mod.card`
- `Yellow-Legacy-Rival-Teams-with-Starters.xlsx`
- `tests/yellow_legacy_changes_test.lua`

Do not assume the README is the complete specification. Trace every content
operation, hook, direct engine replacement, fallback, and edition gate in code.

## 3. Audited reference baseline

Reference manifest:

- ID: `yellow_legacy_changes`
- Version: `1.10.3`
- API: 2
- Profile: `content`
- Category: `BALANCE`
- Priority: 100
- Permission: `engine_internals`
- Declared dependencies/conflicts: none

Audited data surface:

| Surface | Reference scope |
|---|---:|
| Move patches | 73 moves |
| Base-stat patches | 27 species |
| Level-up learnsets | all 151 species |
| TM/HM compatibility | 146 species |
| Encounter maps | 57 maps |
| Rebalanced trainer classes | 44 classes |
| Rematch teams | 12 |
| Rival route variants | 3 starter routes across 8 battles |
| Evolution records replaced | 6 species records |

The installed workbook has four sheets:

1. `Overview` — route mapping and eight-battle evolution timing.
2. `Jolteon Bulbasaur` — Bulbasaur-line rival route.
3. `Flareon Charmander` — Charmander-line rival route.
4. `Vaporeon Squirtle` — Squirtle-line rival route.

The workbook is a source/audit artifact for rival teams. It is not the complete
source for learnsets, TM/HM data, and encounters; those are embedded in the Lua
tables, while the README refers to another `Data.xlsx` that is not present in
the installed folder.

## 4. Required behavior parity

### 4.1 Moves

Recreate all 73 move patches exactly, including changed power, accuracy, PP,
type, priority, and effects. Headline behavior includes:

- Focus Energy provides exactly twice the ordinary critical-hit rate.
- Leech Seed drains a flat 1/8 maximum HP without Toxic-counter multiplication.
- Ghost moves use Special.
- Ghost is super effective against Psychic.
- Bug is neutral against Poison.
- Optional Dragon physical category switch.
- Razor Wind and Skull Bash use Hyper Beam-style recharge behavior.
- Sky Attack loses its charge turn.
- Night Shade becomes a 60-power damaging move.
- Transform gains priority.
- The documented confusion, burn, and flinch side effects land at the intended
  Gen 1 effect probabilities.

Do not implement the README table approximately. Extract a canonical patch
table from the audited reference and test every field.

### 4.2 Species data

- Apply all 27 partial base-stat patches.
- Preserve every unmentioned stat and unrelated species field.
- Replace level-up learnsets for all 151 species.
- Use level-1 entries to seed starting moves.
- Replace TM/HM compatibility for the 146 listed species.
- Resolve names safely, including distinct `NIDORAN_M` and `NIDORAN_F` IDs.
- Reject unknown move/species data predictably; do not create partial trainer
  parties or silently merge the two Nidoran forms.

### 4.3 Evolutions

Required evolution records:

| Species | New evolution |
|---|---|
| Kadabra | Alakazam at level 42 |
| Machoke | Machamp at level 38 |
| Graveler | Golem at level 38 |
| Haunter | Gengar at level 42 |
| Poliwag | Poliwhirl at level 18 |
| Poliwhirl | Poliwrath with Water Stone |

The Poliwag line must retain its normal two-stage shape. Do not reproduce the
older erroneous Poliwhirl-at-level-18 behavior described in historical
changelog entries.

### 4.4 Encounters and fishing

- Replace grass, surf, and rod slots for the 57 audited maps.
- Preserve each map's existing encounter rate.
- When adding a missing surface table, use a documented safe rate fallback so
  no `nil` rate can crash an encounter roll.
- Preserve per-map Old Rod, Good Rod, and Super Rod pools.
- Do not suppress or replace the engine's normal encounter probability loop.
- Read and patch the live content registry so other content providers can
  participate predictably.

### 4.5 Trainers and rival routes

- Replace complete parties for the 44 audited trainer classes.
- Preserve party indexes referenced by map scripts.
- Drop an invalid party as a whole; never create a shortened accidental team.
- Append the 12 rematch teams with a `rematchIndex` marker.
- Keep rematch teams dormant unless a compatible rematch owner consumes the
  marker.
- Brock is not otherwise rebalanced; append his rematch to the live base
  parties rather than replacing his normal party.

Yellow-only rival rule:

- On Yellow, replace the rival's Eevee/Eeveelution route with Bulbasaur,
  Charmander, or Squirtle lines.
- Jolteon route maps to Bulbasaur.
- Flareon route maps to Charmander.
- Vaporeon route maps to Squirtle.
- Early fixed-index battles must resolve the current `save.rivalStarter` route
  at battle time.
- On Red and Blue, preserve the engine's normal counter-pick rival teams and do
  not append Yellow Legacy rival rematch content.

The reference applies most non-rival balance changes to Red, Blue, and Yellow;
only rival content is edition-gated. Preserve that behavior for parity unless
the user explicitly chooses a Yellow-only total ruleset.

### 4.6 Dragon Physical option

Expose a persisted `DRAGON PHYS` toggle:

- Default: OFF.
- OFF: Dragon remains Special.
- ON: Dragon becomes Physical.
- Apply immediately to the live type record.
- Survive save/options reload.
- Do not cache the old damage category in consumers.

Use a documented public option contract where possible. Avoid mutating an
untracked runtime table without a cache invalidation path.

### 4.7 Hard Mode

Hard Mode is optional and defaults OFF. It must be offered:

1. Through a `HARD MODE` row immediately after Battle Style in the game's
   Options screen.
2. Through a default-No prompt in Oak's new-game introduction.

Both controls must write the same persisted option.

When enabled, Hard Mode owns exactly three rules:

1. Forced Set battle style for the enemy-fainted/send-out decision only. The
   player's stored Shift/Set preference must be restored even after an error.
2. No player item use in battle, except Poke Balls. Refusal consumes neither
   the item nor the turn. Enemy trainer items are unaffected.
3. Badge-based level caps:

| Badges | Cap |
|---:|---:|
| 0 | 12 |
| 1 | 21 |
| 2 | 24 |
| 3 | 35 |
| 4 | 43 |
| 5 | 50 |
| 6 | 53 |
| 7 | 55 |
| 8 | None |

Experience must be trimmed before it crosses the cap and become zero at or
above the cap. Stat experience still accrues through the engine's ordinary
path. Rare Candy is refused at the cap. Pokemon already above the cap are not
deleveled.

### 4.8 Crystal Tear quest

Recreate the complete postgame quest:

- Register non-tossable key item `CRYSTAL_TEAR`.
- Oak gifts it after at least one Hall of Fame record and 150 owned species,
  excluding Mew from the count.
- Bag-full behavior must leave the gift retriable.
- Use is rejected in battle.
- Use is rejected outside Cerulean Cave B1F.
- Use before Mewtwo is dealt with gives the dormant/quiver response.
- Valid use plays Mew's cry and reveal, then starts a level-75 Mew battle.
- Mew's intended moves are Psychic, Mega Punch, Amnesia, and Soft-Boiled.
- The Tear shatters after every battle outcome, including win, catch, flee, or
  loss, making the encounter one-shot.
- Scripted Oak, Mewtwo, and Mew event flags must not collide with other mods.

Audit whether the shared Shiny System can roll or present a shiny scripted Mew.
Do not add a second shiny roll. Record the intended policy and test it.

## 5. Ownership boundary

This ruleset owns:

- Its move, type-chart, species-stat, learnset, TM/HM, evolution, encounter,
  fishing, trainer-party, and rematch data changes.
- Its two options and the three Hard Mode rules.
- Its rival-route adaptation.
- Its Crystal Tear item, gift condition, and Mew quest.

It does not own:

- Menu, Summary, Pokedex, battle HUD, or dialogue layout.
- Battle sprites, trainer art, player art, menu icons, or followers.
- Visible-wild entity creation, AI, collision, or encounter initiation.
- Shiny odds, shiny persistence, recoloring, or sparkle effects.
- World geometry, camera, collision maps, voxels, or Dramatic Shape rendering.
- Generic trainer-rematch triggering.

Keep these boundaries explicit in code and README.

## 6. Integration with this collection

### Gen1 Widescreen UI

- Compatible.
- Register Options rows through the public options-row hook so the Widescreen
  modern presenter can discover them later.
- Never draw the Options screen directly or assume 160x144 coordinates.
- Changed stats, types, moves, and EXP thresholds must appear through live data
  read by Party/Summary screens; do not maintain a duplicate UI-only table.

### HGSS Menu Icons

- Compatible.
- This ruleset does not own icon descriptors or art.
- Same-species data changes must not replace icon registrations.

### HGSS Simple Follower

- Compatible.
- This ruleset must not create or count follower entities.
- Evolution changes should naturally change the selected follower species only
  after the engine completes evolution.

### Gen1 Shiny System

- Compatible optional integration.
- All wild Pokemon created from modified encounter tables must pass through the
  Shiny System's single wild-roll owner.
- Do not write `mon.shiny`, DVs, battle recolors, or sparkles here.
- Scripted Mew behavior needs an explicit integration test, not a second roll.

### Kanto Living Encounters (`WILDS_OF_KANTO_MOD_DESIGN.md`)

- Compatible and strategically important.
- The visible-wild mod's native adapter must consume this ruleset's **live
  patched encounter tables** at map entry.
- This ruleset owns encounter data; Kanto Living Encounters owns visible
  entities, behavior, occupancy, and contact battles.
- Classic random encounters remain active.
- Table changes should invalidate visible-spawn resolution if the provider API
  is already active; otherwise map-entry live resolution is sufficient.
- Do not register a competing visible-spawn provider merely to expose the same
  native tables.

### Gen1 Battle Art Replacer

- Compatible.
- This ruleset owns battle data only; the art mod owns 2D Pokemon/trainer/player
  resolution and animation.
- Trainer class IDs and Pokemon species IDs must remain canonical so the art
  provider can resolve them.

### Dramatic Shape / Battle Art Voxel Fork

- Compatible in principle.
- This ruleset must not touch world placement, battle staging, or sprite
  metrics.
- Test trainer intros, the scripted Mew encounter, ordinary wild battles, and
  rematches with voxel battles both enabled and disabled.

### Trainer Rematch mods

- Optional consumer.
- Preserve the `rematchIndex` marker contract only after inspecting the active
  rematch mod's current API.
- Do not make a rematch mod mandatory merely because dormant teams exist.

### Installed Yellow Legacy Changes

- Conflict. Both mods own the same balance tables, encounter tables, trainers,
  quest, and engine behavior.
- Declare a manifest conflict with `yellow_legacy_changes`.
- Never enable both at once.

## 7. Architecture requirements

Split the implementation into narrow modules instead of a monolithic main:

```text
main.lua
data_moves.lua
data_species.lua
data_learnsets.lua
data_encounters.lua
data_trainers.lua
data_rematches.lua
rules_focus_energy.lua
rules_leech_seed.lua
hard_mode.lua
rival_routes.lua
crystal_tear.lua
compat.lua
```

Because release ZIPs must be flat/root-only, keep these modules at archive root
unless nested paths are explicitly proven safe and approved.

Use shared helpers for:

- Loading sibling files safely.
- Name/constant normalization.
- Idempotent hook installation.
- Option persistence.
- Error logging and fail-open behavior.

Prefer public content and hook APIs. If engine internals are unavoidable,
centralize them in one compatibility module with version guards.

## 8. Problems in the reference implementation not to reproduce blindly

The reference behavior is the target; its plumbing is not automatically the
target.

1. Several engine methods are replaced directly on `game.ready` without an
   obvious idempotence guard. Repeated readiness or reload events could stack
   wrappers. Install every wrapper exactly once.
2. `ItemEffects.use` is wrapped in two separate `game.ready` handlers—one for
   Hard Mode and one for Crystal Tear. Use one coordinated ownership layer or
   verified composable hooks.
3. The installed test depends on `tests.modkit`, but that harness is absent from
   the installed folder. Locate the canonical engine test harness or build an
   equivalent local fixture before claiming the test passes.
4. The installed package contains no `LICENSE` file. Verify upstream code and
   data licenses before copying any implementation or derived tables.
5. The README references `Data.xlsx`, but the installed folder only contains
   the rival-team workbook. Establish auditable provenance for learnsets,
   machines, encounters, and trainer data.
6. Hard Mode reads a persisted option that is not part of the one-row
   `mod.options:define` schema shown in the reference. Verify the supported way
   to declare a hidden/shared option or expose both rows consistently.
7. Direct runtime mutation of Dragon's category must remain coherent across
   reloads, content rebuilds, and other type-chart mods.
8. Cached Oak gift scripts and latched Bag/Menu state must be reset safely
   across save changes and game reloads.

## 9. Failure and conflict policy

- Missing optional data module: log the exact module and do not partially apply
  a tightly coupled dataset unless the partial mode is explicitly safe.
- Unknown learnset/TM move: skip the invalid entry and report counts.
- Unknown trainer species: skip the entire affected party/class patch.
- Missing base encounter map: skip it without inventing a map.
- Missing rate: use the audited surface/sibling/vanilla fallback.
- Missing Hard Mode helper: leave normal gameplay untouched.
- Missing quest helper: do not register an unusable item or half-installed
  event chain.
- Hook incompatibility: fail open toward vanilla and name the conflicting owner.
- Never let a ruleset failure suppress classic encounters, corrupt saves, or
  strand an invisible scripted battle.

## 10. Required test coverage

Use the exact Lua 5.1 runtime shipped with Gen1 Recomp where possible.

### Data tests

- Assert all 73 move IDs and every changed field.
- Assert all 27 species patches and preservation of unpatched stats.
- Validate 151 learnsets and 146 TM/HM tables.
- Validate all 57 encounter map IDs, slot counts, species, levels, and rates.
- Validate all 44 trainer classes and preserved party indexes.
- Validate all 12 rematch teams and marker indexes.
- Validate Nidoran male/female resolution independently.
- Validate all six evolution records.
- Confirm no unexpected registry IDs are created.

### Rules tests

- Focus Energy exact probability threshold in faithful and modern rulesets,
  including high-critical moves.
- Leech Seed exact 1/8 drain, minimum damage, KO boundary, healing cap, and
  coexistence with other residual effects.
- Ghost/Psychic and Bug/Poison effectiveness.
- Dragon Physical option default, persistence, live switching, and reload.

### Hard Mode tests

- Prompt default No and Options row synchronization.
- Temporary Set forcing with restoration on success and error.
- Player items refused without item/turn loss.
- Poke Balls still work.
- Enemy trainer items remain untouched.
- Rare Candy gates at each cap.
- EXP trimming for badge counts 0–7 and no cap at 8.
- Pokemon already over cap are not modified and receive zero EXP.
- EXP All routes through the same cap.

### Edition/rival tests

- Yellow receives all three starter-line routes.
- The first four fixed-index battles follow live `save.rivalStarter`.
- Later rival parties select the correct route indexes.
- Red and Blue keep their native counter-pick parties.
- Yellow-only rival rematches never leak into Red/Blue.

### Crystal Tear tests

- Hall of Fame and exactly 150 non-Mew owned species.
- Mew does not fill another missing dex slot.
- Bag-full retry.
- Wrong map, Mewtwo-not-cleared, already-used, and battle-use refusals.
- Correct level-75 Mew and moves.
- Tear removal and completion flag after catch, KO, flee, and loss.
- Script runner already busy versus idle.
- Save reload and second-use protection.

### Integration tests

- Widescreen Summary shows live patched stats/types/moves.
- Shiny System remains the only shiny owner for modified wild tables.
- Kanto Living Encounters consumes the patched live tables while classic
  encounters continue.
- Follower and menu-icon ownership remain untouched.
- Battle Art provider resolves all modified trainer/species IDs.
- Dramatic Shape battles handle ordinary wilds, trainers, rematches, and Mew.
- Another content mod's higher-priority patch produces deterministic behavior
  rather than load-order-dependent silent corruption.

## 11. Implementation sequence

### Phase 0 — Evidence and licensing

1. Diff the installed 1.10.3 data against its README and changelog.
2. Build machine-readable inventories for every changed ID and field.
3. Verify upstream licenses and provenance for code, disassembly data, PDF
   values, and workbooks.
4. Inspect current engine hooks/options/content APIs.
5. Decide and document edition scope outside the rival changes.

### Phase 1 — Pure content

1. Create manifest and modular flat source layout.
2. Implement moves, stats, evolutions, learnsets, machines, encounters,
   fishing, trainer parties, rematches, and rival data.
3. Add exhaustive validation and data tests before runtime rules.

### Phase 2 — Runtime rules and options

1. Implement Focus Energy and Leech Seed through guarded composable hooks.
2. Implement Dragon Physical persistence and live invalidation.
3. Implement Hard Mode with one centralized item-use layer.
4. Add idempotence/reload tests.

### Phase 3 — Quest and integrations

1. Implement Crystal Tear as an isolated quest module.
2. Test script/map/bag lifecycle and all outcomes.
3. Add collection integration tests and conflict declarations.

### Phase 4 — Release

1. Run the new test suite plus affected provider/consumer tests.
2. Audit all data counts against the reference baseline.
3. Build a flat ZIP with root-only entries and no duplicates.
4. Verify manifest entry, version, README, attribution, and licenses.
5. Put the ZIP in `Releases`.
6. Do not install it.

## 12. Required first deliverable from the next agent

Before implementation, provide a concise audit report containing:

1. A complete ID/field inventory of reference changes.
2. A hook and ownership map for every runtime modification.
3. An edition-scope decision for Red, Blue, and Yellow.
4. Provenance and license findings for each data/code source.
5. The final manifest ID, dependencies, optional integrations, and conflicts.
6. The supported options/persistence design.
7. The plan for live encounter-table consumption by Kanto Living Encounters.
8. The exact test harness location and a passing baseline test run.
9. Any behavior that cannot be reproduced faithfully and its safe fallback.

Do not begin by copying the installed directory. Recreate from audited behavior,
use licensed sources, and keep the new mod independently testable.

## 13. Release checklist

- Read the master guide and both active design handoffs.
- Confirm no ownership overlap with UI, shiny, follower, visible-wild, battle-art,
  or world-rendering mods.
- Declare conflict with `yellow_legacy_changes`.
- Run exhaustive data/rules/quest/integration tests.
- Verify Lua 5.1 compatibility.
- Retain attribution and every required license.
- Update manifest, README, source header, and ZIP filename together.
- Package all files at ZIP root.
- Do not install automatically.
