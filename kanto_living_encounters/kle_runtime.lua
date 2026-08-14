return function(Core, Tables)
  local Runtime = {}

  local DIRS = { "up", "down", "left", "right" }

  local function removeValue(list, value)
    for index = #(list or {}), 1, -1 do
      if list[index] == value then table.remove(list, index) end
    end
  end

  local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[deepCopy(key, seen)] = deepCopy(item, seen) end
    return out
  end

  local function random01()
    if love and love.math and love.math.random then return love.math.random() end
    return math.random()
  end

  local function randomInt(a, b)
    if love and love.math and love.math.random then
      if b == nil then return love.math.random(a) end
      return love.math.random(a, b)
    end
    if b == nil then return math.random(a) end
    return math.random(a, b)
  end

  function Runtime.install(mod)
    local Game = require("src.core.Game")
    local NPC = require("src.world.NPC")
    local Collision = require("src.world.Collision")
    local OverworldState = require("src.world.OverworldController")
    local BattleState = require("src.battle.BattleState")
    local Map = require("src.world.Map")
    local Sound = require("src.core.Sound")

    local previous = rawget(OverworldState, "_kantoLivingEncountersState")
    if previous and type(previous.restore) == "function" then pcall(previous.restore) end

    local state = {
      mapId = nil,
      area = "unsupported",
      table = nil,
      eligible = {},
      eligibleByKey = {},
      active = {},
      serial = 0,
      target = 0,
      stepsSinceRefill = 0,
      now = 0,
      lastReason = nil,
      installed = true,
      inBattle = false,
      snapshotRevision = 0,
      needsRefill = false,
      aggressionCooldownUntil = 0,
    }

    local function option(key, default)
      local ok, value = pcall(mod.options.get, mod.options, key)
      if ok and value ~= nil then return value end
      return default
    end

    local function optionSignature()
      return table.concat({
        option("enabled", true) == false and "0" or "1",
        option("aggressive", true) == false and "0" or "1",
        tostring(option("amount", "regular")),
        option("towns", true) == false and "0" or "1",
      }, ":")
    end

    local function provider(modId)
      local handle = type(mod.find) == "function" and mod:find(modId)
      return handle and handle.exports or nil
    end

    local function spriteProvider()
      local exports = provider("hgss_simple_follower")
      if Core.validateSpriteProvider(exports) then return exports end
      return nil
    end

    local function shinyProvider()
      local exports = provider("gen1_shiny_system")
      if Core.validateShinyProvider(exports) then return exports end
      return nil
    end

    local function logReject(reason)
      if state.lastReason ~= reason and mod.log then
        mod.log:warn("Visible spawn unavailable: %s", tostring(reason))
      end
      state.lastReason = reason
    end

    local function entityOccupies(ow, x, y, ignore)
      for _, entity in ipairs(ow and ow.entities or {}) do
        if entity ~= ignore and ((entity.cellX == x and entity.cellY == y)
          or (entity.targetX == x and entity.targetY == y)) then
          return true
        end
      end
      return false
    end

    local function forbidden(map, x, y)
      if not map:inBounds(x, y) then return true end
      if map:warpAtCell(x, y) or map:isWarpTileCell(x, y)
        or map:isDoorTileCell(x, y) or map:signAtCell(x, y) then
        return true
      end
      return false
    end

    local function nearGrass(map, x, y)
      for dy = -2, 2 do
        for dx = -2, 2 do
          if math.abs(dx) + math.abs(dy) <= 2 and map:isGrassCell(x + dx, y + dy) then
            return true
          end
        end
      end
      return false
    end

    local function addEligible(cell)
      state.eligible[#state.eligible + 1] = cell
      state.eligibleByKey[Core.cellKey(cell.x, cell.y)] = cell
    end

    local function reachableFromPlayer(ow)
      local map, player = ow.map, ow.player
      local start = Core.cellKey(player.cellX, player.cellY)
      local seen = { [start] = true }
      local queue = { { x = player.cellX, y = player.cellY } }
      local head = 1
      while head <= #queue do
        local node = queue[head]
        head = head + 1
        for _, direction in ipairs(DIRS) do
          local delta = Collision.DELTA[direction]
          local nx, ny = node.x + delta[1], node.y + delta[2]
          local key = Core.cellKey(nx, ny)
          if not seen[key] and not forbidden(map, nx, ny) then
            local probe = {
              cellX = node.x, cellY = node.y,
              surfing = player.surfing and true or false,
            }
            if Collision.canMove(map, {}, probe, direction) then
              seen[key] = true
              queue[#queue + 1] = { x = nx, y = ny }
            end
          end
        end
      end
      return seen
    end

    local function accessibleWaterCells(map, reachable, player)
      local water = {}
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          if not forbidden(map, x, y) and map:isWaterCell(x, y)
            and not map:isWalkableCell(x, y) then
            water[Core.cellKey(x, y)] = true
          end
        end
      end
      local seen, accessible = {}, {}
      for key in pairs(water) do
        if not seen[key] then
          local sx, sy = key:match("^(-?%d+):(-?%d+)$")
          local queue = { { x = tonumber(sx), y = tonumber(sy) } }
          local component, head, canReach = {}, 1, false
          seen[key] = true
          while head <= #queue do
            local node = queue[head]
            head = head + 1
            component[#component + 1] = node
            if node.x == player.cellX and node.y == player.cellY then canReach = true end
            for _, direction in ipairs(DIRS) do
              local delta = Collision.DELTA[direction]
              local nx, ny = node.x + delta[1], node.y + delta[2]
              local neighborKey = Core.cellKey(nx, ny)
              if water[neighborKey] and not seen[neighborKey] then
                seen[neighborKey] = true
                queue[#queue + 1] = { x = nx, y = ny }
              elseif reachable[neighborKey] and map:inBounds(nx, ny)
                and map:isWalkableCell(nx, ny) then
                canReach = true
              end
            end
          end
          if canReach then
            for _, node in ipairs(component) do
              accessible[Core.cellKey(node.x, node.y)] = true
            end
          end
        end
      end
      return accessible
    end

    local function collectEligible(ow)
      state.eligible, state.eligibleByKey = {}, {}
      local map, player = ow.map, ow.player
      local reachable = reachableFromPlayer(ow)
      local accessibleWater = accessibleWaterCells(map, reachable, player)
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          if not forbidden(map, x, y)
            and Core.distance(x, y, player.cellX, player.cellY) >= Core.MIN_PLAYER_DISTANCE
            and not entityOccupies(ow, x, y) then
            local walkable = map:isWalkableCell(x, y)
            -- isWaterCell deliberately includes walkable shore tiles for the
            -- engine's surf transition. Visible swimmers use open water only.
            local water = map:isWaterCell(x, y) and not walkable
            local landAllowed = false
            if state.area == "town" then landAllowed = walkable
            elseif state.area == "route" then landAllowed = walkable and nearGrass(map, x, y)
            elseif state.area == "cave" then landAllowed = walkable
            elseif state.area == "water" then landAllowed = false end
            landAllowed = landAllowed and reachable[Core.cellKey(x, y)] == true

            if water and accessibleWater[Core.cellKey(x, y)]
              and state.table and #state.table.water > 0 then
              addEligible({ x = x, y = y, surface = "water" })
            elseif landAllowed and state.table and #state.table.land > 0 then
              addEligible({ x = x, y = y, surface = "land" })
            end
          end
        end
      end
    end

    local function activeNear(x, y, minDistance, ignore)
      for _, entity in ipairs(state.active) do
        if entity ~= ignore and entity.state == "AVAILABLE"
          and Core.distance(x, y, entity.cellX, entity.cellY) < minDistance then
          return true
        end
      end
      return false
    end

    local function removeEntity(ow, entity)
      if not entity then return end
      removeValue(ow and ow.npcs, entity.npc)
      removeValue(ow and ow.entities, entity.npc)
      removeValue(state.active, entity)
      entity.state = "REMOVED"
      if ow and ow.emote and ow.emote.npc == entity.npc then ow.emote = nil end
      if ow and ow.kleEngaging == entity then
        ow.kleEngaging = nil
        if ow.player then ow.player.inputLocked = false end
      end
    end

    local function clearOrdinary(ow)
      for index = #state.active, 1, -1 do
        local entity = state.active[index]
        if not entity.shiny then removeEntity(ow, entity) end
      end
      state.stepsSinceRefill = Core.REFILL_STEPS
    end

    local function clearAll(ow)
      for index = #state.active, 1, -1 do removeEntity(ow, state.active[index]) end
      state.active = {}
    end

    local function allowedCell(entity, x, y)
      local cell = state.eligibleByKey[Core.cellKey(x, y)]
      return cell and cell.surface == entity.surface
    end

    local function surfaceMatches(entity, map, x, y)
      if forbidden(map, x, y) then return false end
      local walkable = map:isWalkableCell(x, y)
      local water = map:isWaterCell(x, y) and not walkable
      if entity.surface == "water" then return water end
      return walkable and not water
    end

    local function beginMove(ow, entity, direction, allowPlayer)
      if entity.npc.moving then return false end
      local delta = Collision.DELTA[direction]
      if not delta then return false end
      local tx, ty = entity.cellX + delta[1], entity.cellY + delta[2]
      local onPlayer = ow.player.cellX == tx and ow.player.cellY == ty
      if not allowedCell(entity, tx, ty)
        and not (allowPlayer and onPlayer and surfaceMatches(entity, ow.map, tx, ty)) then
        return false
      end
      if forbidden(ow.map, tx, ty) then return false end
      if activeNear(tx, ty, 1, entity) then return false end
      for _, other in ipairs(ow.entities or {}) do
        if other ~= entity.npc and other ~= ow.player and not other.kantoLivingEncounter
          and ((other.cellX == tx and other.cellY == ty)
            or (other.targetX == tx and other.targetY == ty)) then
          return false
        end
      end
      if onPlayer and not allowPlayer then return false end
      entity.npc.facing = direction
      entity.npc.targetX, entity.npc.targetY = tx, ty
      entity.npc.stepFrames = entity.behavior == "aggressive" and 8 or 16
      entity.npc.progress = 0
      entity.npc.moving = true
      entity.cellX, entity.cellY = tx, ty
      return true
    end

    local function shortestDirection(entity, tx, ty, map)
      local startKey = Core.cellKey(entity.npc.cellX, entity.npc.cellY)
      local targetKey = Core.cellKey(tx, ty)
      if startKey == targetKey then return nil end
      local queue = { { x = entity.npc.cellX, y = entity.npc.cellY } }
      local head, seen = 1, { [startKey] = true }
      while head <= #queue and head <= 512 do
        local node = queue[head]
        head = head + 1
        for _, direction in ipairs(DIRS) do
          local delta = Collision.DELTA[direction]
          local nx, ny = node.x + delta[1], node.y + delta[2]
          local key = Core.cellKey(nx, ny)
          local target = key == targetKey
          if not seen[key] and (allowedCell(entity, nx, ny)
            or (target and surfaceMatches(entity, map, nx, ny))) then
            seen[key] = true
            local first = node.first or direction
            if target then return first end
            queue[#queue + 1] = { x = nx, y = ny, first = first }
          end
        end
      end
      return nil
    end

    local function encounterContact(ow, entity)
      local p, npc = ow.player, entity.npc
      return npc.cellX == p.cellX and npc.cellY == p.cellY
    end

    local function beginBattle(ow, entity)
      if not entity.battleable or not Core.transition(entity, "AVAILABLE", "ENCOUNTER_STARTING") then
        return false
      end
      removeValue(ow.npcs, entity.npc)
      removeValue(ow.entities, entity.npc)
      removeValue(state.active, entity)
      if ow.kleEngaging == entity then ow.kleEngaging = nil end
      ow.player.inputLocked = false

      local shiny = shinyProvider()
      if not shiny then
        entity.state = "REMOVED"
        logReject("Gen1 Shiny System Wild Outcome API v1 is unavailable")
        return false
      end
      local okOpts, opts = pcall(shiny.wildBattleOptions, entity.shinyOutcome)
      if not okOpts or type(opts) ~= "table" then
        entity.state = "REMOVED"
        logReject("Gen1 Shiny System rejected the reserved wild outcome")
        return false
      end
      local okBattle, battle = pcall(BattleState.newWild, Game,
        entity.species, entity.level, opts)
      if not okBattle or not battle then
        entity.state = "REMOVED"
        logReject("wild battle construction failed: " .. tostring(battle))
        return false
      end
      entity.state = "IN_BATTLE"
      local ghost = Map.ghostBattles(ow.map.def)
      if ghost and not (ghost.unlessItem and Game.save.inventory[ghost.unlessItem]) then
        battle:makeGhost()
      end
      if Game.save.safari and Map.inRegion(ow.map.def, "SAFARI", "SAFARI_ZONE") then
        battle:makeSafari(Game.save.safari)
      end
      battle.onFinish = function(result)
        entity.state = "REMOVED"
        ow:afterBattle(result, battle)
      end
      ow:pushBattle(battle)
      return true
    end

    local function reserveShiny()
      local shiny = shinyProvider()
      if not shiny then return nil, "Gen1 Shiny System Wild Outcome API v1 is unavailable" end
      local ok, outcome = pcall(shiny.reserveWildOutcome, randomInt)
      if not ok or type(outcome) ~= "table" or type(outcome.shiny) ~= "boolean" then
        return nil, "Gen1 Shiny System returned an invalid wild outcome"
      end
      return outcome
    end

    local function createSprite(mon)
      local sprites = spriteProvider()
      if not sprites then return nil, "HGSS overworld Sprite API v1 is unavailable" end
      local ok, sprite = pcall(sprites.createOverworldSprite, mon, {
        owner = "kanto_living_encounters",
        role = "wild",
      })
      if not ok or type(sprite) ~= "table" or type(sprite.draw) ~= "function"
        or type(sprite.def) ~= "table" or type(sprite.def.id) ~= "string" then
        return nil, "HGSS sprite provider declined " .. tostring(mon.species)
      end
      return sprite
    end

    local function spawnOne(ow)
      if #state.eligible == 0 then return false end
      local attempts = math.min(64, #state.eligible * 2)
      for _ = 1, attempts do
        local cell = state.eligible[randomInt(1, #state.eligible)]
        if not entityOccupies(ow, cell.x, cell.y)
          and not activeNear(cell.x, cell.y, Core.MIN_WILD_DISTANCE) then
          local pool = cell.surface == "water" and state.table.water or state.table.land
          local excluded
          if state.area == "town" then
            excluded = {}
            for _, active in ipairs(state.active) do excluded[active.species] = true end
          end
          local species, level, source = Tables.pick(pool, function(a, b)
            if a ~= nil then return randomInt(a, b) end
            return random01()
          end, excluded)
          if species then
            local outcome, outcomeError = reserveShiny()
            if not outcome then logReject(outcomeError) return false end
            local mon = { species = species, shiny = outcome.shiny and true or nil, dvs = outcome.dvs }
            local sprite, spriteError = createSprite(mon)
            if not sprite then logReject(spriteError) return false end
            state.serial = state.serial + 1
            local npc = NPC.new(Game.data, ow.map.id, {
              index = 20000 + state.serial,
              name = "KANTO_LIVING_ENCOUNTER",
              sprite = sprite.def.id,
              movement = "STAY",
              range = "NONE",
              x = cell.x,
              y = cell.y,
            })
            npc.sprite = sprite
            npc.passable = false
            npc.kantoLivingEncounter = true
            npc.wanders = false
            local behavior = Core.chooseBehavior(state.area,
              option("aggressive", true), random01)
            local entity = {
              id = ow.map.id .. ":" .. tostring(state.serial),
              mapId = ow.map.id,
              area = state.area,
              species = species,
              level = level,
              shiny = outcome.shiny,
              shinyOutcome = outcome,
              surface = cell.surface,
              behavior = behavior,
              battleable = Core.isBattleable(state.area, behavior),
              sourceMap = source and source.sourceMap,
              sourceProvider = state.table.sourceProvider,
              state = "AVAILABLE",
              cellX = cell.x,
              cellY = cell.y,
              homeX = cell.x,
              homeY = cell.y,
              spawnedAt = state.now,
              nextMoveAt = state.now + (behavior == "idle" and randomInt(5, 10)
                or randomInt(1, 3)),
              npc = npc,
            }
            if behavior == "aggressive" then
              state.aggressionCooldownUntil = math.max(
                state.aggressionCooldownUntil,
                state.now + Core.AGGRESSION_SPAWN_COOLDOWN)
            end
            npc.kleEntity = entity
            ow.npcs[#ow.npcs + 1] = npc
            ow.entities[#ow.entities + 1] = npc
            state.active[#state.active + 1] = entity
            state.lastReason = nil
            return true
          end
        end
      end
      state.lastReason = "no separated safe cell is currently available"
      return false
    end

    local function refill(ow, maximum)
      maximum = maximum or state.target
      local added = 0
      while #state.active < state.target and added < maximum do
        if not spawnOne(ow) then break end
        added = added + 1
      end
      return added
    end

    local function setupMap(ow)
      clearAll(ow)
      state.table = nil
      state.target = 0
      state.eligible = {}
      state.eligibleByKey = {}
      state.mapId = ow and ow.map and ow.map.id or nil
      state.now = 0
      state.stepsSinceRefill = 0
      state.needsRefill = false
      state.aggressionCooldownUntil = 0
      state.snapshotRevision = state.snapshotRevision + 1
      state.optionSignature = optionSignature()
      if not (ow and ow.map and ow.player and state.mapId) then return end
      if option("enabled", true) == false then state.area = "unsupported" return end
      local encDef = Game.data.encounters[state.mapId]
      state.area = Core.classify(state.mapId, ow.map.def, encDef)
      if state.area == "town" and option("towns", true) == false then
        state.area = "unsupported"
      end
      if state.area == "unsupported" then return end
      if not spriteProvider() then logReject("HGSS overworld Sprite API v1 is unavailable") return end
      if not shinyProvider() then logReject("Gen1 Shiny System Wild Outcome API v1 is unavailable") return end
      state.table = Tables.resolve(Game.data, state.mapId, state.area)
      if #state.table.land == 0 and #state.table.water == 0 then
        logReject("no live encounter pool for " .. state.mapId)
        return
      end
      collectEligible(ow)
      state.target = Core.targetForAmount(option("amount", "regular"), randomInt,
        #state.eligible)
      refill(ow, state.target)
    end

    local function randomMove(ow, entity)
      local offset = randomInt(1, #DIRS)
      for index = 0, #DIRS - 1 do
        local direction = DIRS[((offset + index - 1) % #DIRS) + 1]
        if beginMove(ow, entity, direction, true) then return true end
      end
      return false
    end

    local function beginAggression(ow, entity)
      if ow.kleEngaging or ow.engaging or ow.emote or entity.state ~= "AVAILABLE" then return end
      if not surfaceMatches(entity, ow.map, ow.player.cellX, ow.player.cellY) then return end
      if not shortestDirection(entity, ow.player.cellX, ow.player.cellY, ow.map) then return end
      ow.kleEngaging = entity
      ow.player.inputLocked = true
      entity.aggressiveStage = "alert"
      entity.npc:facePlayer(ow.player)
      ow.emote = {
        npc = entity.npc,
        frames = 60,
        onDone = function()
          if entity.state == "AVAILABLE" and ow.kleEngaging == entity then
            entity.aggressiveStage = "chasing"
            entity.chaseUntil = state.now + 8
          else
            ow.player.inputLocked = false
          end
        end,
      }
    end

    local function tickEntity(ow, entity)
      local npc = entity.npc
      entity.cellX, entity.cellY = npc.cellX, npc.cellY
      if entity.battleable and encounterContact(ow, entity) then
        return beginBattle(ow, entity)
      end
      if npc.moving or entity.state ~= "AVAILABLE" then return false end

      if entity.behavior == "aggressive" then
        if entity.aggressiveStage == "chasing" then
          if state.now >= (entity.chaseUntil or 0) then
            entity.aggressiveStage = nil
            ow.kleEngaging = nil
            ow.player.inputLocked = false
            entity.nextMoveAt = state.now + 1
            return false
          end
          local direction = shortestDirection(entity, ow.player.cellX, ow.player.cellY, ow.map)
          if direction then beginMove(ow, entity, direction, true) end
          return false
        end
        -- Newly created aggressive encounters remain still during the shared
        -- grace period. Player-initiated same-cell contact is handled above.
        if Core.aggressionCoolingDown(state.now, state.aggressionCooldownUntil) then
          return false
        end
        if Core.distance(npc.cellX, npc.cellY, ow.player.cellX, ow.player.cellY)
          <= Core.DETECTION_RADIUS then
          beginAggression(ow, entity)
          return false
        end
      end

      if state.now >= (entity.nextMoveAt or 0) then
        randomMove(ow, entity)
        if entity.behavior == "idle" then
          entity.nextMoveAt = state.now + randomInt(5, 10)
        else
          entity.nextMoveAt = state.now + 0.5 + random01() * 1.5
        end
      end
      return false
    end

    local function tick(ow, dt)
      if not (state.installed and ow and ow.map and ow.player) then return end
      if state.optionSignature ~= optionSignature() then
        setupMap(ow)
        return
      end
      state.now = state.now + math.max(0, tonumber(dt) or 0)
      if state.mapId ~= ow.map.id then setupMap(ow) end
      if Game.stack and Game.stack.top and Game.stack:top() ~= ow then return end

      for index = #state.active, 1, -1 do
        local entity = state.active[index]
        local expired = Core.shouldExpire(entity, state.now,
          ow.player.cellX, ow.player.cellY)
        if expired and not (ow.kleEngaging == entity) then
          removeEntity(ow, entity)
          state.needsRefill = true
        else
          if tickEntity(ow, entity) then return end
        end
      end
      if Game.stack and Game.stack.top and Game.stack:top() ~= ow then return end
      if state.needsRefill or state.stepsSinceRefill >= Core.REFILL_STEPS then
        state.stepsSinceRefill = 0
        state.needsRefill = false
        refill(ow, state.area == "town" and 1 or 2)
      end
    end

    local function snapshot()
      local entities = {}
      for _, entity in ipairs(state.active) do
        entities[#entities + 1] = {
          id = entity.id, species = entity.species, level = entity.level,
          shiny = entity.shiny and true or false, surface = entity.surface,
          behavior = entity.behavior, battleable = entity.battleable,
          state = entity.state, x = entity.npc.cellX, y = entity.npc.cellY,
          sourceMap = entity.sourceMap,
        }
      end
      return {
        schemaVersion = 1, mapId = state.mapId, area = state.area,
        eligibleCells = #state.eligible, target = state.target,
        active = entities, lastReason = state.lastReason,
        aggressionCooldownRemaining = math.max(0,
          state.aggressionCooldownUntil - state.now),
        sourceProvider = state.table and state.table.sourceProvider,
        sourceMaps = state.table and deepCopy(state.table.sources) or {},
      }
    end

    local originalUpdate = OverworldState.update
    local updateWrapper = function(self, dt, ...)
      local result = originalUpdate(self, dt, ...)
      local ok, err = pcall(tick, self, dt)
      if not ok and mod.log then mod.log:error("visible spawn update failed: %s", tostring(err)) end
      return result
    end
    OverworldState.update = updateWrapper

    local originalSetMap = OverworldState.setMap
    local setMapWrapper = function(self, ...)
      local result = originalSetMap(self, ...)
      local ok, err = pcall(setupMap, self)
      if not ok and mod.log then mod.log:error("visible spawn map setup failed: %s", tostring(err)) end
      return result
    end
    OverworldState.setMap = setMapWrapper

    local originalPushBattle = OverworldState.pushBattle
    local pushBattleWrapper = function(self, battle, ...)
      clearOrdinary(self)
      state.inBattle = true
      return originalPushBattle(self, battle, ...)
    end
    OverworldState.pushBattle = pushBattleWrapper

    local originalAfterBattle = OverworldState.afterBattle
    local afterBattleWrapper = function(self, ...)
      local result = originalAfterBattle(self, ...)
      state.inBattle = false
      state.stepsSinceRefill = Core.REFILL_STEPS
      return result
    end
    OverworldState.afterBattle = afterBattleWrapper

    -- A completed step onto a visible wild belongs to that visible contact.
    -- Every other step passes through to the native routine unchanged, so the
    -- ordinary grass/cave/water roll remains live.
    local originalOnStepComplete = OverworldState.onStepComplete
    local onStepCompleteWrapper = function(self, ...)
      for _, entity in ipairs(state.active) do
        if entity.battleable and encounterContact(self, entity) then
          if beginBattle(self, entity) then return end
        end
      end
      return originalOnStepComplete(self, ...)
    end
    OverworldState.onStepComplete = onStepCompleteWrapper

    -- Town encounters are flavor NPCs when approached with the A button.
    -- Interaction never constructs a battle; aggressive town encounters may
    -- still start one independently through their proximity/contact behavior.
    local originalTalkTo = OverworldState.talkTo
    local talkToWrapper = function(self, npc, ...)
      local entity = npc and npc.kleEntity
      if entity and entity.area == "town" then
        if type(npc.facePlayer) == "function" then npc:facePlayer(self.player) end
        local ok, err = pcall(Sound.playCry, Game.data, entity.species)
        if not ok and mod.log then
          mod.log:error("town Pokemon cry failed: %s", tostring(err))
        end
        return
      end
      return originalTalkTo(self, npc, ...)
    end
    OverworldState.talkTo = talkToWrapper

    local removeCollisionHook
    if mod.hooks and mod.hooks.wrap then
      removeCollisionHook = mod.hooks:wrap("movement.collision",
        function(next, allowed, context)
          local result = next(allowed, context)
          if result or not (context and context.reason == "entity") then return result end
          local ow = Game.overworld
          if not (ow and context.mover == ow.player) then return result end
          local blocker = Collision.occupied(ow.entities, context.toX, context.toY,
            context.mover)
          if blocker and blocker.kantoLivingEncounter then return true end
          return result
        end)
    end

    local originalDrawUI = OverworldState.drawUI
    local drawUIWrapper = function(self, ...)
      local result = originalDrawUI(self, ...)
      if option("debug", false) and love and love.graphics then
        local s = snapshot()
        local label = string.format("KLE %s | %s | cells %d | target %d | active %d | %s",
          tostring(s.mapId or "-"), tostring(s.area), s.eligibleCells, s.target,
          #s.active, tostring(s.lastReason or s.sourceProvider or "-"))
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 2, 2, 156, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, 4, 4, 0, 0.5, 0.5)
      end
      return result
    end
    OverworldState.drawUI = drawUIWrapper

    if mod.events and mod.events.on then
      mod.events:on("world.stepped", function(payload)
        if payload and payload.mapId == state.mapId then
          state.stepsSinceRefill = state.stepsSinceRefill + 1
        end
      end)
      mod.events:on("mods.loaded", function()
        if Game.overworld then pcall(setupMap, Game.overworld) end
      end)
    end

    local runtime = {}
    runtime.resolveSpawnTable = function(context)
      local mapId = type(context) == "table" and context.mapId or state.mapId
      if not mapId then return nil end
      local mapDef = Game.data.maps[mapId]
      local area = type(context) == "table" and context.area
        or Core.classify(mapId, mapDef, Game.data.encounters[mapId])
      return deepCopy(Tables.resolve(Game.data, mapId, area))
    end
    runtime.getSpawnSnapshot = snapshot
    runtime.getEffectiveSpawnSnapshot = function(context)
      local mapId = type(context) == "table" and context.mapId or state.mapId
      if not mapId then return nil end
      local mapDef = Game.data.maps[mapId]
      local area = type(context) == "table" and context.area
        or Core.classify(mapId, mapDef, Game.data.encounters[mapId])
      local resolved = Tables.resolve(Game.data, mapId, area)
      return Tables.effectiveSnapshot(resolved, mapDef and mapDef.label,
        state.snapshotRevision)
    end
    runtime.invalidate = function(reason)
      state.lastReason = reason or "explicit invalidation"
      if Game.overworld then pcall(setupMap, Game.overworld) end
    end
    runtime.restore = function()
      if not state.installed then return end
      state.installed = false
      if Game.overworld then clearAll(Game.overworld) end
      if OverworldState.update == updateWrapper then OverworldState.update = originalUpdate end
      if OverworldState.setMap == setMapWrapper then OverworldState.setMap = originalSetMap end
      if OverworldState.pushBattle == pushBattleWrapper then
        OverworldState.pushBattle = originalPushBattle
      end
      if OverworldState.afterBattle == afterBattleWrapper then
        OverworldState.afterBattle = originalAfterBattle
      end
      if OverworldState.onStepComplete == onStepCompleteWrapper then
        OverworldState.onStepComplete = originalOnStepComplete
      end
      if OverworldState.talkTo == talkToWrapper then OverworldState.talkTo = originalTalkTo end
      if OverworldState.drawUI == drawUIWrapper then OverworldState.drawUI = originalDrawUI end
      if removeCollisionHook then pcall(removeCollisionHook) end
      if rawget(OverworldState, "_kantoLivingEncountersState") == runtime then
        rawset(OverworldState, "_kantoLivingEncountersState", nil)
      end
    end
    rawset(OverworldState, "_kantoLivingEncountersState", runtime)
    return runtime
  end

  return Runtime
end
