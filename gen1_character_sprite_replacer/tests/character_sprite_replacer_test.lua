local root = (... and ... ~= "" and ...) or "gen1_character_sprite_replacer"

local optionValues = { character_pack = "frlg_red" }
local voxelLevel = 0
local optionDefs
local hooks, events = {}, {}
local drawCalls, markCalls = {}, {}
local scaleRecords = {}
local widescreenOwns = false

local function dimensions(path)
  if path:find("_walk.png", 1, true) then return 16, 384 end
  if path:find("_bike.png", 1, true) then return 32, 384 end
  if path:find("_surf.png", 1, true) then return 32, 192 end
  if path:find("_main_menu.png", 1, true) then return 64, 96 end
  return 64, 64
end

local function image(path)
  local w, h = dimensions(path)
  return {
    path = path,
    getDimensions = function() return w, h end,
    getWidth = function() return w end,
    getHeight = function() return h end,
    setFilter = function(self, min, mag) self.filter = min .. "/" .. mag end,
    setWrap = function() end,
  }
end

local assetInvalidator
package.preload["src.render.Assets"] = function()
  return {
    image = image,
    register = function(fn) assetInvalidator = fn end,
  }
end

local romDraws, romTiles = 0, 0
local function romSprite(id)
  return {
    def = { id = id, image = "rom_" .. id .. ".png", frames = 6, walker = true },
    resolveImage = function() return image("rom.png") end,
    draw = function() romDraws = romDraws + 1 end,
    drawTile = function() romTiles = romTiles + 1 end,
  }
end

