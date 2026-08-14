-- Widescreen Grid Box
-- Version 0.1.0-alpha.1
-- Gen 1 storage semantics for Widescreen Pokemon Storage Provider API v1.

local OWNER = "gen1_widescreen_grid_box"
local API_VERSION = 1
local PATCH_KEY = "__gen1_widescreen_grid_box_dispatch_v1"

return function(mod)
  local compile = loadstring or load
  local function loadModule(path)
    local source, readError = mod:read(path)
    if not source then error("cannot read " .. path .. ": " .. tostring(readError), 0) end
    local chunk, compileError = compile(source,
      "@" .. tostring(mod.path or OWNER) .. "/" .. path)
    if not chunk then error("cannot compile " .. path .. ": " .. tostring(compileError), 0) end
    return chunk()
  end

  local Core = loadModule("storage_core.lua")
  local GridState = loadModule("grid_state.lua")
  local registered = false

  local function logOnce(message)
    message = tostring(message)
    mod.__gridBoxLogs = mod.__gridBoxLogs or {}
    if mod.__gridBoxLogs[message] then return end
    mod.__gridBoxLogs[message] = true
    if mod.log then mod.log:error("Widescreen Grid Box: %s", message) end
  end

  local function widescreenExports()
    local widescreen = type(mod.find) == "function"
      and mod:find("gen1_widescreen_ui") or nil
    return widescreen and widescreen.exports or nil
  end

  local function ensureProvider()
    local exports = widescreenExports()
    if type(exports) ~= "table"
        or exports.pokemonStorageProviderApiVersion ~= API_VERSION
        or type(exports.registerPokemonStorageProvider) ~= "function" then
      registered = false
      logOnce("requires Gen1 Widescreen UI Pokemon Storage Provider API v1")
      return false
    end
    if registered and type(exports.activePokemonStorageProviderOwner) == "function"
        and exports.activePokemonStorageProviderOwner() == OWNER then return true end
    local ok, reason = exports.registerPokemonStorageProvider({
      owner = OWNER, apiVersion = API_VERSION,
      match = function(state)
        return type(state) == "table" and state.isGridBox == true
      end,
      snapshot = GridState.snapshot,
      actions = GridState.Actions,
    })
    if not ok then
      registered = false
      logOnce("provider registration failed: " .. tostring(reason))
      return false
    end
    registered = true
    return true
  end

  local function dependencies()
    return {
      Core = Core,
      Menu = require("src.ui.Menu"),
      Stats = require("src.pokemon.Stats"),
      Follower = require("src.world.PikachuFollower"),
      Screens = require("src.ui.Screens"),
      Sound = require("src.core.Sound"),
      TextBox = require("src.render.TextBox"),
    }
  end

  local function open(game, mode)
    if not ensureProvider() then return false end
    local state = GridState.new(game, mode, dependencies())
    game.stack:push(state)
    return true
  end

  local function labelOf(item)
    return tostring(item and item.label or ""):upper()
  end

  local function findNative(items, word)
    for _, item in ipairs(items or {}) do
      if labelOf(item):find(word, 1, true) then return item end
    end
  end

  local function decorateRoot(game, menu)
    if type(menu) ~= "table" then return menu end
    local native = menu.items or {}
    local changeBox = findNative(native, "CHANGE BOX")
    local printBox = findNative(native, "PRINT BOX")
    local exit = findNative(native, "SEE YA")
    if not changeBox or not exit then
      logOnce("native BoxMenu rows are incompatible; leaving storage unchanged")
      return menu
    end
    local items = {
      { label = "WITHDRAW POKEMON", keepOpen = true,
        onSelect = function() open(game, "withdraw") end },
      { label = "DEPOSIT POKEMON", keepOpen = true,
        onSelect = function() open(game, "deposit") end },
      { label = "MOVE POKEMON", keepOpen = true,
        onSelect = function() open(game, "move") end },
      changeBox,
    }
    if printBox then items[#items + 1] = printBox end
    items[#items + 1] = exit
    menu.items = items
    menu.index = math.max(1, math.min(#items, tonumber(menu.index) or 1))
    if menu.th then menu.th = #items * 2 + 2 end
    menu.__gridBoxRoot = true
    return menu
  end

  local function install(game)
    if not game or not ensureProvider() then return false end
    local ok, BoxMenu = pcall(require, "src.ui.BoxMenu")
    if not ok or type(BoxMenu) ~= "table" or type(BoxMenu.new) ~= "function" then
      logOnce("src.ui.BoxMenu is unavailable")
      return false
    end
    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = { baseNew = BoxMenu.new }
      rawset(_G, PATCH_KEY, dispatch)
      BoxMenu.new = function(currentGame, ...)
        local root = dispatch.baseNew(currentGame, ...)
        return dispatch.decorate and dispatch.decorate(currentGame, root) or root
      end
    end
    dispatch.decorate = function(currentGame, root)
      return decorateRoot(currentGame, root)
    end
    return true
  end

  mod.exports.apiVersion = 1
  mod.exports.core = Core
  mod.exports.state = GridState
  mod.exports.actions = GridState.Actions
  mod.exports.snapshot = GridState.snapshot
  mod.exports.ensureProvider = ensureProvider
  mod.exports.open = open

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mods.loaded", function() ensureProvider() end)
    mod.events:on("game.ready", function(event)
      if install(event and event.game) and mod.log then
        mod.log:info("Widescreen Grid Box alpha 1 installed")
      end
    end)
  end
  ensureProvider()
end
