# Next Agent Brief — Widescreen Move Inspector

Last updated: **2026-08-10**

## Implementation status — completed 2026-08-10

The planned feature is implemented in editable source and release archives:

- Gen1 Widescreen UI `0.1.0-alpha.9`:
  `Releases/gen1_widescreen_ui_v0.1.0-alpha.9.zip`.
- Widescreen Move Inspector `0.1.0-alpha.2`:
  `Releases/gen1_widescreen_move_inspector_v0.1.0-alpha.2.zip`.

Alpha.2 repairs the real-launcher provider lifecycle seen during the first
in-game test: registration is checked at initialization, after `mods.loaded`,
and at `battle.started`, without adding a battle/render hook.

Alpha 9 is based on the newer alpha 8.2 release, not the older development
tree. It preserves alpha 8.2's 2×2 directional navigation and both Dramatic
Shape/Battle Art snapped-HUD adapters. The superseded alpha 8.2 ZIP remains in
`Releases` pending the user's launcher confirmation.

Verified decisions:

- Provider API and snapshot schema are v1; the exact dependency floor is
  Widescreen `0.1.0-alpha.9`.
- Gen1Recomp's merged type-chart multipliers are integer ×10 and missing pairs
  are neutral. The inspector deduplicates repeated current defender types.
- Accuracy is stored as a percentage. Swift's effect is the audited always-hit
  case. Zero/nil is presented as unavailable, never `0%`.
- `SPECIAL_DAMAGE_EFFECT` and explicit `fixedDamage` are `FIXED`; Counter,
  Bide, OHKO, Super Fang, Metronome and Mirror Move are `VARIES`.
- Fixed damage and Super Fang skip type effectiveness in Gen 1, while OHKO
  still checks immunity. Non-ordinary moves therefore show `TYPE CHART` plus
  the numeric factor instead of promising an outcome.
- No authoritative side-effect-free damage preview API exists in the audited
  engine. Final damage, accuracy stages and move-specific gates are not shown.
- Mimic keeps Widescreen's basic detail panel.

The exact shipped Lua 5.1 runtime passes `start_menu_test.lua`, the expanded
`battle_hud_test.lua` provider/integration/regression test, and
`move_inspector_test.lua`. Flat ZIP audits pass with 6 Widescreen root entries
and 5 Move Inspector root entries. Visual layout audits are under
`.audit/move_inspector_visual`. Final launcher/in-game verification remains a
user test; neither archive was installed automatically.

## 1. Mission

Create a new Move Inspector for Invoker's Gen1 Recomp compilation. Recreate the
useful behavior of the installed **Move Inspector 1.0.0**, but make **Gen1
Widescreen UI a mandatory dependency and the sole presenter**.

Working title: **Widescreen Move Inspector**  
Provisional manifest ID: `gen1_widescreen_move_inspector`

The mod is informational only. It may read the live battle state, merged move
data and merged type chart, but it must not change moves, PP, targeting,
accuracy, damage, AI, turn order, battle RNG, saves or ROM data.

Read `MASTER_MOD_GUIDE.md` before implementation. Do not reuse the reference
manifest ID `move_inspector`.

## 2. Installed reference audited

Read-only path:

`C:\Users\invok\AppData\Roaming\pokemon-love2d\mods\move_inspector`

Audited files:

