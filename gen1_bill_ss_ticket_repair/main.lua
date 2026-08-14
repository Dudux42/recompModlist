-- Bill's S.S. Ticket save repair for Gen1Recomp 0.1.78+.
--
-- Red, Blue and Yellow dispatch the same BILLS_HOUSE map script. Yellow only
-- adds Pikachu staging around the machine, so repairing the shared event
-- state is both safer and more accurate than replacing Bill's dialogue.

return function(mod)
  -- Echoes Beyond the Fog 2.2.0 delegates its non-quest Bill conversation
  -- through fog:base_bill_chat.  Its command assumes MapScripts.baseTalk is
  -- always a callback, but Bill's ticket handler is an engine script row list.
  -- Intercept only that incompatible table-shaped case.  Function-shaped
  -- handlers and every other command continue through the original chain, so
  -- Echoes retains ownership of all of its quest branches.
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("script.command", function(next, ctx, name, args)
      if name ~= "fog:base_bill_chat" then
        return next(ctx, name, args)
      end

      local talkId = args and args[1]
        or "TEXT_BILLSHOUSE_BILL_CHECK_OUT_MY_RARE_POKEMON"
      local base = require("src.script.MapScripts")
        .baseTalk("BILLS_HOUSE", talkId)
      if type(base) ~= "table" then
        return next(ctx, name, args)
      end

      local runner = ctx and ctx.runner
      if not (runner and type(runner.exec) == "function") then
        mod.log:warn("could not run Echoes' table-shaped Bill fallback: ScriptRunner.exec is unavailable")
        return next(ctx, name, args)
      end
      runner:exec(base, ctx)
      mod.log:info("ran Echoes' table-shaped vanilla Bill fallback")
    end, 200)
  end

  local function onEnter(game, ow)
    local save = game and game.save
    local flags = save and save.flags
    if not (flags and ow and ow.map and ow.map.id == "BILLS_HOUSE") then
      return
    end

    -- Older/interrupted saves can record that the machine ran (or even that
    -- the reward was claimed) without completing Bill's exit callback. That
    -- leaves the monster hidden while human Bill's ticket dialogue is never
    -- armed. Reconstruct precisely the post-machine state.
    local machineRan = flags.EVENT_USED_CELL_SEPARATOR_ON_BILL
      or flags.EVENT_GOT_SS_TICKET
    if machineRan and not flags.EVENT_MET_BILL_2 then
      local Commands = require("src.script.Commands")
      local ctx = { game = game, save = save, overworld = ow }
      Commands.hide_object(ctx, "BILLS_HOUSE", "BILLSHOUSE_BILL_POKEMON")
      Commands.show_object(ctx, "BILLS_HOUSE", "BILLSHOUSE_BILL1")
      flags.EVENT_BILL_SAID_USE_CELL_SEPARATOR = true
      flags.EVENT_USED_CELL_SEPARATOR_ON_BILL = true
      flags.EVENT_MET_BILL = true
      flags.EVENT_MET_BILL_2 = true
      mod.log:info("repaired Bill's interrupted cell-separator state")
    end

    -- A few legacy saves carry the received flag but neither the Bag nor the
    -- item PC contains the ticket. Do not duplicate a legitimately deposited
    -- ticket, and do not resurrect it after the S.S. Anne has departed.
    local inventory = save.inventory or {}
    local pcItems = save.pcItems or {}
    if flags.EVENT_GOT_SS_TICKET and not flags.EVENT_SS_ANNE_LEFT
        and (inventory.S_S_TICKET or 0) < 1
        and (pcItems.S_S_TICKET or 0) < 1 then
      save.inventory = inventory
      local added = require("src.inventory.Bag")
        .add(save, "S_S_TICKET", 1, game.data)
      if added then
        mod.log:info("restored missing S.S. Ticket from completed Bill event")
      else
        mod.log:warn("Bill event is complete but the S.S. Ticket could not be restored; make room in the Key Items pocket")
      end
    end
  end

  mod.content.map_scripts:register("BILLS_HOUSE", {
    onEnter = onEnter,
    priority = 100,
  })

  mod.exports.version = "0.1.1"
  mod.exports.repairScope = "red_blue_yellow_shared_bill_event"
  mod.exports.echoesBillFallbackCompat = true
end
