-- Dramatic Shape Battle Sprite Lighting Patch v0.2.0
--
-- Battle Pokemon are alpha-cutout cards in Dramatic Shape 1.8.x. They need
-- to cast shadows onto the arena, but allowing the same zero-thickness card
-- to receive its shadow-map result can produce diagonal self-shadow bands.
-- Dramatic Shape also multiplies those provider textures by the world's
-- time-of-day tint, while menus draw the same images at neutral white. This
-- companion suppresses both lighting transforms for that one mesh.

local mod = ...
local VERSION = "0.2.0"
local OWNER_KEY = "__dramaticShapeBattleShadowPatchOwner"
local WRAPPER_KEY = "__dramaticShapeBattleShadowPatchWrapper"
local BASE_KEY = "__dramaticShapeBattleShadowPatchBaseDraw"

local status = {
  active = false,
  reason = "not installed",
  dramaticShapeVersion = nil,
}

local function log(level, message, ...)
  local logger = mod.log and mod.log[level]
  if type(logger) == "function" then
    pcall(logger, mod.log, message, ...)
  end
end

local function findDramaticShape()
  if type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, mod, "DRAMATIC_SHAPE")
  if ok and type(handle) == "table" then return handle end
  return nil
end

local function install()
  local handle = findDramaticShape()
  if not handle then
    status.reason = "Dramatic Shape is unavailable"
    log("warn", "Battle Shadow Patch: Dramatic Shape is unavailable")
    return false
  end

  local version = tostring(handle.version
    or (handle.exports and handle.exports.version) or "")
  status.dramaticShapeVersion = version
  if not version:match("^1%.8%.") then
    status.reason = "unsupported Dramatic Shape version " .. version
    log("warn", "Battle Shadow Patch supports Dramatic Shape 1.8.x; found %s",
      version ~= "" and version or "unknown")
    return false
  end

  local lib = handle.exports and handle.exports.lib
  if type(lib) ~= "table" or type(lib.require) ~= "function" then
    status.reason = "missing exported companion namespace"
    log("warn", "Battle Shadow Patch: Dramatic Shape %s has no companion namespace",
      version)
    return false
  end

  local okVoxel, Voxel3D = pcall(lib.require, "Voxel3D")
  local okBillboard, BattleBillboard = pcall(lib.require, "BattleBillboard")
  local okShadow, ShadowMap = pcall(lib.require, "ShadowMap")
  if not okVoxel or type(Voxel3D) ~= "table"
      or type(Voxel3D.draw) ~= "function"
      or not okBillboard or type(BattleBillboard) ~= "table"
      or type(BattleBillboard.mesh) ~= "function"
      or not okShadow or type(ShadowMap) ~= "table"
      or type(ShadowMap.active) ~= "function" then
    status.reason = "incompatible Dramatic Shape rendering surface"
    log("warn", "Battle Shadow Patch: Dramatic Shape %s rendering surface is incompatible",
      version)
    return false
  end

  -- Hot reload replaces our own prior wrapper instead of stacking another.
  local baseDraw = Voxel3D.draw
  if Voxel3D[OWNER_KEY] == mod.id
      and baseDraw == Voxel3D[WRAPPER_KEY]
      and type(Voxel3D[BASE_KEY]) == "function" then
    baseDraw = Voxel3D[BASE_KEY]
  end

  local battleMesh = BattleBillboard.mesh()
  if not battleMesh then
    status.reason = "battle billboard mesh is unavailable"
    log("warn", "Battle Shadow Patch: Dramatic Shape battle mesh is unavailable")
    return false
  end

  local function patchedDraw(mesh, texture, model, pull, sunModel)
    if mesh ~= battleMesh or not (love and love.graphics
          and type(love.graphics.getShader) == "function") then
      return baseDraw(mesh, texture, model, pull, sunModel)
    end

    local shader = love.graphics.getShader()
    if not shader or type(shader.send) ~= "function" then
      return baseDraw(mesh, texture, model, pull, sunModel)
    end

    -- Only the receiver is unlit. Dramatic Shape creates cast shadows through
    -- ShadowMap.draw, so Pokemon silhouettes still land on the arena. Menus
    -- draw these same provider textures at neutral white; temporarily using a
    -- neutral day tint keeps the in-world card's source colors identical.
    local shadowDisabled = false
    if ShadowMap.active() then
      shadowDisabled = pcall(shader.send, shader, "sunDark", 0)
    end
    local tintNeutralized = pcall(shader.send, shader, "dayTint", { 1, 1, 1 })
    if not shadowDisabled and not tintNeutralized then
      return baseDraw(mesh, texture, model, pull, sunModel)
    end

    local result = { pcall(baseDraw, mesh, texture, model, pull, sunModel) }
    if tintNeutralized then
      pcall(shader.send, shader, "dayTint", Voxel3D.tint or { 1, 1, 1 })
    end
    if shadowDisabled then
      pcall(shader.send, shader, "sunDark", Voxel3D.SHADOW_ALPHA or 0)
    end
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2)
  end

  Voxel3D[OWNER_KEY] = mod.id
  Voxel3D[BASE_KEY] = baseDraw
  Voxel3D[WRAPPER_KEY] = patchedDraw
  Voxel3D.draw = patchedDraw
  status.active = true
  status.reason = "installed"
  log("info", "Battle Sprite Lighting Patch %s installed for Dramatic Shape %s",
    VERSION, version)
  return true
end

install()

mod.exports.version = VERSION
mod.exports.status = function()
  return {
    active = status.active,
    reason = status.reason,
    dramaticShapeVersion = status.dramaticShapeVersion,
  }
end
