-- Gen1 Balances 0.1.0-alpha.2
-- Owns live encounter/fishing data and selected species progression data.
return function(mod)
  local bootstrapBody = mod:read("compat.lua")
  assert(type(bootstrapBody) == "string", "compat.lua is missing")
  local bootstrapChunk, bootstrapError = loadstring(bootstrapBody, "@compat.lua")
  assert(bootstrapChunk, bootstrapError)
  local Compat = bootstrapChunk()

  local Normalize = Compat.load(mod, "normalize.lua")
  local validatorFactory = Compat.load(mod, "validators.lua")
  local Validators = validatorFactory(Normalize)

  local raw = {
    species = Compat.load(mod, "data_species.lua"),
    learnsets = Compat.load(mod, "data_learnsets.lua"),
    evolutions = Compat.load(mod, "data_evolutions.lua"),
    encounters = Compat.load(mod, "data_encounters.lua"),
    fishing = Compat.load(mod, "data_fishing.lua"),
  }
  local staged = Validators.assertBundle(raw)

  local status = {
    phase = "balances_data",
    initialized = true,
    contentOperations = 0,
    hookOperations = 0,
    datasets = {},
    skipped = { pokemonOperations = 0, maps = 0 },
  }
  for name, records in pairs(staged) do
    status.datasets[name] = Compat.count(records)
  end

  local function patchPokemon(records)
    for id, patch in pairs(records) do
      if mod.content.pokemon:get(id) then
        mod.content.pokemon:patch(id, patch)
        status.contentOperations = status.contentOperations + 1
      else
        status.skipped.pokemonOperations = status.skipped.pokemonOperations + 1
      end
    end
  end

  local function encounterPatch(base, record)
    local patch = {}
    for _, kind in ipairs({ "grass", "water" }) do
      local surface = record[kind]
      if surface then
        local live = base and base[kind]
        patch[kind] = {
          rate = live and live.rate or surface.fallbackRate,
          slots = Compat.deepCopy(surface.slots),
        }
      end
    end
    return patch
  end

  patchPokemon(staged.species)
  patchPokemon(staged.learnsets)
  patchPokemon(staged.evolutions)

  for mapId, record in pairs(staged.encounters) do
    local base = mod.content.encounters:get(mapId)
    if base then
      mod.content.encounters:patch(mapId, encounterPatch(base, record))
      status.contentOperations = status.contentOperations + 1
    else
      status.skipped.maps = status.skipped.maps + 1
    end
  end

  -- Yellow Legacy's Old and Good Rod pools are global and retain the engine's
  -- ordinary rejection-loop bite odds. Super Rod remains map-specific.
  mod.content.field:patch("fishing", {
    OLD_ROD = { pool = Compat.deepCopy(staged.fishing.OLD_ROD) },
    GOOD_ROD = { pool = Compat.deepCopy(staged.fishing.GOOD_ROD) },
    SUPER_ROD = { perMap = "balancesSuperRod" },
  })
  mod.content.field:patch("balancesSuperRod",
    Compat.deepCopy(staged.fishing.SUPER_ROD))
  status.contentOperations = status.contentOperations + 2

  mod.exports.version = mod.version
  mod.exports.phase = status.phase
  mod.exports.status = function() return Compat.deepCopy(status) end
  mod.exports.normalize = Normalize
  mod.exports.validators = Validators
  mod.exports.encounterPatch = encounterPatch

  if status.skipped.pokemonOperations > 0 or status.skipped.maps > 0 then
    mod.log:warn("Balances skipped %d unavailable Pokemon operations and %d unavailable maps",
      status.skipped.pokemonOperations, status.skipped.maps)
  end
  mod.log:info("Balances installed %d live content operations",
    status.contentOperations)
end
