-- HGSS Simple Follower v0.1.0-alpha.18
-- One selectable party follower. No PokePC, Followers EX, or Wilds runtime
-- ownership is used here; Wilds may remain installed with its follower count 0.

local SPECIES = {
  "BULBASAUR","IVYSAUR","VENUSAUR","CHARMANDER","CHARMELEON","CHARIZARD",
  "SQUIRTLE","WARTORTLE","BLASTOISE","CATERPIE","METAPOD","BUTTERFREE",
  "WEEDLE","KAKUNA","BEEDRILL","PIDGEY","PIDGEOTTO","PIDGEOT","RATTATA",
  "RATICATE","SPEAROW","FEAROW","EKANS","ARBOK","PIKACHU","RAICHU",
  "SANDSHREW","SANDSLASH","NIDORAN_F","NIDORINA","NIDOQUEEN","NIDORAN_M",
  "NIDORINO","NIDOKING","CLEFAIRY","CLEFABLE","VULPIX","NINETALES",
  "JIGGLYPUFF","WIGGLYTUFF","ZUBAT","GOLBAT","ODDISH","GLOOM","VILEPLUME",
  "PARAS","PARASECT","VENONAT","VENOMOTH","DIGLETT","DUGTRIO","MEOWTH",
  "PERSIAN","PSYDUCK","GOLDUCK","MANKEY","PRIMEAPE","GROWLITHE","ARCANINE",
  "POLIWAG","POLIWHIRL","POLIWRATH","ABRA","KADABRA","ALAKAZAM","MACHOP",
  "MACHOKE","MACHAMP","BELLSPROUT","WEEPINBELL","VICTREEBEL","TENTACOOL",
  "TENTACRUEL","GEODUDE","GRAVELER","GOLEM","PONYTA","RAPIDASH","SLOWPOKE",
  "SLOWBRO","MAGNEMITE","MAGNETON","FARFETCHD","DODUO","DODRIO","SEEL",
  "DEWGONG","GRIMER","MUK","SHELLDER","CLOYSTER","GASTLY","HAUNTER",
  "GENGAR","ONIX","DROWZEE","HYPNO","KRABBY","KINGLER","VOLTORB",
  "ELECTRODE","EXEGGCUTE","EXEGGUTOR","CUBONE","MAROWAK","HITMONLEE",
  "HITMONCHAN","LICKITUNG","KOFFING","WEEZING","RHYHORN","RHYDON","CHANSEY",
  "TANGELA","KANGASKHAN","HORSEA","SEADRA","GOLDEEN","SEAKING","STARYU",
  "STARMIE","MR_MIME","SCYTHER","JYNX","ELECTABUZZ","MAGMAR","PINSIR",
  "TAUROS","MAGIKARP","GYARADOS","LAPRAS","DITTO","EEVEE","VAPOREON",
  "JOLTEON","FLAREON","PORYGON","OMANYTE","OMASTAR","KABUTO","KABUTOPS",
  "AERODACTYL","SNORLAX","ARTICUNO","ZAPDOS","MOLTRES","DRATINI","DRAGONAIR",
  "DRAGONITE","MEWTWO","MEW",
}

local DEX = {}
for dex, species in ipairs(SPECIES) do DEX[species] = dex end

