local registered
local scriptCommandHook
local logs = {}

local baseTalkValue
package.preload["src.script.MapScripts"] = function()
  return {
    baseTalk = function(mapId, talkId)
      assert(mapId == "BILLS_HOUSE")
      assert(type(talkId) == "string")
      return baseTalkValue
    end,
  }
end

package.preload["src.script.Commands"] = function()
  return {
    hide_object = function(ctx, mapId, name)
      ctx.save.objectToggles = ctx.save.objectToggles or {}
      ctx.save.objectToggles[mapId] = ctx.save.objectToggles[mapId] or {}
      ctx.save.objectToggles[mapId][name] = false
    end,
    show_object = function(ctx, mapId, name)
      ctx.save.objectToggles = ctx.save.objectToggles or {}
      ctx.save.objectToggles[mapId] = ctx.save.objectToggles[mapId] or {}
      ctx.save.objectToggles[mapId][name] = true
    end,
  }
end

package.preload["src.inventory.Bag"] = function()
  return {
    add = function(save, id, qty)
      save.inventory[id] = (save.inventory[id] or 0) + qty
      return true
    end,
  }
end

local mod = {
  content = { map_scripts = {
    register = function(_, mapId, contribution)
      assert(mapId == "BILLS_HOUSE")
      registered = contribution
    end,
  } },
  exports = {},
  hooks = {
    wrap = function(_, name, callback, priority)
      assert(name == "script.command")
      assert(priority == 200)
      scriptCommandHook = callback
    end,
  },
  log = {
    info = function(_, message) logs[#logs + 1] = message end,
    warn = function(_, message) logs[#logs + 1] = message end,
  },
}

local installer = assert(loadfile("gen1_bill_ss_ticket_repair/main.lua"))()
installer(mod)
assert(registered and type(registered.onEnter) == "function")
assert(type(scriptCommandHook) == "function")

-- Echoes Beyond the Fog 2.2.0 calls a table-shaped vanilla Bill handler as
-- though it were a function.  The compatibility hook must execute that row
-- list through the current runner and must not call the broken command.
baseTalkValue = {
  { "give_item", "S_S_TICKET", 1 },
  { "set_flag", "EVENT_GOT_SS_TICKET" },
}
local compatSave = { inventory = {}, flags = {} }
local downstreamCalls = 0
local compatCtx = { save = compatSave }
compatCtx.runner = {
  exec = function(_, rows, ctx)
    assert(rows == baseTalkValue)
    assert(ctx == compatCtx)
    for _, row in ipairs(rows) do
      if row[1] == "give_item" then
        ctx.save.inventory[row[2]] = (ctx.save.inventory[row[2]] or 0) + row[3]
      elseif row[1] == "set_flag" then
        ctx.save.flags[row[2]] = true
      end
    end
  end,
}
scriptCommandHook(function()
  downstreamCalls = downstreamCalls + 1
end, compatCtx, "fog:base_bill_chat",
  { "TEXT_BILLSHOUSE_BILL_SS_TICKET" })
assert(downstreamCalls == 0,
  "table-shaped Echoes fallback reached its broken original command")
assert(compatSave.inventory.S_S_TICKET == 1
    and compatSave.flags.EVENT_GOT_SS_TICKET,
  "table-shaped vanilla Bill rows were not executed")

-- Echoes' original command correctly supports function-shaped base handlers;
-- those and all unrelated commands must remain untouched.
baseTalkValue = function() end
scriptCommandHook(function()
  downstreamCalls = downstreamCalls + 1
end, compatCtx, "fog:base_bill_chat",
  { "TEXT_BILLSHOUSE_BILL_CHECK_OUT_MY_RARE_POKEMON" })
scriptCommandHook(function()
  downstreamCalls = downstreamCalls + 1
end, compatCtx, "show_text", { "hello" })
assert(downstreamCalls == 2,
  "function-shaped or unrelated commands did not pass through")

local function game(flags, inventory, pcItems)
  return { save = {
    flags = flags or {}, inventory = inventory or {}, pcItems = pcItems or {},
  }, data = { items = { S_S_TICKET = { pocket = "KEY_ITEM" } } } }
end
local ow = { map = { id = "BILLS_HOUSE" } }

-- This shared state is identical for Red, Blue and Yellow; there is no
-- version branch in the repair.
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local g = game({ EVENT_USED_CELL_SEPARATOR_ON_BILL = true })
  g.version = version
  registered.onEnter(g, ow)
  assert(g.save.flags.EVENT_MET_BILL and g.save.flags.EVENT_MET_BILL_2)
  assert(g.save.objectToggles.BILLS_HOUSE.BILLSHOUSE_BILL_POKEMON == false)
  assert(g.save.objectToggles.BILLS_HOUSE.BILLSHOUSE_BILL1 == true)
end

local completed = game({ EVENT_GOT_SS_TICKET = true })
registered.onEnter(completed, ow)
assert(completed.save.inventory.S_S_TICKET == 1,
  "missing completed-event ticket was not restored")

local deposited = game({ EVENT_GOT_SS_TICKET = true }, {}, { S_S_TICKET = 1 })
registered.onEnter(deposited, ow)
assert(deposited.save.inventory.S_S_TICKET == nil,
  "ticket already in item PC was duplicated")

local departed = game({ EVENT_GOT_SS_TICKET = true,
                        EVENT_SS_ANNE_LEFT = true })
registered.onEnter(departed, ow)
assert(departed.save.inventory.S_S_TICKET == nil,
  "ticket was incorrectly resurrected after the ship departed")

local untouched = game({})
registered.onEnter(untouched, ow)
assert(not untouched.save.flags.EVENT_MET_BILL_2,
  "unstarted Bill quest was modified")

print("bill_repair_test: OK")
