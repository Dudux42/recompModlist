# Yellow Legacy Ruleset — Superseded Full-Recreation Change List

> Archived on 2026-08-11. Gen1 Balances does not implement the move, type-chart,
> battle-rule, or TM/HM sections below. Only the audited stat and learnset data
> remain in active scope; see `BALANCES_MOD_PLAN.md`.

Status: proposed implementation baseline, 2026-08-10  
Primary source: Pokemon Yellow Legacy v1.0.10 source/ROM  
Secondary source: installed `yellow_legacy_changes` 1.10.3 reference mod

## Important audit correction

The installed reference exposes 73 move patch records, but it is not a complete
representation of the original v1.0.10 move data. The original source also
changes fields omitted by the reference and contains three additional
player-facing move records. This ruleset will follow v1.0.10 where the two
sources disagree.

Known stale reference values:

| Move | Installed reference | v1.0.10 value |
|---|---:|---:|
| Bind accuracy | 95% | 85% |
| Double-Edge PP | 10 | 15 |
| Poison Gas PP | 35 | 40 |

## Move balance

Only changed fields are shown. Unlisted fields retain their live base values.

| Move | Final Yellow Legacy changes |
|---|---|
| Barrage | Power 20; accuracy 100% |
| Bind | Accuracy 85% |
| Comet Punch | Power 25; accuracy 100%; PP 25 |
| Constrict | Power 40 |
| Disable | Accuracy 75% |
| Dizzy Punch | PP 20; 10% confusion side effect |
| Double Slap | Power 20; accuracy 100%; PP 35 |
| Double-Edge | Power 120; PP 15 |
| Explosion | Power 250 |
| Focus Energy | PP 30; functional 2× ordinary critical rate |
| Fury Attack | Power 18; accuracy 100%; PP 35 |
| Fury Swipes | Power 20; accuracy 100%; PP 20 |
| Glare | Accuracy 90% |
| Mega Kick | Accuracy 85%; PP 10 |
| Pay Day | Power 60 |
| Rage | Power 60 |
| Razor Wind | Power 80; accuracy 100%; Hyper Beam-style recharge |
| Selfdestruct | Power 200 |
| Skull Bash | Power 100; accuracy 100%; Hyper Beam-style recharge |
| Soft-Boiled | PP 5 |
| Sonic Boom | Accuracy 100% |
| Supersonic | Accuracy 70% |
| Tackle | Accuracy 100% |
| Take Down | Power 95; accuracy 100% |
| Transform | PP 10; +1 priority |
| Tri Attack | Power 85; PP 15; 30% burn side effect |
| Fire Punch | Power 70; stronger burn side-effect tier |
| Fire Spin | Accuracy 85% |
| Blizzard | Accuracy 85%; retain the normal 10% freeze side effect |
| Ice Punch | Power 70; retain the normal 10% freeze side effect |
| Thunder | Accuracy 85%; PP 5 |
| ThunderPunch | Power 70 |
| Fly | Accuracy 100% |
| Gust | Flying type |
| Sky Attack | Power 120; accuracy 85%; PP 10; no charge turn |
| Wing Attack | Power 60 |
| Cut | Power 55; accuracy 100%; Bug type |
| Leech Life | Power 50; PP 25 |
| Pin Missile | Power 20; accuracy 100%; PP 30 |
| Twineedle | Power 40 per hit |
| Absorb | Power 30; PP 25 |
| Egg Bomb | Accuracy 100%; PP 15; Grass type |
| Leech Seed | Accuracy 90%; flat 1/8 maximum-HP drain |
| Mega Drain | Power 65; PP 20 |
| Petal Dance | Power 90 |
| Solar Beam | Power 180 |
| Vine Whip | Power 40; PP 25 |
| Lick | Power 40 |
| Night Shade | Ordinary 60-power damaging move; no fixed-level damage |
| Rock Slide | Accuracy 95%; PP 15; 10% flinch side effect |
| Rock Throw | Accuracy 95%; PP 25 |
| Bone Club | Accuracy 100% |
| Bonemerang | PP 20 |
| Dig | Power 70; PP 20 |
| Bubble | Power 10 |
| Clamp | Accuracy 85% |
| Crabhammer | Power 110; accuracy 100% |
| Hydro Pump | Accuracy 85%; PP 10 |
| Waterfall | Power 70; 10% flinch side effect |
| Psywave | Accuracy 95%; Yellow Legacy damage formula |
| Hi Jump Kick | Power 120 |
| Jump Kick | Power 90 |
| Karate Chop | Accuracy 95%; Fighting type |
| Low Kick | Accuracy 100% |
| Rolling Kick | Power 70; accuracy 100% |
| Submission | Accuracy 100% |
| Acid | Power 65 |
| Poison Gas | Accuracy 85%; PP 40 |
| PoisonPowder | Accuracy 90% |
| Poison Sting | Power 35 |
| Sludge | Power 90 |
| Smog | Power 40; accuracy 80% |
| Slam | Accuracy 100%; Dragon type; 10% flinch side effect |

### Additional v1.0.10 records omitted by the installed reference

| Move | Final change |
|---|---|
| Dragon Rage | PP 20 |
| Ice Beam | PP 15; retain the normal 10% freeze side effect |
| Psychic | PP 15 |

