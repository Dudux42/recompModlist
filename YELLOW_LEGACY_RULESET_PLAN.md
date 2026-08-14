# Gen1 Yellow Legacy Ruleset — Superseded Audit Plan

> Superseded on 2026-08-11 by `BALANCES_MOD_PLAN.md`. The active project is
> `gen1_balances`, not a full Yellow Legacy recreation. This file is retained
> only as source-audit history; its move, TM/HM, trainer, rival, runtime-rule,
> rematch, Crystal Tear, and scripted-Mew implementation gates are inactive.

Status: Gate 1 complete; Gate 2 is next, 2026-08-10  
Target engine: Gen1Recomp 0.1.71, mod API 2  
Working mod ID: `gen1_yellow_legacy_ruleset`  
First planned release: `0.1.0-alpha.1`

## 1. Product decision

Build an independent Gen1Recomp ruleset that reproduces the gameplay balance
of Pokemon Yellow Legacy v1.0.10, then applies that balance consistently to
Red, Blue, and Yellow under the collection's existing ownership boundaries.

The supplied ROM is the exact official v1.0.10 build:

| Property | Value |
|---|---|
| Size | 2,097,152 bytes |
| MD5 | `1891782030C2583075CE593167EC46C3` |
| SHA-1 | `2AC87DE42AFC70EF6016805ACB3B206644417F97` |
| SHA-256 | `EF8908FE2650F671160C89CEBF4E361AA79A81DDCA63E23EB9CD3132ADB5C893` |
| Header title | `POKEMON YELLOW` |

### Source-of-truth order

1. The supplied v1.0.10 ROM and the matching upstream `V1.0.10` source tag
   define Yellow Legacy gameplay data and runtime behavior.
2. Official documentation and source comments define intent where binary data
   alone is ambiguous.
3. The installed `yellow_legacy_changes` mod shows how the current engine can
   be integrated, but is not authoritative when it conflicts with v1.0.10.
4. `MASTER_MOD_GUIDE.md` and the handoff documents define intentional
   collection-specific adaptations and ownership boundaries.

Conflicts between those tiers must be entered in the discrepancy ledger and
resolved explicitly. They must never be silently inherited.

## 2. Edition scope

| Feature | Red | Blue | Yellow |
|---|---:|---:|---:|
| Move, type-chart, stat, learnset and TM/HM balance | Yes | Yes | Yes |
| Evolution changes | Yes | Yes | Yes |
| Wild, surf and fishing tables | Yes | Yes | Yes |
| Non-rival trainer teams | Yes | Yes | Yes |
| Dormant rematch teams | Yes | Yes | Yes |
| Dragon Physical option | Yes | Yes | Yes |
| Crystal Tear quest | Deferred | Deferred | Deferred |
| Yellow starter-line rival adaptation | No | No | Yes |
| Yellow rival rematch | No | No | Yes |

Red and Blue retain their native counter-pick rival progressions. Yellow maps
the original Eevee routes as already established by the project:

- Jolteon route -> Bulbasaur line
- Flareon route -> Charmander line
- Vaporeon route -> Squirtle line

The rival route is resolved from live save state at battle time; it is not
cached at mod load. The audited workbook supplies the eight teams per route at
levels 5, 8, 19, 24, 35, 46, 55, and 65.

If a Red or Blue import lacks a map, trainer index, or script prerequisite
needed by a shared feature, that individual patch must fail open with a named
diagnostic. It must not fabricate an index or partially install a party.

## 3. Verified reference inventory

The installed 1.10.3 reference currently contains:

| Surface | Count |
|---|---:|
| Move records / patched fields | 73 / 114 |
| Species stat records / patched stat fields | 27 / 57 |
| Level-up learnsets | 151 |
| TM/HM compatibility records | 146 |
| Evolution records | 6 |
| Encounter maps | 57 |
| Trainer classes / parties | 44 / 394 |
| Rematch teams | 12 |
| Yellow rival variant classes | 2 |

These counts are useful completeness checks, not proof that every value is
correct.

## 4. Discrepancy ledger

### 4.1 Proven stale or incorrect reference data

Use the v1.0.10 values in the new mod:

| Area | Installed reference | v1.0.10 decision |
|---|---|---|
| Bind accuracy | 95 | 85 |
| Double-Edge PP | 10 | 15 |
| Poison Gas PP | 35 | 40 |
| Gastly Poison Gas | level 20 | level 23 |
| Metapod Harden | duplicate level-7 row | one level-7 row |
| Nidoking | missing level-1 Dig | add level-1 Dig |
| Nidoqueen | Tail Whip at level 1, no Dig | Dig at 1; Tail Whip at 2 |
| Nidorina | missing Sludge/Earthquake | add levels 32/40 |
| Sandshrew Slash | level 23 | level 22 |
| Vaporeon Hydro Pump | duplicated level-52 row | one level-52 row |
| Cubone/Marowak TM list | missing Swords Dance | add Swords Dance |
| Exeggcute/Exeggutor TM list | stale final-tag list | add v1.0.10 entries, including Dream Eater |
| Meowth/Persian TM list | missing Cut | add Cut |

