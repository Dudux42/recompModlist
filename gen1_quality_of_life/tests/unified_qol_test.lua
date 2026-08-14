package.path = "gen1_quality_of_life/?.lua;" .. package.path

local function expect(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

for _, file in ipairs({
  "main.lua", "qol_options.lua", "qol_overlay.lua", "qol_catch.lua",
  "qol_exp.lua", "qol_locations.lua", "qol_hm_tm.lua", "qol_field.lua",
}) do
  local chunk, err = loadfile("gen1_quality_of_life/" .. file)
  assert(chunk, file .. ": " .. tostring(err))
end

package.preload["src.render.PaletteFX"] = function()
  return { markTrueColor = function() end }
end
package.preload["src.world.FieldDefaults"] = function()
  return { field = function() return {} end }
end
package.preload["src.world.Map"] = function()
  return { isPushable = function() return false end, isOutside = function() return true end,
    isFlyTown = function() return true end }
end
package.preload["src.core.Strings"] = function()
  return setmetatable({}, { __call = function(_, text) return text end })
end
package.preload["src.render.Transition"] = function()
  return { whiteFlash = function() return {} end }
end
package.preload["src.core.Sound"] = function()
  return { play = function() end, playCry = function() end }
end
local OverworldController = { handleInput = function() return "vanilla" end }
package.preload["src.world.OverworldController"] = function() return OverworldController end
local TownMapStub = { update = function() return "townmap vanilla" end }
package.preload["src.ui.TownMap"] = function() return TownMapStub end
local ListMenuStub = { new = function(_, title, items, opts)
  return { title = title, items = items, onChoose = opts and opts.onChoose,
    removeCurrent = function(self) table.remove(self.items, 1) end }
end }
package.preload["src.ui.ListMenu"] = function() return ListMenuStub end
local QuantityBoxStub = { new = function(_, opts) return { max = opts.max } end }
package.preload["src.ui.QuantityBox"] = function() return QuantityBoxStub end
local ItemEffectsStub = { use = function(_, _, id)
  if id == "TM_TEST" then return "learn", "TEST_MOVE" end
  return "failed"
end }
package.preload["src.inventory.ItemEffects"] = function() return ItemEffectsStub end
local BagStub = { add = function(save, id, qty)
  save.inventory[id] = (save.inventory[id] or 0) + (qty or 1)
  return true
end }
package.preload["src.inventory.Bag"] = function() return BagStub end

local hooks, events, exports = {}, {}, {}
local defaults = {}
local mod = {
  id = "gen1_quality_of_life",
  options = {
    define = function(_, schema)
      for _, row in ipairs(schema) do defaults[row.key] = row.default end
    end,
    get = function(_, key) return defaults[key] end,
  },
  content = { screens = { register = function() end } },
  hooks = { wrap = function(_, name, fn, priority)
    hooks[name] = hooks[name] or {}
    hooks[name][#hooks[name] + 1] = { fn = fn, priority = priority }
  end },
  events = { on = function(_, name, fn) events[name] = fn end,
    once = function(_, name, fn) events[name] = fn end },
  ui = {
    insertBefore = function(rows, anchor, item)
      local index = #rows + 1
      for i, row in ipairs(rows) do if row.label == anchor then index = i break end end
      table.insert(rows, index, item)
      return rows
    end,
    push = function() end,
    Menu = { new = function(_, items) return { items = items } end },
  },
  exports = exports,
  log = { info = function() end, warn = function() end, error = function() end },
  find = function() return nil end,
}

local options = dofile("gen1_quality_of_life/qol_options.lua").install(mod)
local game = {
  save = { options = { modOptions = {
    quality_of_life = {
      qol_exp_bar = "on", qol_caught_indicator = "red",
      qol_location_banners = 2, qol_easy_interactions = true,
      qol_cut_grass = false, qol_water_interaction = "surf_first",
      qol_repel_prompt = false,
    },
    catch_helper = { show_catch_text = true, pokeball_x = -3, pokeball_y = 4 },
    exp_share_modes = { mode = "modern" },
  } } },
  mods = { modOptions = {}, events = { emit = function() end } },
  writeOptions = function(self) self.wrote = true end,
}
options.migrate(game)
local migrated = game.save.options.modOptions.gen1_quality_of_life
expect(migrated.ownedIndicator, true, "migrated marker")
expect(migrated.expShare, true, "migrated modern EXP Share")
expect(migrated.ballXOffset, nil, "obsolete X offset is not migrated")
expect(migrated.ultraBallRule, nil, "Ultra is never inferred")
expect(game.wrote, true, "migration persists options")
assert(game.save.options.modOptions.quality_of_life, "QOL legacy bucket retained")
assert(game.save.options.modOptions.catch_helper, "Catch Helper legacy bucket retained")
assert(game.save.options.modOptions.exp_share_modes, "EXP legacy bucket retained")

local existingGame = {
  save = { options = { modOptions = {
    gen1_quality_of_life = { expBar = false, expDistribution = "modern_50",
      _migrationVersion = 1 },
    quality_of_life = { qol_exp_bar = "on" },
  } } }, mods = { modOptions = {} },
}
options.migrate(existingGame)
expect(existingGame.save.options.modOptions.gen1_quality_of_life.expBar, false,
  "obsolete alpha 1 key is retained")
expect(existingGame.save.options.modOptions.gen1_quality_of_life.expShare, true,
  "alpha 1 modern mode migrates to EXP Share")
expect(existingGame.save.options.modOptions.gen1_quality_of_life._migrationVersion, 5,
  "alpha 1 profile advances to migration version 5")

local alpha3StyleGame = {
  save = { options = { modOptions = {
    gen1_quality_of_life = { ownedIndicator = "grey", ballXOffset = 17,
      ballYOffset = -8, _migrationVersion = 3 },
  } } }, mods = { modOptions = {} },
}
options.migrate(alpha3StyleGame)
expect(alpha3StyleGame.save.options.modOptions.gen1_quality_of_life.ownedIndicator,
  true, "alpha 3 marker style becomes the red indicator toggle")
expect(alpha3StyleGame.save.options.modOptions.gen1_quality_of_life._migrationVersion,
  5, "alpha 3 profile advances to migration version 5")

local currentGame = {
  save = { options = { modOptions = {
    gen1_quality_of_life = { expShare = false },
    exp_share_modes = { mode = "modern" },
  } } }, mods = { modOptions = {} },
}
options.migrate(currentGame)
expect(currentGame.save.options.modOptions.gen1_quality_of_life.expShare, false,
  "explicit current EXP Share setting wins over legacy mode")

local fallbackGame = {
  save = { options = { modOptions = {
    catch_helper = { show_pokeball = true },
  } } }, mods = { modOptions = {} },
}
options.migrate(fallbackGame)
expect(fallbackGame.save.options.modOptions.gen1_quality_of_life.ownedIndicator,
  true, "Catch Helper marker fallback")

local conflictGame = {
  save = { options = { modOptions = {
    quality_of_life = { qol_exp_bar = "on" },
  } } }, mods = { modOptions = {} },
}
mod.find = function(id) if id == "quality_of_life" then return { id = id } end end
options.migrate(conflictGame)
expect(conflictGame.save.options.modOptions.gen1_quality_of_life, nil,
  "active conflict blocks migration")
mod.find = function() return nil end

local overlay = { add = function(self, layer) self.layer = layer end }
local catchOptionValues = {
  ownedIndicator = false, catchOdds = false,
}
dofile("gen1_quality_of_life/qol_catch.lua").install(mod, {
  value = function(_, key) return catchOptionValues[key] end,
}, overlay)

local registeredHudOverlay
mod.find = function(id)
  if id ~= "gen1_widescreen_ui" then return nil end
  return { exports = {
    battleHudOverlayApiVersion = 1,
    registerBattleHudOverlay = function(spec)
      registeredHudOverlay = spec
      return true, "registered"
    end,
  } }
end
assert(events["mods.loaded"], "catch display did not defer Widescreen registration")
events["mods.loaded"]()
assert(registeredHudOverlay and registeredHudOverlay.owner == "gen1_quality_of_life"
  and registeredHudOverlay.apiVersion == 1
  and type(registeredHudOverlay.draw) == "function",
  "catch display did not register the Widescreen enemy-HUD extension")
mod.find = function() return nil end

local battle = {
  kind = "wild",
  game = {},
  data = {
    balls = {
      POKE_BALL = { randMax = 255, hpFactor = 12 },
      GREAT_BALL = { randMax = 200, hpFactor = 8 },
      ULTRA_BALL = { randMax = 150, hpFactor = 12 },
    },
    statuses = {}, pokemon = {},
  },
  enemy = {
    mon = { species = "TEST", hp = 100, stats = { hp = 100 } },
    def = { catchRate = 45 },
  },
}
function battle:ballDef(id) return self.data.balls[id] end

catchOptionValues.ownedIndicator, catchOptionValues.catchOdds = true, true
battle.game.save = { pokedex = { owned = { TEST = true } } }
local helperRects, helperPanels, helperText = 0, 0, {}
love = { graphics = {
  setColor = function() end,
  rectangle = function() helperRects = helperRects + 1 end,
  setFont = function() end,
  print = function(text) helperText[#helperText + 1] = text end,
} }
registeredHudOverlay.draw(battle, {
  fonts = { tiny = {} },
  colors = { ink = { 0, 0, 0, 1 } },
  layout = { enemy = {
    x = 12, y = 10, w = 190, h = 52,
    nameX = 25, nameY = 19, nameWidth = 50,
  } },
  drawPanel = function(x, y, w, h)
    helperPanels = helperPanels + 1
    expect(x, 12, "catch footer X anchor")
    expect(y, 60, "catch footer Y anchor")
    expect(w, 190, "catch footer width")
    expect(h, 30, "catch footer height")
  end,
})
assert(helperRects > 0, "red caught ball was not drawn beside the enemy name")
expect(helperPanels, 1, "catch odds footer panel count")
assert(table.concat(helperText, "|"):find("P ", 1, true),
  "catch odds did not use the Widescreen font path")
local wildRectCount, wildPanelCount = helperRects, helperPanels
battle.kind = "trainer"
registeredHudOverlay.draw(battle, {
  fonts = { tiny = {} }, colors = { ink = { 0, 0, 0, 1 } },
  layout = { enemy = { x = 12, y = 10, w = 190, h = 52,
    nameX = 25, nameY = 19, nameWidth = 50 } },
  drawPanel = function() helperPanels = helperPanels + 1 end,
})
expect(helperRects, wildRectCount, "trainer Pokemon caught marker suppression")
expect(helperPanels, wildPanelCount, "trainer Pokemon catch helper suppression")
battle.kind = "wild"
catchOptionValues.ownedIndicator, catchOptionValues.catchOdds = false, false

local p = exports.catchProbability(battle, "POKE_BALL", false)
expect(math.floor(p * 100 + 0.5), 6, "Poke Ball fixture")
expect(math.floor(exports.catchProbability(battle, "ULTRA_BALL", false) * 100 + 0.5),
  10, "vanilla Ultra fixture")
expect(math.floor(exports.catchProbability(battle, "ULTRA_BALL", true) * 100 + 0.5),
  15, "corrected Ultra fixture")

local fixtureBalls = { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "ULTRA_BALL" }
local fixtureCorrected = { false, false, false, true }
local fixtures = {
  { hp = 100, status = nil, values = { 6, 11, 10, 15 } },
  { hp = 100, status = "PAR", values = { 11, 17, 18, 23 } },
  { hp = 100, status = "SLP", values = { 16, 24, 27, 32 } },
  { hp = 50, status = nil, values = { 12, 23, 21, 30 } },
  { hp = 50, status = "PAR", values = { 17, 29, 29, 38 } },
  { hp = 50, status = "SLP", values = { 22, 35, 38, 47 } },
  { hp = 1, status = nil, values = { 18, 23, 30, 30 } },
  { hp = 1, status = "PAR", values = { 23, 29, 38, 38 } },
  { hp = 1, status = "SLP", values = { 28, 35, 47, 47 } },
}
for _, fixture in ipairs(fixtures) do
  battle.enemy.mon.hp, battle.enemy.mon.status = fixture.hp, fixture.status
  for i, ballId in ipairs(fixtureBalls) do
    local percent = math.floor(exports.catchProbability(
      battle, ballId, fixtureCorrected[i]) * 100 + 0.5)
    expect(percent, fixture.values[i],
      "catch fixture " .. fixture.hp .. "/" .. tostring(fixture.status) .. "/" .. i)
  end
end
battle.safari, battle.safariCatchRate = true, 127
battle.enemy.mon.hp, battle.enemy.mon.status = 50, nil
expect(math.floor(exports.catchProbability(battle, "SAFARI_BALL", false) * 100 + 0.5),
  59, "Safari fixture")
battle.safari, battle.safariCatchRate = nil, nil
battle.enemy.mon.hp, battle.enemy.mon.status = 100, nil

local catchHook
for _, entry in ipairs(hooks["catch.rate"] or {}) do catchHook = entry.fn end
local calls = 0
local caught, shakes = catchHook(function()
  calls = calls + 1
  expect(battle.data.balls.ULTRA_BALL.hpFactor, 8, "temporary corrected factor")
  return true, 3
end, "ULTRA_BALL", battle.enemy.mon, battle.enemy.def,
  { battle = battle, rng = function() return 0 end })
expect(calls, 1, "catch chain call count")
expect(caught, true, "catch result")
expect(shakes, 3, "shake result")
expect(battle.data.balls.ULTRA_BALL.hpFactor, 12, "factor restoration")

local errorOk, errorMessage = pcall(catchHook, function()
  expect(battle.data.balls.ULTRA_BALL.hpFactor, 8, "error-path factor")
  error("downstream failure")
end, "ULTRA_BALL", battle.enemy.mon, battle.enemy.def, { battle = battle })
expect(errorOk, false, "downstream error is preserved")
assert(tostring(errorMessage):find("downstream failure", 1, true))
expect(battle.data.balls.ULTRA_BALL.hpFactor, 12, "error-path restoration")

battle.data.balls.CUSTOM_BALL = { randMax = 1000000, hpFactor = 12 }
expect(exports.catchProbability(battle, "CUSTOM_BALL", false), nil,
  "unbounded custom ball is not enumerated")

dofile("gen1_quality_of_life/qol_exp.lua").install(mod, {
  value = function() return false end,
})
local a, b, c, d, fainted =
  { hp = 10, id = "a" }, { hp = 10, id = "b" },
  { hp = 10, id = "c" }, { hp = 10, id = "d" },
  { hp = 0, id = "fainted" }
local summaryMessages = {}
local expBattle = {
  game = { save = { party = { a, b, c, d, fainted } } },
  sayNext = function(_, message) summaryMessages[#summaryMessages + 1] = message end,
}
local ctx = { battle = expBattle, alive = { a, b } }
local plan = exports.expRecipientPlan(ctx)
expect(#plan, 4, "participants plus living bench")
expect(plan[1].split, 2, "participants split the normal pool")
expect(plan[1].shared, false, "participant is not shared")
expect(plan[3].split, 2, "first bench receives independent 50 percent")
expect(plan[3].shared, true, "bench is shared")
expect(plan[4].split, 2, "second bench also receives independent 50 percent")

local expHook
for _, entry in ipairs(hooks["battle.exp_award"] or {}) do expHook = entry.fn end
assert(expHook, "battle.exp_award hook missing")
local vanillaCalls, awards = 0, {}
expHook(function() vanillaCalls = vanillaCalls + 1 end, {
  battle = ctx.battle, alive = { a, b },
  applyShare = function(mon, split, announce)
    awards[#awards + 1] = { mon = mon, split = split, announce = announce }
  end,
})
expect(vanillaCalls, 1, "vanilla mode delegates once")
expect(#awards, 0, "vanilla mode makes no custom awards")

local enabledOptions = { value = function(_, key) return key == "expShare" end }
dofile("gen1_quality_of_life/qol_exp.lua").install(mod, enabledOptions)
local shareHook = hooks["battle.exp_award"][#hooks["battle.exp_award"]].fn
vanillaCalls, awards = 0, {}
local sequence = {}
shareHook(function() vanillaCalls = vanillaCalls + 1 end, {
  battle = {
    game = expBattle.game,
    sayNext = function(_, message)
      summaryMessages[#summaryMessages + 1] = message
      sequence[#sequence + 1] = "summary"
    end,
  },
  alive = { a, b }, participants = 2,
  applyShare = function(mon, split, announce)
    awards[#awards + 1] = { mon = mon, split = split, announce = announce }
    sequence[#sequence + 1] = "award:" .. mon.id
  end,
})
expect(vanillaCalls, 0, "EXP Share replaces vanilla award")
expect(#awards, 4, "EXP Share award count")
expect(awards[1].announce, true, "participant keeps normal message")
expect(awards[3].split, 2, "bench hook receives 50 percent")
expect(awards[3].announce, false, "bench individual message suppressed")
expect(#summaryMessages, 1, "one combined EXP Share message")
expect(summaryMessages[1], "Remaining POKEMON\nreceived EXP!",
  "combined EXP Share message text")
expect(table.concat(sequence, ","), "award:a,award:b,summary,award:c,award:d",
  "summary precedes silent bench awards")

-- The shared overlay dispatcher contains layer failures and restores LOVE's
-- graphics state/canvas before continuing with later layers.
local overlayHooks, overlayEvents = {}, {}
local overlayErrors = 0
local overlayMod = {
  hooks = { wrap = function(_, name, fn) overlayHooks[name] = fn end },
  events = {
    on = function(_, name, fn) overlayEvents[name] = fn end,
    once = function(_, name, fn) overlayEvents[name] = fn end,
  },
  log = {
    error = function() overlayErrors = overlayErrors + 1 end,
    info = function() end,
  },
  find = function() return nil end,
}
local dispatcher = dofile("gen1_quality_of_life/qol_overlay.lua").new(overlayMod, {})
local failedDraws, healthyDraws = 0, 0
dispatcher:add({ id = "failing", draw = function()
  failedDraws = failedDraws + 1
  error("layer failure")
end })
dispatcher:add({ id = "healthy", draw = function() healthyDraws = healthyDraws + 1 end })
dispatcher:install()
local previousCanvas = { id = "original" }
local pushes, pops, restored = 0, 0, 0
love = { graphics = {
  getCanvas = function() return previousCanvas end,
  push = function() pushes = pushes + 1 end,
  pop = function() pops = pops + 1 end,
  setCanvas = function(canvas) if canvas == previousCanvas then restored = restored + 1 end end,
} }
local overlayNext = 0
local overlayBattle = {}
overlayHooks["battle.overlay"](function() overlayNext = overlayNext + 1 end, overlayBattle)
overlayHooks["battle.overlay"](function() overlayNext = overlayNext + 1 end, overlayBattle)
expect(overlayNext, 2, "overlay delegates first")
expect(failedDraws, 1, "failed layer is disabled per battle")
expect(healthyDraws, 2, "healthy layer survives sibling failure")
expect(pushes, 3, "graphics push count")
expect(pops, 3, "graphics pop count")
expect(restored, 3, "canvas restoration count")
expect(overlayErrors, 1, "overlay error logged once")

-- End-to-end entrypoint smoke test: every production module is read through
-- the same flat-package API used by the real loader.
local mainHooks, mainEvents, mainScreens, mainDefaults = {}, {}, {}, {}
local mainMod = {
  id = "gen1_quality_of_life", path = "gen1_quality_of_life",
  options = {
    define = function(_, schema)
      for _, row in ipairs(schema) do mainDefaults[row.key] = row.default end
    end,
    get = function(_, key) return mainDefaults[key] end,
  },
  content = { screens = { register = function(_, id) mainScreens[id] = true end } },
  hooks = { wrap = function(_, name, fn)
    mainHooks[name] = mainHooks[name] or {}
    mainHooks[name][#mainHooks[name] + 1] = fn
  end },
  events = {
    on = function(_, name, fn) mainEvents[name] = fn end,
    once = function(_, name, fn) mainEvents[name] = fn end,
  },
  ui = {
    insertBefore = function(rows, anchor, item)
      local index = #rows + 1
      for i, row in ipairs(rows) do if row.label == anchor then index = i break end end
      table.insert(rows, index, item)
      return rows
    end,
    push = function() end,
    Menu = { new = function(_, items) return { items = items } end },
  },
  exports = {},
  log = { info = function() end, warn = function() end, error = function() end },
  find = function() return nil end,
}
function mainMod:read(path)
  local file = assert(io.open("gen1_quality_of_life/" .. path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local initializer = assert(loadfile("gen1_quality_of_life/main.lua"))()
initializer(mainMod)
expect(mainMod.exports.version, "0.1.0-alpha.6", "entrypoint version")
expect(mainScreens.Gen1QolMain, true, "entrypoint options screen")
expect(mainDefaults.expBar, nil, "EXP bar option removed")
expect(mainDefaults.expDistribution, nil, "multi-mode EXP option removed")
expect(mainDefaults.ballXOffset, nil, "caught-indicator X option removed")
expect(mainDefaults.ballYOffset, nil, "caught-indicator Y option removed")
expect(mainDefaults.ultraBallRule, nil, "Ultra Ball selector removed")
expect(mainDefaults.easyInteractions, nil, "Easy Interactions option removed")
expect(mainDefaults.cutGrass, nil, "Cut Grass option removed")
expect(mainDefaults.waterAction, nil, "Water Action option removed")
expect(mainDefaults.expShare, false, "single EXP Share toggle defaults off")
expect(mainDefaults.fieldHMs, true, "field HMs default on")
expect(mainDefaults.reusableTMs, true, "reusable TMs default on")
expect(#(mainHooks["battle.overlay"] or {}), 1, "single overlay hook")
expect(#(mainHooks["catch.rate"] or {}), 1, "single catch hook")
expect(#(mainHooks["battle.exp_award"] or {}), 1, "single EXP hook")

local hmLead = { hp = 10, species = "TEST", moves = {} }
local hmData = {
  items = {
    HM_CUT = { machine = { kind = "HM", move = "CUT" } },
    HM_FLY = { machine = { kind = "HM", move = "FLY" } },
    HM_SURF = { machine = { kind = "HM", move = "SURF" } },
    TM_TEST = { machine = { kind = "TM", move = "TEST_MOVE" } },
  },
  field = { flyOrder = { "PALLET_TOWN" },
    flyWarps = { PALLET_TOWN = { x = 1, y = 1 } } },
  maps = { PALLET_TOWN = { index = 0, tileset = "OVERWORLD" } },
}
local hmSave = {
  inventory = { HM_CUT = 1 }, pcItems = { HM_FLY = 1 },
  flags = { EVENT_GOT_HM03 = true }, party = { hmLead },
  visited = { PALLET_TOWN = true }, options = { modOptions = {} },
}
local hmGame = { save = hmSave, data = hmData, stack = { values = {} },
  input = { wasPressed = function(_, key) return key == "a" end } }
function hmGame.stack:push(value) self.values[#self.values + 1] = value end
function hmGame.stack:pop() return table.remove(self.values) end
function hmGame.stack:top() return self.values[#self.values] end
expect(mainMod.exports.hasHM(hmGame, "CUT"), true, "HM owned in Bag")
expect(mainMod.exports.hasHM(hmGame, "FLY"), true, "HM owned in PC")
expect(mainMod.exports.hasHM(hmGame, "SURF"), true, "HM obtained event flag")
local eligibilityHook = mainHooks["fieldmove.eligibility"][1]
expect(eligibilityHook(function() return nil end, "SURF",
  { save = hmSave, data = hmData }), hmLead, "HM possession supplies eligibility")

local startRows = mainHooks["ui.start_menu.items"][1](function(_, rows) return rows end,
  hmGame, { { label = "POKEMON" }, { label = "ITEM" } })
expect(startRows[2].label, "HMs", "HMs row inserted before ITEM")
local partyRows = mainHooks["ui.party.submenu"][1](function(_, rows) return rows end,
  hmGame, {
    { label = "CUT", action = "cut" }, { label = "DIG", action = "escape" },
    { label = "STATS", action = "stats" },
  }, hmLead, {})
expect(#partyRows, 2, "taught HM shortcut removed from Pokemon submenu")
expect(partyRows[1].label, "DIG", "non-HM field move remains")

local tmResult = ItemEffectsStub.use(hmData, hmSave, "TM_TEST", hmLead)
expect(tmResult, "learnkept", "TM teaching keeps the item")
expect(BagStub.add(hmSave, "TM_TEST", 1, hmData), true, "first TM acquisition")
expect(BagStub.add(hmSave, "TM_TEST", 1, hmData), false, "duplicate Bag TM rejected")
local pcTmSave = { inventory = {}, pcItems = { TM_TEST = 1 },
  options = { modOptions = {} } }
expect(BagStub.add(pcTmSave, "TM_TEST", 1, hmData), false,
  "duplicate PC TM rejected")
local pcGame = { save = pcTmSave, data = hmData }
local pcItem = { value = "TM_TEST", label = "TM TEST" }
local pcList = ListMenuStub.new(pcGame, "WITHDRAW ITEM", { pcItem }, {
  onChoose = function() error("native PC TM withdrawal should be replaced") end,
})
pcList.onChoose(pcItem, pcList)
expect(pcTmSave.inventory.TM_TEST, 1, "PC TM withdraw moves item to Bag")
expect(pcTmSave.pcItems.TM_TEST, nil, "PC TM withdraw clears PC copy")

local shopSave = { inventory = {}, pcItems = {}, options = { modOptions = {} } }
local shopGame = { save = shopSave, data = hmData }
local shopItem = { value = "TM_TEST" }
local selectedQuantity
local shopList = ListMenuStub.new(shopGame, "BUY", { shopItem }, {
  onChoose = function()
    selectedQuantity = QuantityBoxStub.new(shopGame, { max = 99 }).max
  end,
})
shopList.onChoose(shopItem, shopList)
expect(selectedQuantity, 1, "shop caps reusable TM quantity at one")
shopSave.inventory.TM_TEST = 1
selectedQuantity, shopList.footer = nil, nil
shopList.onChoose(shopItem, shopList)
expect(selectedQuantity, nil, "owned shop TM does not open quantity picker")
expect(shopList.footer, "You already own\nthat TM.", "owned shop TM message")

local TextBoxForHM = {}
TextBoxForHM.__index = TextBoxForHM
function TextBoxForHM.new(_, text_, _, opts_) return setmetatable({
  text = text_, choice = opts_ and opts_.choice,
}, TextBoxForHM) end
package.loaded["src.render.TextBox"] = TextBoxForHM
local flyCalls = {}
hmGame.overworld = { flyTo = function(_, mapId) flyCalls[#flyCalls + 1] = mapId end }
hmGame.mods = { exports = { gen1_quality_of_life = mainMod.exports } }
local townScreen = {
  game = hmGame, locs = { { name = "PALLET" } }, sel = 1,
  byMap = {},
}
townScreen.byMap.PALLET_TOWN = townScreen.locs[1]
hmGame.stack.values = { townScreen }
expect(mainMod.exports._townMapHmUpdate(townScreen), true,
  "plain Town Map intercepts visited city")
local flyPrompt = hmGame.stack:top()
expect(flyPrompt.text, "Use FLY?", "Town Map Fly confirmation")
flyPrompt.choice(true)
expect(flyCalls[1], "PALLET_TOWN", "confirmed Town Map Fly destination")

-- Field HM tests use only the public interaction event. Easy Interactions,
-- fishing arbitration, grass cutting and the Select dispatcher are retired.
local TextBox = {}
TextBox.__index = TextBox
function TextBox.new(game_, text_, onDone_, opts_)
  return setmetatable({ game = game_, text = text_, onDone = onDone_, opts = opts_ }, TextBox)
end
local removedItems, usedItems = {}, {}
package.loaded["src.render.TextBox"] = TextBox
package.loaded["src.world.Map"] = {
  isPushable = function(def) return def and def.pushable == true end,
  isOutside = function(def) return def and def.outside == true end,
}
package.loaded["src.world.FieldDefaults"] = { field = function() return {} end }
package.loaded["src.inventory.ItemEffects"] = {
  use = function(_, _, id)
    usedItems[#usedItems + 1] = id
    return "consumed", { "USED " .. id }
  end,
}
package.loaded["src.inventory.Bag"] = {
  remove = function(save, id, count)
    save.inventory[id] = save.inventory[id] - count
    removedItems[#removedItems + 1] = id
  end,
}

local hmFieldEvents, hmActions = {}, {}
local hmAsked, hmPending, hmPushedScreen = nil, nil, nil
local hmService = {
  hasHM = function() return true end,
  ask = function(_, moveId, onYes)
    hmAsked, hmPending = moveId, onYes
    return true
  end,
  message = function() end,
  setAction = function(moveId, fn) hmActions[moveId] = fn end,
}
local hmStack = { values = {} }
function hmStack:top() return self.values[#self.values] end
function hmStack:push(value) self.values[#self.values + 1] = value end
function hmStack:pop() return table.remove(self.values) end
local hmFieldGame = {
  save = { inventory = { REPEL = 1 }, options = { modOptions = {} } },
  data = { pokemon = { TEST = { name = "TESTMON" } }, text = {},
    items = { REPEL = { name = "REPEL" } }, field = {} },
  stack = hmStack,
  input = { wasPressed = function() return false end },
}
local hmOw = {
  player = { moving = false, surfing = false,
    facingCell = function() return 2, 3 end },
  map = { id = "HM_TEST", def = { tileset = "OVERWORLD" },
    isGrassCell = function() return false end },
  water = false, canCut = true,
  facingIsShoreOrWater = function(self) return self.water end,
  useSurfFieldMove = function() return "ok" end,
  trySurf = function(self) self.surfUses = (self.surfUses or 0) + 1 end,
  useCutFieldMove = function(self) return self.canCut and "ok" or "nothing" end,
  tryCut = function(self) self.cutUses = (self.cutUses or 0) + 1 return true end,
  partyKnows = function(_, move)
    if move == "STRENGTH" then return { species = "TEST" } end
  end,
  flyTo = function(self, mapId) self.flewTo = mapId end,
}
hmStack.values = { hmOw }
local hmFieldMod = {
  id = "gen1_quality_of_life",
  world = { game = hmFieldGame, overworld = function() return hmOw end },
  events = { on = function(_, name, fn) hmFieldEvents[name] = fn end },
  ui = {
    Menu = { new = function(_, items) return { items = items } end },
    push = function(_, screen, opts) hmPushedScreen = { screen = screen, opts = opts } end,
  },
  exports = {},
}
local hmFieldOptions = { value = function(_, key)
  local values = { fieldHMs = true, repelPrompt = true }
  return values[key]
end }
dofile("gen1_quality_of_life/qol_field.lua").install(
  hmFieldMod, hmFieldOptions, hmService)

hmOw.water, hmAsked, hmPending = true, nil, nil
hmFieldEvents["world.interacted"]({ kind = "none" })
expect(hmAsked, "SURF", "water interaction asks to use Surf")
hmPending()
expect(hmOw.surfUses, 1, "confirmed Surf activates")

hmStack.values, hmOw.water, hmAsked, hmPending = { hmOw }, false, nil, nil
hmFieldEvents["world.interacted"]({ kind = "none" })
expect(hmAsked, "CUT", "cuttable interaction asks to use Cut")
hmPending()
expect(hmOw.cutUses, 1, "confirmed Cut activates")

hmStack.values, hmOw.water, hmAsked, hmPending = { hmOw }, false, nil, nil
hmOw.map.isGrassCell = function() return true end
hmFieldEvents["world.interacted"]({ kind = "none" })
expect(hmAsked, nil, "ordinary grass never invokes Cut")
expect(hmOw.cutUses, 1, "ordinary grass is not cut")
hmOw.map.isGrassCell = function() return false end

local hmBoulder = { def = { pushable = true }, frozen = true }
hmStack.values, hmAsked, hmPending = {
  hmOw, TextBox.new(hmFieldGame, "native boulder text") }, nil, nil
hmFieldEvents["world.interacted"]({ kind = "npc", target = hmBoulder })
expect(hmAsked, "STRENGTH", "boulder asks to use Strength")
expect(hmBoulder.frozen, false, "native boulder text released before prompt")
hmPending()
expect(hmOw.strengthActive, true, "confirmed Strength activates")

hmOw.dark, hmOw.strengthActive = true, nil
hmStack.values, hmAsked, hmPending = { hmOw }, nil, nil
hmFieldEvents["map.entered"]({ mapId = "DARK_CAVE" })
expect(hmAsked, "FLASH", "dark cave entry automatically offers Flash")
hmPending()
expect(hmFieldGame.save.flashLit, true, "confirmed automatic Flash sets light state")

hmStack.values, hmAsked, hmPending = { hmOw }, nil, nil
hmActions.FLY(hmFieldGame)
expect(hmAsked, "FLY", "HMs menu Fly asks for confirmation")
hmPending()
expect(hmPushedScreen.screen, "TownMap", "confirmed HMs menu Fly opens Town Map")
expect(hmFieldMod.exports._handleSelect, nil, "Easy Interactions Select dispatcher removed")

hmFieldGame.save.repelSteps = 1
hmFieldEvents["world.stepped"]()
hmFieldGame.save.repelSteps = 0
local wearOff = TextBox.new(hmFieldGame, "REPEL wore off.")
hmFieldEvents["screen.pushed"]({ state = wearOff })
wearOff.onDone()
local renew = hmStack:top()
expect(renew.text, "Use another\nREPEL?", "Repel prompt remains independent")
renew.opts.choice(true)
expect(hmFieldGame.save.inventory.REPEL, 0, "renewed Repel decremented once")

-- Location banners resolve live labels, suppress the Rock Tunnel false
-- positive, avoid restarting across adjacent maps with the same name, and
-- clear on save transitions.
local locationEvents, locationHook = {}, nil
local bannerDraws, bannerText, bannerBox, bannerScale, clock = 0, nil, nil, nil, 0
love = {
  timer = { getTime = function() return clock end },
  graphics = {
    push = function() end, pop = function() end, translate = function() end,
    scale = function(value) bannerScale = value end, setColor = function() end,
    getDimensions = function() return 1024, 768 end,
  },
}
local locationOw = {}
local locationGame = {
  data = {
    field = { townMap = { locations = {
      MAP_A = { name = "Viridian Forest" },
      MAP_B = { name = "Viridian Forest" },
    } } },
    maps = { CAMEL_MAP = { label = "RouteTwenty" } },
  },
  stack = { top = function() return locationOw end },
  renderer = { uiSize = function() return 160, 144 end },
}
local locationMod = {
  world = { game = locationGame, overworld = function() return locationOw end },
  events = { on = function(_, name, fn) locationEvents[name] = fn end },
  hooks = { wrap = function(_, name, fn)
    if name == "render.hud" then locationHook = fn end
  end },
  ui = { Font = {
    drawBox = function(tx, ty, tw, th)
      bannerDraws = bannerDraws + 1
      bannerBox = { tx = tx, ty = ty, tw = tw, th = th }
    end,
    width = function(text_) return #text_ * 8 end,
    draw = function(text_) bannerText = text_ end,
  } },
  exports = {},
}
local locationOptions = { value = function() return 2 end }
dofile("gen1_quality_of_life/qol_locations.lua").install(locationMod, locationOptions)
expect(locationMod.exports.locationName(locationGame, "MAP_A"),
  "VIRIDIAN FOREST", "live town-map label")
expect(locationMod.exports.locationName(locationGame, "CAMEL_MAP"),
  "ROUTE TWENTY", "map-label camel-case fallback")
expect(locationMod.exports.locationName(locationGame, "MISSING_MAP"),
  "MISSING MAP", "sanitized map-id fallback")

locationEvents["map.entered"]({ mapId = "MAP_A" })
locationHook(function() end, locationGame,
  { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144 })
expect(bannerDraws, 1, "location banner draws")
expect(bannerText, "VIRIDIAN FOREST", "location banner text")
expect(bannerBox.ty, 1, "location banner anchors at the top")
expect(bannerBox.th, 3, "location banner uses the larger compact panel")
assert(bannerBox.tx > 20, "location banner was not centered in screen space")
assert(bannerScale > 1.5, "location banner was not enlarged")
clock = 1
locationEvents["map.entered"]({ mapId = "MAP_B" })
clock = 2.1
locationHook(function() end, locationGame,
  { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144 })
expect(bannerDraws, 1, "duplicate location does not restart timer")
clock = 3
locationEvents["map.entered"]({ mapId = "ROCK_TUNNEL_POKECENTER" })
locationHook(function() end, locationGame,
  { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144 })
expect(bannerDraws, 1, "suppressed location does not draw")
clock = 4
locationEvents["map.entered"]({ mapId = "CAMEL_MAP" })
locationEvents["save.loaded"]({ game = locationGame })
locationHook(function() end, locationGame,
  { gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144 })
expect(bannerDraws, 1, "save transition clears active banner")

-- A compatible Widescreen owns the actual location-banner presentation and
-- supplies its fonts, palette and panel renderer.
local wideLocationEvents, wideLocationHook, wideLocationSpec = {}, nil, nil
local widePanel, wideBannerText
local wideLocationMod = {
  world = { game = locationGame, overworld = function() return locationOw end },
  events = {
    on = function(_, name, fn) wideLocationEvents[name] = fn end,
    once = function() end,
  },
  hooks = { wrap = function(_, name, fn)
    if name == "render.hud" then wideLocationHook = fn end
  end },
  ui = { Font = locationMod.ui.Font },
  exports = {},
  log = { info = function() end, error = function() end },
  find = function(id)
    if id ~= "gen1_widescreen_ui" then return nil end
    return { exports = {
      worldHudOverlayApiVersion = 1,
      registerWorldHudOverlay = function(spec)
        wideLocationSpec = spec
        return true, "registered"
      end,
    } }
  end,
}
dofile("gen1_quality_of_life/qol_locations.lua").install(
  wideLocationMod, locationOptions)
assert(wideLocationSpec and wideLocationSpec.owner
  == "gen1_quality_of_life.location_banner",
  "location banner did not register the Widescreen World HUD provider")
clock = 10
wideLocationEvents["map.entered"]({ mapId = "MAP_A" })
local beforeFallbackDraws = bannerDraws
wideLocationHook(function() return "next" end, locationGame, {})
expect(bannerDraws, beforeFallbackDraws,
  "engine-style banner was not suppressed under Widescreen")
love.graphics.setFont = function() end
love.graphics.print = function(text_) wideBannerText = text_ end
wideLocationSpec.draw(locationGame, {
  viewW = 640, viewH = 360,
  fonts = { body = {
    getWidth = function(_, text_) return #text_ * 8 end,
    getHeight = function() return 16 end,
  } },
  colors = { ink = { 0, 0, 0, 1 } },
  drawPanel = function(x, y, w, h) widePanel = { x, y, w, h } end,
})
expect(wideBannerText, "VIRIDIAN FOREST", "Widescreen location banner text")
expect(widePanel[2], 10, "Widescreen location banner top anchor")
expect(widePanel[4], 48, "Widescreen location banner height")
expect(widePanel[1], math.floor((640 - widePanel[3]) / 2),
  "Widescreen location banner horizontal center")

print("unified_qol_test: OK")