The ROM source also assigns 37 non-damaging moves the internal `BIRD` type.
That is a source-engine sentinel, not a real player-facing type. Gen1Recomp
already models zero-power moves as status moves, so this mod will not register
or expose a fake Bird type. Exact status-move behavior will be tested instead.

Likewise, v1.0.10 calls the ordinary freeze effect `FREEZE_SIDE_EFFECT`, while
Gen1Recomp calls the same 10% behavior `FREEZE_SIDE_EFFECT1`. The installed
reference writes the source name directly even though that name is not a valid
Gen1Recomp effect handler. This ruleset will use the engine's semantic alias and
will not accidentally remove Ice Punch, Ice Beam, or Blizzard's freeze chance.

## Type and battle rules

- Ghost attacks use Special.
- Ghost is super effective against Psychic.
- Bug is neutral against Poison.
- Dragon remains Special by default.
- The optional `DRAGON PHYS` setting switches Dragon to Physical immediately
  and persists the choice.
- Focus Energy gives exactly twice the ordinary critical-hit threshold.
- Leech Seed drains a flat 1/8 maximum HP and does not inherit Toxic's counter.
- A genuinely 100%-accurate move cannot fail solely on the roll of 255.
- A critical threshold capped at 255 is guaranteed rather than failing on 255.

The data-facing portions enter Gate 2. Focus Energy, Leech Seed, the two 1/256
corrections, Psywave's formula, and persisted Dragon switching require runtime
hooks and are completed in Gate 5.

## Base-stat changes

Only changed stats are patched.

| Pokemon | Changed base stats |
|---|---|
| Charmander | Special 55 |
| Charmeleon | Special 70 |
| Charizard | Special 95 |
| Arbok | HP 62; Attack 95; Speed 90 |
| Pikachu | HP 60; Defense 50; Special 70 |
| Clefable | Special 95 |
| Vulpix | HP 45; Defense 45; Special 70; Speed 75 |
| Wigglytuff | Defense 55; Special 85 |
| Golbat | Speed 100 |
| Oddish | HP 50 |
| Gloom | HP 70 |
| Vileplume | HP 90 |
| Venomoth | Attack 75; Special 95; Speed 100 |
| Diglett | Attack 70 |
| Dugtrio | Attack 90 |
| Ponyta | Speed 100 |
| Rapidash | Speed 115 |
| Farfetch'd | HP 62; Attack 75; Defense 65; Special 68; Speed 70 |
| Muk | Special 85 |
| Onix | HP 75; Attack 80; Special 65; Speed 85 |
| Marowak | Special 80 |
| Hitmonlee | HP 65; Defense 70; Special 60; Speed 93 |
| Hitmonchan | HP 60; Attack 50; Special 105 |
| Lickitung | HP 95; Attack 70; Defense 85; Special 75 |
| Magmar | Special 95 |
| Eevee | HP 70; Attack 65; Defense 65; Special 70 |
| Porygon | HP 75; Attack 70; Special 95 |

Total: 27 species and 57 individual stat fields.

## Evolutions

| Species | Final evolution rule |
|---|---|
| Kadabra | Alakazam at level 42 |
| Machoke | Machamp at level 38 |
| Graveler | Golem at level 38 |
| Haunter | Gengar at level 42 |
| Poliwag | Poliwhirl at level 18 |
| Poliwhirl | Poliwrath with Water Stone |

Five rows differ from vanilla Yellow. Poliwhirl's Water Stone evolution is
restated deliberately so the complete Poliwag line cannot inherit the older,
incorrect single-stage conversion found in historical material.

## Learnsets

The mod will install all 151 v1.0.10 learnsets as complete, validated records,
including level-1 starting moves. A direct source comparison shows that 143
actually differ from vanilla Yellow. The eight unchanged learnsets are:

`Abra`, `Alakazam`, `Caterpie`, `Ditto`, `Kadabra`, `Magikarp`, `Mewtwo`, and
`Weedle`.

Required corrections relative to the installed reference include:

- Gastly learns Poison Gas at level 23, not 20.
- Metapod has one Harden entry at level 7, not a duplicate.
- Nidoking gains level-1 Dig.
- Nidoqueen learns Dig at level 1 and Tail Whip at level 2.
- Nidorina gains Sludge at level 32 and Earthquake at level 40.
- Sandshrew learns Slash at level 22, not 23.
- Vaporeon has one Hydro Pump entry at level 52, not a duplicate.

## TM/HM compatibility

The mod will install the 146 v1.0.10 compatibility records as validated sets.
Seventy-six species differ from vanilla Yellow; unchanged records are still
carried so the ruleset has a deterministic complete compatibility surface.

Required corrections relative to the installed reference include:

- Cubone and Marowak gain Swords Dance.
- Exeggcute and Exeggutor use the final v1.0.10 lists, including Dream Eater.
- Meowth and Persian gain Cut.
- Exeggutor's duplicated Mega Drain token is normalized to one compatibility
  entry without removing the move.

## Out of scope for Gate 2

Wild encounters, fishing, trainers, rival routes, and rematches are later core
gates. Hard Mode is removed. Crystal Tear and scripted Mew remain deferred
until the non-quest core is complete.
