local options = {
  enabled = true, shiny_rate = "always", recolor = true,
  sparkles = true, debug_ow = false,
}
local optionDefs
local events, hooks, screens = {}, {}, {}
local sounds, rectangles = 0, 0
local dramaticDecisions, dramaticArms, dramaticClears = 0, 0, 0
local dramaticBattleEnabled = false

local dramaticShiny = {
  setting = {},
  decide = function(mon)
    dramaticDecisions = dramaticDecisions + 1
    mon.dvs = { attack = 2, defense = 10, speed = 10, special = 10 }
    mon.shiny = true
    return true
  end,
  isShiny = function(mon) return mon and mon.shiny == true end,
}
local dramaticFx = {
  arm = function() dramaticArms = dramaticArms + 1 end,
  clear = function() dramaticClears = dramaticClears + 1 end,
}
local dramaticOverworldBattle = {
  enabled = function() return dramaticBattleEnabled end,
}
local dramaticLib = {
  require = function(name)
    if name == "Shiny" then return dramaticShiny end
    if name == "ShinyFx" then return dramaticFx end
    if name == "OverworldBattle" then return dramaticOverworldBattle end
    error("unknown Dramatic Shape module: " .. tostring(name))
  end,
}

love = {
  timer = { getTime = function() return 0.25 end },
  math = { random = function(n) return n == 8 and 1 or 1 end },
  graphics = {
    setColor = function() end,
    rectangle = function() rectangles = rectangles + 1 end,
  },
}

local Stats = {
  isShiny = function(dvs)
    return type(dvs) == "table" and dvs.defense == 10 and dvs.speed == 10
      and dvs.special == 10
  end,
  calc = function(_, level)
    return { hp = 20 + level, attack = 10, defense = 10, speed = 10, special = 10 }
  end,
}
package.preload["src.pokemon.Stats"] = function() return Stats end

local Pokemon = {}
function Pokemon.new(_, species, level)
  local natural = species == "NATURAL"
  local mon = {
    species = species, level = level, hp = 20,
    stats = { hp = 20 },
    dvs = natural
      and { attack = 2, defense = 10, speed = 10, special = 10 }
      or { attack = 1, defense = 1, speed = 1, special = 1 },
  }
  dramaticShiny.decide(mon)
  return mon
end
package.preload["src.pokemon.Pokemon"] = function() return Pokemon end

local BattleState = {}
function BattleState.newWild(game, species, level)
  return {
    game = game, data = game.data,
    enemy = { mon = Pokemon.new(game.data, species, level), isPlayer = false },
  }
end
function BattleState:drawPicsLayer() self.drawn = true end
package.preload["src.battle.BattleState"] = function() return BattleState end

package.preload["src.render.PaletteFX"] = function()
  return { wholeNamed = function() return {} end }
end
package.preload["src.pokemon.Sprites"] = function()
  return { path = function() return "battle.png", true end }
end
package.preload["src.render.Assets"] = function()
  return { imageData = nil }
end
package.preload["src.core.Sound"] = function()
  return { play = function() sounds = sounds + 1 end }
end
package.preload["src.ui.OptionRows"] = function()
  return {
    clampScroll = function(_, scroll) return scroll end,
    draw = function() end,
  }
end
package.preload["src.ui.Screens"] = function()
  return { push = function() end }
end

local mod = {
  id = "gen1_shiny_system",
  options = {
    define = function(_, defs) optionDefs = defs end,
    get = function(_, key) return options[key] end,
    set = function(_, key, value) options[key] = value end,
  },
  events = {
    on = function(_, name, fn) events[name] = fn end,
  },
  hooks = {
    wrap = function(_, name, fn) hooks[name] = fn end,
  },
  content = { screens = {
    register = function(_, id, def) screens[id] = def end,
  } },
  read = function(_, name)
    if name == "shiny_palettes.lua" then
      return "return { PSYDUCK = { {80,160,240}, {32,80,180} } }"
    end
  end,
  find = function(_, id)
    if id == "DRAMATIC_SHAPE" then
      return {
        id = id, version = "1.8.0",
        exports = { lib = dramaticLib },
      }
    end
  end,
  exports = {},
  log = { info = function() end, warn = function() end },
}

