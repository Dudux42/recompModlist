local M = {}

local STOCK_BALLS = {
  POKE_BALL = { randMax = 255, hpFactor = 12 },
  GREAT_BALL = { randMax = 200, hpFactor = 8 },
  ULTRA_BALL = { randMax = 150, hpFactor = 12 },
  SAFARI_BALL = { randMax = 150, hpFactor = 12 },
}

local STOCK_STATUS = { SLP = 25, FRZ = 25, PSN = 12, BRN = 12, PAR = 12 }

local function clamp(value, low, high)
  value = tonumber(value) or low
  if value < low then return low end
  if value > high then return high end
  return value
end

local function copyWithHpFactor(def, factor)
  local out = {}
  for key, value in pairs(def or {}) do out[key] = value end
  out.hpFactor = factor
  return out
end

local function statusBonus(battle, status)
  if not status then return 0 end
  local record = battle and battle.data and battle.data.statuses
    and battle.data.statuses[status]
  if record and record.catchBonus ~= nil then
    return math.max(0, tonumber(record.catchBonus) or 0)
  end
  return STOCK_STATUS[status] or 0
end

local function ballDef(battle, id, corrected)
  local def
  if battle and type(battle.ballDef) == "function" then
    local ok, found = pcall(battle.ballDef, battle, id)
    if ok then def = found end
  end
  def = def or (battle and battle.data and battle.data.balls
    and battle.data.balls[id]) or STOCK_BALLS[id]
  if corrected and id == "ULTRA_BALL" and def and not def.attempt then
    return copyWithHpFactor(def, 8)
  end
  return def
end

-- Exact enumeration of Gen1Recomp's stock two-roll capture check.
local function probability(battle, id, corrected)
  local enemy = battle and battle.enemy
  local mon = enemy and enemy.mon
  local targetDef = enemy and (enemy.def or (battle.data and battle.data.pokemon
    and battle.data.pokemon[mon and mon.species]))
  if not mon or not targetDef then return nil end
  local def = ballDef(battle, id, corrected)
  if not def or def.attempt then return nil end
  if def.autoCatch then return 1 end

  local randMax = math.max(0, math.floor(tonumber(def.randMax) or 255))
  -- Stock balls are at most 255.  A third-party record with an enormous
  -- range must not turn a per-frame HUD query into an unbounded loop.
  if randMax > 4095 then return nil end
  local factor = math.max(1, tonumber(def.hpFactor) or 12)
  local rate = battle.safari and battle.safariCatchRate or targetDef.catchRate
  rate = math.max(0, tonumber(rate) or 0)
  local maxHP = math.max(1, tonumber(mon.stats and mon.stats.hp) or 1)
  local hp = clamp(mon.hp, 1, maxHP)
  local hpQuarter = math.max(1, math.floor(hp / 4))
  local hpCheck = math.min(255,
    math.floor(math.floor(maxHP * 255 / factor) / hpQuarter))
  local bonus = statusBonus(battle, mon.status)
  local second = (hpCheck + 1) / 256
  local successes = 0
  for first = 0, randMax do
    local adjusted = first - bonus
    if adjusted < 0 then
      successes = successes + 1
    elseif adjusted <= rate then
      successes = successes + second
    end
  end
  return clamp(successes / (randMax + 1), 0, 1)
end

local BALL_RED = {
  "..KKKK..", ".KRRRRK.", "KRRRRRRK", "KKKWWKKK",
  "KWWWWWWK", ".KWWWWK.", "..KKKK..",
}
local COLORS = {
  K={0,0,0,1}, R={0.9,0.1,0.1,1}, W={1,1,1,1},
}

local function drawBall(g, rows, x, y, scale, mark)
  x, y, scale = math.floor(x), math.floor(y), scale or 1
  for py, row in ipairs(rows) do
    for px = 1, #row do
      local color = COLORS[row:sub(px, px)]
      if color then
        local dx, dy = x + (px - 1) * scale, y + (py - 1) * scale
        g.setColor(color[1], color[2], color[3], color[4])
        g.rectangle("fill", dx, dy, scale, scale)
        if mark then mark(dx, dy, scale, scale) end
      end
    end
  end
end

local function hudVisible(battle, context)
  return battle and battle.enemy and not battle.showEnemyTrainer
    and not battle.enemySendingOut and not battle.introBalls
    and not battle.enemy.fainted and not context.intro
    and (not battle.growInScale or not battle:growInScale(battle.enemy))
end

local function isCatchable(battle)
  return battle and not battle.demo and not battle.ghost
    and (battle.safari or battle.kind == "wild")
end

