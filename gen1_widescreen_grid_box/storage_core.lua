-- Widescreen Grid Box
-- Version 0.1.0-alpha.1
-- Pure validate-then-commit operations for Gen 1 dense PC storage.

local Core = {}

Core.BOX_COUNT = 12
Core.BOX_CAPACITY = 20
Core.PARTY_CAPACITY = 6

local function integer(value, minimum, maximum)
  return type(value) == "number" and value == value and value % 1 == 0
    and value >= minimum and value <= maximum
end

local function copyArray(source)
  local out = {}
  for index, value in ipairs(source or {}) do out[index] = value end
  return out
end

local function replaceArray(target, source)
  for index = #target, 1, -1 do target[index] = nil end
  for index, value in ipairs(source) do target[index] = value end
end

local function dense(array)
  if type(array) ~= "table" then return false end
  local count = 0
  for key in pairs(array) do
    if type(key) == "number" then
      if not integer(key, 1, math.huge) then return false end
      count = count + 1
    end
  end
  return count == #array
end

local function boxes(save)
  return type(save) == "table" and type(save.boxes) == "table" and save.boxes
end

function Core.validate(save)
  local all = boxes(save)
  if not all or #all ~= Core.BOX_COUNT then
    return nil, "storage requires exactly 12 boxes"
  end
  if not dense(save.party) or #save.party < 1 or #save.party > Core.PARTY_CAPACITY then
    return nil, "party must be dense and contain 1..6 Pokemon"
  end
  if not integer(save.currentBox or 1, 1, Core.BOX_COUNT) then
    return nil, "current box must be in 1..12"
  end
  for index = 1, Core.BOX_COUNT do
    local box = all[index]
    if not dense(box) or #box > Core.BOX_CAPACITY then
      return nil, "box " .. tostring(index) .. " must be dense and contain 0..20 Pokemon"
    end
  end
  return true
end

local function container(save, descriptor)
  if type(descriptor) ~= "table" then return nil, "container descriptor is required" end
  if descriptor.kind == "party" then return save.party, "party" end
  if descriptor.kind == "box" and integer(descriptor.box, 1, Core.BOX_COUNT) then
    return save.boxes[descriptor.box], "box " .. tostring(descriptor.box)
  end
  return nil, "container must identify party or box 1..12"
end

local function sameContainer(a, b)
  return a.kind == b.kind and (a.kind == "party" or a.box == b.box)
end

local function snapshotRecord(mon)
  return { mon = mon, stats = mon and mon.stats, hp = mon and mon.hp }
end

local function restoreRecord(snapshot)
  if snapshot.mon then
    snapshot.mon.stats = snapshot.stats
    snapshot.mon.hp = snapshot.hp
  end
end

