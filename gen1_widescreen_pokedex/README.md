# Widescreen Pokédex

Current source build: **0.1.0-alpha.7**

Requires **Gen1 Widescreen UI 0.1.0-alpha.14.7 or newer** with Pokedex
Provider API v2. This mod owns read-only semantic models and navigation;
Widescreen remains the sole 640×360 presenter.

Install or update Widescreen UI first, then import this mod. Widescreen owns the
bounded long-entry viewport, focus, scroll affordances, pointer regions and
controller input; the semantic provider supplies the full normalized entry.
Legacy Game Boy line/page controls are converted to spaces so ordinary entries
reflow across the full detail box instead of triggering unnecessary scrolling.

Implemented:

- deterministic merged-species ordering and regional display suffixes;
- privacy-safe unseen, seen, owned, party and PC Box display state;
- real `♀`/`♂` names through Widescreen's glyph-safe Pokemon label renderer;
- Select-to-toggle shiny portraits when an authoritative currently possessed
  party or PC Box Pokemon of that species is shiny;
- immutable main/detail snapshots;
- five-item submenu and session navigation;
- five-stat Generation I base-stat models;
- level-up moves followed by structured TM and HM compatibility sections;
- outgoing evolution models with live method describers and target privacy;
- preferred immutable spawn-provider Habitat query with a merged-engine
  grass/cave/Surf/Super Rod fallback;
- live `Sound.playCry` dispatch at action time;
- graceful refusal to replace the native Pokédex when Provider API v2 is
  unavailable.

No Pokédex flags, saves, species definitions, encounters, moves, evolutions,
items, sprites, cries, world geometry, or ROM data are mutated.

The package conflicts with `pokedex_plus`, since both replace the complete
Pokédex destination. It remains compatible with read-only data, encounter,
art, audio, shiny, follower, and world providers within their ownership
boundaries.

Shiny availability is queried live from the optional Gen1 Shiny System. It is
not inferred from the Pokédex owned flag and no second shiny registry is saved.
When that provider is missing or incompatible, the Pokédex safely displays only
normal art and Select retains Widescreen's ordinary behavior.

The shiny control appears only in Widescreen's footer; no duplicate hint is
drawn beneath the portrait. While shiny art is active, Widescreen displays the
supplied pixel-art gold star at the detail panel's top-right corner above the
sprite.
