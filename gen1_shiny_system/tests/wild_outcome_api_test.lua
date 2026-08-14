local options = {
  enabled = true, shiny_rate = "modern", recolor = true,
  sparkles = true, debug_ow = false,
}
local defaultRngCalls = 0

love = {
  math = { random = function() defaultRngCalls = defaultRngCalls + 1 return 2 end },
  timer = { getTime = function() return 0 end },
  graphics = { setColor = function() end, rectangle = function() end },
}

local Stats = {
  isShiny = function(dvs)
    return type(dvs) == "table" and dvs.defense == 10 and dvs.speed == 10
      and dvs.special == 10
      and ({ [2]=true, [3]=true, [6]=true, [7]=true,
        [10]=true, [11]=true, [14]=true, [15]=true })[dvs.attack] == true
  end,
  calc = function(_, level)
    return { hp = 20 + level, attack = 10, defense = 10, speed = 10, special = 10 }
  end,
}
package.preload["src.pokemon.Stats"] = function() return Stats end

local Pokemon = {}
function Pokemon.new(_, species, level)
  local natural = species == "NATURAL"
  return {
    species = species, level = level, hp = 20, stats = { hp = 20 },
    shiny = natural and true or nil,
    dvs = natural
      and { attack = 2, defense = 10, speed = 10, special = 10, hp = 10 }
      or { attack = 1, defense = 1, speed = 1, special = 1, hp = 15 },
  }
end
package.preload["src.pokemon.Pokemon"] = function() return Pokemon end

local BattleState = {}
function BattleState.newWild(game, species, level, opts)
  return { game = game, data = game.data, opts = opts,
    enemy = { mon = Pokemon.new(game.data, species, level), isPlayer = false } }
end
function BattleState:drawPicsLayer() end
package.preload["src.battle.BattleState"] = function() return BattleState end

package.preload["src.render.PaletteFX"] = function()
  return { wholeNamed = function() return {} end }
end
package.preload["src.pokemon.Sprites"] = function()
  return { path = function() return "battle.png", true end }
end
package.preload["src.render.Assets"] = function() return {} end
package.preload["src.core.Sound"] = function() return { play = function() end } end
package.preload["src.ui.OptionRows"] = function()
  return { clampScroll = function(_, value) return value end, draw = function() end }
end
package.preload["src.ui.Screens"] = function() return { push = function() end } end

local mod = {
  id = "gen1_shiny_system",
  options = {
    define = function() end,
    get = function(_, key) return options[key] end,
    set = function(_, key, value) options[key] = value end,
  },
  events = { on = function() end },
  hooks = { wrap = function() end },
  content = { screens = { register = function() end } },
  read = function() return "return {}" end,
  find = function() return nil end,
  exports = {},
  log = { info = function() end, warn = function() end },
}

local init = assert(loadfile("gen1_shiny_system/main.lua"))()
init(mod)

assert(mod.exports.wildOutcomeApiVersion == 1)
assert(type(mod.exports.reserveWildOutcome) == "function")
assert(type(mod.exports.wildBattleOptions) == "function")

local denominators = {
  gen2 = 8192, modern = 4096, common = 1024, frequent = 512,
  often = 100, high = 10,
}
for rate, denominator in pairs(denominators) do
  options.enabled, options.shiny_rate = true, rate
  local calls = 0
  local hit = mod.exports.reserveWildOutcome(function(n)
    calls = calls + 1
    assert(n == denominator, rate .. " used the wrong denominator")
    return 1
  end)
  assert(hit.shiny == true and calls == 1, rate .. " hit was not one exact roll")
  calls = 0
  local miss = mod.exports.reserveWildOutcome(function(n)
    calls = calls + 1
    assert(n == denominator)
    return 2
  end)
  assert(miss.shiny == false and calls == 1, rate .. " miss was not one exact roll")
end

for _, case in ipairs({
  { enabled = false, rate = "high", shiny = false },
  { enabled = true, rate = "off", shiny = false },
  { enabled = true, rate = "always", shiny = true },
}) do
  options.enabled, options.shiny_rate = case.enabled, case.rate
  local calls = 0
  local outcome = mod.exports.reserveWildOutcome(function()
    calls = calls + 1
    return 1
  end)
  assert(outcome.shiny == case.shiny and calls == 0,
    case.rate .. " should resolve without sampling an irrelevant denominator")
end

local game = { data = { pokemon = {
  PIDGEY = { baseStats = { hp = 40 } },
  NATURAL = { baseStats = { hp = 40 } },
} } }

-- A denominator-based reservation consumes one RNG sample. Battle construction
-- consumes that snapshot and must not touch provider RNG again.
options.enabled, options.shiny_rate = true, "high"
local reserveCalls = 0
local shinyOutcome = mod.exports.reserveWildOutcome(function(n)
  reserveCalls = reserveCalls + 1
  assert(n == 10)
  return 1
end)
assert(shinyOutcome.shiny == true and reserveCalls == 1)
assert(not pcall(function() shinyOutcome.extra = true end),
  "wild outcome accepted ordinary mutation")
local shinyOpts = assert(mod.exports.wildBattleOptions(shinyOutcome))
local secondOpts = assert(mod.exports.wildBattleOptions(shinyOutcome))
assert(shinyOpts ~= secondOpts, "wildBattleOptions must return a fresh table")
defaultRngCalls = 0
local shinyBattle = assert(BattleState.newWild(game, "PIDGEY", 5, shinyOpts))
local shinyMon = shinyBattle.enemy.mon
assert(defaultRngCalls == 0, "reserved battle performed a second provider roll")
assert(shinyMon.shiny == true and Stats.isShiny(shinyMon.dvs),
  "reserved shiny did not produce compatible flag and native DVs")
assert(BattleState.newWild(game, "PIDGEY", 5, secondOpts) == nil,
  "a second options table silently reused a consumed outcome")
assert(mod.exports.wildBattleOptions(shinyOutcome) == nil,
  "consumed outcome was accepted again")

options.shiny_rate = "off"
local missOutcome = mod.exports.reserveWildOutcome()
assert(missOutcome.shiny == false, "reserved visible miss metadata is wrong")
local missBattle = assert(BattleState.newWild(game, "NATURAL", 5,
  assert(mod.exports.wildBattleOptions(missOutcome))))
local missMon = missBattle.enemy.mon
assert(missMon.shiny == nil and not Stats.isShiny(missMon.dvs),
  "reserved miss did not clear explicit flag and naturally shiny DVs")

assert(mod.exports.wildBattleOptions({ shiny = true }) == nil,
  "foreign outcome was accepted")
local altered = mod.exports.reserveWildOutcome()
rawset(altered, "shiny", not altered.shiny)
assert(mod.exports.wildBattleOptions(altered) == nil,
  "altered outcome was accepted")

-- No reservation means the existing provider wrapper still governs every
-- ordinary wild-construction route.
options.enabled, options.shiny_rate = true, "high"
defaultRngCalls = 0
for _, route in ipairs({ "GRASS", "CAVE", "WATER", "ROD", "SCRIPTED" }) do
  local mon = assert(BattleState.newWild(game, route, 5)).enemy.mon
  assert(mon.shiny == nil and not Stats.isShiny(mon.dvs), route .. " escaped provider miss")
end
assert(defaultRngCalls == 5, "ordinary wild routes did not retain one provider roll each")

print("wild_outcome_api_test: OK")
