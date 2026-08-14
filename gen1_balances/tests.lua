-- Gen1 Balances: exact loader, data, ownership, and transaction tests.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local MOD_PATH = "mods/gen1_balances"

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
  return result
end

local function count(value)
  local total = 0
  for _ in pairs(value or {}) do total = total + 1 end
  return total
end

local function snapshot(value, seen)
  local kind = type(value)
  if kind == "function" or kind == "userdata" or kind == "thread" then
    return "<" .. kind .. ">"
  end
  if kind ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return "<cycle>" end
  seen[value] = true
  local result = {}
  for key, item in pairs(value) do result[snapshot(key, seen)] = snapshot(item, seen) end
  seen[value] = nil
  return result
end

local function firstDifference(left, right, path, seen)
  if left == right then return nil end
  if type(left) ~= "table" or type(right) ~= "table" then
    return path .. " (" .. tostring(left) .. " -> " .. tostring(right) .. ")"
  end
  seen = seen or {}
  if seen[left] == right then return nil end
  seen[left] = right
  for key, value in pairs(left) do
    local child = firstDifference(value, right[key], path .. "." .. tostring(key), seen)
    if child then return child end
  end
  for key in pairs(right) do
    if left[key] == nil then return path .. "." .. tostring(key) .. " (nil -> value)" end
  end
  return nil
end

local function loadClean(label)
  local baselineData = T.fixtures.fresh()
  local baseline = T.sdk.loadNone({ data = baselineData })
  baseline.release()
  local expectedPokemon = snapshot(baselineData.pokemon)
  local expectedEncounters = snapshot(baselineData.encounters)

  local data = T.fixtures.fresh()
  local run = T.sdk.loadMod(MOD_PATH, { data = data })

  T.eq(#run.errors, 0,
    label .. " loads with zero errors (" .. tostring(run.errors[1]) .. ")")
  T.check(run.mod ~= nil, label .. " is discovered")
  T.eq(run.mod and run.mod.state, "loaded", label .. " reaches loaded state")
  T.eq(run.mod and run.mod.manifest.id, "gen1_balances",
    label .. " has the canonical manifest ID")
  T.eq(run.mod and run.mod.manifest.version, "0.1.0-alpha.2",
    label .. " manifest and source version agree")
  T.eq(firstDifference(expectedPokemon, snapshot(data.pokemon), "pokemon"), nil,
    label .. " skips unavailable fixture species instead of fabricating them")
  T.eq(firstDifference(expectedEncounters, snapshot(data.encounters), "encounters"), nil,
    label .. " skips unavailable fixture maps instead of fabricating them")
  T.eq(data.field.fishing.OLD_ROD.pool[1].species, "GOLDEEN",
    label .. " installs the global Old Rod pool")
  T.eq(count(data.field.balancesSuperRod), 31,
    label .. " installs every Super Rod map")

  local hooks = T.record.hooks(run.loader)
  for _, name in ipairs(T.catalog.hooks()) do
    T.eq(hooks:depth(name), 0, label .. " installs no hook: " .. name)
  end

  local exports = run.mod and run.mod.api and run.mod.api.exports
    or run.loader.exports.gen1_balances
  T.check(exports ~= nil, label .. " publishes diagnostics")
  local status = exports and exports.status and exports.status()
  T.eq(status and status.phase, "balances_data", label .. " reports the focused data phase")
  T.eq(status and status.contentOperations, 2,
    label .. " reports only two fixture-available fishing operations")
  T.eq(status and status.hookOperations, 0, label .. " reports zero hook ops")
  T.eq(status and status.datasets.species, 27, label .. " reports 27 stat patches")
  T.eq(status and status.datasets.learnsets, 143, label .. " reports 143 learnsets")
  T.eq(status and status.datasets.evolutions, 4, label .. " reports four dual evolutions")

  return run, exports
end

local first, exports = loadClean("initial load")

