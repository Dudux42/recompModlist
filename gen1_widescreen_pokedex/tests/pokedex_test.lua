local function check(value, message)
  assert(value, message)
end

local function close(a, b)
  return math.abs(a - b) < 0.000001
end

local registrations, hooks, events, errors, infos, screenFactories = {}, {}, {}, {}, {}, {}
local activeOwner
local inputDispatches = 0
local widescreen = {
  exports = {
    pokedexProviderApiVersion = 2,
    activePokedexProviderOwner = function() return activeOwner end,
    registerPokedexProvider = function(spec)
      registrations[#registrations + 1] = spec
      activeOwner = spec.owner
      return true, #registrations == 1 and "registered" or "replaced"
    end,
    updatePokedexProviderInput = function(game, state, dt)
      check(game == state.game and dt == 0.25, "wrong input-dispatch arguments")
      inputDispatches = inputDispatches + 1
      return true
    end,
  },
}

local habitatCalls = 0
local spawnProvider = {
  exports = {
    getSpeciesHabitatSnapshot = function(speciesId, context)
      habitatCalls = habitatCalls + 1
      check(context.schemaVersion == 1 and context.purpose == "pokedex")
      return {
        schemaVersion = 1,
        speciesId = speciesId,
        providerId = "fixture_spawn_provider",
        providerRevision = 3,
        snapshotRevision = 7,
        habitats = {
          {
            mapId = "SECRET_GARDEN", mapName = "SECRET GARDEN",
            method = "grass", minLevel = 4, maxLevel = 6,
            slotChance = 12.5, stepChance = 1.25,
            conditions = { "NIGHT" },
          },
        },
      }
    end,
  },
}

local shinyQueries = 0
local shinyProvider = {
  exports = {
    hasShinyState = function(mon)
      shinyQueries = shinyQueries + 1
      if mon.shinyQueryError then error("fixture shiny query failure") end
      return mon.shiny == true
    end,
  },
}

local pushed = {}
local mod = {
  exports = {},
  find = function(_, id)
    if id == "gen1_widescreen_ui" then return widescreen end
    if id == "kanto_living_encounters" then return spawnProvider end
    if id == "gen1_shiny_system" then return shinyProvider end
  end,
  log = {
    error = function(_, message) errors[#errors + 1] = message end,
    info = function(_, message) infos[#infos + 1] = message end,
  },
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) events[name] = callback end },
  content = {
    screens = {
      register = function(_, id, factory) screenFactories[id] = factory end,
    },
  },
  ui = {
    push = function(game, id, opts)
      pushed[#pushed + 1] = { game = game, id = id, opts = opts }
    end,
  },
}

local init = assert(loadfile("gen1_widescreen_pokedex/main.lua"))()
init(mod)
check(#registrations == 1, "provider did not register")
local provider = registrations[1]
check(provider.owner == "gen1_widescreen_pokedex" and provider.apiVersion == 2)
check(type(provider.actions.selectSubmenu) == "function")
check(type(provider.actions.toggleShiny) == "function")
check(screenFactories.WidescreenPokedex, "screen was not registered")
check(hooks["ui.start_menu.items"], "Start-menu hook was not registered")
check(events["mods.loaded"] and events["game.ready"], "lifecycle retries missing")

local game = {
  data = {
    constants = {
      dexDigits = 3,
      encounterBuckets = { 64, 128, 192, 256 },
    },
    pokemon = {
      BULBASAUR = {
        id = "BULBASAUR", name = "BULBASAUR", dex = 1,
        types = { "GRASS", "POISON" },
        baseStats = { hp = 45, attack = 49, defense = 49, speed = 45, special = 65 },
        level1Moves = { "TACKLE" },
        learnset = {
          { level = 7, move = "LEECH_SEED" },
          { level = 7, move = "GROWL" },
          { level = 13, move = "VINE_WHIP" },
        },
        tmhm = { "MEGA_PUNCH", "CUT", "TOXIC" },
        evolutions = { { method = "LEVEL", level = 16, species = "IVYSAUR" } },
        dexEntry = {
          kind = "SEED POKEMON", heightFt = 2, heightIn = 4, weight = 152,
          text = "DEX_BULBASAUR",
        },
      },
      IVYSAUR = {
        id = "IVYSAUR", name = "IVYSAUR", dex = 2,
        types = { "GRASS", "POISON" },
        baseStats = { hp = 60, attack = 62, defense = 63, speed = 60, special = 80 },
        level1Moves = {}, learnset = {}, tmhm = {}, evolutions = {},
        dexEntry = { kind = "SEED POKEMON", text = "DEX_IVYSAUR" },
      },
      VENUSAUR = {
        id = "VENUSAUR", name = "VENUSAUR", dex = 3,
        types = { "GRASS", "POISON" },
        baseStats = { hp = 80, attack = 82, defense = 83, speed = 80, special = 100 },
        level1Moves = {}, learnset = {}, tmhm = {}, evolutions = {},
      },
      BROKEN_STATS = {
        id = "BROKEN_STATS", name = "BROKEN", dex = 4,
        types = { "NORMAL" },
        baseStats = { hp = 10, attack = "bad", defense = 20, speed = 30, special = 40 },
        level1Moves = {}, learnset = {}, tmhm = {}, evolutions = {},
      },
      ONIX = {
        id = "ONIX", name = "ONIX", dex = 95,
        types = { "ROCK", "GROUND" }, baseStats = {},
        level1Moves = {}, learnset = {}, tmhm = {}, evolutions = {},
      },
      CRYSTAL_ONIX = {
        id = "CRYSTAL_ONIX", name = "CRYSTAL ONIX", dex = 152,
        dexDisplay = 95, dexVariant = "C", dexVariantOrder = 1,
        types = { "ROCK", "ICE" }, baseStats = {},
        level1Moves = {}, learnset = {}, tmhm = {}, evolutions = {},
      },
      DUPLICATE_A = { id = "DUPLICATE_A", name = "DUP A", dex = 200 },
      DUPLICATE_B = { id = "DUPLICATE_B", name = "DUP B", dex = 200 },
    },
    text = {
      DEX_BULBASAUR = "A seed\vwas planted.\fIt grows.",
      DEX_IVYSAUR = "Hidden until caught.",
    },
    moves = {
      TACKLE = { name = "TACKLE", type = "NORMAL", power = 35, accuracy = 95, pp = 35 },
      LEECH_SEED = { name = "LEECH SEED", type = "GRASS", power = 0, accuracy = 90, pp = 10 },
      GROWL = { name = "GROWL", type = "NORMAL", power = 0, accuracy = 100, pp = 40 },
      VINE_WHIP = { name = "VINE WHIP", type = "GRASS", power = 35, accuracy = 100, pp = 10 },
      MEGA_PUNCH = { name = "MEGA PUNCH", type = "NORMAL", power = 80, accuracy = 85, pp = 20 },
      CUT = { name = "CUT", type = "NORMAL", power = 50, accuracy = 95, pp = 30 },
      TOXIC = { name = "TOXIC", type = "POISON", power = 0, accuracy = 85, pp = 10 },
    },
    items = {
      TM_MEGA_PUNCH = { name = "TM01", machine = { kind = "TM", number = 1, move = "MEGA_PUNCH" } },
      HM_CUT = { name = "HM01", machine = { kind = "HM", number = 1, move = "CUT" } },
      TM_TOXIC = { name = "TM06", machine = { kind = "TM", number = 6, move = "TOXIC" } },
    },
    type_chart = { types = {
      GRASS = { name = "GRASS" }, POISON = { name = "POISON" },
      NORMAL = { name = "NORMAL" }, ROCK = { name = "ROCK" },
      GROUND = { name = "GROUND" }, ICE = { name = "ICE" },
    } },
    evolution_methods = {
      LEVEL = { describe = function(evo) return "Level " .. tostring(evo.level) end },
    },
    encounters = {
      ROUTE_1 = {
        grass = {
          rate = 32,
          slots = {
            { species = "BULBASAUR", level = 3 },
            { species = "IVYSAUR", level = 4 },
            { species = "BULBASAUR", level = 5 },
            { species = "VENUSAUR", level = 6 },
          },
        },
      },
    },
    maps = {
      ROUTE_1 = { index = 1, label = "ROUTE 1", tileset = "OVERWORLD" },
      FISHING_POND = { index = 2, label = "FISHING POND", tileset = "OVERWORLD" },
    },
    field = {
      indoorEncounters = { firstIndoorMap = 100, excludedTileset = "FOREST" },
      fishing = { SUPER_ROD = { perMap = "superRod" } },
      superRod = {
        FISHING_POND = {
          { species = "BULBASAUR", level = 10 },
          { species = "IVYSAUR", level = 15 },
        },
      },
    },
  },
  save = {
    party = { { species = "BULBASAUR", shiny = true } },
    boxes = { { { species = "CRYSTAL_ONIX", shiny = true } } },
    box = {},
    pokedex = {
      seen = { IVYSAUR = true },
      owned = {},
    },
  },
  stack = {
    pop = function(self) self.popped = (self.popped or 0) + 1 end,
  },
}

local species = mod.exports.speciesRows(game)
check(#species == 6, "invalid or duplicate dex identities were not filtered")
check(species[1].speciesId == "BULBASAUR" and species[1].owned and species[1].seen)
check(species[2].speciesId == "IVYSAUR" and species[2].seen and not species[2].owned)
check(species[3].speciesId == "VENUSAUR" and species[3].hidden)
check(species[5].number == "095" and species[6].number == "95C",
  "variant display order/format is wrong")
check(species[6].owned and species[6].seen, "Box ownership recovery failed")
check(game.save.pokedex.owned.BULBASAUR == nil and game.save.pokedex.seen.BULBASAUR == nil,
  "display recovery mutated Pokedex flags")
check(mod.exports.hasCaughtShiny(game, "BULBASAUR"),
  "party shiny was not discovered through the authoritative provider")
check(mod.exports.hasCaughtShiny(game, "CRYSTAL_ONIX"),
  "boxed shiny was not discovered through the authoritative provider")
check(not mod.exports.hasCaughtShiny(game, "IVYSAUR"),
  "normal-only species was advertised as shiny")
local shinyQuery = shinyProvider.exports.hasShinyState
shinyProvider.exports.hasShinyState = nil
check(not mod.exports.hasCaughtShiny(game, "BULBASAUR"),
  "missing Shiny System query did not fail closed")
shinyProvider.exports.hasShinyState = shinyQuery
game.save.party[1].shinyQueryError = true
local shinyErrors = #errors
check(not mod.exports.hasCaughtShiny(game, "BULBASAUR"),
  "throwing Shiny System query did not fail closed")
check(#errors == shinyErrors + 1, "Shiny System query failure was not diagnosed")
check(not mod.exports.hasCaughtShiny(game, "BULBASAUR") and #errors == shinyErrors + 1,
  "Shiny System query failure was not deduplicated")
game.save.party[1].shinyQueryError = nil

check(mod.exports.normalizeEntryText("one\vtwo\fthree") == "one two three")
check(mod.exports.normalizeEntryText("  one\r\n two\n\nthree  ") == "one two three",
  "legacy entry whitespace was not normalized for Widescreen reflow")
check(mod.exports.normalizeEntryText(
  "After birth, its\vback swells and\vhardens into a\vshell. Powerfully\vsprays foam from")
  == "After birth, its back swells and hardens into a shell. Powerfully sprays foam from",
  "vanilla entry retained narrow Game Boy line breaks")
check(mod.exports.normalizeEntryText(nil) == "DATA UNAVAILABLE")

local state = mod.exports.newState(game)
check(provider.match(state), "provider does not match its screen")
local snap = provider.snapshot(game, state)
check(snap.schemaVersion == 2 and snap.screen == "pokedex")
check(snap.counts.seen == 3 and snap.counts.owned == 2 and snap.counts.total == 6)
check(snap.detail.name == "BULBASAUR" and snap.detail.owned)
check(snap.detail.entry == "A seed was planted. It grows.")
check(snap.detail.portrait.shinyAvailable == true
  and snap.detail.portrait.shiny == false
  and snap.detail.portrait.purpose == "pokedex")
check(snap.detail.height.feet == 2 and close(snap.detail.weight.pounds, 15.2))

check(provider.actions.toggleShiny(game, state), "caught shiny did not toggle on")
snap = provider.snapshot(game, state)
check(snap.detail.portrait.shinyAvailable and snap.detail.portrait.shiny,
  "shiny portrait state was not exposed")
check(provider.actions.toggleShiny(game, state), "caught shiny did not toggle off")
snap = provider.snapshot(game, state)
check(not snap.detail.portrait.shiny, "second shiny toggle did not restore normal art")

provider.actions.down(game, state)
snap = provider.snapshot(game, state)
check(snap.detail.name == "IVYSAUR" and snap.detail.seen and not snap.detail.owned)
check(not snap.detail.portrait.shinyAvailable and not snap.detail.portrait.shiny,
  "species change leaked shiny availability or presentation")
check(snap.detail.entry:match("CATCH THIS POKEMON"), "seen/unowned entry leaked text")
provider.actions.down(game, state)
snap = provider.snapshot(game, state)
check(snap.detail.hidden and snap.detail.name == "?????")
check(snap.detail.portrait.kind == "unknown" and snap.detail.speciesId == nil,
  "unseen detail leaked identity")
check(not provider.actions.select(game, state), "unseen species opened the submenu")

provider.actions.selectRow(game, state, 1)
check(provider.actions.select(game, state), "known species did not open submenu")
snap = provider.snapshot(game, state)
check(snap.submenu and #snap.submenu.rows == 5)
local expected = { "HABITAT", "STATS", "LEARNSET", "EVOLUTION", "CRY" }
for i, label in ipairs(expected) do check(snap.submenu.rows[i].label == label) end

check(provider.actions.selectSubmenu(game, state, 2))
snap = provider.snapshot(game, state)
check(snap.screen == "pokedex_stats" and #snap.rows == 6)
check(snap.rows[1].value == 45 and snap.rows[6].value == 253)
check(#snap.types == 2 and snap.types[1].id == "GRASS")
provider.actions.pageDown(game, state)
check(state.pageIndex.stats == 6 and state.pageScroll.stats == 0,
  "research navigation was not bounded to the available rows")
provider.actions.pageUp(game, state)
check(state.pageIndex.stats == 1,
  "research page-up did not return to the first row")
provider.actions.back(game, state)
check(state.mode == "pokedex" and state.submenuOpen and state.submenuIndex == 2,
  "research back did not preserve submenu focus")

provider.actions.back(game, state)
provider.actions.selectRow(game, state, 2)
provider.actions.select(game, state)
provider.actions.selectSubmenu(game, state, 2)
snap = provider.snapshot(game, state)
check(snap.gated and snap.rows[1].label:match("LOCKED"),
  "seen/unowned research was not gated")
provider.actions.back(game, state)

provider.actions.back(game, state)
provider.actions.selectRow(game, state, 1)
provider.actions.select(game, state)
provider.actions.selectSubmenu(game, state, 3)
snap = provider.snapshot(game, state)
check(snap.screen == "pokedex_learnset")
local level7 = {}
local tmRows, hmRows = {}, {}
for _, row in ipairs(snap.rows) do
  if row.source == "level_up" and row.level == 7 then level7[#level7 + 1] = row.moveId end
  if row.source == "tm" then tmRows[#tmRows + 1] = row.machineNumber end
  if row.machineKind == "HM" then hmRows[#hmRows + 1] = row end
end
check(level7[1] == "LEECH_SEED" and level7[2] == "GROWL",
  "same-level source order was not preserved")
check(#tmRows == 2 and tmRows[1] == 1 and tmRows[2] == 6, "TM ordering is wrong")
check(#hmRows == 1 and hmRows[1].moveId == "CUT"
  and hmRows[1].machineNumber == 1 and hmRows[1].levelLabel == "HM01",
  "learnable HM was not presented through structured machine metadata")
local sectionOrder = {}
for _, row in ipairs(snap.rows) do
  if row.kind == "section" then sectionOrder[#sectionOrder + 1] = row.id end
end
check(sectionOrder[1] == "level_up" and sectionOrder[2] == "tm"
  and sectionOrder[3] == "hm", "Learnset sections are out of order")
provider.actions.back(game, state)

provider.actions.selectSubmenu(game, state, 4)
snap = provider.snapshot(game, state)
check(snap.rows[1].targetName == "IVYSAUR" and snap.rows[1].method == "Level 16")
provider.actions.back(game, state)

provider.actions.selectSubmenu(game, state, 1)
snap = provider.snapshot(game, state)
check(snap.screen == "pokedex_habitat" and snap.rows[1].mapName == "SECRET GARDEN")
check(snap.rows[1].providerId == "fixture_spawn_provider" and habitatCalls == 1,
  "spawn provider was not preferred")
provider.actions.back(game, state)

local native = mod.exports.nativeHabitats(game, "BULBASAUR")
check(#native == 2, "native encounter and fishing habitats were not both reported")
check(native[1].mapName == "ROUTE 1" and native[1].minLevel == 3
  and native[1].maxLevel == 5, "duplicate native slots were not aggregated")
check(close(native[1].slotChance, 50) and close(native[1].stepChance, 6.25),
  "native encounter chance math is wrong")
check(native[2].method == "SUPER ROD" and close(native[2].slotChance, 100 / 6),
  "structured fishing chance is wrong")

local brokenRows = mod.exports.speciesRows(game)
local broken
for _, row in ipairs(brokenRows) do if row.speciesId == "BROKEN_STATS" then broken = row end end
local brokenStats = mod.exports.stats(game, broken)
check(brokenStats[2].display == "—" and brokenStats[6].display == "—",
  "malformed stats were converted into plausible values")

local cryCalls = 0
package.preload["src.core.Sound"] = function()
  return { playCry = function(data, speciesId)
    check(data == game.data and speciesId == "BULBASAUR")
    cryCalls = cryCalls + 1
  end }
end
state.mode, state.submenuOpen, state.submenuIndex = "pokedex", true, 5
provider.actions.selectRow(game, state, 1) -- rejected while submenu focused
state.selectedIndex, state.selectedSpeciesId = 1, "BULBASAUR"
check(provider.actions.selectSubmenu(game, state, 5))
check(cryCalls == 1 and state.mode == "pokedex" and state.submenuOpen,
  "CRY did not use the live action path or closed the submenu")

state:update(0.25)
check(inputDispatches == 1, "state did not delegate input ownership to Widescreen")

local originalCalls = 0
local startRows = hooks["ui.start_menu.items"](
  function(_, rows) originalCalls = originalCalls + 1 return rows end,
  game,
  { { label = "POKéDEX", onSelect = function() error("native row remained") end },
    { label = "SAVE", onSelect = function() end } })
check(originalCalls == 1 and #startRows == 2, "Start hook did not decorate in place")
startRows[1].onSelect()
check(pushed[#pushed].id == "WidescreenPokedex", "Pokedex destination was not replaced")
pushed[#pushed].opts.onCancel()
check(pushed[#pushed].id == "StartMenu", "cancel did not restore Start menu")

-- API mismatch is actionable and does not replace the native Start row.
local missingErrors, missingHook = 0
local missing = {
  exports = {},
  find = function() return { exports = { pokedexProviderApiVersion = 1 } } end,
  log = { error = function() missingErrors = missingErrors + 1 end },
  hooks = { wrap = function(_, name, callback) missingHook = callback end },
  events = { on = function() end },
  content = { screens = { register = function() end } },
  ui = { push = function() error("must not open") end },
}
init(missing)
check(missingErrors == 1, "missing API error was not deduplicated")
local nativeSelect = function() return "native" end
local result = missingHook(function(_, rows) return rows end, game,
  { { label = "POKéDEX", onSelect = nativeSelect } })
check(result[1].onSelect == nativeSelect, "incompatible API patched the native destination")

print("pokedex_test: OK")
