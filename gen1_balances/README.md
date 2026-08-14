# Gen1 Balances

Current build: `0.1.0-alpha.2` — focused data implementation.

Gen1 Balances owns a deliberately narrow set of live gameplay data for
Gen1Recomp Red, Blue, and Yellow:

- Yellow Legacy v1.0.10-derived grass, cave, surf, and fishing tables.
- Yellow Legacy v1.0.10 base-stat changes: 57 fields across 27 species.
- Complete starting-move and level-up records for the 143 species whose
  learnsets differ from vanilla Yellow.
- Trade evolutions remain available, with an additional level path:
  Kadabra 42, Machoke 38, Graveler 38, and Haunter 42.

The mod changes the engine's live encounter registries. Classic random
encounters continue normally. Kanto Living Encounters may independently read
those same live tables to choose visible overworld Pokémon; this mod does not
create entities, control spawn density or AI, start contact battles, or
register a competing spawn provider.

Gen1 Shiny System remains the exclusive owner of shiny rolls, state, DVs,
colors, sparkles, and presentation. Gen1 Balances performs no shiny roll or
state write.

Out of scope:

- Move, type-chart, critical-hit, accuracy, or residual battle-rule changes.
- TM/HM compatibility changes.
- Trainer, rival, rematch, or difficulty changes.
- Crystal Tear, scripted Mew, or other quests.
- UI, art, followers, visible-wild entities, geometry, or generic rematches.

The mod conflicts with `yellow_legacy_changes` because both modify the same
species and encounter registries. Never enable both.
