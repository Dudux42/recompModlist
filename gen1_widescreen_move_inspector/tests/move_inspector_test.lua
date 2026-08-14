local function check(condition, message)
  assert(condition, message)
end

local function close(a, b)
  return math.abs(a - b) < 0.000001
end

local registrations, infos, errors = {}, {}, {}
local activeOwner = "gen1_widescreen_move_inspector"
local eventHandlers = {}
local widescreen = {
  exports = {
    battleMoveInspectorApiVersion = 1,
    activeBattleMoveInspectorOwner = function() return activeOwner end,
    registerBattleMoveInspector = function(spec)
      registrations[#registrations + 1] = spec
      return true, #registrations == 1 and "registered" or "replaced"
    end,
  },
}
local hookCalls = 0
local mod = {
  exports = {},
  find = function(_, id)
    check(id == "gen1_widescreen_ui", "looked up unexpected dependency")
    return widescreen
  end,
  hooks = { wrap = function() hookCalls = hookCalls + 1 end },
  events = { on = function(_, name, callback) eventHandlers[name] = callback end },
  log = {
    info = function(_, message) infos[#infos + 1] = message end,
    error = function(_, message) errors[#errors + 1] = message end,
  },
}

local init = assert(loadfile("gen1_widescreen_move_inspector/main.lua"))()
init(mod)
check(hookCalls == 0, "inspector installed a hook")
check(#registrations == 1, "provider did not register exactly once")
check(registrations[1].owner == "gen1_widescreen_move_inspector")
check(registrations[1].apiVersion == 1)
check(registrations[1].snapshot == mod.exports.snapshot)
check(eventHandlers["mods.loaded"] and eventHandlers["battle.started"],
  "provider lifecycle checks were not registered")
eventHandlers["mods.loaded"]()
check(#registrations == 1, "healthy provider was registered twice")
activeOwner = nil
eventHandlers["battle.started"]()
check(#registrations == 2, "missing provider was not repaired at battle start")
activeOwner = "gen1_widescreen_move_inspector"

local chart = {
  type_chart = {
    matchups = {
      { attacker = "FIRE", defender = "GRASS", multiplier = 20 },
      { attacker = "FIRE", defender = "BUG", multiplier = 20 },
      { attacker = "FIRE", defender = "WATER", multiplier = 5 },
      { attacker = "FIRE", defender = "ROCK", multiplier = 5 },
      { attacker = "ELECTRIC", defender = "WATER", multiplier = 20 },
      { attacker = "ELECTRIC", defender = "GROUND", multiplier = 0 },
      { attacker = "CUSTOM", defender = "ODD", multiplier = 15 },
    },
  },
}
check(close(mod.exports.effectiveness(chart, "FIRE", { "GRASS" }), 2))
check(close(mod.exports.effectiveness(chart, "FIRE", { "GRASS", "BUG" }), 4))
check(close(mod.exports.effectiveness(chart, "FIRE", { "WATER" }), 0.5))
check(close(mod.exports.effectiveness(chart, "FIRE", { "WATER", "ROCK" }), 0.25))
check(close(mod.exports.effectiveness(chart, "ELECTRIC", { "GROUND" }), 0))
check(close(mod.exports.effectiveness(chart, "FIRE", { "GRASS", "GRASS" }), 2),
  "duplicate monotype was squared")
check(close(mod.exports.effectiveness(chart, "FIRE", { "UNKNOWN" }), 1))
check(mod.exports.formatMultiplier(0) == "0×")
check(mod.exports.formatMultiplier(0.25) == "¼×")
check(mod.exports.formatMultiplier(0.5) == "½×")
check(mod.exports.formatMultiplier(1) == "1×")
check(mod.exports.formatMultiplier(2) == "2×")
check(mod.exports.formatMultiplier(4) == "4×")
check(mod.exports.formatMultiplier(1.5) == "1.5×")

local moves = {
  FLAME = { id = "FLAME", name = "FLAME", type = "FIRE", power = 80,
    accuracy = 100, pp = 15, effect = "NO_ADDITIONAL_EFFECT" },
  GROWL = { id = "GROWL", name = "GROWL", type = "NORMAL", power = 0,
    accuracy = 100, pp = 40, effect = "ATTACK_DOWN1_EFFECT" },
  SONICBOOM = { id = "SONICBOOM", name = "SONICBOOM", type = "NORMAL",
    power = 1, accuracy = 90, pp = 20, effect = "SPECIAL_DAMAGE_EFFECT" },
  COUNTER = { id = "COUNTER", name = "COUNTER", type = "FIGHTING",
    power = 1, accuracy = 100, pp = 20, effect = "NO_ADDITIONAL_EFFECT" },
  SWIFT = { id = "SWIFT", name = "SWIFT", type = "NORMAL", power = 60,
    accuracy = 100, pp = 20, effect = "SWIFT_EFFECT" },
  CUSTOM_FIXED = { id = "CUSTOM_FIXED", name = "CUSTOM FIXED", type = "GHOST",
    power = 99, accuracy = 0, pp = 5, fixedDamage = function() error("must not run") end },
}
local moveInstances = {
  { id = "FLAME", pp = 11, ppUps = 2 },
  { id = "GROWL", pp = 39 },
  { id = "SONICBOOM", pp = 18 },
  { id = "COUNTER", pp = 19 },
}
local battle = {
  phase = "moveSelect", moveIndex = 1,
  player = { curMoves = moveInstances, curTypes = { "FIRE" }, disabledSlot = 1 },
  enemy = { curTypes = { "GRASS", "BUG" } },
  data = { moves = moves, type_chart = chart.type_chart },
}
local snap = mod.exports.snapshot(battle)
check(snap and snap.schemaVersion == 1)
check(snap.moveId == "FLAME" and snap.moveName == "FLAME")
check(snap.pp.current == 11 and snap.pp.maximum == 21, "PP Ups were not applied")
check(snap.power.kind == "base" and snap.power.value == 80)
check(snap.accuracy.kind == "percent" and snap.accuracy.label == "100%")
check(close(snap.matchup.factor, 4) and snap.matchup.label == "SUPER EFFECTIVE")
check(snap.matchup.multiplierLabel == "4×")
check(snap.stab.applies and snap.disabled)
check(#snap.matchup.defenderTypes == 2)
check(snap.matchup.defenderTypes ~= battle.enemy.curTypes,
  "snapshot leaked the mutable current-types table")

-- Live merged data and current battle types are read again, not cached.
battle.data.type_chart.matchups[1].multiplier = 5
battle.enemy.curTypes = { "WATER" }
battle.player.curTypes = { "WATER" }
snap = mod.exports.snapshot(battle)
check(close(snap.matchup.factor, 0.5) and snap.matchup.label == "RESISTED")
check(not snap.stab.applies, "STAB ignored transformed/current types")

battle.moveIndex = 2
snap = mod.exports.snapshot(battle)
check(snap.power.kind == "status" and snap.power.label == "—")
check(not snap.stab.applies and snap.matchup.label == "TYPE CHART")

battle.moveIndex = 3
snap = mod.exports.snapshot(battle)
check(snap.power.kind == "fixed" and not snap.stab.applies)
check(snap.matchup.label == "TYPE CHART")

battle.moveIndex = 4
snap = mod.exports.snapshot(battle)
check(snap.power.kind == "special" and snap.power.label == "VARIES")

battle.player.curMoves[4] = { id = "SWIFT", pp = 12, maxPP = 27 }
snap = mod.exports.snapshot(battle)
check(snap.accuracy.kind == "always" and snap.accuracy.label == "ALWAYS")
check(snap.pp.maximum == 27)

battle.player.curMoves[4] = { id = "CUSTOM_FIXED", pp = 5 }
snap = mod.exports.snapshot(battle)
check(snap.power.kind == "fixed", "explicit fixedDamage was not classified")
check(snap.accuracy.kind == "unavailable" and snap.accuracy.label == "—")

battle.phase = "messages"
check(mod.exports.snapshot(battle) == nil)
battle.phase = "moveSelect"
battle.player = nil
check(mod.exports.snapshot(battle) == nil)
battle.player = { curMoves = { { id = "MISSING", pp = 1 } }, curTypes = {} }
check(mod.exports.snapshot(battle) == nil)

-- Runtime incompatibility is actionable and registers nothing.
local missingErrors = 0
local missing = {
  exports = {}, find = function() return nil end,
  log = { error = function() missingErrors = missingErrors + 1 end },
}
init(missing)
check(missingErrors == 1, "missing Widescreen API did not warn exactly once")

print("move_inspector_test: OK")
