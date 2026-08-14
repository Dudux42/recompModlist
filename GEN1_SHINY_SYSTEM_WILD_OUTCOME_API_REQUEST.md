# Provider-agent request: Gen1 Shiny Wild Outcome API v1

Send this prompt to the agent that owns **Gen1 Shiny System**.

---

You own **Gen1 Shiny System**, manifest ID `gen1_shiny_system`, current
canonical version `0.1.0-alpha.2`. Please add the smallest public contract that
lets `kanto_living_encounters` reserve the visible entity's shiny outcome and
reuse that exact outcome when its contact battle is constructed.

## Blocked use case

Kanto Living Encounters must decide visible normal/shiny art when an overworld
entity is created. If the player contacts that entity later, the battle must
contain the same shiny state. Shiny entities also ignore the normal 90-second
and distance despawn rules until map exit.

## Verified evidence

Alpha 2 exports `rollShiny`, `makeShinyDVs`, and `applyShiny`, but its
`BattleState.newWild` wrapper always makes its own fresh roll while constructing
the battle. It ignores caller options for a pre-reserved outcome. Therefore a
consumer using `rollShiny` at spawn time would cause two independent rolls and
could display a normal entity that battles shiny, or the reverse. Mutating the
battle Pokémon after construction would duplicate Shiny System ownership and
can occur after dependent presentation hooks.

## Smallest requested provider-side change

Publish **Wild Outcome API v1**:

```lua
mod.exports.wildOutcomeApiVersion = 1

local outcome = mod.exports.reserveWildOutcome(optionalRng)
-- immutable/opaque provider-owned outcome with at least:
-- { shiny = boolean }

local opts = mod.exports.wildBattleOptions(outcome)
local battle = BattleState.newWild(game, species, level, opts)
```

`reserveWildOutcome` must apply the current master toggle and rate exactly once.
For a shiny result it should reserve valid Gen 2 shiny DVs (or equivalent
opaque provider state); for a non-shiny result it must reserve an explicit miss
so naturally generated shiny DVs cannot override it.

`wildBattleOptions(outcome)` must validate that the outcome came from this API
and return a fresh options table carrying it. The Shiny System's existing
`BattleState.newWild` wrapper must detect that option, consume it once, and
apply the reserved result instead of rolling again. Reuse, malformed outcomes,
foreign tables, or schema/version mismatches must fail safely and must not crash
vanilla battles. Document whether invalid reservations fall back to one normal
provider roll or are rejected; deterministic rejection is preferred for the
consumer path.

The resulting enemy Pokémon must expose both compatible forms when shiny:
valid native shiny DVs and `mon.shiny == true`. A reserved miss must clear both
forms exactly as the current ordinary wrapper does. All colors, battle art,
sparkles, SFX, and presentation remain owned by Gen1 Shiny System.

Load order: exports must be available at provider initialization. Option/rate
changes affect new reservations only; existing visible entities keep their
reserved snapshot. Save persistence is not required because visible entities
are map-lifetime runtime objects.

## Non-goals

- Do not create or render visible overworld entities.
- Do not add spawn timing, persistence, AI, collision, or encounter tables.
- Do not move shiny logic into Kanto Living Encounters.
- Do not change ordinary engine-created wild battle behavior except to honor a
  valid, explicit provider reservation.

## Acceptance tests

1. OFF, every configured denominator, and 100% produce exact deterministic
   reservations under injected RNG.
2. One reservation causes exactly one roll; constructing its battle causes no
   second roll.
3. Reserved shiny and reserved miss produce matching visible-state metadata and
   final battle Pokémon flag/DVs.
4. Reusing or forging an outcome cannot silently create inconsistent state.
5. Ordinary grass, cave, water, rod, and scripted wild battles remain governed
   by the existing wrapper when no reservation is supplied.
6. Existing `shiny_system_test.lua` passes plus new outcome/consumer integration
   tests, including explicit flag/native-DV compatibility.
7. Build and audit the flat package, retaining the Crystal palette MIT license.

## Version and returned artifacts

Bump Gen1 Shiny System to at least `0.1.0-alpha.3`; update manifest, README
current-build line, source header, tests, and ZIP name together. Kanto Living
Encounters will require `gen1_shiny_system@>=0.1.0-alpha.3 <0.2.0`.

Return changed files, finalized outcome schema/consumption semantics, tests
run/results, new version, and the flat release ZIP. Do not install it
automatically.

---
