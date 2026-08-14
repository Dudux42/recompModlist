# Widescreen Move Inspector

Current build: **0.1.0-alpha.2**

This informational mod extends Gen1 Widescreen UI's existing Battle HUD. It
does not draw, install battle hooks, alter moves, consume RNG, or change battle
mechanics, AI, saves, targeting, PP, or ROM data.

## Requirements

- Gen1Recomp `>=0.1.51 <2.0.0`.
- Gen1 Widescreen UI `>=0.1.0-alpha.9 <0.2.0`.
- Do not enable the original `move_inspector`; the manifests conflict.

While this provider is active, Widescreen's Battle HUD is mandatory. A saved
off setting is ignored with one explicit warning. Widescreen remains the only
Battle HUD presenter.

Alpha.2 makes the provider handshake resilient to real launcher lifecycle
ordering: it registers during initialization, verifies registration after all
mods load, and repairs a missing registration when a battle starts. These are
event subscriptions only; the mod still installs no battle or render hook.

## Display

During normal FIGHT move selection, the existing 2x2 panel shows the selected
move's live merged type, current/maximum PP, base-power classification,
accuracy, type-chart multiplier, ordinary STAB, and disabled state. Cursor,
PP, party switch, Transform/Conversion-like current types, and merged move or
type-chart changes are read afresh on every presentation.

Power is classified as:

- a numeric effective base power for ordinary damaging moves;
- `—` for status moves;
- `FIXED` for `SPECIAL_DAMAGE_EFFECT` or explicit `fixedDamage` moves;
- `VARIES` for Counter, Bide, OHKO, Super Fang, Metronome, and Mirror Move.

Swift is labeled `ALWAYS`; other positive accuracy values are percentages.
There is no public side-effect-free damage-preview API in the audited engine,
so this mod deliberately does not predict final damage, criticals, accuracy
stages, random rolls, move-specific gates, or secondary effects.

For ordinary damage, labels are `SUPER EFFECTIVE`, `NEUTRAL`, `RESISTED`, or
`IMMUNE`, plus the numeric multiplier. For status, fixed, and special-formula
moves, the panel says `TYPE CHART` plus the multiplier. This distinction is
important in Gen 1: fixed-damage moves and Super Fang skip type effectiveness,
while OHKO moves still use type immunity.

Mimic selection intentionally retains Widescreen's basic type/PP detail. The
copied move does not yet have verified live user/target semantics there.

## Public API

```lua
exports.apiVersion = 1
exports.effectiveness(data, attackType, defenderTypes)
exports.snapshot(battle)
exports.formatMultiplier(factor)
```

Snapshots are new semantic tables and contain no mutable battler, move,
type-chart, save, or ROM tables.

## Compatibility

The mod reads the effective merged `battle.data.moves` and
`battle.data.type_chart`, so Yellow Legacy-style balance changes require no
special dependency. It uses each battler's current battle types. Dramatic
Shape, Stadium models, Battle Art, world geometry, animations, camera, and
battle simulation remain untouched.

Gen 3 Inspired UI also owns battle presentation. Disable its BATTLE UI while
using Gen1 Widescreen UI; this provider does not resolve conflicts between two
full Battle HUD presenters.

## License

MIT. The included `LICENSE` retains the notice from Move Inspector 1.0.0,
whose read-only calculation behavior informed this independent widescreen
provider.
