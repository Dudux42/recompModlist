# Gen1 Yellow Legacy Ruleset — Gate 0 Evidence Baseline

Status: complete, 2026-08-10  
Parent plan: `YELLOW_LEGACY_RULESET_PLAN.md`

## 1. Frozen identities

| Artifact | Frozen identity |
|---|---|
| Supplied Yellow Legacy ROM | SHA-256 `EF8908FE2650F671160C89CEBF4E361AA79A81DDCA63E23EB9CD3132ADB5C893` |
| Yellow Legacy v1.0.10 source | commit `3a5358e8c9d3d0889f38cdb39a208120fea37a31` |
| Gen1Recomp 0.1.71 source/test kit | commit `18b2bcd0a7e2ebada1e9d05fb7073218cbba8e00` |
| Vanilla Yellow disassembly used for index comparison | commit `0a0851546ff65f65c4bb2af2b95e279e709a8653` |
| Installed reference manifest | SHA-256 `4A4327D672C49B992ECA3DE1F0FD78DEE6ADDE859F24B4BF90098ABDB6D0EAA9` |
| Installed reference `main.lua` | SHA-256 `B1C9FDF0049B227C23540E9114405BBC1D85D9462A23C85A4F290F368069AE6C` |
| Installed reference `trainers.lua` | SHA-256 `3F63F8DB7FAB125A0A8635B569EF205F3C8CA65BBE7935B48787069A564BB530` |
| Installed reference `rematches.lua` | SHA-256 `F4F7358ED71C22068EF2E351B252E9323F41539F16E3C22870BC99FA91937C4D` |
| Rival workbook | SHA-256 `C17D10282EDBAF24292584AD57265A66608B53132F3BB44D1F0A4F05A1433D5B` |

The engine extractor was tested against the supplied hack and correctly
refused it: the hack SHA-1 is
`2ac87de42afc70ef6016805acb3b206644417f97`, while the bundled Yellow manifest
requires retail Yellow SHA-1 `cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1`.
The validation was not bypassed. Trainer consumers were instead mapped from
the retail disassembly and the engine's existing Red/Blue imported caches.

Audit tool: `audit_yellow_legacy_trainers.py`.

## 2. Trainer audit result

The decisive result is narrower than the initial count-only audit suggested:

- Every non-rival party included by the installed reference matches the
  corresponding Yellow Legacy v1.0.10 class and index.
- All 49 `OPP_ROCKET` parties match. The earlier 49-versus-45 report was a
  parser defect: inline comments caused the four Jessie and James mixed-level
  parties to be skipped.
- The installed reference's rival differences are intentional starter-line
  substitutions, not transcription mistakes.
- The 12 separated rematch teams match the v1.0.10 `; Rematch` rows.
- The remaining source-only parties have no equivalent consumer in the base
  Gen1Recomp Red, Blue, or Yellow maps/scripts.

## 3. Index ledger and decisions

### 3.1 Shared base parties

Decision: **replace at the existing class/index in Red, Blue, and Yellow**.

This covers the installed reference's 44 audited classes and 394 parties,
except for rival classes, which follow the edition rule below. Existing map
objects keep their original class/index references; only party contents change.

`OPP_BROCK#1` is deliberately not replaced because Yellow Legacy does not
rebalance Brock's first battle. His live native party remains in every edition.

### 3.2 ROM-only Victory Road additions

| Class/index | Source label | Gen1Recomp consumer | Decision |
|---|---|---|---|
| `OPP_BEAUTY#16` | ReaderDragon | None | Omit |
| `OPP_BUG_CATCHER#16` | Talos | None | Omit |
| `OPP_BURGLAR#10` | Disq | None | Omit |
| `OPP_HIKER#15` | Sable | None | Omit |

These are new NPC battles in modified Victory Road maps. Adding parties without
their NPC, dialogue, and map changes would create unreachable registry data and
would expand this balance ruleset into a map-content recreation.

### 3.3 New Yellow Legacy trainer classes

| Class | Source role | Base engine class/consumer | Decision |
|---|---|---|---|
| `OPP_CRAIG` | Zapdos-area custom fight | None | Omit |
| `OPP_SMITH` | Cerulean Cave custom fight | None | Omit |
| `OPP_WEEBRA` | Seafoam custom fight | None | Omit |
| `OPP_JANINE` | Fuchsia Gym custom fight | None | Omit |
| `OPP_JOY` | Fuchsia Pokecenter custom fight | None | Omit |
| `OPP_JENNY` | Vermilion custom fight | None | Omit |

Their maps, graphics, scripts, text, and trainer constants are not part of the
established balance-mod ownership boundary. They can only be reconsidered as a
separate map/story expansion with explicit user approval.

### 3.4 Progressive gym variants

| Class/index | Role in ROM | Base engine consumer | Decision |
|---|---|---|---|
| `OPP_ERIKA#2` | intermediate scaled team | None | Omit |
| `OPP_ERIKA#3` | intermediate scaled team | None | Omit |
| `OPP_KOGA#2` | intermediate scaled team | None | Omit |
| `OPP_SABRINA#2` | alternate/intermediate team | None | Omit |