- `manifest.json`
- `main.lua`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`

Reference facts:

- Version `1.0.0`, Mod API 2, content profile, QOL category, priority 100.
- No permissions or dependencies; `affects_link` is false.
- Wraps `battle.overlay` at priority 200 and draws after the existing overlay.
- Operates only while `battle.phase == "moveSelect"`.
- Reads the highlighted move from `battle.player.curMoves[battle.moveIndex]`.
- Reads definitions and type matchups from the merged runtime battle data.
- Uses `battle.player.curTypes` and `battle.enemy.curTypes`, so Transform,
  Conversion and modded type changes are reflected.
- Replaces the native TYPE/PP box using hardcoded Classic/Wide coordinates.
- Displays type abbreviation/current PP, power/accuracy, type effectiveness
  and a trailing `*` for STAB.
- Distinguishes status and fixed-damage moves.
- Exports `effectiveness(data, attackType, defenderTypes)` and
  `moveInfo(battle)`.
- Is MIT-licensed. Copied or substantially reused code must retain the
  copyright notice and permission text.

The reference's calculation layer is worth preserving. Its direct drawing and
hardcoded native coordinates are not appropriate for this project.

## 3. Required user-facing behavior

When the player highlights a move in the normal FIGHT move-selection screen,
show at least:

- Full move type through Widescreen's existing color-coded type badge.
- Current PP and maximum PP.
- Power.
- Accuracy.
- Type-chart effectiveness against the opponent's current type or types.
- Whether ordinary STAB applies.
- Clear classification for damaging, status and fixed-damage moves.

Reference labels that must remain semantically available:

| Condition | Compact meaning |
|---|---|
| `4×`, `2×` | Super effective by the current type chart |
| `1×` | Neutral type matchup |
| `½×`, `¼×` | Not very effective by the current type chart |
| `0×` | Type-chart immunity |
| `STATUS` | No normal base-power damage |
| `FIXED` | Fixed-damage move |
| STAB indicator | User's current type matches the move type |

Do not copy the Italian abbreviations `SUPR`, `POC` or `NORM` into the new
English UI unless the user specifically requests them. Prefer readable labels
such as `SUPER EFFECTIVE · 2×`, `NEUTRAL · 1×`, `RESISTED · ½×` and `IMMUNE ·
0×`, with compact fallbacks only when layout testing requires them.

The selected move must update immediately when the cursor moves, PP changes,
the user switches Pokémon, or either battler's live types change.

## 4. Mandatory Widescreen dependency

This mod is a semantic provider/feature extension for Widescreen's Battle HUD.
It must not draw a second overlay.

Conceptual manifest requirement:

```json
"dependencies": [
  "gen1_widescreen_ui@>=REQUIRED_MOVE_INSPECTOR_API_VERSION"
]
```

Use the real launcher schema confirmed from current manifests.

Current development fact: Gen1 Widescreen UI `0.1.0-alpha.8` already owns the
final 640×360 Battle HUD and move-selection panel, but it does **not** publish a
Move Inspector provider contract. Add and test that contract in Widescreen
first, bump Widescreen, then set this mod's exact dependency floor. Do not claim
alpha 8 is sufficient without that API.

Required dependency behavior:

- Widescreen remains the only owner of battle HUD layout and drawing.
- Move Inspector owns calculation and its immutable semantic snapshot.
- Dependency direction is one-way: Move Inspector depends on Widescreen;
  Widescreen must not depend on Move Inspector.
- If the required runtime export is missing despite the manifest dependency,
  log one actionable incompatibility error and install no battle hook/patch.
- While Move Inspector is enabled, the Widescreen Battle HUD must be enabled.
  Lock/hide that Widescreen toggle or report an explicit incompatibility; never
  fall back to a native Classic/Wide inspector box.
- Do not call `love.graphics`, `Font.drawBox` or native tile-coordinate drawing
  from this mod.

### 4.1 Minimum provider contract

Finalize names with the Widescreen owner. The provider contract must support at
least:

```lua
local ok, reason = widescreen.registerBattleMoveInspector({
  owner = "gen1_widescreen_move_inspector",
  apiVersion = 1,
  snapshot = function(battle)
    return inspectorSnapshotOrNil
  end,
})
```

The Widescreen API should:

- Accept one active provider deterministically and reject duplicate owners.
- Validate the provider API version and snapshot schema.
- Call the provider only for active move-selection presentation.
- Treat returned tables as immutable.
- Render a safe default move panel if the provider is absent.
- Expose unregister/reload behavior or replace the same owner safely.
- Deduplicate provider errors and retain a usable Battle HUD.

Do not make Widescreen discover this mod by hardcoded manifest ID. Registration
must be generic so another compatible inspector could use the same API.

## 5. Semantic snapshot

Recommended versioned shape:

```lua
{
  schemaVersion = 1,
  phase = "moveSelect",
  selectedIndex = 1,
  moveId = "THUNDERBOLT",
  moveName = "THUNDERBOLT",
  typeId = "ELECTRIC",
  pp = { current = 14, maximum = 15 },
  power = { kind = "base", value = 95, label = "95" },
  accuracy = { kind = "percent", value = 100, label = "100%" },
  matchup = {
    factor = 2,
    label = "SUPER EFFECTIVE",
    multiplierLabel = "2×",
    defenderTypes = { "WATER" },
  },
  stab = { applies = true, label = "STAB" },
  disabled = false,
}
```

For status and fixed-damage moves, use explicit machine-readable kinds rather
than overloading display strings:

```lua
power = { kind = "status", value = nil, label = "—" }
power = { kind = "fixed", value = nil, label = "FIXED" }
accuracy = { kind = "always", value = nil, label = "—" }
```

The snapshot must not expose mutable battler, move-definition, type-chart or
save tables to Widescreen.

## 6. Calculation requirements

### 6.1 Live sources

Use only the effective current battle state:

- Highlighted move instance and current PP.
- Effective merged move definition.
- User's current battle types.
- Target's current battle types.
- Effective merged type chart.
- Current disabled-slot state where available.

This preserves Transform, Conversion, balance mods, added types and runtime
battle changes. Do not cache these values across frames or selections. Small
lookup indexes derived from the type chart may be cached only with a clear
invalidation key when the active data object changes.

### 6.2 Effectiveness

Compute the product of the attack type's multiplier against each distinct
current defender type. Gen1Recomp's reference chart stores multipliers as
integers scaled by ten (`0`, `5`, `10`, `20`, etc.); verify this against the
current engine rather than hardcoding an assumption silently.

Requirements:

- Default a missing matchup row to neutral only if that matches the engine's
  own type-chart behavior.
- Deduplicate repeated defender type IDs so a monotype represented twice is not
  accidentally squared.
- Support factors beyond the vanilla set without crashing.
- Preserve exact numeric factor separately from its localized label.
- Use tolerant numeric comparison or rational/scaled-integer arithmetic; avoid
  brittle direct floating-point equality.

### 6.3 STAB

The reference marks STAB only for ordinary damaging, non-fixed moves when the
move type matches either current user type. Preserve that behavior unless an
engine audit proves its damage rules differ.

- Do not mark status moves as receiving a damage bonus.
- Do not mark fixed-damage moves as receiving a damage bonus.
- Use current battle types, not base species types.
- Keep `stab.applies` separate from presentation text/iconography.

### 6.4 Power and accuracy

- Positive ordinary base power: show the effective move definition's value.
- Zero/non-damaging power: classify as `status`.
- `fixedDamage`: classify as `fixed`; do not imply normal base-power scaling.
- Positive accuracy: present as a percentage only after confirming the engine
  field's units.
- Zero/nil accuracy commonly means not applicable or always-hit; verify the
  engine convention and show `—`/`ALWAYS`, not `0%`.

Dynamic-power or special-formula moves must not be presented as an exact final
power merely because their static definition has a placeholder. If the engine
exposes a safe preview helper, consume it; otherwise label the value as `VARIES`
or `SPECIAL` and document the limitation.

### 6.5 Honest scope of the prediction

The multiplier is a **type-chart matchup**, not a promised outcome. Unless the
engine provides an authoritative side-effect-free preview API, do not claim to
predict:

- Final damage range.
- Critical hits or random rolls.
- Accuracy/evasion stages.
- Move-specific immunities or failure conditions.
- Semi-invulnerable states.
- Substitute or other battle-state exceptions.
- Multi-hit totals, recoil, drain or secondary effects.
- AI choice or turn order.

For status and fixed-damage moves, a raw type immunity may or may not describe
the move's actual success rules. Audit engine behavior before showing `IMMUNE`;
otherwise present `STATUS`/`FIXED` and a secondary `TYPE MATCHUP 0×` note rather
than asserting “no effect.”

## 7. Widescreen presentation requirements

Extend the existing alpha 8 move panel rather than replacing the whole Battle
HUD. Preserve its 2×2 move grid, selected state, swap outline, disabled state,
type badge and PP display.

Recommended detail-panel hierarchy:

1. Full type badge.
2. `PP current/max`.
3. `POWER value` and `ACCURACY value`.
4. Matchup label plus multiplier.
5. STAB indicator, when applicable.
6. Disabled warning, when applicable.

Requirements:

- Pixelify Sans and Widescreen's established palette/components.
- 640×360 design surface, final-resolution rendering.
- Integer positions; nearest-neighbor treatment for pixel assets.
- No overlap with move names, PP, disabled/swap indicators or screen edges.
- Color is supportive, not the only carrier of meaning.
- Compact labels for narrow fallback sizes without losing the numeric factor.
- Immediate refresh with cursor/type/PP changes.
- No native 160×144 or engine WideBattle inspector underneath.
- No change to battle arena, battlers, animations, camera, Dramatic Shape or
  Stadium models.

Normal move selection is required. Mimic selection is a separate state using
`battle.mimicMoves`; do not display target matchup/STAB there unless the data is
meaningful and verified. The safe default is Widescreen's existing basic Mimic
move detail with no inspector claim.

## 8. Compatibility and ownership

### Yellow Legacy recreation

Read effective merged move and type-chart data. This inspector must reflect
Yellow Legacy's move power, accuracy, typing and matchup changes without
depending on Yellow Legacy or duplicating its tables.

### Unified Quality of Life

The QOL mod owns Catch Helper, EXP policy and field conveniences. Move Inspector
owns only highlighted-battle-move information. Keep it a separate mod so users
can enable it independently.

### Widescreen Modern Bag

The Bag's TM/HM Move Information is an out-of-battle inventory screen. It may
share a future pure move-formatting utility, but neither mod may depend on or
patch the other's UI. Widescreen presents both through separate contracts.

### Moves Manager and Move Learn Stats

Those mods own party moveset management and move-learning information. This
mod does not edit moves or add learn-screen overlays. If common metadata is
needed, read merged engine data or a versioned read-only helper; do not copy
mutable state between mods.

### Battle Art, Shiny, follower, spawn and world mods

No ownership overlap. Do not touch sprites, shiny state, followers, encounter
tables, visible wild entities, world geometry or battle models.

### Other battle UI mods

Any mod that owns the final Battle HUD can conflict visually with Widescreen.
This inspector does not solve that conflict and must not add another overlay.
Document the same Gen 3 Inspired UI compatibility warning as Widescreen where
relevant.

## 9. Conflict, license and package policy

Declare a conflict with `move_inspector`; enabling both would add duplicate and
potentially misleading move information. Inspect the active mod list for other
mods registering the same inspector-provider role.

Proposed flat package:

```text
manifest.json
main.lua
README.md
CHANGELOG.md
LICENSE
```

No assets are required unless the final design adds a small original icon. Use
root-only ZIP entries. Retain the MIT notice when copying or substantially
reusing reference code. Record any additional asset/font licensing, although
Widescreen should normally supply the font and visual components.

## 10. Public exports

Expose pure, narrow helpers for tests and compatible consumers. Final names
must be versioned:

```lua
exports.apiVersion = 1
exports.effectiveness(data, attackType, defenderTypes)
exports.snapshot(battle)
exports.formatMultiplier(factor)
```

Pure helpers must not mutate inputs. Return `nil, reason` or a documented safe
nil for unsupported states; do not throw from ordinary absent battle data.

## 11. Required tests

### Calculation tests

- Not in move selection → no snapshot.
- Missing player, enemy, move instance or definition → safe nil.
- Neutral, 2×, 4×, ½×, ¼× and 0× matchups.
- Unknown/custom multiplier formatting.
- Dual typing and duplicated monotype representation.
- Current types after Transform/Conversion-like changes.
- Merged move/type-chart modifications.
- Ordinary damaging STAB and non-STAB.
- No STAB bonus claim for status/fixed damage.
- Status, fixed, dynamic/special power and always-hit accuracy conventions.
- Current/max PP including PP Ups or explicit `maxPP`.
- Disabled highlighted slot.
- Snapshot contains no mutable engine tables.
- Calculations do not consume RNG or mutate battle state.

### Contract/dependency tests

- Missing/too-old Widescreen fails manifest activation.
- Runtime API mismatch registers nothing and warns once.
- Provider registers once and reloads/replaces its own owner safely.
- Duplicate competing provider is rejected deterministically.
- Provider exception leaves Widescreen's base move panel usable.
- Enabling this mod enforces the Widescreen Battle HUD presentation.
- Disabling/removing this mod restores Widescreen's normal basic move panel.

### Integration tests

- Normal battles, trainer battles and transformed/current-type states.
- Move cursor changes refresh immediately.
- PP changes refresh without reopening the menu.
- Yellow Legacy-style move/type overrides appear live.
- Dramatic Shape retains arena/camera/battler ownership.
- Battle Art modes, including Stadium, are unchanged.
- Another battle overlay in the hook chain still runs; this mod draws nothing.
- Mimic retains a safe basic presentation.

### Visual audit

Capture at least:

- Four-move and fewer-than-four-move grids.
- Long move names.
- Neutral, super-effective, resisted and immune matchups.
- STAB and non-STAB.
- Status, fixed and dynamic/special moves.
- Disabled and move-swap states.
- Low/zero PP and boosted maximum PP.
- Dual-type target.
- 1080p, 1440p, 4K and narrow supported fallback.
- Dramatic Shape 2D/3D arena and Stadium modes.

Verify sharp text, readable hierarchy, no clipping, no color-only meaning and
exactly one final Battle HUD.

## 12. Implementation order

1. Read the master guide and current Widescreen Battle HUD source/tests.
2. Audit the current engine's authoritative type, STAB, fixed-damage, dynamic
   power and accuracy conventions.
3. Design and land the generic Widescreen inspector-provider API.
4. Bump Widescreen and finalize this mod's dependency floor.
5. Implement pure calculations and immutable snapshots.
6. Register the provider without drawing or replacing battle simulation hooks.
7. Extend Widescreen's existing move-detail panel.
8. Run calculation, dependency, integration and visual tests.
9. Build a versioned flat ZIP in `Releases`; do not install it automatically.

## 13. Decisions to verify before coding

1. Final manifest ID and title.
2. Exact Widescreen provider API and dependency version.
3. Engine representation and default behavior for missing type-chart rows.
4. Engine conventions for fixed damage, dynamic power and zero/nil accuracy.
5. Whether the engine exposes a side-effect-free authoritative move preview.
6. Whether Mimic selection should show any inspector fields.
7. Which competing battle UI/inspector mods require declared conflicts.

Do not guess these values in production code. Document verified answers in the
README and tests.

## 14. Definition of done

- Widescreen UI is an enforced manifest and runtime dependency.
- Widescreen is the sole Battle HUD presenter; this mod performs no drawing.
- The highlighted normal battle move shows type, PP, power, accuracy, matchup
  and honest STAB status from live effective data.
- Status, fixed and special/dynamic moves are not misrepresented.
- The feature never changes battle mechanics, RNG, AI or saves.
- Yellow Legacy and runtime type changes are reflected without hardcoded data.
- Required tests and visual audits pass.
- The release is a licensed, versioned, flat ZIP and is not auto-installed.
