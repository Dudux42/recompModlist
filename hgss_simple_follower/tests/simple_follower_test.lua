package.path = "hgss_simple_follower/?.lua;" .. package.path

local draws = {}
love = {
  graphics = {
    newQuad = function(x, y, w, h, iw, ih)
      return { x = x, y = y, w = w, h = h, iw = iw, ih = ih }
    end,
    setColor = function() end,
    draw = function(image, quad, x, y, rot, sx, sy)
      draws[#draws + 1] = { image = image, quad = quad, x = x, y = y, sx = sx, sy = sy }
    end,
  },
}

local function image(path)
  local proxy = type(path) == "string" and path:find("proxy_", 1, true)
  return {
    getDimensions = function() return proxy and 16 or 32, proxy and 96 or 192 end,
    setFilter = function(self, min, mag) self.filter = min .. ":" .. mag end,
    setWrap = function(self, x, y) self.wrap = x .. ":" .. y end,
  }
end

local registeredAssets = {}
local Assets = {
  image = function(path)
    local result = image(path)
    result.path = path
    return result
  end,
  register = function(callback) registeredAssets[#registeredAssets + 1] = callback end,
}

local NPC = {}
function NPC.new(data, mapId, def)
  local npc = {
    def = def,
    id = mapId .. "_obj_" .. tostring(def.index),
    cellX = def.x,
    cellY = def.y,
    px = def.x * 16,
    py = def.y * 16,
    sprite = data.sprites[def.sprite],
    facing = "down",
    moving = false,
    progress = 0,
  }
  function npc:update()
    if self.moving then self.progress = self.progress + 1 end
  end
  function npc:pose()
    return self.sprite, self.px, self.py, self.facing, self:walkPhase(), self.stepFlip, false
  end
  return npc
end
function NPC.walkPhase(self) return self.moving and 1 or 0 end

local Collision = { DELTA = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
} }

local OverworldState = {}
function OverworldState:update() self.baseUpdates = (self.baseUpdates or 0) + 1 end
function OverworldState:interact() self.baseInteracts = (self.baseInteracts or 0) + 1 end
function OverworldState:crossConnection()
  self.player.cellX, self.player.cellY = 4, 5
  self.player.px, self.player.py = 64, 80
  self.player.facing = "right"
  self.player.targetX, self.player.targetY = 5, 5
  return true
end

local stack = { pushed = {} }
function stack:push(value) self.pushed[#self.pushed + 1] = value end

local Game = {
  save = { party = {} },
  data = {
    sprites = {},
    pokemon = {
      FARFETCHD = { name = "FARFETCH'D" },
      WARTORTLE = { name = "WARTORTLE" },
      NIDORINO = { name = "NIDORINO" },
    },
    field = { ledges = {} },
  },
  stack = stack,
}

package.preload["src.core.Game"] = function() return Game end
package.preload["src.render.Assets"] = function() return Assets end
package.preload["src.render.PaletteFX"] = function()
  return { markTrueColor = function(x, y, w, h) draws.trueColor = { x, y, w, h } end }
end
package.preload["src.world.NPC"] = function() return NPC end
package.preload["src.world.Collision"] = function() return Collision end
package.preload["src.world.OverworldController"] = function() return OverworldState end
package.preload["src.world.PikachuFollower"] = function() return {} end
package.preload["src.core.Strings"] = function()
  return function(format, ...) return string.format(format, ...) end
end
package.preload["src.render.TextBox"] = function()
  return { new = function(game, text) return { text = text } end }
end
package.preload["src.core.Sound"] = function()
  return { play = function() return true end }
end
package.preload["src.pokemon.Stats"] = function()
  return { isShiny = function(dvs)
    local attack = dvs and (dvs.attack or dvs.atk)
    return dvs and (dvs.defense or dvs.def) == 10
      and (dvs.speed or dvs.spd) == 10 and (dvs.special or dvs.spc) == 10
      and (attack == 2 or attack == 3 or attack == 6 or attack == 7
        or attack == 10 or attack == 11 or attack == 14 or attack == 15)
  end }
end

local hook
local events = {}
local sprites = {}
local SpriteBillboards = {
  mesh = function() return "original_mesh" end,
  shadowQuad = function() return "original_shadow" end,
}
-- Simulate a launcher session that already loaded an older follower build.
local staleFollowerMesh = function() return "stale_follower_mesh" end
SpriteBillboards.mesh = staleFollowerMesh
SpriteBillboards.shadowQuad = staleFollowerMesh
SpriteBillboards._hgssSimpleFollowerMesh = staleFollowerMesh
local ForkSpriteBillboards = {
  mesh = staleFollowerMesh,
  shadowQuad = staleFollowerMesh,
  _hgssSimpleFollowerMesh = staleFollowerMesh,
}
local Voxel3D = {
  pushQuad = function(indices) indices[1], indices[2], indices[3] = 1, 2, 3 end,
  newMesh = function(vertices, indices) return { vertices = vertices, indices = indices } end,
}
local dramatic = { exports = { lib = { require = function(name)
  if name == "SpriteBillboards" then return SpriteBillboards end
  if name == "Voxel3D" then return Voxel3D end
end } } }
local battleFork = { exports = { lib = { require = function(name)
  if name == "SpriteBillboards" then return ForkSpriteBillboards end
  if name == "Voxel3D" then return Voxel3D end
end } } }
local followerSparkles = 0
local shinySystem = { exports = {
  shouldUseShinyArt = function(mon)
    return mon.shiny == true or (mon.dvs and mon.dvs.defense == 10
      and mon.dvs.speed == 10 and mon.dvs.special == 10)
  end,
  drawFollowerSparkles = function()
    followerSparkles = followerSparkles + 1
  end,
} }
local mod = {
  id = "hgss_simple_follower",
  assets = { path = function(_, rel) return "MOD/" .. rel end },
  content = { sprites = {
    get = function(_, id) return sprites[id] end,
    register = function(_, id, def) sprites[id] = def; Game.data.sprites[id] = def end,
    patch = function(_, id, def) sprites[id] = def; Game.data.sprites[id] = def end,
  } },
  hooks = { wrap = function(_, name, fn) assert(name == "ui.party.submenu"); hook = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  exports = {},
  find = function(_, id)
    if id == "gen1_shiny_system" then return shinySystem end
    if id == "DRAMATIC_SHAPE" then return dramatic end
    if id == "BATTLE_ART_VOXEL_FORK" then return battleFork end
  end,
  log = { info = function() end, error = function(_, fmt, err) error(string.format(fmt, err)) end },
}

local function mon(species, hp, dvs)
  return { species = species, hp = hp, dvs = dvs, otId = 7, moves = {} }
end

local farfetchd = mon("FARFETCHD", 31, { attack = 1, defense = 2, speed = 3, special = 4 })
local wartortle = mon("WARTORTLE", 49, { attack = 2, defense = 10, speed = 10, special = 10 })
local nidorino = mon("NIDORINO", 50, { attack = 9, defense = 10, speed = 11, special = 12 })
Game.save.party = { farfetchd, wartortle, nidorino }

local map = {
  id = "TEST_MAP",
  def = { tileset = "OVERWORLD" },
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 20 and y < 20 end,
  isWalkableCell = function() return true end,
  cellTile = function() return 0 end,
}
local player = {
  cellX = 5, cellY = 5, facing = "down", stepFrames = 16,
  facingCell = function(self)
    local d = Collision.DELTA[self.facing]
    return self.cellX + d[1], self.cellY + d[2]
  end,
}
local ow = setmetatable({ map = map, player = player, npcs = {}, entities = { player } }, { __index = OverworldState })
Game.overworld = ow

local entry = assert(loadfile("hgss_simple_follower/main.lua"))()
entry(mod)

assert(sprites.SPRITE_HGSS_SIMPLE_FOLLOWER, "sprite registered")
assert(sprites.SPRITE_HGSS_OVERWORLD_PROVIDER,
  "public overworld provider sprite definition registered")
assert(type(hook) == "function", "party hook installed")
assert(SpriteBillboards.mesh ~= staleFollowerMesh,
  "new build replaces a stale Dramatic Shape follower wrapper")
assert(ForkSpriteBillboards.mesh ~= staleFollowerMesh,
  "Battle Art Voxel Fork receives its own follower wrapper")
local card = SpriteBillboards.mesh(sprites.SPRITE_HGSS_SIMPLE_FOLLOWER, 3)
assert(type(card) == "table" and card.vertices[1][1] == -8
  and card.vertices[2][1] == 24 and card.vertices[3][2] == 32,
  "Dramatic Shape receives centered 32px card")
local forkCard = ForkSpriteBillboards.mesh(sprites.SPRITE_HGSS_SIMPLE_FOLLOWER, 3)
assert(type(forkCard) == "table" and forkCard.vertices[2][1] == 24
  and forkCard.vertices[3][2] == 32,
  "active Battle Art fork receives centered 32px card")

local baseRows = {
  { label = "STATS" }, { label = "FOLLOWER", onSelect = function() error("legacy callback") end },
  { label = "LEADER", onSelect = function() error("legacy callback") end },
}
local rows = hook(function() return baseRows end, Game, baseRows, wartortle, { battle = false })
assert(#rows == 2 and rows[1].label == "STATS" and rows[2].label == "FOLLOW", "legacy rows replaced")
rows[2].onSelect(wartortle, Game)
assert(Game.save.hgssSimpleFollower.enabled == true, "selection enabled")
assert(mod.exports.activeMon(Game) == wartortle, "chosen mon active")

mod.exports.tick(Game, ow)
assert(#ow.npcs == 1 and ow.npcs[1].hgssSimpleFollower, "one follower spawned")
assert(ow.entities[1] == ow.npcs[1] and ow.entities[2] == player,
  "follower draws before player on flat renderer")
assert(ow.npcs[1].monSpecies == "WARTORTLE", "chosen species rendered")
assert(ow.npcs[1].sprite.def.frameWidth == 32, "native 32px renderer")
assert(ow.npcs[1].sprite.def.image:find("proxy_008.png", 1, true),
  "billboard definition uses the 16x96 compatibility proxy")
assert(ow.npcs[1].sprite:resolveImage().path:find("shiny_008.png", 1, true),
  "shiny DVs select the ROM-extracted shiny overworld palette")
local rw, rh = ow.npcs[1].sprite:resolveImage():getDimensions()
assert(rw == 32 and rh == 192, "resolved follower texture retains native detail")

-- Area transitions respawn immediately on the exact behind-player tile.
player.cellX, player.cellY, player.facing = 5, 5, "right"
events["map.entered"]()
assert(#ow.npcs == 1 and ow.npcs[1].cellX == 4 and ow.npcs[1].cellY == 5,
  "map transition respawns immediately on exact behind tile")

-- Doorway/edge collision often reports the behind tile as non-walkable. The
-- passable follower still belongs there and must remain visible.
player.cellX, player.cellY, player.facing = 5, 5, "down"
map.isWalkableCell = function() return false end
events["map.entered"]({ via = "warp" })
assert(#ow.npcs == 1 and ow.npcs[1].cellX == 5 and ow.npcs[1].cellY == 4,
  "non-walkable doorway tile does not hide passable follower")
map.isWalkableCell = function() return true end

-- Seamless connections emit map.entered before the engine rebases the player.
-- Do not spawn in that intermediate state; crossConnection's wrapper performs
-- the sync afterward and permits the exact behind coordinate outside bounds.
events["map.entered"]({ via = "connection" })
assert(#ow.npcs == 0, "connection event waits for engine rebase")
ow:crossConnection("right", {})
assert(#ow.npcs == 1 and ow.npcs[1].cellX == 3 and ow.npcs[1].cellY == 5,
  "connection sync spawns behind rebased player outside destination bounds")
player.targetX, player.targetY = nil, nil

player.facing = "right"
mod.exports.tick(Game, ow)
assert(ow.npcs[1].facing == "right", "idle follower turns with player")
ow.npcs[1].sprite:draw(80, 80, 0, 0, "down", 0, false)
assert(followerSparkles == 1, "shared shiny system sparkle renderer was called")
assert(draws[#draws].quad.w == 32 and draws[#draws].quad.h == 32, "32px draw quad")
assert(draws[#draws].sx == 1 and draws[#draws].sy == 1, "2D follower uses native 32px scale")
assert(draws.trueColor[3] == 32 and draws.trueColor[4] == 32, "32px true-color region")

-- Selected Wartortle faints: slot 1 is the first healthy replacement.
wartortle.hp = 0
mod.exports.tick(Game, ow)
assert(mod.exports.activeMon(Game) == farfetchd, "fainting chooses first healthy slot")
assert(ow.npcs[1].monSpecies == "FARFETCHD", "live art switches on failover")

-- Party reorder keeps identity rather than blindly retaining the slot number.
Game.save.party = { nidorino, farfetchd, wartortle }
assert(mod.exports.activeMon(Game) == farfetchd, "party reorder preserves follower identity")

-- If that replacement also faints, top-to-bottom evaluation runs again.
farfetchd.hp = 0
mod.exports.tick(Game, ow)
assert(mod.exports.activeMon(Game) == nidorino, "second failover respects new party order")

-- No healthy party means no visible follower; healing restores the first healthy.
nidorino.hp = 0
mod.exports.tick(Game, ow)
assert(#ow.npcs == 0, "all fainted hides follower")
wartortle.hp = 10
mod.exports.tick(Game, ow)
assert(mod.exports.activeMon(Game) == wartortle and #ow.npcs == 1, "healing restores follower")

-- Movement follows the cell the player commits to vacating.
player.facing = "down"
player.targetX, player.targetY = 5, 6
mod.exports.tick(Game, ow)
assert(ow.npcs[1].moving and ow.npcs[1].progress == 1, "follower begins synchronized step")
player.targetX, player.targetY = nil, nil

-- Selecting the current follower exposes the stop action.
rows = hook(function() return { { label = "STATS" } } end, Game, {}, wartortle, { battle = false })
assert(rows[#rows].label == "STOP FOLLOWING", "stop action shown")
rows[#rows].onSelect(wartortle, Game)
assert(Game.save.hgssSimpleFollower.enabled == false and #ow.npcs == 0, "stop removes follower")

mod.exports.restore()
assert(OverworldState.update ~= nil and OverworldState.interact ~= nil, "runtime wrappers restore")
print("simple_follower_test: OK")
return {
  mod = mod,
  Game = Game,
  Assets = Assets,
  NPC = NPC,
  sprites = sprites,
  registeredAssets = registeredAssets,
  draws = draws,
  SpriteBillboards = SpriteBillboards,
  ForkSpriteBillboards = ForkSpriteBillboards,
  events = events,
}
