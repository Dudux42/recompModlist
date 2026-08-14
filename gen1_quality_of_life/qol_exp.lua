local M = {}

local function livingParty(battle)
  local out = {}
  local party = battle and battle.game and battle.game.save and battle.game.save.party or {}
  for _, mon in ipairs(party) do
    if (tonumber(mon.hp) or 0) > 0 then out[#out + 1] = mon end
  end
  return out
end

-- Participants retain the engine's normal full-pool split. Every other
-- living party member receives an independent half share (split = 2).
local function recipientPlan(ctx)
  local plan, participantSet = {}, {}
  local participants = ctx and ctx.alive or {}
  local participantSplit = math.max(1, #participants)
  for _, mon in ipairs(participants) do
    participantSet[mon] = true
    plan[#plan + 1] = {
      mon = mon, split = participantSplit, shared = false, announce = true,
    }
  end
  for _, mon in ipairs(livingParty(ctx and ctx.battle)) do
    if not participantSet[mon] then
      plan[#plan + 1] = { mon = mon, split = 2, shared = true, announce = false }
    end
  end
  return plan
end

function M.install(mod, options)
  local Strings = require("src.core.Strings")

  mod.hooks:wrap("battle.exp_award", function(next, ctx)
    local game = ctx and ctx.battle and ctx.battle.game
    if not options.value(game, "expShare") then return next(ctx) end
    if not ctx or type(ctx.applyShare) ~= "function" then return next(ctx) end

    local plan = recipientPlan(ctx)
    local firstShared
    for i, award in ipairs(plan) do
      if award.shared then firstShared = firstShared or i
      else ctx.applyShare(award.mon, award.split, true) end
    end
    if firstShared then
      -- One summary replaces every bench Pokemon's individual "gained EXP"
      -- line. applyShare still owns stat EXP, level-ups, moves and evolution.
      if ctx.battle and type(ctx.battle.sayNext) == "function" then
        ctx.battle:sayNext(Strings("Remaining POKEMON\nreceived EXP!"))
      end
      for i = firstShared, #plan do
        local award = plan[i]
        if award.shared then ctx.applyShare(award.mon, award.split, false) end
      end
    end
  end, 100)

  mod.exports.expRecipientPlan = recipientPlan
end

return M
