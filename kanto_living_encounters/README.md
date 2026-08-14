# Kanto Living Encounters

Current source build: **0.1.0-alpha.4**

Kanto Living Encounters adds visible wild Pokémon without suppressing or
replacing Gen 1's classic random encounters.

## Behavior

- Route, cave, water, and selected dungeon entities are catchable on contact.
- Route and dungeon behavior weights are Idle 39.375%, Roam 50.625%,
  Aggressive 10%.
- Town behavior is Idle 41.5625%, Roam 53.4375%, Aggressive 5%.
- Town Pokémon face the player and play their cry when interacted with.
  Interaction itself never starts a battle; only aggressive town Pokémon can
  initiate one through their normal proximity/contact behavior.
- Aggressive Pokémon use the native exclamation bubble, lock player input,
  rush the player, and start one battle through an exactly-once lifecycle gate.
- Spawning an aggressive Pokémon starts a shared 30-second grace period.
  Unengaged aggressive Pokémon remain still and cannot detect the player during
  that period, preventing immediate chain rushes. Direct player contact remains
  battleable.
- Ordinary spawns expire after 90 seconds or at 22 tiles of distance.
- Shiny spawns persist until battle or map exit and ignore time/distance expiry.
- Entering any battle clears ordinary visible spawns; shiny entities remain
  unless they are the encountered entity. The map refills after battle.

## Live providers

- `hgss_simple_follower` supplies independent 32×32 HGSS overworld sprite
  presentation objects. It remains the sole owner of the party follower.
- `gen1_shiny_system` reserves one shiny outcome at visible-spawn creation and
  consumes that same outcome when the contact battle is constructed.
- Encounter species and levels are read from `Game.data.encounters` at map
  entry. Therefore Gen1 Balances is used automatically when installed and the
  active vanilla table is used otherwise.

Required provider contracts are available in HGSS Simple Follower alpha 18 and
Gen1 Shiny System alpha 3. Both are hard dependencies because substituting a
sprite or rerolling shiny state would make the visible encounter disagree with
the battle it starts.

## Options

- **Visible Pokémon:** On / Off (default On)
- **Aggressive Pokémon:** Yes / No (default Yes)
- **Amount:** Few (2–4), Regular (5–8), Many (9–12)
- **Town Pokémon:** On / Off (default On)
- **Debug Overlay:** On / Off (default Off)

## Compatibility and ownership

This mod owns visible wild entities, safe-cell selection, occupancy, pacing,
AI, and contact battle startup. It does not own party followers, shiny rules,
encounter tables, world geometry, camera behavior, or battle rules.

It conflicts with Wilds of Kanto (`overworld_wild_spawns`) because both mods
would own the same visible-wild runtime.

No ROM is included. HGSS-derived art remains in its owning provider package.
