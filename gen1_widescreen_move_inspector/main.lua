-- Widescreen Move Inspector
-- Version 0.1.0-alpha.2
-- Semantic provider only: this file performs no drawing and installs no hook.

local OWNER = "gen1_widescreen_move_inspector"
local API_VERSION = 1

local SPECIAL_DAMAGE_EFFECTS = {
  BIDE_EFFECT = true,
  OHKO_EFFECT = true,
  SUPER_FANG_EFFECT = true,
  METRONOME_EFFECT = true,
  MIRROR_MOVE_EFFECT = true,
}

local function finiteNumber(value)
  value = tonumber(value)
  if not value or value ~= value or value == math.huge or value == -math.huge then
    return nil
  end
  return value
end

local function integer(value, fallback)
  local number = finiteNumber(value)
  if not number then return fallback end
  return math.floor(number)
end

local function nearly(a, b)
  return math.abs(a - b) <= 0.0000001 * math.max(1, math.abs(a), math.abs(b))
end

local function deduplicatedTypes(types)
  local result, seen = {}, {}
  for _, typeId in ipairs(type(types) == "table" and types or {}) do
    if typeId ~= nil and not seen[typeId] then
      seen[typeId] = true
      result[#result + 1] = typeId
    end
  end
  return result
end

-- Gen1Recomp's merged chart stores integer multipliers scaled by ten. A
-- missing pair is neutral, matching TypeChart.effectiveness. Repeated current
-- types are collapsed so a monotype represented twice is not squared.
local function effectiveness(data, attackType, defenderTypes)
  if attackType == nil then return 1 end
  local row = {}
  local chart = data and data.type_chart
  for _, matchup in ipairs(chart and chart.matchups or {}) do
    if matchup.attacker == attackType then
      local multiplier = finiteNumber(matchup.multiplier)
      if multiplier then row[matchup.defender] = multiplier end
    end
  end

  local numerator, denominator = 1, 1
  for _, defenderType in ipairs(deduplicatedTypes(defenderTypes)) do
    numerator = numerator * (row[defenderType] or 10)
    denominator = denominator * 10
  end
  return numerator / denominator
end

local function compactNumber(value)
  if nearly(value, math.floor(value + 0.5)) then
    return tostring(math.floor(value + 0.5))
  end
  return ("%.3g"):format(value)
end

local function formatMultiplier(factor)
  factor = finiteNumber(factor)
  if not factor then return "?×" end
  if nearly(factor, 0) then return "0×" end
  if nearly(factor, 0.25) then return "¼×" end
  if nearly(factor, 0.5) then return "½×" end
  if nearly(factor, 1) then return "1×" end
  if nearly(factor, 2) then return "2×" end
  if nearly(factor, 4) then return "4×" end
  return compactNumber(factor) .. "×"
end

local function matchupLabel(factor)
  if nearly(factor, 0) then return "IMMUNE" end
  if factor < 1 then return "RESISTED" end
  if factor > 1 then return "SUPER EFFECTIVE" end
  return "NEUTRAL"
end

local function hasType(types, wanted)
  for _, typeId in ipairs(type(types) == "table" and types or {}) do
    if typeId == wanted then return true end
  end
  return false
end

local function maxPP(move, definition)
  if finiteNumber(move and move.maxPP) then
    return math.max(0, integer(move.maxPP, 0))
  end
  local base = math.max(0, integer(definition and definition.pp,
    integer(move and move.pp, 0)))
  local ppUps = math.max(0, integer(move and move.ppUps, 0))
  return base + ppUps * math.floor(base / 5)
end

local function powerDescriptor(definition, moveId)
  local effect = definition.effect
  if definition.fixedDamage ~= nil or effect == "SPECIAL_DAMAGE_EFFECT" then
    return { kind = "fixed", value = nil, label = "FIXED" }
  end
  if SPECIAL_DAMAGE_EFFECTS[effect]
      or (definition.id or moveId) == "COUNTER" then
    return { kind = "special", value = nil, label = "VARIES" }
  end
  local power = finiteNumber(definition.power) or 0
  if definition.category == "status" or power <= 0 then
    return { kind = "status", value = nil, label = "—" }
  end
  power = math.floor(power)
  return { kind = "base", value = power, label = tostring(power) }
end

local function accuracyDescriptor(definition)
  if definition.alwaysHit == true or definition.effect == "SWIFT_EFFECT" then
    return { kind = "always", value = nil, label = "ALWAYS" }
  end
  local accuracy = finiteNumber(definition.accuracy)
  if not accuracy or accuracy <= 0 then
    return { kind = "unavailable", value = nil, label = "—" }
  end
  return {
    kind = "percent",
    value = accuracy,
    label = compactNumber(accuracy) .. "%",
  }
end

local function snapshot(battle)
  if type(battle) ~= "table" or battle.phase ~= "moveSelect" then return nil end
  local player, enemy, data = battle.player, battle.enemy, battle.data
  if type(player) ~= "table" or type(enemy) ~= "table" or type(data) ~= "table" then
    return nil
  end
  if type(player.curTypes) ~= "table" or type(enemy.curTypes) ~= "table" then
    return nil
  end
  local selected = integer(battle.moveIndex, 1)
  local move = type(player.curMoves) == "table" and player.curMoves[selected] or nil
  if type(move) ~= "table" or move.id == nil then return nil end
  local definition = type(data.moves) == "table" and data.moves[move.id] or nil
  if type(definition) ~= "table" or definition.type == nil then return nil end

  local power = powerDescriptor(definition, move.id)
  local defenderTypes = deduplicatedTypes(enemy.curTypes)
  local factor = effectiveness(data, definition.type, defenderTypes)
  local ordinaryDamage = power.kind == "base"
  local stab = ordinaryDamage and hasType(player.curTypes, definition.type)
  local matchup = ordinaryDamage and matchupLabel(factor) or "TYPE CHART"

  return {
    schemaVersion = 1,
    phase = "moveSelect",
    selectedIndex = selected,
    moveId = tostring(move.id),
    moveName = tostring(definition.name or move.id),
    typeId = tostring(definition.type),
    pp = {
      current = math.max(0, integer(move.pp, 0)),
      maximum = maxPP(move, definition),
    },
    power = power,
    accuracy = accuracyDescriptor(definition),
    matchup = {
      factor = factor,
      label = matchup,
      multiplierLabel = formatMultiplier(factor),
      defenderTypes = defenderTypes,
    },
    stab = { applies = stab and true or false, label = "STAB" },
    disabled = player.disabledSlot == selected or move.disabled == true,
  }
end

return function(mod)
  mod.exports.apiVersion = API_VERSION
  mod.exports.effectiveness = effectiveness
  mod.exports.snapshot = snapshot
  mod.exports.formatMultiplier = formatMultiplier

  local registered = false
  local loggedReady = false
  local loggedErrors = {}

  local function logOnce(message)
    message = tostring(message)
    if loggedErrors[message] then return end
    loggedErrors[message] = true
    mod.log:error("Widescreen Move Inspector: %s", message)
  end

  -- Alpha.1 performed this handshake only while its entry chunk was running.
  -- Keep that fast path, but also retry at lifecycle boundaries where the
  -- loader's complete export set is guaranteed to exist. This remains a
  -- semantic-provider registration only; no battle or render hook is added.
  local function ensureRegistered(context)
    local widescreen = type(mod.find) == "function"
      and mod:find("gen1_widescreen_ui") or nil
    local exports = widescreen and widescreen.exports
    if type(exports) ~= "table"
        or exports.battleMoveInspectorApiVersion ~= API_VERSION
        or type(exports.registerBattleMoveInspector) ~= "function" then
      registered = false
      logOnce("requires Gen1 Widescreen UI 0.1.0-alpha.9 or newer with Battle Move Inspector API v1; provider unavailable at "
        .. tostring(context))
      return false
    end

    if registered and type(exports.activeBattleMoveInspectorOwner) == "function" then
      local okOwner, owner = pcall(exports.activeBattleMoveInspectorOwner)
      if okOwner and owner == OWNER then return true end
      registered = false
    elseif registered then
      return true
    end

    local ok, reason = exports.registerBattleMoveInspector({
      owner = OWNER,
      apiVersion = API_VERSION,
      snapshot = snapshot,
    })
    if not ok then
      registered = false
      logOnce("could not register provider at " .. tostring(context) .. ": "
        .. tostring(reason))
      return false
    end
    registered = true
    if not loggedReady then
      loggedReady = true
      mod.log:info("Widescreen Move Inspector provider %s at %s",
        tostring(reason), tostring(context))
    end
    return true
  end

  ensureRegistered("initialization")
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mods.loaded", function()
      ensureRegistered("mods.loaded")
    end)
    mod.events:on("battle.started", function()
      ensureRegistered("battle.started")
    end)
  end
end