Exeggutor's v1.0.10 source contains a duplicate Mega Drain compatibility token.
The resolver must normalize compatibility as a set while still testing that
the intended move is available.

### 4.2 Encounter conversion errors in the installed reference

- Route 19 and Route 20 surf slots were stored under `grass`; install them as
  water/surf encounters.
- Route 24 and Route 25 were given invented one-slot water tables. Remove
  those fabricated tables.
- Their omitted first Super Rod slots must remain in the rod pools:
  Route 24 level-35 Goldeen and Route 25 level-25 Krabby.
- Yellow Legacy v1.0.10 defines global Old Rod and Good Rod pools. The
  installed reference produces multiple per-map variants. Port the verified
  v1.0.10 behavior unless direct ROM extraction proves a map-specific override.

### 4.3 Trainer differences requiring an index-level audit

Party-count differences exist for Beauty, Bug Catcher, Burglar, Erika, Hiker,
Koga, and Sabrina. They are deliberate omissions of ROM-only Victory Road
trainers, progressive gym variants, or rematches whose consumers do not exist
in base Gen1Recomp maps/scripts. A previous audit also reported a four-party
Rocket discrepancy; that was a parser error caused by inline comments on the
four Jessie and James rows. All 49 Rocket parties match v1.0.10 exactly.

Before trainer data is implemented, produce a per-index ledger containing:

- upstream party and source label;
- installed-reference party;
- Red/Blue/Yellow script consumers in Gen1Recomp;
- decision: replace, append, edition-gate, or omit;
- reason and regression test.

All 12 installed rematch teams match v1.0.10. They remain dormant data until a
separate rematch owner consumes their marker.

### 4.4 Runtime corrections missing from the installed reference

The installed reference is not a complete behavioral port of Yellow Legacy's
standard rules:

- Yellow Legacy's standard rules remove the 1/256 failure from guaranteed-hit
  moves.
- Yellow Legacy's standard rules remove the final 1/256 critical failure at a
  capped threshold.

Decision for this project: implement both corrections as unconditional ruleset
behavior. There is no difficulty mode or alternate branch in this mod. Apply
the fixes through narrow battle hooks, not by copying a large engine function.

## 5. Ownership and hook map

| Behavior | Preferred surface | Ownership/fallback |
|---|---|---|
| Content tables | Live content registry on `game.ready` | Apply validated, idempotent field/record patches; fail open per invalid record |
| Trainer teams | `trainer.party` hook plus validated tables | Preserve script-visible indexes; Yellow rival logic composes last |
| Focus Energy | Guarded critical-threshold rule | Exact 2x ordinary rate, including high-crit cases |
| Guaranteed accuracy | `battle.accuracy` hook | A 100%-accurate move cannot fail solely on the 255 roll |
| Capped critical | Guarded critical-threshold rule | A threshold capped at 255 is guaranteed instead of failing on roll 255 |
| Leech Seed | Guarded residual-effect rule | Flat 1/8 max HP, min/KO/heal bounds; no Toxic multiplication |
| Dragon category | Live type record plus invalidation helper | Default Special; immediate switch; no stale consumer cache |
| Fishing | Live encounter/fishing registry | Do not replace the engine probability loop |
| Rematches | Data only | A rematch mod owns triggering; API must be audited before integration |

Every direct engine override must have: an owner token, an idempotence guard,
the previous function reference, protected execution, and a fail-open path.
Where a public hook exists, direct replacement is prohibited.

The ruleset does not own UI layout, icons, followers, shiny state, battle art,
visible-wild entities, world geometry, or generic rematch triggering.

## 6. Option and persistence

One user-facing setting is required:

| Key | Default | UI |
|---|---|---|
| `dragonPhysical` | Off | Mod option `DRAGON PHYS` |

`options_state.lua` centralizes the default, persistence, live category update,
and reload behavior. No difficulty setting, Oak prompt, level cap, forced Set
rule, or battle-item restriction belongs to this mod.

## 7. Manifest and compatibility baseline

Planned manifest values:

| Field | Value |
|---|---|
| `id` | `gen1_yellow_legacy_ruleset` |
| `api` | `2` |
| `entry` | `main.lua` |
| `profile` | `content` |
| `category` | `BALANCE` |
| `priority` | `110` |
| `game_version` | `>=0.1.71 <0.2.0` |
| required dependencies | none |
| conflict | `yellow_legacy_changes` |

Priority 110 keeps the ruleset in the early content layer, ahead of the old
reference's nominal priority but below the collection's presentation mods.
Compatibility must come from hooks and ownership, not from racing load order.

