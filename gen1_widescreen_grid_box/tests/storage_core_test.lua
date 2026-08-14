package.path = "../?.lua;" .. package.path

local Core = require("storage_core")

local function mon(id) return { species = id, hp = 10 } end
local function saveWith(partyCount)
  local save = { party = {}, boxes = {}, currentBox = 1,
    pikachuHappiness = 90, pikachuMood = 128 }
  for i = 1, partyCount do save.party[i] = mon("PARTY_" .. i) end
  for i = 1, 12 do save.boxes[i] = {} end
  return save
end
local function expect(value, message) assert(value, message) end
local function ids(array)
  local out = {}; for _, value in ipairs(array) do out[#out + 1] = value.species end
  return table.concat(out, ",")
end
local function identitySet(save)
  local set = {}
  for _, value in ipairs(save.party) do set[value] = (set[value] or 0) + 1 end
  for _, box in ipairs(save.boxes) do
    for _, value in ipairs(box) do set[value] = (set[value] or 0) + 1 end
  end
  return set
end
local function sameIdentitySet(left, right)
  for value, count in pairs(left) do if right[value] ~= count then return false end end
  for value, count in pairs(right) do if left[value] ~= count then return false end end
  return true
end

for _, count in ipairs({ 0, 1, 19, 20 }) do
  local save = saveWith(1)
  for index = 1, count do save.boxes[12][index] = mon("BOX_" .. index) end
  expect(Core.validate(save), "valid box occupancy " .. count .. " was rejected")
end

for _, partyCount in ipairs({ 1, 5, 6 }) do
  local save = saveWith(partyCount); local boxed = mon("WITHDRAW")
  save.boxes[1][1] = boxed
  local before = identitySet(save)
  local ok = Core.transact(save, { kind = "box", box = 1, index = 1, record = boxed },
    { kind = "party", index = partyCount + 1 }, { ensureParty = function() end })
  expect((not not ok) == (partyCount < 6), "withdraw party-size boundary failed at " .. partyCount)
  expect(sameIdentitySet(before, identitySet(save)), "withdraw changed Pokemon multiset")
end

for _, partyCount in ipairs({ 1, 2, 6 }) do
  for _, boxCount in ipairs({ 19, 20 }) do
    local save = saveWith(partyCount)
    for index = 1, boxCount do save.boxes[1][index] = mon("D" .. index) end
    local leaving = save.party[partyCount]
    local before = identitySet(save)
    local ok = Core.transact(save,
      { kind = "party", index = partyCount, record = leaving },
      { kind = "box", box = 1, index = boxCount + 1 }, {
        canLeaveParty = function() return true end,
        afterLeaveParty = function() end,
      })
    expect((not not ok) == (partyCount > 1 and boxCount < 20),
      "deposit boundary failed for party/box " .. partyCount .. "/" .. boxCount)
    expect(sameIdentitySet(before, identitySet(save)), "deposit changed Pokemon multiset")
  end
end

do
  local save = saveWith(2); local boxed = mon("BOXED"); save.boxes[1][1] = boxed
  local ensured = 0
  local ok, result = Core.transact(save,
    { kind = "box", box = 1, index = 1, record = boxed },
    { kind = "party", index = 3 },
    { ensureParty = function(value) ensured = ensured + 1; value.stats = { hp = 10 } end })
  expect(ok and result.kind == "transfer", "box-to-party transfer failed")
  expect(#save.party == 3 and #save.boxes[1] == 0 and ensured == 1,
    "box-to-party postconditions failed")
end

do
  local save = saveWith(2); local a = mon("A"); save.boxes[1][1] = a
  local impostor = mon("A")
  local before = identitySet(save)
  local ok = Core.transact(save,
    { kind = "box", box = 1, index = 1, record = impostor },
    { kind = "box", box = 2, index = 1 })
  expect(not ok and sameIdentitySet(before, identitySet(save)),
    "stale record identity was accepted")
end

do
  local save = saveWith(2); save.currentBox = 7
  local moving = mon("A"); save.boxes[12][1] = moving
  local ok = Core.transact(save,
    { kind = "box", box = 12, index = 1, record = moving },
    { kind = "box", box = 2, index = 1 })
  expect(ok and save.currentBox == 7, "storage transaction changed active box")
end

do
  local save = saveWith(2); local leaving = save.party[2]
  local happiness = 0
  local ok = Core.transact(save,
    { kind = "party", index = 2, record = leaving },
    { kind = "box", box = 1, index = 1 }, {
      canLeaveParty = function() return true end,
      afterLeaveParty = function() happiness = happiness + 1 end,
    })
  expect(ok and #save.party == 1 and save.boxes[1][1] == leaving,
    "party-to-box transfer failed")
  expect(happiness == 1, "deposited happiness must run exactly once")
end

do
  local save = saveWith(1); local only = save.party[1]
  local before = ids(save.party)
  local ok = Core.transact(save, { kind = "party", index = 1, record = only },
    { kind = "box", box = 1, index = 1 })
  expect(not ok and ids(save.party) == before and #save.boxes[1] == 0,
    "last-party transfer was not rejected atomically")
end

do
  local save = saveWith(1); local only = save.party[1]; local boxed = mon("BOXED")
  save.boxes[1][1] = boxed; local ensured, deposited = 0, 0
  local ok, result = Core.transact(save,
    { kind = "party", index = 1, record = only },
    { kind = "box", box = 1, index = 1 }, {
      canLeaveParty = function() return true end,
      ensureParty = function(value) ensured = ensured + 1; value.stats = { hp = 10 } end,
      afterLeaveParty = function() deposited = deposited + 1 end,
    })
  expect(ok and result.kind == "swap" and save.party[1] == boxed
    and save.boxes[1][1] == only, "one-member party swap failed")
  expect(ensured == 1 and deposited == 1, "swap callbacks were not exact")
end

do
  local save = saveWith(2); local a, b, c = mon("A"), mon("B"), mon("C")
  save.boxes[1] = { a, b, c }
  local ok = Core.transact(save, { kind = "box", box = 1, index = 1, record = a },
    { kind = "box", box = 1, index = 4 })
  expect(ok and ids(save.boxes[1]) == "B,C,A", "same-box tail reorder failed")
  local before = ids(save.boxes[1])
  ok = Core.transact(save, { kind = "box", box = 1, index = 1,
      record = save.boxes[1][1] }, { kind = "box", box = 1, index = 5 })
  expect(not ok and ids(save.boxes[1]) == before, "later dense tail slot was accepted")
end

do
  local save = saveWith(2); local a, b = mon("A"), mon("B")
  save.boxes[1][1], save.boxes[2][1] = a, b
  local ok = Core.transact(save, { kind = "box", box = 1, index = 1, record = a },
    { kind = "box", box = 2, index = 1 })
  expect(ok and save.boxes[1][1] == b and save.boxes[2][1] == a,
    "cross-box swap failed")
end

do
  local save = saveWith(2); local leaving = save.party[2]
  local beforeParty = ids(save.party)
  local ok = Core.transact(save, { kind = "party", index = 2, record = leaving },
    { kind = "box", box = 1, index = 1 }, {
      canLeaveParty = function() return nil, "sleeping Pikachu" end,
    })
  expect(not ok and ids(save.party) == beforeParty and #save.boxes[1] == 0,
    "Yellow guard rejection mutated storage")
end

do
  local save = saveWith(2); local boxed = mon("BOXED"); save.boxes[1][1] = boxed
  local beforeParty, beforeBox = ids(save.party), ids(save.boxes[1])
  local ok = Core.transact(save,
    { kind = "box", box = 1, index = 1, record = boxed },
    { kind = "party", index = 3 }, {
      ensureParty = function(value) value.stats = { hp = 99 }; error("ensure failed") end,
    })
  expect(not ok and ids(save.party) == beforeParty and ids(save.boxes[1]) == beforeBox,
    "callback error did not roll storage back")
  expect(boxed.stats == nil, "callback error did not roll Pokemon fields back")
end

do
  local save = saveWith(6); for i = 1, 20 do save.boxes[1][i] = mon("B" .. i) end
  local before = Core.total(save)
  local ok = Core.transact(save, { kind = "box", box = 1, index = 1,
      record = save.boxes[1][1] }, { kind = "party", index = 7 })
  expect(not ok and Core.total(save) == before, "full-party rejection failed")
  ok = Core.transact(save, { kind = "box", box = 1, index = 1,
      record = save.boxes[1][1] }, { kind = "box", box = 2, index = 1 })
  expect(ok and #save.boxes[1] == 19 and #save.boxes[2] == 1,
    "full source box transfer failed")
end

print("storage_core_test: all transaction invariants passed")
