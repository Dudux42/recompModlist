package.path = "../?.lua;" .. package.path

local callbacks = {}
local providerSpec
local activeOwner
local widescreen = { exports = {
  pokemonStorageProviderApiVersion = 1,
  registerPokemonStorageProvider = function(spec)
    providerSpec = spec; activeOwner = spec.owner; return true, "registered"
  end,
  activePokemonStorageProviderOwner = function() return activeOwner end,
} }

local Menu = {}
function Menu.new(game, items, options)
  return { game = game, items = items or {}, index = 1, th = options and options.th }
end
package.loaded["src.ui.Menu"] = Menu
package.loaded["src.pokemon.Stats"] = { ensure = function(_, mon)
  mon.stats = mon.stats or { hp = 10, attack = 10, defense = 10, speed = 10, special = 10 }
  return mon
end }
package.loaded["src.world.PikachuFollower"] = {
  isFollowingDisabled = function() return false end,
  isStarterPikachu = function() return false end,
  modifyHappiness = function() end,
}
package.loaded["src.ui.Screens"] = { push = function() end }
package.loaded["src.core.Sound"] = { playCry = function() end }
package.loaded["src.render.TextBox"] = { new = function(_, text) return { text = text } end }

local nativeCalls = { change = 0, print = 0 }
local BoxMenu = {}
function BoxMenu.new(game)
  local items = {
    { label = "WITHDRAW <PK><MN>" }, { label = "DEPOSIT <PK><MN>" },
    { label = "RELEASE <PK><MN>" },
    { label = "CHANGE BOX", keepOpen = true,
      onSelect = function() nativeCalls.change = nativeCalls.change + 1 end },
  }
  if game.yellow then items[#items + 1] = { label = "PRINT BOX", keepOpen = true,
    onSelect = function() nativeCalls.print = nativeCalls.print + 1 end } end
  items[#items + 1] = { label = "SEE YA!" }
  return Menu.new(game, items, { th = #items * 2 + 2 })
end
package.loaded["src.ui.BoxMenu"] = BoxMenu

local function newMod(withProvider)
  return {
    path = "grid-test",
    exports = {},
    read = function(_, path)
      local file = assert(io.open("../" .. path, "rb")); local value = file:read("*a")
      file:close(); return value
    end,
    find = function(_, id) return withProvider and id == "gen1_widescreen_ui"
      and widescreen or nil end,
    events = { on = function(_, name, callback) callbacks[name] = callback end },
    log = { error = function() end, info = function() end },
  }
end

local initializer = assert(loadfile("../main.lua"))()
local unavailable = newMod(false)
initializer(unavailable)
local game = { yellow = false }
callbacks["game.ready"]({ game = game })
local untouched = BoxMenu.new(game)
assert(untouched.items[3].label:find("RELEASE", 1, true),
  "provider failure must leave native BoxMenu untouched")

callbacks = {}
local mod = newMod(true)
initializer(mod)
assert(providerSpec and providerSpec.owner == "gen1_widescreen_grid_box"
  and providerSpec.apiVersion == 1, "provider was not registered")
for _, action in ipairs({ "up", "down", "left", "right", "previousBox",
    "nextBox", "select", "back", "selectCell", "selectPartySlot", "selectPopup" }) do
  assert(type(providerSpec.actions[action]) == "function", "missing action " .. action)
end

callbacks["game.ready"]({ game = game })
local root = BoxMenu.new(game)
local labels = {}
for _, item in ipairs(root.items) do labels[#labels + 1] = item.label end
assert(table.concat(labels, "|") ==
  "WITHDRAW POKEMON|DEPOSIT POKEMON|MOVE POKEMON|CHANGE BOX|SEE YA!",
  "Red/Blue root order is wrong or Release remains")
root.items[4].onSelect()
assert(nativeCalls.change == 1, "native CHANGE BOX callback was not preserved")

local yellow = { yellow = true }
local yellowRoot = BoxMenu.new(yellow)
labels = {}; for _, item in ipairs(yellowRoot.items) do labels[#labels + 1] = item.label end
assert(table.concat(labels, "|") ==
  "WITHDRAW POKEMON|DEPOSIT POKEMON|MOVE POKEMON|CHANGE BOX|PRINT BOX|SEE YA!",
  "Yellow root order is wrong")
yellowRoot.items[5].onSelect()
assert(nativeCalls.print == 1, "native PRINT BOX callback was not preserved")

print("main_integration_test: fail-closed registration and native root passed")