function M.install(mod, options, overlay)
  local PaletteFX = require("src.render.PaletteFX")
  local widescreenProviderActive = false
  local unpackFn = table.unpack or unpack
  local function pack(...) return { n = select("#", ...), ... } end
  local function correctedAttempt(nextFn, id, mon, targetDef, opts)
    local battle = opts and opts.battle
    local def = ballDef(battle, id, false)
    if not def or def.attempt then return nextFn(id, mon, targetDef, opts) end
    local old = def.hpFactor
    def.hpFactor = 8
    local packed = pack(pcall(nextFn, id, mon, targetDef, opts))
    def.hpFactor = old
    if not packed[1] then error(packed[2], 0) end
    return unpackFn(packed, 2, packed.n)
  end

  mod.hooks:wrap("catch.rate", function(next, id, mon, targetDef, opts)
    if id == "ULTRA_BALL" then
      return correctedAttempt(next, id, mon, targetDef, opts)
    end
    return next(id, mon, targetDef, opts)
  end, 100)

  local function drawWidescreenHelper(battle, context)
    if not hudVisible(battle, { intro = false }) or not isCatchable(battle) then return end
    local enemy = context.layout and context.layout.enemy
    if not enemy then return end
    local g, fonts = love.graphics, context.fonts
    if options.value(battle.game, "ownedIndicator") then
      local dex = battle.game and battle.game.save and battle.game.save.pokedex
      local species = battle.enemy and battle.enemy.mon and battle.enemy.mon.species
      if dex and dex.owned and dex.owned[species] == true then
        drawBall(g, BALL_RED, enemy.nameX + enemy.nameWidth + 5,
          enemy.nameY + 2, 1)
      end
    end
    if not options.value(battle.game, "catchOdds") then return end

    local function pc(id)
      local p = probability(battle, id, true)
      return p and tostring(math.floor(p * 100 + 0.5)) .. "%" or "--"
    end
    local text = battle.safari and ("S " .. pc("SAFARI_BALL"))
      or ("P " .. pc("POKE_BALL") .. "    G " .. pc("GREAT_BALL")
        .. "    U " .. pc("ULTRA_BALL"))
    local footerY = enemy.y + enemy.h - 2
    context.drawPanel(enemy.x, footerY, enemy.w, 30)
    g.setFont(fonts.tiny)
    local ink = context.colors.ink
    g.setColor(ink[1], ink[2], ink[3], ink[4])
    g.print(text, enemy.x + 9, footerY + 9)
  end

  local function registerWidescreenProvider()
    if widescreenProviderActive or type(mod.find) ~= "function" then return end
    local handle = mod.find("gen1_widescreen_ui")
    local exports = handle and handle.exports
    if not exports or exports.battleHudOverlayApiVersion ~= 1
        or type(exports.registerBattleHudOverlay) ~= "function" then return end
    local ok, result = pcall(exports.registerBattleHudOverlay, {
      owner = "gen1_quality_of_life", apiVersion = 1,
      draw = drawWidescreenHelper,
    })
    if ok and result then
      widescreenProviderActive = true
      mod.log:info("anchored catch display to the Widescreen enemy HUD")
    elseif not ok then
      mod.log:error("could not register Widescreen catch display: %s", tostring(result))
    end
  end
  registerWidescreenProvider()
  mod.events:once("mods.loaded", registerWidescreenProvider, -90)

  overlay:add({
    id = "owned marker and catch odds",
    start = function(event)
      local battle = event.battle
      local dex = battle.game and battle.game.save and battle.game.save.pokedex
      return { ownedAtStart = dex and dex.owned and dex.owned[event.species] == true }
    end,
    draw = function(battle, state, context)
      if not hudVisible(battle, context) or not isCatchable(battle) then return end
      if widescreenProviderActive then return end
      local g = love.graphics
      local voxel = context.voxel
      local scale = voxel and voxel.scale or 1
      local ox, oy = 0, 0
      if voxel then
        g.setCanvas(voxel.canvas)
        ox, oy = voxel.lx, voxel.ly
      end
      if g.origin then g.origin() end
      if g.setShader then g.setShader() end

      if state.ownedAtStart and options.value(battle.game, "ownedIndicator") then
        local name = battle.enemy.name or ""
        local width = mod.ui.Font.width(name)
        local x, y
        if context.wide then
          x, y = 8 + width, 8
          if x + 8 > 88 then x = 130 end
        else
          local glyphs = #mod.ui.Font.split(name)
          local nameX = 8 + (glyphs <= 2 and 16 or glyphs <= 4 and 8 or 0)
          x, y = nameX + width, 0
        end
        x = ox + (x + context.sx + context.hudShake) * scale
        y = oy + (y + context.sy) * scale
        local mark = not voxel and PaletteFX.markTrueColor or nil
        drawBall(g, BALL_RED, x, y, scale, mark)
      end

      if options.value(battle.game, "catchOdds") then
        local function pc(id)
          local p = probability(battle, id, true)
          return p and tostring(math.floor(p * 100 + 0.5)) or "--"
        end
        local text = battle.safari and ("S" .. pc("SAFARI_BALL"))
          or ("P" .. pc("POKE_BALL") .. " G" .. pc("GREAT_BALL")
            .. " U" .. pc("ULTRA_BALL"))
        g.setColor(0, 0, 0, 1)
        mod.ui.Font.draw(text, ox + 8 * scale, oy + 33 * scale)
      end
    end,
  })

  mod.exports.catchProbability = probability
  mod.exports.effectiveBallDef = ballDef
end

return M