return function(mod)
  local Game = require("src.core.Game")
  local Assets = require("src.render.Assets")
  local PaletteFX = require("src.render.PaletteFX")
  local NPC = require("src.world.NPC")
  local Collision = require("src.world.Collision")
  local OverworldState = require("src.world.OverworldController")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Strings = require("src.core.Strings")
  local TextBox = require("src.render.TextBox")
  local Sound = require("src.core.Sound")
  local Stats = require("src.pokemon.Stats")

  local SPRITE_ID = "SPRITE_HGSS_SIMPLE_FOLLOWER"
  local PROVIDER_SPRITE_ID = "SPRITE_HGSS_OVERWORLD_PROVIDER"
  local NPC_INDEX = 239
  local STATE_KEY = "hgssSimpleFollower"
  local FRAME_STAND = { down = 0, up = 1, left = 2, right = 2 }
  local FRAME_WALK = { down = 3, up = 4, left = 5, right = 5 }

  local function isShiny(mon)
    if type(mon) ~= "table" then return false end
    local shinyMod = mod.find and mod:find("gen1_shiny_system")
    local use = shinyMod and shinyMod.exports
      and shinyMod.exports.shouldUseShinyArt
    if type(use) == "function" then
      local ok, value = pcall(use, mon)
      if ok then return value and true or false end
    end
    if mon.shiny == true then return true end
    return Stats.isShiny and Stats.isShiny(mon.dvs) and true or false
  end

  local function speciesKey(monOrSpecies)
    local value = type(monOrSpecies) == "table" and monOrSpecies.species
      or monOrSpecies
    if type(value) ~= "string" then return nil, "species must be a string" end
    local key = value:upper()
    if not DEX[key] then return nil, "unknown Gen 1 species: " .. tostring(value) end
    return key
  end

  local function assetPath(species, shiny)
    local dex = assert(DEX[species])
    return mod.assets:path(string.format(shiny and "shiny_%03d.png"
      or "follower_%03d.png", dex))
  end

  -- Dramatic Shape's stock billboard builder measures Gen 1 overworld sheets
  -- as 16x96.  Keep a matching per-species proxy as the definition image,
  -- while resolveImage() supplies the native 32x192 texture.  Because the
  -- billboards use normalized UVs, even the stock path then samples every
  -- complete 32x32 frame instead of the tiny upper-left fragment.
  local function proxyPath(species)
    local dex = assert(DEX[species])
    return mod.assets:path(string.format("proxy_%03d.png", dex))
  end

  -- NPC.new needs a registered sprite definition, but the live entity is
  -- immediately given the 32x32 renderer below. This placeholder never draws.
  local followerPlaceholder = {
    id = SPRITE_ID,
    image = proxyPath("CHARMANDER"),
    frames = 6,
    walker = true,
    trueColor = true,
    hgssSimpleFollower = true,
  }
  local providerPlaceholder = {
    id = PROVIDER_SPRITE_ID,
    image = proxyPath("CHARMANDER"),
    frames = 6,
    walker = true,
    trueColor = true,
    frameWidth = 32,
    frameHeight = 32,
    hgssOverworldSprite = true,
  }
  local providerDefinitionReady = false
  pcall(function()
    if mod.content.sprites:get(SPRITE_ID) then
      mod.content.sprites:patch(SPRITE_ID, followerPlaceholder)
    else
      mod.content.sprites:register(SPRITE_ID, followerPlaceholder)
    end
    if mod.content.sprites:get(PROVIDER_SPRITE_ID) then
      mod.content.sprites:patch(PROVIDER_SPRITE_ID, providerPlaceholder)
    else
      mod.content.sprites:register(PROVIDER_SPRITE_ID, providerPlaceholder)
    end
    providerDefinitionReady = mod.content.sprites:get(PROVIDER_SPRITE_ID) ~= nil
  end)

  local imageCache = {}
  local function overworldImage(species, shiny)
    local key = species .. (shiny and "#S" or "#N")
    if not imageCache[key] then
      local ok, image = pcall(Assets.image, assetPath(species, shiny))
      if not (ok and image) then
        return nil, "unavailable overworld artwork for " .. species
      end
      local dimensionsOk, width, height = pcall(image.getDimensions, image)
      if not dimensionsOk or width ~= 32 or height ~= 192 then
        return nil, string.format("invalid overworld sheet for %s: expected 32x192",
          species)
      end
      local filterOk = pcall(image.setFilter, image, "nearest", "nearest")
      if not filterOk then return nil, "could not set nearest filtering for " .. species end
      if image.setWrap then pcall(image.setWrap, image, "clamp", "clamp") end
      imageCache[key] = image
    end
    return imageCache[key]
  end
  Assets.register(function() imageCache = {} end)

  -- A native 32x32 sheet renderer. The feet retain the stock 16x16 entity
  -- anchor while the artwork extends eight pixels sideways and sixteen up.
  local OverworldSprite = {}
  OverworldSprite.__index = OverworldSprite

  function OverworldSprite.new(mon, species, shiny, providerOptions)
    local self = setmetatable({}, OverworldSprite)
    self.mon = type(mon) == "table" and mon or nil
    self.species = species
    self.shiny = shiny and true or false
    self.owner = providerOptions and providerOptions.owner or mod.id
    self.role = providerOptions and providerOptions.role or "follower"
    local provider = providerOptions ~= nil
    self.def = {
      id = provider and PROVIDER_SPRITE_ID or SPRITE_ID,
      image = proxyPath(self.species),
      frames = 6,
      walker = true,
      trueColor = true,
      frameWidth = 32,
      frameHeight = 32,
    }
    if provider then
      self.def.hgssOverworldSprite = true
    else
      self.def.hgssSimpleFollower = true
    end
    local image, reason = overworldImage(self.species, self.shiny)
    if not image then return nil, reason end
    self.image = image
    self.quads = {}
    for frame = 0, 5 do
      self.quads[frame] = love.graphics.newQuad(0, frame * 32, 32, 32, 32, 192)
    end
    return self
  end

  function OverworldSprite:resolveImage()
    return self.image
  end

  function OverworldSprite:draw(px, py, camX, camY, facing, walkPhase, stepFlip)
    local frame = ((walkPhase == 1) and FRAME_WALK or FRAME_STAND)[facing] or 0
    local flip = facing == "right"
      or (walkPhase == 1 and stepFlip and (facing == "up" or facing == "down"))
    local scale = 1
    local x = math.floor(px - camX) - 8
    local y = math.floor(py - camY) - 20
    love.graphics.setColor(1, 1, 1, 1)
    if flip then
      love.graphics.draw(self.image, self.quads[frame], x + 32, y, 0, -scale, scale)
    else
      love.graphics.draw(self.image, self.quads[frame], x, y, 0, scale, scale)
    end
    if PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(x, y, 32, 32)
    end
    local shinyMod = mod.find and mod:find("gen1_shiny_system")
    local draw = shinyMod and shinyMod.exports
      and shinyMod.exports.drawFollowerSparkles
    if type(draw) == "function" and self.mon and self.role == "follower" then
      pcall(draw, self.mon, x, y, 32, 32)
    end
  end

  local function createOverworldSprite(monOrSpecies, options)
    if not providerDefinitionReady then
      return nil, "provider sprite definition is unavailable"
    end
    if type(options) ~= "table" or type(options.owner) ~= "string"
        or options.owner == "" then
      return nil, "options.owner must be a non-empty string"
    end
    if options.role ~= nil and (type(options.role) ~= "string" or options.role == "") then
      return nil, "options.role must be a non-empty string when supplied"
    end
    local species, reason = speciesKey(monOrSpecies)
    if not species then return nil, reason end
    return OverworldSprite.new(monOrSpecies, species, isShiny(monOrSpecies), {
      owner = options.owner,
      role = options.role or "overworld",
    })
  end

  local function healthy(mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
  end

  -- OT + DVs are stable across party reordering and evolution. The slot is
  -- retained as a fast path but is never treated as the Pokemon's identity.
  local function monKey(mon)
    if type(mon) ~= "table" then return nil end
    local dvs = mon.dvs
    if type(dvs) == "table" then
      dvs = table.concat({
        tostring(dvs.attack or dvs.atk or -1),
        tostring(dvs.defense or dvs.def or -1),
        tostring(dvs.speed or dvs.spd or -1),
        tostring(dvs.special or dvs.spc or -1),
      }, ".")
    end
    return tostring(mon.otId or mon.ot or -1) .. ":" .. tostring(dvs or -1)
  end

  local function saveState(game)
    if not (game and game.save) then return nil end
    game.save[STATE_KEY] = game.save[STATE_KEY] or { enabled = false }
    return game.save[STATE_KEY]
  end

  local function firstHealthy(party)
    for slot, mon in ipairs(party or {}) do
      if healthy(mon) then return mon, slot end
    end
    return nil
  end

  local function selectedMon(game)
    local state = saveState(game)
    if not (state and state.enabled) then return nil end
    local party = game.save.party or {}
    local key = state.selectedKey
    local slot = tonumber(state.selectedSlot)
    if key and slot and party[slot] and monKey(party[slot]) == key then
      return party[slot], slot
    end
    if key then
      for index, mon in ipairs(party) do
        if monKey(mon) == key then
          state.selectedSlot = index
          return mon, index
        end
      end
    end
    return nil
  end

  -- This is also the fainting/deposit failover path. Once replacement occurs,
  -- the replacement becomes the saved selection and does not switch back later.
  local function activeMon(game)
    local state = saveState(game)
    if not (state and state.enabled) then return nil end
    local mon, slot = selectedMon(game)
    if healthy(mon) then return mon, slot end
    mon, slot = firstHealthy(game.save.party)
    if mon then
      state.selectedKey = monKey(mon)
      state.selectedSlot = slot
      state.lastFailover = true
      return mon, slot
    end
    return nil
  end

  local function selectMon(game, mon)
    if not healthy(mon) then return false end
    local state = saveState(game)
    local party = game.save.party or {}
    for slot, candidate in ipairs(party) do
      if candidate == mon then
        state.enabled = true
        state.selectedKey = monKey(mon)
        state.selectedSlot = slot
        state.lastFailover = false
        return true
      end
    end
    return false
  end

  local function followerEnabled(game)
    local state = saveState(game)
    return state and state.enabled == true
  end

  local function findFollower(ow)
    for _, npc in ipairs(ow and ow.npcs or {}) do
      if npc.hgssSimpleFollower then return npc end
    end
    return nil
  end

  local function filterList(list, predicate)
    local out = {}
    for _, value in ipairs(list or {}) do
      if predicate(value) then out[#out + 1] = value end
    end
    return out
  end

  local function removeFollower(ow)
    if not ow then return end
    ow.npcs = filterList(ow.npcs, function(npc) return not npc.hgssSimpleFollower end)
    ow.entities = filterList(ow.entities, function(entity) return not entity.hgssSimpleFollower end)
    ow.hgssSimpleTrail = nil
  end

  local function removeStockPikachu(ow)
    if not ow then return end
    ow.npcs = filterList(ow.npcs, function(npc)
      return not (npc and npc.pikachuFollower and not npc.hgssSimpleFollower)
    end)
    ow.entities = filterList(ow.entities, function(entity)
      return not (entity and entity.pikachuFollower and not entity.hgssSimpleFollower)
    end)
  end

  -- The follower may spawn only on the cell directly behind the player. The
  -- synthetic entity is passable and may temporarily occupy a coordinate just
  -- outside the destination map during a seamless connection: the engine puts
  -- the player there too while completing the cross-map step.
  local function followerSpawnCell(ow)
    local p = ow.player
    local forward = Collision.DELTA[p.facing or "down"] or Collision.DELTA.down
    local x, y = p.cellX - forward[1], p.cellY - forward[2]
    return x, y
  end

  local function makeFollower(game, ow, mon)
    local x, y = followerSpawnCell(ow)
    if x == nil or y == nil then return nil end
    local npc = NPC.new(game.data, ow.map.id, {
      index = NPC_INDEX,
      name = "HGSS_SIMPLE_FOLLOWER",
      sprite = SPRITE_ID,
      movement = "STAY",
      range = "NONE",
      x = x,
      y = y,
    })
    npc.hgssSimpleFollower = true
    npc.pikachuFollower = false
    npc.passable = true
    npc.facing = ow.player.facing or "down"
    npc.monKey = monKey(mon)
    npc.monSpecies = mon.species
    npc.monShiny = isShiny(mon)
    local species = assert(speciesKey(mon))
    npc.sprite = assert(OverworldSprite.new(mon, species, isShiny(mon)))
    npc.walkPhase = function(self)
      if self.moving then return NPC.walkPhase(self) end
      return 0
    end
    table.insert(ow.npcs, npc)
    -- Flat rendering follows entity-list order. The 32px follower card can
    -- overlap the trainer even from an adjacent tile, so insert it before the
    -- player to keep the follower visually behind the trainer.
    local playerIndex
    for index, entity in ipairs(ow.entities or {}) do
      if entity == ow.player then playerIndex = index break end
    end
    table.insert(ow.entities, playerIndex or (#ow.entities + 1), npc)
    ow.hgssSimpleTrail = { x = ow.player.cellX, y = ow.player.cellY }
    return npc
  end

  local function ledgeStep(game, ow, cx, cy, direction)
    local delta = Collision.DELTA[direction]
    if not delta then return false end
    local fx, fy = cx + delta[1], cy + delta[2]
    local lx, ly = cx + delta[1] * 2, cy + delta[2] * 2
    if not (ow.map:inBounds(fx, fy) and ow.map:inBounds(lx, ly)) then return false end
    local standing = ow.map:cellTile(cx, cy)
    local front = ow.map:cellTile(fx, fy)
    for _, ledge in ipairs(game.data.field.ledges or {}) do
      if (ledge.tileset or "OVERWORLD") == ow.map.def.tileset
        and ledge.facing == direction and ledge.input == direction
        and ledge.standingTile == standing and ledge.ledgeTile == front then
        return true
      end
    end
    return false
  end

  local function place(npc, x, y)
    npc.cellX, npc.cellY = x, y
    npc.px, npc.py = x * 16, y * 16
    npc.targetX, npc.targetY = nil, nil
    npc.goalX, npc.goalY = nil, nil
    npc.moving, npc.hopStep = false, nil
    npc.progress = 0
  end

  local function hiddenByTravel(game, ow)
    local p = ow and ow.player
    return not p or game.save.onBike or p.onBike or p.surfing or p.fishing
  end

  local function tickFollower(game, ow)
    if not (game and game.save and ow and ow.map and ow.player) then return end
    if followerEnabled(game) then removeStockPikachu(ow) end

    local mon = activeMon(game)
    if not mon or hiddenByTravel(game, ow) then
      removeFollower(ow)
      return
    end

    local npc = findFollower(ow)
    if not npc then
      npc = makeFollower(game, ow, mon)
      if not npc then return end
    elseif npc.monKey ~= monKey(mon) or npc.monSpecies ~= mon.species
        or npc.monShiny ~= isShiny(mon) then
      npc.monKey = monKey(mon)
      npc.monSpecies = mon.species
      npc.monShiny = isShiny(mon)
      local species = assert(speciesKey(mon))
      npc.sprite = assert(OverworldSprite.new(mon, species, isShiny(mon)))
    end

    local player = ow.player
    local trail = ow.hgssSimpleTrail
    if not trail then
      trail = { x = player.cellX, y = player.cellY }
      ow.hgssSimpleTrail = trail
    end

    local destX = player.targetX or player.cellX
    local destY = player.targetY or player.cellY
    if destX ~= trail.x or destY ~= trail.y then
      local direction = destY > trail.y and "down" or destY < trail.y and "up"
        or destX > trail.x and "right" or "left"
      if trail.ledgeHop == direction then
        trail.ledgeHop = nil
        trail.x, trail.y = destX, destY
      else
        trail.ledgeHop = ledgeStep(game, ow, trail.x, trail.y, direction)
          and direction or nil
        npc.goalX, npc.goalY = trail.x, trail.y
        trail.x, trail.y = destX, destY
      end
    end

    if npc.moving then return end
    if not npc.goalX then
      -- Turning in place does not commit a movement cell. Keep the follower's
      -- idle pose aligned with the trainer instead of leaving (for example) a
      -- front-facing Pokemon next to a right-facing trainer.
      if not player.targetX and not player.targetY then
        npc.facing = player.facing or npc.facing
      end
      return
    end
    local gx, gy = npc.goalX, npc.goalY
    if npc.cellX == gx and npc.cellY == gy then
      npc.goalX, npc.goalY = nil, nil
      return
    end
    local far = math.abs(npc.cellX - gx) + math.abs(npc.cellY - gy)
    if far > 6 then
      place(npc, gx, gy)
      return
    end

    local direction
    if npc.cellX < gx then direction = "right"
    elseif npc.cellX > gx then direction = "left"
    elseif npc.cellY < gy then direction = "down"
    else direction = "up" end
    npc.facing = direction
    local delta = Collision.DELTA[direction]
    npc.targetX = npc.cellX + delta[1]
    npc.targetY = npc.cellY + delta[2]
    npc.hopStep = nil
    if ledgeStep(game, ow, npc.cellX, npc.cellY, direction) then
      npc.targetX = npc.cellX + delta[1] * 2
      npc.targetY = npc.cellY + delta[2] * 2
      npc.goalX, npc.goalY = npc.targetX, npc.targetY
      npc.hopStep = true
    end
    local stepFrames = player.stepFramesCur or player.stepFrames or 16
    if far > 1 and not npc.hopStep then
      stepFrames = math.max(1, math.floor(stepFrames / 2))
    end
    npc.stepFrames = stepFrames
    npc.moving = true
    npc.progress = 0
    npc:update(ow.map, ow.entities)
  end

  local function displayName(game, mon)
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    return mon.nickname or (def and def.name) or mon.species
  end

  local function showMessage(game, format, mon)
    if not (game and game.stack and TextBox and TextBox.new) then return end
    game.stack:push(TextBox.new(game, Strings(format, displayName(game, mon))))
  end

  -- Remove legacy Wilds/Followers menu rows from the composed list, then add
  -- this mod's single unambiguous action. Wild spawning itself is untouched.
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
      local out = next(game, items, mon, ctx)
      if type(out) ~= "table" or (ctx and ctx.battle) then return out end
      local cleaned = {}
      for _, row in ipairs(out) do
        local label = type(row) == "table" and tostring(row.label or ""):upper() or ""
        if label ~= "FOLLOWER" and label ~= "FOLLOWING" and label ~= "LEADER"
          and label ~= "FOLLOW" and label ~= "STOP FOLLOWING" then
          cleaned[#cleaned + 1] = row
        end
      end
      if not healthy(mon) then return cleaned end

      local current = activeMon(game)
      local isCurrent = current == mon
      cleaned[#cleaned + 1] = {
        label = Strings(isCurrent and "STOP FOLLOWING" or "FOLLOW"),
        onSelect = function(selected, selectedGame)
          if isCurrent then
            local state = saveState(selectedGame)
            state.enabled = false
            removeFollower(selectedGame.overworld)
            showMessage(selectedGame, "%s stopped\nfollowing you.", selected)
          elseif selectMon(selectedGame, selected) then
            removeFollower(selectedGame.overworld)
            tickFollower(selectedGame, selectedGame.overworld)
            pcall(Sound.play, selectedGame.data, "Swap")
            showMessage(selectedGame, "%s is now\nfollowing you!", selected)
          end
        end,
      }
      return cleaned
    end)
  end

  -- Install after lower-priority world owners (including Wilds), preserving
  -- their update behavior and adding only this entity at the end of the tick.
  local previous = rawget(OverworldState, "_hgssSimpleFollowerState")
  if previous and type(previous.restore) == "function" then pcall(previous.restore) end
  local originalUpdate = OverworldState.update
  local updateWrapper
  updateWrapper = function(self, dt, ...)
    local result = originalUpdate(self, dt, ...)
    local ok, err = pcall(tickFollower, Game, self)
    if not ok and mod.log then mod.log:error("Follower update failed: %s", tostring(err)) end
    return result
  end
  OverworldState.update = updateWrapper

  -- map.entered fires in the middle of a seamless connection, before the
  -- engine moves the player back into the seam-walk start cell. Spawn only
  -- after crossConnection finishes that rebase so the follower is calculated
  -- from the live player position rather than the intermediate landing cell.
  local originalCrossConnection = OverworldState.crossConnection
  local crossConnectionWrapper
  if type(originalCrossConnection) == "function" then
    crossConnectionWrapper = function(self, ...)
      local result = originalCrossConnection(self, ...)
      if result then
        local ok, err = pcall(tickFollower, Game, self)
        if not ok and mod.log then
          mod.log:error("Follower connection sync failed: %s", tostring(err))
        end
      end
      return result
    end
    OverworldState.crossConnection = crossConnectionWrapper
  end

  -- The follower intentionally has no talk/emotion feature. Prevent the base
  -- NPC interaction path from looking for map text on our synthetic object.
  local originalInteract = OverworldState.interact
  local interactWrapper
  interactWrapper = function(self, ...)
    local p = self.player
    if p then
      local x, y = p:facingCell()
      local npc = self:npcAtCell(x, y)
      if npc and npc.hgssSimpleFollower then return end
    end
    return originalInteract(self, ...)
  end
  OverworldState.interact = interactWrapper

  -- Dramatic Shape: a real 32x32 centered card instead of its stock 16x16
  -- billboard. This changes visual geometry only, never collision or maps.
  local voxelInstalls = {}
  local function installVoxelRenderer(modId)
    local renderer = type(mod.find) == "function" and mod:find(modId)
    local lib = renderer and renderer.exports and renderer.exports.lib
    if not lib and Game and Game.mods and Game.mods.exports
        and Game.mods.exports[modId] then
      lib = Game.mods.exports[modId].lib
    end
    if not (lib and lib.require) then return false end
    local SB = lib.require("SpriteBillboards")
    local Voxel3D = lib.require("Voxel3D")
    if not (SB and Voxel3D) then return false end
    local installed = voxelInstalls[SB]
    if installed and SB.mesh == installed.mesh then return true end
    local originalMesh, originalShadow = SB.mesh, SB.shadowQuad
    local cache = {}

    local function build(def, frame)
      local image = Assets.image(def.image)
      local iw, ih = image:getDimensions()
      -- UVs are normalized against the 16x96 proxy. resolveImage() replaces
      -- that proxy with the native 32x192 texture at draw time.
      local fy = math.max(0, math.min(5, math.floor(tonumber(frame) or 0))) * 16
      local vertices = {
        { -8, 0, 0, 0.05 / iw, (fy + 15.95) / ih, 1 },
        { 24, 0, 0, 15.95 / iw, (fy + 15.95) / ih, 1 },
        { 24, 32, 0, 15.95 / iw, (fy + 0.05) / ih, 1 },
        { -8, 32, 0, 0.05 / iw, (fy + 0.05) / ih, 1 },
      }
      local indices = {}
      Voxel3D.pushQuad(indices, 0)
      return Voxel3D.newMesh(vertices, indices)
    end

    local function customMesh(nextMesh, def, frame)
      if not (def and (def.id == SPRITE_ID or def.id == PROVIDER_SPRITE_ID
          or def.hgssSimpleFollower or def.hgssOverworldSprite)) then
        return nextMesh(def, frame)
      end
      local key = tostring(def.image) .. "#" .. tostring(frame or 0)
      if cache[key] == nil then
        local ok, mesh = pcall(build, def, frame)
        cache[key] = ok and mesh or false
      end
      return cache[key] or nextMesh(def, frame)
    end

    local meshWrapper = function(def, frame) return customMesh(originalMesh, def, frame) end
    local shadowWrapper = function(def, frame) return customMesh(originalShadow, def, frame) end
    SB.mesh = meshWrapper
    SB.shadowQuad = shadowWrapper
    SB._hgssSimpleFollowerMesh = meshWrapper
    voxelInstalls[SB] = {
      mesh = meshWrapper,
      restore = function()
      if SB.mesh == meshWrapper then SB.mesh = originalMesh end
      if SB.shadowQuad == shadowWrapper then SB.shadowQuad = originalShadow end
      if SB._hgssSimpleFollowerMesh == meshWrapper then SB._hgssSimpleFollowerMesh = nil end
      cache = {}
      end,
    }
    return true
  end

  local function installVoxelRenderers()
    local any = false
    for _, id in ipairs({ "DRAMATIC_SHAPE", "BATTLE_ART_VOXEL_FORK" }) do
      local ok, installed = pcall(installVoxelRenderer, id)
      if ok and installed then any = true end
    end
    return any
  end
  pcall(installVoxelRenderers)

  if mod.events and mod.events.on then
    mod.events:on("mods.loaded", function() pcall(installVoxelRenderers) end)
    mod.events:on("game.ready", function()
      if Game and Game.overworld then
        removeFollower(Game.overworld)
        pcall(installVoxelRenderers)
        pcall(tickFollower, Game, Game.overworld)
      end
    end)
    mod.events:on("map.entered", function(payload)
      if Game and Game.overworld then
        removeFollower(Game.overworld)
        pcall(installVoxelRenderers)
        if not (payload and payload.via == "connection") then
          pcall(tickFollower, Game, Game.overworld)
        end
      end
    end)
    mod.events:on("battle.ended", function()
      if Game and Game.overworld then pcall(tickFollower, Game, Game.overworld) end
    end)
  end

  local runtimeState = {}
  runtimeState.restore = function()
    if OverworldState.update == updateWrapper then OverworldState.update = originalUpdate end
    if crossConnectionWrapper and OverworldState.crossConnection == crossConnectionWrapper then
      OverworldState.crossConnection = originalCrossConnection
    end
    if OverworldState.interact == interactWrapper then OverworldState.interact = originalInteract end
    for _, installed in pairs(voxelInstalls) do
      if installed.restore then pcall(installed.restore) end
    end
    voxelInstalls = {}
    if rawget(OverworldState, "_hgssSimpleFollowerState") == runtimeState then
      rawset(OverworldState, "_hgssSimpleFollowerState", nil)
    end
  end
  rawset(OverworldState, "_hgssSimpleFollowerState", runtimeState)

  mod.exports.activeMon = activeMon
  mod.exports.select = selectMon
  mod.exports.stop = function(game)
    local state = saveState(game)
    if state then state.enabled = false end
    removeFollower(game and game.overworld)
  end
  mod.exports.tick = tickFollower
  mod.exports.monKey = monKey
  mod.exports.spriteSize = 32
  mod.exports.overworldSpriteApiVersion = 1
  mod.exports.overworldSpriteDefinitionId = PROVIDER_SPRITE_ID
  mod.exports.createOverworldSprite = createOverworldSprite
  mod.exports.restore = runtimeState.restore

  if mod.log then
    mod.log:info("HGSS Simple Follower loaded (32px hot-reloadable card and source)")
  end
end