Optional integrations are behavioral and should only be declared after their
actual manifest IDs/APIs are verified:

- Gen1 Shiny System: remains sole shiny owner for active balance content.
- Kanto Living Encounters: consumes the already-patched live encounter tables.
- Trainer rematch provider: may consume dormant `rematchIndex` teams.
- Widescreen UI, menu icons, follower and battle-art mods require no data
  dependency; integration tests ensure this ruleset does not seize ownership.

Kanto Living Encounters must resolve native tables at map entry. This ruleset
does not register a competing visible-spawn provider. If a future provider API
offers invalidation, the ruleset may notify it after a live table change.

## 8. Provenance and licensing

| Source | Use | Finding/action |
|---|---|---|
| Supplied Yellow Legacy v1.0.10 ROM | Verification/behavior oracle | User-supplied; never redistribute or include in releases |
| Official Yellow Legacy `V1.0.10` source | Data and behavioral verification | Public repository has no root LICENSE; do not copy implementation text verbatim |
| Installed `yellow_legacy_changes` 1.10.3 | Engine mapping/reference | Read-only, no visible license; independently reimplement behavior |
| Rival workbook | Audit of collection-specific rival teams | Treat as project source artifact; do not ship unless provenance is cleared |
| Gen1Recomp 0.1.71 source/test kit | Supported API and harness | Use only under its repository terms; preserve required notices if code is reused |

The mod should contain independently written Lua and factual data tables with a
clear attribution section. No ROM, upstream source tree, audit clone, workbook,
or extracted engine asset belongs in the release ZIP.

## 9. Planned flat module layout

```text
manifest.json
main.lua
compat.lua
options_state.lua
data_moves.lua
data_species.lua
data_learnsets.lua
data_tmhm.lua
data_evolutions.lua
data_encounters.lua
data_fishing.lua
data_trainers.lua
data_rematches.lua
rules_focus_energy.lua
rules_accuracy.lua
rules_critical.lua
rules_leech_seed.lua
rival_routes.lua
README.md
ATTRIBUTION.md
tests.lua
```

`crystal_tear.lua` is intentionally excluded from the active scaffold. It will
be added only after all balance, encounter, trainer, rival, option, runtime,
integration, and reload gates are green.

Release archives remain root-only. Audit tools, cloned repositories, ROMs,
rendered workbook images, and generated comparison reports stay outside the
archive.

## 10. Step-by-step implementation plan

### Gate 0 — Freeze the evidence baseline

1. Preserve the ROM hashes above and the upstream tag/commit in the audit log.
2. Generate canonical machine-readable tables from v1.0.10 without copying
   upstream implementation code.
3. Finish the trainer index ledger and verify Red/Blue/Yellow script consumers.
4. Verify the two standard-rules 1/256 corrections and scripted-Mew shiny policy.
5. Record every intentional deviation from v1.0.10.

Exit condition: every field has a named source and unresolved differences are
zero or explicitly deferred outside the first release.

### Gate 1 — Scaffold and validators

1. Create the manifest and flat modules above.
2. Add normalization for move/species/map/trainer IDs, including distinct
   Nidoran male/female handling.
3. Add transactional validators: an invalid record or party is rejected whole.
4. Add idempotent installation and owner diagnostics.

Exit condition: the empty ruleset loads twice under exact Lua 5.1 without
duplicating hooks or changing vanilla registries.

Result: **pass**. The independent scaffold, canonical-ID normalization,
transactional validators, zero-operation diagnostics, load/reload checks, and
strict Modkit validation are recorded in `YELLOW_LEGACY_GATE1_RESULTS.md`.

### Gate 2 — Pure species and battle data

1. Implement and exhaustively test 76 semantic move records: the installed
   reference's 73 records plus Dragon Rage, Ice Beam, and Psychic fields omitted
   by that reference but present in v1.0.10. Normalize source-only `BIRD` status
   typing and the freeze-effect name to their Gen1Recomp semantic equivalents.
2. Add type-chart changes and the Dragon category switch.
3. Add 27 partial stat patches while proving untouched fields survive.
4. Replace 151 learnsets and 146 TM/HM sets with corrected v1.0.10 values.
5. Add the six evolution changes.

Exit condition: exact ID/field snapshots pass for all three editions.

### Gate 3 — Encounters and fishing

1. Port all 57 maps from the verified surface/rod sources.
2. Preserve native encounter rates and use a documented fallback only when a
   genuinely missing surface must be added.
3. Correct Route 19/20 surf and Route 24/25 Super Rod conversion errors.
4. Verify ordinary engine encounter rolls remain active.
5. Test that Kanto Living Encounters reads the patched live tables without
   acquiring their ownership.

Exit condition: map/slot/rate snapshots pass and no fabricated surface exists.

