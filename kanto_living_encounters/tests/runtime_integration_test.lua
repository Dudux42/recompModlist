local source = debug.getinfo(1, "S").source:gsub("^@", "")
local MOD = source:match("^(.*)[/\\]tests[/\\][^/\\]+$") or "."

local function load(path)
  local chunk, err = loadfile(MOD .. "/" .. path)
  assert(chunk, err)
  return chunk()
end

local Core = load("kle_core.lua")
local Tables = load("kle_tables.lua")(Core)
local Runtime = load("kle_runtime.lua")(Core, Tables)

local rangedRoll = 0
local unitRolls = {}
love = {
  math = {
    random = function(a, b)
      if a ~= nil then
        if b == nil then return 1 end
        if a == 2 and b == 4 then return 2 end
        rangedRoll = rangedRoll + 1
        return a + ((rangedRoll - 1) % (b - a + 1))
      end
      if #unitRolls > 0 then return table.remove(unitRolls, 1) end
      return 0
    end,
  },
  graphics = {},
}

local Game = {
  data = {
    revision = 7,
    pokemon = { RATTATA = { name = "RATTATA" } },
    maps = {
      ROUTE_1 = { id = "ROUTE_1", tileset = "OVERWORLD", outdoor = true },
      ROUTE_21 = { id = "ROUTE_21", tileset = "OVERWORLD", outdoor = true },
    },
    encounters = {
      ROUTE_1 = { grass = { slots = {
        { species = "RATTATA", level = 2 }, { species = "RATTATA", level = 2 },
        { species = "RATTATA", level = 2 }, { species = "RATTATA", level = 2 },
        { species = "RATTATA", level = 2 }, { species = "RATTATA", level = 2 },
        { species = "RATTATA", level = 2 }, { species = "RATTATA", level = 2 },
        { species = "RATTATA", level = 2 }, { species = "RATTATA", level = 2 },
      } } },
      ROUTE_21 = { water = { slots = {
        { species = "RATTATA", level = 5 }, { species = "RATTATA", level = 5 },
        { species = "RATTATA", level = 5 }, { species = "RATTATA", level = 5 },
        { species = "RATTATA", level = 5 }, { species = "RATTATA", level = 5 },
        { species = "RATTATA", level = 5 }, { species = "RATTATA", level = 5 },
        { species = "RATTATA", level = 5 }, { species = "RATTATA", level = 5 },
      } } },
    },
    field = { constants = { encounterBuckets =
      { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 } } },
    sprites = {},
  },
  save = { party = { { species = "PIKACHU", hp = 20 } }, inventory = {} },
}

local NPC = {}
function NPC.new(_, mapId, def)
  return {
    id = mapId .. ":" .. tostring(def.index), def = def,
    cellX = def.x, cellY = def.y, px = def.x * 16, py = def.y * 16,
    facing = "down", moving = false,
    facePlayer = function(self, player)
      self.facing = player.cellX > self.cellX and "right" or "down"
    end,
  }
end

local Collision = { DELTA = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
} }
function Collision.canMove(map, _, mover, direction)
  local delta = Collision.DELTA[direction]
  local x, y = mover.cellX + delta[1], mover.cellY + delta[2]
  return map:inBounds(x, y) and map:isWalkableCell(x, y)
end
function Collision.occupied(entities, x, y, ignore)
  for _, entity in ipairs(entities or {}) do
    if entity ~= ignore and not entity.passable
      and ((entity.cellX == x and entity.cellY == y)
        or (entity.targetX == x and entity.targetY == y)) then
      return entity
    end
  end
end

local Overworld = {}
Overworld.__index = Overworld
function Overworld:update() end
function Overworld:setMap() end
function Overworld:pushBattle(battle)
  self.battles = self.battles + 1
  self.lastBattle = battle
  Game.stack.current = battle
end
function Overworld:afterBattle() end
function Overworld:onStepComplete()
  self.nativeSteps = (self.nativeSteps or 0) + 1
end
function Overworld:talkTo()
  self.nativeTalks = (self.nativeTalks or 0) + 1
end
function Overworld:drawUI() end

local battleOptionsSeen
local BattleState = {}
function BattleState.newWild(_, species, level, opts)
  battleOptionsSeen = opts
  return {
    enemy = { mon = { species = species, level = level } },
    makeGhost = function(self) self.ghost = true end,
    makeSafari = function(self) self.safari = true end,
  }
end

local Map = {
  ghostBattles = function() return nil end,
  inRegion = function() return false end,
}

