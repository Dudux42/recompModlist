local hooks, events, optionDefs = {}, {}, {}
local optionValues = { pokemon_art = "gen5", battle_art = "static" }
local loadedPaths, failPaths = {}, {}
local dramaticFront = false
local frameNumber = 0
local assetInvalidator
local providerTime = 100
local battlePics = {
  filled = function(img) return { filledFrom = img } end,
}

local function imageObject(path)
  local image = { path = path }
  function image:setFilter(min, mag) self.minFilter, self.magFilter = min, mag end
  function image:setWrap(x, y) self.wrapX, self.wrapY = x, y end
  return image
end

package.preload["src.render.Assets"] = function()
  return {
    image = function(path)
      loadedPaths[#loadedPaths + 1] = path
      if failPaths[path] then error("missing fixture") end
      return imageObject(path)
    end,
    register = function(fn) assetInvalidator = fn end,
  }
end

package.preload["src.pokemon.Stats"] = function()
  return { isShiny = function(dvs) return dvs == "shiny-dvs" end }
end

local BattleState = {
  update = function(self) self.nativeUpdates = (self.nativeUpdates or 0) + 1 end,
  resolveBattleScale = function(_, side) return side == "back" and 2 or 1 end,
}
package.preload["src.battle.BattleState"] = function() return BattleState end

love = {
  timer = { getTime = function() return providerTime end },
  filesystem = {
    load = function()
      return function()
        return {
          [25] = { width = 2, height = 2, columns = 2, frames = 2,
            durations = { 50, 100 } },
          [123] = { width = 2, height = 2, columns = 2, frames = 2,
            durations = { 50, 100 },
            shiny = { width = 3, height = 2, columns = 1, frames = 3,
              durations = { 30, 40, 50 } } },
          hgss = { columns = 2, frames = 2, durations = { 500, 500 } },
          platinum = { columns = 2, frames = 2, durations = { 500, 500 } },
          emerald = { columns = 2, frames = 2, durations = { 500, 500 } },
        }
      end
    end,
  },
  image = {
    newImageData = function(a, b)
      local shinyScyther = type(a) == "string"
        and a:find("front_123_shiny.png", 1, true)
      local data = { width = type(a) == "string" and (shinyScyther and 3 or 4) or a,
        height = type(a) == "string" and (shinyScyther and 6 or 2) or b,
        sourcePath = type(a) == "string" and a or nil }
      function data:getDimensions() return self.width, self.height end
      function data:paste(sheet) self.sourcePath = sheet.sourcePath end
      return data
    end,
  },
  graphics = {
    newImage = function(data)
      frameNumber = frameNumber + 1
      local image = imageObject(data.sourcePath)
      image.frame = frameNumber
      return image
    end,
  },
}

local mod = {
  id = "gen1_battle_art_replacer",
  assets = { path = function(_, rel) return "mod/" .. rel end },
  options = {
    define = function(_, defs) optionDefs = defs end,
    get = function(_, key) return optionValues[key] end,
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  exports = {},
  log = { info = function() end },
  find = function(_, id)
    if id ~= "DRAMATIC_SHAPE" then return nil end
    return { exports = { lib = { require = function(name)
      if name == "BattlePics" then return battlePics end
      assert(name == "OverworldBattle")
      return { wantsFront = function() return dramaticFront end }
    end } } }
  end,
}

assert(loadfile("gen1_battle_art_replacer/main.lua"))()(mod)
assert(#optionDefs == 2)
assert(optionDefs[1].key == "battle_art" and optionDefs[2].key == "pokemon_art")
assert(optionDefs[2].choices[2][2] == "gen4Platinum")
assert(optionDefs[2].choices[4][2] == "gen3Emerald")
assert(optionDefs[2].choices[5][2] == "gen3FRLG")
assert(optionDefs[2].choices[6][2] == "gen2Crystal")
assert(mod.exports.presentationApiVersion == 1)
assert(type(mod.exports.resolvePokemonPresentation) == "function")
assert(type(mod.exports.resolvePokemonImage) == "function")
assert(type(assetInvalidator) == "function")

local data = { pokemon = {
  PIKACHU = { dex = 25, spriteFront = "rom-front.png", spriteBack = "rom-back.png" },
  RAICHU = { dex = 26, spriteFront = "raichu-front.png", spriteBack = "raichu-back.png" },
  SCYTHER = { dex = 123, spriteFront = "scyther-front.png", spriteBack = "scyther-back.png" },
} }
local game = { data = data }
local normal = { species = "PIKACHU" }
local lightweight = { species = "PIKACHU" }
local shinyFlag = { species = "PIKACHU", shiny = true }
local shinyDVs = { species = "PIKACHU", dvs = "shiny-dvs" }
local missing = { species = "RAICHU" }
local shinyScyther = { species = "SCYTHER", shiny = true }

local function presentation(mon, side, token, now, purpose)
  return mod.exports.resolvePokemonPresentation(game, mon, side or "front", {
    purpose = purpose or "summary", token = token, now = now,
  })
end

-- STATIC: stable neutral images, lightweight Pokemon support, true color and
-- nearest-neighbor filtering.
local staticToken = {}
local staticA = presentation(normal, "front", staticToken, 1, "title")
local staticB = presentation(lightweight, "front", staticToken, 2, "pokedex")
assert(staticA and staticA.image == staticB.image)
assert(staticA.animated == false and staticA.mode == "static"
       and staticA.artSet == "gen5" and staticA.trueColor == true)
assert(staticA.image.path == "mod/pokemon_static_gen5_front_025.png")
assert(staticA.image.minFilter == "nearest" and staticA.image.magFilter == "nearest")
assert(battlePics.filled(staticA.image) == staticA.image,
  "Dramatic Shape filled an intentional true-color opening")
local foreignImage = imageObject("rom.png")
assert(battlePics.filled(foreignImage).filledFrom == foreignImage,
  "Dramatic Shape native-paper restoration was disabled for foreign art")
local staticShiny = presentation(shinyFlag, "front", {}, 1, "party")
local staticDvShiny = presentation(shinyDVs, "front", {}, 1, "summary")
assert(staticShiny.image.path:find("025_shiny.png", 1, true))
assert(staticDvShiny.image.path:find("025_shiny.png", 1, true))

-- HGSS resolves distinct normal/shiny fronts and its supplied two-pose sheet
-- animates on the provider-owned 500 ms cadence.
optionValues.pokemon_art, optionValues.battle_art = "gen4HGSS", "static"
local hgssStill = presentation(normal, "front", {}, 1, "summary")
local hgssShiny = presentation(shinyFlag, "front", {}, 1, "party")
assert(hgssStill.image.path == "mod/pokemon_static_gen4HGSS_front_025.png")
assert(hgssShiny.image.path == "mod/pokemon_static_gen4HGSS_front_025_shiny.png")
optionValues.battle_art = "animated"
local hgssToken = {}
local hgss0 = presentation(normal, "front", hgssToken, 20.000, "title")
local hgss499 = presentation(normal, "front", hgssToken, 20.499, "title")
local hgss501 = presentation(normal, "front", hgssToken, 20.501, "title")
assert(hgss0.animated and hgss0.frameIndex == 1 and hgss0.artSet == "gen4HGSS")
assert(hgss499.frameIndex == 1 and hgss501.frameIndex == 2)

-- Platinum supplies only the base male/unisex front pair (no redundant
-- female variants) and supports the same static/provider-timed modes.
optionValues.pokemon_art, optionValues.battle_art = "gen4Platinum", "static"
local platinumStill = presentation(normal, "front", {}, 1, "summary")
local platinumShiny = presentation(shinyFlag, "front", {}, 1, "party")
assert(platinumStill.image.path ==
  "mod/pokemon_static_gen4Platinum_front_025.png")
assert(platinumShiny.image.path ==
  "mod/pokemon_static_gen4Platinum_front_025_shiny.png")
optionValues.battle_art = "animated"
local platinumToken = {}
local platinum0 = presentation(normal, "front", platinumToken, 25.000, "title")
local platinum499 = presentation(normal, "front", platinumToken, 25.499, "title")
local platinum501 = presentation(normal, "front", platinumToken, 25.501, "title")
assert(platinum0.animated and platinum0.frameIndex == 1
       and platinum0.artSet == "gen4Platinum")
assert(platinum499.frameIndex == 1 and platinum501.frameIndex == 2)

-- Crystal uses its per-species authored timing table and separate normal/shiny
-- front atlases. The Pikachu fixture advances after its 50 ms first frame.
optionValues.pokemon_art, optionValues.battle_art = "gen2Crystal", "static"
local crystalStill = presentation(normal, "front", {}, 1, "summary")
local crystalShiny = presentation(shinyFlag, "front", {}, 1, "party")
assert(crystalStill.image.path ==
  "mod/pokemon_static_gen2Crystal_front_025.png")
assert(crystalShiny.image.path ==
  "mod/pokemon_static_gen2Crystal_front_025_shiny.png")
optionValues.battle_art = "animated"
local crystalToken = {}
local crystal0 = presentation(normal, "front", crystalToken, 27.000, "title")
local crystal49 = presentation(normal, "front", crystalToken, 27.049, "title")
local crystal51 = presentation(normal, "front", crystalToken, 27.051, "title")
assert(crystal0.animated and crystal0.frameIndex == 1
       and crystal0.artSet == "gen2Crystal")
assert(crystal49.frameIndex == 1 and crystal51.frameIndex == 2)
assert(crystal0.image.minFilter == "nearest"
       and crystal0.image.magFilter == "nearest")

-- Emerald supplies two normal/shiny front poses and uses the documented
-- provider cadence because the sheets contain no authored timing metadata.
optionValues.pokemon_art, optionValues.battle_art = "gen3Emerald", "static"
local emeraldStill = presentation(normal, "front", {}, 1, "summary")
local emeraldShiny = presentation(shinyFlag, "front", {}, 1, "party")
assert(emeraldStill.image.path == "mod/pokemon_static_gen3Emerald_front_025.png")
assert(emeraldShiny.image.path ==
  "mod/pokemon_static_gen3Emerald_front_025_shiny.png")
optionValues.battle_art = "animated"
local emeraldToken = {}
local emerald0 = presentation(normal, "front", emeraldToken, 30.000, "title")
local emerald499 = presentation(normal, "front", emeraldToken, 30.499, "title")
local emerald501 = presentation(normal, "front", emeraldToken, 30.501, "title")
assert(emerald0.animated and emerald0.frameIndex == 1
       and emerald0.artSet == "gen3Emerald")
assert(emerald499.frameIndex == 1 and emerald501.frameIndex == 2)

-- The public UI contract is 2D-front-only and never follows Dramatic Shape's
-- battle-only player-front adapter.
optionValues.pokemon_art = "gen4HGSS"
dramaticFront = true
assert(presentation(normal, "back", {}, 1) == nil)
assert(BattleState.resolveBattleScale(data, "back",
  "mod/pokemon_static_gen4HGSS_front_025.png", "PIKACHU") == 1,
  "Dramatic Shape player front inherited native back-sprite scale")
assert(BattleState.resolveBattleScale(data, "back", "rom-back.png", "PIKACHU") == 2,
  "provider scale bridge changed a ROM back sprite")
dramaticFront = false
assert(BattleState.resolveBattleScale(data, "back",
  "mod/pokemon_static_gen4HGSS_front_025.png", "PIKACHU") == 2,
  "provider scale bridge remained active outside Dramatic Shape front mode")

-- FRLG exposes its normal/shiny front cells and remains truthful under the
-- global ANIMATED setting because the source sheet supplies only one pose.
optionValues.pokemon_art, optionValues.battle_art = "gen3FRLG", "static"
local frlgStill = presentation(normal, "front", {}, 1, "summary")
local frlgShiny = presentation(shinyFlag, "front", {}, 1, "party")
assert(frlgStill.image.path == "mod/pokemon_static_gen3FRLG_front_025.png")
assert(frlgShiny.image.path == "mod/pokemon_static_gen3FRLG_front_025_shiny.png")
optionValues.battle_art = "animated"
local frlgAnimated = presentation(normal, "front", {}, 2, "title")
assert(frlgAnimated.image == frlgStill.image and frlgAnimated.animated == false
       and frlgAnimated.mode == "animated" and frlgAnimated.artSet == "gen3FRLG")

-- Every cartridge selector resolves its own still. ANIMATED reflects the
-- selected mode but truthfully reports animated=false.
local cartridgeCases = {
  { "gen1Red", "pokemon_static_gen1RedBlue_front_025.png" },
  { "Gen1Blue", "pokemon_static_gen1RedBlue_front_025.png" },
  { "Gen1Yellow", "pokemon_static_gen1Yellow_front_025.png" },
}
for _, case in ipairs(cartridgeCases) do
  optionValues.pokemon_art, optionValues.battle_art = case[1], "static"
  local still = presentation(normal, "front", {}, 1)
  assert(still and still.image.path == "mod/" .. case[2])
  assert(still.mode == "static" and still.animated == false and still.artSet == case[1])
  optionValues.battle_art = "animated"
  local fallback = presentation(normal, "front", {}, 2)
  assert(fallback and fallback.image == still.image)
  assert(fallback.mode == "animated" and fallback.animated == false)
end

-- ROM and missing assets are explicit nil fallbacks.
optionValues.pokemon_art = "rom"
assert(presentation(normal, "front", {}, 1) == nil)
optionValues.pokemon_art, optionValues.battle_art = "gen1Red", "static"
failPaths["mod/pokemon_static_gen1RedBlue_front_026.png"] = true
assert(presentation(missing, "front", {}, 1) == nil)

-- Genuine Gen 5 animation follows authored 50ms/100ms durations. Repeating a
-- timestamp does not advance twice, and independent tokens start separately.
optionValues.pokemon_art, optionValues.battle_art = "gen5", "animated"
local tokenA, tokenB = {}, {}
local a0 = presentation(normal, "front", tokenA, 10.000, "title")
local a49 = presentation(normal, "front", tokenA, 10.049, "title")
local a51 = presentation(normal, "front", tokenA, 10.051, "title")
local a51Again = presentation(normal, "front", tokenA, 10.051, "title")
assert(a0.frameIndex == 1 and a49.frameIndex == 1)
assert(a51.frameIndex == 2 and a51Again.frameIndex == 2)
assert(a51.animated == true and a51.mode == "animated" and a51.artSet == "gen5")
assert(a51.image.minFilter == "nearest" and a51.image.magFilter == "nearest")
assert(battlePics.filled(a51.image) == a51.image,
  "Dramatic Shape filled an animated true-color frame")
local bFirst = presentation(normal, "front", tokenB, 10.060, "summary")
assert(bFirst.frameIndex == 1, "independent token inherited another token's frame")
local aLoop = presentation(normal, "front", tokenA, 10.151, "title")
assert(aLoop.frameIndex == 1, "authored second-frame duration was not applied")

-- Shiny Gen 5 uses the distinct shiny atlas and its own token signature.
local shinyPresentation = presentation(shinyFlag, "front", {}, 20, "party")
assert(shinyPresentation.frameIndex == 1)
assert(shinyPresentation.image.path:find("animated_gen5_front_025_shiny.png", 1, true))
local scytherToken = {}
assert(presentation(shinyScyther, "front", scytherToken, 20).frameIndex == 1)
local scytherFrame2 = presentation(shinyScyther, "front", scytherToken, 20.031)
assert(scytherFrame2.frameIndex == 2
       and scytherFrame2.image.path:find("front_123_shiny.png", 1, true),
       "variant-specific shiny animation metadata was not used")

local identityToken = {}
assert(presentation(normal, "front", identityToken, 21.000).frameIndex == 1)
assert(presentation(normal, "front", identityToken, 21.060).frameIndex == 2)
local identityShiny = presentation(shinyFlag, "front", identityToken, 21.070)
assert(identityShiny.frameIndex == 1
       and identityShiny.image.path:find("_shiny.png", 1, true))
assert(presentation(normal, "front", identityToken, 21.080).frameIndex == 1,
       "normal/shiny identity change did not reset token playback")

optionValues.pokemon_art = "Gen1Yellow"
assert(presentation(normal, "front", identityToken, 21.090).animated == false)
optionValues.pokemon_art = "gen5"
assert(presentation(normal, "front", identityToken, 21.100).frameIndex == 1,
       "art collection change did not reset token playback")

-- The provider clock is safe when context.now is omitted.
local clockToken = {}
providerTime = 30
assert(presentation(normal, "front", clockToken, nil).frameIndex == 1)
providerTime = 30.060
assert(presentation(normal, "front", clockToken, nil).frameIndex == 2)

-- Option and asset invalidation reset token playback rather than retaining a
-- stale frame/image object.
local resetToken = {}
assert(presentation(normal, "front", resetToken, 40.000).frameIndex == 1)
assert(presentation(normal, "front", resetToken, 40.060).frameIndex == 2)
events["mod.options_changed"]({ mod = mod.id })
assert(presentation(normal, "front", resetToken, 40.070).frameIndex == 1)
assert(presentation(normal, "front", resetToken, 40.130).frameIndex == 2)
assetInvalidator()
assert(presentation(normal, "front", resetToken, 40.140).frameIndex == 1)

-- Missing animation metadata is a nil UI fallback, not an atlas or still.
assert(presentation(missing, "front", {}, 50) == nil)

-- Backward-compatible path/image exports and battle hook behavior remain.
optionValues.battle_art = "static"
assert(mod.exports.mode() == "static" and mod.exports.isAnimated() == false)
local portrait = mod.exports.resolvePokemonImage(game, shinyFlag, "front", "portrait")
assert(portrait and portrait.path:find("025_shiny.png", 1, true))
assert(mod.exports.resolvePokemonImage(game, normal, "back", "portrait") == nil)
local function original() return "rom.png", false end
local function resolveBattle(mon, side)
  return hooks["pokemon.sprite"](original, "rom.png", {
    kind = "battle", side = side or "front", data = data, mon = mon,
  })
end
assert(resolveBattle(normal) == "mod/pokemon_static_gen5_front_025.png")
assert(resolveBattle(normal, "back") == "rom.png")

optionValues.battle_art = "animated"
assert(mod.exports.isAnimated() == true)
local battle = {
  game = game,
  enemy = { mon = normal, sprite = "enemy-rom" },
  player = { mon = normal, sprite = "player-rom" },
}
events["battle.started"]({ battle = battle })
local battleFrame1 = battle.enemy.sprite
BattleState.update(battle, 0.060)
assert(battle.nativeUpdates == 1 and battle.enemy.sprite ~= battleFrame1)
battle.enemy.mon = shinyFlag
BattleState.update(battle, 0)
assert(battle.enemy.sprite.path:find("_shiny.png", 1, true))

optionValues.pokemon_art = "gen4HGSS"
events["mod.options_changed"]({ mod = mod.id })
BattleState.update(battle, 0)
assert(battle.enemy.sprite.path:find("animated_gen4HGSS_front_025_shiny.png", 1, true),
       "battle animation retained the prior collection after an option change")
optionValues.pokemon_art = "gen5"

dramaticFront = true
BattleState.update(battle, 0)
assert(type(battle.player.sprite) == "table" and battle.player.sprite.frame)
assert(resolveBattle(normal, "back") == "mod/pokemon_static_gen5_front_025.png")
dramaticFront = false

optionValues.pokemon_art = "rom"
assert(mod.exports.mode() == "rom" and mod.exports.isAnimated() == false)
assert(resolveBattle(normal) == "rom.png")
BattleState.update(battle, 0)
assert(battle.enemy.sprite.path == "rom-front.png")

print("battle_art_replacer_test: ok")