### Gate 4 — Trainers, rematches and edition logic

1. Apply only trainer parties approved by the index ledger.
2. Preserve every script-visible index and reject malformed parties whole.
3. Append all 12 dormant rematches, including Brock without replacing his
   normal team.
4. Implement the three Yellow starter routes from the audited workbook.
5. Prove Red/Blue rival parties and rematches are unchanged.

Exit condition: every trainer index resolves correctly in Red, Blue, and
Yellow fixture data.

### Gate 5 — Runtime rules and Dragon option

1. Implement Focus Energy and Leech Seed through narrow guarded rules.
2. Implement the guaranteed-accuracy and capped-critical corrections.
3. Implement the option-state service for Dragon Physical.
4. Add idempotence, persistence, probability-boundary, and reload tests.

Exit condition: probability, persistence, reload, and error-path tests pass
under exact Lua 5.1.

### Gate 6 — Core integration freeze

1. Run the complete balance suite plus relevant provider/consumer suites.
2. Test with each canonical collection mod enabled and disabled.
3. Confirm the declared conflict prevents co-loading `yellow_legacy_changes`.
4. Freeze the core data snapshots and runtime probability tests.
5. Confirm no Crystal Tear item, quest state, script hook, or Mew override is
   present in the core build.

Exit condition: every non-quest feature is complete and stable under exact Lua
5.1 across Red, Blue, and Yellow.

### Deferred Gate 7 — Crystal Tear quest

1. Register the non-tossable key item and namespaced state.
2. Implement Oak's Hall-of-Fame plus 150-owned-non-Mew gift condition.
3. Handle bag-full retry and all invalid-use messages.
4. Launch the level-75 Mew with the exact four moves only after Mewtwo.
5. Remove the Tear and finalize the quest after catch, KO, flee, or loss.
6. Verify scripted-Mew shiny behavior delegates to the shared shiny owner.

Exit condition: every quest branch and save/reload boundary passes.

This gate does not begin until Gate 6 is complete. The existing evidence is
retained so the quest can be resumed without re-discovering its prerequisites.

### Gate 8 — Final integration and release

1. Re-run the core suite and the deferred quest suite together.
2. Re-test each canonical collection mod enabled and disabled.
3. Reconfirm the `yellow_legacy_changes` conflict.
4. Build a root-only ZIP and audit entry names, duplicates, manifest, README,
   attribution, versions, and absence of ROM/audit files.
5. Put the ZIP in `Releases`; do not install it automatically.

## 11. Test harness and resolved baseline issue

Exact harness location:

`C:\Users\invok\OneDrive\Documents\ChatGPT\Gen1 Recomp Mods\.audit\gen1recomp_v0.1.71\tests\modkit`

Exact runtime DLL:

`F:\Games\gen1recomp-win64\lua51.dll`

The installed reference loads successfully against engine 0.1.71 and reports
222 maps, 151 species, and 165 moves, but its bundled test remains unsuitable
as this project's certification baseline. It fails in the synthetic
name-resolution fixture at line 509 when
`resolved.learnsets["FIXMON_LEGACY"]` is nil. Therefore this project now uses
its own independent Gate 1 suite:

- do not certify the installed reference test as green;
- preserve the stale fixture only as evidence about the reference;
- certify this ruleset with the 0.1.71 Modkit and exact shipped Lua 5.1 DLL;
- require the independent Gate 1 suite to stay green during later gates.

Gate 1 resolves the project blocker: **133/133 exact-runtime checks pass**, and
strict fixture-base validation reports the mod valid. This does not make the
reference's stale bundled test trustworthy; it removes our dependency on it.

## 12. Locked decisions and remaining integration check

1. The two v1.0.10 standard-rules 1/256 fixes are included in the first release:
   100%-accurate moves do not fail on roll 255, and capped critical thresholds
   are guaranteed.
2. Trainer-class count/index differences are resolved in
   `YELLOW_LEGACY_GATE0_EVIDENCE.md`: inaccessible ROM-only parties are omitted,
   and the 12 final rematches remain separately marked dormant data.
3. Crystal Tear and scripted Mew are deferred until every other aspect of the
   mod passes Gate 6. No quest item, hook, state, or Mew change enters the active
   scaffold before then.
4. When deferred work resumes, scripted Mew goes through
   `BattleState.newWild`, so Gen1 Shiny System owns exactly one ordinary wild
   roll. This ruleset performs no shiny roll or write.
5. Final optional dependency IDs remain to be checked immediately before the
   integration phase; behavioral compatibility must not become a hard dependency.

No implementation should begin by copying the installed mod directory. Gate 0
is recorded in `YELLOW_LEGACY_GATE0_EVIDENCE.md`, Gate 1 is recorded in
`YELLOW_LEGACY_GATE1_RESULTS.md`, and the next action is Gate 2: pure species
and battle data.