Only each leader's normal live party is replaced. The final rematch team is
stored separately as dormant data. Porting unused intermediate teams would not
recreate their triggering logic and could cause a rematch consumer to choose
the wrong index.

### 3.5 Rematches

Decision: **append as dormant marked data; do not trigger**.

| Class | v1.0.10 source index | Ruleset live append index |
|---|---:|---:|
| Brock | 2 | native party count + 1 |
| Misty | 2 | patched party count + 1 |
| Lt. Surge | 2 | patched party count + 1 |
| Erika | 4 | patched party count + 1 |
| Koga | 3 | patched party count + 1 |
| Blaine | 2 | patched party count + 1 |
| Sabrina | 3 | patched party count + 1 |
| Lorelei | 2 | patched party count + 1 |
| Bruno | 2 | patched party count + 1 |
| Agatha | 2 | patched party count + 1 |
| Lance | 2 | patched party count + 1 |
| Rival3 | 4 | Yellow only, patched party count + 1 |

The source index is provenance, not the index exposed to another mod. Each
appended party receives a `rematchIndex` marker after validation. Generic
rematch triggering remains owned by a separate provider whose API must be
audited before consumption.

### 3.6 Rival classes

Decision: **edition-gate at runtime**.

- Red and Blue retain all native counter-pick `OPP_RIVAL1`, `OPP_RIVAL2`, and
  `OPP_RIVAL3` parties and indexes.
- Yellow replaces the Eevee route with the audited workbook's Bulbasaur,
  Charmander, or Squirtle route.
- Jolteon maps to Bulbasaur, Flareon to Charmander, and Vaporeon to Squirtle.
- The current `save.rivalStarter` is read at battle time.
- The Rival3 rematch is appended only on Yellow.

The engine has Red/Blue-only script consumers for Rival1 indexes 4 and 7 and
larger native party sets (Rival1 has 9 and Rival2 has 12). Replacing those
classes wholesale with Yellow's 3/10 records would break Red/Blue scripts.

## 4. Runtime parity decisions

### 4.1 The two 1/256 corrections

Yellow Legacy v1.0.10 removes the guaranteed-move miss and capped-critical
failure in its standard rules. Gen1Recomp currently models accuracy policy
through its selected engine ruleset:

- `gen1_faithful`: retains the 1/256 accuracy miss;
- `modern_clean`: removes the accuracy miss;
- current critical logic retains the final failure at a capped threshold.

Decision for the first release: **implement both corrections**. This mod has no
difficulty mode, so there is no alternate behavior branch. Its narrow accuracy
and critical hooks make 100%-accurate moves immune to the roll-255 failure and
make a capped critical threshold guaranteed. Other faithful/modern engine
differences remain untouched.

### 4.2 Deferred Crystal Tear edition scope

Decision: **retain the audit, but defer all implementation until the core mod
is complete**. When work resumes, target Red, Blue, and Yellow with prerequisite
validation.

Verified shared prerequisites include:

- `CERULEAN_CAVE_B1F` and its Mewtwo object;
- `EVENT_BEAT_MEWTWO`;
- `save.hallOfFame`;
- `save.pokedex.owned`;
- Oak's Lab talk scripts;
- `BattleState.newWild` and `static_battle`.

No quest item, hook, flag, script, or Mew change belongs in the active core
scaffold. Later quest state will use ruleset-namespaced mod state rather than generic event
names such as `EVENT_GOT_CRYSTAL_TEAR` or `EVENT_BEAT_MEW`. If a future edition
import lacks a prerequisite, only the quest module fails open and reports the
missing prerequisite.

### 4.3 Deferred scripted Mew and shinies

Decision: **one ordinary shared wild roll**.

The engine's `static_battle` command creates the level-75 Mew through
`BattleState.newWild`. Gen1 Shiny System wraps that constructor and is already
the sole shiny-roll owner for every newly constructed wild Pokemon. Therefore
the ruleset must not call `rollShiny`, write DVs, set `mon.shiny`, recolor the
battle, or emit sparkles. With the Shiny System absent, Mew is ordinary unless
the engine/imported state independently makes it shiny.

## 5. Gate 0 exit checks

- ROM/source/engine/reference identities frozen: **pass**.
- Trainer classes and party indexes mapped: **pass**.
- Red/Blue/Yellow consumer scope decided: **pass**.
- Rematch storage and ownership decided: **pass**.
- 1/256 corrections documented and included: **pass**.
- Crystal Tear evidence preserved and implementation deferred: **pass**.
- Scripted-Mew shiny ownership decided: **pass**.
- Known discrepancy ledger corrected: **pass**.

Gate 1 may begin with the empty flat scaffold, normalization helpers,
transactional validators, and exact Lua 5.1 load/reload test.