local cries = {}
local Sound = {
  playCry = function(data, species)
    assert(data == Game.data, "cry receives live game data")
    cries[#cries + 1] = species
  end,
}

local modules = {
  ["src.core.Game"] = Game,
  ["src.world.NPC"] = NPC,
  ["src.world.Collision"] = Collision,
  ["src.world.OverworldController"] = Overworld,
  ["src.battle.BattleState"] = BattleState,
  ["src.world.Map"] = Map,
  ["src.core.Sound"] = Sound,
}
local nativeRequire = require
require = function(name) return modules[name] or nativeRequire(name) end

local spriteRegistry = { SPRITE_HGSS_OVERWORLD_PROVIDER = {
  id = "SPRITE_HGSS_OVERWORLD_PROVIDER", image = "provider-proxy.png", frames = 6,
} }
Game.data.sprites.SPRITE_HGSS_OVERWORLD_PROVIDER = spriteRegistry.SPRITE_HGSS_OVERWORLD_PROVIDER
local reserved = 0
local outcomes = {
  { shiny = true, token = "reserved-shiny" },
  { shiny = false, token = "reserved-ordinary-1" },
  { shiny = false, token = "reserved-ordinary-2" },
  { shiny = false, token = "reserved-ordinary-3" },
  { shiny = false, token = "reserved-water-1" },
  { shiny = false, token = "reserved-water-2" },
  { shiny = false, token = "reserved-cooldown-1" },
  { shiny = false, token = "reserved-cooldown-2" },
}
local providers = {
  hgss_simple_follower = { exports = {
    overworldSpriteApiVersion = 1,
    createOverworldSprite = function(mon, context)
      assert(mon.species == "RATTATA")
      assert(context.owner == "kanto_living_encounters")
      return { def = { id = "SPRITE_HGSS_OVERWORLD_PROVIDER",
        image = "provider-proxy.png", frames = 6 }, draw = function() end }
    end,
  } },
  gen1_shiny_system = { exports = {
    wildOutcomeApiVersion = 1,
    reserveWildOutcome = function(rng)
      reserved = reserved + 1
      assert(rng(10) == 1, "consumer RNG supports the provider's one-argument form")
      return outcomes[reserved]
    end,
    wildBattleOptions = function(value)
      assert(value == outcomes[1], "battle must consume the visible entity's reserved outcome")
      return { gen1ShinyOutcome = value }
    end,
  } },
}

local eventHandlers, collisionHook = {}, nil
local optionValues = { enabled = true, aggressive = false, amount = "few",
  towns = true, debug = false }
local mod = {
  options = {
    get = function(_, key)
      return optionValues[key]
    end,
  },
  find = function(_, id) return providers[id] end,
  content = { sprites = {
    get = function(_, id) return spriteRegistry[id] end,
    register = function(_, id, def)
      spriteRegistry[id] = def
      Game.data.sprites[id] = def
    end,
    patch = function(_, id, def)
      spriteRegistry[id] = def
      Game.data.sprites[id] = def
    end,
  } },
  events = { on = function(_, name, callback) eventHandlers[name] = callback end },
  hooks = { wrap = function(_, name, callback)
    assert(name == "movement.collision")
    collisionHook = callback
    return function() collisionHook = nil end
  end },
  log = { warn = function() end, error = function() end },
}

local map = {
  id = "ROUTE_1", def = Game.data.maps.ROUTE_1,
  widthCells = 12, heightCells = 12,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 12 and y < 12 end,
  warpAtCell = function() return nil end,
  isWarpTileCell = function() return false end,
  isDoorTileCell = function() return false end,
  signAtCell = function() return nil end,
  isGrassCell = function(_, x, y) return x >= 0 and y >= 0 and x < 12 and y < 12 end,
  isWaterCell = function() return false end,
  isWalkableCell = function() return true end,
}
local player = { cellX = 0, cellY = 0, inputLocked = false }
local ow = setmetatable({ map = map, player = player, npcs = {}, entities = { player },
  battles = 0 }, Overworld)
Game.overworld = ow
Game.stack = { current = ow, top = function(self) return self.current end }

local runtime = Runtime.install(mod)
ow:setMap("ROUTE_1")
local first = runtime.getSpawnSnapshot()
assert(first.target == 2, "few uses the lower deterministic target")
assert(#first.active == 2, "map setup fills the visible target")
assert(reserved == 2, "each visible entity receives one reserved shiny outcome")
assert(#ow.npcs == 2 and #ow.entities == 3, "wilds are independent world entities")
assert(ow.npcs[1].passable == false, "wilds block native NPC overlap")
assert(collisionHook(function(allowed) return allowed end, false, {
  reason = "entity", mover = player, toX = first.active[1].x, toY = first.active[1].y,
}) == true, "player may enter a visible wild contact cell")
assert(collisionHook(function(allowed) return allowed end, false, {
  reason = "entity", mover = {}, toX = first.active[1].x, toY = first.active[1].y,
}) == false, "other NPCs remain blocked by visible wilds")

local interactedNpc = ow.npcs[1]
interactedNpc.kleEntity.area = "town"
ow:talkTo(interactedNpc)
assert(interactedNpc.facing == "down", "town interaction faces the Pokemon toward the player")
assert(cries[1] == "RATTATA", "town interaction plays the species cry")
assert(ow.battles == 0 and not ow.nativeTalks,
  "town interaction neither starts a battle nor enters native NPC dialogue")
interactedNpc.kleEntity.area = "route"

local effective = runtime.getEffectiveSpawnSnapshot({ mapId = "ROUTE_1" })
assert(effective and effective.sections[1].entries[1].chance > 0,
  "runtime publishes immutable-style effective encounter data")

ow:onStepComplete()
assert(ow.nativeSteps == 1, "ordinary steps still execute native encounter processing")

local shinyId
for _, entity in ipairs(first.active) do
  if entity.shiny then shinyId = entity.id end
end
assert(shinyId, "one deterministic visible spawn is shiny")

ow:update(91)
local expired = runtime.getSpawnSnapshot()
local keptShiny = false
for _, entity in ipairs(expired.active) do
  if entity.id == shinyId and entity.shiny then keptShiny = true end
end
assert(keptShiny, "shiny visible spawns ignore the 90-second lifetime")
assert(#expired.active == 2 and reserved == 3,
  "expired ordinary spawns are replaced immediately")

ow:pushBattle({ kind = "unrelated" })
local duringOtherBattle = runtime.getSpawnSnapshot()
assert(#duringOtherBattle.active == 1 and duringOtherBattle.active[1].id == shinyId,
  "unrelated battles clear ordinary spawns but preserve the shiny")
Game.stack.current = ow
ow:afterBattle()
ow:update(0)
local afterOtherBattle = runtime.getSpawnSnapshot()
assert(#afterOtherBattle.active == 2 and reserved == 4,
  "the visible population refills after an unrelated battle")

local shinySpawn
for _, entity in ipairs(afterOtherBattle.active) do
  if entity.id == shinyId then shinySpawn = entity end
end
player.cellX, player.cellY = shinySpawn.x, shinySpawn.y
ow:onStepComplete()
assert(ow.battles == 2, "same-cell contact starts one battle")
assert(battleOptionsSeen and battleOptionsSeen.gen1ShinyOutcome == outcomes[1],
  "battle consumes the same shiny reservation")
assert(#runtime.getSpawnSnapshot().active == 0,
  "entering battle refreshes all ordinary visible spawns")
ow:onStepComplete()
assert(ow.battles == 2, "removed contact entity cannot start a duplicate battle")

local waterMap = {
  id = "ROUTE_21", def = Game.data.maps.ROUTE_21,
  widthCells = 8, heightCells = 8,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 8 and y < 8 end,
  warpAtCell = function() return nil end,
  isWarpTileCell = function() return false end,
  isDoorTileCell = function() return false end,
  signAtCell = function() return nil end,
  isGrassCell = function() return false end,
  -- (2,3) deliberately models a walkable shoreline tile which the engine
  -- also marks as water for Surf transitions.
  isWaterCell = function(_, x, y)
    return (x >= 3 and x <= 5 and y >= 3 and y <= 5) or (x == 2 and y == 3)
  end,
  isWalkableCell = function(_, x, y)
    return not (x >= 3 and x <= 5 and y >= 3 and y <= 5)
  end,
}
Game.stack.current = ow
player.cellX, player.cellY = 0, 0
ow.map = waterMap
ow:setMap("ROUTE_21")
local waterSnapshot = runtime.getSpawnSnapshot()
assert(#waterSnapshot.active == 2, "accessible open water receives visible spawns")
for _, entity in ipairs(waterSnapshot.active) do
  assert(entity.surface == "water" and entity.x >= 3 and entity.x <= 5,
    "walkable shoreline cells are excluded from swimmer placement")
end

optionValues.aggressive = true
unitRolls = { 0, 0.95, 0, 0 }
Game.stack.current = ow
player.cellX, player.cellY = 0, 0
ow.map = map
ow:setMap("ROUTE_1")
local cooldownSnapshot = runtime.getSpawnSnapshot()
local aggressiveSpawn
for _, entity in ipairs(cooldownSnapshot.active) do
  if entity.behavior == "aggressive" then aggressiveSpawn = entity break end
end
assert(aggressiveSpawn, "deterministic population includes one aggressive Pokemon")
assert(cooldownSnapshot.aggressionCooldownRemaining == 30,
  "an aggressive spawn starts the shared 30-second grace period")
player.cellX = aggressiveSpawn.x > 0 and aggressiveSpawn.x - 1 or aggressiveSpawn.x + 1
player.cellY = aggressiveSpawn.y
ow:update(29.9)
assert(not ow.kleEngaging and not ow.emote,
  "aggressive Pokemon cannot detect the adjacent player during spawn grace")
ow:update(0.1)
assert(ow.kleEngaging and ow.emote and player.inputLocked,
  "aggressive detection resumes when the shared grace period expires")

runtime.restore()
assert(Overworld.update ~= nil and Overworld.setMap ~= nil, "runtime restores engine methods")
assert(collisionHook == nil, "runtime removes its collision hook")
ow:talkTo({})
assert(ow.nativeTalks == 1, "runtime restores native NPC interaction")
require = nativeRequire
print("Kanto Living Encounters runtime integration: 29 checks passed")
