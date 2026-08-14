-- Widescreen Grid Box
-- Version 0.1.0-alpha.1
-- Semantic state for Pokemon Storage Provider API v1. This module draws nothing.

local State = {}

local tokenByRecord = setmetatable({}, { __mode = "k" })
local nextToken = 0

local function token(mon)
  local value = tokenByRecord[mon]
  if not value then
    nextToken = nextToken + 1
    value = "grid-box-mon-" .. tostring(nextToken)
    tokenByRecord[mon] = value
  end
  return value
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, tonumber(value) or low))
end

local function copyValue(value, depth, seen)
  if type(value) ~= "table" then
    if type(value) == "string" or type(value) == "number"
        or type(value) == "boolean" then return value end
    return nil
  end
  depth = depth or 0
  if depth > 5 then return {} end
  seen = seen or {}
  if seen[value] then return {} end
  seen[value] = true
  local out = {}
  for key, child in pairs(value) do
    if type(key) == "string" or type(key) == "number" then
      local copied = copyValue(child, depth + 1, seen)
      if copied ~= nil then out[key] = copied end
    end
  end
  seen[value] = nil
  return out
end

local function pokemonDef(state, mon)
  return state.game.data and state.game.data.pokemon
    and state.game.data.pokemon[mon.species] or nil
end

local function displayName(state, mon)
  local def = pokemonDef(state, mon)
  return tostring(mon.nickname or (def and def.name) or mon.species or "UNKNOWN")
end

local function presentationCopy(mon)
  local copy = copyValue(mon)
  copy.stats = nil -- Stats are calculated on a separate temporary copy below.
  return copy
end

local function calculatedCopy(state, mon)
  local copy = presentationCopy(mon)
  local def = pokemonDef(state, mon)
  local Stats = state.__deps.Stats
  if Stats and type(Stats.calc) == "function" and def
      and type(def.baseStats) == "table" then
    copy.stats = Stats.calc(def, copy.level or 1, copy.dvs or {}, copy.statExp)
    copy.hp = clamp(tonumber(copy.hp) or copy.stats.hp, 0, copy.stats.hp)
  end
  return copy
end

local function maxPP(move, definition)
  local base = definition and tonumber(definition.pp) or tonumber(move.pp) or 0
  return base + (tonumber(move.ppUps) or 0) * math.floor(base / 5)
end

local function descriptor(state, mon, slotState, enabled, reason)
  if not mon then return { empty = true, state = slotState, enabled = enabled,
    disabledReason = reason } end
  return {
    identityToken = token(mon), speciesId = tostring(mon.species),
    name = displayName(state, mon), shiny = mon.shiny == true,
    enabled = enabled, disabledReason = reason, state = slotState,
    presentation = presentationCopy(mon),
  }
end