local encounterData = dofile(MOD_PATH .. "/data_encounters.lua")
local fishingData = dofile(MOD_PATH .. "/data_fishing.lua")
local speciesData = dofile(MOD_PATH .. "/data_species.lua")
local learnsetData = dofile(MOD_PATH .. "/data_learnsets.lua")
local evolutionData = dofile(MOD_PATH .. "/data_evolutions.lua")
T.eq(count(encounterData), 57, "canonical surface ledger contains 57 maps")
T.eq(count(fishingData.SUPER_ROD), 31, "canonical Super Rod ledger contains 31 maps")
T.eq(count(speciesData), 27, "canonical stat ledger contains 27 species")
T.eq(count(learnsetData), 143, "canonical learnset ledger contains 143 changed species")
T.eq(count(evolutionData), 4, "canonical evolution ledger contains four trade species")
local statFields = 0
for _, patch in pairs(speciesData) do statFields = statFields + count(patch.baseStats) end
T.eq(statFields, 57, "canonical stat ledger contains 57 changed fields")
T.eq(speciesData.PIKACHU.baseStats.hp, 60, "Pikachu HP patch matches the source")
T.eq(speciesData.HITMONCHAN.baseStats.special, 105,
  "Hitmonchan Special patch matches the source")
T.eq(learnsetData.GASTLY.learnset[5].level, 23,
  "Gastly learns Poison Gas at the corrected level")
T.eq(learnsetData.NIDOKING.level1Moves[3], "DIG", "Nidoking starts with Dig")
T.eq(evolutionData.KADABRA.evolutions[1].method, "TRADE",
  "Kadabra keeps its trade evolution")
T.eq(evolutionData.KADABRA.evolutions[2].level, 42,
  "Kadabra also evolves at level 42")
T.eq(evolutionData.MACHOKE.evolutions[2].level, 38,
  "Machoke also evolves at level 38")
T.eq(evolutionData.GRAVELER.evolutions[1].method, "TRADE",
  "Graveler keeps its trade evolution")
T.eq(evolutionData.HAUNTER.evolutions[2].level, 42,
  "Haunter also evolves at level 42")
T.eq(evolutionData.POLIWAG, nil, "Poliwag evolution is outside Balances scope")
T.check(encounterData.ROUTE_19.grass == nil, "Route 19 has no fabricated grass table")
T.check(encounterData.ROUTE_19.water ~= nil, "Route 19 slots are stored as surf encounters")
T.check(encounterData.ROUTE_20.grass == nil, "Route 20 has no fabricated grass table")
T.check(encounterData.ROUTE_20.water ~= nil, "Route 20 slots are stored as surf encounters")
T.check(encounterData.ROUTE_24.water == nil, "Route 24 has no fabricated water table")
T.check(encounterData.ROUTE_25.water == nil, "Route 25 has no fabricated water table")
T.eq(fishingData.ROUTE_24, nil, "rod maps remain nested under SUPER_ROD")
T.eq(fishingData.SUPER_ROD.ROUTE_24[1].species, "GOLDEEN",
  "Route 24 retains its omitted first Super Rod species")
T.eq(fishingData.SUPER_ROD.ROUTE_24[1].level, 35,
  "Route 24 retains its omitted first Super Rod level")
T.eq(fishingData.SUPER_ROD.ROUTE_25[1].species, "KRABBY",
  "Route 25 retains its omitted first Super Rod species")
T.eq(fishingData.SUPER_ROD.ROUTE_25[1].level, 25,
  "Route 25 retains its omitted first Super Rod level")
T.eq(fishingData.OLD_ROD[1].species, "GOLDEEN", "Old Rod uses the global v1.0.10 pool")
T.eq(fishingData.OLD_ROD[2].species, "POLIWAG", "Old Rod keeps both global candidates")
T.eq(fishingData.GOOD_ROD[1].level, 20, "Good Rod uses level-20 candidates")
T.eq(fishingData.GOOD_ROD[2].species, "KRABBY", "Good Rod keeps the global Krabby slot")

local keepRate = exports.encounterPatch({ grass = { rate = 31 } },
  encounterData.ROUTE_1)
T.eq(keepRate.grass.rate, 31, "encounter patch preserves a live edition rate")
local fallbackRate = exports.encounterPatch({ grass = { rate = 25 } },
  encounterData.ROUTE_6)
