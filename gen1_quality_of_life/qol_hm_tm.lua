local M = {}

local MOD_ID = "gen1_quality_of_life"
local SCREEN_HMS = "Gen1QolHMs"
local TOWN_MAP_PATCH = "__gen1QolTownMapDispatcherV1"
local ITEM_USE_PATCH = "__gen1QolReusableTmDispatcherV1"
local BAG_ADD_PATCH = "__gen1QolUniqueTmDispatcherV1"
local PC_WITHDRAW_PATCH = "__gen1QolUniqueTmPcWithdrawV1"
local QUANTITY_PATCH = "__gen1QolUniqueTmQuantityV1"
local BUYING_TM = "__gen1QolBuyingUniqueTm"

local HM_ORDER = { "CUT", "FLY", "SURF", "STRENGTH", "FLASH" }
local HM_IDS = {
  CUT = "HM_CUT", FLY = "HM_FLY", SURF = "HM_SURF",
  STRENGTH = "HM_STRENGTH", FLASH = "HM_FLASH",
}
local HM_FLAGS = {
  CUT = "EVENT_GOT_HM01", FLY = "EVENT_GOT_HM02",
  SURF = "EVENT_GOT_HM03", STRENGTH = "EVENT_GOT_HM04",
  FLASH = "EVENT_GOT_HM05",
}

local function savedOption(save, key, default)
  local buckets = save and save.options and save.options.modOptions
  local own = buckets and buckets[MOD_ID]
  local value = own and own[key]
  if value == nil then return default end
  return value == true
end

local function machineDef(data, id)
  local def = data and data.items and data.items[id]
  return def and def.machine, def
end

local function isTM(data, id)
  local machine = machineDef(data, id)
  return machine and machine.kind == "TM"
end

local function ownsTM(save, id)
  return (tonumber(save and save.inventory and save.inventory[id]) or 0) > 0
    or (tonumber(save and save.pcItems and save.pcItems[id]) or 0) > 0
end

local function hmIdFor(data, moveId)
  local canonical = HM_IDS[moveId]
  local machine = canonical and machineDef(data, canonical)
  if machine and machine.kind == "HM" and machine.move == moveId then
    return canonical
  end
  for id, def in pairs(data and data.items or {}) do
    if def.machine and def.machine.kind == "HM" and def.machine.move == moveId then
      return id
    end
  end
end

local function hasHMData(save, data, moveId)
  local id = hmIdFor(data, moveId)
  if not id then return false end
  if (tonumber(save and save.inventory and save.inventory[id]) or 0) > 0 then
    return true
  end
  if (tonumber(save and save.pcItems and save.pcItems[id]) or 0) > 0 then
    return true
  end
  return save and save.flags and save.flags[HM_FLAGS[moveId]] == true or false
end

local function selectedFlyMap(screen)
  local game = screen and screen.game
  local loc = screen and screen.locs and screen.locs[screen.sel]
  if not game or not loc then return nil end
  local field = game.data and game.data.field or {}
  local visited = game.save and game.save.visited or {}
  local Map = require("src.world.Map")
  for _, mapId in ipairs(field.flyOrder or {}) do
    local def = game.data.maps and game.data.maps[mapId]
    if screen.byMap and screen.byMap[mapId] == loc and visited[mapId]
        and field.flyWarps and field.flyWarps[mapId]
        and def and Map.isFlyTown(def) then
      return mapId
    end
  end
end

local function normalizeTMs(game)
  local save, data = game and game.save, game and game.data
  if not save or not data or not savedOption(save, "reusableTMs", true) then return end
  save.inventory, save.pcItems = save.inventory or {}, save.pcItems or {}
  for id in pairs(data.items or {}) do
    if isTM(data, id) then
      local bag = tonumber(save.inventory[id]) or 0
      local pc = tonumber(save.pcItems[id]) or 0
      if bag > 0 then
        save.inventory[id] = 1
        save.pcItems[id] = nil
      elseif pc > 0 then
        save.pcItems[id] = 1
      end
    end
  end
end

