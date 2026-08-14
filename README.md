# Invoker's Gen1Recomp Mod List

Source, assets, releases, audits, and planning documents for a coordinated
Pokémon Red/Blue/Yellow mod collection targeting
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).

The currently verified engine baseline is **Gen1Recomp 0.1.83**, mod API 2.
This repository is a development and preservation workspace, not an automatic
installer. Import release ZIPs through Gen1Recomp's launcher.

## Current mod list

| Mod | Manifest ID | Version | Purpose |
|---|---|---:|---|
| Gen1 Widescreen UI | `gen1_widescreen_ui` | `0.1.0-alpha.14.32` | Central 640×360 presentation layer for menus, battles, dialogue, PC, Bag, Pokédex, and generic provider contracts. |
| Gen1 Bill S.S. Ticket Repair | `gen1_bill_ss_ticket_repair` | `0.1.1` | Repairs interrupted Bill quest saves and the verified Echoes Beyond the Fog vanilla fallback. |
| HGSS Menu Icons | `hgss_menu_icons` | `0.1.0-alpha.4` | Normal and shiny HGSS-style menu icons for all 151 Gen 1 Pokémon. |
| HGSS Simple Follower | `hgss_simple_follower` | `0.1.0-alpha.18` | One selected party follower plus an independent overworld-sprite provider for visible wilds. |
| Gen1 Shiny System | `gen1_shiny_system` | `0.1.0-alpha.3` | Owns shiny rolls, valid DVs/state, colors, sparkles, art policy, and visible-wild outcome reservations. |
| Gen1 Balances | `gen1_balances` | `0.1.0-alpha.2` | Live encounter/fishing changes, selected base stats and learnsets, and additive level paths for trade evolutions. |
| Gen1 Battle Art Replacer | `gen1_battle_art_replacer` | `0.1.0-alpha.12` | Selectable Red/Blue/Yellow and later-generation 2D Pokémon front art with static/animated modes and ROM fallback. |
| Gen1 Unified Quality of Life | `gen1_quality_of_life` | `0.1.0-alpha.6` | Unified convenience features, Catch Helper information, explicit Ultra Ball correction, and selectable EXP modes. |
| Widescreen Move Inspector | `gen1_widescreen_move_inspector` | `0.1.0-alpha.2` | Read-only highlighted-move type, PP, power, accuracy, matchup, and STAB information in the Widescreen battle HUD. |
| Widescreen Pokédex | `gen1_widescreen_pokedex` | `0.1.0-alpha.7` | Master/detail Pokédex with Habitat, Stats, Learnset, Evolution, Cry, and live provider-aware art/data. |
| Gen1 Character Sprite Replacer | `gen1_character_sprite_replacer` | `0.1.0-alpha.8` | Player, overworld NPC, and enemy-trainer human appearance across overworld and battle contexts. |
| Widescreen Modern Bag | `gen1_widescreen_modern_bag` | `0.1.0-alpha.5` | Six-pocket icon Bag with explicit sorting, vanilla-style movement, large stacks, and engine-owned item actions. |
| Kanto Living Encounters | `kanto_living_encounters` | `0.1.0-alpha.4` | Experimental visible wild Pokémon with safe-cell selection, overworld AI, exact shiny outcomes, and classic random encounters retained. |
| Dramatic Shape Battle Sprite Lighting Patch | `dramatic_shape_battle_shadow_patch` | `0.2.0` | Prevents flat Pokémon battle billboards from receiving unstable self-shadow/time-of-day tint under Dramatic Shape 1.8.x. |

## In-development and planned mods

| Mod | Status | Plan |
|---|---|---|
| Widescreen Grid Box (`gen1_widescreen_grid_box`) | Source build `0.1.0-alpha.1`; release audit pending | Gen III-style 5×4 Bill's PC grid, Party drawer, and atomic movement. Widescreen alpha 14.32 has completed its required Storage Provider API presenter; the consumer dependency and final audits still need updating. |
| Kanto Dex Radar | Ready to implement | Widescreen Start-menu radar that reads only Kanto Living Encounters' immutable effective-spawn snapshot. |
| Yellow Legacy full recreation | Archived/superseded | Preserved as research only. Its selected balance data and narrow Bill repair were split into focused mods. |

