-- Gen1 Battle Art Replacer v0.1.0-alpha.12
-- Selectable cartridge/DS stills and genuine Gen 5 front animation.

local VERSION = "0.1.0-alpha.12"

return function(mod)
  local Assets = require("src.render.Assets")
  local Stats = require("src.pokemon.Stats")

  mod.options:define({
    {
      key = "battle_art",
      type = "choice",
      label = "BATTLE ART",
      default = "static",
      choices = { { "STATIC", "static" }, { "ANIMATED", "animated" } },
      help = "Use a still frame or authentic animation when the selected set supports it.",
    },
    {
      key = "pokemon_art",
      type = "choice",
      label = "POKEMON ART",
      default = "gen5",
      choices = {
        { "GEN 5", "gen5" },
        { "GEN 4 PLATINUM", "gen4Platinum" },
        { "GEN 4 HGSS", "gen4HGSS" },
        { "GEN 3 EMERALD", "gen3Emerald" },
        { "GEN 3 FRLG", "gen3FRLG" },
        { "GEN 2 CRYSTAL", "gen2Crystal" },
        { "GEN 1 RED", "gen1Red" },
        { "GEN 1 BLUE", "Gen1Blue" },
        { "GEN 1 YELLOW", "Gen1Yellow" },
        { "ROM", "rom" },
      },
      help = "Choose Gen 5, Platinum, HGSS, Emerald, FRLG, Crystal, Pokemon Red, Blue, Yellow, or ROM art.",
    },
  })

  local imageCache = {}
  local frameCache, frameOrder = {}, {}
  local animationMetadata
  local crystalMetadata
  local states = setmetatable({}, { __mode = "k" })
  local presentationStates = setmetatable({}, { __mode = "k" })
  local trueColorImages = setmetatable({}, { __mode = "k" })
  local lastProviderNow = 0

  local function invalidate(clearStates)
    imageCache = {}
    frameCache, frameOrder = {}, {}
    animationMetadata = nil
    crystalMetadata = nil
    presentationStates = setmetatable({}, { __mode = "k" })
    if clearStates then states = setmetatable({}, { __mode = "k" }) end
  end

  local function selectedSet()
    return mod.options:get("pokemon_art")
  end

  local function enabled()
    return selectedSet() ~= "rom"
  end

  local function animatedEnabled()
    return enabled() and mod.options:get("battle_art") == "animated"
      and (selectedSet() == "gen5" or selectedSet() == "gen4HGSS"
        or selectedSet() == "gen4Platinum" or selectedSet() == "gen3Emerald"
        or selectedSet() == "gen2Crystal")
  end

  local function selectedMode()
    return mod.options:get("battle_art") == "animated" and "animated" or "static"
  end

  local function shinyArtEnabled(mon)
    if type(mon) ~= "table" then return false end
    local shinyMod = mod.find and mod:find("gen1_shiny_system")
    local resolver = shinyMod and shinyMod.exports
      and shinyMod.exports.shouldUseShinyArt
    if type(resolver) == "function" then
      local ok, value = pcall(resolver, mon)
      if ok then return value and true or false end
    end
    if mon.shiny == true then return true end
    return Stats.isShiny and Stats.isShiny(mon.dvs) and true or false
  end

  local function dexFor(data, species)
    local def = data and data.pokemon and data.pokemon[species]
    local dex = def and tonumber(def.dex)
    if dex and dex >= 1 and dex <= 151 then return math.floor(dex) end
    return nil
  end

  local function fileSet(value)
    -- International Pokemon Red and Blue use the same front-sprite drawings.
    if value == "gen1Red" or value == "Gen1Blue" or value == "gen1Blue" then
      return "gen1RedBlue"
    end
    if value == "Gen1Yellow" then return "gen1Yellow" end
    return value
  end

  local function assetPath(data, mon, side, kind)
    local set = selectedSet()
    if set == "rom" or side ~= "front" or type(mon) ~= "table" then return nil end
    local dex = dexFor(data, mon.species)
    if not dex then return nil end
    local shiny = (set == "gen5" or set == "gen4HGSS"
      or set == "gen4Platinum" or set == "gen3Emerald"
      or set == "gen3FRLG" or set == "gen2Crystal")
      and shinyArtEnabled(mon) and "_shiny" or ""
    kind = kind or "static"
    if kind == "animated" and set ~= "gen5" and set ~= "gen4HGSS"
        and set ~= "gen4Platinum" and set ~= "gen3Emerald"
        and set ~= "gen2Crystal" then
      kind = "static"
    end
    return mod.assets:path(string.format("pokemon_%s_%s_front_%03d%s.png",
      kind, fileSet(set), dex, shiny))
  end

  local function dramaticShapeWantsFront()
    if not mod.find then return false end
    local okFind, handle = pcall(mod.find, mod, "DRAMATIC_SHAPE")
    if not (okFind and handle) then return false end
    local exports = handle.exports or handle
    local lib = exports and exports.lib
    if not (lib and type(lib.require) == "function") then return false end
    local okModule, overworldBattle = pcall(lib.require, "OverworldBattle")
    if not (okModule and overworldBattle
        and type(overworldBattle.wantsFront) == "function") then return false end
    local okFront, wantsFront = pcall(overworldBattle.wantsFront)
    return okFront and wantsFront and true or false
  end

  local function effectiveSide(side)
    if side == "back" and dramaticShapeWantsFront() then return "front" end
    return side
  end

  -- Dramatic Shape restores paper-white regions that the native Gen 1 decoder
  -- keys transparent. That flood fill is correct for ROM art, but enclosed
  -- openings in true-color replacement sprites (Mankey's tail, wing gaps,
  -- rings, and so on) are intentional transparency. Register every image this
  -- provider owns and let Dramatic Shape bypass only those images. The weak
  -- registry lives on BattlePics so it survives a provider hot reload without
  -- retaining abandoned frames.
  local function installDramaticShapeTrueColorBridge()
    if not mod.find then return false end
    local okFind, handle = pcall(mod.find, mod, "DRAMATIC_SHAPE")
    local exports = okFind and handle and (handle.exports or handle) or nil
    local lib = exports and exports.lib
    if not (lib and type(lib.require) == "function") then return false end
    local okModule, battlePics = pcall(lib.require, "BattlePics")
    if not (okModule and type(battlePics) == "table"
        and type(battlePics.filled) == "function") then return false end

    local registry = battlePics.__gen1BattleArtTrueColorImages
    if type(registry) ~= "table" then
      registry = setmetatable({}, { __mode = "k" })
      battlePics.__gen1BattleArtTrueColorImages = registry
    end
    trueColorImages = registry
    if not battlePics.__gen1BattleArtTrueColorWrapped then
      local innerFilled = battlePics.filled
      battlePics.filled = function(img, ...)
        if img and registry[img] then return img end
        return innerFilled(img, ...)
      end
      battlePics.__gen1BattleArtTrueColorWrapped = true
    end
    return true
  end

  local function markTrueColor(image)
    if image then trueColorImages[image] = true end
    return image
  end

  local function loadStill(path)
    if not path then return nil end
    local cached = imageCache[path]
    if cached == false then return nil end
    if cached then return cached end
    local ok, image = pcall(Assets.image, path)
    if not (ok and image) then imageCache[path] = false; return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    if image.setWrap then image:setWrap("clamp", "clamp") end
    imageCache[path] = image
    return image
  end

  local function resolvePokemonImage(game, mon, side, purpose)
    local data = game and game.data or game
    side = effectiveSide(side or "front")
    -- Portrait consumers and cartridge sets always receive one stable image.
    return markTrueColor(loadStill(assetPath(data, mon, side, "static")))
  end

  local function romImage(data, mon, side)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    local path = def and (side == "back" and def.spriteBack or def.spriteFront)
    return path and loadStill(path) or nil
  end

  local function loadMetadata()
    if animationMetadata ~= nil then return animationMetadata or nil end
    local path = mod.assets:path("animation_metadata.lua")
    local chunk
    if love and love.filesystem and love.filesystem.load then
      local ok, loaded = pcall(love.filesystem.load, path)
      if ok then chunk = loaded end
    end
    if not chunk and loadfile then
      local ok, loaded = pcall(loadfile, path)
      if ok then chunk = loaded end
    end
    local ok, value = false, nil
    if chunk then ok, value = pcall(chunk) end
    animationMetadata = ok and type(value) == "table" and value or false
    return animationMetadata or nil
  end

  local function loadCrystalMetadata()
    if crystalMetadata ~= nil then return crystalMetadata or nil end
    local path = mod.assets:path("crystal_animation_metadata.lua")
    local chunk
    if love and love.filesystem and love.filesystem.load then
      local ok, loaded = pcall(love.filesystem.load, path)
      if ok then chunk = loaded end
    end
    if not chunk and loadfile then
      local ok, loaded = pcall(loadfile, path)
      if ok then chunk = loaded end
    end
    local ok, value = false, nil
    if chunk then ok, value = pcall(chunk) end
    crystalMetadata = ok and type(value) == "table" and value or false
    return crystalMetadata or nil
  end

  local function forgetFrameKey(key)
    for i = #frameOrder, 1, -1 do
      if frameOrder[i] == key then table.remove(frameOrder, i) end
    end
  end

  local function rememberFrames(key, frames)
    forgetFrameKey(key)
    frameCache[key] = frames
    frameOrder[#frameOrder + 1] = key
    if #frameOrder > 4 then frameCache[table.remove(frameOrder, 1)] = nil end
  end

  local function loadFrames(data, mon)
    if not (love and love.image and love.image.newImageData
        and love.graphics and love.graphics.newImage) then return nil end
    local dex = dexFor(data, mon and mon.species)
    local metadata = loadMetadata()
    local set = selectedSet()
    local entry = metadata and dex and metadata[dex]
    local def
    if set == "gen5" then
      def = entry and shinyArtEnabled(mon) and entry.shiny or entry
    elseif set == "gen4HGSS" then
      def = metadata and metadata.hgss
    elseif set == "gen4Platinum" then
      def = metadata and metadata.platinum
    elseif set == "gen3Emerald" then
      def = metadata and metadata.emerald
    elseif set == "gen2Crystal" then
      local crystal = loadCrystalMetadata()
      local crystalEntry = crystal and dex and crystal[dex]
      def = crystalEntry and shinyArtEnabled(mon) and crystalEntry.shiny
        or crystalEntry
    end
    if not def then return nil end
    local path = assetPath(data, mon, "front", "animated")
    if not path then return nil end
    local cached = frameCache[path]
    if cached == false then return nil end
    if cached then forgetFrameKey(path); frameOrder[#frameOrder + 1] = path; return cached, def end

    local result
    local ok = pcall(function()
      local sheet = love.image.newImageData(path)
      local sheetW, sheetH = sheet:getDimensions()
      local columns, count = tonumber(def.columns), tonumber(def.frames)
      local rows = columns and count and math.ceil(count / columns) or nil
      local width = tonumber(def.width)
        or (columns and sheetW % columns == 0 and sheetW / columns)
      local height = tonumber(def.height)
        or (rows and sheetH % rows == 0 and sheetH / rows)
      if not (width and height and columns and count and width > 0 and height > 0
          and width == math.floor(width) and height == math.floor(height)
          and columns > 0 and count > 0
          and sheetW >= width * columns
          and sheetH >= height * rows) then return end
      local frames = {}
      for index = 0, count - 1 do
        local cell = love.image.newImageData(width, height)
        cell:paste(sheet, 0, 0, (index % columns) * width,
          math.floor(index / columns) * height, width, height)
        local image = love.graphics.newImage(cell)
        if image.setFilter then image:setFilter("nearest", "nearest") end
        if image.setWrap then image:setWrap("clamp", "clamp") end
        markTrueColor(image)
        frames[#frames + 1] = image
      end
      if #frames == count then result = frames end
    end)
    if not (ok and result) then frameCache[path] = false; return nil end
    rememberFrames(path, result)
    return result, def
  end

  local function monotonicNow(supplied)
    if type(supplied) == "number" and supplied == supplied then return supplied end
    local value
    if love and love.timer and type(love.timer.getTime) == "function" then
      local ok, got = pcall(love.timer.getTime)
      if ok then value = tonumber(got) end
    end
    if not value and os and type(os.clock) == "function" then
      local ok, got = pcall(os.clock)
      if ok then value = tonumber(got) end
    end
    value = value or lastProviderNow
    if value < lastProviderNow then value = lastProviderNow end
    lastProviderNow = value
    return value
  end

  local function frameDuration(def, index)
    return math.max(1, tonumber(def and def.durations
      and def.durations[index]) or 100) / 1000
  end

  local function animationCycle(def, count)
    local cycle = 0
    for index = 1, count do cycle = cycle + frameDuration(def, index) end
    return cycle
  end

  local function advancePresentation(state, now)
    if state.lastNow == nil then state.lastNow = now; return end
    local delta = now - state.lastNow
    state.lastNow = now
    if delta <= 0 then return end
    local cycle = state.cycle
    state.elapsed = state.elapsed + delta
    if cycle > 0 and state.elapsed >= cycle then
      state.elapsed = state.elapsed % cycle
    end
    local duration = frameDuration(state.def, state.frame)
    while state.elapsed >= duration do
      state.elapsed = state.elapsed - duration
      state.frame = state.frame % #state.frames + 1
      duration = frameDuration(state.def, state.frame)
    end
  end

  local function resolvePokemonPresentation(game, mon, side, context)
    local token = type(context) == "table" and context.token or nil
    local function clearToken()
      if type(token) == "table" then presentationStates[token] = nil end
    end
    if type(mon) ~= "table" or side ~= "front" then clearToken(); return nil end
    local set = selectedSet()
    if set == "rom" then clearToken(); return nil end
    local data = game and game.data or game
    local dex = dexFor(data, mon.species)
    if not dex then clearToken(); return nil end
    local mode = selectedMode()
    local shiny = (set == "gen5" or set == "gen4HGSS"
      or set == "gen4Platinum" or set == "gen3Emerald"
      or set == "gen3FRLG" or set == "gen2Crystal")
      and shinyArtEnabled(mon) or false
    local base = {
      trueColor = true,
      mode = mode,
      artSet = set,
    }

    if not ((set == "gen5" or set == "gen4HGSS"
        or set == "gen4Platinum" or set == "gen3Emerald"
        or set == "gen2Crystal")
        and mode == "animated") then
      local image = markTrueColor(loadStill(assetPath(data, mon, "front", "static")))
      clearToken()
      if not image then return nil end
      base.image = image
      base.animated = false
      return base
    end

    local frames, def = loadFrames(data, mon)
    if not (frames and def and #frames > 0) then clearToken(); return nil end
    local now = monotonicNow(type(context) == "table" and context.now or nil)
    local signature = table.concat({ tostring(dex), shiny and "s" or "n", set, mode }, ":")
    local state = type(token) == "table" and presentationStates[token] or nil
    if not state or state.signature ~= signature then
      state = {
        signature = signature,
        frames = frames,
        def = def,
        frame = 1,
        elapsed = 0,
        lastNow = now,
        cycle = animationCycle(def, #frames),
      }
      if type(token) == "table" then presentationStates[token] = state end
    elseif state.frames ~= frames or state.def ~= def then
      state.frames, state.def = frames, def
      state.frame, state.elapsed, state.lastNow = 1, 0, now
      state.cycle = animationCycle(def, #frames)
    else
      advancePresentation(state, now)
    end
    base.image = state.frames[state.frame]
    base.animated = true
    base.frameIndex = state.frame
    return base
  end

  local function applyBattler(battle, battler, side, dt)
    if not (battle and battler and battler.mon) then return end
    local requestedSide = side
    side = effectiveSide(side)
    local data = battle.game and battle.game.data
    if side ~= "front" then
      if states[battler] then
        local original = romImage(data, battler.mon, requestedSide)
        if original then battler.sprite = original end
      end
      states[battler] = nil
      return
    end
    if not enabled() then
      local original = romImage(data, battler.mon, "front")
      if original then battler.sprite = original end
      states[battler] = nil
      return
    end
    local dex = dexFor(data, battler.mon.species)
    if not dex then states[battler] = nil; return end

    if not animatedEnabled() then
      states[battler] = nil
      local still = resolvePokemonImage(battle.game, battler.mon, "front", "battle")
      if still then battler.sprite = still end
      return
    end

    local signature = table.concat({ tostring(dex),
      shinyArtEnabled(battler.mon) and "s" or "n", selectedSet() }, ":")
    local state = states[battler]
    if not state or state.signature ~= signature then
      local frames, def = loadFrames(data, battler.mon)
      if not frames then
        local still = resolvePokemonImage(battle.game, battler.mon, "front", "battle")
        if still then battler.sprite = still end
        states[battler] = nil
        return
      end
      state = { signature = signature, frames = frames, def = def, frame = 1, elapsed = 0 }
      states[battler] = state
    end
    state.elapsed = state.elapsed + math.max(0, tonumber(dt) or 0)
    local durations = state.def.durations or {}
    local duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
    while state.elapsed >= duration do
      state.elapsed = state.elapsed - duration
      state.frame = state.frame % #state.frames + 1
      duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
    end
    battler.sprite = state.frames[state.frame]
  end

  local function updateBattle(battle, dt)
    if not battle then return end
    applyBattler(battle, battle.enemy, "front", dt)
    applyBattler(battle, battle.player, "back", dt)
  end

  mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    local original, originalTrueColor = next(path, ctx)
    if not (ctx and ctx.kind == "battle" and enabled()) then
      return original, originalTrueColor
    end
    local side = effectiveSide(ctx.side)
    if side ~= "front" then return original, originalTrueColor end
    local mon = ctx.mon
    if type(mon) ~= "table" then mon = { species = ctx.species } end
    -- Never give the engine an atlas. The animation manager replaces this
    -- neutral still with decoded frames after BattleState updates.
    local replacement = assetPath(ctx.data, mon, side, "static")
    if replacement then return replacement, true end
    return original, originalTrueColor
  end)

  mod.events:on("battle.started", function(payload)
    installDramaticShapeTrueColorBridge()
    local battle = payload and payload.battle
    if battle then updateBattle(battle, 0) end
  end)

  local okBattle, BattleState = pcall(require, "src.battle.BattleState")
  if okBattle and BattleState and type(BattleState.update) == "function"
      and not BattleState.__gen1BattleArtAnimationWrapped then
    local innerUpdate = BattleState.update
    BattleState.update = function(self, dt, ...)
      local result = innerUpdate(self, dt, ...)
      updateBattle(self, dt)
      return result
    end
    BattleState.__gen1BattleArtAnimationWrapped = true
  end

  -- Dramatic Shape can request a front image in the player's original back
  -- slot. Keep the replacement on the front-image scale path; otherwise the
  -- engine applies its native 2x back-sprite scale to a full-size front and
  -- the two sides no longer match. This does not touch ROM backs or the
  -- provider-independent arena/camera geometry.
  if okBattle and BattleState and type(BattleState.resolveBattleScale) == "function"
      and not BattleState.__gen1BattleArtFrontScaleWrapped then
    local innerBattleScale = BattleState.resolveBattleScale
    BattleState.resolveBattleScale = function(data, side, path, species)
      if side == "back" and enabled() and dramaticShapeWantsFront() then
        local expected = assetPath(data, { species = species }, "front", "static")
        if expected and path == expected then
          return innerBattleScale(data, "front", path, species)
        end
      end
      return innerBattleScale(data, side, path, species)
    end
    BattleState.__gen1BattleArtFrontScaleWrapped = true
  end

  if Assets.register then Assets.register(function() invalidate(true) end) end
  mod.events:on("mod.options_changed", function(payload)
    if payload and payload.mod == mod.id then invalidate(false) end
  end)

  installDramaticShapeTrueColorBridge()

  mod.exports.version = VERSION
  mod.exports.presentationApiVersion = 1
  mod.exports.resolvePokemonPresentation = resolvePokemonPresentation
  mod.exports.resolvePokemonImage = resolvePokemonImage
  mod.exports.resolvePokemonPath = assetPath
  mod.exports.resolveTrainerImage = function() return nil end
  mod.exports.resolvePlayerImage = function() return nil end
  mod.exports.mode = function() return enabled() and mod.options:get("battle_art") or "rom" end
  mod.exports.isAnimated = animatedEnabled
  mod.exports.invalidate = function() invalidate(true) end

  mod.log:info("Gen1 Battle Art Replacer %s ready (static sets + Emerald/HGSS/Gen 5 animation)", VERSION)
end
