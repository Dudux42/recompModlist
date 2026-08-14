package.path = "../?.lua;" .. package.path

local Core = require("storage_core")
local State = require("grid_state")

local function mon(id, opts)
  opts = opts or {}
  return { species = id, nickname = opts.nickname, level = opts.level or 12,
    hp = opts.hp or 20, dvs = {}, statExp = {}, stats = opts.stats,
    status = opts.status, shiny = opts.shiny,
    moves = opts.moves or { { id = "TACKLE", pp = 20 } } }
end

local function makeGame(partyCount)
  local save = { party = {}, boxes = {}, currentBox = 1,
    player = { id = 7, name = "RED" }, pikachuHappiness = 90 }
  for index = 1, partyCount do save.party[index] = mon("P" .. index, { stats = {
    hp = 20, attack = 10, defense = 10, speed = 10, special = 10 } }) end
  for index = 1, 12 do save.boxes[index] = {} end
  local stack = { states = {} }
  function stack:push(value) self.states[#self.states + 1] = value end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  local pokemon = {}
  for index = 1, 20 do pokemon["P" .. index] = {
    name = "PARTY " .. index, types = { "NORMAL" },
    baseStats = { hp = 40, attack = 40, defense = 40, speed = 40, special = 40 } }
  end
  for _, id in ipairs({ "A", "B", "C", "PIKACHU" }) do pokemon[id] = {
    name = id, types = { "NORMAL" },
    baseStats = { hp = 40, attack = 40, defense = 40, speed = 40, special = 40 } }
  end
  return { save = save, stack = stack, data = { pokemon = pokemon,
    moves = {
      TACKLE = { name = "TACKLE", pp = 35, type = "NORMAL" },
      GROWL = { name = "GROWL", pp = 40, type = "NORMAL" },
      SURF = { name = "SURF", pp = 15, type = "WATER" },
      REST = { name = "REST", pp = 10, type = "PSYCHIC_TYPE" },
    } },
    overworld = {} }
end

local summaryCopies, cries, happiness, ensures = {}, 0, 0, 0
local deps = {
  Core = Core,
  Menu = { new = function(game) return { game = game } end },
  Stats = { calc = function()
    return { hp = 30, attack = 11, defense = 12, speed = 13, special = 14 }
  end, ensure = function(def, value)
    ensures = ensures + 1
    if value.stats == nil then value.stats = {
      hp = 30, attack = 11, defense = 12, speed = 13, special = 14 }
      value.hp = math.min(value.hp or 30, value.stats.hp)
    end
    return value
  end },
  Follower = {
    isFollowingDisabled = function(game) return game.blockStarter == true end,
    isStarterPikachu = function(_, value) return value.species == "PIKACHU" end,
    modifyHappiness = function(_, reason, value)
      assert(reason == "DEPOSITED" and value)
      happiness = happiness + 1
    end,
  },
  Screens = { push = function(_, id, value)
    assert(id == "SummaryMenu"); summaryCopies[#summaryCopies + 1] = value
  end },
  Sound = { playCry = function() cries = cries + 1 end },
}

do
  local game = makeGame(2); local boxed = mon("A"); game.save.boxes[1][1] = boxed
  local state = State.new(game, "withdraw", deps); game.stack:push(state)
  local snapshot = State.snapshot(game, state)
  assert(#snapshot.grid.cells == 20 and #snapshot.party.slots == 6)
  assert(snapshot.box.activeIndex == 1 and snapshot.box.viewedIndex == 1)
  assert(snapshot.detail.stats.hp == 30 and boxed.stats == nil,
    "highlight must calculate a copy without caching boxed stats")
  assert(ensures == 0, "highlight must not call native Stats.ensure")
  State.Actions.select(game, state)
  assert(state.region == "popup" and #state.popup.rows == 3)
  State.Actions.down(game, state); State.Actions.select(game, state)
  assert(summaryCopies[#summaryCopies] ~= boxed and summaryCopies[#summaryCopies].stats,
    "Summary must receive a calculated presentation copy")
  assert(state.region == "popup" and state.gridIndex == 1,
    "Summary round trip state was not preserved")
  State.Actions.up(game, state); State.Actions.select(game, state)
  assert(#game.save.party == 3 and #game.save.boxes[1] == 0 and boxed.stats,
    "withdraw did not atomically enter the party")
  assert(ensures == 1, "withdraw must call native Stats.ensure exactly once")
  assert(cries == 1, "withdraw cry was not played exactly once")
end

do
  local game = makeGame(2); game.save.boxes[1][1] = mon("A")
  local state = State.new(game, "move", deps); game.stack:push(state)
  State.Actions.select(game, state)
  assert(state.held and game.save.boxes[1][1].species == "A",
    "pickup mutated storage")
  State.Actions.nextBox(game, state)
  assert(state.viewedBox == 2 and game.save.currentBox == 1 and state.held,
    "box browsing changed active box or lost held Pokemon")
  State.Actions.back(game, state)
  assert(not state.held and game.save.boxes[1][1].species == "A",
    "B cancellation changed storage")
  for _ = 1, 11 do State.Actions.nextBox(game, state) end
  assert(state.viewedBox == 1 and game.save.currentBox == 1,
    "all-12-box browsing did not wrap without changing the active box")
end

do
  local game = makeGame(1); game.save.boxes[1][1] = mon("A")
  local state = State.new(game, "move", deps); game.stack:push(state)
  State.Actions.down(game, state); State.Actions.down(game, state)
  State.Actions.down(game, state); State.Actions.down(game, state)
  assert(state.region == "party_button", "bottom-row Down did not reach PARTY")
  State.Actions.select(game, state)
  assert(state.region == "party" and state.partyOpen, "PARTY drawer did not open")
  State.Actions.select(game, state)
  assert(state.held and state.held.origin.kind == "party", "party pickup failed")
  State.Actions.right(game, state)
  assert(state.region == "grid" and state.held, "Right did not retain held party Pokemon")
  state.gridIndex = 1
  State.Actions.select(game, state)
  assert(game.save.party[1].species == "A" and game.save.boxes[1][1].species == "P1",
    "one-member party/box swap failed")
end

do
  local game = makeGame(2); game.save.party[2] = mon("PIKACHU")
  game.overworld.blockStarter = true
  local state = State.new(game, "deposit", deps); game.stack:push(state)
  state.partyIndex = 2
  State.Actions.select(game, state); State.Actions.select(game, state)
  assert(#game.save.party == 2 and #game.save.boxes[1] == 0,
    "Yellow sleeping starter guard failed")
  game.overworld.blockStarter = false
  State.Actions.back(game, state); State.Actions.select(game, state)
  State.Actions.select(game, state)
  assert(#game.save.party == 1 and #game.save.boxes[1] == 1,
    "deposit failed after Yellow guard cleared")
  assert(happiness == 2, "successful party departures did not apply exactly once")
end

do
  local game = makeGame(2); local state = State.new(game, "move", deps)
  local snapshot = State.snapshot(game, state)
  assert(snapshot.partyButton and snapshot.partyButton.label == "PARTY")
  assert(snapshot.grid.cells[1].state == "empty",
    "semantic slot state was not exported")
end

do
  local game = makeGame(6)
  local featured = mon("A", { nickname = "A VERY LONG NICKNAME", shiny = true,
    status = "PAR", moves = {
      { id = "TACKLE", pp = 21 }, { id = "GROWL", pp = 17 },
      { id = "SURF", pp = 9 }, { id = "REST", pp = 4 },
    } })
  game.save.boxes[1][1] = featured
  for index = 2, 20 do game.save.boxes[1][index] = mon("B") end
  local state = State.new(game, "withdraw", deps)
  local snapshot = State.snapshot(game, state)
  assert(snapshot.box.occupancy == 20 and snapshot.detail.shiny == true
    and snapshot.detail.status == "PAR" and #snapshot.detail.moves == 4,
    "full-box long/shiny/status/four-move detail snapshot failed")
  State.Actions.select(game, state)
  assert(state.popup.rows[1].enabled == false
    and state.popup.rows[1].disabledReason == "The party is full.",
    "full-party Withdraw popup did not export a disabled reason")
  local before = Core.total(game.save)
  State.Actions.back(game, state)
  assert(Core.total(game.save) == before and not state.popup,
    "popup B cancellation mutated storage")
end

print("grid_state_test: snapshots, navigation and workflows passed")
