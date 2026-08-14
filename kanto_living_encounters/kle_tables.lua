return function(Core)
  local Tables = {}
  local DEFAULT_BUCKETS = { 51, 102, 141, 166, 191, 216, 229, 242, 253, 256 }

  local function copyEntry(slot, weight, surface, sourceMap)
    if type(slot) ~= "table" or not slot.species then return nil end
    local level = tonumber(slot.level)
    if not level then return nil end
    return {
      species = slot.species,
      minLevel = level,
      maxLevel = level,
      weight = weight,
      surface = surface,
      sourceMap = sourceMap,
    }
  end

  local function surfaceEntries(encounterDef, kind, sourceMap, buckets)
    local surface = encounterDef and encounterDef[kind]
    if type(surface) ~= "table" or type(surface.slots) ~= "table" then return {} end
    buckets = surface.buckets or buckets or DEFAULT_BUCKETS
    local entries, previous = {}, 0
    for index, slot in ipairs(surface.slots) do
      local threshold = tonumber(buckets[index]) or previous
      local entry = copyEntry(slot, math.max(0, threshold - previous), kind, sourceMap)
      if entry and entry.weight > 0 then entries[#entries + 1] = entry end
      previous = threshold
    end
    return entries
  end

  local function append(into, rows)
    for _, row in ipairs(rows or {}) do into[#into + 1] = row end
  end

  function Tables.resolve(data, mapId, area)
    local encounters = data and data.encounters or {}
    local buckets = data and data.field and data.field.constants
      and data.field.constants.encounterBuckets or DEFAULT_BUCKETS
    local land, water = {}, {}
    local sources = {}

    local routes
    if area == "town" then
      routes = Core.TOWN_ADJACENCY[mapId]
    else
      routes = Core.specialPoolRoutes(mapId)
    end
    if routes then
      for _, routeId in ipairs(routes) do
        local def = encounters[routeId]
        local before = #land + #water
        append(land, surfaceEntries(def, "grass", routeId, buckets))
        append(water, surfaceEntries(def, "water", routeId, buckets))
        if #land + #water > before then sources[#sources + 1] = routeId end
      end
    else
      local def = encounters[mapId]
      append(land, surfaceEntries(def, "grass", mapId, buckets))
      append(water, surfaceEntries(def, "water", mapId, buckets))
      if #land + #water > 0 then sources[1] = mapId end
    end

    return {
      schemaVersion = 1,
      mapId = mapId,
      area = area,
      revision = tostring(data and data.revision or "live"),
      land = land,
      water = water,
      sources = sources,
      sourceProvider = "live-engine-registry",
    }
  end

  function Tables.pick(entries, rng, excludedSpecies)
    local total = 0
    for _, entry in ipairs(entries or {}) do
      if not (excludedSpecies and excludedSpecies[entry.species]) then
        total = total + math.max(0, tonumber(entry.weight) or 0)
      end
    end
    if total <= 0 and excludedSpecies then return Tables.pick(entries, rng, nil) end
    if total <= 0 then return nil end
    local roll = (type(rng) == "function" and rng() or math.random()) * total
    local cumulative = 0
    for _, entry in ipairs(entries) do
      if not (excludedSpecies and excludedSpecies[entry.species]) then
        cumulative = cumulative + math.max(0, tonumber(entry.weight) or 0)
      end
      if not (excludedSpecies and excludedSpecies[entry.species]) and roll < cumulative then
        local minLevel = math.floor(tonumber(entry.minLevel) or 1)
        local maxLevel = math.floor(tonumber(entry.maxLevel) or minLevel)
        local level = minLevel
        if maxLevel > minLevel then
          level = type(rng) == "function" and rng(minLevel, maxLevel)
            or math.random(minLevel, maxLevel)
        end
        return entry.species, level, entry
      end
    end
    local last
    for _, entry in ipairs(entries) do
      if not (excludedSpecies and excludedSpecies[entry.species]) then last = entry end
    end
    if not last then return nil end
    return last.species, last.minLevel, last
  end

  local function snapshotSection(id, title, entries, area)
    local merged, order = {}, {}
    for _, entry in ipairs(entries or {}) do
      local row = merged[entry.species]
      if not row then
        row = {
          species = entry.species,
          weight = 0,
          minLevel = entry.minLevel,
          maxLevel = entry.maxLevel,
          surfaces = { id },
          behaviorWeights = area == "town"
            and { idle = 41.5625, roam = 53.4375, moving = 53.4375, aggressive = 5 }
            or { idle = 39.375, roam = 50.625, moving = 50.625, aggressive = 10 },
          ambient = false,
          battleRule = area == "town" and "aggressive_only" or "contact",
          interactRule = area == "town" and "face_and_cry" or "none",
          available = true,
        }
        merged[entry.species] = row
        order[#order + 1] = row
      end
      row.weight = row.weight + entry.weight
      row.minLevel = math.min(row.minLevel, entry.minLevel)
      row.maxLevel = math.max(row.maxLevel, entry.maxLevel)
    end
    local total = 0
    for _, row in ipairs(order) do total = total + row.weight end
    for _, row in ipairs(order) do row.chance = total > 0 and row.weight / total or 0 end
    return { id = id, title = title, entries = order }
  end

  function Tables.effectiveSnapshot(resolved, mapLabel, snapshotRevision)
    if type(resolved) ~= "table" then return nil end
    local sections = {}
    if #resolved.land > 0 then
      sections[#sections + 1] = snapshotSection("land", "LAND", resolved.land,
        resolved.area)
    end
    if #resolved.water > 0 then
      sections[#sections + 1] = snapshotSection("water", "WATER", resolved.water,
        resolved.area)
    end
    return {
      schemaVersion = 1,
      mapId = resolved.mapId,
      mapLabel = mapLabel or resolved.mapId,
      area = resolved.area,
      providerId = resolved.sourceProvider,
      providerRevision = resolved.revision,
      snapshotRevision = snapshotRevision or 1,
      sections = sections,
    }
  end

  return Tables
end
