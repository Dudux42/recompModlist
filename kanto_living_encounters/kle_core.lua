local Core = {}

Core.VERSION = "0.1.0-alpha.4"
Core.SCHEMA_VERSION = 1
Core.TTL_SECONDS = 90
Core.DESPAWN_DISTANCE = 22
Core.MIN_PLAYER_DISTANCE = 3
Core.MIN_WILD_DISTANCE = 3
Core.REFILL_STEPS = 8
Core.DETECTION_RADIUS = 4
Core.AGGRESSION_SPAWN_COOLDOWN = 30

Core.AMOUNT_RANGES = {
  few = { min = 2, max = 4 },
  regular = { min = 5, max = 8 },
  many = { min = 9, max = 12 },
}

Core.BEHAVIOR_WEIGHTS = {
  -- Non-aggressive probability retains the original 35:45 Idle:Roam ratio.
  wild = { idle = 39.375, roam = 50.625, aggressive = 10 },
  town = { idle = 41.5625, roam = 53.4375, aggressive = 5 },
}

Core.TOWN_ADJACENCY = {
  PALLET_TOWN = { "ROUTE_1", "ROUTE_21" },
  VIRIDIAN_CITY = { "ROUTE_1", "ROUTE_2", "ROUTE_22" },
  PEWTER_CITY = { "ROUTE_2", "ROUTE_3" },
  CERULEAN_CITY = { "ROUTE_4", "ROUTE_5", "ROUTE_9", "ROUTE_24" },
  VERMILION_CITY = { "ROUTE_6", "ROUTE_11" },
  LAVENDER_TOWN = { "ROUTE_8", "ROUTE_10", "ROUTE_12" },
  CELADON_CITY = { "ROUTE_7", "ROUTE_16" },
  FUCHSIA_CITY = { "ROUTE_15", "ROUTE_18" },
  SAFFRON_CITY = { "ROUTE_5", "ROUTE_6", "ROUTE_7", "ROUTE_8" },
  CINNABAR_ISLAND = { "ROUTE_20", "ROUTE_21" },
  INDIGO_PLATEAU = { "ROUTE_23" },
}

Core.SPECIAL_POOL_ADJACENCY = {
  ROCKET_HIDEOUT = { "ROUTE_7", "ROUTE_16" },
  SILPH_CO = { "ROUTE_5", "ROUTE_6", "ROUTE_7", "ROUTE_8" },
}

local function startsWith(value, prefix)
  return tostring(value or ""):sub(1, #prefix) == prefix
end

function Core.isTown(mapId)
  return Core.TOWN_ADJACENCY[tostring(mapId or "")] ~= nil
end

function Core.specialPoolRoutes(mapId)
  mapId = tostring(mapId or "")
  for prefix, routes in pairs(Core.SPECIAL_POOL_ADJACENCY) do
    if startsWith(mapId, prefix) then return routes end
  end
  return nil
end

function Core.isRequestedDungeon(mapId)
  mapId = tostring(mapId or "")
  return startsWith(mapId, "POKEMON_TOWER")
    or startsWith(mapId, "ROCKET_HIDEOUT")
    or startsWith(mapId, "SILPH_CO")
    or mapId == "POWER_PLANT"
    or startsWith(mapId, "POKEMON_MANSION")
end

function Core.classify(mapId, mapDef, encounterDef)
  if Core.isTown(mapId) then return "town" end
  if Core.isRequestedDungeon(mapId) then return "cave" end
  if encounterDef and encounterDef.grass then
    if mapDef and mapDef.outdoor == false then return "cave" end
    local tileset = tostring(mapDef and mapDef.tileset or "")
    if tileset ~= "OVERWORLD" and tileset ~= "FOREST" then return "cave" end
    return "route"
  end
  if encounterDef and encounterDef.water then return "water" end
  return "unsupported"
end

function Core.distance(ax, ay, bx, by)
  return math.abs((ax or 0) - (bx or 0)) + math.abs((ay or 0) - (by or 0))
end

function Core.cellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

function Core.targetForAmount(key, rng, eligibleCount)
  local range = Core.AMOUNT_RANGES[key] or Core.AMOUNT_RANGES.regular
  local target
  if type(rng) == "function" then
    target = rng(range.min, range.max)
  else
    target = range.min
  end
  return math.max(0, math.min(target, tonumber(eligibleCount) or target))
end

function Core.weightedChoice(weights, rng)
  local total = 0
  for _, key in ipairs({ "idle", "roam", "aggressive" }) do
    total = total + math.max(0, tonumber(weights and weights[key]) or 0)
  end
  if total <= 0 then return "idle" end
  local roll = (type(rng) == "function" and rng() or math.random()) * total
  local cumulative = 0
  for _, key in ipairs({ "idle", "roam", "aggressive" }) do
    cumulative = cumulative + math.max(0, tonumber(weights[key]) or 0)
    if roll < cumulative then return key end
  end
  return "roam"
end

function Core.chooseBehavior(area, aggressiveEnabled, rng)
  local source = Core.BEHAVIOR_WEIGHTS[area == "town" and "town" or "wild"]
  local weights = {
    idle = source.idle,
    roam = source.roam,
    aggressive = aggressiveEnabled == false and 0 or source.aggressive,
  }
  return Core.weightedChoice(weights, rng)
end

function Core.isBattleable(area, behavior)
  return area ~= "town" or behavior == "aggressive"
end

function Core.aggressionCoolingDown(now, cooldownUntil)
  return (tonumber(now) or 0) < (tonumber(cooldownUntil) or 0)
end

function Core.shouldExpire(entity, now, playerX, playerY)
  if not entity or entity.shiny then return false end
  if entity.spawnedAt and now - entity.spawnedAt >= Core.TTL_SECONDS then
    return true, "ttl"
  end
  if Core.distance(entity.cellX, entity.cellY, playerX, playerY)
      > Core.DESPAWN_DISTANCE then
    return true, "distance"
  end
  return false
end

function Core.transition(entity, expected, nextState)
  if not entity or entity.state ~= expected then return false end
  entity.state = nextState
  return true
end

function Core.validateSpriteProvider(exports)
  return type(exports) == "table"
    and tonumber(exports.overworldSpriteApiVersion) == 1
    and type(exports.createOverworldSprite) == "function"
end

function Core.validateShinyProvider(exports)
  return type(exports) == "table"
    and tonumber(exports.wildOutcomeApiVersion) == 1
    and type(exports.reserveWildOutcome) == "function"
    and type(exports.wildBattleOptions) == "function"
end

return Core
