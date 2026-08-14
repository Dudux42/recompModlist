# Gen1 Unified Quality of Life

Current build: **0.1.0-alpha.6**

One configurable Gen1Recomp mod for optional battle information, explicit
battle rules, location banners, and field shortcuts. It replaces the ownership
of Quality of Life, Catch Helper, and EXP Share Modes with one documented
Ultra Ball correction and otherwise explicit leveling/convenience rules.

## Defaults

Default settings:

- Caught Indicator: Off
- Catch Odds: Off
- EXP Share: Off
- Location Banners: Off
- Repel Prompt: On
- Field HMs: On
- Reusable TMs: On

Open **OPTIONS → QUALITY OF LIFE** for the grouped interface. The Mod Manager
also exposes the complete flat option schema.

## Battle Display

- A red Poke Ball immediately beside an already-caught wild Pokemon's name.
  Trainer-owned Pokemon never receive this marker.
- Whole-number Poke/Great/Ultra or Safari catch probabilities in the active
  battle-HUD font. With Widescreen UI 0.1.0-alpha.11.1 or newer, the helper is
  an attached footer that follows the enemy status panel.
- Exact enumeration of the stock two-roll check using live HP, status, catch
  rate, and merged ball/status records.
- A custom ball with its own `attempt` function displays unknown odds instead
  of an invented value.

## Battle Rules

The stock Ultra Ball permanently uses the corrected HP factor 8 while
retaining its stronger first roll. A third-party custom `attempt` remains
authoritative. There is no rule toggle.

**EXP Share**

- `OFF`: engine behavior is unchanged, including EXP.ALL.
- `ON`: living participants retain the normal full-pool split. Every other
  living party member independently receives a 50% share. EXP.ALL is ignored
  while this option owns the award.
- Shared recipients produce one `Remaining POKEMON received EXP!` message,
  rather than one gained-EXP message per party member. Necessary level-up and
  move-learning messages still identify the affected Pokemon.

All custom awards use the engine's native award continuation. Trainer/traded
bonuses, stat EXP, happiness, level messages, stat screens, move learning,
evolution scheduling, events, and Yellow Legacy's `exp.gain` cap remain live.
Integer floors and the engine's minimum-one rule can make totals differ
slightly from the headline percentages.

## World Convenience

### Field HMs

When Field HMs is enabled, obtaining an HM permanently unlocks its field move;
it does not have to be taught to a Pokemon and badge gates are bypassed. An HM
counts as obtained when it is in the Bag, stored in the PC, or its normal
acquisition event has been completed.

- The Start menu gains an `HMs` row listing every obtained HM.
- Interacting with a valid tree, pushable boulder, or body of water asks before
  using Cut, Strength, or Surf.
- Water interaction always means Surf; fishing remains on the normal item-use
  path. Ordinary tall grass is never treated as a Cut target.
- Entering a dark cave automatically asks whether to use Flash.
- Flash and Fly can be selected manually from the HMs menu.
- A plain Town Map allows A on a visited Fly city and asks before flying.
- Every HM activation uses a Yes/No prompt. Taught-HM shortcuts are removed
  from individual Pokemon submenus while this system is enabled.

### Reusable TMs

When Reusable TMs is enabled, successfully teaching a TM keeps it in the Bag.
Only one copy of each TM can exist across the Bag and item-storage PC:

- Shops cap a TM purchase at one and refuse an already-owned TM.
- Game Corner prize lists refuse a TM already present in the Bag or PC.
- Pickups and scripted rewards converge on the same duplicate guard.
- Withdrawing a stored TM transfers the one copy back to the Bag.
- Existing duplicate stacks are normalized to one when the save loads.

### Location and Repel

- With Widescreen UI 0.1.0-alpha.11.3.1 or newer, location banners use its
  real paper/ink/shadow panel style and Pixelify Sans body font at the top
  center of the final screen. Without Widescreen, the engine-style top-center
  banner remains as a fallback.
- The optional Repel renewal prompt appears after the wear-off message is
  acknowledged. It is independent of Field HMs.
- Easy Interactions, grass cutting, water-action arbitration and Select-menu
  shortcuts are not part of this mod.

## Compatibility and conflicts

Do not enable this mod with:

- `quality_of_life`
- `catch_helper`
- `exp_share_modes`

The manifest declares those conflicts. The mod does not own battle art, shiny
state, followers, visible-wild entities, encounter tables, world geometry,
camera behavior, EXP-bar rendering, or full UI layouts. The existing
Widescreen EXP bar remains its owner's responsibility. Integrations with
Widescreen UI, Dramatic
Shape/Battle Art Voxel Fork, Shiny System, HGSS icons/follower, Wilds, and
Yellow Legacy are optional and fail open.

The Dramatic Shape snapped-HUD interface is not public in the audited versions.
This alpha uses a narrow version-guarded observer for that path and otherwise
falls back to the engine's public `battle.overlay` hook.

## Legacy migration

If this mod has no settings yet, it migrates compatible settings from the three
superseded mods once. It never deletes their option buckets and never infers
that Catch Helper's unconditional Ultra correction should remain enabled.
Only the old `modern` EXP mode maps exactly to the new EXP Share toggle. Alpha
1's `modern_50` unified setting is upgraded automatically; obsolete alpha 1
keys are retained but ignored. Alpha 3 adds Field HMs and Reusable TMs enabled
by default without deleting older settings. Alpha 4 converts every enabled
legacy marker style to the single red caught-indicator toggle and retires the
manual marker-offset settings. Alpha 5 permanently corrects Ultra Balls and
retires Easy Interactions, Cut Grass and Water Action; their old save keys are
retained only for rollback. Alpha 6 routes location banners through
Widescreen's World HUD Overlay API v1 for exact style ownership.

## Installation

Import the flat release ZIP using the Gen1Recomp launcher. Do not extract it
over another mod and do not enable the three conflicting reference mods.

## Attribution

- Quality of Life by unxpected-uxp: behavioral reference only; its audited
  package/repository did not declare a license, so its source is not copied.
- Catch Helper 1.4.0 and EXP Share Modes 1.0.0: MIT-licensed behavioral and
  algorithmic references. The retained notice is in
  `THIRD_PARTY_LICENSES.txt`.

No ROM is included.