local function detail(state, mon)
  if not mon then return nil end
  local def = pokemonDef(state, mon) or {}
  local copy = calculatedCopy(state, mon)
  local stats = copy.stats or { hp = math.max(1, tonumber(mon.hp) or 1),
    attack = 0, defense = 0, speed = 0, special = 0 }
  local moves = {}
  for index = 1, math.min(4, #(mon.moves or {})) do
    local move = mon.moves[index]
    local moveDef = state.game.data and state.game.data.moves
      and state.game.data.moves[move.id] or nil
    moves[#moves + 1] = {
      name = tostring((moveDef and moveDef.name) or move.id or "-"),
      pp = math.max(0, math.floor(tonumber(move.pp) or 0)),
      maxPp = math.max(0, math.floor(maxPP(move, moveDef))),
      type = moveDef and moveDef.type or nil,
    }
  end
  local speciesName = tostring(def.name or mon.species or "UNKNOWN")
  return {
    identityToken = token(mon), speciesId = tostring(mon.species),
    name = displayName(state, mon), speciesName = speciesName,
    nicknamed = mon.nickname ~= nil and tostring(mon.nickname) ~= speciesName,
    gender = mon.gender, level = math.max(1, math.floor(tonumber(mon.level) or 1)),
    hp = clamp(math.floor(tonumber(copy.hp) or stats.hp), 0, math.max(1, stats.hp)),
    maxHp = math.max(1, math.floor(tonumber(stats.hp) or 1)),
    status = mon.status, shiny = mon.shiny == true,
    stats = { hp = math.max(1, math.floor(tonumber(stats.hp) or 1)),
      attack = math.max(0, math.floor(tonumber(stats.attack) or 0)),
      defense = math.max(0, math.floor(tonumber(stats.defense) or 0)),
      speed = math.max(0, math.floor(tonumber(stats.speed) or 0)),
      special = math.max(0, math.floor(tonumber(stats.special) or 0)) },
    types = copyValue(def.types or { "NORMAL" }), moves = moves,
    presentation = presentationCopy(mon),
  }
end

local function box(state) return state.game.save.boxes[state.viewedBox] end
local function selectedRecord(state)
  local region = state.region == "popup" and state.previousRegion or state.region
  if region == "party" then return state.game.save.party[state.partyIndex] end
  return box(state)[state.gridIndex]
end

local function originMatches(state, kind, containerIndex, index)
  local held = state.held
  return held and held.origin.kind == kind and held.origin.index == index
    and (kind == "party" or held.origin.box == containerIndex)
end

local function targetState(state, kind, containerIndex, index, mon, count)
  if originMatches(state, kind, containerIndex, index) then return "held_origin", false end
  if not state.held then return mon and "occupied" or "empty", true end
  if mon then return "valid_swap", true end
  if index ~= count + 1 then return "invalid_target", false, "Dense storage uses only the first empty tail slot." end
  if kind == "party" and count >= state.__core.PARTY_CAPACITY then
    return "invalid_target", false, "The party is full."
  end
  if kind == "box" and count >= state.__core.BOX_CAPACITY then
    return "invalid_target", false, "The box is full."
  end
  if state.held.origin.kind == "party" and kind == "box"
      and #state.game.save.party <= 1 then
    return "invalid_target", false, "At least one Pokemon must remain in the party."
  end
  return "valid_target", true
end

local function failure(state, text)
  state.footer = tostring(text or "That move cannot be completed.")
  local TextBox = state.__deps.TextBox
  if TextBox and type(TextBox.new) == "function" then
    state.game.stack:push(TextBox.new(state.game, state.footer))
  end
  return nil, state.footer
end

local function notice(state, text)
  state.footer = tostring(text)
  local TextBox = state.__deps.TextBox
  if TextBox and type(TextBox.new) == "function" then
    state.game.stack:push(TextBox.new(state.game, state.footer))
  end
end

local function closeState(state)
  state.held = nil
  if state.game.stack and state.game.stack.top
      and state.game.stack:top() == state then state.game.stack:pop() end
  return true
end

local function partyGuard(state, mon)
  local follower = state.__deps.Follower
  if follower and type(follower.isFollowingDisabled) == "function"
      and type(follower.isStarterPikachu) == "function"
      and follower.isFollowingDisabled(state.game.overworld)
      and follower.isStarterPikachu(state.game.save, mon) then
    return nil, "There isn't any response..."
  end
  return true
end

local function transactionDeps(state)
  return {
    canLeaveParty = function(mon) return partyGuard(state, mon) end,
    ensureParty = function(mon)
      state.__deps.Stats.ensure(pokemonDef(state, mon), mon)
    end,
    afterLeaveParty = function(mon)
      state.__deps.Follower.modifyHappiness(state.game.save, "DEPOSITED", mon)
    end,
  }
end

local function perform(state, origin, destination)
  local ok, result = state.__core.transact(state.game.save, origin, destination,
    transactionDeps(state))
  if not ok then
    state.held = nil -- stale/invalid holds never survive a failed validation.
    return failure(state, result)
  end
  state.footer = result.kind == "swap" and "Pokemon switched."
    or result.kind == "transfer" and "Pokemon moved." or "No change."
  state.held = nil
  return true, result
end

local function openSummary(state, mon)
  if not mon then return false end
  local copy = calculatedCopy(state, mon)
  state.__deps.Screens.push(state.game, "SummaryMenu", copy)
  return true
end

local function popupRows(state)
  local action = state.mode == "withdraw" and "withdraw" or "deposit"
  local label = action:upper()
  local enabled, disabledReason = true, nil
  if action == "withdraw" and #state.game.save.party >= state.__core.PARTY_CAPACITY then
    enabled, disabledReason = false, "The party is full."
  elseif action == "deposit" and #state.game.save.party <= 1 then
    enabled, disabledReason = false, "At least one Pokemon must remain in the party."
  elseif action == "deposit" and #box(state) >= state.__core.BOX_CAPACITY then
    enabled, disabledReason = false, "This box is full."
  elseif action == "deposit" then
    local allowed, reason = partyGuard(state, selectedRecord(state))
    if not allowed then enabled, disabledReason = false, reason end
  end
  return {
    { id = action, label = label, enabled = enabled, disabledReason = disabledReason },
    { id = "stats", label = "STATS", enabled = true },
    { id = "exit", label = "EXIT", enabled = true },
  }
end

local function openPopup(state)
  if not selectedRecord(state) then return false end
  state.popup = { selectedIndex = 1, rows = popupRows(state) }
  state.previousRegion = state.region
  state.region = "popup"
  return true
end

local function closePopup(state)
  state.popup = nil
  state.region = state.previousRegion or (state.mode == "deposit" and "party" or "grid")
  state.previousRegion = nil
  return true
end

local function popupSelect(state)
  local row = state.popup and state.popup.rows[state.popup.selectedIndex]
  local mon = selectedRecord(state)
  if not row or not mon then return closePopup(state) end
  if row.enabled == false then return failure(state, row.disabledReason) end
  if row.id == "exit" then return closePopup(state) end
  if row.id == "stats" then return openSummary(state, mon) end
  if row.id == "withdraw" then
    local origin = { kind = "box", box = state.viewedBox,
      index = state.gridIndex, record = mon }
    local ok = perform(state, origin,
      { kind = "party", index = #state.game.save.party + 1 })
    if ok then
      closePopup(state)
      state.gridIndex = clamp(state.gridIndex, 1, math.max(1, #box(state)))
      state.game.stringBuffer = displayName(state, mon)
      if state.__deps.Sound then state.__deps.Sound.playCry(state.game.data, mon.species) end
      notice(state, displayName(state, mon) .. " was taken out.")
    end
    return ok
  end
  if row.id == "deposit" then
    local origin = { kind = "party", index = state.partyIndex, record = mon }
    local ok = perform(state, origin,
      { kind = "box", box = state.viewedBox, index = #box(state) + 1 })
    if ok then
      closePopup(state)
      state.partyIndex = clamp(state.partyIndex, 1,
        math.max(1, #state.game.save.party))
      state.game.stringBuffer = displayName(state, mon)
      state.game.boxNumString = tostring(state.viewedBox)
      if state.__deps.Sound then state.__deps.Sound.playCry(state.game.data, mon.species) end
      notice(state, displayName(state, mon) .. " was stored in Box "
        .. tostring(state.viewedBox) .. ".")
    end
    return ok
  end
  return false
end

local function pickup(state, kind, containerIndex, index, mon)
  if not mon then return false end
  state.held = { origin = { kind = kind, box = containerIndex,
      index = index, record = mon }, record = mon, identityToken = token(mon) }
  state.footer = "Choose a destination. B cancels."
  return true
end

local function selectMoveTarget(state)
  local kind = state.region == "party" and "party" or "box"
  local index = kind == "party" and state.partyIndex or state.gridIndex
  local containerIndex = kind == "box" and state.viewedBox or nil
  local values = kind == "party" and state.game.save.party or box(state)
  local mon = values[index]
  if not state.held then return pickup(state, kind, containerIndex, index, mon) end
  if originMatches(state, kind, containerIndex, index) then
    state.held = nil; state.footer = "Move cancelled."; return true
  end
  return perform(state, state.held.origin,
    { kind = kind, box = containerIndex, index = index })
end

local Actions = {}

function Actions.up(_, state)
  if state.region == "popup" then
    state.popup.selectedIndex = (state.popup.selectedIndex - 2) % #state.popup.rows + 1
  elseif state.region == "party" then
    state.partyIndex = (state.partyIndex - 2) % 6 + 1
  elseif state.region == "party_button" then
    state.region = "grid"; state.gridIndex = 16 + ((state.gridIndex - 1) % 5)
  else
    local row, col = math.floor((state.gridIndex - 1) / 5), (state.gridIndex - 1) % 5
    state.gridIndex = ((row - 1) % 4) * 5 + col + 1
  end
  return true
end

function Actions.down(_, state)
  if state.region == "popup" then
    state.popup.selectedIndex = state.popup.selectedIndex % #state.popup.rows + 1
  elseif state.region == "party" then
    state.partyIndex = state.partyIndex % 6 + 1
  elseif state.region == "party_button" then
    state.region = "grid"; state.gridIndex = 1 + ((state.gridIndex - 1) % 5)
  else
    local row, col = math.floor((state.gridIndex - 1) / 5), (state.gridIndex - 1) % 5
    if state.mode == "move" and row == 3 then state.region = "party_button"
    else state.gridIndex = ((row + 1) % 4) * 5 + col + 1 end
  end
  return true
end

function Actions.left(_, state)
  if state.region == "popup" then return false end
  if state.region == "party" then return true end
  if state.region == "party_button" then return true end
  local row, col = math.floor((state.gridIndex - 1) / 5), (state.gridIndex - 1) % 5
  state.gridIndex = row * 5 + (col - 1) % 5 + 1
  return true
end

function Actions.right(_, state)
  if state.region == "popup" then return false end
  if state.region == "party" then
    state.partyOpen = false; state.region = "grid"; return true
  end
  if state.region == "party_button" then return true end
  local row, col = math.floor((state.gridIndex - 1) / 5), (state.gridIndex - 1) % 5
  state.gridIndex = row * 5 + (col + 1) % 5 + 1
  return true
end

function Actions.previousBox(_, state)
  if state.region == "popup" then return false end
  state.viewedBox = (state.viewedBox - 2) % state.__core.BOX_COUNT + 1
  return true
end

function Actions.nextBox(_, state)
  if state.region == "popup" then return false end
  state.viewedBox = state.viewedBox % state.__core.BOX_COUNT + 1
  return true
end

function Actions.select(_, state)
  if state.region == "popup" then return popupSelect(state) end
  if state.region == "party_button" then
    state.partyOpen = true; state.region = "party"; return true
  end
  if state.mode == "move" then return selectMoveTarget(state) end
  return openPopup(state)
end

function Actions.back(_, state)
  if state.region == "popup" then return closePopup(state) end
  if state.held then state.held = nil; state.footer = "Move cancelled."; return true end
  if state.region == "party" and state.mode == "move" then
    state.partyOpen = false; state.region = "grid"; return true
  end
  if state.region == "party_button" then state.region = "grid"; return true end
  return closeState(state)
end

function Actions.selectCell(game, state, index)
  state.region = "grid"; state.gridIndex = clamp(index, 1, 20)
  return Actions.select(game, state)
end

function Actions.selectPartySlot(game, state, index)
  if state.mode ~= "deposit" and state.mode ~= "move" then return false end
  state.partyOpen = true; state.region = "party"
  state.partyIndex = clamp(index, 1, 6)
  return Actions.select(game, state)
end

function Actions.selectPopup(game, state, index)
  if not state.popup then return false end
  state.popup.selectedIndex = clamp(index, 1, #state.popup.rows)
  return Actions.select(game, state)
end

function Actions.update(_, state)
  if state.held and state.held.origin.record ~= state.held.record then
    state.held = nil; state.footer = "Held Pokemon identity became invalid."
  end
  return false
end

function State.snapshot(_, state)
  local viewed = box(state)
  local cells = {}
  for index = 1, 20 do
    local mon = viewed[index]
    local slotState, enabled, reason = targetState(state, "box", state.viewedBox,
      index, mon, #viewed)
    cells[index] = descriptor(state, mon, slotState, enabled, reason)
  end
  local slots = {}
  for index = 1, 6 do
    local mon = state.game.save.party[index]
    local slotState, enabled, reason = targetState(state, "party", nil,
      index, mon, #state.game.save.party)
    slots[index] = descriptor(state, mon, slotState, enabled, reason)
  end
  local selected = selectedRecord(state)
  local selectedRegion = state.region == "popup" and "popup"
    or state.region == "party" and "party" or "grid"
  local held = state.held and descriptor(state, state.held.record, "held", true) or nil
  local snapshot = {
    schemaVersion = 1,
    screen = state.popup and "popup" or state.mode,
    title = state.mode == "withdraw" and "WITHDRAW POKEMON"
      or state.mode == "deposit" and "DEPOSIT POKEMON" or "MOVE POKEMON",
    box = { viewedIndex = state.viewedBox,
      activeIndex = state.game.save.currentBox, occupancy = #viewed, capacity = 20,
      name = "BOX " .. string.format("%02d", state.viewedBox) },
    grid = { columns = 5, rows = 4, selectedIndex = state.gridIndex, cells = cells },
    party = { open = state.partyOpen, selectedIndex = state.partyIndex, slots = slots },
    selectedRegion = selectedRegion, held = held, detail = detail(state, selected),
    popup = state.popup and copyValue(state.popup) or nil,
    footer = state.footer, statusText = state.footer,
    hints = state.held and "A PLACE/SWAP   B CANCEL   L/R BOX"
      or state.mode == "move" and "A PICK UP   B BACK   L/R BOX   DOWN PARTY"
      or "A SELECT   B BACK   L/R BOX",
    partyButton = state.mode == "move" and {
      label = "PARTY", selected = state.region == "party_button",
      enabled = true, action = "select" } or nil,
  }
  return snapshot
end

function State.new(game, mode, deps)
  assert(mode == "withdraw" or mode == "deposit" or mode == "move",
    "invalid Grid Box mode")
  local state = deps.Menu.new(game, {
    { label = "STORAGE UNAVAILABLE", onSelect = function()
      if game.stack:top() then game.stack:pop() end
    end },
  }, { noSound = true })
  state.game = game; state.isGridBox = true; state.__gridBox = true
  state.__core = deps.Core; state.__deps = deps
  state.mode = mode; state.viewedBox = game.save.currentBox or 1
  state.region = mode == "deposit" and "party" or "grid"
  state.gridIndex = 1; state.partyIndex = 1; state.popupIndex = 1
  state.partyOpen = mode == "deposit"; state.held = nil
  state.footer = mode == "move" and "Choose a Pokemon to move."
    or mode == "deposit" and "Choose a party Pokemon."
    or "Choose a boxed Pokemon."
  return state
end

State.Actions = Actions
State.detail = detail
State.presentationCopy = presentationCopy

return State
