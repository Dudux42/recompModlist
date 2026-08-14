# Gen1 Shiny System

Current build: **0.1.0-alpha.3**

A focused shiny implementation for the Invoker/Codex mod compilation. It owns
shiny encounter rolls, persistent shiny state, battle recoloring and sparkle
effects. Presentation is delegated directly to our existing mods:

- Gen1 Widescreen UI selects shiny portraits and menu-icon descriptors.
- HGSS Menu Icons selects the audited two-frame shiny icon sheets.
- HGSS Simple Follower selects the ROM-derived shiny overworld sheets and
  draws lightweight looping sparkles.
- Dramatic Shape 1.8.x delegates shiny generation and 3D shiny presentation
  to this mod. Its in-game **SHINY RATE** row controls this mod's rate, so
  only one generator is active and the selected odds remain exact.

The original `SHINY_POKEMON` mod must be disabled because both mods wrap wild
Pokemon creation and battle presentation.

## Options

Pause **OPTIONS -> SHINY POKEMON -> OPEN**:

- **SHINY POKEMON** — master enable.
- **SHINY RATE** — OFF, 1/8192, 1/4096, 1/1024, 1/512, 1/100, 1/10 or 100%.
- **SHINY COLORS** — enables shiny battle art, menu icons and followers.
- **SHINY INTRO** — enables battle/follower sparkle effects and battle SFX.
- **DEBUG OW** — diagnostic logging; normally leave this disabled.

Existing natural Gen 2 shiny DVs and an explicit `mon.shiny` flag are both
recognized. Newly rolled shinies receive valid Gen 2 shiny DVs and retain the
explicit flag when caught.

## Wild Outcome API v1

Visible-wild providers can reserve one immutable shiny verdict when an entity
appears and consume that same snapshot when contact creates its battle:

```lua
local shiny = mod.find("gen1_shiny_system").exports
assert(shiny.wildOutcomeApiVersion == 1)

local outcome = shiny.reserveWildOutcome(optionalRng)
local opts = shiny.wildBattleOptions(outcome)
local battle = BattleState.newWild(game, species, level, opts)
```

`outcome.shiny` is the read-only visible-state boolean. A shiny reservation
also owns a valid Gen 2 DV snapshot; a miss explicitly clears both natural
shiny DVs and `mon.shiny`. Rate and master-option changes affect only later
reservations.

`wildBattleOptions` returns a fresh opaque options table while the outcome is
unused. The first `BattleState.newWild` call that receives any such table
consumes the outcome. Other tables prepared from the same outcome then become
invalid. Foreign, altered, or consumed outcomes return no options; stale or
reused provider options deterministically return no battle and never fall back
to another shiny roll. Vanilla calls without provider options retain the
ordinary Shiny System roll.

## Dramatic Shape compatibility

When Dramatic Shape 1.8.x is active, Gen1 Shiny System disables its independent
Pokemon-creation verdict through Dramatic Shape's exported companion namespace.
Dramatic Shape continues to own its 3D models, tinting, and model-sized sparkle,
but reads this mod's master, color, intro, and rate choices.

Dramatic Shape's custom in-game **SHINY RATE** row is replaced with a live view
of this mod's rate. The launcher's generic Dramatic Shape Mod Manager page may
still display its legacy `shinyOdds` field because Dramatic Shape 1.8.x exposes
no API for another mod to remove a previously registered schema field. That
legacy field is runtime-inert while this compatibility adapter is active; use
the Gen1 Shiny System options or Dramatic Shape's in-game row instead.

## Attribution

The official Crystal palette table is reused from masterwebx's MIT-licensed
Shiny Pokemon mod. See `THIRD_PARTY_LICENSE.txt`. All other integration code in
this package was written specifically for this compilation.
