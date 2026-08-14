local sent = {}
local currentShader = {}
function currentShader:send(name, value)
  sent[#sent + 1] = { name, value }
end

love = {
  graphics = {
    getShader = function() return currentShader end,
  },
}

local battleMesh = {}
local otherMesh = {}
local shadowActive = true
local nativeCalls = {}

local Voxel3D = {
  SHADOW_ALPHA = 0.42,
  tint = { 0.62, 0.70, 0.81 },
  draw = function(mesh, texture, model, pull, sunModel)
    nativeCalls[#nativeCalls + 1] = {
      mesh = mesh, texture = texture, model = model,
      pull = pull, sunModel = sunModel,
    }
    return "native-result"
  end,
}
local BattleBillboard = { mesh = function() return battleMesh end }
local ShadowMap = { active = function() return shadowActive end }

local modules = {
  Voxel3D = Voxel3D,
  BattleBillboard = BattleBillboard,
  ShadowMap = ShadowMap,
}

local logs = {}
local mod = {
  id = "dramatic_shape_battle_shadow_patch",
  exports = {},
  log = {
    info = function(_, message) logs[#logs + 1] = message end,
    warn = function(_, message) logs[#logs + 1] = message end,
  },
  find = function(_, id)
    assert(id == "DRAMATIC_SHAPE")
    return {
      version = "1.8.0",
      exports = {
        lib = { require = function(name) return assert(modules[name]) end },
      },
    }
  end,
}

assert(loadfile("dramatic_shape_battle_shadow_patch/main.lua"))(mod)
local state = mod.exports.status()
assert(state.active and state.reason == "installed")
assert(state.dramaticShapeVersion == "1.8.0")

-- Unrelated geometry passes straight through without touching scene light.
assert(Voxel3D.draw(otherMesh, "terrain", "model") == "native-result")
assert(#sent == 0 and #nativeCalls == 1)

-- The battle card alone disables received shadows and world tint, then
-- restores the exact arena values immediately after the underlying draw.
assert(Voxel3D.draw(battleMesh, "pikachu", "model", 1.5, "sun-model")
  == "native-result")
assert(#nativeCalls == 2)
assert(#sent == 4)
assert(sent[1][1] == "sunDark" and sent[1][2] == 0)
assert(sent[2][1] == "dayTint"
  and sent[2][2][1] == 1 and sent[2][2][2] == 1 and sent[2][2][3] == 1)
assert(sent[3][1] == "dayTint" and sent[3][2] == Voxel3D.tint)
assert(sent[4][1] == "sunDark" and sent[4][2] == 0.42)
assert(nativeCalls[2].sunModel == "sun-model")

-- Even without a shadow map, the battle card still needs neutral source/menu
-- colors; only dayTint is changed and restored.
shadowActive = false
assert(Voxel3D.draw(battleMesh, "pikachu") == "native-result")
assert(#sent == 6 and #nativeCalls == 3)
assert(sent[5][1] == "dayTint" and sent[5][2][1] == 1)
assert(sent[6][1] == "dayTint" and sent[6][2] == Voxel3D.tint)

-- Reloading replaces the old wrapper instead of nesting it. One card draw
-- must still produce exactly one disable/restore pair and one native call.
assert(loadfile("dramatic_shape_battle_shadow_patch/main.lua"))(mod)
shadowActive = true
local sentBefore, callsBefore = #sent, #nativeCalls
Voxel3D.draw(battleMesh, "pikachu")
assert(#sent == sentBefore + 4)
assert(#nativeCalls == callsBefore + 1)

print("dramatic_shape_battle_shadow_patch tests passed")
