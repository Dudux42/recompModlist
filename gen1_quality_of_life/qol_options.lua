local M = {}

local MOD_ID = "gen1_quality_of_life"
local SCREEN_MAIN = "Gen1QolMain"
local SCREEN_DISPLAY = "Gen1QolBattleDisplay"
local SCREEN_RULES = "Gen1QolBattleRules"
local SCREEN_WORLD = "Gen1QolWorld"

local SCHEMA = {
  { key = "ownedIndicator", type = "toggle", label = "CAUGHT INDICATOR",
    default = false },
  { key = "catchOdds", type = "toggle", label = "CATCH ODDS", default = false },
  { key = "expShare", type = "toggle", label = "EXP SHARE", default = false },
  { key = "locationBanners", type = "choice", label = "LOCATION BANNERS",
    default = 0, choices = {
      { "OFF", 0 }, { "1 SECOND", 1 }, { "2 SECONDS", 2 }, { "3 SECONDS", 3 },
    } },
  { key = "repelPrompt", type = "toggle", label = "REPEL PROMPT", default = true },
  { key = "fieldHMs", type = "toggle", label = "FIELD HMS", default = true },
  { key = "reusableTMs", type = "toggle", label = "REUSABLE TMS", default = true },
}

local BY_KEY = {}
for _, row in ipairs(SCHEMA) do BY_KEY[row.key] = row end

local function ownBucket(game, create)
  local options = game and game.save and game.save.options
  if not options then return nil end
  if create then options.modOptions = options.modOptions or {} end
  local buckets = options.modOptions
  if not buckets then return nil end
  if create then buckets[MOD_ID] = buckets[MOD_ID] or {} end
  return buckets[MOD_ID]
end

local function loaderBucket(game, create)
  local loader = game and game.mods
  if not loader then return nil end
  if create then loader.modOptions = loader.modOptions or {} end
  local buckets = loader.modOptions
  if not buckets then return nil end
  if create then buckets[MOD_ID] = buckets[MOD_ID] or {} end
  return buckets[MOD_ID]
end

local function sanitize(row, value)
  if row.type == "toggle" then return value == true end
  if row.type == "number" then
    value = math.floor(tonumber(value) or row.default)
    if row.min then value = math.max(row.min, value) end
    if row.max then value = math.min(row.max, value) end
    return value
  end
  if row.type == "choice" then
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == value then return value end
    end
  end
  return row.default
end

local function labelFor(row, value)
  if row.type == "toggle" then return value and "ON" or "OFF" end
  if row.type == "number" then return tostring(value) end
  for _, choice in ipairs(row.choices or {}) do
    if choice[2] == value then return choice[1] end
  end
  return "----"
end

