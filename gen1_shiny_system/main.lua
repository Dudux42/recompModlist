-- Gen1 Shiny System v0.1.0-alpha.3
-- Focused shiny generation + presentation API for the Invoker/Codex pack.

return function(mod)
  local Stats = require("src.pokemon.Stats")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local PaletteFX = require("src.render.PaletteFX")
  local Sprites = require("src.pokemon.Sprites")
  local Assets = require("src.render.Assets")
  local Sound = require("src.core.Sound")

  local RATE_DENOM = {
    gen2 = 8192, modern = 4096, common = 1024, frequent = 512,
    often = 100, high = 10,
  }
  local RATE_ORDER = {
    "off", "gen2", "modern", "common", "frequent", "often", "high", "always",
  }
  local RATE_LABEL = {
    off = "OFF", gen2 = "1/8192", modern = "1/4096", common = "1/1024",
    frequent = "1/512", often = "1/100", high = "1/10", always = "100%",
  }
  local SHINY_ATTACK_DVS = { 2, 3, 6, 7, 10, 11, 14, 15 }
  local INTRO_SECONDS = 1.35
  local FOLLOWER_INTERVAL = 2.8
  local SHINY_SFX = "Dex_Page_Added"
  local WILD_OUTCOME_API_VERSION = 1
  local outcomeRecords = setmetatable({}, { __mode = "k" })
  local optionRecords = setmetatable({}, { __mode = "k" })
  local wildFrames = {}
  local dramaticShapeCompat = {
    active = false,
    overworldBattle = nil,
  }

  local function option(key, default)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and value ~= nil then return value end
    return default
  end

  local function enabled()
    return option("enabled", true) ~= false
  end

  local function colorsEnabled()
    return enabled() and option("recolor", true) ~= false
  end

  local function introEnabled()
    return enabled() and option("sparkles", true) ~= false
  end

  local function debugEnabled()
    return option("debug_ow", false) == true
  end

  local function rateKey()
    local value = tostring(option("shiny_rate", "modern") or "modern"):lower()
    if value == "100%" or value:find("always", 1, true) then return "always" end
    if value == "off" or value == "gen2" or value == "modern"
        or RATE_DENOM[value] then return value end
    return "modern"
  end

  mod.options:define({
    {
      key = "enabled", type = "toggle", label = "SHINY POKEMON", default = true,
      help = "Roll shinies, show shiny art, and play the shiny intro.",
    },
    {
      key = "shiny_rate", type = "choice", label = "SHINY RATE",
      default = "modern",
      choices = {
        { "OFF", "off" }, { "1/8192 (Gen 2)", "gen2" },
        { "1/4096 (Modern)", "modern" }, { "1/1024", "common" },
        { "1/512", "frequent" }, { "1/100", "often" },
        { "1/10", "high" }, { "100% (Always)", "always" },
      },
      help = "Chance that a newly created wild Pokemon is shiny.",
    },
    {
      key = "recolor", type = "toggle", label = "SHINY COLORS", default = true,
      help = "Use shiny battle, menu-icon, and follower artwork.",
    },
    {
      key = "sparkles", type = "toggle", label = "SHINY INTRO", default = true,
      help = "Show sparkle effects and play the battle shiny sound.",
    },
    {
      key = "debug_ow", type = "toggle", label = "DEBUG OW", default = false,
      help = "Write shiny integration diagnostics. Leave OFF normally.",
    },
  })

  local function randomFunction(rng)
    if type(rng) == "function" then return rng end
    if love and love.math and love.math.random then return love.math.random end
    return math.random
  end

  local function makeShinyDVs(rng)
    rng = randomFunction(rng)
    local attack = SHINY_ATTACK_DVS[rng(#SHINY_ATTACK_DVS)]
    local dvs = { attack = attack, defense = 10, speed = 10, special = 10 }
    dvs.hp = (attack % 2) * 8 + 4 + 2
    return dvs
  end

  local function hasShinyState(mon)
    if type(mon) ~= "table" then return false end
    if mon.shiny == true then return true end
    return Stats.isShiny and Stats.isShiny(mon.dvs) and true or false
  end

  local function isShiny(mon)
    return enabled() and hasShinyState(mon)
  end

  local function shouldUseShinyArt(mon)
    return colorsEnabled() and hasShinyState(mon)
  end

  local function applyShiny(mon, data, dvs)
    if type(mon) ~= "table" then return mon end
    mon.dvs = dvs or makeShinyDVs()
    mon.shiny = true
    local def = data and data.pokemon and data.pokemon[mon.species]
    if def and def.baseStats and Stats.calc then
      local oldMax = mon.stats and mon.stats.hp
      local oldHP = mon.hp
      mon.stats = Stats.calc(def, mon.level or 1, mon.dvs, mon.statExp)
      if oldHP == nil or oldMax == nil or oldHP >= oldMax then
        mon.hp = mon.stats.hp
      else
        mon.hp = math.max(0, math.min(mon.stats.hp, oldHP))
      end
    end
    return mon
  end

  -- Enforce the selected rate exactly. Pokemon.new may naturally roll shiny
  -- DVs, and Dramatic Shape 1.8.x used to make its own decision before this
  -- wrapper ran. A miss must clear both representations or two independent
  -- generators would remain active.
  local function clearShiny(mon, data)
    if type(mon) ~= "table" then return mon end
    local dvs = mon.dvs
    local changed = false
    if type(dvs) == "table" and Stats.isShiny and Stats.isShiny(dvs) then
      dvs.special = (tonumber(dvs.special) == 10) and 9 or 10
      if Stats.isShiny(dvs) then dvs.defense = 9 end
      if dvs.attack and dvs.defense and dvs.speed and dvs.special then
        dvs.hp = (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
          + (dvs.speed % 2) * 2 + (dvs.special % 2)
      end
      changed = true
    end
    mon.shiny = nil
    local def = data and data.pokemon and data.pokemon[mon.species]
    if changed and def and def.baseStats and Stats.calc then
      local oldMax = mon.stats and mon.stats.hp
      local oldHP = mon.hp
      mon.stats = Stats.calc(def, mon.level or 1, mon.dvs, mon.statExp)
      if oldHP == nil or oldMax == nil or oldHP >= oldMax then
        mon.hp = mon.stats.hp
      else
        mon.hp = math.max(0, math.min(mon.stats.hp, oldHP))
      end
    end
    return mon
  end

  local function rollShiny(rng)
    if not enabled() then return false end
    local key = rateKey()
    if key == "off" then return false end
    if key == "always" then return true end
    local denominator = RATE_DENOM[key]
    if not denominator then return false end
    return randomFunction(rng)(denominator) == 1
  end

  local function copyDVs(dvs)
    if type(dvs) ~= "table" then return nil end
    return {
      attack = dvs.attack, defense = dvs.defense, speed = dvs.speed,
      special = dvs.special, hp = dvs.hp,
    }
  end

  local function validOutcome(outcome, requireUnused)
    local record = type(outcome) == "table" and outcomeRecords[outcome] or nil
    if type(record) ~= "table" or record.version ~= WILD_OUTCOME_API_VERSION then
      return nil, "foreign or unsupported wild outcome"
    end
    -- The public surface is read-only through __index. rawset cannot forge a
    -- different visible verdict because validation rejects any shadow field.
    if rawget(outcome, "shiny") ~= nil or outcome.shiny ~= record.shiny then
      return nil, "altered wild outcome"
    end
    if requireUnused and record.consumed then
      return nil, "wild outcome was already consumed"
    end
    return record
  end

  local function reserveWildOutcome(rng)
    local shiny = rollShiny(rng)
    local record = {
      version = WILD_OUTCOME_API_VERSION,
      shiny = shiny and true or false,
      -- Reserving DVs must not make a second rate/RNG decision. A fixed valid
      -- Gen 2 combination is provider-owned and sufficient for identity.
      dvs = shiny and makeShinyDVs(function() return 1 end) or nil,
      consumed = false,
    }
    local outcome
    outcome = setmetatable({}, {
      __index = function(_, key)
        if key == "shiny" then return record.shiny end
        return nil
      end,
      __newindex = function()
        error("Gen1 Shiny System wild outcomes are read-only", 2)
      end,
      __metatable = false,
    })
    outcomeRecords[outcome] = record
    return outcome
  end

  local function wildBattleOptions(outcome)
    local record, reason = validOutcome(outcome, true)
    if not record then return nil, reason end
    local opts = {}
    optionRecords[opts] = { outcome = outcome, record = record }
    return opts
  end

  local function applyReservedOutcome(mon, data, record)
    if record.shiny then
      return applyShiny(mon, data, copyDVs(record.dvs))
    end
    return clearShiny(mon, data)
  end

  -- Only Pokemon constructed inside BattleState.newWild receive a new roll.
  -- Starters, gifts, trades and trainer parties retain their authored DVs.
  local constructingWild = 0
  if not Pokemon.__gen1ShinySystemWrapped then
    local originalPokemonNew = Pokemon.new
    Pokemon.new = function(data, species, level, rng)
      local mon = originalPokemonNew(data, species, level, rng)
      if constructingWild > 0 then
        local frame = wildFrames[#wildFrames]
        if frame and not frame.applied then
          applyReservedOutcome(mon, data, frame.record)
          frame.applied = true
        elseif rollShiny(rng) then
          applyShiny(mon, data, makeShinyDVs(rng))
        else
          clearShiny(mon, data)
        end
      elseif hasShinyState(mon) then
        mon.shiny = true
      end
      return mon
    end
    Pokemon.__gen1ShinySystemWrapped = true
  end

  if not BattleState.__gen1ShinySystemWildWrapped then
    local originalNewWild = BattleState.newWild
    BattleState.newWild = function(game, species, level, opts)
      local optionRecord = type(opts) == "table" and optionRecords[opts] or nil
      local frame
      if optionRecord then
        local valid, reason = validOutcome(optionRecord.outcome, true)
        if not valid or valid ~= optionRecord.record then
          mod.log:warn("Rejected reserved wild outcome: %s", tostring(reason))
          return nil
        end
        valid.consumed = true
        frame = { record = valid, applied = false }
        wildFrames[#wildFrames + 1] = frame
      end
      constructingWild = constructingWild + 1
      local ok, result = pcall(originalNewWild, game, species, level, opts)
      constructingWild = math.max(0, constructingWild - 1)
      if frame then wildFrames[#wildFrames] = nil end
      if not ok then error(result, 0) end
      local mon = result and result.enemy and result.enemy.mon
      if frame and mon and not frame.applied then
        applyReservedOutcome(mon, game and game.data, frame.record)
        frame.applied = true
      elseif not frame and mon and rateKey() == "always" and enabled()
          and not hasShinyState(mon) then
        applyShiny(mon, game and game.data, makeShinyDVs())
      end
      return result
    end
    BattleState.__gen1ShinySystemWildWrapped = true
  end

  mod.events:on("pokemon.caught", function(event)
    local mon = event and (event.pokemon or event.mon)
    if mon and hasShinyState(mon) then mon.shiny = true end
  end)

  -- Official Crystal two-shade palettes. The data file is retained separately
  -- so the runtime remains small and its MIT attribution stays explicit.
  local officialPalettes = {}
  do
    local source = mod:read("shiny_palettes.lua")
    local loader = loadstring or load
    local chunk = type(source) == "string" and loader(source, "@shiny_palettes.lua")
    local ok, value = chunk and pcall(chunk)
    if ok and type(value) == "table" then officialPalettes = value end
    if officialPalettes.FARFETCHD then
      officialPalettes.FARFETCH_D = officialPalettes.FARFETCHD
    end
    if officialPalettes.MR_MIME then
      officialPalettes.MR__MIME = officialPalettes.MR_MIME
    end
  end

  local function officialPair(species)
    local key = tostring(species or ""):upper():gsub("[^%w_]", "_")
    local pair = officialPalettes[key]
    if type(pair) ~= "table" then return nil end
    return pair[1], pair[2]
  end

  local imageCache = {}
  local function recoloredImage(path, species, cacheKey, keyWhite)
    if not path then return nil end
    cacheKey = tostring(cacheKey or path)
    if imageCache[cacheKey] ~= nil then return imageCache[cacheKey] or nil end
    local light, dark = officialPair(species)
    if not (light and dark and love and love.graphics and Assets.imageData) then
      imageCache[cacheKey] = false
      return nil
    end
    local ok, image = pcall(function()
      local data = Assets.imageData(path)
      local sampleR, sampleG, sampleB, sampleA = data:getPixel(0, 0)
      local bytePixels = sampleR > 1 or sampleG > 1 or sampleB > 1
        or (sampleA and sampleA > 1)
      local lumas = {}
      data:mapPixel(function(_, _, r, g, b, a)
        local R, G, B = r, g, b
        local A = a
        if bytePixels then R, G, B, A = r / 255, g / 255, b / 255, a / 255 end
        if A > 0.001 and not (R < 0.08 and G < 0.08 and B < 0.08)
            and not (R > 0.92 and G > 0.92 and B > 0.92) then
          lumas[#lumas + 1] = 0.299 * R + 0.587 * G + 0.114 * B
        end
        return r, g, b, a
      end)
      table.sort(lumas)
      local split = #lumas > 0 and lumas[math.max(1, math.floor(#lumas * 0.55))]
        or 0.55
      data:mapPixel(function(_, _, r, g, b, a)
        local R, G, B = r, g, b
        local A = a
        if bytePixels then R, G, B, A = r / 255, g / 255, b / 255, a / 255 end
        if A <= 0.001 or (R < 0.08 and G < 0.08 and B < 0.08) then
          return r, g, b, a
        end
        if R > 0.92 and G > 0.92 and B > 0.92 then
          if keyWhite then return r, g, b, 0 end
          return r, g, b, a
        end
        local luma = 0.299 * R + 0.587 * G + 0.114 * B
        local color = luma >= split and light or dark
        if bytePixels then return color[1], color[2], color[3], a end
        return color[1] / 255, color[2] / 255, color[3] / 255, a
      end)
      local output = love.graphics.newImage(data)
      if output.setFilter then output:setFilter("nearest", "nearest") end
      return output
    end)
    imageCache[cacheKey] = ok and image or false
    return ok and image or nil
  end

  local function battleImage(game, mon, side)
    if not shouldUseShinyArt(mon) then return nil end
    side = side or "front"
    local data = game and game.data or game
    local path, trueColor = Sprites.path(data, mon.species, side, {
      mon = mon, kind = "battle",
    })
    return recoloredImage(path, mon.species,
      "battle:" .. tostring(mon.species) .. ":" .. side .. ":" .. tostring(path),
      not trueColor)
  end

  local function syncBattler(battle, battler)
    local mon = battler and battler.mon
    if not isShiny(mon) then return end
    mon.shiny = true
    battler.shiny = true
    if not colorsEnabled() then return end
    if dramaticShapeCompat.active and dramaticShapeCompat.overworldBattle then
      local ok, owns = pcall(dramaticShapeCompat.overworldBattle.enabled)
      if ok and owns then return end
    end
    local side = battler.isPlayer and "back" or "front"
    local image = battleImage(battle and (battle.game or battle.data), mon, side)
    if image then battler.sprite = image end
  end

  local function syncBattle(battle)
    if not battle then return end
    syncBattler(battle, battle.enemy)
    syncBattler(battle, battle.player)
  end

  if not BattleState.__gen1ShinySystemDrawWrapped then
    local originalDrawPics = BattleState.drawPicsLayer
    BattleState.drawPicsLayer = function(self, ...)
      syncBattle(self)
      return originalDrawPics(self, ...)
    end
    BattleState.__gen1ShinySystemDrawWrapped = true
  end

  local introStart = setmetatable({}, { __mode = "k" })
  local function now()
    return love and love.timer and love.timer.getTime and love.timer.getTime()
      or os.clock()
  end

  local function drawSparkles(cx, cy, progress, seed, scale)
    if not (love and love.graphics) then return end
    scale = scale or 1
    for index = 1, 8 do
      local angle = index * math.pi / 4 + (seed or 0) * 0.17
      local radius = (4 + progress * 15 + index % 3) * scale
      local x = math.floor(cx + math.cos(angle) * radius)
      local y = math.floor(cy + math.sin(angle) * radius * 0.72)
      local size = math.max(1, math.floor((3 - progress * 2) * scale))
      love.graphics.setColor(1, 1, 0.35, 1)
      love.graphics.rectangle("fill", x, y, size, size)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", x, y, 1, 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  mod.events:on("battle.started", function(event)
    local battle = event and event.battle
    if not battle then return end
    syncBattle(battle)
    introStart[battle] = now()
    if introEnabled() and ((battle.enemy and isShiny(battle.enemy.mon))
        or (battle.player and isShiny(battle.player.mon))) then
      pcall(Sound.play, battle.game and battle.game.data or battle.data, SHINY_SFX)
    end
  end)

  mod.hooks:wrap("battle.overlay", function(next, battle)
    next(battle)
    if not introEnabled() or not battle then return end
    syncBattle(battle)
    -- Dramatic Shape sizes and draws its own 3D sparkle. Keep this overlay as
    -- the fallback when SHINY COLORS is off, because its model selector then
    -- deliberately sees an ordinary model while SHINY INTRO remains valid.
    if colorsEnabled() and dramaticShapeCompat.active
        and dramaticShapeCompat.overworldBattle then
      local ok, owns = pcall(dramaticShapeCompat.overworldBattle.enabled)
      if ok and owns then return end
    end
    local started = introStart[battle] or now()
    introStart[battle] = started
    local progress = (now() - started) / INTRO_SECONDS
    if progress < 0 or progress >= 1 then return end
    if battle.enemy and isShiny(battle.enemy.mon) then
      drawSparkles(120, 34, progress, battle.enemy.mon.level or 1, 1)
    end
    if battle.player and isShiny(battle.player.mon) then
      drawSparkles(42, 90, progress, battle.player.mon.level or 1, 1)
    end
  end)

  local function drawFollowerSparkles(mon, x, y, width, height)
    if not introEnabled() or not isShiny(mon) then return false end
    local phase = now() % FOLLOWER_INTERVAL
    if phase >= INTRO_SECONDS then return false end
    drawSparkles(x + (width or 32) / 2, y + (height or 32) / 2,
      phase / INTRO_SECONDS, mon.level or 1, 0.75)
    return true
  end

  local function setOption(key, value, game)
    pcall(mod.options.set, mod.options, key, value)
    if game and game.save then
      game.save.options = game.save.options or {}
      game.save.options.modOptions = game.save.options.modOptions or {}
      game.save.options.modOptions[mod.id] = game.save.options.modOptions[mod.id] or {}
      game.save.options.modOptions[mod.id][key] = value
    end
    if game and game.writeOptions then pcall(game.writeOptions, game) end
    imageCache = {}
  end

  local function cycleRate(game, dir)
    local index = 1
    for i, key in ipairs(RATE_ORDER) do
      if key == rateKey() then index = i break end
    end
    dir = tonumber(dir) or 1
    index = ((index - 1 + dir) % #RATE_ORDER) + 1
    setOption("shiny_rate", RATE_ORDER[index], game)
    return true
  end

  -- Dramatic Shape 1.8.x publishes `exports.lib` specifically for companion
  -- mods. Its Shiny module has no provider-registration API, so this guarded
  -- adapter uses only that exported namespace: generation delegates here,
  -- its 3D presentation reads this mod's toggles, and its in-game rate row
  -- becomes a second view of this mod's authoritative setting.
  local function installDramaticShapeCompatibility()
    if type(mod.find) ~= "function" then return false end
    local okFind, handle = pcall(mod.find, mod, "DRAMATIC_SHAPE")
    if not okFind or type(handle) ~= "table" then return false end
    local version = tostring(handle.version or "")
    if not version:match("^1%.8%.") then
      mod.log:warn("Dramatic Shape shiny adapter supports 1.8.x; found %s", version)
      return false
    end
    local lib = handle.exports and handle.exports.lib
    if type(lib) ~= "table" or type(lib.require) ~= "function" then
      mod.log:warn("Dramatic Shape %s has no exported companion namespace", version)
      return false
    end
    local okShiny, dsShiny = pcall(lib.require, "Shiny")
    local okBattle, dsBattle = pcall(lib.require, "OverworldBattle")
    local okFx, dsFx = pcall(lib.require, "ShinyFx")
    if not okShiny or type(dsShiny) ~= "table"
        or type(dsShiny.decide) ~= "function"
        or type(dsShiny.isShiny) ~= "function" then
      mod.log:warn("Dramatic Shape %s shiny surface is incompatible", version)
      return false
    end

    dsShiny.__gen1ShinySystemOwner = mod.id
    dsShiny.decide = function(mon)
      if type(mon) ~= "table" then return false end
      local state = hasShinyState(mon)
      mon.shiny = state and true or nil
      return state
    end
    dsShiny.mark = dsShiny.decide
    dsShiny.isShiny = shouldUseShinyArt

    if type(dsShiny.setting) == "table" then
      dsShiny.setting.row = function()
        return {
          id = "DRAMATIC_SHAPE:shinyOdds",
          label = "SHINY RATE",
          value = function() return RATE_LABEL[rateKey()] end,
          step = function(game, dir) return cycleRate(game, dir) end,
        }
      end
    end

    if okFx and type(dsFx) == "table" and type(dsFx.arm) == "function" then
      dsFx.__gen1ShinySystemOriginalArm =
        dsFx.__gen1ShinySystemOriginalArm or dsFx.arm
      dsFx.arm = function(side)
        if introEnabled() then
          return dsFx.__gen1ShinySystemOriginalArm(side)
        end
        if type(dsFx.clear) == "function" then return dsFx.clear(side) end
      end
    end

    dramaticShapeCompat.active = true
    dramaticShapeCompat.overworldBattle = okBattle and dsBattle or nil
    mod.log:info("Dramatic Shape %s shiny generation/options delegated", version)
    return true
  end

  installDramaticShapeCompatibility()

  local SCREEN_ID = "Gen1ShinySystemOptions"
  local function makeOptionsScreen(game)
    local OptionRows = require("src.ui.OptionRows")
    local rows = {
      { label = "SHINY", value = function() return enabled() and "ON" or "OFF" end,
        step = function(g) setOption("enabled", not enabled(), g) end },
      { label = "SHINY RATE", value = function() return RATE_LABEL[rateKey()] end,
        step = function(g) cycleRate(g, 1) end },
      { label = "SHINY COLORS",
        value = function() return colorsEnabled() and "ON" or "OFF" end,
        step = function(g) setOption("recolor", not option("recolor", true), g) end },
      { label = "SHINY INTRO",
        value = function() return introEnabled() and "ON" or "OFF" end,
        step = function(g) setOption("sparkles", not option("sparkles", true), g) end },
      { label = "DEBUG OW",
        value = function() return debugEnabled() and "ON" or "OFF" end,
        step = function(g) setOption("debug_ow", not debugEnabled(), g) end },
    }
    local screen = { game = game, rows = rows, index = 1, scroll = 0, isOpaque = true }
    function screen:sgbPalettes(g) return PaletteFX.wholeNamed(g.data, "MEWMON") end
    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then self.index = (self.index - 2) % #rows + 1
      elseif input:wasPressed("down") then self.index = self.index % #rows + 1
      elseif input:wasPressed("left") or input:wasPressed("right")
          or input:wasPressed("a") then rows[self.index].step(self.game)
      elseif input:wasPressed("b") then self.game.stack:pop() end
      self.scroll = OptionRows.clampScroll(self.index, self.scroll, #rows, nil)
    end
    function screen:draw()
      OptionRows.draw(self.game, rows, self.index, self.scroll, "A/LEFT/RIGHT:CHANGE B:DONE")
    end
    return screen
  end

  mod.content.screens:register(SCREEN_ID, { new = makeOptionsScreen })
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local output = next(game, rows)
    if type(output) ~= "table" then return output end
    local row = {
      id = "gen1_shiny_system_open", label = "SHINY POKEMON",
      value = function() return "OPEN" end,
      activate = function(g) require("src.ui.Screens").push(g, SCREEN_ID) end,
    }
    if mod.ui and type(mod.ui.insertBefore) == "function" then
      return mod.ui.insertBefore(output, "MODS", row)
    end
    output[#output + 1] = row
    return output
  end)

  mod.exports.version = "0.1.0-alpha.3"
  mod.exports.wildOutcomeApiVersion = WILD_OUTCOME_API_VERSION
  mod.exports.reserveWildOutcome = reserveWildOutcome
  mod.exports.wildBattleOptions = wildBattleOptions
  mod.exports.isShiny = isShiny
  mod.exports.hasShinyState = hasShinyState
  mod.exports.shouldUseShinyArt = shouldUseShinyArt
  mod.exports.colorsEnabled = colorsEnabled
  mod.exports.introEnabled = introEnabled
  mod.exports.rateKey = rateKey
  mod.exports.rollShiny = rollShiny
  mod.exports.makeShinyDVs = makeShinyDVs
  mod.exports.applyShiny = applyShiny
  mod.exports.battleImage = battleImage
  mod.exports.drawFollowerSparkles = drawFollowerSparkles
  mod.exports.dramaticShapeCompatActive = function()
    return dramaticShapeCompat.active
  end

  mod.log:info("Gen1 Shiny System ready (rate=%s)", rateKey())
end