local game = {
  overworld = {
    player = {
      sprite = romSprite("walk"),
      bikeSprite = romSprite("bike"),
      surfSprite = romSprite("surf"),
      surfPikachuSprite = romSprite("surfPikachu"),
    },
  },
}
package.preload["src.core.Game"] = function() return game end
local Player = {
  pose = function(self)
    return self.sprite, 0, 0, self.testFacing or "down",
      self.testWalkPhase or 0, self.testStepFlip or false, false
  end,
}
package.preload["src.world.Player"] = function() return Player end
local BattleState = {
  trainerPicPath = function(_, trainer) return trainer and trainer.pic end,
  trainerPalette = function() return "rom-palette" end,
  slidePic = function(self, slot, from, to, step)
    self.slide = { slot = slot, from = from, to = to, step = step }
  end,
  updateFx = function(self) self.fxUpdates = (self.fxUpdates or 0) + 1 end,
  picOffset = function() return 5 end,
  drawPicsLayer = function(self)
    self.originalLayerShowPlayerBack = self.showPlayerBack
    self.originalLayerShowEnemyTrainer = self.showEnemyTrainer
    self.originalLayerDraws = (self.originalLayerDraws or 0) + 1
  end,
}
package.preload["src.battle.BattleState"] = function() return BattleState end
package.preload["src.render.PaletteFX"] = function()
  return { markTrueColor = function(...) markCalls[#markCalls + 1] = { ... } end }
end
package.preload["src.render.Pipelines"] = function()
  return { level = function(id) return id == "voxel" and voxelLevel or 0 end }
end

love = {
  graphics = {
    newQuad = function(x, y, w, h, iw, ih)
      return { x = x, y = y, w = w, h = h, iw = iw, ih = ih }
    end,
    setColor = function() end,
    draw = function(...)
      drawCalls[#drawCalls + 1] = { ... }
    end,
  },
}

local mod = {
  id = "gen1_character_sprite_replacer",
  path = root,
  assets = { path = function(_, rel) return root .. "/" .. rel end },
  read = function(_, rel)
    local file = io.open(root .. "/" .. rel, "rb")
    if not file then return nil, "missing" end
    local source = file:read("*a")
    file:close()
    return source
  end,
  options = {
    define = function(_, defs) optionDefs = defs end,
    get = function(_, key) return optionValues[key] end,
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  content = {
    battle_sprite_scales = {
      register = function(_, id, record) scaleRecords[id] = record end,
    },
  },
  exports = {},
  log = { info = function() end, warn = function() end },
}
mod.find = function(_, id)
  if id == "DRAMATIC_SHAPE" then return mod.dramaticShape end
  if id == "gen1_widescreen_ui" then
    return { exports = { ownsBattleTrainerBack = function()
      return widescreenOwns
    end } }
  end
  return nil
end

local init = assert(loadfile(root .. "/main.lua"))()
init(mod)

assert(optionDefs and #optionDefs == 2)
assert(optionDefs[1].key == "character_pack")
assert(optionDefs[1].choices[1][2] == "frlg_red")
assert(optionDefs[1].choices[2][2] == "frlg_leaf")
assert(optionDefs[1].choices[3][2] == "rom")
assert(optionDefs[2].key == "enemy_trainer_pack")
assert(optionDefs[2].choices[1][2] == "rom")
assert(optionDefs[2].choices[2][2] == "frlg")
assert(mod.exports.version == "0.1.0-alpha.8")
assert(mod.exports.characterAppearanceApiVersion == 1)
assert(mod.exports.activePack() == "frlg_red")
assert(mod.exports.activeTrainerPack() == "rom")
assert(BattleState.trainerPicPath(nil,
  { id = "OPP_BROCK", pic = "rom_brock.png" }, "OPP_BROCK", 1) == "rom_brock.png")
assert(BattleState.trainerPalette(nil, { id = "OPP_BROCK" }) == "rom-palette")
assert(next(scaleRecords) and scaleRecords.frlg_red_player_back.scale == 1
  and scaleRecords.frlg_leaf_player_throw_5.scale == 1)

local walk = assert(mod.exports.resolvePlayerOverworld("walk"))
assert(walk.packId == "frlg_red" and walk.frameW == 16 and walk.frameH == 32)
assert(walk.frameCount == 12 and walk.layout == "frlg-twelve-pose"
  and walk.logicalFootprintW == 16)
assert(mod.exports.resolvePlayerOverworld("fishing") == nil)
assert(mod.exports.resolvePlayerPresentation("start_menu").frameH == 96)
assert(mod.exports.resolvePlayerBattle("front").imagePath:find("frlg_red_front.png", 1, true))

events["game.ready"]()
local player = game.overworld.player
assert(player.sprite ~= nil and player.sprite.def ~= nil)
assert(player.surfPikachuSprite.def.id == "surfPikachu", "Surfing Pikachu must remain untouched")

player.sprite:draw(32, 100, 0, 0, "down", 0, false, false)
assert(#drawCalls == 1)
local call = drawCalls[1]
assert(call[3] == 32 and call[4] == 80, "16x32 walk art was not bottom anchored")
assert(#markCalls == 1)

local battle = setmetatable({ showPlayerBack = true, queue = { { wait = 18 } } },
  { __index = BattleState })
local beforeThrowDraw = #drawCalls
battle:slidePic("back", 0, -72, 4)
assert(battle.characterAppearanceThrow and battle.characterAppearanceThrow.index == 1)
assert(battle.slide.step == 2 and battle.queue[1].wait == 40,
       "slower throw did not keep the slide and queue synchronized")
for _ = 1, 8 do battle:updateFx() end
assert(battle.characterAppearanceThrow.index == 1,
       "slower throw did not hold its first authored pose")
battle:updateFx()
assert(battle.characterAppearanceThrow.index == 2,
       "throw animation did not advance on the battle frame clock")
battle:drawPicsLayer(0, 0, 0)
assert(battle.originalLayerShowPlayerBack == false,
       "throw frame did not suppress only the static player back")
assert(#drawCalls == beforeThrowDraw + 1)
assert(drawCalls[#drawCalls][1].path:find("frlg_red_throw_2.png", 1, true))
assert(drawCalls[#drawCalls][2] == 13 and drawCalls[#drawCalls][3] == 32,
       "64px throw frame was not drawn 1x at the grounded battle position")
widescreenOwns = true
local beforeOwnedThrow = #drawCalls
battle:drawPicsLayer(0, 0, 0)
assert(battle.originalLayerShowPlayerBack == false
       and #drawCalls == beforeOwnedThrow,
       "Widescreen-owned throw was duplicated in the battle layer")
widescreenOwns = false
for _ = 1, 31 do battle:updateFx() end
assert(battle.characterAppearanceThrow.index == 5,
       "40-frame sendout did not reach and hold the fifth authored pose")
battle:slidePic("back")
assert(battle.characterAppearanceThrow == nil)

optionValues.enemy_trainer_pack = "frlg"
events["mod.options_changed"]({ mod = mod.id })
assert(mod.exports.activeTrainerPack() == "frlg")
local brockPath = BattleState.trainerPicPath(nil,
  { id = "OPP_BROCK", pic = "rom_brock.png" }, "OPP_BROCK", 1)
assert(brockPath:find("frlg_trainer_brock.png", 1, true))
assert(BattleState.trainerPalette(nil, { id = "OPP_BROCK" }) == nil)
assert(mod.exports.resolveTrainerBattle("OPP_BROCK").trueColor == true)
assert(BattleState.trainerPicPath(nil,
  { id = "OPP_PROF_OAK", pic = "rom_oak.png" }, "OPP_PROF_OAK", 1) == "rom_oak.png")
local yellowRocket = { id = "OPP_ROCKET", pic = "rom_rocket.png",
  picJessieJames = "rom_jessie_james.png" }
assert(BattleState.trainerPicPath(nil, yellowRocket, "OPP_ROCKET", 42)
  == "rom_rocket.png", "Yellow special Rocket portrait was guessed over")
assert(BattleState.trainerPalette(nil, yellowRocket) == "rom-palette")

local beforeTrainerDraw = #drawCalls
local trainerBattle = setmetatable({
  showEnemyTrainer = true,
  trainerPic = brockPath,
  trainer = { id = "OPP_BROCK" },
}, { __index = BattleState })
trainerBattle:drawPicsLayer(0, 0, 0)
assert(trainerBattle.originalLayerShowEnemyTrainer == true,
       "mapped enemy trainer did not remain engine-owned and static")
assert(#drawCalls == beforeTrainerDraw,
       "mapped enemy trainer received a duplicate adapter draw")

player.sprite:draw(32, 100, 0, 0, "down", 1, false, false)
assert(drawCalls[#drawCalls][2].y == 4 * 32, "step A did not use authored frame 4")
player.sprite:draw(32, 100, 0, 0, "down", 1, true, false)
local stepBCall = drawCalls[#drawCalls]
assert(stepBCall[2].y == 8 * 32, "step B did not use the third authored source frame")
assert(stepBCall[6] == nil, "authored down step B was incorrectly mirrored")
player.sprite:draw(32, 100, 0, 0, "right", 1, true, false)
assert(drawCalls[#drawCalls][2].y == 11 * 32 and drawCalls[#drawCalls][6] == nil,
       "right step B did not use the authored right-facing frame")

player.testFacing, player.testWalkPhase, player.testStepFlip = "down", 1, true
assert(Player.pose(player) == player.sprite)
assert(player.sprite.def.characterAppearanceFrame == 8,
       "Player.pose adapter did not publish the third authored step")

-- Unsupported Dramatic Shape voxel presentation must use the exact ROM
-- renderer instead of slicing a 16px band from a 32px FRLG frame.
mod.dramaticShape = { exports = { version = "1.8.0" } }
voxelLevel = 1
assert(player.sprite.def.id == "walk",
       "voxel path observed the enhanced definition before image resolution")
assert(player.sprite:resolveImage().path == "rom.png",
       "voxel path did not pair the ROM definition with the ROM texture")
local beforeVoxelFallback = romDraws
player.sprite:draw(32, 100, 0, 0, "down", 0, false, false)
assert(romDraws == beforeVoxelFallback + 1,
       "unsupported Dramatic Shape voxel mode did not use ROM fallback")
assert(player.sprite.def.id == "walk", "voxel fallback did not restore ROM definition")
assert(mod.exports.resolvePlayerOverworld("walk").packId == "frlg_red",
       "presentation guard must not erase the public provider descriptor")

-- The adapter patches only this mod's billboard descriptors.
local originalMeshCalls, originalShadowCalls, originalInvalidates = 0, 0, 0
local SpriteBillboards = {
  mesh = function(def, frame)
    originalMeshCalls = originalMeshCalls + 1
    return { original = true, def = def, frame = frame }
  end,
  shadowQuad = function(def, frame)
    originalShadowCalls = originalShadowCalls + 1
    return { originalShadow = true, def = def, frame = frame }
  end,
  invalidate = function() originalInvalidates = originalInvalidates + 1 end,
}
local Voxel3D = {
  pushQuad = function(indices, base)
    indices[1], indices[2], indices[3] = base + 1, base + 2, base + 3
    indices[4], indices[5], indices[6] = base + 1, base + 3, base + 4
  end,
  newMesh = function(verts, indices) return { verts = verts, indices = indices } end,
}
mod.dramaticShape.exports.lib = {
  require = function(name)
    if name == "SpriteBillboards" then return SpriteBillboards end
    if name == "Voxel3D" then return Voxel3D end
    error("unexpected Dramatic Shape module " .. tostring(name))
  end,
}
events["mods.loaded"]()
assert(SpriteBillboards.__gen1CharacterAppearanceAdapterVersion == 1)
assert(player.sprite.def.characterAppearanceOwner == mod.id,
       "installed adapter did not restore the enhanced live definition")
assert(player.sprite:resolveImage().path:find("frlg_red_walk.png", 1, true),
       "installed adapter still forced the ROM texture")

player.sprite:setAppearancePose("down", 1, true)
player.sprite:resolveImage()
assert(player.sprite.def.characterAppearanceFrame == 8,
       "image resolution discarded the published authored pose")
local walkMesh = assert(SpriteBillboards.mesh(player.sprite.def, 4))
assert(walkMesh.verts[1][1] == 0 and walkMesh.verts[2][1] == 16)
assert(walkMesh.verts[1][2] == 0 and walkMesh.verts[3][2] == 32,
       "16x32 walk mesh lost its authored height/ground anchor")
assert(walkMesh.verts[1][5] > walkMesh.verts[3][5],
       "walk mesh UVs do not run from frame bottom to frame top")
local expectedTopV = (8 * 32 + math.min(0.05, 32 / 1000)) / 384
assert(math.abs(walkMesh.verts[3][5] - expectedTopV) < 0.000001,
       "walk mesh did not consume the published authored step-B frame")
assert(walkMesh.verts[1][4] > walkMesh.verts[2][4],
       "walk mesh did not compensate for Dramatic Shape's legacy mirror")
player.sprite:setAppearancePose("right", 0, false)
local rightIdleMesh = assert(SpriteBillboards.mesh(player.sprite.def, 2))
local rightIdleTopV = (3 * 32 + math.min(0.05, 32 / 1000)) / 384
assert(math.abs(rightIdleMesh.verts[3][5] - rightIdleTopV) < 0.000001,
       "Dramatic Shape did not consume the authored right idle")
assert(rightIdleMesh.verts[1][4] > rightIdleMesh.verts[2][4],
       "authored right idle did not cancel the legacy right mirror")

local bikeDesc = assert(mod.exports.resolvePlayerOverworld("bike"))
player.bikeSprite:selection()
player.bikeSprite:setAppearancePose("left", 1, true)
local bikeMesh = assert(SpriteBillboards.shadowQuad(player.bikeSprite.def, 2))
assert(bikeMesh.verts[1][1] == -8 and bikeMesh.verts[2][1] == 24,
       "32px bike mesh was not centered on the logical 16px footprint")
assert(bikeMesh.verts[1][2] == 0 and bikeMesh.verts[3][2] == 32)
assert(bikeDesc.anchorX == 16 and bikeDesc.logicalFootprintW == 16)
assert(player.bikeSprite.def.characterAppearanceFrame == 10,
       "bike did not expose its third authored step")

local unrelated = { image = "npc.png", frames = 6, walker = true }
assert(SpriteBillboards.mesh(unrelated, 0).original == true)
assert(originalMeshCalls == 1, "unrelated sprite did not use original mesh")
assert(SpriteBillboards.shadowQuad(unrelated, 0).originalShadow == true)
assert(originalShadowCalls == 1, "unrelated shadow did not use original shadow mesh")
SpriteBillboards.invalidate()
assert(originalInvalidates == 1, "adapter did not preserve original invalidation")
voxelLevel = 0

local beforeBikeDraw = #drawCalls
player.bikeSprite:draw(32, 100, 0, 0, "left", 1, false, false)
assert(#drawCalls == beforeBikeDraw + 1)
assert(drawCalls[#drawCalls][3] == 24 and drawCalls[#drawCalls][4] == 80,
       "32x32 bike art was not centered/bottom anchored")

local trainerCtx = { side = "front", kind = "trainer_card", trueColor = false }
local trainerPath = hooks["player.sprite"](function() return "rom_front.png" end,
  "rom_front.png", trainerCtx)
assert(trainerPath:find("frlg_red_front.png", 1, true) and trainerCtx.trueColor == true)

local demoCtx = { side = "back", kind = "battle", demo = true, trueColor = false }
assert(hooks["player.sprite"](function() return "old_man.png" end,
  "old_man.png", demoCtx) == "old_man.png")
assert(demoCtx.trueColor == false)

optionValues.character_pack = "frlg_leaf"
events["mod.options_changed"]({ mod = mod.id })
assert(mod.exports.activePack() == "frlg_leaf")
assert(mod.exports.resolvePlayerPresentation("continue").imagePath:find("frlg_leaf_main_menu.png", 1, true))
local hofCtx = { side = "front", kind = "hof", trueColor = false }
assert(hooks["player.sprite"](function() return "rom_front.png" end,
  "rom_front.png", hofCtx):find("frlg_leaf_front.png", 1, true))
assert(hofCtx.trueColor == true)

local beforeRomDraws = romDraws
player.sprite:draw(0, 0, 0, 0, "down", 0, false, true)
assert(romDraws == beforeRomDraws + 1, "fishing top-half must use ROM composition")

optionValues.character_pack = "rom"
events["mod.options_changed"]({ mod = mod.id })
assert(mod.exports.resolvePlayerOverworld("walk") == nil)
assert(mod.exports.resolvePlayerBattle("back") == nil)
assert(mod.exports.resolvePlayerPresentation("main_menu") == nil)
beforeRomDraws = romDraws
player.sprite:draw(0, 0, 0, 0, "down", 0, false, false)
assert(romDraws == beforeRomDraws + 1, "ROM mode did not delegate to the original renderer")

local romCtx = { side = "front", kind = "trainer_card", trueColor = false }
assert(hooks["player.sprite"](function() return "rom_front.png" end,
  "rom_front.png", romCtx) == "rom_front.png")
assert(romCtx.trueColor == false)

local coverage = mod.exports.auditCoverage()
assert(coverage.player.fishing.supported == false)
assert(coverage.player.front.supported == true)
assert(type(assetInvalidator) == "function")
assetInvalidator()

print("character_sprite_replacer_test: ok")