function M.install(mod)
  mod.options:define(SCHEMA)

  local api = { screenId = SCREEN_MAIN }

  function api.value(game, key)
    local row = BY_KEY[key]
    if not row then return nil end
    local bucket = ownBucket(game, false)
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    return sanitize(row, value)
  end

  function api.set(game, key, value)
    local row = assert(BY_KEY[key], "unknown option " .. tostring(key))
    value = sanitize(row, value)
    ownBucket(game, true)[key] = value
    local live = loaderBucket(game, true)
    if live then live[key] = value end
    if game.writeOptions then game:writeOptions() end
    if game.mods and game.mods.events then
      game.mods.events:emit("mod.options_changed", { mod = MOD_ID, key = key, value = value })
    end
    return value
  end

  local function step(game, row, dir)
    local current = api.value(game, row.key)
    if row.type == "toggle" then
      return api.set(game, row.key, not current)
    elseif row.type == "number" then
      return api.set(game, row.key, current + dir * (row.step or 1))
    end
    local index = 1
    for i, choice in ipairs(row.choices or {}) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + dir) % #row.choices + 1
    return api.set(game, row.key, row.choices[index][2])
  end

  local function optionScreen(screenId, keys)
    return function(game)
      local OptionRows = require("src.ui.OptionRows")
      local rows = {}
      for _, key in ipairs(keys) do
        local def = BY_KEY[key]
        rows[#rows + 1] = {
          id = key,
          label = def.label,
          value = function(g) return labelFor(def, api.value(g, key)) end,
          step = function(g, dir) step(g, def, dir or 1) return true end,
        }
      end
      local screen = { game = game, rows = rows, index = 1, scroll = 0, isOpaque = true }
      function screen:update()
        local input = self.game.input
        if input:wasPressed("b") then self.game.stack:pop() return end
        if input:wasPressed("up") then
          self.index = (self.index - 2) % #self.rows + 1
        elseif input:wasPressed("down") then
          self.index = self.index % #self.rows + 1
        elseif input:wasPressed("left") or input:wasPressed("right")
            or input:wasPressed("a") then
          local dir = input:wasPressed("left") and -1 or 1
          self.rows[self.index].step(self.game, dir)
        end
        self.scroll = OptionRows.clampScroll(self.index, self.scroll, #self.rows, nil)
      end
      function screen:draw()
        OptionRows.draw(self.game, self.rows, self.index, self.scroll)
        love.graphics.setColor(0, 0, 0, 1)
        mod.ui.Font.draw("LEFT/RIGHT:A  B:BACK", 8, 136)
        love.graphics.setColor(1, 1, 1, 1)
      end
      return screen
    end
  end

  local function mainScreen(game)
    local OptionRows = require("src.ui.OptionRows")
    local entries = {
      { label = "BATTLE DISPLAY", screen = SCREEN_DISPLAY },
      { label = "BATTLE RULES", screen = SCREEN_RULES },
      { label = "WORLD CONVENIENCE", screen = SCREEN_WORLD },
    }
    local rows = {}
    for _, entry in ipairs(entries) do
      rows[#rows + 1] = {
        label = entry.label,
        value = function() return "CONFIGURE" end,
        activate = function(g) mod.ui.push(g, entry.screen) end,
      }
    end
    local screen = { game = game, rows = rows, index = 1, scroll = 0, isOpaque = true }
    function screen:update()
      local input = self.game.input
      if input:wasPressed("b") then self.game.stack:pop() return end
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #self.rows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #self.rows + 1
      elseif input:wasPressed("a") or input:wasPressed("right") then
        self.rows[self.index].activate(self.game)
      end
      self.scroll = OptionRows.clampScroll(self.index, self.scroll, #self.rows, nil)
    end
    function screen:draw()
      OptionRows.draw(self.game, self.rows, self.index, self.scroll)
      love.graphics.setColor(0, 0, 0, 1)
      mod.ui.Font.draw("A:OPEN  B:BACK", 8, 136)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return screen
  end

  mod.content.screens:register(SCREEN_MAIN, { new = mainScreen })
  mod.content.screens:register(SCREEN_DISPLAY, {
    new = optionScreen(SCREEN_DISPLAY,
      { "ownedIndicator", "catchOdds" })
  })
  mod.content.screens:register(SCREEN_RULES, {
    new = optionScreen(SCREEN_RULES, { "expShare" })
  })
  mod.content.screens:register(SCREEN_WORLD, {
    new = optionScreen(SCREEN_WORLD,
      { "locationBanners", "repelPrompt", "fieldHMs", "reusableTMs" })
  })

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "MODS", {
      id = "gen1_unified_qol",
      label = "QUALITY OF LIFE",
      value = function() return "CONFIGURE" end,
      activate = function(g) mod.ui.push(g, SCREEN_MAIN) end,
    })
  end, 100)

  local function migrate(game)
    local options = game and game.save and game.save.options
    local buckets = options and options.modOptions
    if not buckets then return end
    local own = buckets[MOD_ID]
    local migrationVersion = tonumber(own and own._migrationVersion) or 0
    if migrationVersion >= 5 then return end

    -- Alpha 1 exposed several distribution modes plus an EXP-bar option.
    -- Only its 50% mode maps exactly to the new single EXP Share behavior.
    -- Preserve obsolete keys for rollback; they are simply no longer read.
    if own then
      local hasUnifiedSettings = false
      for key in pairs(own) do
        if BY_KEY[key] then hasUnifiedSettings = true break end
      end
      if hasUnifiedSettings or own.expDistribution ~= nil or own.expBar ~= nil
          or migrationVersion > 0 then
        if own.expShare == nil and own.expDistribution == "modern_50" then
          own.expShare = true
        end
        if type(own.ownedIndicator) == "string" then
          own.ownedIndicator = own.ownedIndicator ~= "off"
        end
        -- Alpha 4 anchors battle helpers to the enemy HUD. Keep obsolete
        -- offset keys in the save for rollback, but no longer expose/read them.
        -- Alpha 5 retires Easy Interactions, Cut Grass, Water Action and the
        -- Ultra Ball selector. Obsolete values remain only for rollback.
        own._migrationVersion = 5
        local live = loaderBucket(game, true)
        for key, value in pairs(own) do live[key] = value end
        if game.writeOptions then game:writeOptions() end
        mod.log:info("updated unified settings to migration version 5")
        return
      end
    end
    if mod.find("quality_of_life") or mod.find("catch_helper")
        or mod.find("exp_share_modes") then
      mod.log:warn("legacy migration skipped while a conflicting mod is active")
      return
    end

    local migrated = {}
    local function put(key, value)
      if value == nil then return end
      local row = BY_KEY[key]
      if not row then return end
      own = own or {}
      buckets[MOD_ID] = own
      own[key] = sanitize(row, value)
      migrated[#migrated + 1] = key
    end
    local oldQol = buckets.quality_of_life or {}
    local oldCatch = buckets.catch_helper or {}
    local oldExp = buckets.exp_share_modes or {}

    if oldQol.qol_caught_indicator ~= nil then
      local value = oldQol.qol_caught_indicator
      if value == true then value = "gen2" end
      put("ownedIndicator", value ~= false and value ~= "off")
    elseif oldCatch.show_pokeball == true then
      put("ownedIndicator", true)
    end
    local banners = oldQol.qol_location_banners
    if banners == true then banners = 2 elseif banners == false then banners = 0 end
    put("locationBanners", banners)
    put("repelPrompt", oldQol.qol_repel_prompt)
    put("catchOdds", oldCatch.show_catch_text)
    if oldExp.mode == "modern" then put("expShare", true) end

    own = own or {}
    buckets[MOD_ID] = own
    own._migrationVersion = 5
    local live = loaderBucket(game, true)
    for key, value in pairs(own) do live[key] = value end
    if game.writeOptions then game:writeOptions() end
    if #migrated > 0 then
      mod.log:info("migrated legacy settings: %s", table.concat(migrated, ", "))
    end
  end

  mod.events:on("game.ready", function(event) migrate(event and event.game) end, 100)
  mod.events:on("save.loaded", function(event)
    local game = mod.world and mod.world.game
    if game then migrate(game) end
  end, 100)

  api.schema = SCHEMA
  api.migrate = migrate
  return api
end

return M
