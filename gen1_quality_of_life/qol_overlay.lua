local M = {}

local SNAP_STATE = "__gen1QolHudSnapped"
local SNAP_PATCH = "__gen1QolSnapObserverV1"

local function validShot(shot)
  return type(shot) == "table" and shot.canvas
    and type(shot.scale) == "number" and shot.scale > 0
    and type(shot.pw) == "number" and type(shot.ph) == "number"
    and type(shot.lx) == "number" and type(shot.ly) == "number"
end

local function pushAll(g)
  local ok = pcall(g.push, "all")
  if not ok then g.push() end
end

function M.new(mod, options)
  local layers = {}
  local stateFor = setmetatable({}, { __mode = "k" })
  local service = {}
  local installed = false

  function service:add(layer)
    assert(type(layer) == "table" and type(layer.id) == "string"
      and type(layer.draw) == "function", "invalid overlay layer")
    layers[#layers + 1] = layer
  end

  function service:state(battle)
    local state = stateFor[battle]
    if not state then
      state = { layers = {}, failed = {} }
      stateFor[battle] = state
    end
    return state
  end

  local function observeSnap(modId)
    if type(mod.find) ~= "function" then return end
    local handle = mod.find(modId)
    local lib = handle and handle.exports and handle.exports.lib
    if not lib or type(lib.require) ~= "function" then return end
    local ok, OverworldBattle = pcall(lib.require, "OverworldBattle")
    if not ok or type(OverworldBattle) ~= "table"
        or type(OverworldBattle.snapHUDs) ~= "function"
        or rawget(OverworldBattle, SNAP_PATCH) then return end
    local original = OverworldBattle.snapHUDs
    OverworldBattle.snapHUDs = function(battle, ...)
      if battle then battle[SNAP_STATE] = false end
      local result = original(battle, ...)
      if battle then battle[SNAP_STATE] = result == true end
      return result
    end
    OverworldBattle[SNAP_PATCH] = true
    mod.log:info("enabled optional snapped-HUD adapter for %s", modId)
  end

  local function contextFor(battle)
    local fx = battle.fx or {}
    local sx, sy = fx.shakeX or 0, fx.shakeY or 0
    if sx == 0 and sy == 0 and (fx.shake or 0) > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    local shot = rawget(battle, "dramaticShapeShot")
    if rawget(battle, SNAP_STATE) ~= true or not validShot(shot) then shot = nil end
    return {
      sx = sx,
      sy = sy,
      hudShake = fx.hudShakeX or 0,
      intro = (battle.introSlide or 0) ~= 0,
      wide = battle.wideLayout and battle:wideLayout() or false,
      voxel = shot,
    }
  end

  local function drawLayer(layer, battle, state, context)
    local g = love and love.graphics
    if not g then return true end
    local previousCanvas = g.getCanvas and g.getCanvas() or nil
    pushAll(g)
    local ok, err = pcall(layer.draw, battle, state, context)
    g.pop()
    if g.setCanvas then
      if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
    end
    if not ok then
      mod.log:error("%s overlay disabled for this battle: %s", layer.id, tostring(err))
      return false
    end
    return true
  end

  function service:install()
    if installed then return end
    installed = true

    mod.events:on("battle.started", function(event)
      local battle = event and event.battle
      if not battle then return end
      local state = { layers = {}, failed = {}, species = event.species }
      for i, layer in ipairs(layers) do
        if layer.start then
          local ok, layerState = pcall(layer.start, event)
          if ok then state.layers[i] = layerState or {} else
            state.failed[i] = true
            mod.log:error("%s overlay start failed: %s", layer.id, tostring(layerState))
          end
        else
          state.layers[i] = {}
        end
      end
      stateFor[battle] = state
    end, 100)

    mod.events:on("battle.ended", function(event)
      if event and event.battle then stateFor[event.battle] = nil end
    end, -100)

    mod.events:once("mods.loaded", function()
      observeSnap("DRAMATIC_SHAPE")
      observeSnap("BATTLE_ART_VOXEL_FORK")
    end, -100)

    mod.hooks:wrap("battle.overlay", function(next, battle)
      next(battle)
      if not battle or battle.blankForAskName then return end
      local state = service:state(battle)
      local context = contextFor(battle)
      for i, layer in ipairs(layers) do
        if not state.failed[i] then
          if not drawLayer(layer, battle, state.layers[i] or {}, context) then
            state.failed[i] = true
          end
        end
      end
    end, 200)
  end

  service.validShot = validShot
  service.options = options
  return service
end

return M
