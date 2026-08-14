-- Gen1 Character Sprite Replacer v0.1.0-alpha.8
-- Selectable FRLG Red/Leaf players plus independently selectable enemy fronts.

local VERSION = "0.1.0-alpha.8"
local THROW_FRAME_TICKS = 8
local THROW_TOTAL_TICKS = 40
local THROW_SLIDE_STEP = 2

return function(mod)
  local Assets = require("src.render.Assets")
  local Game = require("src.core.Game")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Player = require("src.world.Player")
  local BattleState = require("src.battle.BattleState")

  local compile = loadstring or load
  local function loadModule(path)
    local source, readError = mod:read(path)
    if not source then error("cannot read " .. path .. ": " .. tostring(readError), 0) end
    local chunk, compileError = compile(source, "@" .. tostring(mod.path or mod.id) .. "/" .. path)
    if not chunk then error("cannot compile " .. path .. ": " .. tostring(compileError), 0) end
    return chunk()
  end

  local PACKS = loadModule("character_packs.lua")
  local ROLE_MAP = loadModule("player_role_map.lua")
  local TRAINER_MAP = loadModule("trainer_class_map.lua")
  local STAND = { down = 0, up = 1, left = 2, right = 2 }
  local WALK = { down = 3, up = 4, left = 5, right = 5 }
  local WALK_B = { down = 6, up = 7, left = 8, right = 8 }
  local STAND_4 = { down = 0, up = 1, left = 2, right = 3 }
  local WALK_4 = { down = 4, up = 5, left = 6, right = 7 }
  local WALK_B_4 = { down = 8, up = 9, left = 10, right = 11 }

  mod.options:define({
    {
      key = "character_pack",
      type = "choice",
      label = "CHARACTER SPRITE",
      default = "frlg_red",
      choices = {
        { "FRLG RED (MALE)", "frlg_red" },
        { "FRLG LEAF (FEMALE)", "frlg_leaf" },
        { "ROM", "rom" },
      },
      help = "Choose Red, Leaf, or the original ROM player appearance. This is visual only and does not alter save gender or identity.",
    },
    {
      key = "enemy_trainer_pack",
      type = "choice",
      label = "ENEMY TRAINERS",
      default = "rom",
      choices = {
        { "ROM", "rom" },
        { "GEN 3 (FRLG)", "frlg" },
      },
      help = "Choose original ROM enemy portraits or mapped FireRed/LeafGreen trainer portraits. Unsupported special classes keep their ROM art.",
    },
  })

  local imageCache = {}
  local quadCache = {}
  local warnedDramaticShape = false
  local dramaticShapeHandle
  local dramaticAdapterInstalled = false
  local battleAdapterInstalled = false

  local function findDramaticShape()
    if dramaticShapeHandle then return dramaticShapeHandle end
    if not mod.find then return nil end
    local ok, handle = pcall(mod.find, mod, "DRAMATIC_SHAPE")
    if ok and handle then dramaticShapeHandle = handle end
    return dramaticShapeHandle
  end

  local function dramaticShapeSupportsEnhancedCharacters()
    if dramaticAdapterInstalled then return true end
    local handle = findDramaticShape()
    local exports = handle and (handle.exports or handle)
    local version = exports and (exports.characterAppearanceBillboardApiVersion
      or exports.enhancedCharacterSpriteApiVersion)
    return tonumber(version) and tonumber(version) >= 1 or false
  end

  local function incompatibleVoxelActive()
    if not findDramaticShape() or dramaticShapeSupportsEnhancedCharacters() then
      return false
    end
    local ok, level = pcall(Pipelines.level, "voxel")
    return ok and (tonumber(level) or 0) > 0
  end

  -- Dramatic Shape 1.8.0 exposes its module loader but not an enhanced sprite
  -- descriptor API. Install a surgical consumer-side mesh adapter: only defs
  -- owned by this mod are intercepted, while every ROM/NPC/other-mod sprite
  -- continues through Dramatic Shape's original functions unchanged.
  local function installDramaticShapeAdapter()
    if dramaticAdapterInstalled then return true end
    local handle = findDramaticShape()
    local exports = handle and (handle.exports or handle)
    local lib = exports and exports.lib
    if not (lib and type(lib.require) == "function") then return false end
    local okBillboards, SpriteBillboards = pcall(lib.require, "SpriteBillboards")
    local okVoxel, Voxel3D = pcall(lib.require, "Voxel3D")
    if not (okBillboards and okVoxel and type(SpriteBillboards) == "table"
        and type(Voxel3D) == "table" and type(Voxel3D.pushQuad) == "function"
        and type(Voxel3D.newMesh) == "function") then
      return false
    end

    local originalMesh = SpriteBillboards.__gen1CharacterOriginalMesh
      or SpriteBillboards.mesh
    local originalShadow = SpriteBillboards.__gen1CharacterOriginalShadowQuad
      or SpriteBillboards.shadowQuad
    local originalInvalidate = SpriteBillboards.__gen1CharacterOriginalInvalidate
      or SpriteBillboards.invalidate
    if type(originalMesh) ~= "function" or type(originalShadow) ~= "function" then
      return false
    end

    SpriteBillboards.__gen1CharacterOriginalMesh = originalMesh
    SpriteBillboards.__gen1CharacterOriginalShadowQuad = originalShadow
    SpriteBillboards.__gen1CharacterOriginalInvalidate = originalInvalidate

    local enhancedMeshes = {}
    local function ownedDescriptor(def)
      if type(def) ~= "table" or def.characterAppearanceOwner ~= mod.id
          or tonumber(def.characterAppearanceApiVersion) ~= 1 then
        return nil
      end
      local fw = tonumber(def.frameW or def.frameWidth)
      local fh = tonumber(def.frameH or def.frameHeight)
      local ax = tonumber(def.anchorX)
      local ay = tonumber(def.anchorY)
      local lw = tonumber(def.logicalFootprintW) or 16
      local lh = tonumber(def.logicalFootprintH) or 16
      if not (fw and fh and ax and ay and fw > 0 and fh > 0
          and ax >= 0 and ax <= fw and ay >= 0 and ay <= fh
          and lw == 16 and lh == 16 and type(def.image) == "string") then
        return nil
      end
      return fw, fh, ax, ay
    end

    local function buildEnhanced(def, frame, fw, fh, ax, ay, cancelLegacyMirror)
      local image = Assets.image(def.image)
      local iw, ih = image:getDimensions()
      frame = math.floor(tonumber(frame) or 0)
      local fy = frame * fh
      if fy < 0 or fy + fh > ih or fw > iw then return nil end
      local insetX = math.min(0.02, fw / 1000)
      local insetY = math.min(0.05, fh / 1000)
      local u0, u1 = insetX / iw, (fw - insetX) / iw
      if cancelLegacyMirror then u0, u1 = u1, u0 end
      local v0, v1 = (fy + insetY) / ih, (fy + fh - insetY) / ih
      -- VoxelScene's unchanged matrix centres the logical 16px cell around
      -- x=8. Offset visible geometry by the descriptor anchor; vertical
      -- coordinates put anchorY exactly on the ground plane.
      local left, right = 8 - ax, 8 - ax + fw
      local bottom, top = ay - fh, ay
      local verts = {
        { left, bottom, 0, u0, v1, 1 },
        { right, bottom, 0, u1, v1, 1 },
        { right, top, 0, u1, v0, 1 },
        { left, top, 0, u0, v0, 1 },
      }
      local indices = {}
      Voxel3D.pushQuad(indices, 0)
      return Voxel3D.newMesh(verts, indices)
    end

    local function ownedMesh(def, frame)
      local fw, fh, ax, ay = ownedDescriptor(def)
      if not fw then return nil, false end
      frame = tonumber(def.characterAppearanceFrame) or frame
      local cancelLegacyMirror = def.characterAppearanceCancelLegacyMirror == true
      local key = table.concat({ def.image, frame or 0, fw, fh, ax, ay,
        cancelLegacyMirror and 1 or 0 }, "#")
      if enhancedMeshes[key] == nil then
        local ok, mesh = pcall(buildEnhanced, def, frame, fw, fh, ax, ay,
          cancelLegacyMirror)
        enhancedMeshes[key] = (ok and mesh) or false
      end
      return enhancedMeshes[key] or nil, true
    end

    local function enhancedMesh(def, frame)
      local mesh, owned = ownedMesh(def, frame)
      if owned then return mesh end
      return originalMesh(def, frame)
    end

    local function enhancedShadow(def, frame)
      local mesh, owned = ownedMesh(def, frame)
      if owned then return mesh end
      return originalShadow(def, frame)
    end

    SpriteBillboards.mesh = enhancedMesh
    SpriteBillboards.shadowQuad = enhancedShadow
    SpriteBillboards.invalidate = function(...)
      enhancedMeshes = {}
      if type(originalInvalidate) == "function" then return originalInvalidate(...) end
    end
    if Assets.register then Assets.register(function() enhancedMeshes = {} end) end
    SpriteBillboards.__gen1CharacterAppearanceAdapterVersion = 1
    dramaticAdapterInstalled = true
    warnedDramaticShape = false
    local player = Game and Game.overworld and Game.overworld.player
    for _, key in ipairs({ "sprite", "bikeSprite", "surfSprite" }) do
      local roleSprite = player and player[key]
      if roleSprite and type(roleSprite.selection) == "function" then
        pcall(roleSprite.selection, roleSprite)
      end
    end
    mod.log:info("Character Sprite Replacer: installed scoped Dramatic Shape enhanced-billboard adapter")
    return true
  end

  local function activePackId()
    local id = mod.options:get("character_pack")
    return PACKS[id] and id or "rom"
  end

  local function activePack()
    return PACKS[activePackId()] or PACKS.rom
  end

  local function activeTrainerPackId()
    return mod.options:get("enemy_trainer_pack") == "frlg" and "frlg" or "rom"
  end

  local function trainerKey(trainer, oppClass)
    local id = oppClass or (trainer and trainer.id)
    -- Yellow's Jessie/James share OPP_ROCKET but have a distinct paired
    -- portrait not present on this sheet. Keep every Rocket ROM-owned in a
    -- Yellow cache that exposes that special portrait, avoiding a mismatch.
    if id == "OPP_ROCKET" and trainer and trainer.picJessieJames then return nil end
    return TRAINER_MAP[id], id
  end

  local function trainerDescriptor(trainerClass)
    if activeTrainerPackId() ~= "frlg" then return nil end
    local name = TRAINER_MAP[trainerClass]
    if not name then return nil end
    return {
      owner = mod.id,
      apiVersion = 1,
      packId = "frlg",
      trainerClass = trainerClass,
      imagePath = mod.assets:path("frlg_trainer_" .. name .. ".png"),
      trueColor = true,
      frameW = 64,
      frameH = 64,
      frameCount = 1,
      anchorX = 32,
      anchorY = 64,
      fallback = false,
    }
  end

  local function descriptor(role)
    local pack = activePack()
    local source = pack and pack.player and pack.player[role]
    if not source then return nil end
    return {
      owner = mod.id,
      apiVersion = 1,
      packId = pack.id,
      subjectId = "PLAYER",
      role = role,
      imagePath = mod.assets:path(source.path),
      trueColor = true,
      frameW = source.frameW,
      frameH = source.frameH,
      frameCount = source.frames,
      layout = source.frames == 12 and "frlg-twelve-pose"
        or source.frames == 9 and "gen1-nine-pose"
        or (source.frames == 6 and "gen1-six-pose" or "static"),
      anchorX = source.anchorX,
      anchorY = source.anchorY,
      logicalFootprintW = 16,
      logicalFootprintH = 16,
      fallback = false,
      genderPresentation = pack.genderPresentation,
    }
  end

  local function imageFor(desc)
    if not desc then return nil end
    local path = desc.imagePath
    if imageCache[path] == nil then
      local ok, image = pcall(Assets.image, path)
      if ok and image then
        image:setFilter("nearest", "nearest")
        if image.setWrap then image:setWrap("clamp", "clamp") end
        imageCache[path] = image
      else
        imageCache[path] = false
        mod.log:warn("Character Sprite Replacer: missing player asset %s; using ROM fallback", tostring(path))
      end
    end
    return imageCache[path] or nil
  end

  local function throwImages()
    local pack = activePackId()
    local stem = pack == "frlg_red" and "red"
      or (pack == "frlg_leaf" and "leaf" or nil)
    if not stem then return nil end
    local frames = {}
    for index = 1, 5 do
      local image = imageFor({
        imagePath = mod.assets:path("frlg_" .. stem .. "_throw_" .. index .. ".png"),
      })
      if not image then return nil end
      frames[index] = image
    end
    return frames
  end

  local function widescreenOwnsTrainerBack()
    if not mod.find then return false end
    local ok, handle = pcall(mod.find, mod, "gen1_widescreen_ui")
    local exports = ok and handle and (handle.exports or handle)
    local owns = exports and exports.ownsBattleTrainerBack
    if type(owns) ~= "function" then return false end
    local ownsOk, active = pcall(owns)
    return ownsOk and active == true
  end

  -- BattleState exposes trainer path/palette resolution and the player-back
  -- slide as public methods, but no live trainer-art hook or throw-frame
  -- provider. Wrap only those seams. The original behavior remains exact
  -- for ROM mode, unmapped classes, demos, and every unrelated battle pic.
  local function installBattleAdapter()
    if battleAdapterInstalled then return true end
    if type(BattleState) ~= "table" then return false end
    local originalTrainerPicPath = BattleState.__gen1CharacterOriginalTrainerPicPath
      or BattleState.trainerPicPath
    local originalTrainerPalette = BattleState.__gen1CharacterOriginalTrainerPalette
      or BattleState.trainerPalette
    local originalSlidePic = BattleState.__gen1CharacterOriginalSlidePic
      or BattleState.slidePic
    local originalUpdateFx = BattleState.__gen1CharacterOriginalUpdateFx
      or BattleState.updateFx
    local originalDrawPicsLayer = BattleState.__gen1CharacterOriginalDrawPicsLayer
      or BattleState.drawPicsLayer
    if type(originalTrainerPicPath) ~= "function"
        or type(originalTrainerPalette) ~= "function"
        or type(originalSlidePic) ~= "function"
        or type(originalUpdateFx) ~= "function"
        or type(originalDrawPicsLayer) ~= "function" then
      return false
    end

    BattleState.__gen1CharacterOriginalTrainerPicPath = originalTrainerPicPath
    BattleState.__gen1CharacterOriginalTrainerPalette = originalTrainerPalette
    BattleState.__gen1CharacterOriginalSlidePic = originalSlidePic
    BattleState.__gen1CharacterOriginalUpdateFx = originalUpdateFx
    BattleState.__gen1CharacterOriginalDrawPicsLayer = originalDrawPicsLayer

    BattleState.trainerPicPath = function(data, trainer, oppClass, partyIndex)
      local original = originalTrainerPicPath(data, trainer, oppClass, partyIndex)
      if activeTrainerPackId() ~= "frlg" then return original end
      local mapped, id = trainerKey(trainer, oppClass)
      local desc = mapped and trainerDescriptor(id)
      return desc and desc.imagePath or original
    end

    BattleState.trainerPalette = function(data, trainer)
      local mapped = activeTrainerPackId() == "frlg" and trainerKey(trainer)
      if mapped then return nil end -- preserve the supplied true-color pixels
      return originalTrainerPalette(data, trainer)
    end

    BattleState.slidePic = function(self, slot, from, to, step)
      local startsThrow = slot == "back" and to ~= nil
        and tonumber(to) and tonumber(to) < 0
        and not self.demo and not self.safari
      -- Keep the five authored poses visible for eight updates each. The
      -- stock 18-frame/4-pixel slide would otherwise finish before a slower
      -- animation could reach its last pose.
      local result = originalSlidePic(self, slot, from, to,
        startsThrow and THROW_SLIDE_STEP or step)
      if startsThrow
          and not self.demo and not self.safari then
        local frames = throwImages()
        if frames then
          self.characterAppearanceThrow = { frames = frames, tick = 0, index = 1 }
          local nextRow = self.queue and self.queue[1]
          if nextRow and nextRow.wait == 18 then
            nextRow.wait = THROW_TOTAL_TICKS
          end
        end
      elseif slot == "back" and to == nil then
        self.characterAppearanceThrow = nil
      end
      return result
    end

    BattleState.updateFx = function(self, ...)
      local result = originalUpdateFx(self, ...)
      local anim = self.characterAppearanceThrow
      if anim then
        anim.tick = anim.tick + 1
        anim.index = math.min(#anim.frames,
          math.floor((anim.tick - 1) / THROW_FRAME_TICKS) + 1)
      end
      return result
    end

    BattleState.drawPicsLayer = function(self, slide, sx, sy, onlySide, skipMenuClip)
      local anim = self.characterAppearanceThrow
      local showPlayerBack = self.showPlayerBack
      local replacesPlayer = anim and showPlayerBack and anim.frames[anim.index]
      if replacesPlayer then self.showPlayerBack = false end
      local result = { pcall(originalDrawPicsLayer, self, slide, sx, sy,
        onlySide, skipMenuClip)
      }
      self.showPlayerBack = showPlayerBack
      if not result[1] then error(result[2], 0) end
      if not replacesPlayer then return result[2] end
      -- Widescreen removes the arena billboard and draws the live throw in
      -- its final HUD pass. Do not draw a second copy into the battle layer.
      if widescreenOwnsTrainerBack() then return result[2] end
      if onlySide == "enemy" then return end
      local image = anim.frames[anim.index]
      local x = 8 + (slide or 0) + (sx or 0)
        + (type(self.picOffset) == "function" and self:picOffset("back") or 0)
      local y = 96 - image:getHeight() + (sy or 0)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(image, x, y)
    end

    BattleState.__gen1CharacterBattleAdapterVersion = 1
    battleAdapterInstalled = true
    mod.log:info("Character Sprite Replacer: installed scoped battle trainer/throw adapter")
    return true
  end

  if mod.content and mod.content.battle_sprite_scales
      and type(mod.content.battle_sprite_scales.register) == "function" then
    for _, pack in ipairs({ "red", "leaf" }) do
      local backPath = mod.assets:path("frlg_" .. pack .. "_back.png")
      mod.content.battle_sprite_scales:register("frlg_" .. pack .. "_player_back",
        { path = backPath, scale = 1 })
      for index = 1, 5 do
        local path = mod.assets:path("frlg_" .. pack .. "_throw_" .. index .. ".png")
        mod.content.battle_sprite_scales:register(
          "frlg_" .. pack .. "_player_throw_" .. index,
          { path = path, scale = 1 })
      end
    end
  end

  local function invalidate()
    imageCache = {}
    quadCache = {}
  end
  if Assets.register then Assets.register(invalidate) end

  local RoleSprite = {}
  RoleSprite.__index = function(self, key)
    -- Dramatic Shape reads sprite.def BEFORE resolveImage(). Make the public
    -- definition itself dynamic so its first voxel frame sees the matching
    -- ROM definition and ROM texture together, never an enhanced definition
    -- paired with a fallback texture.
    if key == "def" then
      if incompatibleVoxelActive() then
        return self.rom and self.rom.def or rawget(self, "_def")
      end
      return rawget(self, "_def") or (self.rom and self.rom.def)
    end
    return RoleSprite[key]
  end

  function RoleSprite.new(role, rom)
    return setmetatable({ role = role, rom = rom, _def = rom and rom.def }, RoleSprite)
  end

  function RoleSprite:selection()
    -- If the scoped adapter cannot be installed, retain alpha 2's exact ROM
    -- safety fallback. Never feed enhanced frames into an incompatible mesh.
    if incompatibleVoxelActive() then
      self._def = self.rom and self.rom.def or self._def
      return nil, nil
    end
    local desc = descriptor(self.role)
    local image = imageFor(desc)
    if not (desc and image) then
      self._def = self.rom and self.rom.def or self._def
      return nil, nil
    end
    local previousDef = self._def
    self._def = {
      id = "GEN1_CHARACTER_PLAYER_" .. self.role:upper(),
      image = desc.imagePath,
      frames = desc.frameCount,
      layout = desc.layout,
      walker = true,
      trueColor = true,
      frameWidth = desc.frameW,
      frameHeight = desc.frameH,
      frameW = desc.frameW,
      frameH = desc.frameH,
      anchorX = desc.anchorX,
      anchorY = desc.anchorY,
      logicalFootprintW = 16,
      logicalFootprintH = 16,
      characterAppearanceApiVersion = 1,
      characterAppearanceOwner = mod.id,
      characterAppearanceFrame = previousDef
        and previousDef.characterAppearanceFrame or 0,
      characterAppearanceFacing = previousDef
        and previousDef.characterAppearanceFacing or "down",
      characterAppearanceStepB = previousDef
        and previousDef.characterAppearanceStepB or false,
      characterAppearanceCancelLegacyMirror = previousDef
        and previousDef.characterAppearanceCancelLegacyMirror or false,
    }
    return desc, image
  end

  -- Player.pose exposes the engine's otherwise-private alternate-foot flag.
  -- Store a fully resolved authored frame on this mod's live definition so
  -- native 2D and Dramatic Shape consume the same authored pose cycle.
  function RoleSprite:setAppearancePose(facing, walkPhase, stepFlip)
    local desc = descriptor(self.role)
    if not desc or desc.frameCount < 6 then return end
    if not (self._def and self._def.characterAppearanceOwner == mod.id) then
      self:selection()
    end
    local def = self._def
    if not (def and def.characterAppearanceOwner == mod.id) then return end
    local walking = walkPhase == 1
    local useAuthoredStepB = walking and stepFlip and desc.frameCount >= 9
    local fourDirections = desc.frameCount >= 12
    local poses = fourDirections
      and (not walking and STAND_4 or (useAuthoredStepB and WALK_B_4 or WALK_4))
      or (not walking and STAND or (useAuthoredStepB and WALK_B or WALK))
    def.characterAppearanceFrame = poses[facing] or 0
    def.characterAppearanceFacing = facing
    def.characterAppearanceStepB = useAuthoredStepB
    -- Dramatic Shape mirrors the old two-frame down/up walk in its matrix.
    -- Pre-flip only those authored B frames so the final result is unmirrored.
    def.characterAppearanceCancelLegacyMirror = (fourDirections and facing == "right")
      or (useAuthoredStepB and (facing == "up" or facing == "down")) or false
  end

  function RoleSprite:resolveImage()
    local _, image = self:selection()
    if image then return image end
    return self.rom and self.rom.resolveImage and self.rom:resolveImage() or nil
  end

  local function frameQuad(desc, image, frame)
    local key = desc.imagePath .. "#" .. tostring(frame)
    if not quadCache[key] then
      local iw, ih = image:getDimensions()
      quadCache[key] = love.graphics.newQuad(0, frame * desc.frameH,
        desc.frameW, desc.frameH, iw, ih)
    end
    return quadCache[key]
  end

  function RoleSprite:draw(px, py, camX, camY, facing, walkPhase, stepFlip, topHalf)
    -- Fishing is a ROM-local composition: an 8px hand tile plus a separately
    -- positioned rod effect. The supplied FRLG frames include a full rod, so
    -- replacing only one half would either double or sever it.
    if topHalf then
      if self.rom and self.rom.draw then
        return self.rom:draw(px, py, camX, camY, facing, walkPhase, stepFlip, topHalf)
      end
      return
    end
    local desc, image = self:selection()
    if not (desc and image) then
      if self.rom and self.rom.draw then
        return self.rom:draw(px, py, camX, camY, facing, walkPhase, stepFlip, topHalf)
      end
      return
    end
    local useAuthoredStepB = walkPhase == 1 and stepFlip and desc.frameCount >= 9
    local fourDirections = desc.frameCount >= 12
    local tableForPose = fourDirections
      and (walkPhase ~= 1 and STAND_4 or (useAuthoredStepB and WALK_B_4 or WALK_4))
      or (walkPhase ~= 1 and STAND or (useAuthoredStepB and WALK_B or WALK))
    local frame = tableForPose[facing] or 0
    local flip = (not fourDirections and facing == "right")
      or (desc.frameCount < 9 and walkPhase == 1 and stepFlip
        and (facing == "up" or facing == "down"))
    local cellX = math.floor(px - camX)
    local cellBottom = math.floor(py - camY) + 12
    local x = cellX + math.floor((16 - desc.frameW) / 2)
    local y = cellBottom - desc.frameH
    local quad = frameQuad(desc, image, frame)
    love.graphics.setColor(1, 1, 1, 1)
    if flip then
      love.graphics.draw(image, quad, x + desc.frameW, y, 0, -1, 1)
    else
      love.graphics.draw(image, quad, x, y)
    end
    if PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(x, y, desc.frameW, desc.frameH)
    end
  end

  function RoleSprite:drawTile(path, x, y, flip)
    if self.rom and self.rom.drawTile then return self.rom:drawTile(path, x, y, flip) end
  end

  local function wrapRole(player, key, role)
    local current = player and player[key]
    if not current then return end
    if getmetatable(current) == RoleSprite then return end
    player[key] = RoleSprite.new(role, current)
  end

  local function installPlayerRenderers()
    local player = Game and Game.overworld and Game.overworld.player
    if not player then return false end
    wrapRole(player, "sprite", "walk")
    wrapRole(player, "bikeSprite", "bike")
    wrapRole(player, "surfSprite", "surf")
    for _, key in ipairs({ "sprite", "bikeSprite", "surfSprite" }) do
      local roleSprite = player[key]
      if roleSprite and type(roleSprite.selection) == "function" then
        pcall(roleSprite.selection, roleSprite)
      end
    end
    -- surfPikachuSprite, Fly bird, and fishing composition keep their owner.
    return true
  end

  local function installPlayerPoseAdapter()
    if type(Player) ~= "table" or type(Player.pose) ~= "function" then return false end
    if Player.__gen1CharacterNinePoseWrapped then return true end
    local originalPose = Player.pose
    Player.pose = function(self, ...)
      local sprite, px, py, facing, walkPhase, stepFlip, topHalf = originalPose(self, ...)
      if sprite and type(sprite.setAppearancePose) == "function" then
        pcall(sprite.setAppearancePose, sprite, facing, walkPhase, stepFlip)
      end
      return sprite, px, py, facing, walkPhase, stepFlip, topHalf
    end
    Player.__gen1CharacterNinePoseWrapped = true
    Player.__gen1CharacterOriginalPose = originalPose
    return true
  end

  local function checkDramaticShape()
    if warnedDramaticShape or activePackId() == "rom" then return end
    if incompatibleVoxelActive() then
      warnedDramaticShape = true
      mod.log:warn("Character Sprite Replacer: Dramatic Shape voxel mode lacks enhanced player-frame support; overworld roles are using ROM art until its owner-side descriptor integration is available")
    end
  end

  mod.hooks:wrap("player.sprite", function(next, path, ctx)
    local original = next(path, ctx)
    if activePackId() == "rom" or not ctx or ctx.demo or ctx.oakDemo then
      return original
    end
    local role = ctx.side == "back" and "back" or "front"
    local desc = descriptor(role)
    if not (desc and imageFor(desc)) then return original end
    ctx.trueColor = true
    return desc.imagePath
  end)

  if mod.events and mod.events.on then
    mod.events:on("mods.loaded", function()
      installDramaticShapeAdapter()
      installBattleAdapter()
      checkDramaticShape()
    end)
    mod.events:on("game.ready", function()
      installDramaticShapeAdapter()
      installBattleAdapter()
      installPlayerRenderers()
      checkDramaticShape()
    end)
    mod.events:on("map.entered", installPlayerRenderers)
    mod.events:on("mod.options_changed", function(payload)
      if payload and payload.mod == mod.id then
        invalidate()
        installDramaticShapeAdapter()
        installBattleAdapter()
        installPlayerRenderers()
        checkDramaticShape()
      end
    end)
  end

  installPlayerPoseAdapter()
  installBattleAdapter()

  mod.exports.version = VERSION
  mod.exports.characterAppearanceApiVersion = 1
  mod.exports.activePack = activePackId
  mod.exports.activeTrainerPack = activeTrainerPackId
  mod.exports.resolvePlayerOverworld = function(role)
    if role == "fishing" or role == "surfPikachu" or role == "fly" then return nil end
    return descriptor(role)
  end
  mod.exports.resolveNpcOverworld = function() return nil end
  mod.exports.resolveTrainerOverworld = function() return nil end
  mod.exports.resolveTrainerBattle = function(trainerClass)
    return trainerDescriptor(trainerClass)
  end
  mod.exports.resolvePlayerBattle = function(role)
    if role ~= "front" and role ~= "back" then return nil end
    return descriptor(role)
  end
  mod.exports.resolvePlayerPresentation = function(role)
    if role == "main_menu" or role == "start_menu" or role == "continue" then
      return descriptor("main_menu")
    end
    if role == "trainer_card" or role == "hall_of_fame" or role == "intro" then
      return descriptor("front")
    end
    return nil
  end
  mod.exports.invalidate = invalidate
  mod.exports.auditCoverage = function()
    return {
      packId = activePackId(),
      enemyTrainerPackId = activeTrainerPackId(),
      player = ROLE_MAP,
      supported = { "walk", "bike", "surf", "front", "back", "main_menu_provider" },
      fallback = { "fishing", "surfPikachu", "fly" },
      excluded = { "npc", "trainer_overworld" },
      trainerBattleMapped = TRAINER_MAP,
    }
  end

  mod.log:info("Gen1 Character Sprite Replacer %s ready (ROM / FRLG Red / FRLG Leaf)", VERSION)
end
