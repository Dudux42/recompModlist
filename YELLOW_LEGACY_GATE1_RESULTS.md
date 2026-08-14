# Yellow Legacy Ruleset — Archived Gate 1 Results

> Archived on 2026-08-11. The validated loader/normalizer foundation was renamed
> and narrowed into `gen1_balances`; active scope is in `BALANCES_MOD_PLAN.md`.

Status: complete, 2026-08-10  
Target: Gen1Recomp 0.1.71, mod API 2, exact shipped Lua 5.1 runtime

## Outcome

Gate 1 passes. The project now has an independent, permission-free flat mod
scaffold at `gen1_yellow_legacy_ruleset` and can proceed to Gate 2 data work.
No Yellow Legacy gameplay records, runtime hooks, Crystal Tear content, or
scripted-Mew behavior are installed by this gate.

## Implemented foundation

- API 2 manifest with the canonical mod ID, engine range, balance category,
  link-affecting flag, and explicit conflict with `yellow_legacy_changes`.
- Sibling-module loader using only the supported `mod:read` surface.
- Canonical normalizers for species, moves, maps, trainers, items, and types.
- Explicit distinct handling for both Nidoran genders plus punctuation-sensitive
  IDs such as Farfetch'd, Mr. Mime, and the engine's `PSYCHIC_M` move ID.
- Transactional table, party, learnset, and complete-bundle validators. Invalid
  input returns no staged payload and never partially changes its source.
- Empty data modules for moves, species, learnsets, TM/HM sets, evolutions,
  encounters, fishing, trainers, and rematches.
- Diagnostic exports reporting `gate1_scaffold`, zero content operations, and
  zero hook operations.

## Verification evidence

Exact-runtime test result:

```text
133/133 checks passed  (gen1_yellow_legacy_ruleset_gate1)
```

The suite proves:

- clean discovery and load under engine 0.1.71;
- no errors on initial load or reload;
- no hooks in any public hook channel;
- no registry changes beyond the engine's own no-mod baseline;
- stable diagnostic exports;
- correct canonical-ID edge cases;
- whole-record rejection and source immutability for invalid staged data.

Strict Modkit result:

```text
ok gen1_yellow_legacy_ruleset valid
```

ROM-content lint result:

```text
ok gen1_yellow_legacy_ruleset: no ROM-derived content
```

The source checkout identifies itself as `0.0.0-dev`, while the installed
release and target DLL are 0.1.71. The external test adapter stamps only the
test process as 0.1.71. It lives outside the mod, so the shipped mod does not
import private engine modules and requires no `engine_internals` permission.

## Gate boundary

Gate 2 may now populate and verify moves, type-chart/category changes, partial
species patches, learnsets, TM/HM compatibility, and evolutions. Crystal Tear
and the scripted Mew battle remain deferred until the core integration freeze
at Gate 6 has passed.