local function uniqueRecords(save)
  local result, seen = {}, {}
  local function add(mon)
    if seen[mon] then return nil, "the same Pokemon record appears more than once" end
    seen[mon] = true
    result[#result + 1] = mon
    return true
  end
  for _, mon in ipairs(save.party) do
    local ok, reason = add(mon); if not ok then return nil, reason end
  end
  for _, box in ipairs(save.boxes) do
    for _, mon in ipairs(box) do
      local ok, reason = add(mon); if not ok then return nil, reason end
    end
  end
  return result
end

function Core.total(save)
  local total = type(save.party) == "table" and #save.party or 0
  for _, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
    total = total + #box
  end
  return total
end

-- Move or swap a live record. No mutation occurs until all descriptors,
-- capacities, identities and party/Yellow rules have passed validation.
-- deps may provide:
--   canLeaveParty(mon) -> true | nil, reason
--   ensureParty(mon)    -- native Stats.ensure boundary
--   afterLeaveParty(mon)-- native Yellow DEPOSITED happiness boundary
function Core.transact(save, origin, destination, deps)
  deps = deps or {}
  local valid, reason = Core.validate(save)
  if not valid then return nil, reason end
  local beforeTotal = Core.total(save)
  local recordsBefore, duplicateReason = uniqueRecords(save)
  if not recordsBefore then return nil, duplicateReason end

  local source, sourceName = container(save, origin)
  if not source then return nil, sourceName end
  local target, targetName = container(save, destination)
  if not target then return nil, targetName end
  if not integer(origin.index, 1, #source) then
    return nil, sourceName .. " source index is stale"
  end
  local moving = source[origin.index]
  if origin.record ~= nil and origin.record ~= moving then
    return nil, "source Pokemon identity changed while it was held"
  end

  local same = sameContainer(origin, destination)
  local targetCount = #target
  if not integer(destination.index, 1, targetCount + 1) then
    return nil, targetName .. " destination must be occupied or the first empty tail slot"
  end
  local replacing = destination.index <= targetCount and target[destination.index] or nil
  if same and destination.index == origin.index then
    return true, { kind = "unchanged", moving = moving }
  end
  if not replacing then
    local limit = destination.kind == "party" and Core.PARTY_CAPACITY or Core.BOX_CAPACITY
    if #target >= limit and not same then return nil, targetName .. " is full" end
  end

  local partyAfter = #save.party
  if origin.kind == "party" and destination.kind ~= "party" and not replacing then
    partyAfter = partyAfter - 1
  elseif origin.kind ~= "party" and destination.kind == "party" and not replacing then
    partyAfter = partyAfter + 1
  end
  if partyAfter < 1 or partyAfter > Core.PARTY_CAPACITY then
    return nil, partyAfter < 1 and "at least one Pokemon must remain in the party"
      or "the party is full"
  end

  local leavingParty
  if origin.kind == "party" and destination.kind ~= "party" then
    leavingParty = moving
  end
  if leavingParty and type(deps.canLeaveParty) == "function" then
    local ok, allowed, why = pcall(deps.canLeaveParty, leavingParty)
    if not ok then return nil, "party departure validation failed: " .. tostring(allowed) end
    if allowed ~= true then return nil, why or "that Pokemon cannot be deposited" end
  end

  local sourceBefore = copyArray(source)
  local targetBefore = same and nil or copyArray(target)
  local sourceResult, targetResult
  if same then
    sourceResult = copyArray(sourceBefore)
    if replacing then
      sourceResult[origin.index], sourceResult[destination.index] =
        sourceResult[destination.index], sourceResult[origin.index]
    else
      table.remove(sourceResult, origin.index)
      sourceResult[#sourceResult + 1] = moving
    end
  else
    sourceResult, targetResult = copyArray(sourceBefore), copyArray(targetBefore)
    if replacing then
      sourceResult[origin.index] = replacing
      targetResult[destination.index] = moving
    else
      table.remove(sourceResult, origin.index)
      targetResult[#targetResult + 1] = moving
    end
  end

  local enteringParty
  if origin.kind == "box" and destination.kind == "party" then enteringParty = moving end
  if destination.kind == "box" and origin.kind == "party" and replacing then
    enteringParty = replacing
  end
  local movingSnapshot = snapshotRecord(moving)
  local replacingSnapshot = snapshotRecord(replacing)
  local happiness = save.pikachuHappiness
  local mood = save.pikachuMood
  local emotion = save.pikachuEmotionModifier

  if same then replaceArray(source, sourceResult)
  else replaceArray(source, sourceResult); replaceArray(target, targetResult) end

  local postOk, postError = pcall(function()
    if enteringParty and type(deps.ensureParty) == "function" then
      deps.ensureParty(enteringParty)
    end
    if leavingParty and type(deps.afterLeaveParty) == "function" then
      deps.afterLeaveParty(leavingParty)
    end
  end)
  local afterValid, afterReason = Core.validate(save)
  local recordsAfter, afterDuplicate = uniqueRecords(save)
  if not postOk or not afterValid or not recordsAfter or Core.total(save) ~= beforeTotal then
    replaceArray(source, sourceBefore)
    if not same then replaceArray(target, targetBefore) end
    restoreRecord(movingSnapshot); restoreRecord(replacingSnapshot)
    save.pikachuHappiness, save.pikachuMood, save.pikachuEmotionModifier =
      happiness, mood, emotion
    return nil, not postOk and ("transaction callback failed: " .. tostring(postError))
      or afterReason or afterDuplicate or "transaction changed the Pokemon total"
  end

  return true, {
    kind = replacing and "swap" or "transfer",
    moving = moving,
    replaced = replacing,
    source = { kind = origin.kind, box = origin.box, index = origin.index },
    destination = { kind = destination.kind, box = destination.box,
      index = destination.index },
  }
end

return Core