function M.install(mod, options)
  local service = { actions = {}, screenId = SCREEN_HMS }

  function service.hasHM(game, moveId)
    return options.value(game, "fieldHMs")
      and hasHMData(game and game.save, game and game.data, moveId)
  end

  function service.obtained(game)
    local out = {}
    for _, moveId in ipairs(HM_ORDER) do
      if service.hasHM(game, moveId) then out[#out + 1] = moveId end
    end
    return out
  end

  function service.ask(game, moveId, onYes)
    local TextBox = require("src.render.TextBox")
    game.stack:push(TextBox.new(game, "Use " .. moveId .. "?", nil, {
      choice = function(yes) if yes and onYes then onYes() end end,
    }))
    return true
  end

  function service.message(game, text)
    local TextBox = require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text))
  end

  function service.setAction(moveId, fn) service.actions[moveId] = fn end
  function service.use(game, moveId, source)
    local action = service.actions[moveId]
    if action then return action(game, source) end
    return false
  end

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local vanilla = next(moveId, ctx)
    if vanilla then return vanilla end
    if not savedOption(ctx and ctx.save, "fieldHMs", true)
        or not hasHMData(ctx and ctx.save, ctx and ctx.data, moveId) then
      return nil
    end
    -- Native Cut/Surf/Strength continuations use the returned mon only for
    -- their conventional message and surfing-Pikachu pose.
    return ctx.save.party and ctx.save.party[1] or nil
  end, 100)

  mod.content.screens:register(SCREEN_HMS, { new = function(game)
    local items = {}
    for _, moveId in ipairs(service.obtained(game)) do
      items[#items + 1] = {
        label = moveId,
        onSelect = function() service.use(game, moveId, "menu") end,
      }
    end
    local reopen = function() mod.ui.push(game, "StartMenu") end
    items[#items + 1] = { label = "CANCEL", onSelect = reopen }
    return mod.ui.Menu.new(game, items, {
      tx = 8, ty = 0, tw = 12, maxVisible = 7, onCancel = reopen,
    })
  end })

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" or #service.obtained(game) == 0 then return out end
    return mod.ui.insertBefore(out, "ITEM", {
      id = "gen1_qol_hms", label = "HMs",
      onSelect = function() mod.ui.push(game, SCREEN_HMS) end,
    })
  end, 100)

  -- When possession-based HMs own the feature, remove taught-HM shortcuts
  -- from individual Pokemon submenus so every activation follows the same
  -- confirmation path. Non-HM field moves remain untouched.
  local hmActions = { cut = true, fly = true, surf = true,
    strength = true, flash = true }
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or not options.value(game, "fieldHMs") then return out end
    local filtered = {}
    for _, item in ipairs(out) do
      if not hmActions[item.action] then filtered[#filtered + 1] = item end
    end
    return filtered
  end, 100)

  -- Plain Town Map viewers gain A-to-Fly on visited city cells. Fly-mode and
  -- Pokedex nest-mode screens keep their native update paths.
  local TownMap = require("src.ui.TownMap")
  local townDispatcher = rawget(TownMap, TOWN_MAP_PATCH)
  if not townDispatcher then
    townDispatcher = { original = TownMap.update }
    TownMap[TOWN_MAP_PATCH] = townDispatcher
    TownMap.update = function(screen, ...)
      local game = screen and screen.game
      local exports = game and game.mods and game.mods.exports
        and game.mods.exports[MOD_ID]
      local handler = exports and exports._townMapHmUpdate
      if handler and handler(screen, ...) then return end
      return townDispatcher.original(screen, ...)
    end
  end
  mod.exports._townMapHmUpdate = function(screen)
    local game = screen and screen.game
    if not game or screen.fly or screen.nestSpecies
        or not service.hasHM(game, "FLY")
        or not game.input:wasPressed("a") then return false end
    local mapId = selectedFlyMap(screen)
    if not mapId then return false end
    service.ask(game, "FLY", function()
      if game.stack:top() == screen then game.stack:pop() end
      local ow = game.overworld
      if ow then ow:flyTo(mapId) end
    end)
    return true
  end

  -- The native Bag already preserves HMs. Convert successful TM teaching to
  -- the same kept-item result without copying the teaching flow.
  local ItemEffects = require("src.inventory.ItemEffects")
  if not rawget(ItemEffects, ITEM_USE_PATCH) then
    local originalUse = ItemEffects.use
    ItemEffects.use = function(data, save, itemId, ...)
      local packed = { n = 0 }
      local function pack(...)
        packed.n = select("#", ...)
        for i = 1, packed.n do packed[i] = select(i, ...) end
      end
      pack(originalUse(data, save, itemId, ...))
      if packed[1] == "learn" and savedOption(save, "reusableTMs", true)
          and isTM(data, itemId) then
        packed[1] = "learnkept"
      end
      return (table.unpack or unpack)(packed, 1, packed.n)
    end
    ItemEffects[ITEM_USE_PATCH] = true
  end

  -- All normal pickups, shops, scripts and Game Corner prizes converge on
  -- Bag.add. Reject a second TM across both Bag and PC storage.
  local Bag = require("src.inventory.Bag")
  if not rawget(Bag, BAG_ADD_PATCH) then
    local originalAdd = Bag.add
    Bag.add = function(save, id, qty, data)
      data = data or require("src.core.Data")
      if savedOption(save, "reusableTMs", true) and isTM(data, id) then
        if (tonumber(save.inventory and save.inventory[id]) or 0) > 0
            or (tonumber(save.pcItems and save.pcItems[id]) or 0) > 0
            or (tonumber(qty) or 1) ~= 1 then
          return false, "duplicate_tm"
        end
      end
      return originalAdd(save, id, qty, data)
    end
    Bag[BAG_ADD_PATCH] = true
  end

  -- PlayerPC normally calls Bag.add before removing the source PC stack.
  -- That ordering correctly looks like a duplicate to the global guard, so
  -- specialize only the WITHDRAW ITEM list: move the one reusable TM as a
  -- transaction while keeping every other PC item on its native path.
  local ListMenu = require("src.ui.ListMenu")
  if not rawget(ListMenu, PC_WITHDRAW_PATCH) then
    local originalNew = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      if opts and type(opts.onChoose) == "function" then
        local originalChoose = opts.onChoose
        opts.onChoose = function(item, list)
          local id = item and item.value
          if title == "PRIZES (COINS)" and type(id) == "table" then id = id.item end
          if id and savedOption(game.save, "reusableTMs", true)
              and isTM(game.data, id) and (title == "BUY" or title == "PRIZES (COINS)") then
            if ownsTM(game.save, id) then
              list.footer = "You already own\nthat TM."
              return
            end
            if title == "BUY" then
              game[BUYING_TM] = true
              local result = originalChoose(item, list)
              game[BUYING_TM] = nil
              return result
            end
          end
          if title == "WITHDRAW ITEM" and id
              and savedOption(game.save, "reusableTMs", true)
              and isTM(game.data, id)
              and (tonumber(game.save.pcItems and game.save.pcItems[id]) or 0) > 0 then
            if (tonumber(game.save.inventory and game.save.inventory[id]) or 0) > 0 then
              list.footer = "You already own\nthat TM."
              return
            end
            local count = game.save.pcItems[id]
            game.save.pcItems[id] = nil
            if not Bag.add(game.save, id, 1, game.data) then
              game.save.pcItems[id] = count
              list.footer = "You can't carry\nany more items."
              return
            end
            list:removeCurrent()
            require("src.core.Sound").play(game.data, "Withdraw_Deposit")
            list.footer = "Withdrew the TM."
            return
          end
          return originalChoose(item, list)
        end
      end
      return originalNew(game, title, items, opts)
    end
    ListMenu[PC_WITHDRAW_PATCH] = true
  end


  -- Mart quantity selection is synchronous with the BUY row callback. Cap a
  -- newly selected reusable TM at one instead of inviting an invalid stack.
  local QuantityBox = require("src.ui.QuantityBox")
  if not rawget(QuantityBox, QUANTITY_PATCH) then
    local originalQuantityNew = QuantityBox.new
    QuantityBox.new = function(game, opts)
      if game and game[BUYING_TM] and opts then
        local copy = {}
        for key, value in pairs(opts) do copy[key] = value end
        copy.max = 1
        opts = copy
      end
      return originalQuantityNew(game, opts)
    end
    QuantityBox[QUANTITY_PATCH] = true
  end

  mod.events:on("game.ready", function(event) normalizeTMs(event and event.game) end, 90)
  mod.events:on("save.loaded", function()
    normalizeTMs(mod.world and mod.world.game)
  end, 90)

  service.normalizeTMs = normalizeTMs
  service.isTM = isTM
  service.hmIdFor = hmIdFor
  mod.exports.hasHM = service.hasHM
  mod.exports.obtainedHMs = service.obtained
  return service
end

return M
