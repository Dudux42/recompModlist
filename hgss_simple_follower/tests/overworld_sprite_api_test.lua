local ctx = assert(dofile("hgss_simple_follower/tests/simple_follower_test.lua"))
local mod, Game, Assets, NPC = ctx.mod, ctx.Game, ctx.Assets, ctx.NPC

assert(mod.exports.overworldSpriteApiVersion == 1, "API v1 published")
assert(mod.exports.overworldSpriteDefinitionId == "SPRITE_HGSS_OVERWORLD_PROVIDER",
  "provider definition ID published")
local registered = ctx.sprites[mod.exports.overworldSpriteDefinitionId]
assert(registered and registered.hgssOverworldSprite == true,
  "provider definition exists before consumer NPC creation")

local function options(owner, role)
  return { owner = owner or "kanto_living_encounters", role = role or "wild" }
end

local function speciesList()
  local file = assert(io.open("hgss_simple_follower/main.lua", "rb"))
  local source = file:read("*a")
  file:close()
  local block = assert(source:match("local SPECIES = %{%s*(.-)%s*%}%s*%s*local DEX"))
  local list = {}
  for name in block:gmatch('"([A-Z_]+)"') do list[#list + 1] = name end
  assert(#list == 151, "source species registry contains all 151 species")
  return list
end

local species = speciesList()
for dex, name in ipairs(species) do
  local normal, reason = mod.exports.createOverworldSprite(name, options())
  assert(normal, reason)
  assert(normal ~= ctx.lastNormal, "each call returns a fresh renderer")
  assert(normal.def.id == mod.exports.overworldSpriteDefinitionId,
    "renderer uses registered provider definition")
  assert(normal.def.hgssOverworldSprite == true and not normal.def.hgssSimpleFollower,
    "wild renderer carries provider marker only")
  assert(normal.owner == "kanto_living_encounters" and normal.role == "wild",
    "consumer identity retained")
  assert(normal.def.image:find(string.format("proxy_%03d.png", dex), 1, true),
    "correct species proxy mapping for " .. name)
  assert(normal:resolveImage().path:find(string.format("follower_%03d.png", dex), 1, true),
    "correct normal sheet mapping for " .. name)
  local width, height = normal:resolveImage():getDimensions()
  assert(width == 32 and height == 192, "normal sheet is 32x192 for " .. name)
  assert(normal:resolveImage().filter == "nearest:nearest",
    "normal sheet is nearest-filtered for " .. name)
  assert(normal:resolveImage().wrap == "clamp:clamp",
    "normal sheet is clamp-wrapped for " .. name)
  for frame = 0, 5 do
    local quad = normal.quads[frame]
    assert(quad and quad.x == 0 and quad.y == frame * 32
      and quad.w == 32 and quad.h == 32 and quad.iw == 32 and quad.ih == 192,
      "correct frame geometry for " .. name .. " frame " .. tostring(frame + 1))
  end
  assert(normal.quads[6] == nil, "exactly six frames exposed for " .. name)

  local shiny = assert(mod.exports.createOverworldSprite(
    { species = name, shiny = true }, options("api_test", "wild")))
  assert(shiny:resolveImage().path:find(string.format("shiny_%03d.png", dex), 1, true),
    "correct shiny sheet mapping for " .. name)
  assert(shiny:resolveImage().filter == "nearest:nearest",
    "shiny sheet is nearest-filtered for " .. name)
  ctx.lastNormal = normal
end

local invalid, invalidReason = mod.exports.createOverworldSprite("MISSINGNO", options())
assert(invalid == nil and type(invalidReason) == "string", "invalid species rejected")
assert(mod.exports.createOverworldSprite({}, options()) == nil, "missing species rejected")
assert(mod.exports.createOverworldSprite("PIKACHU", {}) == nil, "missing owner rejected")
assert(mod.exports.createOverworldSprite("PIKACHU", { owner = "x", role = "" }) == nil,
  "empty role rejected")

-- Missing known artwork is a hard failure, never a Charmander substitution.
for _, invalidate in ipairs(ctx.registeredAssets) do invalidate() end
local originalImage = Assets.image
Assets.image = function(path)
  if path:find("follower_151.png", 1, true) then error("missing test art") end
  return originalImage(path)
end
local missing, missingReason = mod.exports.createOverworldSprite("MEW", options())
assert(missing == nil and missingReason:find("unavailable", 1, true),
  "missing requested artwork returns nil and reason")
Assets.image = originalImage

-- Full objects honor provider/public shiny state and native DVs.
for _, invalidate in ipairs(ctx.registeredAssets) do invalidate() end
local explicit = assert(mod.exports.createOverworldSprite(
  { species = "PIKACHU", shiny = true }, options()))
assert(explicit.shiny and explicit:resolveImage().path:find("shiny_025.png", 1, true),
  "explicit shiny flag selects shiny art")
local oldFind = mod.find
mod.find = function() return nil end
local native = assert(mod.exports.createOverworldSprite({
  species = "RAICHU",
  dvs = { attack = 2, defense = 10, speed = 10, special = 10 },
}, options()))
assert(native.shiny and native:resolveImage().path:find("shiny_026.png", 1, true),
  "native shiny DVs select shiny art without Shiny System")
mod.find = oldFind

-- Renderers share immutable cached images but own their renderer/quads and do
-- not alter follower save state or one another's animation inputs.
local beforeEnabled = Game.save.hgssSimpleFollower.enabled
local first = assert(mod.exports.createOverworldSprite("PSYDUCK", options("one", "wild")))
local second = assert(mod.exports.createOverworldSprite("PSYDUCK", options("two", "wild")))
assert(first ~= second and first.quads ~= second.quads and first.def ~= second.def,
  "renderer animation identity is independent")
local drawStart = #ctx.draws
first:draw(64, 64, 0, 0, "down", 0, false)
second:draw(64, 64, 0, 0, "down", 1, false)
assert(#ctx.draws == drawStart + 2, "one flat body drawn per renderer call")
assert(ctx.draws[drawStart + 1].quad.y == 0 and ctx.draws[drawStart + 2].quad.y == 96,
  "independent renderers accept independent animation phases")
assert(Game.save.hgssSimpleFollower.enabled == beforeEnabled,
  "public renderer creation does not mutate follower state")

-- The definition can be passed to NPC.new before assigning the fresh renderer.
local npc = NPC.new(Game.data, "API_TEST", {
  index = 77, sprite = mod.exports.overworldSpriteDefinitionId,
  movement = "STAY", range = "NONE", x = 1, y = 1,
})
assert(npc and npc.sprite, "NPC.new accepts registered provider definition")
npc.sprite = first
assert(not npc.hgssSimpleFollower, "consumer NPC is not a follower")

-- Cache invalidation changes future image resolution while old renderers keep
-- their already-resolved image safe and stable.
local oldResolved = first:resolveImage()
for _, invalidate in ipairs(ctx.registeredAssets) do invalidate() end
local refreshed = assert(mod.exports.createOverworldSprite("PSYDUCK", options()))
assert(refreshed:resolveImage() ~= oldResolved and first:resolveImage() == oldResolved,
  "asset reload invalidates future calls without breaking live renderers")

-- Reinstall the voxel seam after the base regression restored wrappers.
ctx.events["mods.loaded"]()
local mesh = ctx.SpriteBillboards.mesh(first.def, 3)
local forkMesh = ctx.ForkSpriteBillboards.mesh(first.def, 3)
assert(type(mesh) == "table" and mesh.vertices[1][1] == -8
  and mesh.vertices[2][1] == 24 and mesh.vertices[3][2] == 32,
  "Dramatic Shape receives centered ground-anchored provider billboard")
assert(type(forkMesh) == "table" and forkMesh.vertices[1][1] == -8
  and forkMesh.vertices[2][1] == 24 and forkMesh.vertices[3][2] == 32,
  "Battle Art Voxel Fork receives centered provider billboard")

mod.exports.restore()
print("overworld_sprite_api_test: OK")