T.eq(fallbackRate.water.rate, 3,
  "missing Route 6 surf uses only its audited source fallback")

local N = exports.normalize
T.eq(N.species("Nidoran♀"), "NIDORAN_F", "female Nidoran resolves distinctly")
T.eq(N.species("Nidoran♂"), "NIDORAN_M", "male Nidoran resolves distinctly")
T.neq(N.species("Nidoran♀"), N.species("Nidoran♂"), "Nidoran forms never merge")
T.eq(N.species("Farfetch'd"), "FARFETCHD", "Farfetch'd punctuation normalizes")
T.eq(N.species("Mr. Mime"), "MR_MIME", "Mr. Mime punctuation normalizes")
T.eq(N.move("Psychic"), "PSYCHIC_M", "Psychic resolves to the engine move ID")
T.eq(N.move("Double-Edge"), "DOUBLE_EDGE", "move punctuation normalizes")
T.eq(N.trainer("rival1"), "OPP_RIVAL1", "trainer prefix is canonical")
T.eq(N.map("Cerulean Cave B1F"), "CERULEAN_CAVE_B1F", "map ID normalizes")

local V = exports.validators
local allowed = { NIDORAN_F = true, NIDORAN_M = true, PIKACHU = true }
local function resolveSpecies(id) return allowed[id] and id or nil end

local validParty = {
  { level = 5, species = "Nidoran♀" },
  { level = 6, species = "Pikachu" },
}
local stagedParty, validErrors = V.validateParty(validParty, resolveSpecies)
T.eq(#validErrors, 0, "valid party has no errors")
T.eq(stagedParty[1].species, "NIDORAN_F", "valid party is normalized")
T.eq(validParty[1].species, "Nidoran♀", "party staging never mutates its source")

local invalidParty = {
  { level = 0, species = "Nidoran♂" },
  { level = 8, species = "MissingNo" },
}
local invalidBefore = copy(invalidParty)
local rejected, invalidErrors = V.validateParty(invalidParty, resolveSpecies)
T.eq(rejected, nil, "invalid party is rejected as a whole")
T.check(#invalidErrors >= 2, "invalid party reports every discovered error")
T.same(invalidParty, invalidBefore, "rejected party leaves its source untouched")

local validSurface, surfaceErrors = V.validateEncounter(encounterData.ROUTE_19,
  function(id) return id end)
T.eq(#surfaceErrors, 0, "valid surf encounter record has no errors")
T.eq(#validSurface.water.slots, 10, "valid surf encounter keeps all ten slots")
local badSurface = copy(encounterData.ROUTE_19)
badSurface.water.slots[4].level = 0
local badBefore = copy(badSurface)
local rejectedSurface, encounterErrors = V.validateEncounter(badSurface,
  function(id) return id end)
T.eq(rejectedSurface, nil, "one invalid encounter slot rejects the whole map")
T.check(#encounterErrors >= 1, "invalid encounter reports its slot error")
T.same(badSurface, badBefore, "rejected encounter leaves its source untouched")

local stagedFishing, fishingErrors = V.validateFishing(fishingData,
  function(id) return id end)
T.eq(#fishingErrors, 0, "canonical fishing dataset has no errors")
T.eq(count(stagedFishing.SUPER_ROD), 31, "fishing validation preserves all maps")
local badFishing = copy(fishingData)
badFishing.SUPER_ROD.ROUTE_24[4] = nil
local rejectedFishing, badFishingErrors = V.validateFishing(badFishing,
  function(id) return id end)
T.eq(rejectedFishing, nil, "short Super Rod pool rejects the whole fishing dataset")
T.check(#badFishingErrors >= 1, "invalid fishing dataset reports its map error")

local duplicate, duplicateErrors = V.stageMap({
  ["Nidoran F"] = { hp = 1 },
  ["Nidoran-F"] = { hp = 2 },
}, N.species)
T.eq(duplicate, nil, "canonical duplicate records reject the whole table")
T.eq(#duplicateErrors, 1, "canonical duplicate has one deterministic error")

first.release()
local second = loadClean("reload")
second.release()

T.finish("gen1_balances")