See [Agent_list.md](Agent_list.md) for the current workstream roster, progress,
blockers, and home-to-work-PC handoff. See
[MASTER_MOD_GUIDE.md](MASTER_MOD_GUIDE.md) for mandatory ownership,
compatibility, packaging, and licensing rules.

## Important dependencies and conflicts

- Widescreen-dependent mods require the version range declared in their own
  manifests. Grid Box must use Widescreen `>=0.1.0-alpha.14.32 <0.2.0` before
  release.
- Kanto Living Encounters requires HGSS Simple Follower alpha 18 and Gen1
  Shiny System alpha 3. It conflicts with the original Wilds of Kanto
  (`overworld_wild_spawns`).
- Battle Art Replacer conflicts with Battle Art Voxel Fork because both own
  the same Pokémon battle-art surface.
- Modern Bag, Move Inspector, Pokédex, Quality of Life, Shiny, and Grid Box
  declare conflicts with the corresponding original mods that own the same
  behavior.
- Dramatic Shape Battle Sprite Lighting Patch is guarded to Dramatic Shape
  `>=1.8.0 <1.9.0` and fails closed outside its audited renderer surface.

## Repository layout

```text
Releases/                         Current release ZIPs
Releases/Old versions/            Recoverable superseded releases
gen1_*/ and hgss_*/               Editable mod source trees
kanto_living_encounters/          Visible-wild source
dramatic_shape_battle_shadow_patch/ Compatibility-patch source
pokemon_white2_front_spritesheets/ Source artwork used by Battle Art work
request_assets/                   Supplied task assets
visual_audits/                    Rendered verification images
tools/                            Asset and audit utilities
NEXT_AGENT_*.md                   Implementation handoffs
*_REQUEST.md                      Cross-mod owner requests and completions
MASTER_MOD_GUIDE.md               Canonical project policy and architecture
Agent_list.md                     Current progress and computer handoff
```

The `.audit` scratch tree, local `node_modules` junction, ROMs, saves,
credentials, emulator data, and third-party AnimaEngine binary archive are
intentionally excluded from Git. They are machine-specific, unsafe, or not
project-owned redistributables.

## Installation

1. Install a compatible Gen1Recomp build and import a legally obtained Pokémon
   Red, Blue, or Yellow ROM through its normal workflow.
2. Download the desired ZIPs from `Releases`.
3. Import them through the Gen1Recomp launcher.
4. Enable required providers before their consumers and resolve any manifest
   conflicts reported by the launcher.
5. Keep backups before testing alpha or experimental gameplay mods.

Do not extract a release directly over another installed version. This project
does not install or alter the user's launcher directory automatically.

## Development rules

- Read `MASTER_MOD_GUIDE.md` before editing any workstream.
- Never edit the launcher's installed-mod folder; extract a release into a
  separate development directory.
- Another mod's required fix belongs to its owning agent and must be expressed
  as a focused owner request.
- Keep UI presentation separate from gameplay and world geometry.
- Use nearest-neighbor filtering and integer placement for pixel art.
- Bump manifest, README, source header, dependency floors, and ZIP filename
  together. Never overwrite a delivered release.
- Package flat/root-only ZIPs and never include a ROM.

## Releases and retention

The main `Releases` directory normally keeps the latest three semantic
versions per mod. Older ZIPs are moved to `Releases/Old versions` rather than
deleted. The repository preserves both directories so development can be
continued from another computer.

## Legal and attribution notice

Pokémon and related names, characters, artwork, and trademarks belong to their
respective owners. This is an unofficial fan-development project and is not
affiliated with or endorsed by Nintendo, Game Freak, Creatures, or The Pokémon
Company.

No ROM is included. Some project assets are ROM-derived or based on supplied
game artwork and are retained for private development/reference. Their
presence does not grant redistribution rights. Each mod's included license and
third-party notices govern its code/assets; do not assume the entire repository
is covered by one license.
