local M = {}

local REPELS = { "REPEL", "SUPER_REPEL", "MAX_REPEL" }

local function firstOwned(game, ids)
  local inventory = game and game.save and game.save.inventory or {}
  for _, id in ipairs(ids) do
    if (tonumber(inventory[id]) or 0) > 0 then return id end
  end
end

local function itemName(game, id)
  local def = game and game.data and game.data.items and game.data.items[id]
  return def and def.name or tostring(id):gsub("_", " ")
end

function M.install(mod, options, hmTm)
  local Map = require("src.world.Map")
  local Strings = require("src.core.Strings")

  local function gameNow() return mod.world and mod.world.game end

  local function useRepel(game, id)
    local ItemEffects = require("src.inventory.ItemEffects")
    local Bag = require("src.inventory.Bag")
    local TextBox = require("src.render.TextBox")
    local result, messages = ItemEffects.use(game.data, game.save, id)
    if result ~= "consumed" then return false end
    Bag.remove(game.save, id, 1)
    if messages and #messages > 0 then
      game.stack:push(TextBox.new(game, table.concat(messages, "\f")))
    end
    return true
  end

  local function useCut(ow)
    if ow:useCutFieldMove() ~= "ok" then return false end
    local fx, fy = ow.player:facingCell()
    if ow.map:isGrassCell(fx, fy) then return false end
    return ow:tryCut(fx, fy) == true
  end

  local function useSurf(ow)
    local fx, fy = ow.player:facingCell()
    ow:trySurf(fx, fy)
  end

  local function useStrength(ow, target)
    if (target and not Map.isPushable(target.def)) or ow.strengthActive then
      return false
    end
    local mon = ow:partyKnows("STRENGTH")
    if not mon then return false end
    local game = gameNow()
    local TextBox = require("src.render.TextBox")
    if target and getmetatable(game.stack:top()) == TextBox then
      game.stack:pop()
      target.frozen = false
    end
    local def = game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or mon.species
    ow.strengthActive = true
    local used = (game.data.text._UsedStrengthText
      or "{RAM:wNameBuffer} used\nSTRENGTH."):gsub("{RAM:wNameBuffer}", name)
    local canMove = (game.data.text._CanMoveBouldersText
      or "{RAM:wNameBuffer} can\nmove boulders."):gsub("{RAM:wNameBuffer}", name)
    game.stack:push(TextBox.new(game, used, function()
      game.stack:push(TextBox.new(game, canMove))
    end, { auto = { sound = function()
      return require("src.core.Sound").playCry(game.data, mon.species)
    end } }))
    return true
  end

  local function useFlash(ow, game)
    local TextBox = require("src.render.TextBox")
    local Transition = require("src.render.Transition")
    game.save.flashLit = true
    game.stack:push(TextBox.new(game,
      game.data.text._FlashLightsAreaText
        or Strings("A blinding FLASH\nlights the area!"), function()
        game.stack:push(Transition.whiteFlash(game, nil, function()
          ow:setDark(false)
        end))
      end))
  end

  local function fieldHMsEnabled(game)
    return hmTm and options.value(game, "fieldHMs") == true
  end

  local function hasHM(game, moveId)
    return fieldHMsEnabled(game) and hmTm.hasHM(game, moveId)
  end

  local function promptCut(game, ow)
    if not hasHM(game, "CUT") or ow:useCutFieldMove() ~= "ok" then return false end
    local fx, fy = ow.player:facingCell()
    if ow.map:isGrassCell(fx, fy) then return false end
    return hmTm.ask(game, "CUT", function() useCut(ow) end)
  end

  local function promptSurf(game, ow)
    if not hasHM(game, "SURF") or not ow:facingIsShoreOrWater()
        or (ow.player and ow.player.surfing)
        or ow:useSurfFieldMove() ~= "ok" then return false end
    return hmTm.ask(game, "SURF", function() useSurf(ow) end)
  end

  local function promptStrength(game, ow, target)
    if not hasHM(game, "STRENGTH") or ow.strengthActive
        or (target and not Map.isPushable(target.def)) then return false end
    if target then
      local TextBox = require("src.render.TextBox")
      if getmetatable(game.stack:top()) == TextBox then
        game.stack:pop()
        target.frozen = false
      end
    end
    return hmTm.ask(game, "STRENGTH", function() useStrength(ow, target) end)
  end

  if hmTm then
    hmTm.setAction("CUT", function(game)
      local ow = mod.world and mod.world:overworld()
      if ow and promptCut(game, ow) then return true end
      hmTm.message(game, "Nothing to CUT!")
      return false
    end)
    hmTm.setAction("SURF", function(game)
      local ow = mod.world and mod.world:overworld()
      if ow and promptSurf(game, ow) then return true end
      hmTm.message(game, "No SURFing here!")
      return false
    end)
    hmTm.setAction("STRENGTH", function(game)
      local ow = mod.world and mod.world:overworld()
      if ow and promptStrength(game, ow, nil) then return true end
      hmTm.message(game, "STRENGTH is already\nactive!")
      return false
    end)
    hmTm.setAction("FLASH", function(game)
      local ow = mod.world and mod.world:overworld()
      if not ow or not ow.dark then
        hmTm.message(game, "No need for FLASH\nhere.")
        return false
      end
      return hmTm.ask(game, "FLASH", function() useFlash(ow, game) end)
    end)
    hmTm.setAction("FLY", function(game)
      local ow = mod.world and mod.world:overworld()
      if not ow then return false end
      return hmTm.ask(game, "FLY", function()
        mod.ui.push(game, "TownMap", { fly = true, onFly = function(mapId)
          ow:flyTo(mapId)
        end })
      end)
    end)
  end

  mod.events:on("world.interacted", function(event)
    local game = gameNow()
    if not game or not event or not fieldHMsEnabled(game) then return end
    local ow = mod.world:overworld()
    if not ow or not game.stack then return end
    if event.kind == "npc" then
      promptStrength(game, ow, event.target)
    elseif event.kind == "none" then
      if game.stack:top() ~= ow then return end
      if ow:facingIsShoreOrWater() and not (ow.player and ow.player.surfing) then
        promptSurf(game, ow)
        return
      end
      promptCut(game, ow)
    end
  end, -100)

  local pendingWearOff = setmetatable({}, { __mode = "k" })
  local pendingFlash = setmetatable({}, { __mode = "k" })
  local function offerPendingFlash()
    local game = gameNow()
    local ow = mod.world and mod.world:overworld()
    if not game or not ow or not pendingFlash[game] or not ow.dark
        or not hasHM(game, "FLASH") or game.stack:top() ~= ow then return end
    pendingFlash[game] = nil
    hmTm.ask(game, "FLASH", function() useFlash(ow, game) end)
  end

  mod.events:on("map.entered", function(event)
    local game = gameNow()
    local ow = mod.world and mod.world:overworld()
    if not game or not ow then return end
    pendingFlash[game] = ow.dark and hasHM(game, "FLASH")
      and (event and event.mapId or true) or nil
    offerPendingFlash()
  end, -90)

  mod.events:on("screen.popped", function() offerPendingFlash() end, -90)

  mod.events:on("world.stepped", function()
    local game = gameNow()
    if not game then return end
    offerPendingFlash()
    pendingWearOff[game] = options.value(game, "repelPrompt")
      and (tonumber(game.save.repelSteps) or 0) == 1 or nil
  end, -100)

  mod.events:on("screen.pushed", function(event)
    local game = gameNow()
    if not game or not pendingWearOff[game]
        or (tonumber(game.save.repelSteps) or 0) ~= 0 then return end
    local TextBox = require("src.render.TextBox")
    local box = event and event.state
    if getmetatable(box) ~= TextBox then return end
    pendingWearOff[game] = nil
    local oldDone = box.onDone
    box.onDone = function(...)
      if oldDone then oldDone(...) end
      local repel = firstOwned(game, REPELS)
      if not repel then return end
      game.stack:push(TextBox.new(game,
        "Use another\n" .. itemName(game, repel) .. "?", nil,
        { choice = function(yes) if yes then useRepel(game, repel) end end }))
    end
  end, -100)

  mod.exports.weakestRepel = function(game) return firstOwned(game, REPELS) end
end

return M
