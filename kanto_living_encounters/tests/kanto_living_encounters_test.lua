local source = debug.getinfo(1, "S").source:gsub("^@", "")
local MOD = source:match("^(.*)[/\\]tests[/\\][^/\\]+$") or "."

local function load(path)
  local chunk, err = loadfile(MOD .. "/" .. path)
  assert(chunk, err)
  return chunk()
end

local Core = load("kle_core.lua")
local Tables = load("kle_tables.lua")(Core)
local passed = 0

for _, path in ipairs({ "main.lua", "kle_core.lua", "kle_tables.lua", "kle_runtime.lua" }) do
  local chunk, err = loadfile(MOD .. "/" .. path)
  assert(chunk, path .. " syntax: " .. tostring(err))
end

local function eq(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  passed = passed + 1
end

local function check(value, label)
  assert(value, label)
  passed = passed + 1
end

eq(Core.classify("PALLET_TOWN", { outdoor = true }, nil), "town", "town classification")
eq(Core.classify("ROUTE_1", { tileset = "OVERWORLD" }, { grass = {} }),
  "route", "route classification")
eq(Core.classify("MT_MOON_1F", { outdoor = false, tileset = "CAVERN" }, { grass = {} }),
  "cave", "cave classification")
eq(Core.classify("POWER_PLANT", { outdoor = false }, { grass = {} }),
  "cave", "requested dungeon classification")
eq(Core.classify("HOUSE", { outdoor = false }, nil), "unsupported", "unsupported classification")

for key, expectedMin in pairs({ few = 2, regular = 5, many = 9 }) do
  eq(Core.targetForAmount(key, function(a) return a end, 99), expectedMin,
    key .. " minimum")
end
eq(Core.targetForAmount("many", function(_, b) return b end, 10), 10,
  "eligible cells clamp amount")

eq(Core.chooseBehavior("route", true, function() return 0.10 end), "idle",
  "wild idle weight")
eq(Core.chooseBehavior("route", true, function() return 0.50 end), "roam",
  "wild roam weight")
eq(Core.chooseBehavior("route", true, function() return 0.899 end), "roam",
  "wild non-aggressive share is ninety percent")
eq(Core.chooseBehavior("route", true, function() return 0.90 end), "aggressive",
  "wild aggressive share is final ten percent")
eq(Core.chooseBehavior("route", false, function() return 0.99 end), "roam",
  "aggressive disabled renormalizes safely")
eq(Core.chooseBehavior("town", true, function() return 0.949 end), "roam",
  "town non-aggressive share is ninety-five percent")
eq(Core.chooseBehavior("town", true, function() return 0.95 end), "aggressive",
  "town aggressive share is final five percent")
eq(Core.BEHAVIOR_WEIGHTS.wild.idle, 39.375, "wild idle redistribution")
eq(Core.BEHAVIOR_WEIGHTS.wild.roam, 50.625, "wild roam redistribution")
eq(Core.BEHAVIOR_WEIGHTS.town.idle, 41.5625, "town idle redistribution")
eq(Core.BEHAVIOR_WEIGHTS.town.roam, 53.4375, "town roam redistribution")
eq(Core.isBattleable("town", "idle"), false, "town idle is cosmetic")
eq(Core.isBattleable("town", "roam"), false, "town roam is cosmetic")
eq(Core.isBattleable("town", "aggressive"), true, "town aggressive battles")
eq(Core.isBattleable("route", "idle"), true, "route idle battles")
eq(Core.AGGRESSION_SPAWN_COOLDOWN, 30, "aggressive spawn grace duration")
eq(Core.aggressionCoolingDown(29.99, 30), true, "aggression waits during grace")
eq(Core.aggressionCoolingDown(30, 30), false, "aggression resumes at grace end")

local normal = { state = "AVAILABLE", spawnedAt = 0, cellX = 1, cellY = 1 }
local shiny = { state = "AVAILABLE", spawnedAt = 0, cellX = 1, cellY = 1, shiny = true }
eq(Core.shouldExpire(normal, 89, 1, 1), false, "ordinary spawn before ttl")
eq(Core.shouldExpire(normal, 90, 1, 1), true, "ordinary spawn at ttl")
eq(Core.shouldExpire(normal, 1, 24, 1), true, "ordinary spawn by distance")
eq(Core.shouldExpire(shiny, 999, 99, 99), false, "shiny ignores ttl and distance")
eq(Core.transition(normal, "AVAILABLE", "ENCOUNTER_STARTING"), true,
  "first battle transition wins")
eq(Core.transition(normal, "AVAILABLE", "ENCOUNTER_STARTING"), false,
  "duplicate battle transition loses")

check(Core.validateSpriteProvider({ overworldSpriteApiVersion = 1,
  createOverworldSprite = function() end }), "sprite provider contract")
check(not Core.validateSpriteProvider({ createOverworldSprite = function() end }),
  "sprite provider rejects missing version")
check(Core.validateShinyProvider({ wildOutcomeApiVersion = 1,
  reserveWildOutcome = function() end, wildBattleOptions = function() end }),
  "shiny provider contract")

local data = {
  encounters = {
    ROUTE_1 = { grass = { slots = {
      { species = "RATTATA", level = 2 }, { species = "PIDGEY", level = 3 },
      { species = "RATTATA", level = 3 }, { species = "PIDGEY", level = 4 },
      { species = "RATTATA", level = 4 }, { species = "PIDGEY", level = 5 },
      { species = "RATTATA", level = 5 }, { species = "PIDGEY", level = 6 },
      { species = "RATTATA", level = 6 }, { species = "PIDGEY", level = 7 },
    } } },
    ROUTE_21 = { water = { slots = {
      { species = "TENTACOOL", level = 5 }, { species = "TENTACOOL", level = 6 },
      { species = "TENTACOOL", level = 7 }, { species = "TENTACOOL", level = 8 },
      { species = "TENTACOOL", level = 9 }, { species = "TENTACOOL", level = 10 },
      { species = "TENTACOOL", level = 11 }, { species = "TENTACOOL", level = 12 },
      { species = "TENTACOOL", level = 13 }, { species = "TENTACOOL", level = 14 },
    } } },
  },
  field = { constants = { encounterBuckets =
    { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 } } },
}

local route = Tables.resolve(data, "ROUTE_1", "route")
eq(#route.land, 10, "live route table keeps all slots")
eq(route.land[1].weight, 51, "native first slot weight")
eq(route.land[3].weight, 39, "native third slot weight")
eq(route.sourceProvider, "live-engine-registry", "live registry authority")

local town = Tables.resolve(data, "PALLET_TOWN", "town")
eq(#town.land, 10, "town draws surrounding land slots")
eq(#town.water, 10, "town draws surrounding water slots")
eq(town.sources[1], "ROUTE_1", "town source is explicit")
eq(town.sources[2], "ROUTE_21", "town second source is explicit")

local species, level = Tables.pick(route.land, function(a)
  if a ~= nil then return a end
  return 0
end)
eq(species, "RATTATA", "weighted pick first slot")
eq(level, 2, "weighted pick preserves live level")

local excludedSpecies = { RATTATA = true }
local diverse = Tables.pick(route.land, function(a)
  if a ~= nil then return a end
  return 0
end, excludedSpecies)
eq(diverse, "PIDGEY", "town diversity excludes an already active species")

local effective = Tables.effectiveSnapshot(route, "ROUTE 1", 9)
eq(effective.schemaVersion, 1, "effective snapshot schema")
eq(effective.snapshotRevision, 9, "effective snapshot revision")
eq(effective.sections[1].id, "land", "effective snapshot land section")
eq(#effective.sections[1].entries, 2, "duplicate species aggregate for display")
eq(effective.sections[1].entries[1].behaviorWeights.aggressive, 10,
  "effective wild snapshot advertises ten-percent aggression")
local townEffective = Tables.effectiveSnapshot(town, "PALLET TOWN", 10)
eq(townEffective.sections[1].entries[1].behaviorWeights.aggressive, 5,
  "effective town snapshot advertises five-percent aggression")
eq(townEffective.sections[1].entries[1].interactRule, "face_and_cry",
  "effective town snapshot advertises cry interaction")
local chanceTotal = 0
for _, entry in ipairs(effective.sections[1].entries) do
  chanceTotal = chanceTotal + entry.chance
end
check(math.abs(chanceTotal - 1) < 0.000001, "effective chances normalize to one")

print(string.format("Kanto Living Encounters core: %d checks passed", passed))
