# Gen1 Balances — Active Scope and Implementation Plan

Status: focused scope adopted, 2026-08-11  
Working name: **Gen1 Balances**  
Manifest ID: `gen1_balances`  
Target: Gen1Recomp 0.1.71, mod API 2

## Product boundary

Gen1 Balances is not a full Yellow Legacy recreation. It owns only five live
data surfaces:

1. Grass and cave encounter tables.
2. Surf encounter tables.
3. Old, Good, and Super Rod pools.
4. Yellow Legacy v1.0.10-derived base-stat and level-up learnset changes.
5. Additional level paths for the four Gen I trade evolutions, while preserving
   every original trade path.

It does not own moves, type-chart rules, battle mechanics, TM/HM compatibility,
trainers, rivals, rematches, difficulty, quests, UI, art, followers, shiny
state, visible-wild entities, spawn behavior, or world geometry.

## Edition policy

The same balance data applies to Red, Blue, and Yellow. Existing encounter
rates are preserved per live edition and surface. A Yellow Legacy source rate
is used only when an edition genuinely lacks a required surface.

The current edition audit found five such Red/Blue surfaces:

| Surface | Fallback rate |
|---|---:|
| Route 6 Surf | 3 |
| Route 12 Surf | 3 |
| Route 13 Surf | 3 |
| Seafoam Islands B3F Surf | 5 |
| Seafoam Islands B4F Surf | 5 |

Yellow has every required surface. Missing maps fail open individually; the mod
does not fabricate unknown maps.

## Encounter ownership

Balances patches Gen1Recomp's authoritative live encounter and fishing
registries. It does not suppress or replace the engine's random-encounter
probability loop.

Kanto Living Encounters owns visible entity creation, placement, AI, contact
battles, and spawn pacing. Its native adapter reads the effective live table at
map entry, so it automatically consumes Balances data without a dependency or
second provider table. Visible and classic encounters make independent rolls
from the same authoritative content.

Balances must not call `registerSpawnProvider`; that contract is for a future
controller that replaces normalized visible-spawn data, not for the owner of
the native live tables.

## Shiny ownership

Gen1 Shiny System is the sole owner of shiny rolls, DV construction, persistent
state, colors, sparkles, and presentation. Balances creates no Pokémon instance,
performs no RNG roll, and writes no shiny field or DV. Kanto Living Encounters
must consult the Shiny System when it creates a visible instance.

## Data inventory

| Dataset | Scope |
|---|---:|
| Encounter maps | 57 |
| Grass/cave surfaces | 55 |
| Surf surfaces | 8 |
| Super Rod maps | 31 |
| Base-stat patches | 27 species / 57 fields |
| Changed learnset records | 143 species |
| Additive evolution records | 4 species |

The complete encounter ledger is in `BALANCES_ENCOUNTER_TABLE.md`.

## Evolution rules

| Species | Original path retained | Additional path |
|---|---|---|
| Kadabra | Trade → Alakazam | Level 42 → Alakazam |
| Machoke | Trade → Machamp | Level 38 → Machamp |
| Graveler | Trade → Golem | Level 38 → Golem |
| Haunter | Trade → Gengar | Level 42 → Gengar |

Poliwag and Poliwhirl retain their edition-native evolution rules; the former
Yellow Legacy plan to change Poliwag is no longer part of this mod.

## Compatibility

- Conflict with `yellow_legacy_changes`: both own overlapping Pokémon and
  encounter records.
- No required or optional dependency on Kanto Living Encounters: it reads live
  tables when present.
- No Shiny System dependency: Balances has no shiny behavior.
- `affects_link = true`: base stats, learnsets, and evolutions affect link-safe
  gameplay fingerprints.

## Verification gates

1. Validate every source-derived record transactionally under exact Lua 5.1.
2. Apply stats, starting moves, learnsets, and dual evolution rows through the
   public Pokémon content registry.
3. Apply surface slots while preserving live rates and using only the five
   audited fallbacks.
4. Apply global Old/Good Rod pools and all 31 Super Rod maps without replacing
   the fishing rejection-loop mechanics.
5. Test Red, Blue, and Yellow merged snapshots.
6. Test that Kanto Living Encounters' native adapter reads the patched live
   table without transferring ownership or suppressing classic encounters.
7. Build and audit a flat root-only ZIP; place it in `Releases` and never
   install it automatically.

Current status: gates 1–5 and 7 pass. The exact Lua 5.1 suite passes 187/187 checks,
strict validation passes against the fixture and the real imported Red, Blue,
and Yellow datasets, and the ROM-content lint is clean. The flat root-only
`0.1.0-alpha.2` test build is in `Releases` and was not installed. Gate 6
remains pending until Kanto Living Encounters implements its native live-table
adapter.

## Superseded scope

`YELLOW_LEGACY_RULESET_PLAN.md`, `YELLOW_LEGACY_GATE1_RESULTS.md`, and
`YELLOW_LEGACY_GATE2_CHANGE_LIST.md` are preserved audit history. Their broader
full-recreation gates are superseded by this document.
