local M = {}

local SUPPRESSED = { ROCK_TUNNEL_POKECENTER = true }

local function locationName(game, mapId, map)
  local townMap = game and game.data and game.data.field and game.data.field.townMap
  local locations = townMap and (townMap.locations or townMap)
  local entry = type(locations) == "table" and locations[mapId]
  local name = type(entry) == "table" and (entry.name or entry.label)
  local def = map and map.def or (game and game.data and game.data.maps
    and game.data.maps[mapId])
  if not name and def and type(def.label) == "string" then
    name = def.label:gsub("(%l)(%u)", "%1 %2")
  end
  name = name or tostring(mapId or "UNKNOWN"):gsub("_", " ")
  return name:upper()
end

function M.install(mod, options)
  local active = setmetatable({}, { __mode = "k" })
  local lastName = setmetatable({}, { __mode = "k" })
  local widescreenProviderActive = false

  local function liveState(game)
    local state = active[game]
    if not state then return nil end
    if options.value(game, "locationBanners") <= 0
        or love.timer.getTime() >= state.expires then
      active[game] = nil
      return nil
    end
    local ow = mod.world and mod.world:overworld()
    if not ow or not game.stack or game.stack:top() ~= ow then return nil end
    return state
  end

  local function drawWidescreenBanner(game, context)
    local state = liveState(game)
    if not state then return end
    local g, font = love.graphics, context.fonts.body
    local textW = font:getWidth(state.name)
    local w, h = math.max(180, math.ceil(textW + 48)), 48
    local x, y = math.floor((context.viewW - w) / 2), 10
    context.drawPanel(x, y, w, h)
    g.setFont(font)
    local ink = context.colors.ink
    g.setColor(ink[1], ink[2], ink[3], ink[4])
    g.print(state.name, x + math.floor((w - textW) / 2),
      y + math.floor((h - font:getHeight()) / 2))
  end

  local function registerWidescreenProvider()
    if widescreenProviderActive or type(mod.find) ~= "function" then return end
    local handle = mod.find("gen1_widescreen_ui")
    local exports = handle and handle.exports
    if not exports or exports.worldHudOverlayApiVersion ~= 1
        or type(exports.registerWorldHudOverlay) ~= "function" then return end
    local ok, result = pcall(exports.registerWorldHudOverlay, {
      owner = "gen1_quality_of_life.location_banner",
      apiVersion = 1,
      draw = drawWidescreenBanner,
    })
    if ok and result then
      widescreenProviderActive = true
      mod.log:info("using Widescreen UI style for location banners")
    elseif not ok then
      mod.log:error("could not register Widescreen location banner: %s",
        tostring(result))
    end
  end
  registerWidescreenProvider()
  if mod.events and type(mod.events.once) == "function" then
    mod.events:once("mods.loaded", registerWidescreenProvider, -90)
  end

  mod.events:on("map.entered", function(event)
    local game = mod.world and mod.world.game
    if not game or not event or not event.mapId then return end
    if SUPPRESSED[event.mapId] then active[game] = nil return end
    local duration = options.value(game, "locationBanners")
    if type(duration) ~= "number" or duration <= 0 then return end
    local name = locationName(game, event.mapId, event.map)
    if lastName[game] == name then return end
    lastName[game] = name
    active[game] = { name = name, expires = love.timer.getTime() + duration }
  end, 100)

  mod.events:on("save.loaded", function()
    local game = mod.world and mod.world.game
    if game then active[game], lastName[game] = nil, nil end
  end, 100)

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    local result = next(game, viewport)
    local state = liveState(game)
    if not state or widescreenProviderActive then return result end
    local g = love.graphics
    local ww, wh
    if g.getDimensions then ww, wh = g.getDimensions() end
    ww = tonumber(ww) or tonumber(viewport and viewport.gameWidth) or 640
    wh = tonumber(wh) or tonumber(viewport and viewport.gameHeight) or 360
    local baseScale = math.min(ww / 640, wh / 360)
    local scale = math.max(0.5, baseScale * 1.25)
    local logicalW = ww / scale
    local width = mod.ui.Font.width(state.name)
    local tileW = math.max(11, math.ceil((width + 32) / 8))
    local tx = math.max(0, math.floor((logicalW / 8 - tileW) / 2))
    local ty = 1
    local ok = pcall(g.push, "all")
    if not ok then g.push() end
    if g.origin then g.origin() end
    g.scale(scale, scale)
    mod.ui.Font.drawBox(tx, ty, tileW, 3)
    g.setColor(0, 0, 0, 1)
    mod.ui.Font.draw(state.name,
      tx * 8 + math.floor((tileW * 8 - width) / 2), ty * 8 + 8)
    g.pop()
    return result
  end, 100)

  mod.exports.locationName = locationName
end

return M