local init = assert(loadfile("gen1_shiny_system/main.lua"))()
init(mod)

assert(#optionDefs == 5, "expected the five requested shiny options")
assert(type(mod.exports.isShiny) == "function")
assert(type(mod.exports.shouldUseShinyArt) == "function")
assert(type(mod.exports.drawFollowerSparkles) == "function")
assert(mod.exports.wildOutcomeApiVersion == 1)
assert(type(mod.exports.reserveWildOutcome) == "function")
assert(type(mod.exports.wildBattleOptions) == "function")
assert(screens.Gen1ShinySystemOptions, "shiny option submenu registered")
assert(mod.exports.dramaticShapeCompatActive(),
  "Dramatic Shape 1.8 compatibility adapter was not installed")
assert(dramaticShiny.__gen1ShinySystemOwner == mod.id,
  "Dramatic Shape shiny ownership was not recorded")

local game = { data = { pokemon = {
  PSYDUCK = { baseStats = { hp = 50 } },
} } }
local battle = BattleState.newWild(game, "PSYDUCK", 12)
local psyduck = battle.enemy.mon
assert(dramaticDecisions == 0,
  "Dramatic Shape's independent shiny verdict still ran")
assert(psyduck.shiny == true, "100% rate did not flag new wild Pokemon")
assert(Stats.isShiny(psyduck.dvs), "rolled Pokemon lacks valid shiny DVs")
assert(mod.exports.isShiny(psyduck), "export did not recognize rolled shiny")
assert(mod.exports.shouldUseShinyArt(psyduck), "shiny colors should be active")

options.shiny_rate = "off"
local natural = BattleState.newWild(game, "NATURAL", 12).enemy.mon
assert(not Stats.isShiny(natural.dvs),
  "OFF did not clear a natural/competing shiny DV result")
assert(natural.shiny == nil, "OFF retained a competing explicit shiny flag")
options.shiny_rate = "always"

options.recolor = false
assert(not mod.exports.shouldUseShinyArt(psyduck), "SHINY COLORS toggle was ignored")
assert(not dramaticShiny.isShiny(psyduck),
  "Dramatic Shape ignored the authoritative color toggle")
options.recolor = true
assert(dramaticShiny.isShiny(psyduck),
  "Dramatic Shape did not consume authoritative shiny presentation")
options.enabled = false
assert(not mod.exports.isShiny(psyduck), "master toggle was ignored")
options.enabled = true

events["battle.started"]({ battle = battle })
assert(sounds == 1, "shiny battle intro sound was not requested")
hooks["battle.overlay"](function() end, battle)
assert(rectangles > 0, "shiny intro sparkles did not draw")

options.sparkles = false
dramaticFx.arm("enemy")
assert(dramaticArms == 0 and dramaticClears == 1,
  "Dramatic Shape intro was not suppressed by SHINY INTRO")
options.sparkles = true
dramaticFx.arm("enemy")
assert(dramaticArms == 1, "Dramatic Shape intro did not follow SHINY INTRO")

dramaticBattleEnabled = true
local before3DOverlay = rectangles
hooks["battle.overlay"](function() end, battle)
assert(rectangles == before3DOverlay,
  "duplicate flat sparkle was drawn over Dramatic Shape's 3D sparkle")
dramaticBattleEnabled = false

local followerBefore = rectangles
assert(mod.exports.drawFollowerSparkles(psyduck, 10, 20, 32, 32))
assert(rectangles > followerBefore, "follower sparkle integration did not draw")

local rows = hooks["ui.options.rows"](function(_, current) return current end,
  game, {})
assert(rows[#rows].label == "SHINY POKEMON", "OPTIONS entry missing")

local dramaticRateRow = dramaticShiny.setting:row()
assert(dramaticRateRow.label == "SHINY RATE",
  "Dramatic Shape in-game shiny row was not replaced")
assert(dramaticRateRow.value() == "100%",
  "Dramatic Shape in-game row does not show the authoritative rate")
dramaticRateRow.step(game, -1)
assert(options.shiny_rate == "high",
  "Dramatic Shape in-game row did not update the authoritative rate")

events["pokemon.caught"]({ pokemon = psyduck })
assert(psyduck.shiny == true, "caught shiny flag was not retained")

print("shiny_system_test: OK")
