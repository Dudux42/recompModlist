-- Widescreen Pokedex
-- Version 0.1.0-alpha.7
-- Semantic provider for Pokedex Provider API v2.
-- This mod owns read-only models and navigation. It performs no drawing.

local OWNER = "gen1_widescreen_pokedex"
local SCREEN_ID = "WidescreenPokedex"
local API_VERSION = 2

local SUBMENU = {
  { id = "habitat", label = "HABITAT" },
  { id = "stats", label = "STATS" },
  { id = "learnset", label = "LEARNSET" },
  { id = "evolution", label = "EVOLUTION" },
  { id = "cry", label = "CRY", action = true },
}

local DEFAULT_BUCKETS = { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 }

local function finite(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return value
end

local function integer(value)
  local number = finite(value)
  if not number or number % 1 ~= 0 then return nil end
  return number
end

local function upper(value)
  return type(value) == "string" and value:upper() or ""
end

local function humanize(value)
  local text = tostring(value or "UNKNOWN"):gsub("_", " ")
  return text:upper()
end

local function semanticCopy(value, depth)
  if type(value) ~= "table" then
    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
      return value
    end
    return nil
  end
  depth = depth or 0
  if depth >= 4 then return {} end
  local out = {}
  for key, child in pairs(value) do
    if type(key) == "string" or type(key) == "number" then
      local copy = semanticCopy(child, depth + 1)
      if copy ~= nil then out[key] = copy end
    end
  end
  return out
end

local function normalizeEntryText(value)
  if type(value) ~= "string" or value == "" then return "DATA UNAVAILABLE" end
  -- ROM entries contain line and page controls sized for the Game Boy text
  -- window. They are word boundaries, not semantic paragraphs. Keeping them
  -- as hard newlines produces narrow columns inside the much wider presenter.
  -- Collapse all legacy/manual whitespace and let Widescreen wrap by the
  -- active rendered font width. Truly oversized modded entries can still use
  -- Widescreen's bounded viewport.
  local normalized = value:gsub("\r\n", " "):gsub("[\r\n\v\f]+", " ")
    :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return normalized ~= "" and normalized or "DATA UNAVAILABLE"
end

local function displayNumber(def, digits)
  local internal = integer(def and def.dex)
  if not internal or internal < 1 then return nil end
  local shown = integer(def.dexDisplay) or internal
  if shown < 1 then return nil end
  local variant = upper(def.dexVariant):gsub("[^A-Z0-9]", "")
  if variant ~= "" then return tostring(shown) .. variant end
  return ("%0" .. tostring(digits or 3) .. "d"):format(shown)
end

local function possessedSpecies(save)
  local owned = {}
  local function visit(mon)
    if type(mon) == "table" and type(mon.species) == "string" then
      owned[mon.species] = true
    end
  end
  save = type(save) == "table" and save or {}
  for _, mon in ipairs(type(save.party) == "table" and save.party or {}) do visit(mon) end
  for _, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
    for _, mon in ipairs(type(box) == "table" and box or {}) do visit(mon) end
  end
  for _, mon in ipairs(type(save.box) == "table" and save.box or {}) do visit(mon) end
  return owned
end

local function visitSavedPokemon(save, callback)
  save = type(save) == "table" and save or {}
  for _, mon in ipairs(type(save.party) == "table" and save.party or {}) do
    if callback(mon) then return true end
  end
  for _, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
    for _, mon in ipairs(type(box) == "table" and box or {}) do
      if callback(mon) then return true end
    end
  end
  for _, mon in ipairs(type(save.box) == "table" and save.box or {}) do
    if callback(mon) then return true end
  end
  return false
end

local function hasCaughtShiny(mod, game, speciesId, diagnose)
  if type(speciesId) ~= "string" or speciesId == "" then return false end
  local provider = type(mod.find) == "function" and mod:find("gen1_shiny_system") or nil
  local query = provider and provider.exports and provider.exports.hasShinyState
  if type(query) ~= "function" then return false end
  local failed
  local found = visitSavedPokemon(game and game.save, function(mon)
    if type(mon) ~= "table" or mon.species ~= speciesId then return false end
    local ok, shiny = pcall(query, mon)
    if not ok then failed = shiny return true end
    return shiny == true
  end)
  if failed then
    if diagnose then diagnose("Shiny System possession query failed: " .. tostring(failed)) end
    return false
  end
  return found
end

local function speciesRows(game)
  local data = type(game) == "table" and game.data or {}
  local pokemon = type(data.pokemon) == "table" and data.pokemon or {}
  local dexUse = {}
  for id, def in pairs(pokemon) do
    local dex = type(def) == "table" and integer(def.dex) or nil
    if type(id) == "string" and id ~= "" and dex and dex >= 1 then
      dexUse[dex] = (dexUse[dex] or 0) + 1
    end
  end

  local save = type(game.save) == "table" and game.save or {}
  local dexState = type(save.pokedex) == "table" and save.pokedex or {}
  local seenFlags = type(dexState.seen) == "table" and dexState.seen or {}
  local ownedFlags = type(dexState.owned) == "table" and dexState.owned or {}
  local possessed = possessedSpecies(save)
  local digits = type(data.constants) == "table" and integer(data.constants.dexDigits) or 3
  if not digits or digits < 1 then digits = 3 end

  local rows = {}
  for id, def in pairs(pokemon) do
    local internal = type(def) == "table" and integer(def.dex) or nil
    if type(id) == "string" and id ~= "" and internal and internal >= 1
        and dexUse[internal] == 1 then
      local number = displayNumber(def, digits)
      if number then
        local displayDex = integer(def.dexDisplay) or internal
        local variant = upper(def.dexVariant):gsub("[^A-Z0-9]", "")
        local variantOrder = finite(def.dexVariantOrder)
        if not variantOrder then variantOrder = variant ~= "" and 1 or 0 end
        local owned = ownedFlags[id] == true or possessed[id] == true
        local seen = seenFlags[id] == true or owned
        rows[#rows + 1] = {
          speciesId = id,
          number = number,
          name = seen and tostring(def.name or id) or "?????",
          seen = seen and true or false,
          owned = owned and true or false,
          hidden = not seen,
          displayDex = displayDex,
          variant = variant,
          variantOrder = variantOrder,
          internalDex = internal,
        }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.displayDex ~= b.displayDex then return a.displayDex < b.displayDex end
    if a.variantOrder ~= b.variantOrder then return a.variantOrder < b.variantOrder end
    if a.variant ~= b.variant then return a.variant < b.variant end
    if a.internalDex ~= b.internalDex then return a.internalDex < b.internalDex end
    return a.speciesId < b.speciesId
  end)
  return rows
