-- Transactional validators. They stage normalized copies first and return no
-- content operations when any record is invalid.
return function(Normalize)
  local Validators = {}

  local EXPECTED_DATASETS = {
    "species", "learnsets", "evolutions", "encounters", "fishing",
  }

  local NORMALIZERS = {
    species = Normalize.species,
    learnsets = Normalize.species,
    evolutions = Normalize.species,
    encounters = Normalize.map,
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
      result[copy(key, seen)] = copy(item, seen)
    end
    return result
  end

  local function push(errors, message)
    errors[#errors + 1] = tostring(message)
  end

  local function integer(value, minimum, maximum)
    return type(value) == "number" and value % 1 == 0
      and value >= minimum and value <= maximum
  end

  function Validators.stageMap(source, normalizeKey, validateRecord)
    local errors, staged, seen = {}, {}, {}
    if type(source) ~= "table" then
      return nil, { "record set must be a table" }
    end
    if type(normalizeKey) ~= "function" then
      return nil, { "record set needs a key normalizer" }
    end

    local keys = {}
    for key in pairs(source) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, rawKey in ipairs(keys) do
      local id = normalizeKey(rawKey)
      if id == "" then
        push(errors, "empty canonical ID from " .. tostring(rawKey))
      elseif seen[id] then
        push(errors, ("duplicate canonical ID %s from %s and %s")
          :format(id, tostring(seen[id]), tostring(rawKey)))
      else
        seen[id] = rawKey
        local candidate = copy(source[rawKey])
        if type(validateRecord) == "function" then
          local ok, value, detail = pcall(validateRecord, candidate, id, rawKey)
          if not ok then
            push(errors, id .. ": validator failed: " .. tostring(value))
          elseif value == nil or value == false then
            push(errors, id .. ": " .. tostring(detail or "invalid record"))
          else
            candidate = value == true and candidate or value
          end
        end
        staged[id] = candidate
      end
    end

    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateParty(party, resolveSpecies)
    local errors, staged = {}, {}
    if type(party) ~= "table" then
      return nil, { "party must be a table" }
    end
    if #party < 1 or #party > 6 then
      push(errors, "party size must be between 1 and 6")
    end

    for index, mon in ipairs(party) do
      if type(mon) ~= "table" then
        push(errors, ("slot %d must be a table"):format(index))
      else
        local level = mon.level
        local species = Normalize.species(mon.species)
        if not integer(level, 1, 100) then
          push(errors, ("slot %d has invalid level %s"):format(index, tostring(level)))
        end
        if species == "" then
          push(errors, ("slot %d has no species"):format(index))
        elseif type(resolveSpecies) == "function" then
          local resolved = resolveSpecies(species)
          if not resolved then
            push(errors, ("slot %d has unknown species %s"):format(index, species))
          else
            species = resolved
          end
        end
        staged[index] = { level = level, species = species }
      end
    end

    local numeric = 0
    for key in pairs(party) do
      if type(key) == "number" then numeric = numeric + 1 end
    end
    if numeric ~= #party then push(errors, "party array is sparse") end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateLearnset(rows, resolveMove)
    local errors, staged = {}, {}
    if type(rows) ~= "table" then
      return nil, { "learnset must be a table" }
    end
    for index, row in ipairs(rows) do
      if type(row) ~= "table" then
        push(errors, ("row %d must be a table"):format(index))
      else
        local level = row.level or row[1]
        local move = Normalize.move(row.move or row[2])
        if not integer(level, 1, 100) then
          push(errors, ("row %d has invalid level %s"):format(index, tostring(level)))
        end
        if move == "" then
          push(errors, ("row %d has no move"):format(index))
        elseif type(resolveMove) == "function" then
          local resolved = resolveMove(move)
          if not resolved then
            push(errors, ("row %d has unknown move %s"):format(index, move))
          else
            move = resolved
          end
        end
        staged[index] = { level = level, move = move }
      end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateSpeciesPatch(record)
    local errors, staged = {}, { baseStats = {} }
    if type(record) ~= "table" or type(record.baseStats) ~= "table" then
      return nil, { "species patch needs baseStats" }
    end
    local allowed = { hp = true, attack = true, defense = true,
      special = true, speed = true }
    for field, value in pairs(record.baseStats) do
      if not allowed[field] then
        push(errors, "unknown base stat " .. tostring(field))
      elseif not integer(value, 1, 255) then
        push(errors, field .. " must be an integer from 1 to 255")
      else
        staged.baseStats[field] = value
      end
    end
    if next(staged.baseStats) == nil then push(errors, "baseStats is empty") end
    for key in pairs(record) do
      if key ~= "baseStats" then push(errors, "unknown species patch field " .. tostring(key)) end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateLearnsetRecord(record, resolveMove)
    local errors = {}
    if type(record) ~= "table" or type(record.level1Moves) ~= "table" then
      return nil, { "learnset record needs level1Moves" }
    end
    local starting = {}
    for index, rawMove in ipairs(record.level1Moves) do
      local move = Normalize.move(rawMove)
      if move == "" then
        push(errors, ("level1Moves slot %d has no move"):format(index))
      elseif type(resolveMove) == "function" and not resolveMove(move) then
        push(errors, ("level1Moves slot %d has unknown move %s"):format(index, move))
      else
        starting[index] = move
      end
    end
    if #starting > 4 then push(errors, "level1Moves cannot exceed four moves") end
    local rows, rowErrors = Validators.validateLearnset(record.learnset, resolveMove)
    if not rows then
      for _, message in ipairs(rowErrors) do push(errors, message) end
    end
    for key in pairs(record) do
      if key ~= "level1Moves" and key ~= "learnset" then
        push(errors, "unknown learnset record field " .. tostring(key))
      end
    end
    if #errors > 0 then return nil, errors end
    return { level1Moves = starting, learnset = rows }, {}
  end

  function Validators.validateEvolutionPatch(record, resolveSpecies)
    local errors, staged = {}, { evolutions = {} }
    local rows = type(record) == "table" and record.evolutions
    if type(rows) ~= "table" then return nil, { "evolution patch needs evolutions" } end
    local seen = {}
    for index, row in ipairs(rows) do
      if type(row) ~= "table" then
        push(errors, ("evolution row %d must be a table"):format(index))
      else
        local method = Normalize.token(row.method)
        local species = Normalize.species(row.species)
        local key = method .. ":" .. species
        if method ~= "TRADE" and method ~= "LEVEL" then
          push(errors, ("evolution row %d has unsupported method %s"):format(index, method))
        elseif seen[key] then
          push(errors, ("evolution row %d duplicates %s"):format(index, key))
        else
          seen[key] = true
        end
        if species == "" or (type(resolveSpecies) == "function" and not resolveSpecies(species)) then
          push(errors, ("evolution row %d has unknown species %s"):format(index, species))
        end
        if method == "LEVEL" and not integer(row.level, 2, 100) then
          push(errors, ("evolution row %d has invalid level"):format(index))
        end
        local out = { method = method, species = species }
        if method == "LEVEL" then out.level = row.level end
        staged.evolutions[index] = out
      end
    end
    if #rows ~= 2 then push(errors, "trade alternative must contain exactly TRADE and LEVEL rows") end
    if not seen["TRADE:" .. tostring(staged.evolutions[1] and staged.evolutions[1].species)] then
      push(errors, "trade evolution row must be preserved first")
    end
    for key in pairs(record) do
      if key ~= "evolutions" then push(errors, "unknown evolution patch field " .. tostring(key)) end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateEncounterSlots(rows, resolveSpecies, expectedCount)
    local errors, staged = {}, {}
    if type(rows) ~= "table" then
      return nil, { "encounter slots must be a table" }
    end
    if expectedCount and #rows ~= expectedCount then
      push(errors, ("encounter table needs %d slots, got %d")
        :format(expectedCount, #rows))
    elseif #rows < 1 then
      push(errors, "encounter table cannot be empty")
    end
    for index, row in ipairs(rows) do
      if type(row) ~= "table" then
        push(errors, ("slot %d must be a table"):format(index))
      else
        local level = row.level or row[1]
        local species = Normalize.species(row.species or row[2])
        if not integer(level, 1, 100) then
          push(errors, ("slot %d has invalid level %s")
            :format(index, tostring(level)))
        end
        if species == "" then
          push(errors, ("slot %d has no species"):format(index))
        elseif type(resolveSpecies) == "function" then
          local resolved = resolveSpecies(species)
          if not resolved then
            push(errors, ("slot %d has unknown species %s")
              :format(index, species))
          else
            species = resolved
          end
        end
        staged[index] = { level = level, species = species }
      end
    end
    local numeric = 0
    for key in pairs(rows) do
      if type(key) == "number" then numeric = numeric + 1 end
    end
    if numeric ~= #rows then push(errors, "encounter slot array is sparse") end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateEncounter(record, resolveSpecies)
    local errors, staged, surfaces = {}, {}, 0
    if type(record) ~= "table" then
      return nil, { "encounter record must be a table" }
    end
    for _, kind in ipairs({ "grass", "water" }) do
      local surface = record[kind]
      if surface ~= nil then
        surfaces = surfaces + 1
        if type(surface) ~= "table" then
          push(errors, kind .. " surface must be a table")
        else
          if not integer(surface.fallbackRate, 0, 255) then
            push(errors, kind .. " surface has invalid fallbackRate")
          end
          local slots, slotErrors = Validators.validateEncounterSlots(
            surface.slots, resolveSpecies, 10)
          if not slots then
            for _, message in ipairs(slotErrors) do
              push(errors, kind .. ": " .. message)
            end
          else
            staged[kind] = {
              fallbackRate = surface.fallbackRate,
              slots = slots,
            }
          end
        end
      end
    end
    if surfaces == 0 then push(errors, "encounter record has no surface") end
    for key in pairs(record) do
      if key ~= "grass" and key ~= "water" then
        push(errors, "unknown encounter surface " .. tostring(key))
      end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateFishing(record, resolveSpecies)
    local errors, staged = {}, {}
    if type(record) ~= "table" then
      return nil, { "fishing dataset must be a table" }
    end
    for _, rod in ipairs({ "OLD_ROD", "GOOD_ROD" }) do
      local slots, slotErrors = Validators.validateEncounterSlots(
        record[rod], resolveSpecies, 2)
      if not slots then
        for _, message in ipairs(slotErrors) do
          push(errors, rod .. ": " .. message)
        end
      else
        staged[rod] = slots
      end
    end
    if type(record.SUPER_ROD) ~= "table" then
      push(errors, "SUPER_ROD map table is missing")
    else
      local maps, mapErrors = Validators.stageMap(record.SUPER_ROD,
        Normalize.map, function(rows)
          local slots, slotErrors = Validators.validateEncounterSlots(
            rows, resolveSpecies, 4)
          if not slots then return nil, table.concat(slotErrors, "; ") end
          return slots
        end)
      if not maps then
        for _, message in ipairs(mapErrors) do
          push(errors, "SUPER_ROD: " .. message)
        end
      else
        staged.SUPER_ROD = maps
      end
    end
    for key in pairs(record) do
      if key ~= "OLD_ROD" and key ~= "GOOD_ROD" and key ~= "SUPER_ROD" then
        push(errors, "unknown fishing key " .. tostring(key))
      end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.validateBundle(bundle)
    local errors, staged = {}, {}
    if type(bundle) ~= "table" then
      return nil, { "data bundle must be a table" }
    end
    for _, name in ipairs(EXPECTED_DATASETS) do
      local records = bundle[name]
      if type(records) ~= "table" then
        push(errors, name .. " dataset must return a table")
      else
        local value, recordErrors
        if name == "species" then
          value, recordErrors = Validators.stageMap(records, Normalize.species,
            function(record)
              local checked, details = Validators.validateSpeciesPatch(record)
              if not checked then return nil, table.concat(details, "; ") end
              return checked
            end)
        elseif name == "learnsets" then
          value, recordErrors = Validators.stageMap(records, Normalize.species,
            function(record)
              local checked, details = Validators.validateLearnsetRecord(record)
              if not checked then return nil, table.concat(details, "; ") end
              return checked
            end)
        elseif name == "evolutions" then
          value, recordErrors = Validators.stageMap(records, Normalize.species,
            function(record)
              local checked, details = Validators.validateEvolutionPatch(record)
              if not checked then return nil, table.concat(details, "; ") end
              return checked
            end)
        elseif name == "encounters" then
          value, recordErrors = Validators.stageMap(records, Normalize.map,
            function(record)
              local checked, details = Validators.validateEncounter(record)
              if not checked then return nil, table.concat(details, "; ") end
              return checked
            end)
        elseif name == "fishing" then
          value, recordErrors = Validators.validateFishing(records)
        else
          value, recordErrors = Validators.stageMap(records, NORMALIZERS[name])
        end
        if not value then
          for _, message in ipairs(recordErrors) do
            push(errors, name .. ": " .. message)
          end
        else
          staged[name] = value
        end
      end
    end
    if #errors > 0 then return nil, errors end
    return staged, {}
  end

  function Validators.assertBundle(bundle)
    local staged, errors = Validators.validateBundle(bundle)
    if not staged then
      error("Yellow Legacy data validation failed:\n- "
        .. table.concat(errors, "\n- "), 0)
    end
    return staged
  end

  return Validators
end
