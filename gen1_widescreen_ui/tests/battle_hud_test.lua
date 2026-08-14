local printed = {}
local rectangles = 0
local rectangleCalls = {}
local windowWidth, windowHeight = 1920, 1080
local shinyStarImage = {
  getDimensions = function() return 32, 31 end,
  setFilter = function() end,
}
local shinyStarDraws = {}
local trainerBackImage = {
  getDimensions = function() return 80, 96 end,
  setFilter = function() end,
}
local trainerBackDraws = {}
local trainerThrowImage = {
  getDimensions = function() return 64, 64 end,
  setFilter = function() end,
}
local trainerThrowDraws = 0
local trainerThrowLast

local function mockFont(size)
  return {
    setFilter = function() end,
    getWidth = function(_, text) return #tostring(text or "") * math.max(4, size / 2) end,
    getHeight = function() return size end,
  }
end

love = {
  timer = { getTime = function() return 1 end },
  graphics = {
    newFont = function(_, size) return mockFont(size or 12) end,
    setColor = function() end,
    setFont = function() end,
    getDimensions = function() return windowWidth, windowHeight end,
    rectangle = function(mode, x, y, w, h)
      rectangles = rectangles + 1
      rectangleCalls[#rectangleCalls + 1] = { mode, x, y, w, h }
    end,
    circle = function() rectangles = rectangles + 1 end,
    line = function() rectangles = rectangles + 1 end,
    setLineWidth = function() end,
    polygon = function() rectangles = rectangles + 1 end,
    print = function(text) printed[#printed + 1] = tostring(text) end,
    push = function() end,
    pop = function() end,
    translate = function() end,
    scale = function() end,
    draw = function(image, x, y)
      if image == shinyStarImage then
        shinyStarDraws[#shinyStarDraws + 1] = { x = x, y = y }
      end
      if image == trainerBackImage then
        trainerBackDraws[#trainerBackDraws + 1] = { x = x, y = y }
      end
      if image == trainerThrowImage then
        trainerThrowDraws = trainerThrowDraws + 1
        trainerThrowLast = { x = x, y = y }
      end
    end,
    newQuad = function() return {} end,
  },
}

local StartMenu = {}
function StartMenu.new(game)
  return { game = game, items = {}, index = 1, draw = function() end }
end
package.preload["src.ui.StartMenu"] = function() return StartMenu end

local PartyMenu = { drawIcon = function() return false end }
function PartyMenu.new(game, opts)
  return { game = game, party = opts and opts.party or {}, index = 1,
           draw = function() end, bottomMessage = function() return "" end }
end
package.preload["src.ui.PartyMenu"] = function() return PartyMenu end

local SummaryMenu = { isOpaque = true }
function SummaryMenu.new(game, mon)
  return { game = game, mon = mon, page = 1, draw = function() end }
end
package.preload["src.ui.SummaryMenu"] = function() return SummaryMenu end

package.preload["src.pokemon.Sprites"] = function()
  return { path = function() return nil end }
end
package.preload["src.render.Assets"] = function()
  return {
    image = function() return nil end,
    register = function() end,
  }
end
package.preload["src.render.PaletteFX"] = function() return {} end
package.preload["src.pokemon.Stats"] = function()
  return {
    isShiny = function() return false end,
    calc = function(_, level)
      return {
        hp = level * 2 + 14,
        attack = level + 1,
        defense = level + 5,
        speed = level * 2 - 4,
        special = level * 2 - 8,
      }
    end,
  }
end
package.preload["src.render.Font"] = function()
  return { split = function() return {} end }
end
package.preload["src.render.TextBox"] = function()
  return { draw = function() end }
end
package.preload["src.ui.ChoiceBox"] = function()
  return { draw = function() end }
end
package.preload["src.pokemon.Growth"] = function()
  return { expForLevel = function(_, level) return level * level * level end }
end

local nativeHUD, nativeText, nativeStatBoxDraws, statBoxUpdates = 0, 0, 0, 0
local pressed = {}
local StatBox = {}
StatBox.__index = StatBox
function StatBox.new(game, mon, onDone)
  return setmetatable({ game = game, mon = mon, onDone = onDone }, StatBox)
end
function StatBox:update()
  statBoxUpdates = statBoxUpdates + 1
end
function StatBox:draw()
  nativeStatBoxDraws = nativeStatBoxDraws + 1
end
local BattleState
BattleState = {
  wideLayout = function() return true end,
  drawHUDs = function() nativeHUD = nativeHUD + 1 end,
  drawTextArea = function() nativeText = nativeText + 1 end,
  update = function(self)
    local input = self.game and self.game.input
    local index = self.phase == "mimicSelect" and "mimicIndex" or "moveIndex"
    if input and input:wasPressed("up") then self[index] = math.max(1, self[index] - 1) end
    if input and input:wasPressed("down") then self[index] = self[index] + 1 end
    if input and input:wasPressed("left") then self[index] = math.max(1, self[index] - 1) end
    if input and input:wasPressed("right") then self[index] = self[index] + 1 end
  end,
  updateQueue = function() return false end,
  sayNext = function(self, text)
    self.nextInsert = (self.nextInsert or 0) + 1
    table.insert(self.queue, self.nextInsert, { text = text })
  end,
  awardExp = function(self)
    self.nextInsert = 0
    local levels = require("src.battle.Experience").apply(
      self.data, self.player.mon)
    BattleState.sayNext(self, "PSYDUCK gained 120 EXP. Points!")
    for _, level in ipairs(levels) do
      BattleState.sayNext(self, "PSYDUCK grew to level " .. tostring(level) .. "!")
    end
  end,
  StatBox = StatBox,
}
package.preload["src.battle.BattleState"] = function() return BattleState end
local Experience = {
  apply = function(data, mon)
    mon.level = mon.level + 1
    mon.stats = require("src.pokemon.Stats").calc(
      data.pokemon[mon.species], mon.level, mon.dvs, mon.statExp)
    return { mon.level }, 120
  end,
}
package.preload["src.battle.Experience"] = function() return Experience end

local originalSnapCalls, originalPanelCalls = 0, 0
local overworldBattle = {
  snapHUDs = function() originalSnapCalls = originalSnapCalls + 1; return false end,
  drawHudPanels = function() nativeHUD = nativeHUD + 1 end,
  textures = function()
    return { enemy = { trainer = true, ay = 56 }, player = {} }
  end,
}
local dramaticHud = {
  panel = function() originalPanelCalls = originalPanelCalls + 1; return false end,
}
local dramaticLib = {
  require = function(name)
    if name == "OverworldBattle" then return overworldBattle end
    if name == "BattleHud" then return dramaticHud end
    error("unexpected Dramatic Shape module " .. tostring(name))
  end,
}
local battleArtSnapCalls = 0
local battleArtOverworld = {
  snapHUDs = function() battleArtSnapCalls = battleArtSnapCalls + 1; return false end,
  drawHudPanels = function() nativeHUD = nativeHUD + 1 end,
  textures = function() return { enemy = {}, player = {} } end,
}
local battleArtHud = { panel = function() return false end }
local battleArtLib = {
  require = function(name)
    if name == "OverworldBattle" then return battleArtOverworld end
    if name == "BattleHud" then return battleArtHud end
    error("unexpected Battle Art module " .. tostring(name))
  end,
}

local hooks = {}
local eventHandlers = {}
local enabled = true
local warnings, errors = {}, {}
local mod = {
  options = {
    define = function() end,
    get = function(_, key)
      if key == "battle_hud" then return enabled end
      return false
    end,
  },
  hooks = {
    wrap = function(_, name, fn, priority)
      hooks[name] = fn
      if name == "battle.overlay" then assert(priority == 11000) end
      if name == "render.hud" then assert(priority == 12000) end
    end,
  },
  events = {
    on = function(_, name, fn) eventHandlers[name] = fn end,
  },
  log = {
    warn = function(_, message) warnings[#warnings + 1] = tostring(message) end,
    error = function(_, message) errors[#errors + 1] = tostring(message) end,
  },
  assets = {
    path = function(_, path) return "mods/gen1_widescreen_ui/assets/" .. path end,
    image = function(_, relative)
      if relative == "assets/shiny_star.png" then return shinyStarImage end
      return nil
    end,
  },
  find = function() return nil end,
  exports = {},
}

local init = assert(loadfile("gen1_widescreen_ui/main.lua"))()
init(mod)
assert(hooks["battle.overlay"] and hooks["render.hud"])
assert(mod.exports.battleMoveInspectorApiVersion == 1)
assert(mod.exports.ownsBattleTrainerBack() == true)
enabled = false
assert(mod.exports.ownsBattleTrainerBack() == false)
enabled = true
assert(BattleState:wideLayout() == false,
       "custom HUD did not select its presentation-safe battle surface")
BattleState:drawHUDs()
BattleState:drawTextArea()
assert(nativeHUD == 0 and nativeText == 0, "native HUD was not suppressed")

local moves = {
  { id = "CONFUSION", pp = 20 }, { id = "DISABLE", pp = 19 },
  { id = "TAIL_WHIP", pp = 30 }, { id = "SCRATCH", pp = 35 },
}
local playerMon = {
  species = "PSYDUCK", nickname = "PSYDUCK", level = 22, hp = 41,
  exp = 11000,
  stats = { hp = 58, attack = 23, defense = 27, speed = 40, special = 36 },
  moves = moves,
}
local enemyMon = {
  species = "RATTATA", nickname = "RATTATA", level = 18, hp = 32,
  stats = { hp = 40 },
}
local battle = {
  phase = "menu", menuIndex = 1, moveIndex = 1, frame = 10,
  player = { name = "PSYDUCK", mon = playerMon, curMoves = moves,
             curTypes = { "PSYCHIC_TYPE" } },
  enemy = { name = "RATTATA", mon = enemyMon, curTypes = { "NORMAL" } },
  data = {
    pokemon = { PSYDUCK = { growthRate = "medium" } },
    growth_rates = {},
    moves = {
      CONFUSION = { id = "CONFUSION", name = "CONFUSION", type = "PSYCHIC_TYPE",
        power = 50, accuracy = 100, pp = 25, effect = "CONFUSION_SIDE_EFFECT" },
      DISABLE = { id = "DISABLE", name = "DISABLE", type = "NORMAL",
        power = 0, accuracy = 55, pp = 20, effect = "DISABLE_EFFECT" },
      TAIL_WHIP = { id = "TAIL_WHIP", name = "TAIL WHIP", type = "NORMAL",
        power = 0, accuracy = 100, pp = 30, effect = "DEFENSE_DOWN1_EFFECT" },
      SCRATCH = { id = "SCRATCH", name = "SCRATCH", type = "NORMAL",
        power = 40, accuracy = 100, pp = 35, effect = "NO_ADDITIONAL_EFFECT" },
    },
    type_chart = { matchups = {
      { attacker = "PSYCHIC_TYPE", defender = "NORMAL", multiplier = 10 },
    } },
  },
  growInScale = function() return nil end,
  statusLabel = function(_, value) return value.status end,
}
local game = {
  save = { party = { playerMon }, options = {} },
  stack = { states = { battle } },
  input = { wasPressed = function(_, key) return pressed[key] == true end },
  mods = { exports = {
    DRAMATIC_SHAPE = { lib = dramaticLib },
    BATTLE_ART_VOXEL_FORK = { lib = battleArtLib },
    gen1_character_sprite_replacer = { exports = {
      resolveTrainerBattle = function(id)
        if id == "OPP_SWIMMER" then return { anchorY = 64, frameH = 64 } end
      end,
    } },
  } },
}
function game.stack:top() return self.states[#self.states] end
function game.stack:pop() return table.remove(self.states) end
battle.game = game

assert(eventHandlers["battle.started"], "early battle provider adapter was not registered")
eventHandlers["battle.started"]({ battle = battle })
assert(overworldBattle.snapHUDs(battle, { canvas = {}, scale = 3 }) == true,
       "native HUD capture was not suppressed at battle creation")
battle.showEnemyTrainer = true
battle.trainer = { id = "OPP_SWIMMER" }
local anchoredTextures = overworldBattle.textures(battle)
assert(anchoredTextures.enemy.ay == 64,
       "64px FRLG trainer was not anchored above Dramatic Shape's ground plane")
battle.showEnemyTrainer = false
hooks["battle.overlay"](function() end, battle)
local hudExtensionContext
local worldExtensionContext
local registered, registerReason = mod.exports.registerBattleHudOverlay({
  owner = "qol_test", apiVersion = 1,
  draw = function(seenBattle, context)
    assert(seenBattle == battle)
    hudExtensionContext = context
  end,
})
assert(registered and registerReason == "registered")
registered, registerReason = mod.exports.registerWorldHudOverlay({
  owner = "location_test", apiVersion = 1,
  draw = function(seenGame, context)
    assert(seenGame == game)
    worldExtensionContext = context
  end,
})
assert(registered and registerReason == "registered")
hooks["render.hud"](function() return "downstream" end, game, {})
assert(rectangles > 20, "battle HUD geometry was not rendered")
assert(table.concat(printed, "|"):find("FIGHT", 1, true))
assert(table.concat(printed, "|"):find("PSYDUCK", 1, true))
assert(hudExtensionContext and hudExtensionContext.fonts.small,
       "Battle HUD extension did not receive Widescreen fonts")
assert(hudExtensionContext.layout.enemy.x == 12
       and hudExtensionContext.layout.enemy.y == 10,
       "Battle HUD extension did not receive the enemy panel anchor")
assert(hudExtensionContext.layout.enemy.name == "RATTATA"
       and hudExtensionContext.layout.enemy.nameWidth > 0,
       "Battle HUD extension did not receive rendered-name metrics")
assert(worldExtensionContext and worldExtensionContext.fonts.body
       and worldExtensionContext.viewW == 640
       and worldExtensionContext.viewH == 360
       and type(worldExtensionContext.drawPanel) == "function",
       "World HUD extension did not receive Widescreen style/layout context")
assert(#shinyStarDraws == 0, "normal battle Pokemon drew a shiny star")

-- During the intro, the trainer back belongs to the final HUD rather than a
-- floating Dramatic Shape arena billboard. Its bottom is exactly the message
-- panel's top edge (360-72).
battle.showPlayerBack = true
battle.playerBackPic = trainerBackImage
battle.picImage = function(_, image) return image end
battle.picOffset = function(self, slot)
  return slot == "back" and (self.backOffset or 0) or 0
end
battle.introSlide = 0
battle.phase = "messages"
battle.current = { text = "Wild RATTATA appeared!" }
assert(overworldBattle.textures(battle).player == nil,
       "Dramatic Shape player-trainer billboard was not suppressed")
hooks["render.hud"](function() end, game, {})
assert(#trainerBackDraws == 1 and trainerBackDraws[1].y == 108,
       "player trainer was not grounded on the Widescreen bottom panel")
battle.characterAppearanceThrow = { frames = { trainerThrowImage }, index = 1 }
battle.backOffset = -72
hooks["render.hud"](function() end, game, {})
assert(trainerThrowDraws == 1 and #trainerBackDraws == 1,
       "Widescreen froze the Character Sprite Replacer throw on its static back")
assert(trainerThrowLast and trainerThrowLast.x <= -180,
       "HUD-owned throw did not follow the trainer-back slide off screen")
battle.characterAppearanceThrow = nil
battle.backOffset = nil
battle.showPlayerBack = false
battle.playerBackPic = nil
battle.introSlide = 0
battle.phase = "menu"
battle.current = nil

enemyMon.shiny = true
hooks["render.hud"](function() end, game, {})
assert(#shinyStarDraws == 1 and shinyStarDraws[1].y == 18,
       "shiny enemy did not draw one star beside its battle name")
enemyMon.shiny = false
playerMon.shiny = true
hooks["render.hud"](function() end, game, {})
assert(#shinyStarDraws == 2 and shinyStarDraws[2].y == 220,
       "shiny player did not draw one star beside its battle name")
playerMon.shiny = false
assert(mod.exports.unregisterBattleHudOverlay("qol_test"))
assert(mod.exports.unregisterWorldHudOverlay("location_test"))

-- A 4:3 window exposes a 640x480 battle HUD surface at the same uniform
-- scale. Enemy chrome remains at y=10 while the command chrome reaches the
-- actual bottom edge (480 - 8), instead of being centered with 60-unit gaps.
windowWidth, windowHeight = 1024, 768
rectangleCalls = {}
hooks["render.hud"](function() end, game, {})
local foundEnemyTop, foundCommandBottom = false, false
for _, call in ipairs(rectangleCalls) do
  if call[1] == "fill" and call[2] == 12 and call[3] == 10
      and call[4] == 190 and call[5] == 52 then
    foundEnemyTop = true
  end
  if call[1] == "fill" and call[2] == 250 and call[3] == 408
      and call[4] == 382 and call[5] == 64 then
    foundCommandBottom = true
  end
end
assert(foundEnemyTop, "enemy panel did not anchor to the 4:3 top edge")
assert(foundCommandBottom, "command panel did not anchor to the 4:3 bottom edge")
windowWidth, windowHeight = 1920, 1080
assert(overworldBattle.snapHUDs(battle, { canvas = {}, scale = 3 }) == true,
       "Dramatic Shape native HUD was not suppressed")
assert(battleArtOverworld.snapHUDs(battle, { canvas = {}, scale = 3 }) == true,
       "Battle Art native HUD was not suppressed")

-- Alpha 8.2 grid navigation remains intact under the inspector extension.
battle.phase, battle.moveIndex = "moveSelect", 1
pressed = { right = true }
BattleState.update(battle, 0)
assert(battle.moveIndex == 2, "right did not preserve grid row")
battle.moveIndex, pressed = 3, { up = true }
BattleState.update(battle, 0)
assert(battle.moveIndex == 1, "up did not preserve grid column")
battle.moveIndex, pressed = 2, { down = true }
BattleState.update(battle, 0)
assert(battle.moveIndex == 4, "down did not preserve grid column")
pressed = {}

printed = {}
battle.phase, battle.moveIndex = "moveSelect", 1
hooks["render.hud"](function() end, game, {})
local moveText = table.concat(printed, "|")
assert(moveText:find("CONFUSION", 1, true))
assert(moveText:find("PSYCHIC", 1, true))
assert(moveText:find("PP", 1, true))

printed = {}
battle.phase = "messages"
battle.current = { text = "PSYDUCK used\nCONFUSION!" }
battle.msgWaiting = true
hooks["render.hud"](function() end, game, {})
assert(table.concat(printed, "|"):find("CONFUSION!", 1, true))

printed = {}
battle.current = { text = "PSYDUCK learned\nWATER GUN!" }
hooks["render.hud"](function() end, game, {})
assert(table.concat(printed, "|"):find("WATER GUN!", 1, true),
       "short-moves auto-learn message lost the learned move name")

-- Pixelify Sans has no gender characters. Battle dialogue must render both
-- symbols as vectors instead of passing missing-glyph boxes to the font.
local beforeGenderShapes = rectangles
printed = {}
battle.current = { text = "LASS sent out NIDORAN\226\153\128!\nNIDORAN\226\153\130 appeared!" }
hooks["render.hud"](function() end, game, {})
assert(rectangles > beforeGenderShapes,
       "battle dialogue did not vector-render gender symbols")
assert(not table.concat(printed, "|"):find("\226\153\128", 1, true)
       and not table.concat(printed, "|"):find("\226\153\130", 1, true),
       "battle dialogue passed unsupported gender glyphs to the font")

-- The native level-up modal keeps input ownership, while Widescreen retains
-- the battle message panel and shows exact gains captured around Experience.
local levels = Experience.apply(battle.data, playerMon)
assert(levels[1] == 23)
local statBox = StatBox.new(game, playerMon)
game.stack.states = { battle, statBox }
statBox:draw()
assert(nativeStatBoxDraws == 0, "native level-up stat box was not suppressed")
statBox:update()
assert(statBoxUpdates == 1, "level-up input/update behavior was replaced")
printed, rectangleCalls = {}, {}
battle.phase = "messages"
battle.current = nil
battle.__widescreenUiLastMessage = "PSYDUCK grew to level 23!"
hooks["render.hud"](function() end, game, {})
local levelText = table.concat(printed, "|")
  assert(levelText:find("LEVEL UP", 1, true)
       and levelText:find("ATTACK", 1, true)
       and levelText:find("+2", 1, true)
       and levelText:find("+1", 1, true),
       "responsive level-up panel omitted values or per-stat gains")
  assert(not levelText:find("CONTINUE", 1, true),
       "level-up panel retained the redundant continue footer")
local retainedBottomPanel = false
for _, call in ipairs(rectangleCalls) do
  if call[1] == "fill" and call[2] == 8 and call[3] == 288
      and call[4] == 624 and call[5] == 64 then
    retainedBottomPanel = true
    break
  end
end
assert(retainedBottomPanel, "level-up modal removed the bottom battle panel")
game.stack.states = { battle }

-- Execute the real wrapped award path, not only its rendering aftermath. This
-- catches queue-helper scope/runtime errors that appear only when EXP is paid.
battle.queue, battle.nextInsert = {}, 0
playerMon.level, playerMon.exp = 22, 11000
playerMon.stats = { hp = 58, attack = 23, defense = 27, speed = 40, special = 36 }
BattleState.awardExp(battle)
assert(battle.__widescreenExpHold
       and battle.__widescreenExpHold.mon == playerMon,
       "EXP display was not pinned before the queued animation began")
local foundExpAnimation
for _, item in ipairs(battle.queue) do
  if item.__widescreenExp then foundExpAnimation = item; break end
end
assert(foundExpAnimation, "wrapped EXP award did not queue a bar animation")
battle.queue, battle.current = { foundExpAnimation }, nil
local queueSteps = 0
while (battle.__widescreenExpDisplay
      or (battle.queue[1] and battle.queue[1].__widescreenExp))
    and queueSteps < 200 do
  BattleState.updateQueue(battle)
  queueSteps = queueSteps + 1
end
assert(queueSteps > 1 and queueSteps < 200,
       "EXP animation did not block and then release battle progression")

-- Generic provider contract: one owner, safe same-owner replacement, no calls
-- outside moveSelect, schema validation and fallback on exceptions.
local providerCalls = 0
local function inspectorSnapshot()
  providerCalls = providerCalls + 1
  return {
    schemaVersion = 1, phase = "moveSelect", selectedIndex = 1,
    moveId = "CONFUSION", moveName = "CONFUSION", typeId = "PSYCHIC",
    pp = { current = 20, maximum = 25 },
    power = { kind = "base", value = 50, label = "50" },
    accuracy = { kind = "percent", value = 100, label = "100%" },
    matchup = { factor = 2, label = "SUPER EFFECTIVE", multiplierLabel = "2×" },
    stab = { applies = true, label = "STAB" }, disabled = false,
  }
end
local ok, reason = mod.exports.registerBattleMoveInspector({
  owner = "provider_a", apiVersion = 1, snapshot = inspectorSnapshot,
})
assert(ok and reason == "registered")
local duplicate, duplicateReason = mod.exports.registerBattleMoveInspector({
  owner = "provider_b", apiVersion = 1, snapshot = inspectorSnapshot,
})
assert(not duplicate and duplicateReason:find("provider_a", 1, true))
assert(mod.exports.activeBattleMoveInspectorOwner() == "provider_a")

printed = {}
battle.phase = "menu"
hooks["render.hud"](function() end, game, {})
assert(providerCalls == 0, "provider was called outside moveSelect")
battle.phase = "moveSelect"
hooks["render.hud"](function() end, game, {})
local inspectorText = table.concat(printed, "|")
assert(providerCalls == 1)
assert(inspectorText:find("MOVE INSPECTOR", 1, true))
assert(inspectorText:find("SUPER EFFECTIVE", 1, true))
assert(inspectorText:find("STAB", 1, true))

local beforeErrors = #errors
ok, reason = mod.exports.registerBattleMoveInspector({
  owner = "provider_a", apiVersion = 1,
  snapshot = function() error("test provider failure") end,
})
assert(ok and reason == "replaced")
hooks["render.hud"](function() end, game, {})
hooks["render.hud"](function() end, game, {})
assert(#errors == beforeErrors + 1, "provider error was not deduplicated")

ok = mod.exports.registerBattleMoveInspector({
  owner = "provider_a", apiVersion = 1, snapshot = inspectorSnapshot,
})
assert(ok)
enabled = false
assert(BattleState:wideLayout() == false, "provider did not enforce Battle HUD")
assert(#warnings == 1, "forced Battle HUD warning was not emitted once")
assert(BattleState:wideLayout() == false and #warnings == 1)
assert(mod.exports.unregisterBattleMoveInspector("provider_a"))
assert(mod.exports.activeBattleMoveInspectorOwner() == nil)
assert(BattleState:wideLayout() == true, "unregister did not restore saved HUD setting")

-- Load the real dependent mod against this real Widescreen contract.
enabled = true
local consumerLogs = { info = 0, error = 0 }
local consumerMod = {
  exports = {},
  find = function(_, id)
    assert(id == "gen1_widescreen_ui")
    return { exports = mod.exports }
  end,
  hooks = { wrap = function() error("consumer must not install hooks") end },
  log = {
    info = function() consumerLogs.info = consumerLogs.info + 1 end,
    error = function() consumerLogs.error = consumerLogs.error + 1 end,
  },
}
local inspectorInit = assert(loadfile("gen1_widescreen_move_inspector/main.lua"))()
inspectorInit(consumerMod)
assert(consumerLogs.info == 1 and consumerLogs.error == 0)
assert(mod.exports.activeBattleMoveInspectorOwner()
  == "gen1_widescreen_move_inspector")
printed = {}
battle.phase = "moveSelect"
hooks["render.hud"](function() end, game, {})
local integratedText = table.concat(printed, "|")
assert(integratedText:find("MOVE INSPECTOR", 1, true))
assert(integratedText:find("NEUTRAL", 1, true))
assert(integratedText:find("STAB", 1, true))
assert(mod.exports.unregisterBattleMoveInspector("gen1_widescreen_move_inspector"))

printed = {}
battle.phase = "menu"
battle.safari = { balls = 17 }
hooks["render.hud"](function() end, game, {})
local safariText = table.concat(printed, "|")
assert(safariText:find("SAFARI ZONE", 1, true))
assert(safariText:find("BAIT", 1, true))
battle.safari = nil

enabled = false
assert(BattleState:wideLayout() == true, "native wide setting was not restored")
BattleState:drawHUDs()
BattleState:drawTextArea()
assert(nativeHUD == 1 and nativeText == 1, "native battle drawing was not restored")
assert(overworldBattle.snapHUDs(battle, { canvas = {}, scale = 3 }) == false)
assert(originalSnapCalls == 1)
assert(battleArtOverworld.snapHUDs(battle, { canvas = {}, scale = 3 }) == false)
assert(battleArtSnapCalls == 1)

print("battle_hud_test: OK")