end

local function countsFor(rows)
  local seen, owned = 0, 0
  for _, row in ipairs(rows) do
    if row.seen then seen = seen + 1 end
    if row.owned then owned = owned + 1 end
  end
  return { seen = seen, owned = owned, total = #rows }
end

local function publicRow(row)
  return {
    speciesId = row.speciesId,
    number = row.number,
    name = row.name,
    seen = row.seen,
    owned = row.owned,
    hidden = row.hidden,
  }
end

local function rowForId(rows, speciesId)
  for index, row in ipairs(rows) do
    if row.speciesId == speciesId then return row, index end
  end
end

local function selectedRow(state, rows)
  local row, index = rowForId(rows, state.selectedSpeciesId)
  if row then
    state.selectedIndex = index
    return row
  end
  local indexValue = math.max(1, math.min(#rows, integer(state.selectedIndex) or 1))
  row = rows[indexValue]
  state.selectedIndex = indexValue
  state.selectedSpeciesId = row and row.speciesId or nil
  return row
end

local function selectedDefinition(game, row)
  local pokemon = game and game.data and game.data.pokemon
  return row and type(pokemon) == "table" and pokemon[row.speciesId] or nil
end

local function detailFor(mod, game, row, state)
  if not row or not row.seen then
    return {
      number = row and row.number or "---",
      name = "?????",
      seen = false,
      owned = false,
      hidden = true,
      entry = "NO DATA RECORDED",
      portrait = { kind = "unknown" },
    }
  end
  local def = selectedDefinition(game, row) or {}
  local detail = {
    speciesId = row.speciesId,
    number = row.number,
    name = tostring(def.name or row.name),
    seen = true,
    owned = row.owned,
    hidden = false,
    portrait = {
      kind = "pokemon", speciesId = row.speciesId, side = "front",
      purpose = "pokedex", shiny = false,
    },
  }
  local shinyAvailable = row.owned
    and hasCaughtShiny(mod, game, row.speciesId, state and state._diagnose) or false
  if state and state.shinySpeciesId ~= row.speciesId then
    state.shinySpeciesId, state.shinyEnabled = row.speciesId, false
  end
  detail.portrait.shinyAvailable = shinyAvailable and true or false
  detail.portrait.shiny = shinyAvailable and state and state.shinyEnabled == true or false
  local entry = type(def.dexEntry) == "table" and def.dexEntry or {}
  if not row.owned then
    detail.entry = "DATA UNKNOWN — CATCH THIS POKEMON"
    return detail
  end
  detail.kind = type(entry.kind) == "string" and entry.kind or "DATA UNAVAILABLE"
  local textId = entry.text
  local text = type(textId) == "string" and game.data and game.data.text
    and game.data.text[textId] or nil
  detail.entry = normalizeEntryText(text)
  if finite(entry.heightM) then
    detail.height = { metres = finite(entry.heightM) }
  elseif integer(entry.heightFt) then
    detail.height = { feet = integer(entry.heightFt), inches = integer(entry.heightIn) or 0 }
  end
  if finite(entry.weightKg) then
    detail.weight = { kilograms = finite(entry.weightKg) }
  elseif finite(entry.weight) then
    detail.weight = { pounds = finite(entry.weight) / 10 }
  end
  return detail
end

local function typeName(data, typeId)
  local types = data and data.type_chart and data.type_chart.types
  local def = type(types) == "table" and types[typeId] or nil
  return type(def) == "table" and tostring(def.name or humanize(typeId))
    or humanize(typeId)
end

local function statsModel(game, row)
  local def = selectedDefinition(game, row) or {}
  local stats = type(def.baseStats) == "table" and def.baseStats or {}
  local keys = {
    { "hp", "HP" }, { "attack", "ATTACK" }, { "defense", "DEFENSE" },
    { "speed", "SPEED" }, { "special", "SPECIAL" },
  }
  local rows, total, complete = {}, 0, true
  for _, pair in ipairs(keys) do
    local value = integer(stats[pair[1]])
    if not value or value < 1 then complete = false else total = total + value end
    rows[#rows + 1] = {
      kind = "stat", id = pair[1], label = pair[2], value = value,
      display = value and tostring(value) or "—",
    }
  end
  rows[#rows + 1] = {
    kind = "total", id = "total", label = "TOTAL",
    value = complete and total or nil,
    display = complete and tostring(total) or "—",
  }
  local types = {}
  for _, typeId in ipairs(type(def.types) == "table" and def.types or {}) do
    if type(typeId) == "string" then
      types[#types + 1] = { id = typeId, name = typeName(game.data, typeId) }
    end
  end
  return rows, types, not complete
end

local function moveRow(data, moveId, extra)
  local def = data and data.moves and data.moves[moveId]
  local valid = type(def) == "table"
  local row = {
    kind = "move",
    moveId = tostring(moveId or "UNKNOWN"),
    moveName = valid and tostring(def.name or moveId) or "INVALID MOVE",
    typeId = valid and def.type or nil,
    typeName = valid and typeName(data, def.type) or "UNKNOWN",
    valid = valid,
  }
  if valid then
    row.power = integer(def.power)
    row.accuracy = finite(def.accuracy)
    row.pp = integer(def.pp)
  end
  for key, value in pairs(extra or {}) do row[key] = value end
  return row
end

local function learnsetModel(game, row)
  local data = game and game.data or {}
  local def = selectedDefinition(game, row) or {}
  local result = { { kind = "section", id = "level_up", label = "LEVEL-UP MOVES" } }
  for _, moveId in ipairs(type(def.level1Moves) == "table" and def.level1Moves or {}) do
    result[#result + 1] = moveRow(data, moveId,
      { source = "level_up", level = 1, levelLabel = "START" })
  end
  local ordered = {}
  for sourceIndex, entry in ipairs(type(def.learnset) == "table" and def.learnset or {}) do
    if type(entry) == "table" then
      ordered[#ordered + 1] = { entry = entry, sourceIndex = sourceIndex }
    end
  end
  table.sort(ordered, function(a, b)
    local al = integer(a.entry.level) or math.huge
    local bl = integer(b.entry.level) or math.huge
    if al ~= bl then return al < bl end
    return a.sourceIndex < b.sourceIndex
  end)
  for _, source in ipairs(ordered) do
    local level = integer(source.entry.level)
    result[#result + 1] = moveRow(data, source.entry.move, {
      source = "level_up",
      level = level,
      levelLabel = level and (level <= 1 and "START" or tostring(level)) or "—",
    })
  end
  if #result == 1 then
    result[#result + 1] = { kind = "message", label = "NO LEVEL-UP MOVES" }
  end

  local compatible = {}
  for _, moveId in ipairs(type(def.tmhm) == "table" and def.tmhm or {}) do
    compatible[moveId] = true
  end
  local function appendMachines(kind)
    local lowerKind = kind:lower()
    result[#result + 1] = {
      kind = "section", id = lowerKind, label = "LEARNABLE " .. kind .. "s",
    }
    local machines = {}
    for itemId, item in pairs(type(data.items) == "table" and data.items or {}) do
      local machine = type(item) == "table" and item.machine or nil
      local number = type(machine) == "table" and integer(machine.number) or nil
      if type(machine) == "table" and upper(machine.kind) == kind
          and number and number >= 0 and compatible[machine.move] then
        machines[#machines + 1] = {
          itemId = itemId, number = number, moveId = machine.move,
        }
      end
    end
    table.sort(machines, function(a, b)
      if a.number ~= b.number then return a.number < b.number end
      return tostring(a.itemId) < tostring(b.itemId)
    end)
    for _, machine in ipairs(machines) do
      result[#result + 1] = moveRow(data, machine.moveId, {
        source = lowerKind, itemId = machine.itemId,
        machineKind = kind, machineNumber = machine.number,
        levelLabel = (kind .. "%02d"):format(machine.number),
      })
    end
    if #machines == 0 then
      result[#result + 1] = {
        kind = "message", label = "NO LEARNABLE " .. kind .. "s",
      }
    end
  end
  appendMachines("TM")
  appendMachines("HM")
  local invalid = 0
  for _, move in ipairs(result) do
    if move.kind == "move" and move.valid == false then invalid = invalid + 1 end
  end
  return result, invalid
end

local function describeEvolution(game, evo, diagnose)
  if type(evo) ~= "table" then return "SPECIAL — DATA INCOMPLETE" end
  local methodId = tostring(evo.method or "SPECIAL")
  local methods = game and game.data and game.data.evolution_methods
  local method = type(methods) == "table" and methods[evo.method] or nil
  if type(method) == "table" and type(method.describe) == "function" then
    local ok, value = pcall(method.describe, evo, game.data)
    if ok and type(value) == "string" and value ~= "" then return value end
    if diagnose then
      diagnose("evolution describer failed for " .. methodId .. ": " .. tostring(value))
    end
  end
  if methodId == "LEVEL" then
    local level = integer(evo.level)
    return level and ("LEVEL " .. tostring(level)) or "LEVEL — DATA INCOMPLETE"
  end
  if methodId == "ITEM" then
    local item = game and game.data and game.data.items and game.data.items[evo.item]
    local name = type(item) == "table" and item.name or evo.item
    return name and ("USE " .. tostring(name)) or "ITEM — DATA INCOMPLETE"
  end
  if methodId == "TRADE" then return "TRADE" end
  return humanize(methodId)
end

local function evolutionModel(game, row, diagnose)
  local def = selectedDefinition(game, row) or {}
  local dex = game and game.save and game.save.pokedex or {}
  local possessed = possessedSpecies(game and game.save)
  local result = {}
  for _, evo in ipairs(type(def.evolutions) == "table" and def.evolutions or {}) do
    if type(evo) == "table" then
      local targetId = evo.species
      local target = game.data and game.data.pokemon and game.data.pokemon[targetId]
      local targetKnown = type(targetId) == "string" and
        ((type(dex.seen) == "table" and dex.seen[targetId])
          or (type(dex.owned) == "table" and dex.owned[targetId]) or possessed[targetId])
      result[#result + 1] = {
        kind = "evolution",
        targetSpeciesId = targetKnown and targetId or nil,
        targetName = targetKnown and type(target) == "table"
          and tostring(target.name or targetId) or "?????",
        targetHidden = not targetKnown,
        methodId = tostring(evo.method or "SPECIAL"),
        method = describeEvolution(game, evo, diagnose),
      }
    end
  end
  if #result == 0 then
    result[1] = { kind = "message", label = "NO FURTHER EVOLUTION" }
  end
  return result
end

local function mapName(data, mapId)
  local maps = data and data.maps
  local map = type(maps) == "table" and maps[mapId] or nil
  if type(map) == "table" and type(map.label) == "string" and map.label ~= "" then
    return map.label
  end
  local townMap = data and data.field and data.field.townMap
  local locations = type(townMap) == "table" and (townMap.locations or townMap) or nil
  local location = type(locations) == "table" and locations[mapId] or nil
  if type(location) == "table" then
    local name = location.name or location.label
    if type(name) == "string" and name ~= "" then return name end
  end
  return humanize(mapId)
end

local function nativeMethod(data, mapId, groupId)
  if groupId == "water" then return "SURF" end
  local map = data and data.maps and data.maps[mapId]
  local indoor = data and data.field and data.field.indoorEncounters
  if type(map) == "table" and type(indoor) == "table"
      and finite(map.index) and finite(indoor.firstIndoorMap)
      and map.index >= indoor.firstIndoorMap
      and map.tileset ~= indoor.excludedTileset then
    return "CAVE"
  end
  return "GRASS"
end

local function aggregateHabitat(out, index, row)
  local key = table.concat({ tostring(row.mapId), tostring(row.method),
    tostring(row.conditionKey or "") }, "\31")
  local existing = index[key]
  if not existing then
    row.conditionKey = nil
    out[#out + 1] = row
    index[key] = row
    return
  end
  existing.minLevel = math.min(existing.minLevel, row.minLevel)
  existing.maxLevel = math.max(existing.maxLevel, row.maxLevel)
  existing.slotChance = (existing.slotChance or 0) + (row.slotChance or 0)
  if existing.stepChance and row.stepChance then
    existing.stepChance = existing.stepChance + row.stepChance
  else
    existing.stepChance = nil
  end
end

local function nativeHabitats(game, speciesId)
  local data = game and game.data or {}
  local out, index = {}, {}
  local constants = type(data.constants) == "table" and data.constants or {}
  local defaultBuckets = type(constants.encounterBuckets) == "table"
    and constants.encounterBuckets or DEFAULT_BUCKETS
  for mapId, encounter in pairs(type(data.encounters) == "table" and data.encounters or {}) do
    if type(encounter) == "table" then
      for _, groupId in ipairs({ "grass", "water" }) do
        local group = encounter[groupId]
        local slots = type(group) == "table" and group.slots or nil
        local buckets = type(group) == "table" and group.buckets or defaultBuckets
        if type(slots) == "table" and type(buckets) == "table" then
          local previous = 0
          for slotIndex, thresholdValue in ipairs(buckets) do
            local threshold = finite(thresholdValue)
            local slot = slots[slotIndex]
            local width = threshold and math.max(0, threshold - previous) or 0
            if threshold then previous = threshold end
            if type(slot) == "table" and slot.species == speciesId
                and integer(slot.level) and width > 0 then
              local slotChance = width / 256 * 100
              local rate = finite(group.rate)
              aggregateHabitat(out, index, {
                kind = "habitat", mapId = tostring(mapId),
                mapName = mapName(data, mapId),
                method = nativeMethod(data, mapId, groupId),
                minLevel = integer(slot.level), maxLevel = integer(slot.level),
                slotChance = slotChance,
                stepChance = rate and rate / 256 * slotChance or nil,
                conditions = {}, providerId = "engine_encounters",
              })
            end
          end
        end
      end
    end
  end

  local field = type(data.field) == "table" and data.field or {}
  local fishing = type(field.fishing) == "table" and field.fishing or {}
  for rodId, rod in pairs(fishing) do
    local perMap = type(rod) == "table" and rod.perMap or nil
    local groups = type(perMap) == "string" and field[perMap] or nil
    if type(groups) == "table" then
      for mapId, slots in pairs(groups) do
        if type(slots) == "table" and #slots > 0 then
          for _, slot in ipairs(slots) do
            if type(slot) == "table" and slot.species == speciesId
                and integer(slot.level) then
              local chance = 100 / (#slots + 4)
              aggregateHabitat(out, index, {
                kind = "habitat", mapId = tostring(mapId),
                mapName = mapName(data, mapId), method = humanize(rodId),
                minLevel = integer(slot.level), maxLevel = integer(slot.level),
                slotChance = chance, conditions = {},
                providerId = "engine_fishing",
              })
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    local amap = data.maps and data.maps[a.mapId]
    local bmap = data.maps and data.maps[b.mapId]
    local ai = type(amap) == "table" and finite(amap.index) or math.huge
    local bi = type(bmap) == "table" and finite(bmap.index) or math.huge
    if ai ~= bi then return ai < bi end
    if a.mapName ~= b.mapName then return a.mapName < b.mapName end
    if a.method ~= b.method then return a.method < b.method end
    if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
    return a.maxLevel < b.maxLevel
  end)
  if #out == 0 then
    out[1] = { kind = "message", label = "NO WILD HABITAT RECORDED" }
  end
  return out
end

local function validatedProviderHabitats(snapshot, speciesId)
  if type(snapshot) ~= "table" or snapshot.schemaVersion ~= 1
      or snapshot.speciesId ~= speciesId or type(snapshot.habitats) ~= "table" then
    return nil, "incompatible species-habitat snapshot"
  end
  local rows = {}
  for _, source in ipairs(snapshot.habitats) do
    if type(source) == "table" and type(source.mapId) == "string"
        and type(source.mapName) == "string" and type(source.method) == "string"
        and integer(source.minLevel) and integer(source.maxLevel)
        and source.minLevel <= source.maxLevel then
      rows[#rows + 1] = {
        kind = "habitat", mapId = source.mapId, mapName = source.mapName,
        method = source.method, minLevel = source.minLevel,
        maxLevel = source.maxLevel, slotChance = finite(source.slotChance),
        stepChance = finite(source.stepChance),
        conditions = semanticCopy(source.conditions or {}),
        providerId = tostring(snapshot.providerId or "kanto_living_encounters"),
        providerRevision = finite(snapshot.providerRevision),
        snapshotRevision = finite(snapshot.snapshotRevision),
      }
    end
  end
  if #rows == 0 then
    rows[1] = { kind = "message", label = "NO WILD HABITAT RECORDED" }
  end
  return rows
end

local function researchSnapshot(mod, state, row)
  local screen = "pokedex_" .. tostring(state.mode)
  local base = {
    schemaVersion = API_VERSION,
    screen = screen,
    title = upper(state.mode),
    speciesId = row.speciesId,
    number = row.number,
    name = row.name,
    selectedIndex = integer(state.pageIndex[state.mode]) or 1,
    scroll = integer(state.pageScroll[state.mode]) or 0,
  }
  if not row.owned then
    base.gated = true
    base.message = "RESEARCH DATA LOCKED — CATCH THIS POKEMON"
    base.rows = { { kind = "message", label = base.message } }
    return base
  end
  if state.mode == "stats" then
    local malformed
    base.rows, base.types, malformed = statsModel(state.game, row)
    if malformed and state._diagnose then
      state._diagnose("malformed base stats for " .. row.speciesId)
    end
  elseif state.mode == "learnset" then
    local invalid
    base.rows, invalid = learnsetModel(state.game, row)
    if invalid > 0 and state._diagnose then
      state._diagnose(tostring(invalid) .. " invalid learnset/machine move rows for "
        .. row.speciesId)
    end
  elseif state.mode == "evolution" then
    base.rows = evolutionModel(state.game, row, state._diagnose)
  elseif state.mode == "habitat" then
    local provider = type(mod.find) == "function" and mod:find("kanto_living_encounters") or nil
    local query = provider and provider.exports and provider.exports.getSpeciesHabitatSnapshot
    if type(query) == "function" then
      local ok, value = pcall(query, row.speciesId, {
        schemaVersion = 1, game = state.game, purpose = "pokedex",
      })
      if ok and value ~= nil then
        local rows, reason = validatedProviderHabitats(value, row.speciesId)
        if rows then base.rows = rows end
        if not rows and state._diagnose then
          state._diagnose("spawn habitat provider returned an invalid snapshot: "
            .. tostring(reason))
        end
      elseif not ok and state._diagnose then
        state._diagnose("spawn habitat provider query failed: " .. tostring(value))
      end
    end
    if not base.rows then base.rows = nativeHabitats(state.game, row.speciesId) end
  end
  return base
end

local function snapshot(mod, game, state)
  if type(state) ~= "table" or state.__widescreenPokedex ~= true then return nil end
  local rows = speciesRows(game)
  local selected = selectedRow(state, rows)
  if not selected then
    return {
      schemaVersion = API_VERSION, screen = "pokedex", title = "POKEDEX",
      rows = {}, selectedIndex = 1,
      counts = { seen = 0, owned = 0, total = 0 },
      detail = { name = "NO POKEDEX DATA", hidden = true,
        portrait = { kind = "unknown" }, entry = "DATA UNAVAILABLE" },
    }
  end
  if state.mode ~= "pokedex" then return researchSnapshot(mod, state, selected) end
  local publicRows = {}
  for _, row in ipairs(rows) do publicRows[#publicRows + 1] = publicRow(row) end
  local submenu
  if state.submenuOpen then
    submenu = { selectedIndex = state.submenuIndex, rows = {} }
    for _, item in ipairs(SUBMENU) do
      submenu.rows[#submenu.rows + 1] = {
        id = item.id, label = item.label, action = item.action and true or false,
      }
    end
  end
  return {
    schemaVersion = API_VERSION,
    screen = "pokedex",
    title = "POKEDEX",
    rows = publicRows,
    selectedIndex = state.selectedIndex,
    selectedSpeciesId = selected.speciesId,
    counts = countsFor(rows),
    detail = detailFor(mod, game, selected, state),
    submenu = submenu,
  }
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

return function(mod)
  local logged = {}
  local registered = false
  local widescreenExports

  local function logOnce(message)
    message = tostring(message)
    if logged[message] then return end
    logged[message] = true
    if mod.log and type(mod.log.error) == "function" then
      mod.log:error("Widescreen Pokedex: %s", message)
    end
  end

  local function currentRows(state)
    return speciesRows(state and state.game)
  end

  local function currentResearchCount(state)
    if not state or state.mode == "pokedex" then return 0 end
    local rows = currentRows(state)
    local row = selectedRow(state, rows)
    if not row then return 0 end
    local model = researchSnapshot(mod, state, row)
    return type(model.rows) == "table" and #model.rows or 0
  end

  local function moveResearchSelection(state, delta)
    local count = currentResearchCount(state)
    local index = clamp((integer(state.pageIndex[state.mode]) or 1) + delta,
      1, math.max(1, count))
    state.pageIndex[state.mode] = index
    local scroll = integer(state.pageScroll[state.mode]) or 0
    if index <= scroll then scroll = index - 1 end
    if index > scroll + 7 then scroll = index - 7 end
    state.pageScroll[state.mode] = clamp(scroll, 0, math.max(0, count - 7))
    return true
  end

  local actions = {}

  local function setSelectedRow(state, rows, index)
    index = clamp(index, 1, math.max(1, #rows))
    local speciesId = rows[index] and rows[index].speciesId or nil
    if state.selectedSpeciesId ~= speciesId then
      state.shinySpeciesId, state.shinyEnabled = speciesId, false
    end
    state.selectedIndex, state.selectedSpeciesId = index, speciesId
    return true
  end

  function actions.up(_, state)
    if state.mode ~= "pokedex" then
      return moveResearchSelection(state, -1)
    end
    if state.submenuOpen then
      state.submenuIndex = clamp(state.submenuIndex - 1, 1, #SUBMENU)
      return true
    end
    local rows = currentRows(state)
    return setSelectedRow(state, rows, state.selectedIndex - 1)
  end

  function actions.down(_, state)
    if state.mode ~= "pokedex" then
      return moveResearchSelection(state, 1)
    end
    if state.submenuOpen then
      state.submenuIndex = clamp(state.submenuIndex + 1, 1, #SUBMENU)
      return true
    end
    local rows = currentRows(state)
    return setSelectedRow(state, rows, state.selectedIndex + 1)
  end

  function actions.pageUp(_, state)
    if state.mode ~= "pokedex" then
      return moveResearchSelection(state, -7)
    end
    if state.submenuOpen then return actions.up(nil, state) end
    local rows = currentRows(state)
    return setSelectedRow(state, rows, state.selectedIndex - 7)
  end

  function actions.pageDown(_, state)
    if state.mode ~= "pokedex" then
      return moveResearchSelection(state, 7)
    end
    if state.submenuOpen then return actions.down(nil, state) end
    local rows = currentRows(state)
    return setSelectedRow(state, rows, state.selectedIndex + 7)
  end

  function actions.selectRow(_, state, index)
    if state.mode ~= "pokedex" or state.submenuOpen then return nil, "list is not focused" end
    local rows = currentRows(state)
    index = integer(index)
    if not index or not rows[index] then return nil, "invalid row index" end
    return setSelectedRow(state, rows, index)
  end

  function actions.toggleShiny(game, state)
    if state.mode ~= "pokedex" or state.submenuOpen then
      return nil, "shiny portrait is not focused"
    end
    local row = selectedRow(state, currentRows(state))
    if not row or not row.owned
        or not hasCaughtShiny(mod, game, row.speciesId, state._diagnose) then
      state.shinyEnabled = false
      return nil, "no caught shiny is currently available"
    end
    state.shinySpeciesId = row.speciesId
    state.shinyEnabled = not (state.shinyEnabled == true)
    return true
  end

  function actions.submenuSelect(game, state, actionId)
    local rows = currentRows(state)
    local row = selectedRow(state, rows)
    if not row or not row.seen then return nil, "selected species is unseen" end
    actionId = tostring(actionId or "")
    if actionId == "cry" then
      local ok, sound = pcall(require, "src.core.Sound")
      if not ok or type(sound) ~= "table" or type(sound.playCry) ~= "function" then
        logOnce("engine Sound.playCry is unavailable")
        return nil, "cry unavailable"
      end
      local played, reason = pcall(sound.playCry, game.data, row.speciesId)
      if not played then
        logOnce("cry failed for " .. row.speciesId .. ": " .. tostring(reason))
        return nil, "cry failed"
      end
      return true
    end
    if actionId ~= "habitat" and actionId ~= "stats"
        and actionId ~= "learnset" and actionId ~= "evolution" then
      return nil, "unknown submenu action"
    end
    state.mode = actionId
    state.pageIndex[actionId] = state.pageIndex[actionId] or 1
    state.pageScroll[actionId] = state.pageScroll[actionId] or 0
    return true
  end

  function actions.selectSubmenu(game, state, index)
    index = integer(index)
    if not state.submenuOpen or not index or not SUBMENU[index] then
      return nil, "invalid submenu selection"
    end
    state.submenuIndex = index
    return actions.submenuSelect(game, state, SUBMENU[index].id)
  end

  function actions.select(game, state)
    if state.mode ~= "pokedex" then return true end
    if state.submenuOpen then
      return actions.selectSubmenu(game, state, state.submenuIndex)
    end
    local row = selectedRow(state, currentRows(state))
    if not row or not row.seen then return nil, "selected species is unseen" end
    state.submenuOpen = true
    return true
  end

  local function closeState(state)
    local game = state and state.game
    if game and game.stack and type(game.stack.pop) == "function" then game.stack:pop() end
    if state and type(state.onCancel) == "function" then state.onCancel() end
    return true
  end

  function actions.back(_, state)
    if state.mode ~= "pokedex" then
      state.mode = "pokedex"
      state.submenuOpen = true
      return true
    end
    if state.submenuOpen then
      state.submenuOpen = false
      return true
    end
    return closeState(state)
  end

  function actions.scroll(_, state, delta)
    delta = integer(delta) or 0
    if state.mode == "pokedex" then return delta < 0 and actions.up(nil, state)
      or delta > 0 and actions.down(nil, state) or true end
    return moveResearchSelection(state, delta)
  end

  local function ensureRegistered(context)
    local widescreen = type(mod.find) == "function" and mod:find("gen1_widescreen_ui") or nil
    local exports = widescreen and widescreen.exports
    if type(exports) ~= "table" or exports.pokedexProviderApiVersion ~= API_VERSION
        or type(exports.registerPokedexProvider) ~= "function"
        or type(exports.updatePokedexProviderInput) ~= "function" then
      registered, widescreenExports = false, nil
      logOnce("requires a Gen1 Widescreen UI release with Pokedex Provider API v2; native Pokedex destination remains unchanged")
      return false
    end
    if registered and type(exports.activePokedexProviderOwner) == "function" then
      local ok, owner = pcall(exports.activePokedexProviderOwner)
      if ok and owner == OWNER then widescreenExports = exports return true end
      registered = false
    end
    local ok, reason = exports.registerPokedexProvider({
      owner = OWNER,
      apiVersion = API_VERSION,
      match = function(state) return type(state) == "table" and state.__widescreenPokedex == true end,
      snapshot = function(game, state) return snapshot(mod, game, state) end,
      actions = actions,
    })
    if not ok then
      registered, widescreenExports = false, nil
      logOnce("could not register Pokedex provider at " .. tostring(context) .. ": " .. tostring(reason))
      return false
    end
    registered, widescreenExports = true, exports
    if mod.log and type(mod.log.info) == "function" then
      mod.log:info("Widescreen Pokedex provider %s at %s", tostring(reason), tostring(context))
    end
    return true
  end

  local State = {}
  State.__index = State
  State.isOpaque = true

  function State.new(game, opts)
    opts = type(opts) == "table" and opts or {}
    local rows = speciesRows(game)
    local state = setmetatable({
      game = game,
      onCancel = opts.onCancel,
      __widescreenPokedex = true,
      mode = "pokedex",
      selectedIndex = 1,
      selectedSpeciesId = rows[1] and rows[1].speciesId or nil,
      shinySpeciesId = rows[1] and rows[1].speciesId or nil,
      shinyEnabled = false,
      submenuOpen = false,
      submenuIndex = 1,
      pageIndex = {},
      pageScroll = {},
      _diagnose = logOnce,
    }, State)
    return state
  end

  function State:update(dt)
    if not ensureRegistered("screen update") then return end
    local ok, reason = pcall(widescreenExports.updatePokedexProviderInput,
      self.game, self, dt)
    if not ok then logOnce("Widescreen input dispatch failed: " .. tostring(reason)) end
  end

  function State:draw()
    -- Widescreen is the sole presenter. A valid screen cannot be opened until
    -- API v2 registration succeeds, so there is intentionally no native draw.
  end

  mod.exports.apiVersion = API_VERSION
  mod.exports.speciesRows = speciesRows
  mod.exports.possessedSpecies = possessedSpecies
  mod.exports.hasCaughtShiny = function(game, speciesId)
    return hasCaughtShiny(mod, game, speciesId, logOnce)
  end
  mod.exports.normalizeEntryText = normalizeEntryText
  mod.exports.snapshot = function(game, state) return snapshot(mod, game, state) end
  mod.exports.stats = statsModel
  mod.exports.learnset = learnsetModel
  mod.exports.evolutions = evolutionModel
  mod.exports.nativeHabitats = nativeHabitats
  mod.exports.actions = actions
  mod.exports.newState = State.new
  mod.exports.ensureRegistered = ensureRegistered

  if mod.content and mod.content.screens and type(mod.content.screens.register) == "function" then
    mod.content.screens:register(SCREEN_ID, { new = State.new })
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
      local out = next(game, items)
      if type(out) ~= "table" or not ensureRegistered("Start menu") then return out end
      local decorated = {}
      for i, item in ipairs(out) do decorated[i] = item end
      for i, item in ipairs(decorated) do
        local label = tostring(item and item.label or "")
          :gsub("é", "E"):gsub("É", "E"):upper():gsub("[^A-Z]", "")
        if label == "POKEDEX" then
          local replacement = {}
          for key, value in pairs(item) do replacement[key] = value end
          replacement.onSelect = function()
            mod.ui.push(game, SCREEN_ID, {
              onCancel = function() mod.ui.push(game, "StartMenu") end,
            })
          end
          replacement.id = replacement.id or OWNER
          decorated[i] = replacement
          break
        end
      end
      return decorated
    end)
  end

  ensureRegistered("initialization")
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mods.loaded", function() ensureRegistered("mods.loaded") end)
    mod.events:on("game.ready", function() ensureRegistered("game.ready") end)
  end
end
