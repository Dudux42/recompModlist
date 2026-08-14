-- Gen1 Widescreen UI
-- Version 0.1.0-alpha.14.32
--
-- The world renderer deliberately remains on its normal 160x144 logical
-- surface.  Converted screens are presented in render.hud, after Gen1Recomp
-- and Dramatic Shape have finished composing the world.  This avoids the
-- camera/zoom changes caused by asking Renderer for a wider UI canvas while
-- the overworld is visible.

local DESIGN_W, DESIGN_H = 640, 360
local FONT_PATH = "PixelifySans-VariableFont_wght.ttf"
local PokemonSprites, Assets, PaletteFX, Stats, BattleState
local ShinyArtResolver, ShinyBattleImage, BattleArtProviderImage
local BattleArtProviderPresentation
local EngineFont, TextBoxClass, ChoiceBoxClass
local ListMenuClass, MenuClass, PokedexMenuClass, DexEntryMenuClass
local TitleStateClass, QuarantineReportClass, OptionsMenuClass, ManagerStateClass
local partyBattleSpriteCache = {}
local partyIconSheetCache = {}
local titlePresentationCycles = setmetatable({}, { __mode = "k" })
local titleBattleArtPreviews = setmetatable({}, { __mode = "k" })
local pokemonPresentationTokens = setmetatable({}, { __mode = "k" })
local drawPartyBattleSprite
local selectedBattleSpriteImage
local levelExpProgress
local battleMoveInspectorProvider
local battleMoveInspectorLogError
local BATTLE_MOVE_INSPECTOR_API_VERSION = 1
local pokedexProvider
local pokedexProviderLogError
local POKEDEX_PROVIDER_API_VERSION = 2
local bagProvider
local bagProviderLogError
local BAG_PROVIDER_API_VERSION = 2
local PokedexProviderUI = {
  storageApiVersion = 1,
  compatVersion = 1,
  lastValid = setmetatable({}, { __mode = "k" }),
  hitRegions = setmetatable({}, { __mode = "k" }),
  views = setmetatable({}, { __mode = "k" }),
  providerFaults = setmetatable({}, { __mode = "k" }),
  levelUpGains = setmetatable({}, { __mode = "k" }),
  expAwardBattle = nil,
  expAwardRecord = nil,
  bagLastValid = setmetatable({}, { __mode = "k" }),
  bagHitRegions = setmetatable({}, { __mode = "k" }),
  bagIconCache = {},
  storageLastValid = setmetatable({}, { __mode = "k" }),
  storageHitRegions = setmetatable({}, { __mode = "k" }),
  storageProviderFaults = setmetatable({}, { __mode = "k" }),
  storagePortraitTokens = {},
  storageIconCache = {},
}
function PokedexProviderUI.queueExpAnimation(battle, record, fromRatio, toRatio,
                                               release)
  if not (battle and record and battle.player
      and battle.player.mon == record.mon) then return end
  battle.nextInsert = (battle.nextInsert or 0) + 1
  table.insert(battle.queue, battle.nextInsert, {
    __widescreenExp = true, mon = record.mon,
    -- This installer helper is declared before the file-local clamp function;
    -- keep it self-contained so Lua 5.1 never resolves a missing global.
    fromRatio = math.max(0, math.min(1, tonumber(fromRatio) or 0)),
    toRatio = math.max(0, math.min(1, tonumber(toRatio) or 0)),
    release = release == true,
  })
end
function PokedexProviderUI.finishExpRecord(battle)
  local record = PokedexProviderUI.expAwardRecord
  if not (record and record.battle == battle) then return end
  if not record.announcementSeen then
    PokedexProviderUI.queueExpAnimation(battle, record, record.oldRatio,
      record.finalRatio, true)
  elseif #record.levels > 0 then
    PokedexProviderUI.queueExpAnimation(battle, record, 0,
      record.finalRatio, true)
  end
  PokedexProviderUI.expAwardRecord = nil
end
function PokedexProviderUI.installExpSequence(BattleClass, ExperienceModule)
  if not (BattleClass and ExperienceModule
      and type(ExperienceModule.apply) == "function"
      and type(BattleClass.awardExp) == "function")
      or BattleClass.__widescreenExpSequenceWrapped then return end
  PokedexProviderUI.originalBattleUpdateQueue = BattleClass.updateQueue
  PokedexProviderUI.originalBattleAwardExp = BattleClass.awardExp
  PokedexProviderUI.originalBattleSayNext = BattleClass.sayNext
  local capturedApply = ExperienceModule.apply
  ExperienceModule.apply = function(data, mon, ...)
    local battle = PokedexProviderUI.expAwardBattle
    if battle then PokedexProviderUI.finishExpRecord(battle) end
    local oldExp = tonumber(mon and mon.exp) or 0
    local oldLevel = tonumber(mon and mon.level) or 1
    local levels, gained, extra = capturedApply(data, mon, ...)
    if battle and mon then
      local def = data and data.pokemon and data.pokemon[mon.species]
      local shadow = { exp = oldExp, level = oldLevel }
      PokedexProviderUI.expAwardRecord = {
        battle = battle, mon = mon, levels = levels or {},
        oldRatio = def and levelExpProgress(battle.game, shadow, def) or 0,
        finalRatio = def and levelExpProgress(battle.game, mon, def) or 0,
        announcementSeen = false, grewSeen = 0,
      }
      -- Experience.apply commits the model immediately. Pin presentation to
      -- the pre-award value now, before the queue reaches its animation row,
      -- so the HUD never flashes the final value and jumps backwards.
      if battle.player and battle.player.mon == mon then
        battle.__widescreenExpHold = {
          mon = mon, ratio = PokedexProviderUI.expAwardRecord.oldRatio }
      end
    end
    return levels, gained, extra
  end
  BattleClass.awardExp = function(self, ...)
    local previousBattle = PokedexProviderUI.expAwardBattle
    PokedexProviderUI.expAwardBattle = self
    local ok, a, b, c = pcall(
      PokedexProviderUI.originalBattleAwardExp, self, ...)
    PokedexProviderUI.finishExpRecord(self)
    PokedexProviderUI.expAwardBattle = previousBattle
    if not ok then error(a, 0) end
    return a, b, c
  end
  BattleClass.sayNext = function(self, text, ...)
    local record = PokedexProviderUI.expAwardRecord
    if not (record and record.battle == self) then
      return PokedexProviderUI.originalBattleSayNext(self, text, ...)
    end
    local isGrew = tostring(text or ""):lower():find(" grew", 1, true) ~= nil
    if not record.announcementSeen then
      local result = PokedexProviderUI.originalBattleSayNext(self, text, ...)
      record.announcementSeen = true
      if #record.levels > 0 then
        PokedexProviderUI.queueExpAnimation(self, record, record.oldRatio, 1)
      else
        PokedexProviderUI.queueExpAnimation(self, record, record.oldRatio,
          record.finalRatio, true)
      end
      return result
    end
    if isGrew then
      record.grewSeen = record.grewSeen + 1
      if record.grewSeen > 1 then
        PokedexProviderUI.queueExpAnimation(self, record, 0, 1)
      end
    end
    return PokedexProviderUI.originalBattleSayNext(self, text, ...)
  end
  if type(PokedexProviderUI.originalBattleUpdateQueue) == "function" then
    BattleClass.updateQueue = function(self, ...)
      local animation = self.__widescreenExpDisplay
      if animation then
        animation.frame = animation.frame + 1
        local t = math.min(1, animation.frame / animation.duration)
        animation.ratio = animation.fromRatio
          + (animation.toRatio - animation.fromRatio) * t
        if t >= 1 then
          if animation.release then
            self.__widescreenExpHold = nil
          else
            self.__widescreenExpHold = {
              mon = animation.mon, ratio = animation.toRatio }
          end
          self.__widescreenExpDisplay = nil
        end
        return true
      end
      local first = self.queue and self.queue[1]
      if first and first.__widescreenExp then
        table.remove(self.queue, 1)
        self.__widescreenExpHold = nil
        local distance = math.abs(first.toRatio - first.fromRatio)
        self.__widescreenExpDisplay = {
          mon = first.mon, fromRatio = first.fromRatio,
          toRatio = first.toRatio, ratio = first.fromRatio,
          release = first.release, frame = 0,
          -- About 100 frames for a full level gives the 162px HUD bar
          -- sub-two-pixel visual steps at 60fps without delaying small gains.
          duration = math.max(18, math.floor(100 * distance + 0.5)),
        }
        return true
      end
      return PokedexProviderUI.originalBattleUpdateQueue(self, ...)
    end
  end
  BattleClass.__widescreenExpSequenceWrapped = true
end
PokedexProviderUI.draw2dPokemonPortrait = function(...)
  return drawPartyBattleSprite(...)
end
PokedexProviderUI.resolve2dPokemonPortrait = function(...)
  return selectedBattleSpriteImage(...)
end
PokedexProviderUI.IntroFadeInState = {}
PokedexProviderUI.IntroFadeInState.__index = PokedexProviderUI.IntroFadeInState
PokedexProviderUI.IntroFadeInState.isOpaque = false
function PokedexProviderUI.IntroFadeInState.new(game)
  return setmetatable({ game=game, frame=0, duration=90 },
    PokedexProviderUI.IntroFadeInState)
end
function PokedexProviderUI.IntroFadeInState:update(dt)
  self.frame=self.frame+1
  if self.frame>=self.duration and self.game and self.game.stack then
    local states=self.game.stack.states
    local top=type(states)=="table" and states[#states] or nil
    if top==self then self.game.stack:pop() end
  end
end
function PokedexProviderUI.IntroFadeInState:draw() end
local battleHudOverlayProviders = {}
local battleHudOverlayLogError
local BATTLE_HUD_OVERLAY_API_VERSION = 1
local worldHudOverlayProviders = {}
local worldHudOverlayLogError
local WORLD_HUD_OVERLAY_API_VERSION = 1
local TRAINER_CARD_LEADERS = {
  "OPP_BROCK", "OPP_MISTY", "OPP_LT_SURGE", "OPP_ERIKA",
  "OPP_KOGA", "OPP_SABRINA", "OPP_BLAINE", "OPP_GIOVANNI",
}

local PARTY_ICON_SPECIES = {
  "BULBASAUR","IVYSAUR","VENUSAUR","CHARMANDER","CHARMELEON","CHARIZARD",
  "SQUIRTLE","WARTORTLE","BLASTOISE","CATERPIE","METAPOD","BUTTERFREE",
  "WEEDLE","KAKUNA","BEEDRILL","PIDGEY","PIDGEOTTO","PIDGEOT","RATTATA",
  "RATICATE","SPEAROW","FEAROW","EKANS","ARBOK","PIKACHU","RAICHU",
  "SANDSHREW","SANDSLASH","NIDORANF","NIDORINA","NIDOQUEEN","NIDORANM",
  "NIDORINO","NIDOKING","CLEFAIRY","CLEFABLE","VULPIX","NINETALES",
  "JIGGLYPUFF","WIGGLYTUFF","ZUBAT","GOLBAT","ODDISH","GLOOM","VILEPLUME",
  "PARAS","PARASECT","VENONAT","VENOMOTH","DIGLETT","DUGTRIO","MEOWTH",
  "PERSIAN","PSYDUCK","GOLDUCK","MANKEY","PRIMEAPE","GROWLITHE","ARCANINE",
  "POLIWAG","POLIWHIRL","POLIWRATH","ABRA","KADABRA","ALAKAZAM","MACHOP",
  "MACHOKE","MACHAMP","BELLSPROUT","WEEPINBELL","VICTREEBEL","TENTACOOL",
  "TENTACRUEL","GEODUDE","GRAVELER","GOLEM","PONYTA","RAPIDASH","SLOWPOKE",
  "SLOWBRO","MAGNEMITE","MAGNETON","FARFETCHD","DODUO","DODRIO","SEEL",
  "DEWGONG","GRIMER","MUK","SHELLDER","CLOYSTER","GASTLY","HAUNTER",
  "GENGAR","ONIX","DROWZEE","HYPNO","KRABBY","KINGLER","VOLTORB",
  "ELECTRODE","EXEGGCUTE","EXEGGUTOR","CUBONE","MAROWAK","HITMONLEE",
  "HITMONCHAN","LICKITUNG","KOFFING","WEEZING","RHYHORN","RHYDON","CHANSEY",
  "TANGELA","KANGASKHAN","HORSEA","SEADRA","GOLDEEN","SEAKING","STARYU",
  "STARMIE","MRMIME","SCYTHER","JYNX","ELECTABUZZ","MAGMAR","PINSIR",
  "TAUROS","MAGIKARP","GYARADOS","LAPRAS","DITTO","EEVEE","VAPOREON",
  "JOLTEON","FLAREON","PORYGON","OMANYTE","OMASTAR","KABUTO","KABUTOPS",
  "AERODACTYL","SNORLAX","ARTICUNO","ZAPDOS","MOLTRES","DRATINI","DRAGONAIR",
  "DRAGONITE","MEWTWO","MEW",
}
local PARTY_ICON_DEX = {}
for dex, species in ipairs(PARTY_ICON_SPECIES) do PARTY_ICON_DEX[species] = dex end

local COLORS = {
  shadow = { 0.02, 0.025, 0.03, 0.72 },
  paper = { 0.965, 0.965, 0.93, 0.97 },
  paper2 = { 0.88, 0.89, 0.84, 0.97 },
  ink = { 0.055, 0.065, 0.07, 1.0 },
  selected = { 0.075, 0.10, 0.12, 1.0 },
  selectedText = { 1.0, 1.0, 0.96, 1.0 },
  accent = { 0.82, 0.16, 0.11, 1.0 },
  enabled = { 0.12, 0.62, 0.27, 1.0 },
  disabled = { 0.88, 0.18, 0.14, 1.0 },
  muted = { 0.25, 0.27, 0.27, 1.0 },
}

local function setColor(c)
  love.graphics.setColor(c[1], c[2], c[3], c[4])
end

local function presentationToken(owner, purpose, identity)
  if type(owner) ~= "table" then return {} end
  local tokens = pokemonPresentationTokens[owner]
  if not tokens then
    tokens = {}
    pokemonPresentationTokens[owner] = tokens
  end
  local key = tostring(purpose or "portrait") .. ":" .. tostring(identity or "")
  if not tokens[key] then tokens[key] = {} end
  return tokens[key]
end

-- Presentation API v1 is the only path allowed to time or decode the
-- standalone Battle Art provider's animations. The second result tells
-- callers that the provider owns the request even when ROM mode/missing art
-- intentionally returns nil.
local function providerPokemonPresentation(game, mon, purpose, token)
  if type(BattleArtProviderPresentation) ~= "function" then return nil, false end
  local ok, result, supported = pcall(BattleArtProviderPresentation,
    game, mon, "front", {
      purpose = purpose or "portrait",
      token = token,
    })
  if not (ok and supported) then return nil, false end
  if type(result) ~= "table" or not result.image
      or type(result.image.getDimensions) ~= "function" then
    return nil, true
  end
  return result, true
end

local function topState(game)
  if not (game and game.stack) then return nil end
  if type(game.stack.top) == "function" then return game.stack:top() end
  local states = game.stack.states
  return type(states) == "table" and states[#states] or nil
end

local function stateInStack(game, wanted)
  local states = game and game.stack and game.stack.states
  if type(states) ~= "table" or wanted == nil then return false end
  for _, state in ipairs(states) do
    if state == wanted then return true end
  end
  return false
end

local function drawPanel(x, y, w, h)
  local g = love.graphics
  setColor(COLORS.shadow)
  g.rectangle("fill", x + 4, y + 5, w, h)
  setColor(COLORS.ink)
  g.rectangle("fill", x, y, w, h)
  setColor(COLORS.paper)
  g.rectangle("fill", x + 2, y + 2, w - 4, h - 4)
  setColor(COLORS.ink)
  g.rectangle("fill", x + 6, y + 6, w - 12, 2)
  g.rectangle("fill", x + 6, y + h - 8, w - 12, 2)
end

local function loadFont(size)
  local g = love and love.graphics
  if not g then return nil end
  local ok, font = pcall(g.newFont, FONT_PATH, size, "mono")
  if not ok or not font then
    ok, font = pcall(g.newFont, size)
  end
  if ok and font and font.setFilter then
    pcall(font.setFilter, font, "nearest", "nearest")
  end
  return ok and font or nil
end

local function cleanLabel(value)
  local text = tostring(value or "")
  -- Menu labels should be one line even when supplied by an external mod.
  text = text:gsub("[\r\n]+", " ")
  return text
end

local function fitLabel(font, value, maxWidth)
  local text = cleanLabel(value)
  if not font or font:getWidth(text) <= maxWidth then return text end
  local suffix = ".."
  while #text > 1 and font:getWidth(text .. suffix) > maxWidth do
    text = text:sub(1, -2)
  end
  return text .. suffix
end

local FEMALE_GLYPH, MALE_GLYPH = "\226\153\128", "\226\153\130"

local function genderGlyphAdvance(font)
  local height = font and font.getHeight and font:getHeight() or 14
  return math.max(9, math.floor(height * 0.72 + 0.5))
end

local function pokemonLabelTokens(font, value, maxWidth)
  local text = cleanLabel(value)
  local tokens, width, position = {}, 0, 1
  local suffix, suffixWidth = "..", font:getWidth("..")
  while position <= #text do
    local token, glyph
    local triple = text:sub(position, position + 2)
    if triple == FEMALE_GLYPH or triple == MALE_GLYPH then
      token, glyph, position = triple, triple, position + 3
    else
      local byte = text:byte(position) or 0
      local length = byte < 0x80 and 1 or byte < 0xE0 and 2
        or byte < 0xF0 and 3 or 4
      token, position = text:sub(position, position + length - 1),
        position + length
    end
    local tokenWidth = glyph and genderGlyphAdvance(font)
      or font:getWidth(token)
    if maxWidth and width + tokenWidth > maxWidth then
      while #tokens > 0 and width + suffixWidth > maxWidth do
        local removed = table.remove(tokens)
        width = width - removed.width
      end
      if width + suffixWidth <= maxWidth then
        tokens[#tokens + 1] = { text = suffix, width = suffixWidth }
      end
      return tokens
    end
    tokens[#tokens + 1] = { text = token, glyph = glyph,
      width = tokenWidth }
    width = width + tokenWidth
  end
  return tokens
end

local function drawGenderGlyph(glyph, x, y, font)
  local g = love.graphics
  local advance = genderGlyphAdvance(font)
  local height = font and font.getHeight and font:getHeight() or 14
  local radius = math.max(2, math.floor(math.min(advance, height) * 0.23))
  local cx, cy = x + radius + 1, y + math.floor(height * 0.39)
  if g.setLineWidth then g.setLineWidth(1) end
  g.circle("line", cx, cy, radius)
  if glyph == FEMALE_GLYPH then
    local stemBottom = cy + radius + math.max(3, math.floor(height * 0.28))
    g.line(cx, cy + radius, cx, stemBottom)
    g.line(cx - radius, stemBottom - 2, cx + radius, stemBottom - 2)
  else
    local tipX, tipY = cx + radius + 3, cy - radius - 3
    g.line(cx + radius - 1, cy - radius + 1, tipX, tipY)
    g.line(tipX - 4, tipY, tipX, tipY, tipX, tipY + 4)
  end
end

-- Pixelify Sans lacks U+2640/U+2642. Draw those two semantic characters as
-- matching vector glyphs while preserving the UTF-8 string and measuring the
-- composite label as a single bounded run. This is intentionally generic:
-- ROM dialogue and trainer labels use the same symbols as Pokemon names.
local function drawPokemonLabel(font, value, x, y, maxWidth)
  local g, cursor, run, rendered = love.graphics, x, "", {}
  local function flush()
    if run == "" then return end
    g.print(run, cursor, y)
    cursor, run = cursor + font:getWidth(run), ""
  end
  for _, token in ipairs(pokemonLabelTokens(font, value, maxWidth)) do
    rendered[#rendered + 1] = token.text
    if token.glyph then
      flush()
      drawGenderGlyph(token.glyph, cursor, y, font)
      cursor = cursor + token.width
    else
      run = run .. token.text
    end
  end
  flush()
  return cursor - x, table.concat(rendered)
end

local function updatePresentationScroll(menu, visible)
  local count = #(menu.items or {})
  local index = math.max(1, math.min(tonumber(menu.index) or 1,
                                    math.max(1, count)))
  local maxScroll = math.max(0, count - visible)
  local scroll = math.max(0, math.min(tonumber(menu.__wideUiScroll) or 0,
                                     maxScroll))
  if index <= scroll then
    scroll = index - 1
  elseif index > scroll + visible then
    scroll = index - visible
  end
  menu.__wideUiScroll = math.max(0, math.min(scroll, maxScroll))
  return menu.__wideUiScroll
end

local function drawStartMenu(menu, fonts)
  local g = love.graphics
  -- Keep a generous row pitch so proportional fonts and accented labels have
  -- room at every output resolution. The two-pass row renderer below is also
  -- intentional: every highlight is painted before any label, so a glyph that
  -- extends outside its nominal font box can never be overpainted by the next
  -- row's selection band.
  local x, y, w, h = DESIGN_W - 224, 5, 212, DESIGN_H - 10
  local headerH, footerH, rowH = 31, 24, 22
  local contentTop = y + headerH + 3
  local contentBottom = y + h - footerH - 3
  local visible = math.max(1, math.floor((contentBottom - contentTop) / rowH))
  local items = menu.items or {}
  local scroll = updatePresentationScroll(menu, visible)

  drawPanel(x, y, w, h)

  setColor(COLORS.ink)
  g.setFont(fonts.title)
  g.print("START", x + 14, y + 10)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 83, y + 17, w - 99, 3)

  g.setFont(fonts.body)
  -- Pass 1: selection decoration.
  for slot = 1, visible do
    local itemIndex = scroll + slot
    local item = items[itemIndex]
    if not item then break end
    local ry = contentTop + (slot - 1) * rowH
    if itemIndex == menu.index then
      setColor(COLORS.selected)
      g.rectangle("fill", x + 9, ry + 2, w - 18, rowH - 2)
      setColor(COLORS.accent)
      g.rectangle("fill", x + 9, ry + 2, 4, rowH - 2)
    end
  end

  -- Pass 2: labels. Center using the selected font's actual line height
  -- instead of relying on font-specific baseline offsets.
  local textOffsetY = math.floor((rowH - fonts.body:getHeight()) / 2)
  for slot = 1, visible do
    local itemIndex = scroll + slot
    local item = items[itemIndex]
    if not item then break end
    local ry = contentTop + (slot - 1) * rowH
    if itemIndex == menu.index then
      setColor(COLORS.selectedText)
    else
      setColor(COLORS.ink)
    end
    g.print(cleanLabel(item.label), x + 20, ry + textOffsetY)
  end

  g.setFont(fonts.small)
  if scroll > 0 then
    setColor(COLORS.muted)
    g.print("MORE", x + w - 51, y + headerH - 1)
    g.polygon("fill", x + w - 19, y + headerH + 5,
              x + w - 13, y + headerH + 5,
              x + w - 16, y + headerH + 1)
  end
  if scroll + visible < #items then
    setColor(COLORS.muted)
    g.print("MORE", x + w - 51, y + h - footerH - 12)
    g.polygon("fill", x + w - 19, y + h - footerH - 8,
              x + w - 13, y + h - footerH - 8,
              x + w - 16, y + h - footerH - 4)
  end

  setColor(COLORS.paper2)
  g.rectangle("fill", x + 8, y + h - footerH, w - 16, footerH - 8)
  setColor(COLORS.muted)
  g.print("A  SELECT", x + 14, y + h - footerH + 3)
  local closeText = "B / START  CLOSE"
  g.print(closeText, x + w - 14 - fonts.small:getWidth(closeText),
          y + h - footerH + 3)
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function monDefinition(game, mon)
  local pokemon = game and game.data and game.data.pokemon
  return pokemon and mon and pokemon[mon.species] or nil
end

local function monName(game, mon)
  local def = monDefinition(game, mon)
  return cleanLabel(mon and (mon.nickname or (def and def.name) or mon.species)
                    or "POKEMON")
end

local function shownHP(menu, mon)
  if menu.heal and menu.heal.mon == mon then
    return math.floor(menu.heal.shown or mon.hp or 0)
  end
  return math.floor(mon.hp or 0)
end

local function hpColor(hp, maximum)
  local ratio = clamp(hp / math.max(1, maximum), 0, 1)
  if ratio <= 0.20 then return { 0.78, 0.15, 0.12, 1 } end
  if ratio <= 0.50 then return { 0.86, 0.62, 0.08, 1 } end
  return { 0.12, 0.62, 0.25, 1 }
end

local function drawHPBar(x, y, w, hp, maximum)
  local g = love.graphics
  local ratio = clamp(hp / math.max(1, maximum), 0, 1)
  setColor(COLORS.ink)
  g.rectangle("fill", x, y, w, 6)
  setColor(COLORS.paper2)
  g.rectangle("fill", x + 1, y + 1, w - 2, 4)
  local fill = math.floor((w - 2) * ratio + 0.5)
  if fill > 0 then
    setColor(hpColor(hp, maximum))
    g.rectangle("fill", x + 1, y + 1, fill, 4)
  end
end

local TYPE_COLORS = {
  NORMAL   = { 0.66, 0.65, 0.48, 1 },
  FIRE     = { 0.93, 0.51, 0.19, 1 },
  WATER    = { 0.39, 0.56, 0.94, 1 },
  ELECTRIC = { 0.97, 0.82, 0.17, 1 },
  GRASS    = { 0.48, 0.78, 0.30, 1 },
  ICE      = { 0.59, 0.85, 0.84, 1 },
  FIGHTING = { 0.76, 0.18, 0.16, 1 },
  POISON   = { 0.64, 0.24, 0.63, 1 },
  GROUND   = { 0.89, 0.75, 0.40, 1 },
  FLYING   = { 0.66, 0.56, 0.95, 1 },
  PSYCHIC  = { 0.98, 0.33, 0.53, 1 },
  BUG      = { 0.65, 0.73, 0.10, 1 },
  ROCK     = { 0.71, 0.63, 0.21, 1 },
  GHOST    = { 0.45, 0.34, 0.59, 1 },
  DRAGON   = { 0.44, 0.21, 0.99, 1 },
  DARK     = { 0.44, 0.34, 0.27, 1 },
  STEEL    = { 0.72, 0.72, 0.81, 1 },
  FAIRY    = { 0.84, 0.52, 0.68, 1 },
}

local LIGHT_TYPE_TEXT = {
  NORMAL = true, ELECTRIC = true, GRASS = true, ICE = true,
  GROUND = true, ROCK = true, STEEL = true,
}

local function normalizedType(typeId)
  return tostring(typeId or "-"):gsub("_TYPE$", ""):gsub("_", " "):upper()
end

local function drawTypeBadge(typeId, fonts, x, y, w, h)
  local g = love.graphics
  local label = normalizedType(typeId)
  local color = TYPE_COLORS[label] or { 0.40, 0.43, 0.45, 1 }
  local badgeFont = (h <= 18 and fonts.tiny) or fonts.small
  setColor(COLORS.ink)
  g.rectangle("fill", x, y, w, h, math.floor(h / 2), math.floor(h / 2))
  setColor(color)
  g.rectangle("fill", x + 1, y + 1, w - 2, h - 2,
              math.floor((h - 2) / 2), math.floor((h - 2) / 2))
  -- Small upper highlight gives the capsule the polished newer-game look
  -- without requiring additional image assets.
  setColor({ 1, 1, 1, 0.22 })
  g.rectangle("fill", x + 4, y + 3, w - 8, 2, 1, 1)
  g.setFont(badgeFont)
  setColor(LIGHT_TYPE_TEXT[label] and COLORS.ink or COLORS.selectedText)
  local tx = x + math.floor((w - badgeFont:getWidth(label)) / 2)
  local ty = y + math.floor((h - badgeFont:getHeight()) / 2)
  g.print(label, tx, ty)
end

local function drawXPBar(x, y, w, ratio)
  local g = love.graphics
  ratio = clamp(tonumber(ratio) or 0, 0, 1)
  setColor(COLORS.ink)
  g.rectangle("fill", x, y, w, 7)
  setColor(COLORS.paper2)
  g.rectangle("fill", x + 1, y + 1, w - 2, 5)
  local fill = math.floor((w - 2) * ratio + 0.5)
  if fill > 0 then
    setColor({ 0.18, 0.52, 0.94, 1 })
    g.rectangle("fill", x + 1, y + 1, fill, 5)
  end
end

-- -------------------------------------------------------------------------
-- Battle HUD
-- -------------------------------------------------------------------------

local function battleShownHP(battler)
  if not battler then return 0 end
  return math.max(0, math.floor(tonumber(battler.shownHP)
    or tonumber(battler.mon and battler.mon.hp) or 0))
end

local function battleMaxHP(battler)
  return math.max(1, math.floor(tonumber(battler and battler.mon
    and battler.mon.stats and battler.mon.stats.hp) or 1))
end

local function battleName(battler)
  return cleanLabel(battler and (battler.name
    or (battler.mon and battler.mon.nickname)
    or (battler.mon and battler.mon.species)) or "POKEMON")
end

local function battleStatus(battle, battler)
  if not (battler and battler.shownStatus) then return nil end
  if battle and type(battle.statusLabel) == "function" then
    local ok, label = pcall(battle.statusLabel, battle,
                            { status = battler.shownStatus })
    if ok and label and label ~= "" then return cleanLabel(label):upper() end
  end
  return cleanLabel(battler.shownStatus):upper()
end

local BATTLE_STATUS_COLORS = {
  PSN = { 0.58, 0.20, 0.68, 1 }, TOX = { 0.58, 0.20, 0.68, 1 },
  PAR = { 0.88, 0.63, 0.06, 1 }, BRN = { 0.88, 0.28, 0.08, 1 },
  FRZ = { 0.16, 0.57, 0.82, 1 }, SLP = { 0.35, 0.38, 0.43, 1 },
}

local function battleStatusColor(label)
  label = tostring(label or ""):upper()
  for key, color in pairs(BATTLE_STATUS_COLORS) do
    if label:find(key, 1, true) then return color end
  end
  return COLORS.muted
end

local function battleEnemyVisible(battle)
  if not (battle and battle.enemy) or battle.showEnemyTrainer
      or battle.enemySendingOut or battle.enemy.fainted
      or battle.introBalls then return false end
  if battle.growInScale then
    local ok, scale = pcall(battle.growInScale, battle, battle.enemy)
    if ok and scale then return false end
  end
  return (tonumber(battle.introSlide) or 0) == 0
end

local function battlePlayerVisible(battle)
  return battle and battle.player and not battle.safari and not battle.demo
    and not battle.showPlayerBack and (tonumber(battle.introSlide) or 0) == 0
end

local function battleExpRatio(battle, battler)
  local mon = battler and battler.mon
  local def = mon and battle and battle.data and battle.data.pokemon
    and battle.data.pokemon[mon.species]
  if not (mon and def) then return 0 end
  local animation = battle and battle.__widescreenExpDisplay
  if type(animation) == "table" and animation.mon == mon
      and type(animation.ratio) == "number" then
    return clamp(animation.ratio, 0, 1)
  end
  local held = battle and battle.__widescreenExpHold
  if type(held) == "table" and held.mon == mon
      and type(held.ratio) == "number" then
    return clamp(held.ratio, 0, 1)
  end
  return levelExpProgress(battle.game, mon, def)
end

local function pokemonIsShiny(mon)
  if type(mon) ~= "table" then return false end
  local resolved = ShinyArtResolver and ShinyArtResolver(mon, true)
  if resolved ~= nil then return resolved == true end
  return mon.shiny == true
    or (Stats and type(Stats.isShiny) == "function"
      and Stats.isShiny(mon.dvs) == true)
end

local function loadShinyStarAsset()
  local cached = partyIconSheetCache.__widescreenShinyStar
  if cached then return cached end
  local loader = partyIconSheetCache.__widescreenShinyStarLoader
  if type(loader) ~= "function" then return nil end
  local ok, image = pcall(loader)
  if ok and image and type(image.getDimensions) == "function" then
    local iw, ih = image:getDimensions()
    if iw and ih and iw > 0 and ih > 0 then
      if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
      cached = { image = image, width = iw, height = ih }
      partyIconSheetCache.__widescreenShinyStar = cached
      return cached
    end
  end
  local detail = ok and "image loader returned no usable bitmap" or tostring(image)
  local diagnostics = partyIconSheetCache.__widescreenShinyStarDiagnostics or {}
  partyIconSheetCache.__widescreenShinyStarDiagnostics = diagnostics
  if not diagnostics[detail] then
    diagnostics[detail] = true
    local logError = partyIconSheetCache.__widescreenShinyStarLogError
    if type(logError) == "function" then
      logError("could not load shiny_star.png: " .. detail)
    end
  end
  -- Do not cache failure: the launcher may register/reload assets later.
  return nil
end

local function loadTrainerBadgeAsset()
  local cached = partyIconSheetCache.__widescreenTrainerBadges
  if cached then return cached end
  local loader = partyIconSheetCache.__widescreenTrainerBadgeLoader
  if type(loader) ~= "function" then return nil end
  local ok, image = pcall(loader)
  if ok and image and type(image.getDimensions) == "function" then
    local iw, ih = image:getDimensions()
    if iw and ih and iw >= 512 and ih >= 64 then
      if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
      local quads = {}
      for i = 0, 7 do
        quads[i + 1] = love.graphics.newQuad(i * 64, 0, 64, 64, iw, ih)
      end
      cached = { image = image, quads = quads }
      partyIconSheetCache.__widescreenTrainerBadges = cached
      return cached
    end
  end
  local detail = ok and "image loader returned no usable 512x64 bitmap"
    or tostring(image)
  local diagnostics = partyIconSheetCache.__widescreenTrainerBadgeDiagnostics or {}
  partyIconSheetCache.__widescreenTrainerBadgeDiagnostics = diagnostics
  if not diagnostics[detail] then
    diagnostics[detail] = true
    local logError = partyIconSheetCache.__widescreenTrainerBadgeLogError
    if type(logError) == "function" then
      logError("could not load trainer_badges.png: " .. detail)
    end
  end
  return nil
end

local function drawShinyStarIcon(x, y, size)
  local asset = loadShinyStarAsset()
  if not asset then return false end
  size = math.max(1, math.floor((tonumber(size) or 14) + 0.5))
  x, y = math.floor(x + 0.5), math.floor(y + 0.5)
  local g = love.graphics
  g.push("all")
  setColor({ 1, 1, 1, 1 })
  g.draw(asset.image, x, y, 0,
    size / asset.width, size / asset.height)
  g.pop()
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    PaletteFX.markTrueColor(x, y, size, size)
  end
  return true
end

local function drawBattleStatusPanel(battle, battler, fonts,
                                    x, y, w, h, player)
  local g = love.graphics
  drawPanel(x, y, w, h)
  local hp, maximum = battleShownHP(battler), battleMaxHP(battler)

  g.setFont(fonts.small)
  setColor(COLORS.ink)
  local displayWidth, displayName = drawPokemonLabel(
    fonts.small, battleName(battler), x + 13, y + 9, w - 76)
  if pokemonIsShiny(battler.mon) then
    drawShinyStarIcon(x + 16 + displayWidth, y + 8, 13)
  end
  local level = tostring((battler.mon and battler.mon.level) or "?")
  local levelText = "Lv." .. level
  g.print(levelText, x + w - 13 - fonts.small:getWidth(levelText), y + 9)

  local status = battleStatus(battle, battler)
  if status then
    local color = battleStatusColor(status)
    setColor(color)
    g.rectangle("fill", x + 13, y + 28, 34, 12, 6, 6)
    g.setFont(fonts.tiny)
    setColor(COLORS.selectedText)
    g.print(fitLabel(fonts.tiny, status, 28), x + 16, y + 29)
  else
    g.setFont(fonts.tiny)
    setColor(COLORS.muted)
    g.print("HP", x + 13, y + 29)
  end

  drawHPBar(x + 50, y + 32, w - 63, hp, maximum)
  if player then
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    local hpText = tostring(hp) .. "/" .. tostring(maximum)
    g.print(hpText, x + w - 13 - fonts.small:getWidth(hpText), y + 42)
    -- Leave a full separator row between EXP and the panel's lower rule.
    -- This avoids the same bottom-edge collision corrected in the Party UI.
    drawXPBar(x + 13, y + h - 18, w - 26, battleExpRatio(battle, battler))
  end
  return {
    x = x, y = y, w = w, h = h,
    name = displayName, nameX = x + 13, nameY = y + 9,
    nameWidth = displayWidth,
  }
end

local function drawBattleHudExtensions(battle, fonts, layout)
  for _, provider in ipairs(battleHudOverlayProviders) do
    if not provider.failed then
      local ok, err = pcall(provider.draw, battle, {
        apiVersion = BATTLE_HUD_OVERLAY_API_VERSION,
        fonts = fonts,
        layout = layout,
        colors = COLORS,
        drawPanel = drawPanel,
      })
      if not ok then
        provider.failed = true
        if battleHudOverlayLogError then
          battleHudOverlayLogError(provider.owner .. ": " .. tostring(err))
        end
      end
    end
  end
end

local function drawWorldHudExtensions(game, fonts, viewW, viewH)
  for _, provider in ipairs(worldHudOverlayProviders) do
    if not provider.failed then
      local ok, err = pcall(provider.draw, game, {
        apiVersion = WORLD_HUD_OVERLAY_API_VERSION,
        fonts = fonts,
        viewW = viewW,
        viewH = viewH,
        colors = COLORS,
        drawPanel = drawPanel,
      })
      if not ok then
        provider.failed = true
        if worldHudOverlayLogError then
          worldHudOverlayLogError(provider.owner .. ": " .. tostring(err))
        end
      end
    end
  end
end

local function drawBattlePartyPips(party, x, y, direction)
  local g = love.graphics
  for i = 1, math.min(6, #(party or {})) do
    local mon = party[i]
    local px = x + (i - 1) * 14 * direction
    setColor(COLORS.ink)
    g.circle("fill", px, y, 5)
    if (tonumber(mon and mon.hp) or 0) <= 0 then
      setColor({ 0.40, 0.41, 0.40, 1 })
    elseif mon and mon.status then
      setColor({ 0.86, 0.52, 0.10, 1 })
    else
      setColor({ 0.82, 0.16, 0.11, 1 })
    end
    g.circle("fill", px, y, 3)
    setColor(COLORS.paper)
    g.rectangle("fill", px - 3, y - 1, 6, 2)
  end
end

local function battleMessageLines(battle, font, maxWidth)
  if battle and battle.current and battle.current.text then
    battle.__widescreenUiLastMessage = tostring(battle.current.text)
  end
  local text = tostring(battle and battle.__widescreenUiLastMessage or "")
  -- ROM newlines target an 18-column Game Boy box. Reflow the semantic text
  -- against the real HUD width so three-line messages such as
  -- "MON / learned / MOVE!" retain the move name instead of losing line 3.
  text = text:gsub("[\r\n\v\f]+", " "):gsub("%s+", " ")
    :gsub("^%s+", ""):gsub("%s+$", "")
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = line == "" and word or (line .. " " .. word)
    if line ~= "" and font:getWidth(candidate) > maxWidth then
      lines[#lines + 1], line = line, word
    else
      line = candidate
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

local function drawBattleMessage(battle, fonts, viewW, viewH)
  local g = love.graphics
  local x, y, w, h = 8, viewH - 72, viewW - 16, 64
  drawPanel(x, y, w, h)
  g.setFont(fonts.small)
  setColor(COLORS.ink)
  local lines = battleMessageLines(battle, fonts.small, w - 48)
  for i = 1, math.min(2, #lines) do
    drawPokemonLabel(fonts.small, lines[i], x + 20,
      y + 10 + (i - 1) * 20, w - 48)
  end
  if (battle.msgWaiting or battle.msgPrompt)
      and (tonumber(battle.frame) or 0) % 60 < 30 then
    setColor(COLORS.accent)
    g.polygon("fill", x + w - 25, y + h - 24,
              x + w - 13, y + h - 24, x + w - 19, y + h - 16)
  end
end

local function drawBattleChoiceCell(fonts, label, selected, x, y, w, h)
  local g = love.graphics
  setColor(selected and COLORS.selected or COLORS.paper2)
  g.rectangle("fill", x, y, w, h)
  if selected then
    setColor(COLORS.accent)
    g.rectangle("fill", x, y, 5, h)
  end
  g.setFont(fonts.small)
  setColor(selected and COLORS.selectedText or COLORS.ink)
  local text = fitLabel(fonts.small, label, w - 22)
  g.print(text, x + 12, y + math.floor((h - fonts.small:getHeight()) / 2))
end

local function drawBattleCommand(battle, fonts, viewW, viewH)
  local g = love.graphics
  local promptX, menuW, y, h = 8, 382, viewH - 72, 64
  local menuX = viewW - menuW - 8
  local promptW = menuX - promptX - 8
  drawPanel(promptX, y, promptW, h)
  drawPanel(menuX, y, menuW, h)

  if not battle.demo then
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    if battle.safari then
      g.print("SAFARI ZONE", promptX + 16, y + 10)
      g.setFont(fonts.small)
      g.print("BALLS  " .. tostring(battle.safari.balls or 0),
              promptX + 16, y + 34)
    else
      g.print("What will", promptX + 16, y + 10)
      g.print(fitLabel(fonts.small, battleName(battle.player) .. " do?", promptW - 32),
              promptX + 16, y + 34)
    end
  end

  local labels = battle.safari and { "BALL", "BAIT", "ROCK", "RUN" }
    or { "FIGHT", "POKEMON", "BAG", "RUN" }
  local selected = tonumber(battle.menuIndex) or 1
  if battle.demo then
    labels = { "FIGHT", "POKEMON", "BAG", "RUN" }
    selected = (tonumber(battle.demoTimer) or 0) <= 80 and 1 or 3
  end
  local gap, pad = 4, 10
  local cellW = math.floor((menuW - pad * 2 - gap) / 2)
  local cellH = 21
  for i, label in ipairs(labels) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    drawBattleChoiceCell(fonts, label, i == selected,
      menuX + pad + col * (cellW + gap), y + 9 + row * (cellH + 4),
      cellW, cellH)
  end
end

local function battleMoveMaxPP(move, def)
  if move and move.maxPP then return tonumber(move.maxPP) or 0 end
  local base = tonumber(def and def.pp) or tonumber(move and move.pp) or 0
  return base + (tonumber(move and move.ppUps) or 0) * math.floor(base / 5)
end

local SNAPSHOT_POWER_KINDS = {
  base = true, status = true, fixed = true, special = true,
}
local SNAPSHOT_ACCURACY_KINDS = {
  percent = true, always = true, unavailable = true,
}

local function validateMoveInspectorSnapshot(value)
  if type(value) ~= "table" then return nil, "snapshot must be a table" end
  if value.schemaVersion ~= 1 then return nil, "unsupported snapshot schemaVersion" end
  if value.phase ~= "moveSelect" then return nil, "snapshot phase must be moveSelect" end
  if type(value.selectedIndex) ~= "number" then return nil, "selectedIndex must be numeric" end
  if type(value.moveId) ~= "string" or type(value.moveName) ~= "string" then
    return nil, "moveId and moveName must be strings"
  end
  if type(value.typeId) ~= "string" then return nil, "typeId must be a string" end
  if type(value.pp) ~= "table" or type(value.pp.current) ~= "number"
      or type(value.pp.maximum) ~= "number" then
    return nil, "pp.current and pp.maximum must be numeric"
  end
  if type(value.power) ~= "table" or not SNAPSHOT_POWER_KINDS[value.power.kind]
      or type(value.power.label) ~= "string" then
    return nil, "invalid power descriptor"
  end
  if type(value.accuracy) ~= "table"
      or not SNAPSHOT_ACCURACY_KINDS[value.accuracy.kind]
      or type(value.accuracy.label) ~= "string" then
    return nil, "invalid accuracy descriptor"
  end
  if type(value.matchup) ~= "table" or type(value.matchup.factor) ~= "number"
      or type(value.matchup.label) ~= "string"
      or type(value.matchup.multiplierLabel) ~= "string" then
    return nil, "invalid matchup descriptor"
  end
  if type(value.stab) ~= "table" or type(value.stab.applies) ~= "boolean" then
    return nil, "invalid STAB descriptor"
  end
  if type(value.disabled) ~= "boolean" then return nil, "disabled must be boolean" end
  return value
end

local function activeMoveInspectorSnapshot(battle)
  local provider = battleMoveInspectorProvider
  if not provider then return nil end
  local ok, value, reason = pcall(provider.snapshot, battle)
  if not ok then
    if battleMoveInspectorLogError then
      battleMoveInspectorLogError("provider exception: " .. tostring(value))
    end
    return nil
  end
  if value == nil then
    if reason and battleMoveInspectorLogError then
      battleMoveInspectorLogError("provider returned no snapshot: " .. tostring(reason))
    end
    return nil
  end
  local snapshot, invalid = validateMoveInspectorSnapshot(value)
  if not snapshot and battleMoveInspectorLogError then
    battleMoveInspectorLogError("invalid provider snapshot: " .. tostring(invalid))
  end
  return snapshot
end

local function drawBattleMoves(battle, fonts, moves, selected, allowInspector,
                               viewW, viewH)
  local g = love.graphics
  local x, y, w, h = 8, viewH - 116, viewW - 16, 108
  drawPanel(x, y, w, h)
  local detailW, gap = 150, 5
  local listX, listY, cellH = x + 12, y + 12, 38
  local detailX = x + w - detailW - 12
  local listW = detailX - listX - 18
  local cellW = math.floor((listW - gap) / 2)
  selected = clamp(tonumber(selected) or 1, 1, math.max(1, #(moves or {})))
  for i = 1, 4 do
    local move = moves and moves[i]
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local cx, cy = listX + col * (cellW + gap), listY + row * (cellH + gap)
    local def = move and battle.data and battle.data.moves
      and battle.data.moves[move.id]
    local label = def and def.name or (move and move.id) or "-"
    drawBattleChoiceCell(fonts, label, i == selected, cx, cy, cellW, cellH)
    if battle.moveSwapIndex == i and i ~= selected then
      setColor(COLORS.accent)
      g.rectangle("line", cx + 2, cy + 2, cellW - 4, cellH - 4)
    end
  end

  local snapshot = allowInspector and activeMoveInspectorSnapshot(battle) or nil
  local move = moves and moves[selected]
  local def = move and battle.data and battle.data.moves
    and battle.data.moves[move.id]
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print(snapshot and "MOVE INSPECTOR" or "MOVE INFO", detailX, y + 8)
  if snapshot then
    drawTypeBadge(snapshot.typeId, fonts, detailX, y + 25, 132, 16)
    g.setFont(fonts.tiny)
    setColor(COLORS.ink)
    g.print("PP  " .. tostring(snapshot.pp.current) .. "/"
      .. tostring(snapshot.pp.maximum), detailX, y + 45)
    local stats = "POW " .. snapshot.power.label
      .. "  ACC " .. snapshot.accuracy.label
    g.print(fitLabel(fonts.tiny, stats, 150), detailX, y + 59)
    local matchup = snapshot.matchup.label .. " "
      .. snapshot.matchup.multiplierLabel
    g.print(fitLabel(fonts.tiny, matchup, 150), detailX, y + 73)
    local flags = {}
    if snapshot.stab.applies then flags[#flags + 1] = snapshot.stab.label or "STAB" end
    if snapshot.disabled then flags[#flags + 1] = "DISABLED" end
    if #flags > 0 then
      setColor(snapshot.disabled and COLORS.accent or COLORS.muted)
      g.print(table.concat(flags, "  "), detailX, y + 87)
    end
  elseif def then
    drawTypeBadge(def.type, fonts, detailX, y + 28, 132, 16)
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    local pp = "PP  " .. tostring(move.pp or 0) .. "/" .. tostring(battleMoveMaxPP(move, def))
    g.print(pp, detailX, y + 51)
    if battle.player and battle.player.disabledSlot == selected then
      setColor(COLORS.accent)
      g.print("DISABLED", detailX, y + 72)
    end
  end
end

local function drawBattleTrainerBack(battle, viewW, viewH)
  if not (battle and battle.showPlayerBack and battle.playerBackPic) then return end
  local throw = battle.characterAppearanceThrow
  local image = throw and throw.frames and throw.frames[throw.index]
    or battle.playerBackPic
  if not (throw and throw.frames and throw.frames[throw.index])
      and type(battle.picImage) == "function" then
    local ok, resolved = pcall(battle.picImage, battle, image)
    if ok and resolved then image = resolved end
  end
  if not (image and type(image.getDimensions) == "function") then return end
  local iw, ih = image:getDimensions()
  if not (iw and ih and iw > 0 and ih > 0) then return end
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end

  -- The Widescreen message/command panel begins at viewH-72. Dramatic Shape
  -- normally hangs the intro trainer on the arena tile, which leaves an
  -- obvious gap above that panel. Draw the trainer as HUD art instead, with
  -- its bottom edge pinned to the exact panel boundary. Preserve the native
  -- left-to-right intro slide in the wider coordinate space.
  local slotX, slotW, slotH = 12, 200, 180
  local scale = math.min(slotW / iw, slotH / ih, 3)
  local slide = math.max(0, tonumber(battle.introSlide) or 0) * 8
  local backOffset = 0
  if type(battle.picOffset) == "function" then
    local ok, value = pcall(battle.picOffset, battle, "back")
    if ok then backOffset = tonumber(value) or 0 end
  end
  -- The engine's trainer-back slide is expressed in native battle pixels.
  -- Apply it at the same scale as the HUD-owned sprite so the live throw
  -- travels left with the battle program and fully clears the wide screen.
  local dx = math.floor(slotX + (slotW - iw * scale) / 2 - slide
    + backOffset * scale)
  local dy = math.floor((viewH - 72) - ih * scale)
  setColor({ 1, 1, 1, 1 })
  love.graphics.draw(image, dx, dy, 0, scale, scale)
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    PaletteFX.markTrueColor(dx, dy, iw * scale, ih * scale)
  end
end

local function drawBattleHUD(battle, fonts, viewW, viewH, forceMessage)
  if not battle or battle.blankForAskName then return end
  local layout = { viewW = viewW, viewH = viewH }
  drawBattleTrainerBack(battle, viewW, viewH)
  if battleEnemyVisible(battle) then
    layout.enemy = drawBattleStatusPanel(
      battle, battle.enemy, fonts, 12, 10, 190, 52, false)
  end
  if battlePlayerVisible(battle) then
    -- Alpha 8.2 docks this panel above the command area. Move selection uses a
    -- taller inspector surface, so lift it without changing arena ownership.
    local panelLift = (battle.phase == "moveSelect" or battle.phase == "mimicSelect")
      and 192 or 148
    drawBattleStatusPanel(battle, battle.player, fonts,
                          viewW - 198, viewH - panelLift, 190, 72, true)
  end
  if battle.introBalls then
    drawBattlePartyPips(battle.enemyParty, 94, 82, -1)
    drawBattlePartyPips(battle.playerParty
      or (battle.game and battle.game.save and battle.game.save.party),
      viewW - 94, viewH - 204, 1)
  elseif battle.showEnemyBalls then
    drawBattlePartyPips(battle.enemyParty, 94, 25, -1)
  end

  if forceMessage then
    drawBattleMessage(battle, fonts, viewW, viewH)
  elseif battle.phase == "messages"
      and (battle.current or battle.animPlaying or battle.msgHold
        or battle.__widescreenUiLastMessage) then
    drawBattleMessage(battle, fonts, viewW, viewH)
  elseif battle.phase == "menu" then
    drawBattleCommand(battle, fonts, viewW, viewH)
  elseif battle.phase == "moveSelect" then
    drawBattleMoves(battle, fonts,
      battle.player and battle.player.curMoves, battle.moveIndex, true,
      viewW, viewH)
  elseif battle.phase == "mimicSelect" then
    drawBattleMoves(battle, fonts, battle.mimicMoves, battle.mimicIndex, false,
                    viewW, viewH)
  end
  if layout.enemy then drawBattleHudExtensions(battle, fonts, layout) end
end

PokedexProviderUI.drawLevelUpPanel = function(state, fonts, viewW, viewH)
  local g = love.graphics
  local mon = state and state.mon or {}
  local snapshot = state and state.__widescreenLevelUp or {}
  local stats = snapshot.stats or mon.stats or {}
  local gains = snapshot.gains or {}
  local level = tonumber(snapshot.level) or tonumber(mon.level) or 1
  local w, h = 230, 188
  local x, y = viewW - w - 10, math.max(10, viewH - 72 - h - 8)
  drawPanel(x, y, w, h)

  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print("LEVEL UP", x + 15, y + 13)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 112, y + 24, w - 128, 3)
  g.setFont(fonts.small)
  setColor(COLORS.ink)
  local identity = fitLabel(fonts.small, monName(state.game, mon), w - 88)
  g.print(identity, x + 15, y + 40)
  local levelText = "Lv." .. tostring(level)
  g.print(levelText, x + w - 15 - fonts.small:getWidth(levelText), y + 40)

  local rows = {
    { "HP", "hp" },
    { "ATTACK", "attack" },
    { "DEFENSE", "defense" },
    { "SPEED", "speed" },
    { "SPECIAL", "special" },
  }
  for i, row in ipairs(rows) do
    local ry = y + 61 + (i - 1) * 24
    setColor(i % 2 == 1 and COLORS.paper2 or COLORS.paper)
    g.rectangle("fill", x + 12, ry, w - 24, 21)
    g.setFont(fonts.small)
    setColor(COLORS.muted)
    g.print(row[1], x + 21, ry + 4)
    local value = math.floor(tonumber(stats[row[2]]) or 0)
    local gain = math.max(0, math.floor(tonumber(gains[row[2]]) or 0))
    local valueText = tostring(value)
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    g.print(valueText, x + 155 - fonts.small:getWidth(valueText), ry + 4)
    local gainText = "+" .. tostring(gain)
    setColor(COLORS.enabled)
    g.print(gainText, x + w - 18 - fonts.small:getWidth(gainText), ry + 4)
  end

end
local function drawBattleLevelUp(battle, state, fonts, viewW, viewH)
  drawBattleHUD(battle, fonts, viewW, viewH, true)
  PokedexProviderUI.drawLevelUpPanel(state,fonts,viewW,viewH)
end
PokedexProviderUI.drawBattleLevelUp = drawBattleLevelUp

local function wrapRenderedText(font, text, maxWidth)
  text = tostring(text or ""):gsub("\v", "\n"):gsub("\f", "\n")
  local lines = {}
  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if line ~= "" and font:getWidth(candidate) > maxWidth then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
  end
  return lines
end

local function drawPokedexHeader(fonts, title, page)
  local g = love.graphics
  setColor({ COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 1 })
  g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print(cleanLabel(title or "POKEDEX"), 20, 14)
  setColor(COLORS.accent)
  g.rectangle("fill", 184, 30, 270, 3)
  if page then
    g.setFont(fonts.small)
    setColor(COLORS.muted)
    g.print(page, DESIGN_W - 20 - fonts.small:getWidth(page), 17)
  end
end

local function drawPokedexList(state, fonts, model)
  local g = love.graphics
  local rows = model and model.rows or state.items or {}
  local index = tonumber(model and model.index or state.index) or 1
  local scroll = tonumber(model and model.scroll or state.scroll) or 0
  local title = model and model.title or state.title or "POKEDEX"
  drawPokedexHeader(fonts, title)
  local x, y, w, h = 20, 52, 600, 266
  drawPanel(x, y, w, h)
  local visible, rowH = 7, 34
  for row = 1, visible do
    local i = scroll + row
    local item = rows[i]
    if not item then break end
    local ry = y + 11 + (row - 1) * rowH
    local selected = i == index
    setColor(selected and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", x + 10, ry, w - 20, rowH - 4)
    if selected then
      setColor(COLORS.accent)
      g.rectangle("fill", x + 10, ry, 5, rowH - 4)
    end
    g.setFont(fonts.small)
    setColor(selected and COLORS.selectedText or COLORS.ink)
    local label = cleanLabel(item.label or "")
    g.print(fitLabel(fonts.small, label, w - 150), x + 25, ry + 6)
    local value = item.value or item.right
    if value ~= nil and type(value) ~= "table" then
      local valueText = cleanLabel(value)
      g.print(valueText, x + w - 26 - fonts.small:getWidth(valueText), ry + 6)
    end
    if item.marker or item.ball then
      local bx, by = x + w - 112, ry + 14
      setColor(selected and COLORS.selectedText or COLORS.ink)
      g.circle("line", bx, by, 5)
      g.rectangle("fill", bx - 5, by - 1, 10, 2)
      g.circle("fill", bx, by, 2)
    end
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  local footer = model and model.footer or state.footer
  if type(footer) == "table" then footer = table.concat(footer, "     ") end
  footer = cleanLabel(footer or "A OPEN     B BACK")
  g.print(fitLabel(fonts.tiny, footer, DESIGN_W - 40), 20, 334)
end

local function providerPokedexRegions(state)
  local regions = {}
  if type(state) == "table" then PokedexProviderUI.hitRegions[state] = regions end
  return regions
end

local function addPokedexRegion(regions, x, y, w, h, action, value)
  regions[#regions + 1] = {
    x = math.floor(x), y = math.floor(y),
    w = math.floor(w), h = math.floor(h),
    action = action, value = value,
  }
end

local function providerVisibleRange(rows, selected, requestedScroll, visible)
  local count = #(rows or {})
  selected = clamp(math.floor(tonumber(selected) or 1), 1, math.max(1, count))
  local scroll = clamp(math.floor(tonumber(requestedScroll) or 0),
    0, math.max(0, count - visible))
  if selected <= scroll then scroll = selected - 1 end
  if selected > scroll + visible then scroll = selected - visible end
  return selected, clamp(scroll, 0, math.max(0, count - visible))
end

local function providerTrackedRange(state, key, rows, selected,
                                    requestedScroll, visible)
  if type(state) ~= "table" then
    return providerVisibleRange(rows, selected, requestedScroll, visible)
  end
  local views = PokedexProviderUI.views[state]
  if not views then
    views = {}
    PokedexProviderUI.views[state] = views
  end
  local view = views[key]
  local count = #(rows or {})
  selected = clamp(math.floor(tonumber(selected) or 1), 1, math.max(1, count))
  requestedScroll = clamp(math.floor(tonumber(requestedScroll) or 0),
    0, math.max(0, count - visible))
  if not view then
    view = { selected = selected, requested = requestedScroll,
      scroll = requestedScroll }
    views[key] = view
  elseif requestedScroll ~= view.requested then
    -- Provider pageUp/pageDown/scroll changed the explicit viewport.
    view.scroll = requestedScroll
  elseif selected ~= view.selected then
    -- Provider up/down/selectRow changed focus; reveal that row without
    -- writing presentation state back into the immutable snapshot.
    if selected <= view.scroll then view.scroll = selected - 1 end
    if selected > view.scroll + visible then view.scroll = selected - visible end
  end
  view.selected, view.requested = selected, requestedScroll
  view.scroll = clamp(view.scroll, 0, math.max(0, count - visible))
  return selected, view.scroll
end

local function providerEntryViewport(state, snapshot, lineCount)
  local maxOffset = math.max(0, (tonumber(lineCount) or 0) - 5)
  if type(state) ~= "table" then
    return { offset = 0, maxOffset = maxOffset, focused = false,
      available = maxOffset > 0 }
  end
  local views = PokedexProviderUI.views[state]
  if not views then
    views = {}
    PokedexProviderUI.views[state] = views
  end
  local detail = type(snapshot.detail) == "table" and snapshot.detail or {}
  local selected = math.floor(tonumber(snapshot.selectedIndex) or 1)
  local selectedRow = type(snapshot.rows) == "table" and snapshot.rows[selected]
  local speciesKey = tostring(detail.speciesId or snapshot.selectedSpeciesId
    or (type(selectedRow) == "table" and selectedRow.speciesId)
    or detail.number or selected)
  local view = views.entryViewport
  if not view or view.speciesKey ~= speciesKey then
    -- A newly selected species always opens at the beginning. This prevents a
    -- long entry's offset from hiding the first lines of the next species.
    view = { speciesKey = speciesKey, offset = 0, focused = false }
    views.entryViewport = view
  end
  view.maxOffset = maxOffset
  view.offset = clamp(math.floor(tonumber(view.offset) or 0), 0, maxOffset)
  view.available = maxOffset > 0 and snapshot.submenu == nil
  view.shinyAvailable = detail.seen == true and not detail.hidden
    and detail.owned == true and type(detail.portrait) == "table"
    and detail.portrait.shinyAvailable == true and snapshot.submenu == nil
  view.shiny = view.shinyAvailable and detail.portrait.shiny == true or false
  if not view.available then view.focused = false end
  return view
end

PokedexProviderUI.applyEntryAction = function(state, action, value)
  local views = type(state) == "table" and PokedexProviderUI.views[state]
  local view = views and views.entryViewport
  if not (view and view.available and (view.maxOffset or 0) > 0) then
    return false
  end
  if action == "entryFocus" then
    view.focused = value == nil and not view.focused or value and true or false
  elseif action == "entryBlur" then
    view.focused = false
  elseif action == "entryScroll" then
    view.focused = true
    view.offset = clamp((view.offset or 0) + (tonumber(value) or 0),
      0, view.maxOffset)
  else
    return false
  end
  return true
end

local function drawProviderPokemonPortrait(game, state, detail, x, y, w, h)
  if type(detail) ~= "table" or detail.hidden or detail.seen == false then
    return false
  end
  local portrait = detail.portrait
  if type(portrait) ~= "table" or portrait.kind ~= "pokemon"
      or type(portrait.speciesId) ~= "string" then return false end
  -- Deliberately species/presentation-only: no DVs or party identity reaches
  -- the art provider. Shiny is accepted only from the validated provider
  -- possession verdict and never inferred from Pokedex ownership.
  local mon = { species = portrait.speciesId, shiny = portrait.shiny == true }
  local image = selectedBattleSpriteImage(game, mon, "pokedex", state)
  if not (image and type(image.getDimensions) == "function") then return false end
  local sw, sh = image:getDimensions()
  if not sw or not sh or sw <= 0 or sh <= 0 then return false end
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  local scale = math.min(w / sw, h / sh)
  local dx = math.floor(x + (w - sw * scale) / 2)
  local dy = math.floor(y + (h - sh * scale) / 2)
  setColor({ 1, 1, 1, 1 })
  love.graphics.draw(image, dx, dy, 0, scale, scale)
  return true
end

local function pokedexCountText(counts)
  counts = type(counts) == "table" and counts or {}
  return ("SEEN %03d     OWN %03d     TOTAL %03d"):format(
    tonumber(counts.seen) or 0, tonumber(counts.owned) or 0,
    tonumber(counts.total) or 0)
end

local function drawPokedexProviderMain(game, state, snapshot, fonts)
  local g = love.graphics
  local regions = providerPokedexRegions(state)
  drawPokedexHeader(fonts, snapshot.title or "POKEDEX")
  local listX, listY, listW, listH = 20, 52, 260, 266
  local detailX, detailY, detailW, detailH = 292, 52, 328, 266
  drawPanel(listX, listY, listW, listH)
  drawPanel(detailX, detailY, detailW, detailH)

  local rows = snapshot.rows or {}
  local visible, rowH = 8, 29
  local selected, scroll = providerTrackedRange(state, "pokedex",
    rows, snapshot.selectedIndex, snapshot.scroll, visible)
  for row = 1, visible do
    local index = scroll + row
    local item = rows[index]
    if not item then break end
    local ry = listY + 10 + (row - 1) * rowH
    local focused = index == selected
    setColor(focused and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", listX + 9, ry, listW - 18, rowH - 3)
    if focused then
      setColor(COLORS.accent)
      g.rectangle("fill", listX + 9, ry, 5, rowH - 3)
    end
    g.setFont(fonts.small)
    setColor(focused and COLORS.selectedText or COLORS.ink)
    local number = tostring(item.number or "---")
    local name = (item.hidden or item.seen == false) and "?????"
      or tostring(item.name or "UNKNOWN")
    drawPokemonLabel(fonts.small, number .. "  " .. name,
      listX + 22, ry + 5, listW - 62)
    if item.owned then
      local bx, by = listX + listW - 25, ry + 12
      g.circle("line", bx, by, 5)
      g.rectangle("fill", bx - 5, by - 1, 10, 2)
      g.circle("fill", bx, by, 2)
    end
    addPokedexRegion(regions, listX + 9, ry, listW - 18, rowH - 3,
      "selectRow", index)
  end

  local detail = type(snapshot.detail) == "table" and snapshot.detail or {}
  local hidden = detail.hidden or detail.seen == false
  if hidden then
    -- Privacy transitions also retire any viewport that belonged to the
    -- previously visible species; hidden details expose neither stale text
    -- focus nor scroll controls.
    providerEntryViewport(state, snapshot, 0)
  end
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  local detailName = hidden and "?????" or tostring(detail.name or "UNKNOWN")
  drawPokemonLabel(fonts.body, detailName,
    detailX + 17, detailY + 15, 178)
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print("No. " .. tostring(detail.number or "---"), detailX + 18, detailY + 43)

  if hidden then
    g.setFont(fonts.body)
    setColor(COLORS.muted)
    g.print("?", detailX + 236, detailY + 79)
    g.setFont(fonts.small)
    local hiddenMessage = snapshot.providerError and "PROVIDER DATA UNAVAILABLE"
      or "NO DATA RECORDED"
    g.print(hiddenMessage, detailX + 18, detailY + 113)
    if snapshot.providerError then
      local lines = wrapRenderedText(fonts.tiny, snapshot.providerError,
        detailW - 36)
      g.setFont(fonts.tiny)
      for i = 1, math.min(5, #lines) do
        g.print(lines[i], detailX + 18, detailY + 145 + (i - 1) * 15)
      end
    end
  else
    drawProviderPokemonPortrait(game, state, detail,
      detailX + 185, detailY + 13, 125, 126)
    local portrait = detail.portrait
    if detail.seen == true and detail.owned == true
        and snapshot.submenu == nil
        and not PokedexProviderUI.providerFaults[state]
        and type(portrait) == "table" and portrait.kind == "pokemon"
        and portrait.shinyAvailable == true and portrait.shiny == true then
      drawShinyStarIcon(detailX + detailW - 35, detailY + 10, 16)
    end
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    if detail.kind then
      g.print(fitLabel(fonts.small, detail.kind, 166),
        detailX + 18, detailY + 70)
    end
    if detail.height then
      local height = detail.height.metres and
        (tostring(detail.height.metres) .. " m") or
        ((tostring(detail.height.feet or "-") .. "' " ..
          tostring(detail.height.inches or 0) .. '\"'))
      g.print("HT  " .. height, detailX + 18, detailY + 94)
    end
    if detail.weight then
      local weight = detail.weight.kilograms and
        (tostring(detail.weight.kilograms) .. " kg") or
        (tostring(detail.weight.pounds or "-") .. " lb")
      g.print("WT  " .. weight, detailX + 18, detailY + 116)
    end
    local entry = detail.owned == false
      and tostring(detail.entry or "CATCH THIS POKEMON TO UNLOCK RESEARCH")
      or tostring(detail.entry or "DATA UNAVAILABLE")
    local lines = wrapRenderedText(fonts.small, entry, detailW - 54)
    local entryView = providerEntryViewport(state, snapshot, #lines)
    local entryX, entryY, entryW, entryH =
      detailX + 12, detailY + 145, detailW - 24, 98
    -- The broad detail action remains available outside the entry viewport.
    -- Entry-specific regions are registered afterwards and therefore receive
    -- pointer priority in the reverse-order hit test.
    addPokedexRegion(regions, detailX + 8, detailY + 8,
      detailW - 16, detailH - 16, "select")
    if entryView.maxOffset > 0 then
      setColor(entryView.focused and COLORS.accent or COLORS.muted)
      g.rectangle("line", entryX, entryY, entryW, entryH)
      addPokedexRegion(regions, entryX, entryY, entryW, entryH,
        "entryFocus", true)
    end
    setColor(detail.owned == false and COLORS.muted or COLORS.ink)
    for i = 1, 5 do
      local line = lines[entryView.offset + i]
      if not line then break end
      g.print(line, detailX + 18, detailY + 151 + (i - 1) * 18)
    end
    local arrowX = detailX + detailW - 18
    if entryView.offset > 0 then
      setColor(entryView.focused and COLORS.accent or COLORS.muted)
      g.polygon("fill", arrowX - 5, entryY + 12,
        arrowX + 5, entryY + 12, arrowX, entryY + 5)
      addPokedexRegion(regions, arrowX - 11, entryY,
        22, 24, "entryScroll", -1)
    end
    if entryView.offset < entryView.maxOffset then
      setColor(entryView.focused and COLORS.accent or COLORS.muted)
      g.polygon("fill", arrowX - 5, entryY + entryH - 12,
        arrowX + 5, entryY + entryH - 12, arrowX, entryY + entryH - 5)
      addPokedexRegion(regions, arrowX - 11, entryY + entryH - 24,
        22, 24, "entryScroll", 1)
    end
  end

  if type(snapshot.submenu) == "table" then
    local submenu = snapshot.submenu
    local menuX, menuY, menuW, menuH = detailX + 85, detailY + 38, 226, 210
    drawPanel(menuX, menuY, menuW, menuH)
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    g.print("RESEARCH", menuX + 16, menuY + 13)
    local menuRows = submenu.rows or {}
    for i = 1, math.min(5, #menuRows) do
      local item = menuRows[i]
      local ry = menuY + 40 + (i - 1) * 31
      local focused = i == (tonumber(submenu.selectedIndex) or 1)
      setColor(focused and COLORS.selected or COLORS.paper2)
      g.rectangle("fill", menuX + 10, ry, menuW - 20, 27)
      if focused then
        setColor(COLORS.accent)
        g.rectangle("fill", menuX + 10, ry, 5, 27)
      end
      g.setFont(fonts.small)
      setColor(focused and COLORS.selectedText or COLORS.ink)
      g.print(fitLabel(fonts.small, item.label or item.id, menuW - 45),
        menuX + 24, ry + 5)
      addPokedexRegion(regions, menuX + 10, ry, menuW - 20, 27,
        "selectSubmenu", i)
    end
  end

  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print(pokedexCountText(snapshot.counts), 20, 334)
  local entryViews = type(state) == "table" and PokedexProviderUI.views[state]
  local entryView = entryViews and entryViews.entryViewport
  local controls
  if snapshot.submenu then
    controls = "A OPEN     B CLOSE"
  elseif entryView and entryView.focused then
    controls = "UP/DOWN SCROLL     A/B/SELECT DONE"
  elseif entryView and entryView.shinyAvailable and entryView.available then
    controls = (entryView.shiny and "SELECT NORMAL" or "SELECT SHINY")
      .. "     START ENTRY     A DETAILS"
  elseif entryView and entryView.shinyAvailable then
    controls = (entryView.shiny and "SELECT NORMAL" or "SELECT SHINY")
      .. "     A DETAILS     B BACK"
  elseif entryView and entryView.available then
    controls = "SELECT ENTRY     A DETAILS     B BACK"
  else
    controls = "A DETAILS     B BACK"
  end
  g.print(controls, DESIGN_W - 20 - fonts.tiny:getWidth(controls), 334)
end

local function providerRowDisplay(row)
  if type(row) ~= "table" then return "DATA UNAVAILABLE" end
  return tostring(row.label or row.message or "DATA UNAVAILABLE")
end

local function drawPokedexResearchRow(snapshot, row, fonts, x, y, w, h, focused)
  local g = love.graphics
  local kind = tostring(row.kind or "message")
  setColor(focused and COLORS.selected or COLORS.paper2)
  g.rectangle("fill", x, y, w, h)
  if focused then
    setColor(COLORS.accent)
    g.rectangle("fill", x, y, 5, h)
  end
  local ink = focused and COLORS.selectedText or COLORS.ink
  g.setFont(fonts.small)
  setColor(ink)
  if snapshot.screen == "pokedex_habitat" and kind == "habitat" then
    g.print(fitLabel(fonts.small, row.mapName or row.mapId, w - 310), x + 14, y + 5)
    g.print(fitLabel(fonts.small, row.method or "UNKNOWN", 92), x + 240, y + 5)
    local levels = ("Lv.%s-%s"):format(tostring(row.minLevel or "-"),
      tostring(row.maxLevel or "-"))
    g.print(levels, x + 342, y + 5)
    local chance = tonumber(row.slotChance)
    local chanceText = chance and (("%.1f%%"):format(chance)) or "—"
    g.print(chanceText, x + w - 14 - fonts.small:getWidth(chanceText), y + 5)
  elseif snapshot.screen == "pokedex_learnset" and kind == "section" then
    setColor(COLORS.accent)
    g.print(fitLabel(fonts.small, row.label or "MOVES", w - 28), x + 14, y + 5)
  elseif snapshot.screen == "pokedex_learnset" and kind == "move" then
    g.print(fitLabel(fonts.small, row.levelLabel or "—", 62), x + 14, y + 5)
    g.print(fitLabel(fonts.small, row.moveName or row.moveId, 190), x + 82, y + 5)
    drawTypeBadge(row.typeId or row.typeName, fonts, x + 282, y + 4, 74, h - 8)
    local meta = {}
    if row.power ~= nil then meta[#meta + 1] = "PWR " .. tostring(row.power) end
    if row.accuracy ~= nil then meta[#meta + 1] = "ACC " .. tostring(row.accuracy) end
    if row.pp ~= nil then meta[#meta + 1] = "PP " .. tostring(row.pp) end
    g.setFont(fonts.tiny)
    setColor(ink)
    local value = table.concat(meta, "  ")
    g.print(fitLabel(fonts.tiny, value, w - 382), x + 370, y + 8)
  elseif snapshot.screen == "pokedex_evolution" and kind == "evolution" then
    local target = row.targetHidden and "?????" or
      tostring(row.targetName or row.targetSpeciesId or "?????")
    g.print(fitLabel(fonts.small, target, 200), x + 14, y + 5)
    g.print(fitLabel(fonts.small, row.method or "DATA INCOMPLETE", w - 240),
      x + 224, y + 5)
  else
    g.print(fitLabel(fonts.small, providerRowDisplay(row), w - 28), x + 14, y + 5)
  end
end

local function drawPokedexProviderResearch(state, snapshot, fonts)
  local g = love.graphics
  local regions = providerPokedexRegions(state)
  local modeName = tostring(snapshot.screen or "pokedex"):gsub("^pokedex_", ""):upper()
  drawPokedexHeader(fonts, "POKEDEX / " .. modeName,
    tostring(snapshot.number or "---") .. "  " .. tostring(snapshot.name or "UNKNOWN"))
  local x, y, w, h = 20, 52, 600, 266
  drawPanel(x, y, w, h)
  if snapshot.gated then
    g.setFont(fonts.body)
    setColor(COLORS.muted)
    local message = fitLabel(fonts.body,
      snapshot.message or "RESEARCH DATA LOCKED", w - 60)
    g.print(message, x + math.floor((w - fonts.body:getWidth(message)) / 2), y + 112)
  elseif snapshot.screen == "pokedex_stats" then
    local types = snapshot.types or {}
    for i = 1, math.min(2, #types) do
      drawTypeBadge(types[i].id or types[i].name, fonts,
        x + 18 + (i - 1) * 91, y + 15, 82, 20)
    end
    local rows = snapshot.rows or {}
    for i = 1, math.min(6, #rows) do
      local row = rows[i]
      local ry = y + 48 + (i - 1) * 33
      setColor(COLORS.paper2)
      g.rectangle("fill", x + 16, ry, w - 32, 28)
      g.setFont(fonts.small)
      setColor(COLORS.ink)
      g.print(fitLabel(fonts.small, row.label or row.id, 150), x + 30, ry + 5)
      local numeric = tonumber(row.value)
      if numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
        numeric = nil
      end
      local display = numeric ~= nil and tostring(numeric) or "—"
      g.print(display, x + 196 - fonts.small:getWidth(display), ry + 5)
      if row.kind ~= "total" and numeric then
        local barX, barW = x + 224, w - 258
        setColor({ 0.74, 0.75, 0.70, 1 })
        g.rectangle("fill", barX, ry + 8, barW, 12)
        setColor(COLORS.enabled)
        g.rectangle("fill", barX, ry + 8,
          math.floor(barW * clamp(numeric / 255, 0, 1)), 12)
      end
    end
  else
    local rows = snapshot.rows or {}
    local visible, rowH = 7, 32
    local selected, scroll = providerTrackedRange(state, snapshot.screen,
      rows, snapshot.selectedIndex, snapshot.scroll, visible)
    for rowIndex = 1, visible do
      local index = scroll + rowIndex
      local row = rows[index]
      if not row then break end
      local ry = y + 13 + (rowIndex - 1) * rowH
      drawPokedexResearchRow(snapshot, row, fonts,
        x + 13, ry, w - 26, rowH - 4, index == selected)
      addPokedexRegion(regions, x + 13, ry, w - 26, rowH - 4,
        index < selected and "up" or index > selected and "down" or "select")
    end
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print("UP / DOWN  SCROLL     LEFT / RIGHT  PAGE", 20, 334)
  local controls = "B BACK"
  g.print(controls, DESIGN_W - 20 - fonts.tiny:getWidth(controls), 334)
end

PokedexProviderUI.draw = function(game, state, snapshot, fonts)
  if snapshot.screen == "pokedex" then
    drawPokedexProviderMain(game, state, snapshot, fonts)
  else
    drawPokedexProviderResearch(state, snapshot, fonts)
  end
end

local function drawWithPalette(image, palette, drawFn, keyed)
  local g = love.graphics
  local applied = false
  local shaderFactory = keyed and PaletteFX and PaletteFX.keyedShader
    or PaletteFX and PaletteFX.shader
  if palette and type(shaderFactory) == "function"
      and type(PaletteFX.sendColors) == "function"
      and type(g.setShader) == "function" then
    local okShader, shader = pcall(shaderFactory)
    if okShader and shader then
      local ok = pcall(PaletteFX.sendColors, shader, palette)
      if ok then
        g.setShader(shader)
        applied = true
      end
    end
  end
  drawFn()
  if applied then g.setShader() end
end

local function drawPokedexEntry(state, fonts)
  local g = love.graphics
  local def = state.def or {}
  local game = state.game or {}
  local entry = def.dexEntry or {}
  local digits = game.data and game.data.constants
    and game.data.constants.dexDigits or 3
  drawPokedexHeader(fonts, "POKEMON DATA")
  drawPanel(20, 52, 228, 266)
  drawPanel(260, 52, 360, 266)

  g.setFont(fonts.body)
  setColor(COLORS.ink)
  drawPokemonLabel(fonts.body, def.name or "UNKNOWN", 36, 68, 196)
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print(("No.%0" .. tostring(digits) .. "d"):format(def.dex or 0), 36, 96)
  local pokemonDrawn = false
  if def.id then
    local token = presentationToken(state, "pokedex", def.id)
    local presentation = providerPokemonPresentation(
      game, { species = def.id }, "pokedex", token)
    local providerImage = presentation and presentation.image
    if providerImage and type(providerImage.getDimensions) == "function" then
      local sw, sh = providerImage:getDimensions()
      if sw > 0 and sh > 0 then
        local scale = math.min(196 / sw, 156 / sh)
        local dx = 36 + (196 - sw * scale) / 2
        local dy = 116 + (156 - sh * scale) / 2
        if providerImage.setFilter then
          pcall(providerImage.setFilter, providerImage, "nearest", "nearest")
        end
        setColor({ 1, 1, 1, 1 })
        g.draw(providerImage, math.floor(dx), math.floor(dy), 0, scale, scale)
        pokemonDrawn = true
      end
    end
  end
  if not pokemonDrawn and state.sprite
      and type(state.sprite.getDimensions) == "function" then
    local sw, sh = state.sprite:getDimensions()
    if sw > 0 and sh > 0 then
      local scale = math.min(176 / sw, 156 / sh)
      local dx = 134 - sw * scale / 2
      local dy = 202 - sh * scale / 2
      if state.sprite.setFilter then pcall(state.sprite.setFilter, state.sprite, "nearest", "nearest") end
      setColor({ 1, 1, 1, 1 })
      local palette = PaletteFX and PaletteFX.monPal
        and PaletteFX.monPal(game.data, def.id) or nil
      drawWithPalette(state.sprite, palette, function()
        g.draw(state.sprite, math.floor(dx), math.floor(dy), 0, scale, scale)
      end)
    end
  end

  g.setFont(fonts.small)
  setColor(COLORS.ink)
  g.print(fitLabel(fonts.small, entry.kind or "UNKNOWN", 320), 278, 72)
  local owned = state.forceOwned or (game.save and game.save.pokedex
    and game.save.pokedex.owned and game.save.pokedex.owned[def.id])
  if owned and entry.heightFt then
    local height = entry.heightM and string.format("HEIGHT  %.1fm", entry.heightM)
      or string.format("HEIGHT  %d'%02d\"", entry.heightFt, entry.heightIn or 0)
    local weight = entry.weightKg and string.format("WEIGHT  %.1fkg", entry.weightKg)
      or string.format("WEIGHT  %.1flb", (entry.weight or 0) / 10)
    g.print(height, 278, 102)
    g.print(weight, 278, 124)
  end
  local text = owned and entry.text and game.data and game.data.text
    and game.data.text[entry.text] or "DATA UNKNOWN."
  local lines = wrapRenderedText(fonts.small, text, 322)
  for i = 1, math.min(7, #lines) do
    g.print(lines[i], 278, 160 + (i - 1) * 20)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print("A / B  BACK", 20, 334)
end

local function drawImageContained(image, x, y, w, h, maxScale, palette, keyed)
  if not (image and type(image.getDimensions) == "function") then return end
  local iw, ih = image:getDimensions()
  if iw <= 0 or ih <= 0 then return end
  local scale = math.min(w / iw, h / ih, maxScale or math.huge)
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  setColor({ 1, 1, 1, 1 })
  drawWithPalette(image, palette, function()
    love.graphics.draw(image,
      math.floor(x + (w - iw * scale) / 2),
      math.floor(y + (h - ih * scale) / 2), 0, scale, scale)
  end, keyed)
end

local function drawImageGrounded(image, x, bottom, w, h, maxScale, palette, keyed)
  if not (image and type(image.getDimensions) == "function") then return end
  local iw, ih = image:getDimensions()
  if iw <= 0 or ih <= 0 then return end
  local scale = math.min(w / iw, h / ih, maxScale or math.huge)
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  setColor({ 1, 1, 1, 1 })
  drawWithPalette(image, palette, function()
    love.graphics.draw(image, math.floor(x + (w - iw * scale) / 2),
      math.floor(bottom - ih * scale), 0, scale, scale)
  end, keyed)
end

-- TitleState's ribbon image is an 80x8 source strip. Blue uses its first
-- 64 pixels; Red composes pixels 0..15 and 40..79 with an eight-pixel gap.
-- Drawing the whole source exposed unused white canvas and shifted the label.
local function drawTitleVersion(title, x, y, w, h, palette)
  local image = title and title.version
  if not (image and type(image.getDimensions) == "function") then return end
  local iw, ih = image:getDimensions()
  if iw <= 0 or ih < 8 then return end
  local logicalW = 64
  local scale = math.min(w / logicalW, h / 8, 4)
  local dx = math.floor(x + (w - logicalW * scale) / 2)
  local dy = math.floor(y + (h - 8 * scale) / 2)
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  setColor({ 1, 1, 1, 1 })
  drawWithPalette(image, palette, function()
    if title.blue then
      local q = love.graphics.newQuad(0, 0, math.min(64, iw), 8, iw, ih)
      love.graphics.draw(image, q, dx, dy, 0, scale, scale)
    else
      local leftW = math.min(16, iw)
      local rightX, rightW = 40, math.max(0, math.min(40, iw - 40))
      if leftW > 0 then
        love.graphics.draw(image,
          love.graphics.newQuad(0, 0, leftW, 8, iw, ih), dx, dy, 0, scale, scale)
      end
      if rightW > 0 then
        love.graphics.draw(image,
          love.graphics.newQuad(rightX, 0, rightW, 8, iw, ih),
          dx + 24 * scale, dy, 0, scale, scale)
      end
    end
  end, true)
end

-- Exact Red/Blue motion tables from pokered engine/movie/title2.asm.
-- Each pair is { horizontal pixels per frame, number of frames }. The old
-- picture accelerates left; after CheckForUserInterruption's one-frame pause
-- (and the starter ball's five-frame wait), the new picture decelerates from
-- 120 pixels off the right edge. The stationary hold is 200 frames.
local TITLE_HOLD_FRAMES = 200
local TITLE_OUT_SCROLL = {
  { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 },
  { 5, 2 }, { 6, 2 }, { 8, 3 }, { 9, 3 },
}
local TITLE_IN_SCROLL = {
  { 10, 2 }, { 9, 4 }, { 8, 4 }, { 6, 3 },
  { 5, 2 }, { 3, 1 }, { 1, 1 },
}
local TITLE_OUT_FRAMES, TITLE_IN_FRAMES = 18, 17
local TITLE_IN_DISTANCE = 120
local TITLE_STARTERS = { CHARMANDER = true, SQUIRTLE = true, BULBASAUR = true }
local TITLE_SHINY_ROLL = 64

local function titleRandom(low, high)
  local random = love and love.math and love.math.random or math.random
  local ok, value = pcall(random, low, high)
  if not ok or type(value) ~= "number" then return low end
  return clamp(math.floor(value), low, high)
end

local function titleSpeciesPool(title)
  local pool, ordered = {}, {}
  local pokemon = title and title.game and title.game.data
    and title.game.data.pokemon
  if type(pokemon) == "table" then
    for speciesId, def in pairs(pokemon) do
      local dex = type(def) == "table" and tonumber(def.dex)
      if type(speciesId) == "string" and dex and dex >= 1 and dex <= 151 then
        ordered[#ordered + 1] = { species = speciesId, dex = dex }
      end
    end
    table.sort(ordered, function(a, b)
      return a.dex == b.dex and a.species < b.species or a.dex < b.dex
    end)
    for _, item in ipairs(ordered) do
      pool[#pool + 1] = item.species
    end
  end
  if #pool == 0 then
    for _, speciesId in ipairs(title and title.cycleSpecies or {}) do
      if type(speciesId) == "string" and speciesId ~= "" then
        pool[#pool + 1] = speciesId
      end
    end
  end
  return pool
end

local function titleMascot(title, pool)
  local wanted = title and (title.yellow or title.yellowLayout) and "PIKACHU"
    or title and title.blue and "BLASTOISE" or "CHARIZARD"
  for i, speciesId in ipairs(pool) do
    if speciesId == wanted then return i, wanted end
  end
  return 1, pool[1]
end

local function titleRandomSelection(pool, currentSpecies)
  if #pool == 0 then return nil end
  local index = titleRandom(1, #pool)
  if #pool > 1 then
    local guard = 0
    while pool[index] == currentSpecies and guard < #pool * 2 do
      index = titleRandom(1, #pool)
      guard = guard + 1
    end
    if pool[index] == currentSpecies then index = index % #pool + 1 end
  end
  local shiny = titleRandom(1, TITLE_SHINY_ROLL) == 1
  return { index = index, species = pool[index], shiny = shiny,
    mon = { species = pool[index], shiny = shiny } }
end

local function titleScrollDistance(schedule, elapsedFrames)
  local remaining = math.max(0, math.floor(elapsedFrames))
  local distance = 0
  for _, step in ipairs(schedule) do
    local used = math.min(remaining, step[2])
    distance = distance + used * step[1]
    remaining = remaining - used
    if remaining <= 0 then break end
  end
  return distance
end

-- Legacy fallback used only when the standalone provider/API is unavailable.
-- Battle Art Replacer conflicts with this older provider, so it must never
-- override a Presentation API v1 result or that provider's deliberate nil.
local function legacyAnimatedTitleImage(title, species, shiny, fallback)
  local exports = title and title.game and title.game.mods
    and title.game.mods.exports
  local handle = exports and exports.BATTLE_ART_VOXEL_FORK
  local lib = handle and handle.lib
  if not (species and lib and type(lib.require) == "function") then return nil end
  local okArt, art = pcall(lib.require, "BattleArt")
  if not (okArt and art and art.setting and type(art.setting.get) == "function") then
    return nil
  end
  local okMode, mode = pcall(art.setting.get, art.setting)
  if not okMode then return nil end
  if mode ~= "animated" then return nil end

  local okAnimated, animated = pcall(lib.require, "AnimatedBattleArt")
  if not (okAnimated and animated and type(animated.update) == "function") then
    return nil
  end
  local bySpecies = titleBattleArtPreviews[title]
  if not bySpecies then
    bySpecies = {}
    titleBattleArtPreviews[title] = bySpecies
  end
  local preview = bySpecies[species]
  if not preview or preview.handle ~= handle or preview.fallback ~= fallback
      or preview.shiny ~= (shiny == true) then
    if preview and type(animated.finish) == "function" then
      pcall(animated.finish, preview.battle)
    end
    local mon = { species = species, shiny = shiny == true }
    local battler = { mon = mon, sprite = fallback }
    preview = {
      handle = handle,
      fallback = fallback,
      shiny = shiny == true,
      battler = battler,
      battle = { enemy = battler },
      lastTime = nil,
    }
    bySpecies[species] = preview
  end
  local now = love.timer and love.timer.getTime and love.timer.getTime()
              or os.clock()
  local dt = preview.lastTime and clamp(now - preview.lastTime, 0, 0.10) or 0
  preview.lastTime = now
  local ok = pcall(animated.update, preview.battle, dt)
  local image = ok and preview.battler.sprite or nil
  return image and image ~= fallback and image or nil
end

local function titleSpriteAt(title, selection)
  if not selection then return nil end
  local index, speciesId = selection.index, selection.species
  local original = title.cycleIndex
  title.cycleIndex = index
  local ok, image, trueColor = pcall(title.currentSprite, title)
  title.cycleIndex = original
  local mon = selection.mon or {
    species = speciesId, shiny = selection.shiny == true,
  }
  local providerSupplied = false
  if speciesId then
    local token = presentationToken(title, "title", speciesId)
    local presentation, providerOwned = providerPokemonPresentation(
      title.game, mon, "title", token)
    if presentation then
      image = presentation.image
      trueColor = presentation.trueColor ~= false
      ok, providerSupplied = true, true
    elseif providerOwned then
      providerSupplied = true
    end
  end
  if speciesId and not providerSupplied
      and type(BattleArtProviderImage) == "function" then
    local providerOk, providerImage = pcall(BattleArtProviderImage,
      title.game, mon, "front", "title")
    if providerOk and providerImage then
      image, trueColor, ok = providerImage, true, true
      providerSupplied = true
    end
  end
  if speciesId and selection.shiny and not providerSupplied
      and ShinyArtResolver and ShinyArtResolver(mon)
      and type(ShinyBattleImage) == "function" then
    local shinyOk, shinyImage = pcall(ShinyBattleImage,
      title.game, mon, "front")
    if shinyOk and shinyImage then
      image, trueColor, ok = shinyImage, true, true
      providerSupplied = true
    end
  end
  if speciesId and not providerSupplied then
    local animated = legacyAnimatedTitleImage(title, speciesId,
                                              selection.shiny,
                                              ok and image or nil)
    if animated then image, trueColor, ok = animated, true, true end
  end
  return {
    image = ok and image or nil,
    species = speciesId,
    trueColor = ok and trueColor or false,
  }
end

local function titlePresentationSprites(title)
  if not (title and type(title.currentSprite) == "function") then return nil end
  local pool = titleSpeciesPool(title)
  if #pool <= 1 then
    local item
    if #pool == 1 then
      title.cycleSpecies = pool
      item = titleSpriteAt(title, {
        index = 1, species = pool[1], shiny = false,
        mon = { species = pool[1], shiny = false },
      })
    else
      local ok, image, trueColor = pcall(title.currentSprite, title)
      item = { image = ok and image or nil, species = nil,
               trueColor = ok and trueColor or false }
    end
    return {
      current = item,
      offset = 0,
    }
  end
  local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
  local cycle = titlePresentationCycles[title]
  if not cycle then
    -- Own the list presented by currentSprite so its native cry/cache path
    -- remains aligned with the random species currently on screen.
    title.cycleSpecies = pool
    local initialIndex, initialSpecies = titleMascot(title, pool)
    local current = {
      index = initialIndex, species = initialSpecies, shiny = false,
      mon = { species = initialSpecies, shiny = false },
    }
    cycle = { pool = pool, current = current,
      next = titleRandomSelection(pool, initialSpecies), startedAt = now }
    title.cycleIndex = initialIndex
    titlePresentationCycles[title] = cycle
  end

  local function cycleFrames()
    local starterWait = TITLE_STARTERS[cycle.current.species] and 5 or 0
    return TITLE_HOLD_FRAMES + TITLE_OUT_FRAMES + 1 + starterWait
      + TITLE_IN_FRAMES
  end

  local elapsed = math.max(0, (now - cycle.startedAt) * 60)
  local guard = 0
  while elapsed >= cycleFrames() and guard < #cycle.pool * 2 do
    local completed = cycleFrames()
    cycle.current = cycle.next
    cycle.next = titleRandomSelection(cycle.pool, cycle.current.species)
    cycle.startedAt = cycle.startedAt + completed / 60
    elapsed = math.max(0, (now - cycle.startedAt) * 60)
    guard = guard + 1

    -- Keep native TitleState aligned so START plays the displayed species'
    -- cry, and suppress the engine's older linear-slide approximation.
    title.cycleIndex = cycle.current.index
    if type(title.timer) == "number" then title.timer = 0 end
    title.slideIn = nil
  end

  if elapsed < TITLE_HOLD_FRAMES then
    return { current = titleSpriteAt(title, cycle.current), offset = 0 }
  end
  elapsed = elapsed - TITLE_HOLD_FRAMES
  if elapsed < TITLE_OUT_FRAMES then
    return {
      current = titleSpriteAt(title, cycle.current),
      offset = -titleScrollDistance(TITLE_OUT_SCROLL, elapsed) * 3,
    }
  end
  elapsed = elapsed - TITLE_OUT_FRAMES
  local pause = 1 + (TITLE_STARTERS[cycle.current.species] and 5 or 0)
  if elapsed < pause then return { current = nil, offset = 0 } end
  elapsed = elapsed - pause
  return {
    current = titleSpriteAt(title, cycle.next),
    offset = (TITLE_IN_DISTANCE
      - titleScrollDistance(TITLE_IN_SCROLL, elapsed)) * 3,
  }
end

local function drawTitleBackdrop(title, fonts, viewW, viewH)
  local g = love.graphics
  setColor({ COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 1 })
  g.rectangle("fill", 0, 0, viewW, viewH)
  setColor(COLORS.accent)
  g.rectangle("fill", 0, 0, viewW, 6)
  local data = title and title.game and title.game.data
  local logoPal = PaletteFX and PaletteFX.pal and PaletteFX.pal(data, "LOGO2")
  local versionPal = PaletteFX and PaletteFX.pal and PaletteFX.pal(data, "LOGO1")
  local actorPal = PaletteFX and PaletteFX.pal and PaletteFX.pal(data, "MEWMON")
  -- The title card owns the full upper band. This keeps it large at 4:3 and
  -- 16:9 while leaving the lower-left region available for the menu panel.
  local logoW = math.min(460, viewW - 56)
  local logoX = math.floor((viewW - logoW) / 2)
  drawImageContained(title and title.logo, logoX, 14, logoW, 104, 4,
                     logoPal, true)
  if title and title.version and not title.yellow then
    drawTitleVersion(title, math.floor((viewW - 196) / 2), 116, 196, 28,
                     versionPal)
  end
  local artX, artW = math.floor(viewW * 0.49), math.floor(viewW * 0.47)
  local ground = viewH - 38
  if title and title.yellowLayout and title.phase ~= "loop" then
    -- Preserve Yellow's boot-only Pikachu drop/cry composition. Once the
    -- interactive title loop begins it joins the same mascot-first random
    -- presentation as Red and Blue.
    drawImageGrounded(title.yellowPikachu, artX + 24, ground, artW - 48,
                      viewH - 158, 3, actorPal, true)
  elseif title then
    local presentation = titlePresentationSprites(title)
    local slotW = math.floor(artW * 0.50)
    local function drawMon(item, x)
      if not item then return end
      local monPal = item.species and PaletteFX and PaletteFX.monPal
        and PaletteFX.monPal(data, item.species) or actorPal
      if item.trueColor then monPal = nil end
      drawImageGrounded(item.image, x, ground, slotW, viewH - 158, 3,
                        monPal, not item.trueColor)
    end
    if presentation then
      -- Keep the Pokemon in its own half of the art band, but let it rest
      -- closer to the trainer instead of hugging the left edge.
      local monRestOffset = math.floor(slotW * 0.15)
      drawMon(presentation.current,
              artX + monRestOffset + (presentation.offset or 0))
    end
    drawImageGrounded(title.player, artX + math.floor(artW * 0.50), ground,
                      math.floor(artW * 0.50), viewH - 154, 3, actorPal, true)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  local copyright = title and title.title and title.title.copyrightText
    or "2026 BOIS CLUB GAMES"
  g.print(cleanLabel(copyright), viewW - 20 - fonts.tiny:getWidth(cleanLabel(copyright)),
          viewH - 22)
end

local function drawTitleStandby(title, fonts, viewW, viewH)
  drawTitleBackdrop(title, fonts, viewW, viewH)
  local g = love.graphics
  g.setFont(fonts.small)
  setColor(COLORS.ink)
  local prompt = "PRESS START"
  local x = 24
  g.print(prompt, x, viewH - 54)
  setColor(COLORS.accent)
  g.rectangle("fill", x, viewH - 34, fonts.small:getWidth(prompt), 3)
end

local function drawTitleMenu(title, menu, fonts, viewW, viewH)
  local g = love.graphics
  drawTitleBackdrop(title, fonts, viewW, viewH)
  local items = menu.items or {}
  local panelW = math.min(300, math.floor(viewW * 0.47))
  local rowH = #items > 5 and 30 or 36
  local panelH = math.min(viewH - 36, 78 + #items * rowH)
  local x = 20
  local y = math.max(126, math.floor((viewH - panelH + 90) / 2))
  y = math.min(y, viewH - panelH - 12)
  drawPanel(x, y, panelW, panelH)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print("MAIN MENU", x + 18, y + 16)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 142, y + 29, panelW - 164, 3)
  local firstY = y + 54
  local selected = tonumber(menu.index) or 1
  for i, item in ipairs(items) do
    local ry = firstY + (i - 1) * rowH
    local isSelected = i == selected
    setColor(isSelected and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", x + 12, ry, panelW - 24, rowH - 5)
    if isSelected then
      setColor(COLORS.accent)
      g.rectangle("fill", x + 12, ry, 5, rowH - 5)
    end
    g.setFont(fonts.body)
    setColor(isSelected and COLORS.selectedText or COLORS.ink)
    g.print(fitLabel(fonts.body, cleanLabel(item.label or ""), panelW - 58),
            x + 28, ry + math.floor((rowH - 5 - fonts.body:getHeight()) / 2))
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print("A SELECT", x + 18, y + panelH - 24)
end

local function drawContinueInfo(title, info, fonts, viewW, viewH)
  local g = love.graphics
  drawTitleBackdrop(title, fonts, viewW, viewH)
  local save = info.save or {}
  local badges = 0
  local okBadges, Badges = pcall(require, "src.inventory.Badges")
  if okBadges and Badges and type(Badges.count) == "function" then
    local ok, count = pcall(Badges.count, info.game and info.game.data, save)
    if ok then badges = tonumber(count) or 0 end
  end
  local owned = 0
  for _ in pairs(save.pokedex and save.pokedex.owned or {}) do owned = owned + 1 end
  local seconds = math.floor(tonumber(save.playTime) or 0)
  local rows = {
    { "PLAYER", save.player and save.player.name or "RED" },
    { "BADGES", tostring(badges) },
    { "POKEDEX", tostring(owned) },
    { "TIME", ("%d:%02d"):format(math.floor(seconds / 3600),
                                    math.floor(seconds / 60) % 60) },
  }
  local w, h = math.min(390, viewW - 40), 260
  local x, y = 24, math.floor((viewH - h) / 2)
  drawPanel(x, y, w, h)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print("CONTINUE", x + 18, y + 16)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 132, y + 29, w - 154, 3)
  for i, row in ipairs(rows) do
    local ry = y + 58 + (i - 1) * 38
    setColor(COLORS.paper2)
    g.rectangle("fill", x + 14, ry, w - 28, 30)
    g.setFont(fonts.small)
    setColor(COLORS.muted)
    g.print(row[1], x + 26, ry + 7)
    setColor(COLORS.ink)
    g.print(row[2], x + w - 26 - fonts.small:getWidth(row[2]), ry + 7)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print("A CONTINUE     B BACK", x + 18, y + h - 24)
end

local function loadReportPresentationLines(state, fonts, maxWidth)
  local report = state.report or {}
  local out = {}
  local function add(text)
    for _, line in ipairs(wrapRenderedText(fonts.small, text, maxWidth)) do
      out[#out + 1] = line
    end
  end
  local function section(title, rows)
    if #rows == 0 then return end
    if #out > 0 then out[#out + 1] = "" end
    out[#out + 1] = title
    for _, row in ipairs(rows) do add("  " .. row) end
  end
  if report.recovered then add("SAVE RECOVERED FROM ." .. tostring(report.recovered)
    .. " BACKUP COPY") end
  local rows = {}
  for _, mon in ipairs(report.lostMons or {}) do
    rows[#rows + 1] = tostring(mon.species or "?") .. " ("
      .. tostring(mon.from or "?") .. ")"
  end
  section("MOVED TO LOST BOX", rows)
  rows = {}
  for _, item in ipairs(report.lostItems or {}) do
    rows[#rows + 1] = tostring(item.id or "?") .. " x"
      .. tostring(item.count or 1)
  end
  section("ITEMS REMOVED", rows)
  rows = {}
  for _, map in ipairs(report.remappedMaps or {}) do
    rows[#rows + 1] = tostring(map.id or "?") .. "  ->  "
      .. tostring(map.to or map.field or "?")
  end
  section("LOCATION RESET", rows)
  rows = {}
  for _, mon in ipairs(report.restoredMons or {}) do
    rows[#rows + 1] = tostring(mon.species or "?") .. " TO BOX "
      .. tostring(mon.box or 0)
  end
  for _, item in ipairs(report.restoredItems or {}) do
    rows[#rows + 1] = tostring(item.id or "?") .. " x"
      .. tostring(item.count or 1)
  end
  section("RESTORED", rows)
  local okSave, SaveData = pcall(require, "src.core.SaveData")
  if okSave and SaveData and type(SaveData.modsDiffNotice) == "function" then
    local ok, notice = pcall(SaveData.modsDiffNotice, report.modsDiff,
      state.game and state.game.save and state.game.save.meta)
    if ok and notice then
      -- SaveData deliberately exposes a compact one-line notice. The wide
      -- report is a reading surface, so promote every semicolon/comma clause
      -- to an independent row instead of wrapping mid-sentence.
      local noticeRows = {}
      for row in tostring(notice):gmatch("[^;,]+") do
        row = row:match("^%s*(.-)%s*$")
        if row ~= "" then noticeRows[#noticeRows + 1] = row end
      end
      section("MOD CONFIGURATION", noticeRows)
    end
  elseif #out == 0 and type(state.lines) == "table" then
    for _, line in ipairs(state.lines) do out[#out + 1] = line end
  end
  if #out == 0 then out[1] = "NO LOAD CHANGES REPORTED" end
  return out
end

local function drawLoadReport(state, fonts, viewW, viewH)
  local g = love.graphics
  setColor({ COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 1 })
  g.rectangle("fill", 0, 0, viewW, viewH)
  local x, y, w, h = 18, 18, viewW - 36, viewH - 36
  drawPanel(x, y, w, h)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print("LOAD REPORT", x + 18, y + 16)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 166, y + 29, w - 188, 3)
  local lines = loadReportPresentationLines(state, fonts, w - 52)
  local visible = math.max(1, math.floor((h - 94) / 20))
  local offset = clamp(tonumber(state.offset) or 0, 0, math.max(0, #lines - visible))
  g.setFont(fonts.small)
  for row = 1, visible do
    local line = lines[offset + row]
    if not line then break end
    setColor(line ~= "" and COLORS.ink or COLORS.muted)
    g.print(fitLabel(fonts.small, cleanLabel(line), w - 52),
            x + 24, y + 54 + (row - 1) * 20)
  end
  if offset + visible < #lines then
    setColor(COLORS.accent)
    g.polygon("fill", x + w - 34, y + h - 32,
      x + w - 18, y + h - 32, x + w - 26, y + h - 22)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  local position = ("%d / %d"):format(math.min(#lines, offset + 1), #lines)
  g.print("UP / DOWN  SCROLL     A / B / START  CONTINUE", x + 20, y + h - 25)
  g.print(position, x + w - 20 - fonts.tiny:getWidth(position), y + h - 25)
end

local OPTION_HELP = {
  textSpeed = "Controls how quickly dialogue characters appear.",
  animations = "Enables or disables move animations during battle.",
  battleStyle = "SHIFT offers a switch after a foe faints. SET does not.",
  battleLayout = "Chooses the classic battle canvas or the wide composition.",
  battleFit = "FIXED keeps integer pixels. FILL expands battle to the window.",
  battleBg = "Chooses what appears around and behind the battle presentation.",
  uiLayout = "Chooses fixed classic placement or dynamic window-edge docking.",
  ruleset = "Selects the active battle-mechanics ruleset.",
  musicVol = "Adjusts music volume from OFF through level 7.",
  sfxVol = "Adjusts sound-effect volume from OFF through level 7.",
  pikaVol = "Adjusts the volume of Pikachu voice clips in Yellow.",
  musicFilter = "Applies progressively stronger low-pass filtering to music.",
  performance = "Selects the performance tier used by advanced rendering.",
  colors = "Selects the active Game Boy, SGB, GBC or enhanced color treatment.",
  tilt = "Adjusts the 3D tilt level used by the world renderer.",
  gbcfx = "Adjusts Game Boy Color-style display effects.",
  zoom = "Offsets the overworld survey zoom from its fitted level.",
  voidFill = "Chooses how empty space beyond map geometry is presented.",
  videoMode = "Changes the active window or fullscreen presentation mode.",
  orientation = "Locks the display orientation on supported mobile devices.",
  faithfulRes = "Locks the window to an exact multiple of 160 by 144.",
  fpsCap = "Sets the maximum presentation frame rate.",
  speed = "Changes game logic speed without changing music pitch.",
  mods = "Opens the installed-mod manager.",
  controls = "Opens controller and keyboard binding settings.",
  touchControls = "Enables or disables the on-screen touch pad.",
  haptics = "Selects touch-control vibration strength.",
}

local function optionRowValue(row, game)
  if not (row and type(row.value) == "function") then return nil end
  local ok, value = pcall(row.value, game)
  if not ok or value == nil then return nil end
  return cleanLabel(value)
end

local function drawOptionsMenu(state, fonts, viewW, viewH, config)
  config = config or {}
  local g = love.graphics
  setColor({ COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 1 })
  g.rectangle("fill", 0, 0, viewW, viewH)
  setColor(COLORS.accent)
  g.rectangle("fill", 0, 0, viewW, 6)

  local rows = config.rows or state.rows or {}
  local includeCancel = config.includeCancel ~= false
  local lastIndex = #rows + (includeCancel and 1 or 0)
  if lastIndex < 1 then lastIndex = 1 end
  local index = clamp(tonumber(config.index or state.index) or 1, 1, lastIndex)
  local selected = index <= #rows and rows[index] or {
    id = "cancel", label = "CANCEL",
  }
  local selectedLabel = cleanLabel(selected.label or "OPTION")
  local selectedValue = optionRowValue(selected, state.game)

  local detailX, detailY, detailW, detailH = 18, 54, 220, viewH - 90
  drawPanel(detailX, detailY, detailW, detailH)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print(fitLabel(fonts.body, selectedLabel, detailW - 36),
          detailX + 16, detailY + 16)
  setColor(COLORS.accent)
  g.rectangle("fill", detailX + 16, detailY + 43, detailW - 32, 3)

  if selectedValue then
    g.setFont(fonts.tiny)
    setColor(COLORS.muted)
    g.print("CURRENT", detailX + 16, detailY + 62)
    setColor(COLORS.paper2)
    g.rectangle("fill", detailX + 14, detailY + 82, detailW - 28, 38)
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    local valueText = fitLabel(fonts.small, selectedValue, detailW - 62)
    g.print(valueText,
      detailX + math.floor((detailW - fonts.small:getWidth(valueText)) / 2),
      detailY + 91)
    if selected.step then
      g.print("<", detailX + 25, detailY + 91)
      g.print(">", detailX + detailW - 34, detailY + 91)
    end
  end

  local help = config.help and config.help(selected) or OPTION_HELP[selected.id]
  if not help then
    if selected.activate then
      help = "Open " .. selectedLabel .. "."
    elseif selected.step then
      help = "Adjust this option. This row may be supplied by another mod."
    else
      help = "Return to the previous screen."
    end
  end
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  local helpY = detailY + (selectedValue and 138 or 66)
  for i, line in ipairs(wrapRenderedText(fonts.small, help, detailW - 32)) do
    if i > 5 then break end
    g.print(line, detailX + 16, helpY + (i - 1) * 20)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.ink)
  local action = selected.activate and "A OPEN"
    or selected.step and "LEFT / RIGHT CHANGE"
    or "A CLOSE"
  g.print(action, detailX + 16, detailY + detailH - 28)

  local listX, listY = 250, 20
  local listW, listH = viewW - listX - 18, viewH - 38
  drawPanel(listX, listY, listW, listH)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print(fitLabel(fonts.body, config.title or "OPTIONS", listW - 170),
          listX + 18, listY + 14)
  setColor(COLORS.accent)
  g.rectangle("fill", listX + 132, listY + 27, listW - 152, 3)

  local visible = math.max(4, math.floor((listH - 64) / 31))
  local total = lastIndex
  local maxStart = math.max(1, total - visible + 1)
  local first = clamp(index - math.floor(visible / 2), 1, maxStart)
  local rowY = listY + 49
  for slot = 1, visible do
    local rowIndex = first + slot - 1
    if rowIndex > total then break end
    local row = rowIndex <= #rows and rows[rowIndex]
      or { id = "cancel", label = "CANCEL" }
    local active = rowIndex == index
    local y = rowY + (slot - 1) * 31
    setColor(active and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", listX + 12, y, listW - 24, 27)
    if active then
      setColor(COLORS.accent)
      g.rectangle("fill", listX + 12, y, 5, 27)
    end
    g.setFont(fonts.small)
    setColor(active and COLORS.selectedText or COLORS.ink)
    local label = fitLabel(fonts.small, cleanLabel(row.label or ""),
                           math.floor((listW - 48) * 0.60))
    g.print(label, listX + 27, y + 5)
    local value = rowIndex <= #rows and optionRowValue(row, state.game) or nil
    if value then
      local maxValueW = math.floor((listW - 48) * 0.38)
      value = fitLabel(fonts.small, value, maxValueW)
      g.print(value, listX + listW - 26 - fonts.small:getWidth(value), y + 5)
    elseif row.activate then
      g.print(">", listX + listW - 34, y + 5)
    end
  end
  if first > 1 then
    setColor(COLORS.accent)
    g.polygon("fill", listX + listW - 34, listY + 14,
      listX + listW - 18, listY + 14, listX + listW - 26, listY + 5)
  end
  if first + visible - 1 < total then
    setColor(COLORS.accent)
    g.polygon("fill", listX + listW - 34, listY + listH - 18,
      listX + listW - 18, listY + listH - 18,
      listX + listW - 26, listY + listH - 8)
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print(config.footer or "UP / DOWN SELECT     B / START CLOSE",
          20, viewH - 25)
end

local MANAGER_TITLES = {
  list = "MOD MANAGER", detail = "MOD DETAILS", permissions = "PERMISSIONS",
  errors = "MOD ERRORS", apply = "PENDING CHANGES",
}

local function managerRows(state)
  if not (state and type(state.rowsForScreen) == "function") then return {} end
  local ok, rows = pcall(state.rowsForScreen, state)
  return ok and type(rows) == "table" and rows or {}
end

local function managerIsStaged(state, modInfo)
  if not (modInfo and type(state.isStaged) == "function") then return false end
  local ok, staged = pcall(state.isStaged, state, modInfo)
  return ok and staged and true or false
end

local function drawManagerOverlay(state, fonts, viewW, viewH)
  local overlay = state.overlay
  if not overlay then return end
  local lines = {}
  for _, raw in ipairs(overlay.lines or {}) do
    for _, line in ipairs(wrapRenderedText(fonts.small, raw, 360)) do
      lines[#lines + 1] = line
    end
  end
  local w = math.min(420, viewW - 70)
  local h = math.min(viewH - 50, 92 + #lines * 20
    + (overlay.kind == "confirm" and 54 or 22))
  local x, y = math.floor((viewW - w) / 2), math.floor((viewH - h) / 2)
  drawPanel(x, y, w, h)
  love.graphics.setFont(fonts.body)
  setColor(COLORS.ink)
  love.graphics.print(overlay.kind == "confirm" and "CONFIRM" or "NOTICE",
                      x + 18, y + 16)
  setColor(COLORS.accent)
  love.graphics.rectangle("fill", x + 126, y + 29, w - 148, 3)
  love.graphics.setFont(fonts.small)
  for i, line in ipairs(lines) do
    setColor(COLORS.ink)
    love.graphics.print(line, x + 22, y + 54 + (i - 1) * 20)
  end
  if overlay.kind == "confirm" then
    local baseY = y + h - 70
    for i, label in ipairs({ "YES", "NO" }) do
      local active = (tonumber(overlay.index) or 1) == i
      setColor(active and COLORS.selected or COLORS.paper2)
      love.graphics.rectangle("fill", x + 22, baseY + (i - 1) * 30,
                              w - 44, 26)
      if active then
        setColor(COLORS.accent)
        love.graphics.rectangle("fill", x + 22, baseY + (i - 1) * 30, 5, 26)
      end
      setColor(active and COLORS.selectedText or COLORS.ink)
      love.graphics.print(label, x + 38, baseY + 4 + (i - 1) * 30)
    end
  else
    love.graphics.setFont(fonts.tiny)
    setColor(COLORS.muted)
    love.graphics.print("A OK", x + 22, y + h - 28)
  end
end

local function drawModManager(state, fonts, viewW, viewH)
  if state.screen == "options" then
    local modInfo = state.currentMod or {}
    drawOptionsMenu(state, fonts, viewW, viewH, {
      rows = state.optionRows or {}, index = state.cursor,
      includeCancel = false,
      title = fitLabel(fonts.body,
        cleanLabel((modInfo.name or modInfo.id or "MOD") .. " OPTIONS"), 220),
      footer = state.notice or "LEFT / RIGHT CHANGE     A OPEN     B DONE",
      help = function(row)
        if row.id == "__reset" then return "Restore every option for this mod to its declared default." end
        return "Adjust this mod setting. Changes are saved without restarting unless the mod states otherwise."
      end,
    })
    drawManagerOverlay(state, fonts, viewW, viewH)
    return
  end

  local g = love.graphics
  setColor({ COLORS.paper[1], COLORS.paper[2], COLORS.paper[3], 1 })
  g.rectangle("fill", 0, 0, viewW, viewH)
  setColor(COLORS.accent)
  g.rectangle("fill", 0, 0, viewW, 6)
  local rows = managerRows(state)
  local cursor = clamp(tonumber(state.cursor) or 1, 1, math.max(1, #rows))
  local focused = rows[cursor]
  local title = MANAGER_TITLES[state.screen] or "MOD MANAGER"

  local listX, listY, listW, listH = 18, 20, 350, viewH - 58
  drawPanel(listX, listY, listW, listH)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print(title, listX + 16, listY + 13)
  setColor(COLORS.accent)
  g.rectangle("fill", listX + 154, listY + 27, listW - 174, 3)

  local contentY = listY + 48
  if state.screen == "list" then
    local tabs = { "MODS", "PROFILES", "ERRORS" }
    local tabW = math.floor((listW - 24) / 3)
    for i, label in ipairs(tabs) do
      local active = (tonumber(state.tab) or 1) == i
      setColor(active and COLORS.selected or COLORS.paper2)
      g.rectangle("fill", listX + 12 + (i - 1) * tabW, contentY,
                  tabW - 4, 25)
      g.setFont(fonts.tiny)
      setColor(active and COLORS.selectedText or COLORS.ink)
      g.print(label, listX + 22 + (i - 1) * tabW, contentY + 6)
    end
    contentY = contentY + 34
  end

  local visible = math.max(5, math.floor((listY + listH - 18 - contentY) / 28))
  local maxStart = math.max(1, #rows - visible + 1)
  local first = clamp(cursor - math.floor(visible / 2), 1, maxStart)
  for slot = 1, visible do
    local rowIndex = first + slot - 1
    local row = rows[rowIndex]
    if not row then break end
    local y = contentY + (slot - 1) * 28
    if row.header then
      g.setFont(fonts.tiny)
      setColor(COLORS.muted)
      g.print(fitLabel(fonts.tiny, cleanLabel(row.label or ""), listW - 42),
              listX + 18, y + 7)
    else
      local active = rowIndex == cursor
      setColor(active and COLORS.selected or COLORS.paper2)
      g.rectangle("fill", listX + 12, y, listW - 24, 25)
      if active then
        setColor(COLORS.accent)
        g.rectangle("fill", listX + 12, y, 5, 25)
      end
      g.setFont(fonts.small)
      setColor(active and COLORS.selectedText or COLORS.ink)
      local prefix = row.glyph and row.glyph ~= " " and row.glyph .. " " or ""
      g.print(fitLabel(fonts.small, prefix .. cleanLabel(row.label or ""),
                       listW - 82), listX + 27, y + 4)
      if row.mod then
        local cx, cy = listX + listW - 29, y + 12
        local enabled = row.mod.enabled == true
        setColor(enabled and COLORS.enabled or COLORS.disabled)
        if type(g.setLineWidth) == "function" then g.setLineWidth(3) end
        if type(g.line) == "function" then
          if enabled then
            g.line(cx - 6, cy, cx - 2, cy + 4)
            g.line(cx - 2, cy + 4, cx + 7, cy - 6)
          else
            g.line(cx - 6, cy - 6, cx + 6, cy + 6)
            g.line(cx + 6, cy - 6, cx - 6, cy + 6)
          end
        else
          g.print(enabled and "V" or "X", cx - 4, cy - 7)
        end
        if type(g.setLineWidth) == "function" then g.setLineWidth(1) end
      end
    end
  end

  local detailX, detailY, detailW, detailH = 380, 20, viewW - 398, viewH - 58
  drawPanel(detailX, detailY, detailW, detailH)
  local modInfo = focused and focused.mod or state.currentMod
  local detailTitle = modInfo and (modInfo.name or modInfo.id)
    or focused and focused.label or title
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  g.print(fitLabel(fonts.body, cleanLabel(detailTitle or title), detailW - 32),
          detailX + 16, detailY + 14)
  setColor(COLORS.accent)
  g.rectangle("fill", detailX + 16, detailY + 41, detailW - 32, 3)

  local infoY = detailY + 58
  if modInfo then
    g.setFont(fonts.small)
    setColor(modInfo.enabled and COLORS.enabled or COLORS.disabled)
    local status = modInfo.enabled and "ENABLED" or "DISABLED"
    if managerIsStaged(state, modInfo) then status = status .. " / STAGED" end
    g.print(status, detailX + 16, infoY)
    setColor(COLORS.muted)
    g.print(fitLabel(fonts.small,
      cleanLabel((modInfo.version or "") .. "  " .. (modInfo.category or "OTHER")),
      detailW - 32), detailX + 16, infoY + 22)
    local description = modInfo.error and ("FAILED: " .. tostring(modInfo.error))
      or modInfo.description or "No description supplied."
    for i, line in ipairs(wrapRenderedText(fonts.small, description, detailW - 32)) do
      if i > 7 then break end
      g.print(line, detailX + 16, infoY + 54 + (i - 1) * 19)
    end
  elseif state.screen == "apply" and type(state.stagedList) == "function" then
    local ok, staged = pcall(state.stagedList, state)
    staged = ok and staged or {}
    g.setFont(fonts.small)
    setColor(COLORS.muted)
    g.print(tostring(#staged) .. " MOD CHANGES WAITING", detailX + 16, infoY)
    for i, entry in ipairs(staged) do
      if i > 8 then break end
      g.print((entry.enabled and "ON  " or "OFF ")
        .. cleanLabel(entry.name or entry.id), detailX + 16, infoY + i * 21)
    end
  else
    g.setFont(fonts.small)
    setColor(COLORS.muted)
    local detail = focused and cleanLabel(focused.label or "")
      or "No entry selected."
    for i, line in ipairs(wrapRenderedText(fonts.small, detail, detailW - 32)) do
      if i > 8 then break end
      g.print(line, detailX + 16, infoY + (i - 1) * 20)
    end
  end

  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  local footer = state.notice or (state.screen == "list"
    and "A OPEN   SELECT TOGGLE   START APPLY   B EXIT"
    or "A CHOOSE   B BACK")
  g.print(fitLabel(fonts.tiny, cleanLabel(footer), viewW - 40), 20, viewH - 25)
  drawManagerOverlay(state, fonts, viewW, viewH)
end

local function bundledPartyIcon(mod, mon, selected, counter)
  if not (Assets and love and love.graphics and mon and mon.species) then
    return nil
  end
  local species = tostring(mon.species):upper():gsub("[^A-Z0-9]", "")
  local dex = PARTY_ICON_DEX[species]
  if not dex then return nil end
  local path = mod.assets:path("party_icons.png")
  local cached = partyIconSheetCache[path]
  if cached == nil then
    local ok, image = pcall(Assets.image, path)
    if ok and image and type(image.getDimensions) == "function" then
      local iw, ih = image:getDimensions()
      if iw == 512 and ih == 640 then
        if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
        if image.setWrap then pcall(image.setWrap, image, "clamp", "clamp") end
        cached = { image = image, iw = iw, ih = ih, quads = {} }
      end
    end
    cached = cached or false
    partyIconSheetCache[path] = cached
  end
  if cached == false then return nil end

  local maxHP = mon.stats and mon.stats.hp or 1
  local hp = mon.hp or maxHP
  local pixels = math.floor(hp * 48 / math.max(1, maxHP))
  local speed = pixels >= 27 and 10 or pixels >= 10 and 20 or 32
  local alternate = math.floor((counter or 0) / speed) % 2 == 1
  local frame = alternate and 2 or 1
  local key = dex * 2 + frame
  local quad = cached.quads[key]
  if not quad then
    local zero = dex - 1
    local x = (zero % 16) * 32
    local y = math.floor(zero / 16) * 64 + (frame - 1) * 32
    quad = love.graphics.newQuad(x, y, 32, 32, cached.iw, cached.ih)
    cached.quads[key] = quad
  end
  return cached.image, quad
end

local function nativePartyIcon(game, mon, selected, counter)
  if not (Assets and love and love.graphics and mon and mon.species) then
    return nil
  end
  local icons = game and game.data and game.data.icons
  local entry = icons and icons.bySpecies and icons.bySpecies[mon.species]
  local path
  if type(entry) == "table" then
    local shiny = ShinyArtResolver and ShinyArtResolver(mon)
    if shiny == nil then
      shiny = mon.shiny == true
        or (Stats and Stats.isShiny and Stats.isShiny(mon.dvs))
    end
    path = shiny and entry.shinyImage or entry.image
  end
  if type(path) ~= "string" or path == "" then return nil end

  local cached = partyIconSheetCache[path]
  if cached == nil then
    local ok, image = pcall(Assets.image, path)
    if ok and image and type(image.getDimensions) == "function" then
      local iw, ih = image:getDimensions()
      if iw == 32 and ih == 64 then
        if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
        if image.setWrap then pcall(image.setWrap, image, "clamp", "clamp") end
        cached = {
          image = image,
          quads = {
            love.graphics.newQuad(0, 0, 32, 32, iw, ih),
            love.graphics.newQuad(0, 32, 32, 32, iw, ih),
          },
        }
      end
    end
    cached = cached or false
    partyIconSheetCache[path] = cached
  end
  if cached == false then return nil end

  local alternate = false
  if selected then
    local maxHP = mon.stats and mon.stats.hp or 1
    local hp = mon.hp or maxHP
    local pixels = math.floor(hp * 48 / math.max(1, maxHP))
    local speed = pixels >= 27 and 5 or pixels >= 10 and 16 or 32
    alternate = math.floor((counter or 0) / speed) % 2 == 1
  end
  return cached.image, cached.quads[alternate and 2 or 1]
end

local function drawPartyIcon(mod, PartyMenu, menu, mon, x, y, selected)
  local g = love.graphics
  g.push("all")
  setColor({ 1, 1, 1, 1 })
  -- Prefer the currently registered 32x64 icon descriptor. This lets a
  -- focused icon provider (such as hgss_menu_icons) own the artwork while
  -- retaining the widescreen atlas as a no-dependency fallback.
  local image, quad = nativePartyIcon(menu.game, mon, selected, menu.blink or 0)
  if not image then
    image, quad = bundledPartyIcon(mod, mon, selected, menu.blink or 0)
  end
  if image and quad then
    -- Modern icon packs author 32x32 frames. Drawing them directly on this
    -- 640x360 surface avoids the stock 32 -> 16 -> output-size round trip.
    g.draw(image, quad, x, y)
    if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
      PaletteFX.markTrueColor(x, y, 32, 32)
    end
  else
    g.translate(x, y)
    g.scale(2, 2)
    PartyMenu.drawIcon(menu.game, mon, 0, 0, selected, menu.blink or 0)
  end
  g.pop()
end

local function partyBattlePaletteKey(data, species)
  if not PaletteFX then return "none", nil end
  local colors = PaletteFX.monPal(data, species)
  if not colors then return "none", nil end
  local name = PaletteFX.monPalName(data, species) or "MON"
  if PaletteFX.usesGbcPack and PaletteFX.usesGbcPack() then
    name = "redpp:" .. name
  end
  return name, colors
end

-- This follows the same live resolver used by battle presentation. The path
-- is deliberately resolved every frame: an enabled sprite mod may select a
-- different generated variant while the game is running, and caching the
-- resolver result would pin this panel to stale art.
local function engineBattleSpriteImage(game, mon)
  if not (PokemonSprites and Assets and game and game.data
      and mon and mon.species) then return nil end

  local path, trueColor = PokemonSprites.path(
    game.data, mon.species, "front", { mon = mon, kind = "battle" })
  if not path then return nil end

  local palName, colors = partyBattlePaletteKey(game.data, mon.species)
  local key = path .. "|" .. (trueColor and "truecolor" or palName)
  local cached = partyBattleSpriteCache[key]
  if cached then return cached end

  local image
  if trueColor or not colors or not (love.image and love.image.newImageData) then
    image = Assets.image(path)
  else
    local id = Assets.imageData(path)
    if id then
      id:mapPixel(function(_, _, r, green, blue, alpha)
        if alpha == 0 then return r, green, blue, alpha end
        local color = r > 0.83 and colors[1]
          or r > 0.50 and colors[2]
          or r > 0.17 and colors[3]
          or colors[4]
        return color[1] / 255, color[2] / 255, color[3] / 255, alpha
      end)
      image = love.graphics.newImage(id)
    end
  end

  if image and image.setFilter then
    image:setFilter("nearest", "nearest")
  end
  partyBattleSpriteCache[key] = image
  return image
end

local battleArtPreview = setmetatable({}, { __mode = "k" })

local function battleArtModules(game)
  local exports = game and game.mods and game.mods.exports
  local handle = exports and exports.BATTLE_ART_VOXEL_FORK
  local lib = handle and handle.lib
  if not (lib and type(lib.require) == "function") then return nil end
  local okArt, art = pcall(lib.require, "BattleArt")
  if not (okArt and art) then return nil end
  local okAnimated, animated = pcall(lib.require, "AnimatedBattleArt")
  return art, okAnimated and animated or nil, handle
end

-- BATTLE_ART_VOXEL_FORK applies its STATIC/ANIMATED images directly to the
-- battler after the engine's pokemon.sprite resolver has run. Consult its
-- exported modules first so Party sees the same selected collection. ROM and
-- missing-pack cases fall back to the normal engine resolver.
selectedBattleSpriteImage = function(game, mon, purpose, tokenOwner)
  purpose = purpose or "portrait"
  local token = presentationToken(tokenOwner or mon, purpose,
                                  mon and mon.species)
  local presentation, providerOwned = providerPokemonPresentation(
    game, mon, purpose, token)
  if presentation then return presentation.image, nil end
  if providerOwned then return engineBattleSpriteImage(game, mon), nil end
  if type(BattleArtProviderImage) == "function" then
    local ok, image = pcall(BattleArtProviderImage, game, mon, "front", "portrait")
    if ok and image then return image, nil end
  end
  if ShinyArtResolver and ShinyArtResolver(mon)
      and type(ShinyBattleImage) == "function" then
    local ok, image = pcall(ShinyBattleImage, game, mon, "front")
    if ok and image then return image, nil end
  end
  local fallback = engineBattleSpriteImage(game, mon)
  local art, animated, handle = battleArtModules(game)
  if not art then return fallback, nil end

  local okMode, mode = pcall(art.setting.get, art.setting)
  if not okMode or mode == "rom" then return fallback, nil end

  if mode == "static" then
    local ok, image = pcall(art.image, mon.species, "front")
    if ok and image then
      local metric = type(art.metrics) == "function" and art.metrics(image)
      return image, metric
    end
    return fallback, nil
  end

  if mode == "animated" and animated
      and type(animated.update) == "function" then
    local preview = battleArtPreview[mon]
    if not preview or preview.handle ~= handle or preview.fallback ~= fallback then
      if preview and type(animated.finish) == "function" then
        pcall(animated.finish, preview.battle)
      end
      local battler = { mon = mon, sprite = fallback }
      preview = {
        handle = handle,
        fallback = fallback,
        battler = battler,
        battle = { enemy = battler },
        lastTime = nil,
      }
      battleArtPreview[mon] = preview
    end
    local now = love.timer and love.timer.getTime and love.timer.getTime()
                or os.clock()
    local dt = preview.lastTime and clamp(now - preview.lastTime, 0, 0.10) or 0
    preview.lastTime = now
    -- AnimatedBattleArt owns atlas cells and durations; advancing its preview
    -- battler makes UI portraits obey the same selected generation and timing
    -- without treating Dramatic Shape's Stadium models as 2D images.
    local ok = pcall(animated.update, preview.battle, dt)
    local image = ok and preview.battler.sprite or nil
    if image and image ~= fallback then
      local metric = type(art.metrics) == "function" and art.metrics(image)
      return image, metric
    end
  end

  return fallback, nil
end

drawPartyBattleSprite = function(game, mon, x, y, w, h, overscan,
                                 purpose, tokenOwner)
  local image, metric = selectedBattleSpriteImage(game, mon, purpose, tokenOwner)
  if not image then return false end
  local iw, ih = image:getDimensions()
  if not iw or not ih or iw <= 0 or ih <= 0 then return false end

  local sourceX, sourceY, frameW, frameH = 0, 0, iw, ih
  if metric and metric.x0 and metric.x1 and metric.y0 and metric.y1 then
    sourceX, sourceY = metric.x0, metric.y0
    frameW = metric.x1 - metric.x0 + 1
    frameH = metric.y1 - metric.y0 + 1
  elseif iw >= ih * 2 and iw % ih == 0 then
    frameW = ih
  elseif ih >= iw * 2 and ih % iw == 0 then
    frameH = iw
  end
  local scale = math.min(w / frameW, h / frameH)
  -- Wide silhouettes naturally look much shorter when fitted only by width.
  -- The compact Party panel may opt into a small bounded boost, aiming for
  -- three quarters of its portrait height while allowing at most the supplied
  -- overscan. This covers Kadabra and the same issue in Golbat, Geodude,
  -- Goldeen, Aerodactyl, Zubat, etc. without per-species exceptions.
  overscan = math.max(1, tonumber(overscan) or 1)
  if overscan > 1 then
    local shownHeight = frameH * scale
    local targetHeight = h * 0.75
    local boost = shownHeight > 0 and targetHeight / shownHeight or 1
    scale = scale * clamp(boost, 1, overscan)
  end
  if scale <= 0 then return false end
  local dx = math.floor(x + (w - frameW * scale) / 2 + 0.5)
  local dy = math.floor(y + (h - frameH * scale) / 2 + 0.5)

  setColor({ 1, 1, 1, 1 })
  if sourceX ~= 0 or sourceY ~= 0 or frameW ~= iw or frameH ~= ih then
    local quad = love.graphics.newQuad(sourceX, sourceY,
                                      frameW, frameH, iw, ih)
    love.graphics.draw(image, quad, dx, dy, 0, scale, scale)
  else
    love.graphics.draw(image, dx, dy, 0, scale, scale)
  end
  return true
end

local function canLearnTM(menu, mon)
  if not (menu.tmhm and mon) then return nil end
  local def = monDefinition(menu.game, mon)
  for _, moveId in ipairs((def and def.tmhm) or {}) do
    if moveId == menu.tmhm.move then return true end
  end
  return false
end

local function drawPartyRows(mod, menu, PartyMenu, fonts, x, y, w)
  local g = love.graphics
  local party = menu.party or (menu.game.save and menu.game.save.party) or {}
  local rowH = 44

  -- Decorations first, labels second. This keeps selection fills from ever
  -- painting over glyphs, matching the START menu's overlap fix.
  for i = 1, math.min(6, #party) do
    local ry = y + (i - 1) * rowH
    setColor(i == menu.index and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", x, ry, w, rowH - 3)
    if i == menu.index then
      setColor(COLORS.accent)
      g.rectangle("fill", x, ry, 5, rowH - 3)
    end
  end

  g.setFont(fonts.body)
  for i = 1, math.min(6, #party) do
    local mon = party[i]
    local ry = y + (i - 1) * rowH
    local selected = i == menu.index
    local maxHP = math.max(1, mon.stats and mon.stats.hp or 1)
    local hp = shownHP(menu, mon)
    drawPartyIcon(mod, PartyMenu, menu, mon, x + 9, ry + 4, selected)

    setColor(selected and COLORS.selectedText or COLORS.ink)
    drawPokemonLabel(fonts.body, monName(menu.game, mon),
      x + 49, ry + 4, w - 135)
    local level = "Lv." .. tostring(mon.level or "?")
    g.print(level, x + w - 10 - fonts.body:getWidth(level), ry + 4)

    g.setFont(fonts.small)
    local able = canLearnTM(menu, mon)
    if able ~= nil then
      local label = able and "ABLE" or "NOT ABLE"
      setColor(able and { 0.12, 0.55, 0.23, 1 }
                       or { 0.70, 0.16, 0.12, 1 })
      g.print(label, x + 49, ry + 24)
    else
      setColor(selected and COLORS.selectedText or COLORS.muted)
      g.print("HP", x + 49, ry + 24)
      drawHPBar(x + 72, ry + 28, 112, hp, maxHP)
      setColor(selected and COLORS.selectedText or COLORS.ink)
      local hpText = string.format("%d/%d", hp, maxHP)
      g.print(hpText, x + w - 10 - fonts.small:getWidth(hpText), ry + 22)
    end
    g.setFont(fonts.body)
  end
end

local function updateSubmenuScroll(menu, visible)
  local count = #(menu.subItems or {})
  local index = clamp(tonumber(menu.subIndex) or 1, 1, math.max(1, count))
  local maxScroll = math.max(0, count - visible)
  local scroll = clamp(tonumber(menu.__wideUiSubScroll) or 0, 0, maxScroll)
  if index <= scroll then
    scroll = index - 1
  elseif index > scroll + visible then
    scroll = index - visible
  end
  menu.__wideUiSubScroll = clamp(scroll, 0, maxScroll)
  return menu.__wideUiSubScroll
end

local function statValue(mon, ...)
  local stats = mon and mon.stats or {}
  for i = 1, select("#", ...) do
    local value = stats[select(i, ...)]
    if value ~= nil then return tostring(math.floor(value)) end
  end
  return "-"
end

local function drawPartySidePanel(menu, fonts, x, y, w, h)
  local g = love.graphics
  drawPanel(x, y, w, h)
  local party = menu.party or (menu.game.save and menu.game.save.party) or {}
  local mon = party[clamp(menu.index or 1, 1, math.max(1, #party))]
  local showShiny = not menu.submenu and pokemonIsShiny(mon)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print(menu.submenu and "ACTIONS" or "DETAILS", x + 14, y + 12)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 102, y + 21, w - 118 - (showShiny and 22 or 0), 3)
  if showShiny then drawShinyStarIcon(x + w - 34, y + 10, 16) end

  if menu.submenu and menu.subItems then
    local rowH, listY = 24, y + 43
    local visible = math.max(1, math.floor((h - 56) / rowH))
    local scroll = updateSubmenuScroll(menu, visible)

    -- Background pass.
    for slot = 1, visible do
      local index = scroll + slot
      if not menu.subItems[index] then break end
      if index == menu.subIndex then
        local ry = listY + (slot - 1) * rowH
        setColor(COLORS.selected)
        g.rectangle("fill", x + 9, ry, w - 18, rowH - 2)
        setColor(COLORS.accent)
        g.rectangle("fill", x + 9, ry, 4, rowH - 2)
      end
    end

    -- Label pass.
    g.setFont(fonts.body)
    local offset = math.floor((rowH - fonts.body:getHeight()) / 2)
    for slot = 1, visible do
      local index = scroll + slot
      local entry = menu.subItems[index]
      if not entry then break end
      local ry = listY + (slot - 1) * rowH
      setColor(index == menu.subIndex and COLORS.selectedText or COLORS.ink)
      g.print(cleanLabel(entry.label), x + 21, ry + offset)
    end

    if scroll > 0 or scroll + visible < #menu.subItems then
      g.setFont(fonts.small)
      setColor(COLORS.muted)
      g.print("MORE", x + w - 52, y + h - 20)
    end
    return
  end

  if not mon then return end
  local maxHP = math.max(1, mon.stats and mon.stats.hp or 1)
  local hp = shownHP(menu, mon)
  local name = monName(menu.game, mon)
  local nameWidth = w - 86
  local nameFont = fonts.body
  if fonts.body:getWidth(name) > nameWidth then nameFont = fonts.small end
  g.setFont(nameFont)
  setColor(COLORS.ink)
  drawPokemonLabel(nameFont, name, x + 14, y + 39, nameWidth)

  -- Free-standing active battle portrait. No frame is drawn around it; the
  -- transparent prepared art sits directly on the panel background.
  drawPartyBattleSprite(menu.game, mon, x + w - 68, y + 38, 56, 66, 1.15,
                        "party", mon)

  local def = monDefinition(menu.game, mon)
  local types = def and def.types or {}
  drawTypeBadge(types[1], fonts, x + 14, y + 61, 54, 18)
  if types[2] and types[2] ~= types[1] then
    drawTypeBadge(types[2], fonts, x + 72, y + 61, 54, 18)
  end

  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print("LEVEL", x + 14, y + 86)
  setColor(COLORS.ink)
  g.print(tostring(mon.level or "?"), x + 55, y + 86)
  setColor(COLORS.muted)
  g.print("HP", x + 14, y + 104)
  setColor(COLORS.ink)
  g.print(string.format("%d/%d", hp, maxHP), x + 55, y + 104)
  drawHPBar(x + 14, y + 124, w - 28, hp, maxHP)
  drawXPBar(x + 14, y + 134, w - 28,
            levelExpProgress(menu.game, mon, def))

  setColor(COLORS.muted)
  g.print("STATS", x + 14, y + 148)
  setColor(COLORS.ink)
  g.print("ATK " .. statValue(mon, "attack", "atk"), x + 14, y + 165)
  g.print("DEF " .. statValue(mon, "defense", "def"), x + 99, y + 165)
  g.print("SPD " .. statValue(mon, "speed", "spd"), x + 14, y + 181)
  g.print("SPC " .. statValue(mon, "special", "spc", "specialAttack"),
          x + 99, y + 181)

  setColor(COLORS.muted)
  g.print("MOVES", x + 14, y + 194)
  local moves = mon.moves or {}
  for i = 1, math.min(4, #moves) do
    local move = moves[i]
    local def = menu.game.data and menu.game.data.moves
                and menu.game.data.moves[move.id]
    local name = cleanLabel((def and def.name) or move.id or "-")
    setColor(COLORS.ink)
    g.print(name, x + 14, y + 194 + i * 13)
  end
end

local function drawPartyMenu(mod, menu, PartyMenu, fonts)
  local g = love.graphics
  setColor({ 0.11, 0.12, 0.12, 0.96 })
  g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)

  drawPanel(9, 8, DESIGN_W - 18, DESIGN_H - 16)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print("POKÉMON", 25, 22)
  setColor(COLORS.accent)
  g.rectangle("fill", 126, 31, 276, 3)

  local party = menu.party or (menu.game.save and menu.game.save.party) or {}
  if #party == 0 then
    g.setFont(fonts.body)
    setColor(COLORS.ink)
    g.print("No POKEMON!", 28, 70)
    return
  end

  drawPartyRows(mod, menu, PartyMenu, fonts, 23, 49, 382)
  drawPartySidePanel(menu, fonts, 422, 49, 195, 268)

  setColor(COLORS.paper2)
  g.rectangle("fill", 23, 322, 594, 24)
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  local prompt = cleanLabel(menu:bottomMessage())
  g.print(prompt, 31, 328)
  local controls = menu.submenu and "A SELECT   B BACK" or "A OPEN   B CLOSE"
  g.print(controls, 609 - fonts.small:getWidth(controls), 328)
end

local function presentationStackIndex(game, background)
  local states = game and game.stack and game.stack.states
  if type(states) ~= "table" then return nil end
  for i, state in ipairs(states) do
    if state == background then return i end
  end
  return nil
end

local function presentationRange(game, background)
  local states = game and game.stack and game.stack.states
  local first = presentationStackIndex(game, background)
  if not first then return nil end
  -- An opaque screen above this presenter correctly replaces it. Non-opaque
  -- states are messages/choices/effects that must be composited over the
  -- widescreen background instead of reviving its native draw underneath.
  for i = first + 1, #states do
    if states[i].isOpaque then return nil end
  end
  return first, #states
end

local function expForNextLevel(game, mon, def)
  local level = tonumber(mon.level) or 1
  if level >= 100 then return 0 end
  local ok, Growth = pcall(require, "src.pokemon.Growth")
  if ok and Growth and type(Growth.expForLevel) == "function" then
    local growth = def and (def.growthRate or def.growth)
    local rates = game and game.data and game.data.growth_rates
    local calcOk, target = pcall(Growth.expForLevel, growth, level + 1, rates)
    if calcOk and target then
      return math.max(0, math.floor(target - (tonumber(mon.exp) or 0)))
    end
  end
  return nil
end

levelExpProgress = function(game, mon, def)
  local level = tonumber(mon.level) or 1
  if level >= 100 then return 1 end
  local ok, Growth = pcall(require, "src.pokemon.Growth")
  if not (ok and Growth and type(Growth.expForLevel) == "function") then
    return 0
  end
  local growth = def and (def.growthRate or def.growth)
  local rates = game and game.data and game.data.growth_rates
  local baseOk, base = pcall(Growth.expForLevel, growth, level, rates)
  local nextOk, nextLevel = pcall(Growth.expForLevel, growth, level + 1, rates)
  if not (baseOk and nextOk and base and nextLevel) or nextLevel <= base then
    return 0
  end
  return clamp(((tonumber(mon.exp) or base) - base) / (nextLevel - base), 0, 1)
end

local function summaryStatus(mon)
  local status = mon and mon.status
  if status == nil or status == false or status == 0 or status == "" then
    return "OK"
  end
  return cleanLabel(tostring(status):gsub("_", " "))
end

local function drawSummaryShared(summary, fonts, x, y, w, h)
  local g, mon, game = love.graphics, summary.mon, summary.game
  local def = monDefinition(game, mon)
  local showShiny = pokemonIsShiny(mon)
  drawPanel(x, y, w, h)

  local name = monName(game, mon)
  local nameFont = fonts.title
  local nameWidth = w - 30 - (showShiny and 22 or 0)
  if nameFont:getWidth(name) > nameWidth then nameFont = fonts.small end
  g.setFont(nameFont)
  setColor(COLORS.ink)
  drawPokemonLabel(nameFont, name, x + 14, y + 13, nameWidth)
  if showShiny then drawShinyStarIcon(x + w - 34, y + 11, 16) end

  g.setFont(fonts.small)
  setColor(COLORS.muted)
  local dex = def and (def.dex or def.number or def.id)
  if dex then
    g.print(string.format("No. %03d", tonumber(dex) or 0), x + 14, y + 38)
  end

  -- The same resolver used by Party: Battle Art static/animated 2D fronts,
  -- then the engine's active front-sprite resolver. Stadium models are never
  -- requested by this path.
  drawPartyBattleSprite(game, mon, x + 16, y + 53, w - 32, 142, nil,
                        "summary", mon)

  local player = game and game.save and game.save.player or {}
  setColor(COLORS.muted)
  g.print("OT", x + 14, y + 205)
  g.print("ID No.", x + 14, y + 231)
  setColor(COLORS.ink)
  g.print(cleanLabel(mon.ot or player.name or "-"), x + 65, y + 205)
  g.print(tostring(mon.otId or player.id or "-"), x + 65, y + 231)
end

local function drawSummaryPageOne(summary, fonts, x, y, w, h)
  local g, mon = love.graphics, summary.mon
  local def = monDefinition(summary.game, mon)
  local maxHP = math.max(1, mon.stats and mon.stats.hp or 1)
  local hp = math.floor(mon.hp or 0)
  drawPanel(x, y, w, h)

  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print("LEVEL", x + 15, y + 18)
  g.print("STATUS", x + 190, y + 18)
  setColor(COLORS.ink)
  g.print(tostring(mon.level or "?"), x + 15, y + 37)
  g.print(summaryStatus(mon), x + 190, y + 37)

  setColor(COLORS.muted)
  g.print("HP", x + 15, y + 61)
  local hpText = string.format("%d/%d", hp, maxHP)
  setColor(COLORS.ink)
  g.print(hpText, x + w - 15 - fonts.small:getWidth(hpText), y + 61)
  drawHPBar(x + 15, y + 82, w - 30, hp, maxHP)

  setColor(COLORS.muted)
  g.print("STATS", x + 15, y + 101)
  local cards = {
    { "ATTACK", statValue(mon, "attack", "atk") },
    { "DEFENSE", statValue(mon, "defense", "def") },
    { "SPEED", statValue(mon, "speed", "spd") },
    { "SPECIAL", statValue(mon, "special", "spc", "specialAttack") },
  }
  for i, entry in ipairs(cards) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local cx, cy = x + 15 + col * 170, y + 120 + row * 42
    setColor(COLORS.paper2)
    g.rectangle("fill", cx, cy, 155, 34)
    setColor(COLORS.muted)
    g.print(entry[1], cx + 8, cy + 8)
    setColor(COLORS.ink)
    g.print(entry[2], cx + 145 - fonts.small:getWidth(entry[2]), cy + 8)
  end

  setColor(COLORS.muted)
  g.print("TYPE", x + 15, y + 216)
  local types = def and def.types or {}
  drawTypeBadge(types[1], fonts, x + 73, y + 211, 78, 21)
  if types[2] and types[2] ~= types[1] then
    drawTypeBadge(types[2], fonts, x + 158, y + 211, 78, 21)
  end
end

local function drawSummaryPageTwo(summary, fonts, x, y, w, h)
  local g, mon, game = love.graphics, summary.mon, summary.game
  local def = monDefinition(game, mon)
  drawPanel(x, y, w, h)
  g.setFont(fonts.small)

  setColor(COLORS.muted)
  g.print("EXP POINTS", x + 15, y + 14)
  g.print("NEXT LEVEL", x + 190, y + 14)
  setColor(COLORS.ink)
  g.print(tostring(math.floor(tonumber(mon.exp) or 0)), x + 15, y + 33)
  local nextExp = expForNextLevel(game, mon, def)
  g.print(nextExp ~= nil and tostring(nextExp) or "-", x + 190, y + 33)

  setColor(COLORS.muted)
  g.print("LEVEL PROGRESS", x + 15, y + 55)
  drawXPBar(x + 125, y + 59, w - 140, levelExpProgress(game, mon, def))

  setColor(COLORS.muted)
  g.print("MOVES", x + 15, y + 84)
  local moves = mon.moves or {}
  for i = 1, 4 do
    local move = moves[i]
    local mdef = move and game.data and game.data.moves
                 and game.data.moves[move.id]
    local ry = y + 104 + (i - 1) * 37
    setColor(COLORS.paper2)
    g.rectangle("fill", x + 15, ry, w - 30, 30)
    setColor(COLORS.ink)
    local moveName = fitLabel(fonts.small,
      (mdef and mdef.name) or (move and move.id) or "-", 154)
    g.print(moveName, x + 25, ry + 6)
    if move then
      drawTypeBadge(mdef and mdef.type, fonts, x + 190, ry + 6, 65, 18)
      local maxPP = tonumber(mdef and mdef.pp) or tonumber(move.pp) or 0
      local ups = tonumber(move.ppUps) or 0
      maxPP = maxPP + ups * math.floor(maxPP / 5)
      local pp = tostring(move.pp or 0) .. "/" .. tostring(maxPP)
      setColor(COLORS.muted)
      g.print("PP " .. pp, x + w - 25 - fonts.small:getWidth("PP " .. pp),
              ry + 6)
    end
  end
end

local function drawSummaryMenu(summary, fonts)
  local g = love.graphics
  setColor({ 0.11, 0.12, 0.12, 0.96 })
  g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  drawPanel(9, 8, DESIGN_W - 18, DESIGN_H - 16)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  local summaryTitle = "POKEMON SUMMARY"
  g.print(summaryTitle, 25, 22)
  setColor(COLORS.accent)
  local lineX = 25 + fonts.title:getWidth(summaryTitle) + 15
  g.rectangle("fill", lineX, 31, math.max(20, 402 - lineX), 3)
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  local page = clamp(tonumber(summary.page) or 1, 1, 2)
  g.print(page .. " / 2", 579, 24)

  drawSummaryShared(summary, fonts, 23, 49, 202, 267)
  if page == 1 then
    drawSummaryPageOne(summary, fonts, 240, 49, 377, 267)
  else
    drawSummaryPageTwo(summary, fonts, 240, 49, 377, 267)
  end

  setColor(COLORS.paper2)
  g.rectangle("fill", 23, 322, 594, 24)
  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print(page == 1 and "POKEMON DATA" or "MOVES & EXPERIENCE", 31, 328)
  local controls = page == 1 and "A / B NEXT" or "A / B CLOSE"
  g.print(controls, 609 - fonts.small:getWidth(controls), 328)
end

local function evolutionPreviewMon(state, species, key)
  if not (state and type(state.mon) == "table" and species) then return nil end
  local cached = state[key]
  if type(cached) == "table" and cached.species == species then return cached end
  cached = {}
  for field, value in pairs(state.mon) do cached[field] = value end
  cached.species = species
  -- The evolved form has no separate nickname during the movie. Artwork
  -- resolution needs the retained DVs/shiny identity, but not the old label.
  cached.nickname = nil
  state[key] = cached
  return cached
end

local function evolutionDisplayedMon(state)
  if not (state and state.mon and state.newSpecies) then return nil, false end
  state.__widescreenEvolutionOldSpecies = state.__widescreenEvolutionOldSpecies
    or state.mon.species
  local showNew
  if state.done then
    showNew = not state.canceled
  else
    local period = math.max(4, 28 - math.floor((tonumber(state.t) or 0) / 40) * 6)
    showNew = math.floor((tonumber(state.t) or 0) / period) % 2 == 1
  end
  if showNew then
    return evolutionPreviewMon(state, state.newSpecies,
      "__widescreenEvolutionNewMon"), true
  end
  return evolutionPreviewMon(state, state.__widescreenEvolutionOldSpecies,
    "__widescreenEvolutionOldMon"), false
end

local function drawEvolutionScreen(state, fonts)
  local g = love.graphics
  drawPokedexHeader(fonts, "EVOLUTION")
  local x, y, w, h = 90, 52, 460, 248
  drawPanel(x, y, w, h)

  local mon, showingNew = evolutionDisplayedMon(state)
  local game = state and state.game
  local oldName = cleanLabel(state and state.oldName or "POKEMON")
  local newDef = game and game.data and game.data.pokemon
    and game.data.pokemon[state and state.newSpecies]
  local newName = cleanLabel(newDef and newDef.name or state and state.newSpecies
    or "POKEMON")

  g.setFont(fonts.title)
  setColor(COLORS.ink)
  local shownName = showingNew and newName or oldName
  drawPokemonLabel(fonts.title, shownName, x + 18, y + 14, w - 36)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 18, y + 42, w - 36, 3)

  if mon then
    drawPartyBattleSprite(game, mon, x + 75, y + 50, w - 150, 138, 1.08,
      "evolution", state)
  end

  setColor(COLORS.paper2)
  g.rectangle("fill", x + 12, y + h - 48, w - 24, 34)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  local message
  if state and state.done then
    message = state.canceled and "EVOLUTION STOPPED"
      or ("EVOLVED INTO " .. newName .. "!")
  else
    message = "WHAT? " .. oldName .. " IS EVOLVING!"
  end
  g.print(fitLabel(fonts.body, message, w - 48), x + 24, y + h - 42)

  g.setFont(fonts.small)
  setColor(COLORS.muted)
  if state and not state.done and state.cancelable then
    g.print("HOLD B TO STOP", x + w - 24
      - fonts.small:getWidth("HOLD B TO STOP"), y + h - 10)
  end
end
PokedexProviderUI.drawEvolutionScreen = drawEvolutionScreen

local function trainerBadgeOwned(state, badgeIndex)
  local game = state and state.game
  local save = game and game.save
  local badges = PokedexProviderUI.badgesModule
  if not (save and type(save.inventory) == "table" and badges
      and type(badges.list) == "function"
      and type(badges.itemFor) == "function") then
    return false
  end
  local okList, list = pcall(badges.list, game.data)
  if not (okList and type(list) == "table" and list[badgeIndex]) then
    return false
  end
  local okItem, item = pcall(badges.itemFor, list[badgeIndex])
  return okItem and item ~= nil and save.inventory[item] and true or false
end

local function trainerCardLeaderPalette(game, badgeIndex)
  local id = TRAINER_CARD_LEADERS[badgeIndex]
  local trainer = game and game.data and game.data.trainers
    and game.data.trainers[id]
  if trainer and PaletteFX and type(PaletteFX.spriteObp) == "function" then
    local ok, palette = pcall(PaletteFX.spriteObp, trainer, id)
    if ok and palette then return palette end
  end
  return PaletteFX and PaletteFX.pal and PaletteFX.pal(
    game and game.data, "MEWMON") or nil
end

local function trainerCardImageSpec(value)
  if not value then return nil end
  if type(value.getDimensions) == "function" then
    return { image = value }
  end
  if type(value) ~= "table" then return nil end
  local image = value.image
  if not image and value.imagePath and Assets and type(Assets.image) == "function" then
    PokedexProviderUI.trainerCardImages =
      PokedexProviderUI.trainerCardImages or {}
    image = PokedexProviderUI.trainerCardImages[value.imagePath]
    if image == nil then
      local ok, loaded = pcall(Assets.image, value.imagePath)
      image = ok and loaded or false
      PokedexProviderUI.trainerCardImages[value.imagePath] = image
    end
  end
  if not (image and type(image.getDimensions) == "function") then return nil end
  local spec = {
    image = image,
    quad = value.quad,
    frameW = tonumber(value.frameW),
    frameH = tonumber(value.frameH),
    palette = value.palette,
    trueColor = value.trueColor == true,
    anchorY = tonumber(value.anchorY),
  }
  if not spec.quad and spec.frameW and spec.frameH
      and love.graphics and type(love.graphics.newQuad) == "function" then
    local iw, ih = image:getDimensions()
    if spec.frameW > 0 and spec.frameH > 0
        and (iw > spec.frameW or ih > spec.frameH) then
      spec.quad = love.graphics.newQuad(0, 0, spec.frameW, spec.frameH, iw, ih)
    end
  end
  return spec
end

local function trainerCardGrayShader()
  if PokedexProviderUI.trainerCardGrayShader ~= nil then
    return PokedexProviderUI.trainerCardGrayShader or nil
  end
  local g = love.graphics
  if not (g and type(g.newShader) == "function") then
    PokedexProviderUI.trainerCardGrayShader = false
    return nil
  end
  local ok, shader = pcall(g.newShader, [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords,
                vec2 screen_coords) {
      vec4 pixel = Texel(texture, texture_coords);
      float value = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
      return vec4(vec3(value), pixel.a) * color;
    }
  ]])
  PokedexProviderUI.trainerCardGrayShader = ok and shader or false
  return ok and shader or nil
end

local function drawTrainerCardPortrait(spec, x, y, w, h, maxScale, grounded,
                                      locked, fallbackPalette)
  spec = trainerCardImageSpec(spec)
  if not spec then return false end
  local image, g = spec.image, love.graphics
  local iw, ih = image:getDimensions()
  local sw = spec.frameW and spec.frameW > 0 and spec.frameW or iw
  local sh = spec.frameH and spec.frameH > 0 and spec.frameH or ih
  if sw <= 0 or sh <= 0 then return false end
  local scale = math.min(w / sw, h / sh, maxScale or math.huge)
  local dx = math.floor(x + (w - sw * scale) / 2)
  local dy = grounded and math.floor(y + h - sh * scale
    + (spec.anchorY or 0) * scale)
    or math.floor(y + (h - sh * scale) / 2)
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  setColor({ 1, 1, 1, 1 })
  local shader = locked and trainerCardGrayShader() or nil
  if shader then g.setShader(shader) end
  local palette
  if not locked and not spec.trueColor then
    palette = spec.palette or fallbackPalette
  end
  drawWithPalette(image, palette, function()
    if spec.quad then
      g.draw(image, spec.quad, dx, dy, 0, scale, scale)
    else
      g.draw(image, dx, dy, 0, scale, scale)
    end
  end)
  if shader then g.setShader() end
  if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
    PaletteFX.markTrueColor(x, y, w, h)
  end
  return true
end

local function drawTrainerCard(state, fonts)
  local g = love.graphics
  local game = state and state.game
  local save = game and game.save or {}
  drawPokedexHeader(fonts, "TRAINER CARD")

  local x, y, w, topH = 20, 52, 600, 144
  drawPanel(x, y, w, topH)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print(cleanLabel(save.player and save.player.name or "RED"), x + 24, y + 18)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 24, y + 44, 280, 3)

  local seconds = math.max(0, math.floor(tonumber(save.playTime) or 0))
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor(seconds / 60) % 60
  g.setFont(fonts.body)
  setColor(COLORS.muted)
  g.print("MONEY", x + 24, y + 78)
  g.print("TIME", x + 212, y + 78)
  setColor(COLORS.ink)
  g.print(tostring(math.floor(tonumber(save.money) or 0)), x + 92, y + 78)
  g.print(("%d:%02d"):format(hours, minutes), x + 264, y + 78)

  local playerPortrait = PokedexProviderUI.resolveTrainerCardPortrait
    and PokedexProviderUI.resolveTrainerCardPortrait(
      "player", game, state, nil, nil, true)
  playerPortrait = trainerCardImageSpec(playerPortrait)
  if not playerPortrait and state.pic then playerPortrait = { image = state.pic } end
  drawTrainerCardPortrait(playerPortrait, x + w - 176, y + 10,
    148, topH - 20, 3, true, false,
    PaletteFX and PaletteFX.pal and PaletteFX.pal(game and game.data, "MEWMON"))

  local badgeY, badgeH = 208, 110
  drawPanel(x, badgeY, w, badgeH)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print("BADGES", x + 18, badgeY + 10)
  setColor(COLORS.accent)
  g.rectangle("fill", x + 112, badgeY + 22, w - 130, 3)

  local asset = loadTrainerBadgeAsset()
  for i = 1, 8 do
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    local tileX = x + 14 + col * 145
    local tileY = badgeY + 32 + row * 32
    local owned = trainerBadgeOwned(state, i)
    setColor(owned and COLORS.paper2 or { 0.82, 0.83, 0.79, 0.72 })
    g.rectangle("fill", tileX, tileY, 132, 27)
    setColor(owned and COLORS.ink or COLORS.muted)
    g.setFont(fonts.small)
    g.print(("%02d"):format(i), tileX + 8, tileY + 7)
    if asset and asset.quads[i] then
      setColor(owned and { 1, 1, 1, 1 } or { 0.28, 0.29, 0.28, 0.38 })
      g.draw(asset.image, asset.quads[i], tileX + 27, tileY - 1,
        0, 29 / 64, 29 / 64)
      if PaletteFX and type(PaletteFX.markTrueColor) == "function" then
        PaletteFX.markTrueColor(tileX + 27, tileY - 1, 29, 29)
      end
    end
    local leader = PokedexProviderUI.resolveTrainerCardPortrait
      and PokedexProviderUI.resolveTrainerCardPortrait(
        "leader", game, state, i, TRAINER_CARD_LEADERS[i], owned)
    if not leader and state.faces and state.faces.img and state.faces.quads
        and state.faces.quads[i - 1] then
      leader = {
        image = state.faces.img,
        quad = state.faces.quads[i - 1],
        frameW = 16,
        frameH = 16,
      }
    end
    drawTrainerCardPortrait(leader, tileX + 67, tileY + 1,
      28, 25, 1.65, false, not owned,
      trainerCardLeaderPalette(game, i))
  end

  g.setFont(fonts.small)
  setColor(COLORS.muted)
  g.print("A / B CLOSE", 609 - fonts.small:getWidth("A / B CLOSE"), 328)
end
PokedexProviderUI.drawTrainerCard = drawTrainerCard

local function visibleTextBoxLine(box, shownIndex)
  local shown = box.shown and box.shown[shownIndex]
  local page = box.pages and box.pages[box.pageIndex]
  if not (shown and page) then return "" end
  local sourceIndex = box.lineIndex - (#box.shown - shownIndex)
  local source = page[sourceIndex] or ""
  if not (EngineFont and EngineFont.split) then
    return source:sub(1, math.min(#source, #shown))
  end
  local spans = EngineFont.split(source)
  local count = math.min(#shown, #spans)
  if count <= 0 then return "" end
  return source:sub(1, spans[count].to)
end

PokedexProviderUI.WIDE_DIALOGUE_COLS = 56
PokedexProviderUI.OAK_DIALOGUE_COLS = 68

-- Rebuild one native NPC text stream for the actual wide box. Newline and
-- CONT markers in the ROM mostly describe the 18-column Game Boy window;
-- normalize those within each semantic paragraph, wrap to the wide budget,
-- and retain at most two lines per page. Explicit paragraph/page markers
-- remain button-gated, while obsolete CONT presses disappear.
PokedexProviderUI.reflowWideDialogue = function(TextBox, text, maxCols)
  if type(text) ~= "string" or type(TextBox) ~= "table"
      or type(TextBox.paginate) ~= "function" then return text end
  maxCols = maxCols or PokedexProviderUI.WIDE_DIALOGUE_COLS
  local output = {}
  for paragraph in (text .. "\f"):gmatch("(.-)\f") do
    if paragraph ~= "" then
      local normalized = paragraph:gsub("[\n\v]", " ")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      local wrapped = TextBox.paginate(normalized, maxCols)
      local lines = wrapped and wrapped[1] or { normalized }
      for index = 1, #lines, 2 do
        local page = lines[index] or ""
        if lines[index + 1] then page = page .. "\n" .. lines[index + 1] end
        output[#output + 1] = page
      end
    end
  end
  return #output > 0 and table.concat(output, "\f") or text
end

-- Oak's Game Boy text contains page markers chosen for an 18-column box.
-- The 640px opening can present those beats in a single two-line page, so all
-- legacy line/CONT/page controls are treated as spacing before repagination.
PokedexProviderUI.reflowOakDialogue = function(TextBox, text, maxCols)
  if type(text) ~= "string" or type(TextBox) ~= "table"
      or type(TextBox.paginate) ~= "function" then return text end
  maxCols = maxCols or PokedexProviderUI.OAK_DIALOGUE_COLS
  local normalized = text:gsub("[\n\v\f]", " ")
    :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local wrapped = TextBox.paginate(normalized, maxCols)
  local lines = wrapped and wrapped[1] or { normalized }
  local pages = {}
  for index = 1, #lines, 2 do
    local page = lines[index] or ""
    if lines[index + 1] then page = page .. "\n" .. lines[index + 1] end
    pages[#pages + 1] = page
  end
  return #pages > 0 and table.concat(pages, "\f") or text
end

local function drawWideTextBox(box, fonts, viewW, viewH)
  local g = love.graphics
  viewW, viewH = viewW or DESIGN_W, viewH or DESIGN_H
  local x, w, h = 12, math.max(296, viewW - 24), 92
  local y = math.max(12, viewH - h - 12)
  drawPanel(x, y, w, h)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  -- TextBox's native draw owns the retained-line scroll countdown. Because
  -- Widescreen suppresses that draw while presenting this box, advance the
  -- same 2px-per-frame state here. The update method, typing cadence, page
  -- waits and callbacks remain entirely native.
  local nativeOff = tonumber(box.scrollPx) or 0
  if nativeOff > 0 then
    nativeOff = math.max(0, nativeOff - 2)
    box.scrollPx = nativeOff > 0 and nativeOff or nil
  end
  local lineStep = 28
  local retainedOff = nativeOff > 0
    and math.floor(nativeOff * lineStep / 8 + 0.5) or 0
  for i = 1, math.min(2, #(box.shown or {})) do
    local lineY = y + 19 + (i - 1) * lineStep
    if i == 1 then lineY = lineY + retainedOff end
    drawPokemonLabel(fonts.body, visibleTextBoxLine(box, i), x + 20,
      math.floor(lineY), w - 48)
  end
  if (box.waiting or (box.done and not box.choice and not box.auto
                      and not box.stay)) and (box.blink or 0) < 30 then
    setColor(COLORS.accent)
    g.polygon("fill", x + w - 29, y + h - 25,
              x + w - 15, y + h - 25,
              x + w - 22, y + h - 15)
  end
end

local function drawOakTextBox(box, fonts, viewW, viewH)
  local g = love.graphics
  viewW, viewH = viewW or DESIGN_W, viewH or DESIGN_H
  local x, w, h = 8, math.max(304, viewW - 16), 70
  local y = math.max(4, viewH - h - 4)
  drawPanel(x, y, w, h)
  g.setFont(fonts.body)
  setColor(COLORS.ink)
  local nativeOff = tonumber(box.scrollPx) or 0
  if nativeOff > 0 then
    nativeOff = math.max(0, nativeOff - 2)
    box.scrollPx = nativeOff > 0 and nativeOff or nil
  end
  local lineStep = 23
  local retainedOff = nativeOff > 0
    and math.floor(nativeOff * lineStep / 8 + 0.5) or 0
  for i = 1, math.min(2, #(box.shown or {})) do
    local lineY = y + 13 + (i - 1) * lineStep
    if i == 1 then lineY = lineY + retainedOff end
    drawPokemonLabel(fonts.body, visibleTextBoxLine(box, i), x + 20,
      math.floor(lineY), w - 48)
  end
  if (box.waiting or (box.done and not box.choice and not box.auto
                      and not box.stay)) and (box.blink or 0) < 30 then
    setColor(COLORS.accent)
    g.polygon("fill", x + w - 27, y + h - 18,
      x + w - 13, y + h - 18, x + w - 20, y + h - 8)
  end
end

local function drawWideChoiceBox(choice, fonts, viewW, viewH, aboveText)
  local g = love.graphics
  viewW, viewH = viewW or DESIGN_W, viewH or DESIGN_H
  local w, h = 154, 82
  local textTop = math.max(12, viewH - 104)
  local x = math.max(12, viewW - w - 12)
  local y = aboveText and math.max(12, textTop - h - 8)
    or math.max(12, viewH - h - 12)
  drawPanel(x, y, w, h)
  local rowH = 28
  for i = 1, 2 do
    local ry = y + 13 + (i - 1) * rowH
    if i == choice.index then
      setColor(COLORS.selected)
      g.rectangle("fill", x + 9, ry, w - 18, rowH - 2)
      setColor(COLORS.accent)
      g.rectangle("fill", x + 9, ry, 4, rowH - 2)
    end
  end
  g.setFont(fonts.body)
  setColor(choice.index == 1 and COLORS.selectedText or COLORS.ink)
  g.print("YES", x + 24, y + 18)
  setColor(choice.index == 2 and COLORS.selectedText or COLORS.ink)
  g.print("NO", x + 24, y + 46)
end

local function drawNativeOverlay(state)
  if not (state and type(state.draw) == "function") then return end
  local g = love.graphics
  g.push("all")
  -- Generic non-opaque effects use the engine's 160x144 coordinate space.
  -- Stretching a full-screen veil is exact; custom TextBox/Choice presenters
  -- above avoid stretching text or borders.
  g.scale(DESIGN_W / 160, DESIGN_H / 144)
  pcall(state.draw, state)
  g.pop()
end

local function drawPresentationOverlays(game, first, last, fonts, viewW, viewH,
                                        oakDialogue)
  local states = game.stack.states
  for i = first + 1, last do
    local state = states[i]
    local mt = getmetatable(state)
    if TextBoxClass and mt == TextBoxClass then
      if oakDialogue then
        drawOakTextBox(state, fonts, viewW, viewH)
      else
        drawWideTextBox(state, fonts, viewW, viewH)
      end
    elseif ChoiceBoxClass and mt == ChoiceBoxClass then
      local aboveText = false
      for under = first + 1, i - 1 do
        if TextBoxClass and getmetatable(states[under]) == TextBoxClass then
          aboveText = true
          break
        end
      end
      drawWideChoiceBox(state, fonts, viewW, viewH, aboveText)
    else
      drawNativeOverlay(state)
    end
  end
end

-- Professor Oak's state machine remains the sole owner of the New Game
-- sequence.  This presenter only replaces its 160x144 drawing pass, keeping
-- dialogue, naming, cries, music, reveal timing and callbacks native.
local function oakSpeechAssets()
  local cached = PokedexProviderUI.oakSpeechAssets
  if cached then return cached end
  cached = {}
  for key, loader in pairs(PokedexProviderUI.oakSpeechAssetLoaders or {}) do
    local ok, image = pcall(loader)
    if ok and image and type(image.getDimensions) == "function" then
      if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
      cached[key] = image
    elseif PokedexProviderUI.oakSpeechAssetLogError then
      PokedexProviderUI.oakSpeechAssetLogError(
        "New Game " .. tostring(key) .. " asset: " .. tostring(image))
    end
  end
  PokedexProviderUI.oakSpeechAssets = cached
  return cached
end

local function drawOakSpeechImage(state, image, palette, flip, alpha, offset)
  if not (image and type(image.getDimensions) == "function") then return end
  local g = love.graphics
  local iw, ih = image:getDimensions()
  if iw <= 0 or ih <= 0 then return end
  local scale = math.min(226 / iw, 194 / ih, 3)
  local x = math.floor(320 - iw * scale / 2 + (offset or 0))
  local y = math.floor(271 - ih * scale)
  if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
  g.setColor(1, 1, 1, alpha or 1)
  drawWithPalette(image, palette, function()
    if flip then
      g.draw(image, x + iw * scale, y, 0, -scale, scale)
    else
      g.draw(image, x, y, 0, scale, scale)
    end
  end)
end

local function drawOakSpeech(state, fonts)
  local g = love.graphics
  local assets = oakSpeechAssets()
  setColor(COLORS.paper)
  g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  setColor(COLORS.paper2)
  g.rectangle("fill", 0, 224, DESIGN_W, 64)
  setColor({ 0.43, 0.67, 0.58, 1 })
  g.rectangle("fill", 0, 253, DESIGN_W, 35)
  setColor({ 0.78, 0.88, 0.76, 1 })
  g.ellipse("fill", 320, 267, 102, 13)
  local image, palette, flip = state.pic, nil, state.picFlip == true
  if state.pic == state.oakPic then
    image, flip = assets.oak or image, false
  elseif state.pic == state.playerPic then
    image, flip = assets.player or image, false
  elseif state.pic == state.rivalPic then
    image, flip = assets.rival or image, false
  elseif state.pic == state.demoPic and state.demoSpecies then
    local token = presentationToken(state, "oak_speech", state.demoSpecies)
    local presentation = providerPokemonPresentation(state.game,
      { species = state.demoSpecies }, "oak_speech", token)
    image = presentation and presentation.image or image
    if not presentation and PaletteFX and type(PaletteFX.monPal) == "function" then
      palette = PaletteFX.monPal(state.game.data, state.demoSpecies)
    end
  end

  if state.shrink then
    image, palette, flip = assets.player or state.playerPic, nil, false
  end

  local alpha, offset = 1, 0
  if state.picReveal then
    local r = state.picReveal
    local progress = math.min(1, (tonumber(r.t) or 0) / math.max(1, tonumber(r.dur) or 1))
    if r.kind == "fade" then alpha = progress end
    if r.kind == "wipe" then offset = math.floor(300 * (1 - progress)) end
  end
  drawOakSpeechImage(state, image, palette, flip, alpha, offset)

  if state.walkVisible and state.walkSheet and not state.shrink then
    local sheet = state.walkSheet
    local sw, sh = sheet:getDimensions()
    state.__widescreenWalkQuad = state.__widescreenWalkQuad
      or g.newQuad(0, 0, 16, 16, sw, sh)
    g.setColor(1, 1, 1, 1)
    g.draw(sheet, state.__widescreenWalkQuad, 296, 222, 0, 3, 3)
  end
  -- `shrinkText` is the engine's ROM-font replica after the real final
  -- TextBox closes. Widescreen intentionally omits it: Pixelify remains until
  -- the native A acknowledgement, then the clean fade starts.
  if state.fadeLevel then
    g.setColor(1, 1, 1, math.min(1, state.fadeLevel / 3))
    g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  end
  local fadeFrame = tonumber(state.__widescreenFadeToHouse) or 0
  if fadeFrame > 30 then
    -- Hold Red for half a second, fade for three seconds, then keep the fully
    -- white bridge for another half-second before native completion.
    g.setColor(1, 1, 1, math.min(1, (fadeFrame - 30) / 180))
    g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  end
end
PokedexProviderUI.drawOakSpeech = drawOakSpeech

PokedexProviderUI.drawIntroFadeIn = function(state, viewW, viewH)
  local progress=math.min(1,(tonumber(state.frame) or 0)
    / math.max(1,tonumber(state.duration) or 90))
  love.graphics.setColor(1,1,1,1-progress)
  love.graphics.rectangle("fill",0,0,viewW or DESIGN_W,viewH or DESIGN_H)
end

local function drawOakNaming(speech, naming, menu, fonts)
  local g = love.graphics
  local assets = oakSpeechAssets()
  setColor(COLORS.paper)
  g.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print(cleanLabel(naming.title or "YOUR NAME?"), 24, 20)
  setColor(COLORS.accent)
  g.rectangle("fill", 24, 47, 384, 3)
  drawPanel(20, 64, 396, 270)
  drawPanel(438, 64, 182, 270)
  local rival = tostring(naming.title or ""):upper():find("HIS", 1, true) ~= nil
  drawImageGrounded(rival and assets.rival or assets.player,
    454, 314, 150, 218, 3)

  if menu then
    g.setFont(fonts.body)
    for i, item in ipairs(menu.items or {}) do
      local y = 87 + (i - 1) * 47
      if i == menu.index then
        setColor(COLORS.selected)
        g.rectangle("fill", 36, y, 364, 38)
        setColor(COLORS.accent)
        g.rectangle("fill", 36, y, 5, 38)
        setColor(COLORS.selectedText)
      else
        setColor(COLORS.paper2)
        g.rectangle("fill", 36, y, 364, 38)
        setColor(COLORS.ink)
      end
      g.print(cleanLabel(item.label or item.text or item), 54, y + 8)
    end
  else
    local typed = type(naming.glyphs) == "table"
      and table.concat(naming.glyphs) or ""
    local text = cleanLabel(naming.value or naming.name or typed)
    g.setFont(fonts.body)
    setColor(COLORS.ink)
    g.print(text, 42, 80)
    setColor(COLORS.accent)
    g.rectangle("fill", 42, 108, 340, 2)
    local grid = type(naming.grid) == "function" and naming:grid() or naming.glyphs or {}
    g.setFont(fonts.small)
    for row, values in ipairs(grid) do
      for col, value in ipairs(values) do
        local x, y = 40 + (col - 1) * 38, 128 + (row - 1) * 34
        if row == naming.row and col == naming.col then
          setColor(COLORS.selected)
          g.rectangle("fill", x - 5, y - 4, 32, 27)
          setColor(COLORS.selectedText)
        else
          setColor(COLORS.ink)
        end
        g.print(cleanLabel(value), x, y)
      end
    end
  end
  g.setFont(fonts.tiny)
  setColor(COLORS.muted)
  g.print("A SELECT     B BACK     START OK", 28, 340)
end
PokedexProviderUI.drawOakNaming = drawOakNaming

PokedexProviderUI.BAG_SCREENS = {
  bag = true, search = true, machine_filter = true, move_info = true,
  item_options = true, item_confirmation = true,
}

PokedexProviderUI.bagFiniteInteger = function(value, minimum)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge and value % 1 == 0
    and value >= (minimum or 0)
end

PokedexProviderUI.bagModelRows = function(model)
  if type(model) ~= "table" then return nil end
  return model.lines or model.rows or model.options
end

PokedexProviderUI.validateBagSelection = function(model, label, rows, required)
  if type(rows) ~= "table" then return nil, label .. " rows must be an array" end
  local ids = {}
  for i, row in ipairs(rows) do
    if type(row) == "table" then
      if row.id ~= nil and (type(row.id) ~= "string" or row.id == "") then
        return nil, label .. " row " .. tostring(i) .. " id must be a string"
      end
      if row.id and ids[row.id] then
        return nil, "duplicate " .. label .. " row id " .. row.id
      end
      if row.id then ids[row.id] = i end
      if type(row.label or row.value) ~= "string" then
        return nil, label .. " row " .. tostring(i) .. " requires a label"
      end
    elseif type(row) ~= "string" then
      return nil, label .. " row " .. tostring(i) .. " must be text or a descriptor"
    end
  end
  local index = model.selectedIndex
  if index ~= nil and (not PokedexProviderUI.bagFiniteInteger(index, 1)
      or index > #rows) then
    return nil, label .. " selectedIndex must address the rows"
  end
  if model.selectedId ~= nil then
    if type(model.selectedId) ~= "string" or not ids[model.selectedId] then
      return nil, label .. " selectedId must identify a row"
    end
    if index and ids[model.selectedId] ~= index then
      return nil, label .. " selectedId and selectedIndex disagree"
    end
  end
  if required and #rows > 0 and index == nil and model.selectedId == nil then
    return nil, label .. " requires selectedIndex or selectedId"
  end
  return true
end

PokedexProviderUI.validateBagKeyboard = function(keyboard)
  if type(keyboard) ~= "table" then
    return nil, "search keyboard must be a table"
  end
  if not PokedexProviderUI.bagFiniteInteger(keyboard.columns, 1) then
    return nil, "search keyboard columns must be a positive integer"
  end
  if type(keyboard.keys) ~= "table" or #keyboard.keys < 1 then
    return nil, "search keyboard keys must be a non-empty array"
  end
  local ids = {}
  for i, key in ipairs(keyboard.keys) do
    if type(key) ~= "table" or type(key.id) ~= "string" or key.id == ""
        or type(key.label) ~= "string" then
      return nil, "search keyboard key " .. tostring(i) .. " requires id and label"
    end
    if ids[key.id] then return nil, "duplicate search keyboard key id " .. key.id end
    ids[key.id] = i
    if key.value ~= nil and type(key.value) ~= "string" then
      return nil, "search keyboard key " .. tostring(i) .. " value must be text"
    end
    if key.action ~= nil and type(key.action) ~= "string" then
      return nil, "search keyboard key " .. tostring(i) .. " action must be text"
    end
  end
  local index = keyboard.selectedIndex
  if index ~= nil and (not PokedexProviderUI.bagFiniteInteger(index, 1)
      or index > #keyboard.keys) then
    return nil, "search keyboard selectedIndex must address the keys"
  end
  if keyboard.selectedKeyId ~= nil then
    if type(keyboard.selectedKeyId) ~= "string"
        or not ids[keyboard.selectedKeyId] then
      return nil, "search keyboard selectedKeyId must identify a key"
    end
    if index and ids[keyboard.selectedKeyId] ~= index then
      return nil, "search keyboard selectedKeyId and selectedIndex disagree"
    end
  end
  if index == nil and keyboard.selectedKeyId == nil then
    return nil, "search keyboard requires selectedIndex or selectedKeyId"
  end
  return true
end

PokedexProviderUI.validateBagSnapshot = function(snapshot)
  if type(snapshot) ~= "table" then return nil, "snapshot must be a table" end
  if snapshot.schemaVersion ~= 1
      and snapshot.schemaVersion ~= BAG_PROVIDER_API_VERSION then
    return nil, "unsupported snapshot schemaVersion"
  end
  if not PokedexProviderUI.BAG_SCREENS[snapshot.screen] then
    return nil, "unsupported screen " .. tostring(snapshot.screen)
  end
  if snapshot.mode ~= "field" and snapshot.mode ~= "battle" then
    return nil, "mode must be field or battle"
  end
  if type(snapshot.pockets) ~= "table" or #snapshot.pockets < 1 then
    return nil, "pockets must be a non-empty array"
  end
  local pocketIds = {}
  for i, pocket in ipairs(snapshot.pockets) do
    if type(pocket) ~= "table" or type(pocket.id) ~= "string"
        or pocket.id == "" or type(pocket.label) ~= "string" then
      return nil, "pocket " .. tostring(i) .. " requires id and label"
    end
    if pocketIds[pocket.id] then return nil, "duplicate pocket id " .. pocket.id end
    pocketIds[pocket.id] = true
  end
  if type(snapshot.selectedPocketId) ~= "string"
      or not pocketIds[snapshot.selectedPocketId] then
    return nil, "selectedPocketId must identify a pocket"
  end
  if type(snapshot.rows) ~= "table" then return nil, "rows must be an array" end
  local rowIds = {}
  for i, row in ipairs(snapshot.rows) do
    if type(row) ~= "table" or type(row.itemId) ~= "string" or row.itemId == ""
        or type(row.label) ~= "string"
        or not PokedexProviderUI.bagFiniteInteger(row.count, 0)
        or type(row.enabled) ~= "boolean" or type(row.favorite) ~= "boolean"
        or type(row.pinned) ~= "boolean" then
      return nil, "row " .. tostring(i)
        .. " requires itemId, label, finite count and boolean state"
    end
    if rowIds[row.itemId] then return nil, "duplicate itemId " .. row.itemId end
    rowIds[row.itemId] = true
    if row.icon ~= nil and type(row.icon) ~= "table" then
      return nil, "row " .. tostring(i) .. " icon must be a descriptor"
    end
    if row.detail ~= nil then
      if snapshot.schemaVersion ~= BAG_PROVIDER_API_VERSION then
        return nil, "structured row detail requires Bag schema v2"
      end
      if type(row.detail) ~= "table" or row.detail.kind ~= "machine" then
        return nil, "row " .. tostring(i)
          .. " detail must be a supported structured detail model"
      end
      if type(row.detail.typeId) ~= "string" or row.detail.typeId == ""
          or #row.detail.typeId > 32 then
        return nil, "row " .. tostring(i)
          .. " machine detail requires a bounded typeId"
      end
      local parameters=row.detail.parameters
      if type(parameters) ~= "table" or #parameters < 1 or #parameters > 8 then
        return nil, "row " .. tostring(i)
          .. " machine parameters must be a bounded non-empty array"
      end
      local seenLabels={}
      for parameterIndex,parameter in ipairs(parameters) do
        if type(parameter) ~= "table" or type(parameter.label) ~= "string"
            or parameter.label == "" or #parameter.label > 32
            or type(parameter.value) ~= "string" then
          return nil, "row " .. tostring(i) .. " machine parameter "
            .. tostring(parameterIndex) .. " requires bounded label and text value"
        end
        local key=parameter.label:upper()
        local maxValue=key=="DESCRIPTION" and 1024 or 128
        if #parameter.value > maxValue then
          return nil, "row " .. tostring(i) .. " machine parameter "
            .. tostring(parameterIndex) .. " value is too long"
        end
        if seenLabels[key] then
          return nil, "row " .. tostring(i)
            .. " has duplicate machine parameter " .. key
        end
        seenLabels[key]=true
      end
    end
  end
  if not PokedexProviderUI.bagFiniteInteger(snapshot.selectedIndex, 1)
      or (#snapshot.rows > 0 and snapshot.selectedIndex > #snapshot.rows) then
    return nil, "selectedIndex must address the rows"
  end
  if not PokedexProviderUI.bagFiniteInteger(snapshot.scroll or 0, 0) then
    return nil, "scroll must be a non-negative integer"
  end
  if snapshot.money ~= nil
      and not PokedexProviderUI.bagFiniteInteger(snapshot.money, 0) then
    return nil, "money must be a finite non-negative integer"
  end
  if snapshot.actions ~= nil and type(snapshot.actions) ~= "table" then
    return nil, "actions must be an array"
  end
  if snapshot.inventory ~= nil or snapshot.save ~= nil or snapshot.game ~= nil then
    return nil, "snapshot must not expose live inventory, save or game tables"
  end
  if snapshot.screen == "search" and type(snapshot.search) ~= "table" then
    return nil, "search screen requires search model"
  end
  if snapshot.screen == "machine_filter"
      and type(snapshot.machineFilter) ~= "table" then
    return nil, "machine_filter screen requires machineFilter model"
  end
  if snapshot.screen == "move_info" and type(snapshot.move) ~= "table" then
    return nil, "move_info screen requires move model"
  end
  if (snapshot.screen == "item_options" or snapshot.screen == "item_confirmation")
      and type(snapshot.item) ~= "table" then
    return nil, snapshot.screen .. " requires item model"
  end
  if snapshot.schemaVersion == BAG_PROVIDER_API_VERSION then
    if snapshot.screen == "search" then
      if type(snapshot.search.query) ~= "string" then
        return nil, "search query must be text"
      end
      local ok, reason = PokedexProviderUI.validateBagKeyboard(
        snapshot.search.keyboard)
      if not ok then return nil, reason end
    elseif snapshot.screen == "machine_filter" then
      local ok, reason = PokedexProviderUI.validateBagSelection(
        snapshot.machineFilter, "machine filter",
        PokedexProviderUI.bagModelRows(snapshot.machineFilter), true)
      if not ok then return nil, reason end
    elseif snapshot.screen == "item_options"
        or snapshot.screen == "item_confirmation" then
      local ok, reason = PokedexProviderUI.validateBagSelection(
        snapshot.item, snapshot.screen:gsub("_", " "),
        PokedexProviderUI.bagModelRows(snapshot.item), true)
      if not ok then return nil, reason end
    end
  end
  return snapshot
end

PokedexProviderUI.drawBagBoldText = function(font,text,x,y)
  local g=love.graphics
  g.setFont(font)
  g.print(text,x,y)
  -- Pixelify Sans is shipped as one variable-font file and LÖVE's Font API
  -- does not expose its weight axis consistently across supported runtimes.
  -- A one-pixel overprint supplies a deterministic bold label while values
  -- remain a single regular-weight draw.
  g.print(text,x+1,y)
end

PokedexProviderUI.drawBagMachineDetail = function(detail,fonts,x,y,w,h)
  if type(detail)~="table" or detail.kind~="machine" then return false end
  local g=love.graphics
  local parameters={}
  for _,parameter in ipairs(detail.parameters or {}) do
    parameters[tostring(parameter.label):upper()]=tostring(parameter.value)
  end
  local lineY=y
  local lineH=22
  local labelFont,valueFont=fonts.tiny,fonts.tiny
  local function row(label,value)
    setColor(COLORS.muted)
    PokedexProviderUI.drawBagBoldText(labelFont,label..":",x,lineY)
    local labelW=labelFont:getWidth(label..": ")+2
    setColor(COLORS.ink); g.setFont(valueFont)
    g.print(fitLabel(valueFont,value or "--",math.max(12,w-labelW)),
      x+labelW,lineY)
    lineY=lineY+lineH
  end
  row("MOVE",parameters.MOVE)
  setColor(COLORS.muted)
  PokedexProviderUI.drawBagBoldText(labelFont,"TYPE:",x,lineY+3)
  drawTypeBadge(detail.typeId,fonts,x+54,lineY,w-54,18)
  lineY=lineY+lineH
  row("CATEGORY",parameters.CATEGORY)
  row("POWER",parameters.POWER)
  row("ACCURACY",parameters.ACCURACY)
  row("PP",parameters.PP)
  setColor(COLORS.muted)
  PokedexProviderUI.drawBagBoldText(labelFont,"DESCRIPTION:",x,lineY)
  lineY=lineY+17
  setColor(COLORS.ink); g.setFont(valueFont)
  local description=(parameters.DESCRIPTION or "--")
    :gsub("\r\n","\n"):gsub("\r","\n")
  -- Preserve explicit provider line breaks, then measured-wrap every segment.
  -- Continuations use the full panel width rather than the label indent.
  local wrapped={}
  for segment in (description.."\n"):gmatch("(.-)\n") do
    local lines=wrapRenderedText(valueFont,segment,w)
    if #lines==0 then lines={""} end
    for _,line in ipairs(lines) do wrapped[#wrapped+1]=line end
  end
  local available=math.max(0,y+h-lineY)
  local visible=math.max(0,math.floor(available/14))
  for i=1,math.min(visible,#wrapped) do
    g.print(wrapped[i],x,lineY+(i-1)*14)
  end
  return true
end

PokedexProviderUI.bagIconImage = function(icon)
  if type(icon) ~= "table" then return nil end
  if icon.image and type(icon.image.getDimensions) == "function" then
    return icon.image
  end
  local path = icon.imagePath or icon.path
  if type(path) ~= "string" or path == "" then return nil end
  local cached = PokedexProviderUI.bagIconCache[path]
  if cached ~= nil then return cached or nil end
  local ok, image = pcall(love.graphics.newImage,
    Assets and type(Assets.resolve) == "function" and Assets.resolve(path) or path)
  if ok and image and type(image.getDimensions) == "function" then
    if image.setFilter then pcall(image.setFilter, image, "nearest", "nearest") end
    PokedexProviderUI.bagIconCache[path] = image
    return image
  end
  PokedexProviderUI.bagIconCache[path] = false
  if bagProviderLogError then
    bagProviderLogError("icon " .. path .. " could not be loaded: " .. tostring(image))
  end
  return nil
end

PokedexProviderUI.drawBagFallbackIcon = function(x, y, category)
  local g = love.graphics
  setColor(COLORS.paper2)
  g.rectangle("fill", x, y, 28, 28)
  setColor(COLORS.muted)
  g.rectangle("line", x + 1, y + 1, 26, 26)
  g.setFont(PokedexProviderUI.bagFonts and PokedexProviderUI.bagFonts.tiny)
  local label = tostring(category or "ITEM"):sub(1, 1):upper()
  g.print(label, x + 10, y + 7)
end

PokedexProviderUI.addBagRegion = function(regions, x, y, w, h, action, value)
  regions[#regions + 1] = { x=x, y=y, w=w, h=h,
    action=action, value=value }
end

PokedexProviderUI.bagSelectedModelIndex = function(model, rows)
  if type(model) ~= "table" or type(rows) ~= "table" then return nil end
  if PokedexProviderUI.bagFiniteInteger(model.selectedIndex, 1) then
    return model.selectedIndex
  end
  if type(model.selectedId) == "string" then
    for i, row in ipairs(rows) do
      if type(row) == "table" and row.id == model.selectedId then return i end
    end
  end
end

PokedexProviderUI.bagSelectedKeyboardKey = function(search)
  local keyboard = type(search) == "table" and search.keyboard
  if type(keyboard) ~= "table" or type(keyboard.keys) ~= "table" then return nil end
  local index = keyboard.selectedIndex
  if not PokedexProviderUI.bagFiniteInteger(index, 1)
      and type(keyboard.selectedKeyId) == "string" then
    for i, key in ipairs(keyboard.keys) do
      if key.id == keyboard.selectedKeyId then index = i break end
    end
  end
  return keyboard.keys[index or 0], index
end

PokedexProviderUI.drawBagScreen = function(
    state, snapshot, fonts, viewW, viewH, errorMessage)
  local g = love.graphics
  viewW, viewH = viewW or DESIGN_W, viewH or DESIGN_H
  PokedexProviderUI.bagFonts = fonts
  setColor(COLORS.paper)
  g.rectangle("fill", 0, 0, viewW, viewH)
  g.setFont(fonts.title)
  setColor(COLORS.ink)
  g.print(snapshot and (snapshot.title or "BAG") or "BAG INCOMPATIBILITY", 18, 13)
  setColor(COLORS.accent)
  g.rectangle("fill", 18, 39, viewW - 36, 3)
  if not snapshot then
    drawPanel(18, 58, viewW - 36, viewH - 80)
    g.setFont(fonts.body)
    setColor(COLORS.disabled)
    g.print("THE ACTIVE BAG PROVIDER RETURNED AN INVALID SNAPSHOT.", 38, 83)
    g.setFont(fonts.small)
    setColor(COLORS.ink)
    local lines = wrapRenderedText(fonts.small, errorMessage or
      "Update Gen1 Widescreen UI and the dependent Bag mod together.", viewW - 76)
    for i=1, math.min(8,#lines) do g.print(lines[i],38,118+(i-1)*20) end
    return
  end
  local regions = {}
  local tabX, tabY = 18, 51
  local tabW = math.max(70, math.floor((viewW - 36) / #snapshot.pockets))
  g.setFont(fonts.tiny)
  for i, pocket in ipairs(snapshot.pockets) do
    local x = tabX + (i - 1) * tabW
    local selected = pocket.id == snapshot.selectedPocketId
    setColor(selected and COLORS.selected or COLORS.paper2)
    g.rectangle("fill", x, tabY, tabW - 3, 28)
    setColor(selected and COLORS.selectedText
      or pocket.enabled == false and COLORS.muted or COLORS.ink)
    g.print(fitLabel(fonts.tiny, pocket.label, tabW - 15), x + 7, tabY + 7)
    PokedexProviderUI.addBagRegion(
      regions, x, tabY, tabW - 3, 28, "pocket", pocket.id)
  end
  local leftX, topY = 18, 87
  local leftW = math.max(310, math.floor(viewW * 0.62))
  local panelH = viewH - topY - 31
  drawPanel(leftX, topY, leftW, panelH)
  drawPanel(leftX + leftW + 10, topY, viewW - leftX - leftW - 28, panelH)
  local visible = math.max(1, math.floor((panelH - 28) / 38))
  local selected = math.max(1, math.min(#snapshot.rows, snapshot.selectedIndex))
  local scroll = math.max(0, math.min(snapshot.scroll or 0,
    math.max(0, #snapshot.rows - visible)))
  if selected <= scroll then scroll = selected - 1 end
  if selected > scroll + visible then scroll = selected - visible end
  g.setFont(fonts.small)
  for slot=1,visible do
    local index = scroll + slot
    local row = snapshot.rows[index]
    if not row then break end
    local y = topY + 12 + (slot - 1) * 38
    if index == selected then
      setColor(COLORS.selected); g.rectangle("fill",leftX+9,y,leftW-18,34)
      setColor(COLORS.accent); g.rectangle("fill",leftX+9,y,5,34)
    else
      setColor(COLORS.paper2); g.rectangle("fill",leftX+9,y,leftW-18,34)
    end
    local icon = PokedexProviderUI.bagIconImage(row.icon)
    local labelX=leftX+20
    if icon then
      drawImageContained(icon,leftX+20,y+3,28,28,1); labelX=leftX+58
    elseif not snapshot.nativeVanilla then
      PokedexProviderUI.drawBagFallbackIcon(leftX+20,y+3,row.category)
      labelX=leftX+58
    end
    setColor(index == selected and COLORS.selectedText
      or row.enabled and COLORS.ink or COLORS.muted)
    g.print(fitLabel(fonts.small,row.label,leftW-(labelX-leftX)-100),labelX,y+8)
    local flags = (row.favorite and "*" or "") .. (row.pinned and "^" or "")
    g.print(flags,leftX+leftW-91,y+8)
    local count = "x" .. tostring(row.count)
    g.print(count,leftX+leftW-21-fonts.small:getWidth(count),y+8)
    PokedexProviderUI.addBagRegion(
      regions,leftX+9,y,leftW-18,34,"selectIndex",index)
  end
  local detail = snapshot.rows[selected]
  local dx = leftX + leftW + 25
  local dw = viewW - dx - 25
  if detail then
    local structured=PokedexProviderUI.drawBagMachineDetail(
      detail.detail,fonts,dx,topY+16,dw,panelH-30)
    if not structured then
      local icon = PokedexProviderUI.bagIconImage(detail.icon)
      if icon then drawImageContained(icon,dx,topY+19,dw,62,2)
      elseif not snapshot.nativeVanilla then
        PokedexProviderUI.drawBagFallbackIcon(
          dx+math.floor((dw-28)/2),topY+36,detail.category) end
      g.setFont(fonts.small); setColor(COLORS.ink)
      g.print(fitLabel(fonts.small,detail.label,dw),dx,topY+91)
      g.setFont(fonts.tiny); setColor(COLORS.muted)
      local lines=wrapRenderedText(fonts.tiny,
        snapshot.description or detail.description or "NO DESCRIPTION.",dw)
      for i=1,math.min(6,#lines) do g.print(lines[i],dx,topY+119+(i-1)*15) end
    end
  end
  if snapshot.screen ~= "bag" then
    local mx,my,mw,mh=math.floor(viewW*0.16),72,math.floor(viewW*0.68),viewH-105
    drawPanel(mx,my,mw,mh)
    g.setFont(fonts.body); setColor(COLORS.ink)
    local heading = snapshot.screen:gsub("_"," "):upper()
    g.print(heading,mx+20,my+18)
    local model = snapshot.search or snapshot.machineFilter or snapshot.move
      or snapshot.item or {}
    if snapshot.schemaVersion == 2 and snapshot.screen == "search" then
      local keyboard = model.keyboard
      g.setFont(fonts.small); setColor(COLORS.muted)
      g.print("QUERY",mx+20,my+53)
      setColor(COLORS.paper2); g.rectangle("fill",mx+76,my+48,mw-96,27)
      setColor(COLORS.ink)
      g.print(fitLabel(fonts.small,model.query or "",mw-110),mx+83,my+54)
      local columns=math.max(1,math.min(#keyboard.keys,keyboard.columns))
      local rows=math.max(1,math.ceil(#keyboard.keys/columns))
      local gap=4
      local keyW=math.floor((mw-40-(columns-1)*gap)/columns)
      local keyH=math.max(20,math.min(29,
        math.floor((mh-101-(rows-1)*gap)/rows)))
      local selectedKey,selectedIndex=
        PokedexProviderUI.bagSelectedKeyboardKey(model)
      g.setFont(fonts.tiny)
      for i,key in ipairs(keyboard.keys) do
        local col=(i-1)%columns
        local row=math.floor((i-1)/columns)
        local x=mx+20+col*(keyW+gap)
        local y=my+86+row*(keyH+gap)
        local focused=i==selectedIndex
        setColor(focused and COLORS.selected or COLORS.paper2)
        g.rectangle("fill",x,y,keyW,keyH)
        if focused then
          setColor(COLORS.accent); g.rectangle("fill",x,y,4,keyH)
        end
        setColor(focused and COLORS.selectedText or COLORS.ink)
        local label=fitLabel(fonts.tiny,key.label,keyW-10)
        g.print(label,x+math.floor((keyW-fonts.tiny:getWidth(label))/2),
          y+math.max(3,math.floor((keyH-fonts.tiny:getHeight())/2)))
        PokedexProviderUI.addBagRegion(
          regions,x,y,keyW,keyH,"keyboardKey",key.id)
      end
    else
      g.setFont(fonts.small)
      local lines = PokedexProviderUI.bagModelRows(model) or {}
      if model.query then
        g.print("QUERY  "..tostring(model.query),mx+20,my+53)
      end
      local selectedIndex=snapshot.schemaVersion==2
        and PokedexProviderUI.bagSelectedModelIndex(model,lines) or nil
      for i,value in ipairs(lines) do
        local y=my+72+(i-1)*27
        local focused=i==selectedIndex
        if focused then
          setColor(COLORS.selected); g.rectangle("fill",mx+15,y,mw-30,26)
          setColor(COLORS.accent); g.rectangle("fill",mx+15,y,4,26)
          setColor(COLORS.selectedText)
        else
          setColor(COLORS.ink)
        end
        local label=type(value)=="table" and (value.label or value.value) or value
        g.print(fitLabel(fonts.small,label or "",mw-48),mx+24,y+5)
        PokedexProviderUI.addBagRegion(
          regions,mx+15,y,mw-30,26,"modalIndex",i)
      end
    end
  end
  g.setFont(fonts.tiny); setColor(COLORS.muted)
  local money = snapshot.money and ("MONEY  "..tostring(snapshot.money).."     ") or ""
  local hints = snapshot.hints or "A SELECT   B BACK   L/R POCKET"
  g.print(money .. hints,18,viewH-20)
  PokedexProviderUI.bagHitRegions[state]=regions
end

PokedexProviderUI.nativeBagRange = function(game)
  local states=game and game.stack and game.stack.states
  if type(states)~="table" then return nil end
  for i,state in ipairs(states) do
    if getmetatable(state)==ListMenuClass and state.kind=="bag" then
      return state,i,#states
    end
  end
end

-- Short, deliberately non-technical field descriptions for the vanilla
-- inventory.  The amounts and behavior mirror src/inventory/ItemEffects.lua;
-- descriptions never own or predict whether an item can currently be used.
PokedexProviderUI.itemDescriptions = {
  MASTER_BALL="Catches a wild POKEMON without fail.",
  ULTRA_BALL="A high-performance Ball for catching wild POKEMON.",
  GREAT_BALL="A better Ball for catching wild POKEMON.",
  POKE_BALL="A Ball used to catch wild POKEMON.",
  SAFARI_BALL="A special Ball used in the Safari Zone.",
  POTION="Restores 20 HP to one POKEMON.",
  SUPER_POTION="Restores 50 HP to one POKEMON.",
  HYPER_POTION="Restores 200 HP to one POKEMON.",
  MAX_POTION="Fully restores one POKEMON's HP.",
  FULL_RESTORE="Fully restores HP and cures status problems.",
  FRESH_WATER="Restores 50 HP to one POKEMON.",
  SODA_POP="Restores 60 HP to one POKEMON.",
  LEMONADE="Restores 80 HP to one POKEMON.",
  ANTIDOTE="Cures poison.", BURN_HEAL="Cures a burn.",
  ICE_HEAL="Thaws a frozen POKEMON.", AWAKENING="Wakes a sleeping POKEMON.",
  PARLYZ_HEAL="Cures paralysis.", FULL_HEAL="Cures any status problem.",
  REVIVE="Revives a fainted POKEMON with half its HP.",
  MAX_REVIVE="Revives a fainted POKEMON with full HP.",
  ETHER="Restores 10 PP to one move.", MAX_ETHER="Fully restores one move's PP.",
  ELIXER="Restores 10 PP to every move.",
  MAX_ELIXER="Fully restores every move's PP.",
  HP_UP="Raises one POKEMON's HP potential.",
  PROTEIN="Raises one POKEMON's ATTACK potential.",
  IRON="Raises one POKEMON's DEFENSE potential.",
  CARBOS="Raises one POKEMON's SPEED potential.",
  CALCIUM="Raises one POKEMON's SPECIAL potential.",
  PP_UP="Raises the maximum PP of one move.",
  RARE_CANDY="Raises one POKEMON by one level.",
  FIRE_STONE="Makes certain POKEMON evolve.",
  WATER_STONE="Makes certain POKEMON evolve.",
  THUNDER_STONE="Makes certain POKEMON evolve.",
  LEAF_STONE="Makes certain POKEMON evolve.",
  MOON_STONE="Makes certain POKEMON evolve.",
  REPEL="Keeps weaker wild POKEMON away for 100 steps.",
  SUPER_REPEL="Keeps weaker wild POKEMON away for 200 steps.",
  MAX_REPEL="Keeps weaker wild POKEMON away for 250 steps.",
  ESCAPE_ROPE="Returns you to safety from inside a dungeon.",
  POKE_DOLL="Lets you escape from a wild POKEMON.",
  X_ATTACK="Raises ATTACK during a battle.",
  X_DEFEND="Raises DEFENSE during a battle.",
  X_SPEED="Raises SPEED during a battle.",
  X_SPECIAL="Raises SPECIAL during a battle.",
  X_ACCURACY="Makes attacks avoid missing during a battle.",
  DIRE_HIT="Raises the chance of critical hits in battle.",
  GUARD_SPEC="Prevents stat reduction during a battle.",
  TOWN_MAP="Shows a map of the Kanto region.",
  BICYCLE="A folding bicycle for faster travel.",
  ITEMFINDER="Checks for hidden items nearby.",
  COIN_CASE="Stores and displays your Game Corner Coins.",
  POKE_FLUTE="Wakes sleeping POKEMON with a familiar tune.",
  OLD_ROD="A fishing rod for catching POKEMON in water.",
  GOOD_ROD="A good fishing rod for catching water POKEMON.",
  SUPER_ROD="The best fishing rod for catching water POKEMON.",
  EXP_ALL="Shares battle experience with the whole party.",
  SILPH_SCOPE="Reveals the true form of ghostly POKEMON.",
  NUGGET="A solid gold nugget that can be sold for money.",
  OLD_AMBER="Ancient amber containing rare POKEMON material.",
  DOME_FOSSIL="A fossil of an ancient POKEMON.",
  HELIX_FOSSIL="A fossil of an ancient POKEMON.",
  S_S_TICKET="A ticket for boarding the S.S. ANNE.",
  BIKE_VOUCHER="Can be exchanged for a BICYCLE.",
  OAKS_PARCEL="A parcel to deliver to PROF. OAK.",
  SECRET_KEY="Opens the locked CINNABAR GYM.",
  CARD_KEY="Opens doors inside SILPH CO.",
  LIFT_KEY="Operates the TEAM ROCKET elevator.",
  GOLD_TEETH="The Safari Zone Warden's lost teeth.",
}

PokedexProviderUI.itemDescription = function(game, id, def)
  id = tostring(id or ""):upper()
  local fixed = PokedexProviderUI.itemDescriptions[id]
  if fixed then return fixed end
  if def and def.machine then
    local moveId = def.machine.move
    local move = game and game.data and game.data.moves
      and game.data.moves[moveId]
    local name = cleanLabel(move and move.name or moveId or "A MOVE")
    if tostring(def.machine.kind or ""):upper() == "HM" then
      return "Teaches " .. name .. ". It can be used repeatedly."
    end
    return "Teaches " .. name .. " to a compatible POKEMON."
  end
  if def and type(def.description) == "string" and def.description ~= "" then
    return cleanLabel(def.description)
  end
  if def and type(def.desc) == "string" and def.desc ~= "" then
    return cleanLabel(def.desc)
  end
  local effect = def and def.effect and game and game.data
    and game.data.item_effects and game.data.item_effects[def.effect]
  if effect and type(effect.description) == "string" then
    return cleanLabel(effect.description)
  end
  if def and def.keyItem then return "An important item used during your journey." end
  if def and def.effect then return "A special item with a custom effect." end
  return "An item carried in your Bag."
end

PokedexProviderUI.nativeBagSnapshot = function(game,bag,top)
  local rows={}
  for _,item in ipairs(bag.items or {}) do
    local id=item.value
    local def=game and game.data and game.data.items and game.data.items[id]
    local count=game and game.save and game.save.inventory
      and tonumber(game.save.inventory[id]) or tonumber(
        tostring(item.right or ""):match("%d+")) or 0
    rows[#rows+1]={ itemId=tostring(id or item.label or #rows+1),
      label=cleanLabel(item.label or id or "ITEM"),count=math.max(0,count),
      enabled=item.enabled~=false,favorite=false,pinned=false,
      category=def and def.keyItem and "key" or "item",
      description=PokedexProviderUI.itemDescription(game,id,def),
      icon=def and def.icon and {imagePath=def.icon} or nil }
  end
  local screen,itemModel="bag",nil
  if top and top~=bag and getmetatable(top)==MenuClass then
    screen="item_options"; itemModel={options={}}
    for _,entry in ipairs(top.items or {}) do
      itemModel.options[#itemModel.options+1]=cleanLabel(entry.label or "OPTION")
    end
  elseif top and top~=bag and PokedexProviderUI.quantityBoxClass
      and getmetatable(top)==PokedexProviderUI.quantityBoxClass then
    screen="item_confirmation"
    itemModel={lines={"QUANTITY  x"..tostring(top.qty or 1),
      "MAX  x"..tostring(top.max or 1)}}
  elseif top and top~=bag and ChoiceBoxClass
      and getmetatable(top)==ChoiceBoxClass then
    screen="item_confirmation"
    itemModel={lines={"CONFIRM ITEM ACTION?","YES / NO"}}
  end
  return { schemaVersion=1,screen=screen,mode=bag.battle and "battle" or "field",
    nativeVanilla=true,
    title="BAG",pockets={{id="items",label="ITEMS",enabled=true}},
    selectedPocketId="items",rows=rows,
    selectedIndex=math.max(1,math.min(#rows,tonumber(bag.index) or 1)),
    scroll=math.max(0,tonumber(bag.scroll) or 0),
    money=game and game.save and tonumber(game.save.money) or 0,
    description=rows[bag.index or 1] and rows[bag.index or 1].description,
    item=itemModel,hints="A SELECT   B BACK   SELECT MOVE" }
end

PokedexProviderUI.pcMenuLabels = function(state)
  local labels={}
  for _,entry in ipairs(type(state) == "table" and state.items or {}) do
    labels[#labels+1]=PokedexProviderUI.pcDisplayLabel(entry.label):upper()
  end
  return labels
end

PokedexProviderUI.pcDisplayLabel = function(value)
  local label=cleanLabel(value or "")
  label=label:gsub("<[Pp][Kk]><[Mm][Nn]>","POKEMON")
  label=label:gsub("<[Pp][Kk]>","PO")
  label=label:gsub("<[Mm][Nn]>","KEMON")
  return label
end

PokedexProviderUI.isPcRoot = function(state)
  if type(state)~="table" then return false end
  if state.__widescreenUiPcRoot then return true end
  if getmetatable(state)~=MenuClass then return false end
  local joined=table.concat(PokedexProviderUI.pcMenuLabels(state),"|")
  local playerItems=joined:find("WITHDRAW ITEM",1,true)
    and joined:find("DEPOSIT ITEM",1,true)
  local boxes=joined:find("WITHDRAW POKEMON",1,true)
    and joined:find("DEPOSIT POKEMON",1,true)
  local terminal=joined:find("LOG OFF",1,true)
    and (joined:find("BILL'S PC",1,true)
      or joined:find("SOMEONE'S PC",1,true)
      or joined:find("PROF.OAK'S PC",1,true))
  return not not (playerItems or boxes or terminal)
end

PokedexProviderUI.pcSessionActive = function(game)
  local states=game and game.stack and game.stack.states
  if type(states)~="table" then return false end
  for _,state in ipairs(states) do
    if PokedexProviderUI.isPcRoot(state) then return true end
  end
  return false
end

PokedexProviderUI.pcPresentation = function(game)
  local states=game and game.stack and game.stack.states
  if type(states)~="table" then return nil end
  for i,state in ipairs(states) do
    if PokedexProviderUI.isPcRoot(state) then
      local base=#states
      while base>i do
        local mt=getmetatable(states[base])
        if mt==TextBoxClass or mt==ChoiceBoxClass then base=base-1 else break end
      end
      local content=states[base]
      local mt=getmetatable(content)
      local primary,popup
      if base==i then
        primary=content
      elseif mt==ListMenuClass then
        primary=content
      elseif (mt==MenuClass or mt==PokedexProviderUI.quantityBoxClass)
          and base>i and getmetatable(states[base-1])==ListMenuClass then
        primary=states[base-1]
        popup=content
      elseif mt==MenuClass then
        -- A nested BoxMenu/PlayerPC menu is another full PC page, not the
        -- per-Pokemon action popup (which always sits over a ListMenu).
        primary=content
      else
        -- SummaryMenu and any future non-PC screen above the root own their
        -- own presentation.  Returning nil prevents the PC layer from
        -- swallowing it (the old cause of STATS playing only a cry).
        PokedexProviderUI.currentPcView=nil
        return nil
      end
      PokedexProviderUI.currentPcView={state=primary,root=i,last=#states,
        base=base,popup=popup}
      return primary,i,#states,base
    end
  end
  -- The Pokemon Center terminal chooser is built inside OverworldController,
  -- not by a dedicated screen constructor. Recognize only its unique PC
  -- labels so unrelated generic menus remain untouched.
  for i,state in ipairs(states) do
    if getmetatable(state)==MenuClass then
      local joined=table.concat(PokedexProviderUI.pcMenuLabels(state),"|")
      if joined:find("LOG OFF",1,true)
          and (joined:find("BILL'S PC",1,true)
            or joined:find("SOMEONE'S PC",1,true)
            or joined:find("PROF.OAK'S PC",1,true)) then
        state.__widescreenUiPcRoot=true
        PokedexProviderUI.currentPcView={state=states[#states],root=i,
          last=#states,base=#states}
        return states[#states],i,#states,#states
      end
    end
  end
end

PokedexProviderUI.pcContext = {
  ["BILL'S PC"]="Store, withdraw, release, or inspect your POKEMON.",
  ["SOMEONE'S PC"]="Access the POKEMON storage system.",
  ["PROF.OAK'S PC"]="Ask PROF. OAK to rate your POKEDEX progress.",
  ["WITHDRAW ITEM"]="Move an item from PC storage into your Bag.",
  ["DEPOSIT ITEM"]="Move an item from your Bag into PC storage.",
  ["TOSS ITEM"]="Discard an item stored in the PC.",
  ["WITHDRAW POKEMON"]="Move a stored POKEMON into your party.",
  ["DEPOSIT POKEMON"]="Move a party POKEMON into the current Box.",
  ["MOVE POKEMON"]="Rearrange POKEMON within Boxes or the party.",
  ["RELEASE POKEMON"]="Release a stored POKEMON. This cannot be undone.",
  ["CHANGE BOX"]="Choose which storage Box is currently active.",
  ["PRINT BOX"]="Save a printable list of the current Box.",
  ["LOG OFF"]="Close the PC and return to the room.",
  ["SEE YA!"]="Close the POKEMON storage system.",
}

PokedexProviderUI.pcEntryDescription = function(game,state,entry)
  local label=PokedexProviderUI.pcDisplayLabel(entry and entry.label):upper()
  local known=PokedexProviderUI.pcContext[label]
  if known then return known end
  local id=entry and entry.value
  local def=id and game and game.data and game.data.items and game.data.items[id]
  if def then return PokedexProviderUI.itemDescription(game,id,def) end
  if label:find("BOX",1,true) then return "Select this POKEMON storage Box." end
  if label:find(":L",1,true) then return "Open this POKEMON's storage actions." end
  return "Choose this option."
end

PokedexProviderUI.pcSelectedPokemon = function(game,state)
  if not (game and type(state)=="table") then return nil end
  local title=PokedexProviderUI.pcDisplayLabel(state.title):upper()
  local entry=state.items and state.items[state.index or 1]
  local index=tonumber(entry and entry.value) or tonumber(state.index) or 1
  local save=game.save or {}
  -- Pokemon deposit lists are explicitly titled PARTY (DEPOSIT). Do not use
  -- the party index for DEPOSIT ITEM: its first six rows otherwise appear to
  -- correspond to the six party slots and leak the Party detail portrait.
  if title:find("PARTY",1,true) and title:find("DEPOSIT",1,true) then
    return type(save.party)=="table" and save.party[index] or nil
  end
  if title:find("BOX",1,true)
      and (title:find("WITHDRAW",1,true) or title:find("RELEASE",1,true)) then
    local box=type(save.boxes)=="table" and save.boxes[save.currentBox or 1]
    return type(box)=="table" and box[index] or nil
  end
end

PokedexProviderUI.pcPokemonStats = function(game,mon)
  if not mon then return {} end
  if type(mon.stats)=="table" then return mon.stats end
  local def=monDefinition(game,mon)
  if Stats and type(Stats.calc)=="function" and def then
    local ok,value=pcall(Stats.calc,def,tonumber(mon.level) or 1,
      mon.dvs,mon.statExp)
    if ok and type(value)=="table" then return value end
  end
  return {}
end

PokedexProviderUI.drawPcPokemonDetail = function(game,state,fonts,x,y,w,h)
  local mon=PokedexProviderUI.pcSelectedPokemon(game,state)
  if not mon then return false end
  local g=love.graphics
  local name=monName(game,mon)
  local showShiny=pokemonIsShiny(mon)
  g.setFont(fonts.body); setColor(COLORS.ink)
  drawPokemonLabel(fonts.body,name,x+13,y+12,w-26-(showShiny and 22 or 0))
  if showShiny then drawShinyStarIcon(x+w-31,y+11,16) end
  drawPartyBattleSprite(game,mon,x+12,y+38,w-24,112,1.08,"pc",mon)
  local stats=PokedexProviderUI.pcPokemonStats(game,mon)
  g.setFont(fonts.tiny); setColor(COLORS.muted)
  g.print("LEVEL",x+13,y+151)
  setColor(COLORS.ink)
  g.print(tostring(mon.level or "?"),x+w-13-fonts.tiny:getWidth(
    tostring(mon.level or "?")),y+151)
  local maxHP=math.max(1,tonumber(stats.hp) or tonumber(mon.hp) or 1)
  local hp=math.max(0,math.min(maxHP,tonumber(mon.hp) or maxHP))
  setColor(COLORS.muted); g.print("HP",x+13,y+169)
  local hpText=string.format("%d/%d",hp,maxHP)
  setColor(COLORS.ink)
  g.print(hpText,x+w-13-fonts.tiny:getWidth(hpText),y+169)
  drawHPBar(x+13,y+185,w-26,hp,maxHP)
  local rows={{"ATK",stats.attack or stats.atk},{"DEF",stats.defense or stats.def},
    {"SPD",stats.speed or stats.spd},{"SPC",stats.special or stats.spc
      or stats.specialAttack}}
  for i,row in ipairs(rows) do
    local col=(i-1)%2
    local line=math.floor((i-1)/2)
    local rx=x+13+col*math.floor((w-26)/2)
    local ry=y+199+line*22
    setColor(COLORS.muted); g.print(row[1],rx,ry)
    setColor(COLORS.ink); g.print(tostring(math.floor(tonumber(row[2]) or 0)),
      rx+30,ry)
  end
  return true
end

PokedexProviderUI.drawPcPopup = function(state,fonts,viewW,viewH)
  if type(state)~="table" then return end
  local g=love.graphics
  if getmetatable(state)==PokedexProviderUI.quantityBoxClass then
    local w,h=174,82
    local x,y=viewW-w-18,viewH-h-27
    drawPanel(x,y,w,h)
    g.setFont(fonts.small); setColor(COLORS.muted)
    g.print("QUANTITY",x+14,y+14)
    g.setFont(fonts.body); setColor(COLORS.ink)
    local value="x"..tostring(state.qty or 1)
    g.print(value,x+w-15-fonts.body:getWidth(value),y+40)
    return
  end
  local items=state.items or {}
  if #items==0 then return end
  local rowH=28
  local w,h=188,49+#items*rowH
  local x,y=viewW-w-18,viewH-h-27
  drawPanel(x,y,w,h)
  g.setFont(fonts.small); setColor(COLORS.ink)
  g.print("ACTIONS",x+13,y+12)
  setColor(COLORS.accent); g.rectangle("fill",x+76,y+21,w-89,3)
  for i,entry in ipairs(items) do
    local ry=y+39+(i-1)*rowH
    local active=i==(state.index or 1)
    setColor(active and COLORS.selected or COLORS.paper2)
    g.rectangle("fill",x+10,ry,w-20,rowH-3)
    if active then setColor(COLORS.accent); g.rectangle("fill",x+10,ry,4,rowH-3) end
    setColor(active and COLORS.selectedText or COLORS.ink)
    g.print(PokedexProviderUI.pcDisplayLabel(entry.label),x+22,ry+5)
  end
end

PokedexProviderUI.drawPcScreen = function(game,state,fonts,viewW,viewH)
  local g=love.graphics
  viewW,viewH=viewW or DESIGN_W,viewH or DESIGN_H
  setColor(COLORS.paper); g.rectangle("fill",0,0,viewW,viewH)
  g.setFont(fonts.title); setColor(COLORS.ink); g.print("PC STORAGE",18,13)
  setColor(COLORS.accent); g.rectangle("fill",18,39,viewW-36,3)
  local listX,listY,listW,listH=18,56,math.floor(viewW*.61),viewH-83
  local detailX=listX+listW+10
  local detailW=viewW-detailX-18
  drawPanel(listX,listY,listW,listH); drawPanel(detailX,listY,detailW,listH)
  local title=PokedexProviderUI.pcDisplayLabel(state and state.title or "PC MENU")
  if getmetatable(state)==MenuClass and title=="" then title="PC MENU" end
  g.setFont(fonts.body); setColor(COLORS.ink)
  g.print(fitLabel(fonts.body,title~="" and title or "PC MENU",listW-30),listX+15,listY+13)
  setColor(COLORS.accent); g.rectangle("fill",listX+15,listY+39,listW-30,3)
  local items=type(state)=="table" and state.items or {}
  local selected=math.max(1,math.min(#items,tonumber(state and state.index) or 1))
  local visible=math.max(1,math.floor((listH-64)/31))
  local scroll=math.max(0,tonumber(state and state.scroll) or 0)
  if selected<=scroll then scroll=selected-1 end
  if selected>scroll+visible then scroll=selected-visible end
  g.setFont(fonts.small)
  for slot=1,visible do
    local index=scroll+slot
    local entry=items[index]
    if not entry then break end
    local y=listY+53+(slot-1)*31
    local active=index==selected
    setColor(active and COLORS.selected or COLORS.paper2)
    g.rectangle("fill",listX+12,y,listW-24,27)
    if active then setColor(COLORS.accent); g.rectangle("fill",listX+12,y,5,27) end
    setColor(active and COLORS.selectedText or COLORS.ink)
    g.print(fitLabel(fonts.small,PokedexProviderUI.pcDisplayLabel(entry.label),listW-116),listX+27,y+5)
    if entry.right then
      local right=cleanLabel(entry.right)
      g.print(right,listX+listW-27-fonts.small:getWidth(right),y+5)
    end
  end
  local entry=items[selected]
  local pokemonDetail=PokedexProviderUI.drawPcPokemonDetail(
    game,state,fonts,detailX,listY,detailW,listH)
  if not pokemonDetail then
    g.setFont(fonts.body); setColor(COLORS.ink)
    g.print(fitLabel(fonts.body,entry and PokedexProviderUI.pcDisplayLabel(entry.label) or "DETAILS",detailW-28),detailX+14,listY+13)
    setColor(COLORS.accent); g.rectangle("fill",detailX+14,listY+39,detailW-28,3)
    g.setFont(fonts.small); setColor(COLORS.muted)
    local description=PokedexProviderUI.pcEntryDescription(game,state,entry)
    for i,line in ipairs(wrapRenderedText(fonts.small,description,detailW-28)) do
      if i>7 then break end
      g.print(line,detailX+14,listY+58+(i-1)*19)
    end
  end
  local save=game and game.save or {}
  local party=type(save.party)=="table" and #save.party or 0
  local boxes=save.boxes
  local current=tonumber(save.currentBox) or 1
  local stored=type(boxes)=="table" and type(boxes[current])=="table"
    and #boxes[current] or 0
  if not pokemonDetail then
    g.setFont(fonts.tiny); setColor(COLORS.muted)
    g.print("PARTY  "..party.."/6",detailX+14,listY+listH-63)
    g.print("BOX "..current.."  "..stored.."/20",detailX+14,listY+listH-45)
  end
  if PokedexProviderUI.quantityBoxClass
      and getmetatable(state)==PokedexProviderUI.quantityBoxClass then
    g.setFont(fonts.body); setColor(COLORS.ink)
    local qty="QUANTITY  x"..tostring(state.qty or 1)
    g.print(qty,detailX+14,listY+112)
  end
  g.setFont(fonts.tiny); setColor(COLORS.muted)
  g.print("A SELECT   B BACK",18,viewH-20)
  local view=PokedexProviderUI.currentPcView
  if view and view.popup then
    PokedexProviderUI.drawPcPopup(view.popup,fonts,viewW,viewH)
  end
end

PokedexProviderUI.STORAGE_SCREENS = {
  withdraw=true,deposit=true,move=true,party=true,popup=true,stats=true,
}

PokedexProviderUI.STORAGE_TARGET_STATES = {
  occupied=true,empty=true,held_origin=true,valid_target=true,
  valid_swap=true,invalid_target=true,
}

PokedexProviderUI.storageFiniteInteger = function(value, minimum)
  return type(value)=="number" and value==value and value~=math.huge
    and value~=-math.huge and value%1==0 and value>=(minimum or 0)
end

PokedexProviderUI.validateStoragePokemon = function(model,label)
  if type(model)~="table" then return nil,label.." must be a table" end
  if model.enabled~=nil and type(model.enabled)~="boolean" then
    return nil,label.." enabled must be boolean"
  end
  if model.disabledReason~=nil and type(model.disabledReason)~="string" then
    return nil,label.." disabledReason must be text"
  end
  if model.state~=nil and not PokedexProviderUI.STORAGE_TARGET_STATES[model.state] then
    return nil,label.." has unsupported target state"
  end
  if model.empty==true then return true end
  if type(model.identityToken)~="string" and type(model.identityToken)~="number" then
    return nil,label.." requires a stable identityToken"
  end
  if type(model.speciesId)~="string" or model.speciesId=="" then
    return nil,label.." requires speciesId"
  end
  if type(model.name)~="string" then return nil,label.." requires name" end
  if model.icon~=nil and type(model.icon)~="table" then
    return nil,label.." icon must be a descriptor"
  end
  if model.presentation~=nil and type(model.presentation)~="table" then
    return nil,label.." presentation must be a read-only Pokemon copy"
  end
  return true
end

PokedexProviderUI.validatePokemonStorageSnapshot = function(snapshot)
  if type(snapshot)~="table" then return nil,"snapshot must be a table" end
  if snapshot.schemaVersion~=PokedexProviderUI.storageApiVersion then
    return nil,"unsupported snapshot schemaVersion"
  end
  if not PokedexProviderUI.STORAGE_SCREENS[snapshot.screen] then
    return nil,"unsupported storage screen "..tostring(snapshot.screen)
  end
  if type(snapshot.box)~="table"
      or not PokedexProviderUI.storageFiniteInteger(snapshot.box.viewedIndex,1)
      or snapshot.box.viewedIndex>12
      or not PokedexProviderUI.storageFiniteInteger(snapshot.box.activeIndex,1)
      or snapshot.box.activeIndex>12
      or not PokedexProviderUI.storageFiniteInteger(snapshot.box.occupancy,0)
      or not PokedexProviderUI.storageFiniteInteger(snapshot.box.capacity,1)
      or snapshot.box.capacity~=20 or snapshot.box.occupancy>20 then
    return nil,"box requires viewed/active indices 1..12 and occupancy/capacity 20"
  end
  local grid=snapshot.grid
  if type(grid)~="table" or grid.columns~=5 or grid.rows~=4
      or type(grid.cells)~="table" or #grid.cells~=20
      or not PokedexProviderUI.storageFiniteInteger(grid.selectedIndex,1)
      or grid.selectedIndex>20 then
    return nil,"grid must be a fixed 5x4 model with 20 cells and selectedIndex"
  end
  for i,cell in ipairs(grid.cells) do
    local ok,reason=PokedexProviderUI.validateStoragePokemon(cell,
      "grid cell "..tostring(i))
    if not ok then return nil,reason end
  end
  local party=snapshot.party
  if type(party)~="table" or type(party.open)~="boolean"
      or type(party.slots)~="table" or #party.slots~=6
      or not PokedexProviderUI.storageFiniteInteger(party.selectedIndex,1)
      or party.selectedIndex>6 then
    return nil,"party requires open, six slots and selectedIndex"
  end
  for i,slot in ipairs(party.slots) do
    local ok,reason=PokedexProviderUI.validateStoragePokemon(slot,
      "party slot "..tostring(i))
    if not ok then return nil,reason end
  end
  if snapshot.partyButton~=nil then
    local button=snapshot.partyButton
    if type(button)~="table" or type(button.label)~="string"
        or (button.selected~=nil and type(button.selected)~="boolean")
        or (button.enabled~=nil and type(button.enabled)~="boolean")
        or (button.disabledReason~=nil
          and type(button.disabledReason)~="string") then
      return nil,"partyButton requires label and optional boolean state"
    end
  end
  if snapshot.selectedRegion~="grid" and snapshot.selectedRegion~="party"
      and snapshot.selectedRegion~="partyButton"
      and snapshot.selectedRegion~="popup" then
    return nil,"selectedRegion must be grid, partyButton, party or popup"
  end
  if snapshot.selectedRegion=="partyButton" and snapshot.partyButton==nil then
    return nil,"selectedRegion partyButton requires a partyButton model"
  end
  if snapshot.held~=nil then
    local ok,reason=PokedexProviderUI.validateStoragePokemon(snapshot.held,"held Pokemon")
    if not ok then return nil,reason end
    if detail.speciesName~=nil and type(detail.speciesName)~="string" then
      return nil,"detail speciesName must be text"
    end
    if detail.nicknamed~=nil and type(detail.nicknamed)~="boolean" then
      return nil,"detail nicknamed must be boolean"
    end
    if detail.gender~=nil and type(detail.gender)~="string" then
      return nil,"detail gender must be text"
    end
  end
  if snapshot.detail~=nil then
    local detail=snapshot.detail
    local ok,reason=PokedexProviderUI.validateStoragePokemon(detail,"detail")
    if not ok then return nil,reason end
    if not PokedexProviderUI.storageFiniteInteger(detail.level,1)
        or not PokedexProviderUI.storageFiniteInteger(detail.hp,0)
        or not PokedexProviderUI.storageFiniteInteger(detail.maxHp,1)
        or detail.hp>detail.maxHp or type(detail.stats)~="table"
        or type(detail.types)~="table" or #detail.types<1 or #detail.types>2
        or type(detail.moves)~="table" or #detail.moves>4 then
      return nil,"detail requires level, HP, stats, one/two types and up to four moves"
    end
    for _,key in ipairs({"hp","attack","defense","speed","special"}) do
      if not PokedexProviderUI.storageFiniteInteger(detail.stats[key],0) then
        return nil,"detail stats require five finite Gen 1 values"
      end
    end
    for i,move in ipairs(detail.moves) do
      if type(move)~="table" or type(move.name)~="string"
          or not PokedexProviderUI.storageFiniteInteger(move.pp,0)
          or not PokedexProviderUI.storageFiniteInteger(move.maxPp,0) then
        return nil,"move "..tostring(i).." requires name and PP"
      end
    end
  end
  if snapshot.popup~=nil then
    local popup=snapshot.popup
    if type(popup)~="table" or type(popup.rows)~="table" or #popup.rows<1
        or not PokedexProviderUI.storageFiniteInteger(popup.selectedIndex,1)
        or popup.selectedIndex>#popup.rows then
      return nil,"popup requires rows and selectedIndex"
    end
    for i,row in ipairs(popup.rows) do
      if type(row)~="table" or type(row.id)~="string" or row.id==""
          or type(row.label)~="string"
          or (row.enabled~=nil and type(row.enabled)~="boolean")
          or (row.disabledReason~=nil
            and type(row.disabledReason)~="string") then
        return nil,"popup row "..tostring(i).." requires id, label and enabled state"
      end
    end
  end
  if snapshot.save~=nil or snapshot.boxes~=nil or snapshot.inventory~=nil
      or snapshot.game~=nil then
    return nil,"snapshot must not expose live save or storage tables"
  end
  return snapshot
end

PokedexProviderUI.resetStorageProviderCaches = function()
  PokedexProviderUI.storageLastValid=setmetatable({}, {__mode="k"})
  PokedexProviderUI.storageHitRegions=setmetatable({}, {__mode="k"})
  PokedexProviderUI.storageProviderFaults=setmetatable({}, {__mode="k"})
  PokedexProviderUI.storagePortraitTokens={}
  PokedexProviderUI.storageIconCache={}
end

PokedexProviderUI.storageOwnsState = function(state)
  local provider=PokedexProviderUI.storageProvider
  if not (provider and type(state)=="table") then return false end
  local ok,matched=pcall(provider.match,state)
  if not ok then
    local message="match exception: "..tostring(matched)
    if PokedexProviderUI.storageProviderLogError then
      PokedexProviderUI.storageProviderLogError(message)
    end
    PokedexProviderUI.storageProviderFaults[state]=message
    return PokedexProviderUI.storageLastValid[state]~=nil
  end
  return matched==true
end

PokedexProviderUI.storageOverlayClass = function(state)
  local mt=getmetatable(state)
  return mt==TextBoxClass or mt==ChoiceBoxClass
end

PokedexProviderUI.storageOpaqueDestination = function(state)
  if state and state.isOpaque then return true end
  local mt=getmetatable(state)
  return mt==PokedexProviderUI.summaryMenuClass
    or mt==PokedexProviderUI.evolutionStateClass
end

PokedexProviderUI.storagePresentation = function(game)
  local provider=PokedexProviderUI.storageProvider
  local states=game and game.stack and game.stack.states
  if not (provider and type(states)=="table") then return nil end
  local state,index
  for i=#states,1,-1 do
    if PokedexProviderUI.storageOwnsState(states[i]) then state,index=states[i],i break end
  end
  if not state then return nil end
  for i=index+1,#states do
    if PokedexProviderUI.storageOpaqueDestination(states[i]) then return nil end
    if not PokedexProviderUI.storageOverlayClass(states[i]) then return nil end
  end
  local fault=PokedexProviderUI.storageProviderFaults[state]
  local snapshot
  if not fault or PokedexProviderUI.storageLastValid[state] then
    local ok,value=pcall(provider.snapshot,game,state)
    if not ok then fault="snapshot exception: "..tostring(value)
    else
      local valid,reason=PokedexProviderUI.validatePokemonStorageSnapshot(value)
      if valid then snapshot=valid
      else fault="invalid snapshot: "..tostring(reason) end
    end
  end
  if snapshot then
    PokedexProviderUI.storageLastValid[state]=snapshot
    PokedexProviderUI.storageProviderFaults[state]=nil
  else
    snapshot=PokedexProviderUI.storageLastValid[state]
    PokedexProviderUI.storageProviderFaults[state]=fault
    if PokedexProviderUI.storageProviderLogError then
      PokedexProviderUI.storageProviderLogError(fault or "provider unavailable")
    end
  end
  return state,snapshot,fault,index,#states
end

PokedexProviderUI.addStorageRegion = function(regions,x,y,w,h,action,value)
  regions[#regions+1]={x=x,y=y,w=w,h=h,action=action,value=value}
end

PokedexProviderUI.routeStoragePointer = function(game,state,event,invoke)
  if type(state)~="table" or type(event)~="table" or event.phase~="pressed"
      or (event.source=="mouse"
        and event.button~=nil and event.button~=1) then return false end
  local regions=state.__widescreenStorageHitRegions
    or PokedexProviderUI.storageHitRegions[state]
  local g=love and love.graphics
  local ww,wh
  if g and type(g.getDimensions)=="function" then ww,wh=g.getDimensions() end
  if type(regions)~="table" or not ww or not wh or ww<=0 or wh<=0 then
    return false
  end
  local scale=math.min(ww/DESIGN_W,wh/DESIGN_H)
  local ox=math.floor((ww-DESIGN_W*scale)/2)
  local oy=math.floor((wh-DESIGN_H*scale)/2)
  local px=((tonumber(event.x) or -1)-ox)/scale
  local py=((tonumber(event.y) or -1)-oy)/scale
  for i=#regions,1,-1 do
    local region=regions[i]
    if px>=region.x and px<=region.x+region.w
        and py>=region.y and py<=region.y+region.h then
      invoke(region.action,game,state,region.value)
      return true
    end
  end
  return false
end

PokedexProviderUI.activateStorageRegion = function(state,region,invoke)
  if type(state)~="table" or type(region)~="table"
      or type(invoke)~="function" then return false end
  invoke(region.action,state.game,state,region.value)
  return true
end

PokedexProviderUI.storagePokemonCopy = function(model)
  if type(model)~="table" or model.empty==true then return nil end
  local mon={}
  for key,value in pairs(type(model.presentation)=="table"
      and model.presentation or {}) do mon[key]=value end
  if mon.species==nil then mon.species=model.speciesId end
  if mon.nickname==nil then mon.nickname=model.name end
  if mon.level==nil then mon.level=model.level end
  if mon.hp==nil then mon.hp=model.hp end
  if mon.shiny==nil then mon.shiny=model.shiny end
  if mon.dvs==nil then mon.dvs=model.dvs end
  if mon.stats==nil and model.stats then mon.stats=model.stats end
  return mon
end

PokedexProviderUI.drawStorageIcon = function(game,model,x,y)
  local g=love.graphics
  local mon=PokedexProviderUI.storagePokemonCopy(model)
  local image,quad=mon and nativePartyIcon(game,mon,false,0)
  if image and quad then
    if image.setFilter then pcall(image.setFilter,image,"nearest","nearest") end
    g.push("all"); setColor({1,1,1,1}); g.draw(image,quad,x,y); g.pop()
    if PaletteFX and type(PaletteFX.markTrueColor)=="function" then
      PaletteFX.markTrueColor(x,y,32,32)
    end
    return true
  end
  local descriptor=type(model)=="table" and model.icon
  if type(descriptor)=="table" and descriptor.image
      and type(descriptor.image.getDimensions)=="function" then
    image=descriptor.image
    if image.setFilter then pcall(image.setFilter,image,"nearest","nearest") end
  elseif type(descriptor)=="table" then
    local path=descriptor.imagePath or descriptor.path
    if type(path)=="string" and path~="" then
      local cached=PokedexProviderUI.storageIconCache[path]
      if cached~=nil then image=cached or nil
      else
        local ok,value=pcall(love.graphics.newImage,
          Assets and type(Assets.resolve)=="function" and Assets.resolve(path) or path)
        if ok and value and type(value.getDimensions)=="function" then
          image=value
          if image.setFilter then pcall(image.setFilter,image,"nearest","nearest") end
          PokedexProviderUI.storageIconCache[path]=image
        else
          PokedexProviderUI.storageIconCache[path]=false
          if PokedexProviderUI.storageProviderLogError then
            PokedexProviderUI.storageProviderLogError(
              "icon "..path.." could not be loaded: "..tostring(value))
          end
        end
      end
    end
  end
  if image then
    local iw,ih=image:getDimensions()
    local frameH=ih>=64 and 32 or ih
    g.push("all"); setColor({1,1,1,1})
    if ih>=64 and love.graphics.newQuad then
      g.draw(image,love.graphics.newQuad(0,0,math.min(32,iw),32,iw,ih),x,y)
    else g.draw(image,x,y,0,32/iw,32/frameH) end
    g.pop(); return true
  end
  setColor(COLORS.paper2); g.circle("fill",x+16,y+16,12)
  setColor(COLORS.muted); g.circle("line",x+16,y+16,12)
  g.line(x+4,y+16,x+28,y+16)
  return false
end

PokedexProviderUI.storageGenderLabel = function(value)
  local gender=tostring(value or ""):lower()
  if gender=="female" or gender=="f" or gender==FEMALE_GLYPH then
    return FEMALE_GLYPH
  end
  if gender=="male" or gender=="m" or gender==MALE_GLYPH then
    return MALE_GLYPH
  end
  return cleanLabel(value)
end

-- Target meaning remains legible in monochrome: each transfer state has a
-- distinct border/corner mark in addition to its color. The provider supplies
-- semantics; Widescreen only presents them.
PokedexProviderUI.drawStorageTarget = function(model,x,y,w,h,active,fonts)
  local g=love.graphics
  model=type(model)=="table" and model or {}
  setColor(active and COLORS.selected or COLORS.paper2)
  g.rectangle("fill",x,y,w,h)
  if active then setColor(COLORS.accent); g.rectangle("fill",x,y,4,h) end
end

PokedexProviderUI.drawStorageTargetOverlay = function(model,x,y,w,h,active)
  local g=love.graphics
  model=type(model)=="table" and model or {}
  local state=model.state or (model.empty==true and "empty" or "occupied")
  setColor(active and COLORS.selectedText or COLORS.muted)
  if state=="held_origin" then
    g.rectangle("line",x+2,y+2,w-4,h-4)
    g.rectangle("line",x+5,y+5,w-10,h-10)
    g.line(x+w-12,y+3,x+w-3,y+12)
  elseif state=="valid_target" then
    local k=8
    g.line(x+2,y+k,x+2,y+2,x+k,y+2)
    g.line(x+w-k,y+2,x+w-2,y+2,x+w-2,y+k)
    g.line(x+2,y+h-k,x+2,y+h-2,x+k,y+h-2)
    g.line(x+w-k,y+h-2,x+w-2,y+h-2,x+w-2,y+h-k)
  elseif state=="valid_swap" then
    g.rectangle("line",x+2,y+2,w-4,h-4)
    g.line(x+w-13,y+3,x+w-3,y+13)
    g.line(x+w-3,y+3,x+w-13,y+13)
  elseif state=="invalid_target" then
    g.line(x+3,y+3,x+w-3,y+h-3)
    g.line(x+w-3,y+3,x+3,y+h-3)
  end
  if model.enabled==false then
    g.line(x+2,y+h-3,x+w-2,y+h-3)
    g.line(x+2,y+h-6,x+w-2,y+h-6)
  end
end

PokedexProviderUI.storageDisabledReason = function(snapshot)
  if not snapshot then return nil end
  local model
  if snapshot.selectedRegion=="grid" then
    model=snapshot.grid and snapshot.grid.cells[snapshot.grid.selectedIndex]
  elseif snapshot.selectedRegion=="party" then
    model=snapshot.party and snapshot.party.slots[snapshot.party.selectedIndex]
  elseif snapshot.selectedRegion=="partyButton" then
    model=snapshot.partyButton
  elseif snapshot.selectedRegion=="popup" then
    model=snapshot.popup and snapshot.popup.rows[snapshot.popup.selectedIndex]
  end
  if model and model.enabled==false and model.disabledReason~="" then
    return model.disabledReason
  end
  return nil
end

PokedexProviderUI.drawStorageDetail = function(game,detail,fonts,x,y,w,h)
  local g=love.graphics
  drawPanel(x,y,w,h)
  if not detail then
    g.setFont(fonts.small); setColor(COLORS.muted)
    g.print("EMPTY SLOT",x+14,y+14); return
  end
  local showShiny=detail.shiny==true or pokemonIsShiny(
    PokedexProviderUI.storagePokemonCopy(detail))
  g.setFont(fonts.small); setColor(COLORS.ink)
  g.print(fitLabel(fonts.small,detail.name,w-42-(showShiny and 18 or 0)),x+13,y+12)
  if showShiny then drawShinyStarIcon(x+w-30,y+9,15) end
  g.setFont(fonts.tiny); setColor(COLORS.muted)
  local species=detail.nicknamed==true and cleanLabel(detail.speciesName) or ""
  local gender=PokedexProviderUI.storageGenderLabel(detail.gender)
  if gender~=FEMALE_GLYPH and gender~=MALE_GLYPH then
    gender=fitLabel(fonts.tiny,gender,34)
  end
  local genderWidth=(gender==FEMALE_GLYPH or gender==MALE_GLYPH)
    and genderGlyphAdvance(fonts.tiny) or fonts.tiny:getWidth(gender)
  if species~="" then
    drawPokemonLabel(fonts.tiny,species,x+13,y+30,w-35-genderWidth)
  end
  if gender~="" then
    drawPokemonLabel(fonts.tiny,gender,x+w-13-genderWidth,y+30,genderWidth)
  end
  for i,typeId in ipairs(detail.types) do
    drawTypeBadge(typeId,fonts,x+13+(i-1)*76,y+45,70,17)
  end
  local mon=PokedexProviderUI.storagePokemonCopy(detail)
  local tokenKey=tostring(detail.identityToken)
  local token=PokedexProviderUI.storagePortraitTokens[tokenKey]
  if not token then token={}; PokedexProviderUI.storagePortraitTokens[tokenKey]=token end
  drawPartyBattleSprite(game,mon,x+12,y+63,w-24,74,1.08,"storage",token)
  g.setFont(fonts.tiny); setColor(COLORS.muted)
  g.print("Lv."..tostring(detail.level),x+13,y+139)
  local hp=string.format("HP %d/%d",detail.hp,detail.maxHp)
  g.print(hp,x+w-13-fonts.tiny:getWidth(hp),y+139)
  drawHPBar(x+13,y+154,w-26,detail.hp,detail.maxHp)
  local s=detail.stats
  local rows={{"ATK",s.attack,"DEF",s.defense},{"SPD",s.speed,"SPC",s.special}}
  for i,row in ipairs(rows) do
    local ry=y+169+(i-1)*17
    setColor(COLORS.muted); g.print(row[1],x+13,ry); g.print(row[3],x+91,ry)
    setColor(COLORS.ink); g.print(tostring(row[2]),x+45,ry); g.print(tostring(row[4]),x+124,ry)
  end
  setColor(COLORS.muted); g.print("MOVES",x+13,y+204)
  for i,move in ipairs(detail.moves) do
    local ry=y+218+(i-1)*14
    setColor(COLORS.ink)
    g.print(fitLabel(fonts.tiny,move.name,w-75),x+13,ry)
    local pp=string.format("%d/%d",move.pp,move.maxPp)
    setColor(COLORS.muted); g.print(pp,x+w-13-fonts.tiny:getWidth(pp),ry)
  end
  if detail.status and detail.status~="" then
    setColor(COLORS.disabled); g.print(detail.status,x+13,y+h-20)
  end
end

PokedexProviderUI.drawPokemonStorageScreen = function(
    game,state,snapshot,fonts,viewW,viewH,errorMessage)
  local g=love.graphics
  viewW,viewH=viewW or DESIGN_W,viewH or DESIGN_H
  setColor(COLORS.paper); g.rectangle("fill",0,0,viewW,viewH)
  g.setFont(fonts.title); setColor(COLORS.ink)
  g.print(snapshot and (snapshot.title or "POKEMON STORAGE")
    or "STORAGE INCOMPATIBILITY",18,11)
  setColor(COLORS.accent); g.rectangle("fill",18,37,viewW-36,3)
  if not snapshot then
    drawPanel(18,54,viewW-36,viewH-76)
    g.setFont(fonts.body); setColor(COLORS.disabled)
    g.print("THE STORAGE PROVIDER RETURNED NO VALID SNAPSHOT.",36,78)
    g.setFont(fonts.small); setColor(COLORS.ink)
    local lines=wrapRenderedText(fonts.small,errorMessage or
      "Update Widescreen UI and the storage mod together.",viewW-72)
    for i=1,math.min(8,#lines) do g.print(lines[i],36,112+(i-1)*19) end
    return
  end
  local regions={}
  local drawerW=snapshot.party.open and 110 or 0
  local gridX=12+drawerW+(drawerW>0 and 8 or 0)
  local detailW=198
  local detailX=viewW-detailW-12
  local gridW=detailX-gridX-8
  local topY=51
  if snapshot.party.open then
    drawPanel(12,topY,110,270)
    g.setFont(fonts.tiny); setColor(COLORS.ink); g.print("PARTY",22,topY+9)
    for i,slot in ipairs(snapshot.party.slots) do
      local sy=topY+28+(i-1)*38
      local active=snapshot.selectedRegion=="party"
        and i==snapshot.party.selectedIndex
      PokedexProviderUI.drawStorageTarget(slot,20,sy,94,34,active,fonts)
      if slot.empty~=true then
        PokedexProviderUI.drawStorageIcon(game,slot,24,sy+1)
        g.setFont(fonts.tiny); setColor(slot.enabled==false and COLORS.muted
          or active and COLORS.selectedText or COLORS.ink)
        g.print(fitLabel(fonts.tiny,slot.name,54),58,sy+9)
      end
      PokedexProviderUI.drawStorageTargetOverlay(slot,20,sy,94,34,active)
      PokedexProviderUI.addStorageRegion(regions,20,sy,94,34,
        "selectPartySlot",i)
    end
  end
  drawPanel(gridX,topY,gridW,270)
  g.setFont(fonts.small); setColor(COLORS.ink)
  local boxTitle=string.format("BOX %02d  %d/%d",snapshot.box.viewedIndex,
    snapshot.box.occupancy,snapshot.box.capacity)
  g.print(boxTitle,gridX+12,topY+9)
  local headerRight=gridX+gridW-10
  if snapshot.partyButton then
    local button=snapshot.partyButton
    local bw=58; local bh=22; local bx=headerRight-bw; local by=topY+7
    local active=snapshot.selectedRegion=="partyButton" or button.selected==true
    PokedexProviderUI.drawStorageTarget(button,bx,by,bw,bh,active,fonts)
    g.setFont(fonts.tiny)
    setColor(button.enabled==false and COLORS.muted
      or active and COLORS.selectedText or COLORS.ink)
    local label=fitLabel(fonts.tiny,button.label,bw-12)
    g.print(label,bx+math.floor((bw-fonts.tiny:getWidth(label))/2),by+5)
    PokedexProviderUI.drawStorageTargetOverlay(button,bx,by,bw,bh,active)
    PokedexProviderUI.addStorageRegion(regions,bx,by,bw,bh,
      "selectPartyButton",true)
    headerRight=bx-5
  end
  if snapshot.box.viewedIndex==snapshot.box.activeIndex then
    g.setFont(fonts.tiny)
    local label="ACTIVE"; local bw=fonts.tiny:getWidth(label)+10
    local bx=headerRight-bw
    setColor(COLORS.paper2); g.rectangle("fill",bx,topY+9,bw,18)
    setColor(COLORS.ink); g.rectangle("line",bx,topY+9,bw,18)
    g.print(label,bx+5,topY+13)
  end
  local cellGap=4
  local cellW=math.floor((gridW-24-cellGap*4)/5)
  local cellH=53
  for i,cell in ipairs(snapshot.grid.cells) do
    local col=(i-1)%5; local row=math.floor((i-1)/5)
    local cx=gridX+12+col*(cellW+cellGap)
    local cy=topY+34+row*(cellH+5)
    local active=snapshot.selectedRegion=="grid" and i==snapshot.grid.selectedIndex
    PokedexProviderUI.drawStorageTarget(cell,cx,cy,cellW,cellH,active,fonts)
    if cell.empty~=true then
      PokedexProviderUI.drawStorageIcon(game,cell,cx+math.floor((cellW-32)/2),cy+2)
      g.setFont(fonts.tiny); setColor(cell.enabled==false and COLORS.muted
        or active and COLORS.selectedText or COLORS.ink)
      local label=fitLabel(fonts.tiny,cell.name,cellW-6)
      g.print(label,cx+math.floor((cellW-fonts.tiny:getWidth(label))/2),cy+37)
    end
    PokedexProviderUI.drawStorageTargetOverlay(cell,cx,cy,cellW,cellH,active)
    PokedexProviderUI.addStorageRegion(regions,cx,cy,cellW,cellH,
      "selectCell",i)
  end
  local boxNavW=snapshot.partyButton and math.max(40,gridW-68) or gridW
  PokedexProviderUI.addStorageRegion(regions,gridX,topY,boxNavW/2,30,
    "previousBox",snapshot.box.viewedIndex)
  PokedexProviderUI.addStorageRegion(regions,gridX+boxNavW/2,topY,boxNavW/2,30,
    "nextBox",snapshot.box.viewedIndex)
  PokedexProviderUI.drawStorageDetail(game,snapshot.detail,fonts,
    detailX,topY,detailW,270)
  if snapshot.held then
    local hx=gridX+gridW-42; local hy=topY+6
    g.push("all"); g.setColor(1,1,1,0.72)
    PokedexProviderUI.drawStorageIcon(game,snapshot.held,hx,hy); g.pop()
  end
  if snapshot.popup then
    local popup=snapshot.popup
    local rowH=29; local pw=178; local ph=46+#popup.rows*rowH
    local px=viewW-pw-20; local py=viewH-ph-25
    drawPanel(px,py,pw,ph)
    g.setFont(fonts.small); setColor(COLORS.ink)
    g.print(popup.title or "ACTIONS",px+13,py+11)
    for i,row in ipairs(popup.rows) do
      local ry=py+36+(i-1)*rowH
      local active=i==popup.selectedIndex
      PokedexProviderUI.drawStorageTarget(row,px+10,ry,pw-20,rowH-3,
        active,fonts)
      setColor(row.enabled==false and COLORS.muted
        or active and COLORS.selectedText or COLORS.ink)
      g.print(fitLabel(fonts.small,row.label,pw-38),px+22,ry+5)
      PokedexProviderUI.drawStorageTargetOverlay(row,px+10,ry,pw-20,rowH-3,
        active)
      PokedexProviderUI.addStorageRegion(regions,px+10,ry,pw-20,rowH-3,
        "selectPopup",i)
    end
  end
  if errorMessage then
    setColor(COLORS.disabled); g.setFont(fonts.tiny)
    g.print(fitLabel(fonts.tiny,"PROVIDER ERROR: "..errorMessage,viewW-36),18,328)
  else
    g.setFont(fonts.tiny); setColor(COLORS.muted)
    local disabledReason=PokedexProviderUI.storageDisabledReason(snapshot)
    g.print(fitLabel(fonts.tiny,disabledReason or snapshot.statusText
      or snapshot.footer or "",viewW-210),18,328)
    local hints=snapshot.hints or "A SELECT   B BACK   L/R BOX"
    g.print(hints,viewW-18-fonts.tiny:getWidth(hints),342)
  end
  PokedexProviderUI.storageHitRegions[state]=regions
  if state then
    state.__widescreenStorageHitRegions=regions
  end
end

local function drawInDesignSpace(drawFn)
  local g = love.graphics
  local ww, wh = g.getDimensions()
  if ww <= 0 or wh <= 0 then return end
  local scale = math.min(ww / DESIGN_W, wh / DESIGN_H)
  local ox = math.floor((ww - DESIGN_W * scale) / 2)
  local oy = math.floor((wh - DESIGN_H * scale) / 2)
  g.push("all")
  g.translate(ox, oy)
  g.scale(scale, scale)
  drawFn()
  g.pop()
end

-- Battles use the same uniform pixel scale as the 640x360 presentation, but
-- expose the entire physical window to the HUD. This keeps 16:9 unchanged and
-- anchors chrome to the real top/bottom edges on taller 4:3 displays without
-- changing the world renderer, camera, or battle arena geometry.
local function drawInBattleSpace(drawFn)
  local g = love.graphics
  local ww, wh = g.getDimensions()
  if ww <= 0 or wh <= 0 then return end
  local scale = math.min(ww / DESIGN_W, wh / DESIGN_H)
  if scale <= 0 then return end
  local viewW = math.floor(ww / scale + 0.5)
  local viewH = math.floor(wh / scale + 0.5)
  g.push("all")
  g.scale(scale, scale)
  drawFn(viewW, viewH)
  g.pop()
end

PokedexProviderUI.drawWorldExtensions = function(game, fonts, viewW, viewH)
  drawWorldHudExtensions(game, fonts, viewW, viewH)
end

return function(mod)
  local function modImageLoader(relative)
    return function()
      if not (mod.assets and type(mod.assets.image) == "function") then
        error("mod.assets:image is unavailable")
      end
      return mod.assets:image(relative)
    end
  end
  local function assetLogError(message)
    mod.log:error("Widescreen UI asset: %s", tostring(message))
  end
  partyIconSheetCache.__widescreenShinyStarLoader =
    modImageLoader("assets/shiny_star.png")
  partyIconSheetCache.__widescreenShinyStarLogError = assetLogError
  partyIconSheetCache.__widescreenTrainerBadgeLoader =
    modImageLoader("assets/trainer_badges.png")
  partyIconSheetCache.__widescreenTrainerBadgeLogError = assetLogError
  PokedexProviderUI.oakSpeechAssetLoaders = {
    oak = modImageLoader("assets/intro_oak_frlg.png"),
    player = modImageLoader("assets/intro_red_frlg.png"),
    rival = modImageLoader("assets/intro_rival_frlg.png"),
  }
  PokedexProviderUI.oakSpeechAssetLogError = assetLogError
  PokedexProviderUI.oakSpeechAssets = nil
  PokedexProviderUI.providerErrors = {}
  PokedexProviderUI.warnedForcedBattleHud = false
  battleMoveInspectorLogError = function(message)
    message = tostring(message)
    if PokedexProviderUI.providerErrors[message] then return end
    PokedexProviderUI.providerErrors[message] = true
    mod.log:error("Widescreen UI Move Inspector: %s", message)
  end

  PokedexProviderUI.trainerCardPortraitProvider = nil
  PokedexProviderUI.trainerCardPortraitErrors = {}
  local function trainerCardPortraitError(message)
    message = tostring(message)
    if PokedexProviderUI.trainerCardPortraitErrors[message] then return end
    PokedexProviderUI.trainerCardPortraitErrors[message] = true
    mod.log:error("Widescreen UI Trainer Card portrait: %s", message)
  end
  local function characterAppearanceExports(game)
    local handles = game and game.mods and game.mods.exports
    local handle = handles and handles.gen1_character_sprite_replacer
    if not handle and mod.find then
      local ok, found = pcall(mod.find, mod, "gen1_character_sprite_replacer")
      if ok then handle = found end
    end
    return handle and (handle.exports or handle) or nil
  end
  PokedexProviderUI.resolveTrainerCardPortrait = function(
      kind, game, state, badgeIndex, trainerId, owned)
    local provider = PokedexProviderUI.trainerCardPortraitProvider
    local resolve = provider and (kind == "player" and provider.resolvePlayer
      or provider.resolveLeader)
    if type(resolve) == "function" then
      local ok, result = pcall(resolve, game, state, {
        kind = kind,
        badgeIndex = badgeIndex,
        trainerId = trainerId,
        owned = owned == true,
      })
      if ok and result then return result end
      if not ok then
        trainerCardPortraitError(provider.owner .. ": " .. tostring(result))
      end
    end

    -- Compatibility bridge for the dedicated character-art owner. Player
    -- packs already expose resolvePlayerPresentation("trainer_card"). Future
    -- NPC packs may implement resolveTrainerCardPortrait(subject, context),
    -- or reuse resolveTrainerBattle(trainerId, "front", context).
    local exports = characterAppearanceExports(game)
    if not exports then return nil end
    if kind == "player" and type(exports.resolvePlayerPresentation) == "function" then
      local ok, result = pcall(exports.resolvePlayerPresentation, "trainer_card")
      if ok then return result end
      trainerCardPortraitError("gen1_character_sprite_replacer player: "
        .. tostring(result))
    elseif kind == "leader" then
      local context = {
        purpose = "trainer_card",
        badgeIndex = badgeIndex,
        owned = owned == true,
      }
      if type(exports.resolveTrainerCardPortrait) == "function" then
        local ok, result = pcall(exports.resolveTrainerCardPortrait, {
          kind = "gym_leader",
          trainerId = trainerId,
          badgeIndex = badgeIndex,
        }, context)
        if ok and result then return result end
        if not ok then
          trainerCardPortraitError("gen1_character_sprite_replacer leader: "
            .. tostring(result))
        end
      end
      if type(exports.resolveTrainerBattle) == "function" then
        local ok, result = pcall(exports.resolveTrainerBattle,
          trainerId, "front", context)
        if ok then return result end
        trainerCardPortraitError("gen1_character_sprite_replacer battle leader: "
          .. tostring(result))
      end
    end
    return nil
  end

  mod.exports.trainerCardPortraitApiVersion = 1
  mod.exports.registerTrainerCardPortraitProvider = function(spec)
    if type(spec) ~= "table" then
      return nil, "provider descriptor must be a table"
    end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= 1 then
      return nil, "unsupported Trainer Card portrait API version"
    end
    if type(spec.resolvePlayer) ~= "function"
        and type(spec.resolveLeader) ~= "function" then
      return nil, "provider must resolve player and/or leader portraits"
    end
    if PokedexProviderUI.trainerCardPortraitProvider
        and PokedexProviderUI.trainerCardPortraitProvider.owner ~= spec.owner then
      return nil, "Trainer Card portrait provider already owned by "
        .. PokedexProviderUI.trainerCardPortraitProvider.owner
    end
    local replaced = PokedexProviderUI.trainerCardPortraitProvider ~= nil
    PokedexProviderUI.trainerCardPortraitProvider = {
      owner = spec.owner,
      resolvePlayer = spec.resolvePlayer,
      resolveLeader = spec.resolveLeader,
    }
    PokedexProviderUI.trainerCardImages = {}
    return true, replaced and "replaced" or "registered"
  end
  mod.exports.unregisterTrainerCardPortraitProvider = function(owner)
    if PokedexProviderUI.trainerCardPortraitProvider
        and PokedexProviderUI.trainerCardPortraitProvider.owner == owner then
      PokedexProviderUI.trainerCardPortraitProvider = nil
      PokedexProviderUI.trainerCardImages = {}
      return true, "unregistered"
    end
    return true, "absent"
  end
  mod.exports.activeTrainerCardPortraitProviderOwner = function()
    local provider=PokedexProviderUI.trainerCardPortraitProvider
    return provider and provider.owner or nil
  end

  local battleHudOverlayErrors = {}
  battleHudOverlayLogError = function(message)
    message = tostring(message)
    if battleHudOverlayErrors[message] then return end
    battleHudOverlayErrors[message] = true
    mod.log:error("Widescreen UI Battle HUD overlay: %s", message)
  end
  mod.exports.battleHudOverlayApiVersion = BATTLE_HUD_OVERLAY_API_VERSION
  mod.exports.registerBattleHudOverlay = function(spec)
    if type(spec) ~= "table" then
      return nil, "provider descriptor must be a table"
    end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= BATTLE_HUD_OVERLAY_API_VERSION then
      return nil, "unsupported Battle HUD overlay API version"
    end
    if type(spec.draw) ~= "function" then
      return nil, "provider draw must be a function"
    end
    for i, provider in ipairs(battleHudOverlayProviders) do
      if provider.owner == spec.owner then
        battleHudOverlayProviders[i] = {
          owner = spec.owner, draw = spec.draw, failed = false,
        }
        return true, "replaced"
      end
    end
    battleHudOverlayProviders[#battleHudOverlayProviders + 1] = {
      owner = spec.owner, draw = spec.draw, failed = false,
    }
    return true, "registered"
  end
  mod.exports.unregisterBattleHudOverlay = function(owner)
    for i, provider in ipairs(battleHudOverlayProviders) do
      if provider.owner == owner then
        table.remove(battleHudOverlayProviders, i)
        return true, "unregistered"
      end
    end
    return true, "absent"
  end

  local worldHudOverlayErrors = {}
  worldHudOverlayLogError = function(message)
    message = tostring(message)
    if worldHudOverlayErrors[message] then return end
    worldHudOverlayErrors[message] = true
    mod.log:error("Widescreen UI World HUD overlay: %s", message)
  end
  mod.exports.worldHudOverlayApiVersion = WORLD_HUD_OVERLAY_API_VERSION
  mod.exports.registerWorldHudOverlay = function(spec)
    if type(spec) ~= "table" then
      return nil, "provider descriptor must be a table"
    end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= WORLD_HUD_OVERLAY_API_VERSION then
      return nil, "unsupported World HUD overlay API version"
    end
    if type(spec.draw) ~= "function" then
      return nil, "provider draw must be a function"
    end
    for i, provider in ipairs(worldHudOverlayProviders) do
      if provider.owner == spec.owner then
        worldHudOverlayProviders[i] = {
          owner = spec.owner, draw = spec.draw, failed = false,
        }
        return true, "replaced"
      end
    end
    worldHudOverlayProviders[#worldHudOverlayProviders + 1] = {
      owner = spec.owner, draw = spec.draw, failed = false,
    }
    return true, "registered"
  end
  mod.exports.unregisterWorldHudOverlay = function(owner)
    for i, provider in ipairs(worldHudOverlayProviders) do
      if provider.owner == owner then
        table.remove(worldHudOverlayProviders, i)
        return true, "unregistered"
      end
    end
    return true, "absent"
  end

  mod.exports.battleMoveInspectorApiVersion = BATTLE_MOVE_INSPECTOR_API_VERSION
  mod.exports.registerBattleMoveInspector = function(spec)
    if type(spec) ~= "table" then return nil, "provider descriptor must be a table" end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= BATTLE_MOVE_INSPECTOR_API_VERSION then
      return nil, "unsupported Move Inspector API version"
    end
    if type(spec.snapshot) ~= "function" then
      return nil, "provider snapshot must be a function"
    end
    if battleMoveInspectorProvider
        and battleMoveInspectorProvider.owner ~= spec.owner then
      return nil, "Move Inspector provider already owned by "
        .. battleMoveInspectorProvider.owner
    end
    local replaced = battleMoveInspectorProvider ~= nil
    battleMoveInspectorProvider = {
      owner = spec.owner,
      apiVersion = spec.apiVersion,
      snapshot = spec.snapshot,
    }
    PokedexProviderUI.providerErrors = {}
    return true, replaced and "replaced" or "registered"
  end
  mod.exports.unregisterBattleMoveInspector = function(owner)
    if not battleMoveInspectorProvider then return true, "absent" end
    if owner ~= battleMoveInspectorProvider.owner then
      return nil, "provider is owned by " .. battleMoveInspectorProvider.owner
    end
    battleMoveInspectorProvider = nil
    PokedexProviderUI.providerErrors = {}
    PokedexProviderUI.warnedForcedBattleHud = false
    return true, "unregistered"
  end
  mod.exports.activeBattleMoveInspectorOwner = function()
    return battleMoveInspectorProvider and battleMoveInspectorProvider.owner or nil
  end

  local pokedexProviderErrors = {}
  pokedexProviderLogError = function(message)
    message = tostring(message)
    if pokedexProviderErrors[message] then return end
    pokedexProviderErrors[message] = true
    mod.log:error("Widescreen UI Pokedex provider: %s", message)
  end
  mod.exports.pokedexProviderApiVersion = POKEDEX_PROVIDER_API_VERSION
  mod.exports.registerPokedexProvider = function(spec)
    if type(spec) ~= "table" then return nil, "provider descriptor must be a table" end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= POKEDEX_PROVIDER_API_VERSION
        and spec.apiVersion ~= PokedexProviderUI.compatVersion then
      return nil, "unsupported Pokedex provider API version"
    end
    if type(spec.match) ~= "function" or type(spec.snapshot) ~= "function" then
      return nil, "provider match and snapshot must be functions"
    end
    if type(spec.actions) ~= "table" then
      return nil, "provider actions must be a table"
    end
    if pokedexProvider and pokedexProvider.owner ~= spec.owner then
      return nil, "Pokedex provider already owned by " .. pokedexProvider.owner
    end
    local replaced = pokedexProvider ~= nil
    pokedexProvider = {
      owner = spec.owner,
      apiVersion = spec.apiVersion,
      match = spec.match,
      snapshot = spec.snapshot,
      actions = spec.actions,
    }
    pokedexProviderErrors = {}
    PokedexProviderUI.lastValid = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.hitRegions = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.views = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.providerFaults = setmetatable({}, { __mode = "k" })
    return true, replaced and "replaced" or "registered"
  end
  mod.exports.unregisterPokedexProvider = function(owner)
    if not pokedexProvider then return true, "absent" end
    if owner ~= pokedexProvider.owner then
      return nil, "provider is owned by " .. pokedexProvider.owner
    end
    pokedexProvider = nil
    pokedexProviderErrors = {}
    PokedexProviderUI.lastValid = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.hitRegions = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.views = setmetatable({}, { __mode = "k" })
    PokedexProviderUI.providerFaults = setmetatable({}, { __mode = "k" })
    return true, "unregistered"
  end
  mod.exports.activePokedexProviderOwner = function()
    return pokedexProvider and pokedexProvider.owner or nil
  end

  PokedexProviderUI.bagProviderErrors = {}
  PokedexProviderUI.bagProviderFaults = setmetatable({}, { __mode="k" })
  bagProviderLogError = function(message)
    message = tostring(message)
    if PokedexProviderUI.bagProviderErrors[message] then return end
    PokedexProviderUI.bagProviderErrors[message] = true
    mod.log:error("Widescreen UI Bag provider: %s", message)
  end
  mod.exports.bagProviderApiVersion = BAG_PROVIDER_API_VERSION
  mod.exports.bagProviderCompatibleApiVersions = { [1]=true, [2]=true }
  mod.exports.registerBagProvider = function(spec)
    if type(spec) ~= "table" then return nil, "provider descriptor must be a table" end
    if type(spec.owner) ~= "string" or spec.owner == "" then
      return nil, "provider owner must be a non-empty string"
    end
    if spec.apiVersion ~= 1 and spec.apiVersion ~= BAG_PROVIDER_API_VERSION then
      return nil, "unsupported Bag provider API version"
    end
    if type(spec.match) ~= "function" or type(spec.snapshot) ~= "function" then
      return nil, "provider match and snapshot must be functions"
    end
    if type(spec.actions) ~= "table" then
      return nil, "provider actions must be a table"
    end
    if bagProvider and bagProvider.owner ~= spec.owner then
      return nil, "Bag provider already owned by " .. bagProvider.owner
    end
    local replaced = bagProvider ~= nil
    bagProvider = { owner=spec.owner, apiVersion=spec.apiVersion,
      match=spec.match, snapshot=spec.snapshot, actions=spec.actions }
    PokedexProviderUI.bagProviderErrors = {}
    PokedexProviderUI.bagLastValid = setmetatable({}, { __mode="k" })
    PokedexProviderUI.bagHitRegions = setmetatable({}, { __mode="k" })
    PokedexProviderUI.bagProviderFaults = setmetatable({}, { __mode="k" })
    return true, replaced and "replaced" or "registered"
  end
  mod.exports.unregisterBagProvider = function(owner)
    if not bagProvider then return true, "absent" end
    if owner ~= bagProvider.owner then
      return nil, "provider is owned by " .. bagProvider.owner
    end
    bagProvider = nil
    PokedexProviderUI.bagProviderErrors = {}
    PokedexProviderUI.bagLastValid = setmetatable({}, { __mode="k" })
    PokedexProviderUI.bagHitRegions = setmetatable({}, { __mode="k" })
    PokedexProviderUI.bagProviderFaults = setmetatable({}, { __mode="k" })
    return true, "unregistered"
  end
  mod.exports.activeBagProviderOwner = function()
    return bagProvider and bagProvider.owner or nil
  end
  PokedexProviderUI.storageProviderErrors={}
  PokedexProviderUI.storageProviderLogError=function(message)
    message=tostring(message)
    if PokedexProviderUI.storageProviderErrors[message] then return end
    PokedexProviderUI.storageProviderErrors[message]=true
    mod.log:error("Widescreen UI Pokemon Storage provider: %s",message)
  end
  mod.exports.pokemonStorageProviderApiVersion=PokedexProviderUI.storageApiVersion
  mod.exports.registerPokemonStorageProvider=function(spec)
    if type(spec)~="table" then return nil,"provider descriptor must be a table" end
    if type(spec.owner)~="string" or spec.owner=="" then
      return nil,"provider owner must be a non-empty string"
    end
    if spec.apiVersion~=PokedexProviderUI.storageApiVersion then
      return nil,"unsupported Pokemon Storage provider API version"
    end
    if type(spec.match)~="function" or type(spec.snapshot)~="function" then
      return nil,"provider match and snapshot must be functions"
    end
    if type(spec.actions)~="table" then return nil,"provider actions must be a table" end
    local required={"up","down","left","right","previousBox","nextBox",
      "select","back","selectCell","selectPartySlot","selectPopup"}
    for _,action in ipairs(required) do
      if type(spec.actions[action])~="function" then
        return nil,"provider action "..action.." must be a function"
      end
    end
    local current=PokedexProviderUI.storageProvider
    if current and current.owner~=spec.owner then
      return nil,"Pokemon Storage provider already owned by "..current.owner
    end
    local replaced=current~=nil
    PokedexProviderUI.storageProvider={owner=spec.owner,
      apiVersion=spec.apiVersion,match=spec.match,snapshot=spec.snapshot,
      actions=spec.actions}
    PokedexProviderUI.storageProviderErrors={}
    PokedexProviderUI.resetStorageProviderCaches()
    return true,replaced and "replaced" or "registered"
  end
  mod.exports.unregisterPokemonStorageProvider=function(owner)
    local provider=PokedexProviderUI.storageProvider
    if not provider then return true,"absent" end
    if owner~=provider.owner then return nil,"provider is owned by "..provider.owner end
    PokedexProviderUI.storageProvider=nil
    PokedexProviderUI.storageProviderErrors={}
    PokedexProviderUI.resetStorageProviderCaches()
    return true,"unregistered"
  end
  mod.exports.activePokemonStorageProviderOwner=function()
    local provider=PokedexProviderUI.storageProvider
    return provider and provider.owner or nil
  end
  mod.exports.invokePokemonStorageProviderAction=function(actionId,game,state,...)
    local provider=PokedexProviderUI.storageProvider
    if not provider then return nil,"no active Pokemon Storage provider" end
    local action=provider.actions[actionId]
    -- v1 completion: old providers can keep using their focus-aware `select`,
    -- while newer providers may expose an explicit pointer/touch action.
    if actionId=="selectPartyButton" and type(action)~="function" then
      action=provider.actions.select
    end
    if type(action)~="function" then
      return nil,"unsupported Pokemon Storage action "..tostring(actionId)
    end
    local ok,value,reason=pcall(action,game,state,...)
    if not ok then
      local message="action "..tostring(actionId).." exception: "..tostring(value)
      PokedexProviderUI.storageProviderLogError(message)
      if type(state)=="table" then PokedexProviderUI.storageProviderFaults[state]=message end
      return nil,value
    end
    return value,reason
  end
  mod.exports.updatePokemonStorageProviderInput=function(game,state,dt)
    if not PokedexProviderUI.storageOwnsState(state) then
      return nil,"state is not owned by the active Pokemon Storage provider"
    end
    if topState(game)~=state then return false,"state is not focused" end
    local provider=PokedexProviderUI.storageProvider
    if provider and type(provider.actions.update)=="function" then
      local value,reason=mod.exports.invokePokemonStorageProviderAction(
        "update",game,state,dt)
      if value~=nil and value~=false then return value,reason end
    end
    local input=game and game.input
    if not (input and type(input.wasPressed)=="function") then
      return false,"input unavailable"
    end
    local action
    if input:wasPressed("b") then action="back"
    elseif input:wasPressed("a") then action="select"
    elseif input:wasPressed("up") then action="up"
    elseif input:wasPressed("down") then action="down"
    elseif input:wasPressed("left") then action="left"
    elseif input:wasPressed("right") then action="right"
    elseif input:wasPressed("l") then action="previousBox"
    elseif input:wasPressed("r") then action="nextBox" end
    if not action then return false end
    return mod.exports.invokePokemonStorageProviderAction(action,game,state,dt)
  end
  PokedexProviderUI.storageInputRouter=mod.exports.updatePokemonStorageProviderInput
  mod.exports.routePokemonStorageProviderKey=function(game,state,key)
    if not PokedexProviderUI.storageOwnsState(state) or topState(game)~=state then
      return false
    end
    local map={up="up",down="down",left="left",right="right",
      ["return"]="select",space="select",escape="back",backspace="back",
      pageup="previousBox",pagedown="nextBox",q="previousBox",e="nextBox"}
    local action=map[tostring(key or ""):lower()]
    if not action then return false end
    mod.exports.invokePokemonStorageProviderAction(action,game,state)
    return true
  end
  mod.exports.routePokemonStorageProviderPointer=function(game,state,event)
    return PokedexProviderUI.routeStoragePointer(game,state,event,
      mod.exports.invokePokemonStorageProviderAction)
  end
  PokedexProviderUI.bagOwnsState = function(state)
    if not (bagProvider and type(state)=="table") then return false end
    local ok, matched = pcall(bagProvider.match, state)
    if not ok then
      bagProviderLogError("match exception: " .. tostring(matched))
      -- A crashing mandatory provider must never uncover the native Bag.
      PokedexProviderUI.bagProviderFaults[state] =
        "match exception: " .. tostring(matched)
      return state.kind == "bag" or state.__widescreenBagOwned == true
    end
    return matched and true or false
  end
  mod.exports.invokeBagProviderAction = function(actionId, game, state, ...)
    if not bagProvider then return nil, "no active Bag provider" end
    local action = bagProvider.actions[actionId]
    if type(action) ~= "function" then
      return nil, "unsupported Bag action " .. tostring(actionId)
    end
    local ok, value, reason = pcall(action, game, state, ...)
    if not ok then
      local message="action " .. tostring(actionId)
        .. " exception: " .. tostring(value)
      bagProviderLogError(message)
      if type(state)=="table" then
        PokedexProviderUI.bagProviderFaults[state]=message
      end
      return nil, value
    end
    return value, reason
  end
  PokedexProviderUI.bagInputSnapshot = function(state)
    local snapshot=PokedexProviderUI.bagLastValid[state]
    if type(snapshot)~="table" or not bagProvider
        or snapshot.schemaVersion~=bagProvider.apiVersion then return nil end
    return snapshot
  end
  mod.exports.routeBagProviderText = function(game,state,value)
    if not PokedexProviderUI.bagOwnsState(state)
        or topState(game)~=state then return false end
    local snapshot=PokedexProviderUI.bagInputSnapshot(state)
    if not snapshot or snapshot.schemaVersion~=2
        or snapshot.screen~="search" then return false end
    if type(value)~="string" or value=="" then return false end
    return mod.exports.invokeBagProviderAction("textInput",game,state,value)
  end
  mod.exports.routeBagProviderKey = function(game,state,key)
    if not PokedexProviderUI.bagOwnsState(state)
        or topState(game)~=state then return false end
    local snapshot=PokedexProviderUI.bagInputSnapshot(state)
    if not snapshot or snapshot.schemaVersion~=2
        or snapshot.screen~="search" then return false end
    key=tostring(key or ""):lower()
    if key~="backspace" and key~="delete" then return false end
    local keyboard=love and love.keyboard
    local control=keyboard and type(keyboard.isDown)=="function"
      and (keyboard.isDown("lctrl") or keyboard.isDown("rctrl"))
    return mod.exports.invokeBagProviderAction(
      control and "clear" or "delete",game,state)
  end
  mod.exports.updateBagProviderInput = function(game, state, dt)
    if not PokedexProviderUI.bagOwnsState(state) then
      return nil, "state is not owned by the active Bag provider"
    end
    if topState(game) ~= state then return false, "state is not focused" end
    local input = game and game.input
    if not (input and type(input.wasPressed)=="function") then
      return false, "input unavailable"
    end
    local snapshot=PokedexProviderUI.bagInputSnapshot(state)
    local action,value
    if input:wasPressed("b") then action="back"
    elseif input:wasPressed("a") then
      if snapshot and snapshot.schemaVersion==2
          and snapshot.screen=="search" then
        local key=PokedexProviderUI.bagSelectedKeyboardKey(snapshot.search)
        if key then action="keyboardKey"; value=key.id else action="select" end
      else action="select" end
    elseif input:wasPressed("up") then action="up"
    elseif input:wasPressed("down") then action="down"
    elseif input:wasPressed("left") then
      action=snapshot and snapshot.screen~="bag" and "left" or "pocketLeft"
    elseif input:wasPressed("right") then
      action=snapshot and snapshot.screen~="bag" and "right" or "pocketRight"
    elseif input:wasPressed("start") then action="search"
    elseif input:wasPressed("select") then action="options"
    elseif input:wasPressed("y") or input:wasPressed("i") then action="info" end
    if not action then return false end
    if value~=nil then
      return mod.exports.invokeBagProviderAction(action,game,state,value)
    end
    return mod.exports.invokeBagProviderAction(action,game,state,dt)
  end
  local function pokedexProviderOwnsState(state)
    if not (pokedexProvider and type(state) == "table") then return false end
    local ok, matched = pcall(pokedexProvider.match, state)
    if not ok then
      pokedexProviderLogError("match exception: " .. tostring(matched))
      return false
    end
    return matched and true or false
  end
  mod.exports.invokePokedexProviderAction = function(actionId, game, state, ...)
    if not pokedexProvider then return nil, "no active Pokedex provider" end
    local action = pokedexProvider.actions[actionId]
    if type(action) ~= "function" then
      return nil, "unsupported Pokedex action " .. tostring(actionId)
    end
    local ok, value, reason = pcall(action, game, state, ...)
    if not ok then
      pokedexProviderLogError("action " .. tostring(actionId)
        .. " exception: " .. tostring(value))
      return nil, value
    end
    return value, reason
  end
  mod.exports.updatePokedexProviderInput = function(game, state, dt)
    if not pokedexProviderOwnsState(state) then
      return nil, "state is not owned by the active Pokedex provider"
    end
    if topState(game) ~= state then return false, "state is not focused" end
    local input = game and game.input
    if not (input and type(input.wasPressed) == "function") then
      return false, "input unavailable"
    end
    local views = PokedexProviderUI.views[state]
    local entryView = views and views.entryViewport
    if entryView and entryView.focused and entryView.available then
      -- Entry focus is presenter-owned transient state. It never asks the
      -- semantic provider to understand coordinates, wrapping or raw input.
      if input:wasPressed("b") or input:wasPressed("start")
          or input:wasPressed("a") or input:wasPressed("select") then
        return PokedexProviderUI.applyEntryAction(state, "entryBlur")
      elseif input:wasPressed("up") then
        return PokedexProviderUI.applyEntryAction(state, "entryScroll", -1)
      elseif input:wasPressed("down") then
        return PokedexProviderUI.applyEntryAction(state, "entryScroll", 1)
      elseif input:wasPressed("left") then
        return PokedexProviderUI.applyEntryAction(state, "entryScroll", -5)
      elseif input:wasPressed("right") then
        return PokedexProviderUI.applyEntryAction(state, "entryScroll", 5)
      end
      return false
    end
    if input:wasPressed("select") and entryView
        and entryView.shinyAvailable
        and pokedexProvider and type(pokedexProvider.actions.toggleShiny) == "function" then
      return mod.exports.invokePokedexProviderAction(
        "toggleShiny", game, state, dt)
    end
    -- When shiny Select and a long entry coexist, START is the explicit
    -- controller-only entry-focus gesture. B remains the ordinary Back path.
    if input:wasPressed("start") and entryView
        and entryView.shinyAvailable and entryView.available then
      return PokedexProviderUI.applyEntryAction(state, "entryFocus", true)
    end
    if input:wasPressed("select") and entryView and entryView.available then
      return PokedexProviderUI.applyEntryAction(state, "entryFocus", true)
    end
    -- One semantic action per fixed update. B has first refusal so closing a
    -- submenu/page can never also move a newly exposed list in the same frame.
    local action
    if input:wasPressed("b") or input:wasPressed("start") then
      action = "back"
    elseif input:wasPressed("a") then
      action = "select"
    elseif input:wasPressed("up") then
      action = "up"
    elseif input:wasPressed("down") then
      action = "down"
    elseif input:wasPressed("left") then
      action = "pageUp"
    elseif input:wasPressed("right") then
      action = "pageDown"
    end
    if not action then return false end
    return mod.exports.invokePokedexProviderAction(action, game, state, dt)
  end
  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("screen.render_visible",function(next,state)
      if PokedexProviderUI.storageOwnsState(state) then return false end
      return next(state)
    end,12000)
    mod.hooks:wrap("input.pointer", function(next, game, event)
      local state = topState(game)
      if mod.exports.routePokemonStorageProviderPointer(game,state,event) then
        return true
      end
      if PokedexProviderUI.bagOwnsState(state) and type(event)=="table"
          and event.phase=="pressed"
          and not (event.source=="mouse" and event.button~=nil
            and event.button~=1) then
        local regions=PokedexProviderUI.bagHitRegions[state]
        local g=love and love.graphics
        local ww,wh=g and g.getDimensions and g.getDimensions()
        if type(regions)=="table" and ww and wh and ww>0 and wh>0 then
          local scale=math.min(ww/DESIGN_W,wh/DESIGN_H)
          local ox=math.floor((ww-DESIGN_W*scale)/2)
          local oy=math.floor((wh-DESIGN_H*scale)/2)
          local px=((tonumber(event.x) or -1)-ox)/scale
          local py=((tonumber(event.y) or -1)-oy)/scale
          for i=#regions,1,-1 do
            local region=regions[i]
            if px>=region.x and px<=region.x+region.w
                and py>=region.y and py<=region.y+region.h then
              mod.exports.invokeBagProviderAction(region.action,game,state,
                region.value)
              return true
            end
          end
        end
      end
      if not pokedexProviderOwnsState(state) or type(event) ~= "table"
          or event.phase ~= "pressed"
          or (event.source == "mouse" and event.button ~= nil
              and event.button ~= 1) then
        return next(game, event)
      end
      local regions = PokedexProviderUI.hitRegions[state]
      if type(regions) ~= "table" then return next(game, event) end
      local g = love and love.graphics
      local ww, wh
      if g and g.getDimensions then ww, wh = g.getDimensions() end
      if not ww or not wh or ww <= 0 or wh <= 0 then
        return next(game, event)
      end
      local scale = math.min(ww / DESIGN_W, wh / DESIGN_H)
      local ox = math.floor((ww - DESIGN_W * scale) / 2)
      local oy = math.floor((wh - DESIGN_H * scale) / 2)
      local px = ((tonumber(event.x) or -1) - ox) / scale
      local py = ((tonumber(event.y) or -1) - oy) / scale
      -- Reverse order gives the submenu, which is drawn last, first refusal
      -- over the detail panel beneath it.
      for i = #regions, 1, -1 do
        local region = regions[i]
        if px >= region.x and px <= region.x + region.w
            and py >= region.y and py <= region.y + region.h then
          if region.action == "entryFocus" or region.action == "entryScroll"
              or region.action == "entryBlur" then
            PokedexProviderUI.applyEntryAction(state, region.action, region.value)
          elseif region.value ~= nil then
            mod.exports.invokePokedexProviderAction(region.action,
              game, state, region.value)
          else
            mod.exports.invokePokedexProviderAction(region.action, game, state)
          end
          return true
        end
      end
      return next(game, event)
    end, 12000)
  end

  ShinyArtResolver = function(mon, identityOnly)
    local shinyMod = mod.find and mod:find("gen1_shiny_system")
    local exports = shinyMod and shinyMod.exports
    local use = exports and (identityOnly and exports.isShiny
      or exports.shouldUseShinyArt)
    if identityOnly and type(use) ~= "function" then
      use = exports and exports.shouldUseShinyArt
    end
    if type(use) ~= "function" then return nil end
    local ok, value = pcall(use, mon)
    return ok and (value and true or false) or nil
  end
  ShinyBattleImage = function(game, mon, side)
    local shinyMod = mod.find and mod:find("gen1_shiny_system")
    local resolve = shinyMod and shinyMod.exports
      and shinyMod.exports.battleImage
    if type(resolve) ~= "function" then return nil end
    return resolve(game, mon, side)
  end
  BattleArtProviderImage = function(game, mon, side, purpose)
    local handles = game and game.mods and game.mods.exports
    local handle = handles and handles.gen1_battle_art_replacer
    if not handle and mod.find then
      local ok, found = pcall(mod.find, mod, "gen1_battle_art_replacer")
      if ok then handle = found end
    end
    local exports = handle and (handle.exports or handle)
    local resolve = exports and exports.resolvePokemonImage
    if type(resolve) ~= "function" then return nil end
    return resolve(game, mon, side, purpose)
  end
  BattleArtProviderPresentation = function(game, mon, side, context)
    local handles = game and game.mods and game.mods.exports
    local handle = handles and handles.gen1_battle_art_replacer
    if not handle and mod.find then
      local ok, found = pcall(mod.find, mod, "gen1_battle_art_replacer")
      if ok then handle = found end
    end
    local exports = handle and (handle.exports or handle)
    if not (exports and tonumber(exports.presentationApiVersion) == 1
        and type(exports.resolvePokemonPresentation) == "function") then
      return nil, false
    end
    return exports.resolvePokemonPresentation(game, mon, side, context), true
  end

  mod.options:define({
    {
      key = "start_menu",
      type = "toggle",
      label = "WIDESCREEN START MENU",
      default = true,
    },
    {
      key = "title_menu",
      type = "toggle",
      label = "WIDESCREEN MAIN MENU",
      default = true,
    },
    {
      key = "new_game_intro",
      type = "toggle",
      label = "WIDESCREEN NEW GAME INTRO",
      default = true,
    },
    {
      key = "load_report",
      type = "toggle",
      label = "WIDESCREEN LOAD REPORT",
      default = true,
    },
    {
      key = "options_menu",
      type = "toggle",
      label = "WIDESCREEN OPTIONS MENU",
      default = true,
    },
    {
      key = "party_screen",
      type = "toggle",
      label = "WIDESCREEN POKEMON SCREEN",
      default = true,
    },
    {
      key = "bag_screen",
      type = "toggle",
      label = "WIDESCREEN BAG",
      default = true,
    },
    {
      key = "pc_ui",
      type = "toggle",
      label = "WIDESCREEN PC",
      default = true,
    },
    {
      key = "summary_screen",
      type = "toggle",
      label = "WIDESCREEN STAT SCREEN",
      default = true,
    },
    {
      key = "evolution_screen",
      type = "toggle",
      label = "WIDESCREEN EVOLUTION",
      default = true,
    },
    {
      key = "trainer_card",
      type = "toggle",
      label = "WIDESCREEN TRAINER CARD",
      default = true,
    },
    {
      key = "pokedex_screen",
      type = "toggle",
      label = "WIDESCREEN POKEDEX",
      default = true,
    },
    {
      key = "battle_hud",
      type = "toggle",
      label = "WIDESCREEN BATTLE HUD",
      default = true,
    },
    {
      key = "dialogue_boxes",
      type = "toggle",
      label = "WIDESCREEN DIALOGUE BOXES",
      default = true,
    },
  })

  local function optionEnabled(key)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if key == "battle_hud" and battleMoveInspectorProvider then
      if ok and value == false and not PokedexProviderUI.warnedForcedBattleHud then
        PokedexProviderUI.warnedForcedBattleHud = true
        mod.log:warn("Widescreen UI: WIDESCREEN BATTLE HUD is required by Move Inspector provider %s; the disabled setting is ignored while it is active",
          battleMoveInspectorProvider.owner)
      end
      return true
    end
    if key == "pokedex_screen" and pokedexProvider then return true end
    if key == "bag_screen" and bagProvider then return true end
    if key == "pc_ui" and PokedexProviderUI.storageProvider then return true end
    return not ok or value ~= false
  end

  local fonts = {
    title = loadFont(16),
    body = loadFont(16),
    small = loadFont(12),
    tiny = loadFont(10),
  }
  if not fonts.title or not fonts.body or not fonts.small or not fonts.tiny then
    mod.log:warn("Widescreen UI: could not create screen-space fonts")
  end

  local okSpriteDeps, spriteDepsErr = pcall(function()
    PokemonSprites = require("src.pokemon.Sprites")
    Assets = require("src.render.Assets")
    PaletteFX = require("src.render.PaletteFX")
    Stats = require("src.pokemon.Stats")
    EngineFont = require("src.render.Font")
    TextBoxClass = require("src.render.TextBox")
    ChoiceBoxClass = require("src.ui.ChoiceBox")
    local function optionalRequire(name)
      local loaded, value = pcall(require, name)
      return loaded and value or nil
    end
    ListMenuClass = optionalRequire("src.ui.ListMenu")
    MenuClass = optionalRequire("src.ui.Menu")
    PokedexMenuClass = optionalRequire("src.ui.PokedexMenu")
    DexEntryMenuClass = optionalRequire("src.ui.DexEntryMenu")
    TitleStateClass = optionalRequire("src.ui.TitleState")
    QuarantineReportClass = optionalRequire("src.ui.QuarantineReport")
    OptionsMenuClass = optionalRequire("src.ui.OptionsMenu")
    ManagerStateClass = optionalRequire("src.mods.ManagerState")
    PokedexProviderUI.gameClass = optionalRequire("src.core.Game")
    PokedexProviderUI.quantityBoxClass = optionalRequire("src.ui.QuantityBox")
    PokedexProviderUI.bagMenuModule = optionalRequire("src.ui.BagMenu")
    PokedexProviderUI.playerPcModule = optionalRequire("src.ui.PlayerPC")
    PokedexProviderUI.boxMenuModule = optionalRequire("src.ui.BoxMenu")
    PokedexProviderUI.evolutionStateClass = optionalRequire("src.ui.EvolutionState")
    PokedexProviderUI.summaryMenuClass = optionalRequire("src.ui.SummaryMenu")
    PokedexProviderUI.trainerCardClass = optionalRequire("src.ui.TrainerCard")
    PokedexProviderUI.oakSpeechClass = optionalRequire("src.ui.OakSpeech")
    PokedexProviderUI.namingScreenClass = optionalRequire("src.ui.NamingScreen")
    PokedexProviderUI.badgesModule = optionalRequire("src.inventory.Badges")
    BattleState = require("src.battle.BattleState")
    PokedexProviderUI.statBoxClass = BattleState and BattleState.StatBox
    PokedexProviderUI.experienceModule = optionalRequire("src.battle.Experience")
    if Assets.register then
      Assets.register(function()
        partyBattleSpriteCache = {}
        partyIconSheetCache = {
          __widescreenShinyStarLoader = modImageLoader("assets/shiny_star.png"),
          __widescreenShinyStarLogError = assetLogError,
          __widescreenTrainerBadgeLoader = modImageLoader("assets/trainer_badges.png"),
          __widescreenTrainerBadgeLogError = assetLogError,
        }
        PokedexProviderUI.oakSpeechAssets = nil
        battleArtPreview = setmetatable({}, { __mode = "k" })
      end)
    end
  end)
  if not okSpriteDeps then
    mod.log:warn("Widescreen UI: battle portrait resolver unavailable: %s",
                 tostring(spriteDepsErr))
  end

  local okDialoguePatch, dialoguePatchErr = pcall(function()
    if not (TextBoxClass and type(TextBoxClass.new) == "function"
        and type(TextBoxClass.paginate) == "function"
        and type(TextBoxClass.substitute) == "function"
        and type(TextBoxClass.beginLine) == "function")
        or TextBoxClass.__widescreenUiWidePaginationWrapped then return end
    local originalNew = TextBoxClass.new
    TextBoxClass.new = function(game, text, onDone, opts)
      local state = originalNew(game, text, onDone, opts)
      local states = game and game.stack and game.stack.states
      local underneath = type(states) == "table" and states[#states] or nil
      local isOverworldDialogue = underneath ~= nil
        and (underneath == game.overworld or underneath.isOverworld == true)
      local isOakDialogue = underneath ~= nil
        and PokedexProviderUI.oakSpeechClass
        and getmetatable(underneath) == PokedexProviderUI.oakSpeechClass
      if not ((isOverworldDialogue and optionEnabled("dialogue_boxes")
          or isOakDialogue and optionEnabled("new_game_intro"))
          and type(state) == "table" and type(text) == "string") then
        return state
      end
      local substituted = TextBoxClass.substitute(game, text)
      local wideCols = isOakDialogue and PokedexProviderUI.OAK_DIALOGUE_COLS
        or PokedexProviderUI.WIDE_DIALOGUE_COLS
      local reflowed = isOakDialogue
        and PokedexProviderUI.reflowOakDialogue(
          TextBoxClass, substituted, wideCols)
        or PokedexProviderUI.reflowWideDialogue(
          TextBoxClass, substituted, wideCols)
      state.maxCols = wideCols
      state.pages = TextBoxClass.paginate(reflowed, wideCols)
      state.pageIndex, state.lineIndex, state.charIndex = 1, 1, 0
      state.shown, state.waiting, state.contAdvance = {}, false, false
      state.done, state.blink = false, 0
      state.codes, state.charTimer = nil, nil
      state.holdFrames, state.scrollPx = nil, nil
      state:beginLine()
      state.__widescreenUiReflowed = true
      state.__widescreenUiOakDialogue = isOakDialogue or nil
      return state
    end
    TextBoxClass.__widescreenUiWidePaginationWrapped = true
  end)
  if not okDialoguePatch then
    mod.log:error("Widescreen UI: dialogue pagination patch failed: %s",
                  tostring(dialoguePatchErr))
  end

  -- The engine's WIDE battle compositor and Dramatic Shape's snapped HUD are
  -- both presentations of the same battle state.  While this option is on,
  -- keep the simulation/input untouched but route drawing through the classic
  -- battlefield layer with its native HUD/text passes suppressed.  The final
  -- 640x360 presenter below then becomes the single owner of battle chrome.
  local activeBattle
  local statBoxClass = PokedexProviderUI.statBoxClass
  local experienceModule = PokedexProviderUI.experienceModule
  if experienceModule and type(experienceModule.apply) == "function"
      and not experienceModule.__widescreenLevelGainWrapped then
    local originalExperienceApply = experienceModule.apply
    experienceModule.apply = function(data, mon, ...)
      local before = {}
      for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
        before[key] = tonumber(mon and mon.stats and mon.stats[key]) or 0
      end
      local levels, gained, extra = originalExperienceApply(data, mon, ...)
      if type(levels) == "table" and #levels > 0 and mon then
        local queue, previous = {}, before
        local def = data and data.pokemon and data.pokemon[mon.species]
        for _, reachedLevel in ipairs(levels) do
          local calculated
          if Stats and type(Stats.calc) == "function" and def then
            local ok, value = pcall(Stats.calc, def, reachedLevel,
              mon.dvs, mon.statExp)
            if ok and type(value) == "table" then calculated = value end
          end
          calculated = calculated or mon.stats or {}
          local gains = {}
          for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
            gains[key] = math.max(0,
              (tonumber(calculated[key]) or 0) - (tonumber(previous[key]) or 0))
          end
          queue[#queue + 1] = {
            level = tonumber(reachedLevel) or tonumber(mon.level),
            stats = calculated,
            gains = gains,
          }
          previous = calculated
        end
        PokedexProviderUI.levelUpGains[mon] = queue
      end
      return levels, gained, extra
    end
    experienceModule.__widescreenLevelGainWrapped = true
  end
  if statBoxClass and type(statBoxClass.new) == "function"
      and not statBoxClass.__widescreenUiNewWrapped then
    local originalStatBoxNew = statBoxClass.new
    statBoxClass.new = function(game, mon, ...)
      local state = originalStatBoxNew(game, mon, ...)
      local queue = mon and PokedexProviderUI.levelUpGains[mon]
      if type(queue) == "table" and #queue > 0 then
        state.__widescreenLevelUp = table.remove(queue, 1)
        if #queue == 0 then PokedexProviderUI.levelUpGains[mon] = nil end
      elseif mon then
        local current = mon.stats or {}
        local previous = {}
        local def = game and game.data and game.data.pokemon
          and game.data.pokemon[mon.species]
        if Stats and type(Stats.calc) == "function" and def
            and (tonumber(mon.level) or 1) > 1 then
          local ok, value = pcall(Stats.calc, def, mon.level - 1,
            mon.dvs, mon.statExp)
          if ok and type(value) == "table" then previous = value end
        end
        local gains = {}
        for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
          gains[key] = math.max(0,
            (tonumber(current[key]) or 0) - (tonumber(previous[key]) or 0))
        end
        state.__widescreenLevelUp = {
          level = tonumber(mon.level) or 1,
          stats = current,
          gains = gains,
        }
      end
      return state
    end
    statBoxClass.__widescreenUiNewWrapped = true
  end
  local okBattlePatch, battlePatchErr = pcall(function()
    if not BattleState or BattleState.__widescreenUiBattleWrapped then return end
    local originalWideLayout = BattleState.wideLayout
    local originalDrawHUDs = BattleState.drawHUDs
    local originalDrawTextArea = BattleState.drawTextArea
    local originalUpdate = BattleState.update
    PokedexProviderUI.installExpSequence(BattleState, experienceModule)

    BattleState.wideLayout = function(self, ...)
      if optionEnabled("battle_hud") then return false end
      return originalWideLayout(self, ...)
    end
    BattleState.drawHUDs = function(self, ...)
      if optionEnabled("battle_hud") then return end
      return originalDrawHUDs(self, ...)
    end
    BattleState.drawTextArea = function(self, ...)
      if optionEnabled("battle_hud") then return end
      return originalDrawTextArea(self, ...)
    end
    if type(originalUpdate) == "function" then
      BattleState.update = function(self, dt, ...)
        -- Rendering uses the classic battlefield layer so its native chrome
        -- can be suppressed cleanly. Preserve the 2x2 navigation promised by
        -- the visible move grid explicitly while A/B/SELECT remain native.
        if optionEnabled("battle_hud") and self and self.game
            and self.game.input and type(self.game.input.wasPressed) == "function"
            and (self.phase == "moveSelect" or self.phase == "mimicSelect") then
          local moves = self.phase == "moveSelect"
            and self.player and self.player.curMoves or self.mimicMoves
          local key = self.phase == "moveSelect" and "moveIndex" or "mimicIndex"
          local index = tonumber(self[key]) or 1
          local count = #(moves or {})
          local input = self.game.input
          local direction
          for _, candidate in ipairs({ "left", "right", "up", "down" }) do
            if input:wasPressed(candidate) then
              direction = candidate
              break
            end
          end
          if direction == "left" or direction == "right" then
            local row = math.floor((index - 1) / 2)
            local col = (index - 1) % 2
            local other = row * 2 + (1 - col) + 1
            if other <= count then self[key] = other end
          elseif direction == "up" or direction == "down" then
            local row = math.floor((index - 1) / 2)
            local col = (index - 1) % 2
            local other = (1 - row) * 2 + col + 1
            if other <= count then self[key] = other end
          end
          if direction then
            -- wideLayout is false only for drawing suppression. Prevent the
            -- classic +/-1 navigation from applying after the grid step.
            local originalWasPressed = input.wasPressed
            input.wasPressed = function(obj, pressedKey)
              if pressedKey == "left" or pressedKey == "right"
                  or pressedKey == "up" or pressedKey == "down" then
                return false
              end
              return originalWasPressed(obj, pressedKey)
            end
            local ok, a, b, c = pcall(originalUpdate, self, dt, ...)
            input.wasPressed = originalWasPressed
            if not ok then error(a, 0) end
            return a, b, c
          end
        end
        return originalUpdate(self, dt, ...)
      end
    end
    BattleState.__widescreenUiBattleWrapped = true
  end)
  if not okBattlePatch then
    mod.log:error("Widescreen UI: battle-state patch failed: %s",
                  tostring(battlePatchErr))
  end

  local battleProviderAdapters = {}
  local function patchBattleProvider(game, providerId)
    if battleProviderAdapters[providerId] then return true end
    local exports = game and game.mods and game.mods.exports
    local handle = exports and exports[providerId]
    if not handle and mod.find then
      local ok, found = pcall(mod.find, mod, providerId)
      if ok then handle = found end
    end
    local lib = handle and (handle.lib
      or (handle.exports and handle.exports.lib))
    if not (lib and type(lib.require) == "function") then return false end
    local okOB, OB = pcall(lib.require, "OverworldBattle")
    local okBH, BH = pcall(lib.require, "BattleHud")
    if not (okOB and OB and okBH and BH) then return false end

    local originalSnapHUDs = OB.snapHUDs
    local originalDrawHudPanels = OB.drawHudPanels
    local originalTextures = OB.textures
    local originalPanel = BH.panel
    OB.snapHUDs = function(battle, shot, ...)
      if optionEnabled("battle_hud") then
        return battle ~= nil and shot ~= nil and shot.canvas ~= nil
          and (tonumber(shot.scale) or 0) > 0
      end
      return originalSnapHUDs(battle, shot, ...)
    end
    OB.drawHudPanels = function(battle, ...)
      if optionEnabled("battle_hud") then return end
      return originalDrawHudPanels(battle, ...)
    end
    if type(originalTextures) == "function" then
      OB.textures = function(battle, ...)
        local textures = originalTextures(battle, ...)
        if optionEnabled("battle_hud") and battle
            and type(textures) == "table" then
          if battle.showEnemyTrainer and type(textures.enemy) == "table"
              and not textures.enemy.__widescreenCharacterAnchorAdjusted then
            local provider = characterAppearanceExports(game)
            local trainerId = battle.trainer and battle.trainer.id
            local resolve = provider and provider.resolveTrainerBattle
            if trainerId and type(resolve) == "function" then
              local ok, desc = pcall(resolve, trainerId, "front", {
                purpose = "dramatic_shape_anchor",
              })
              local anchorY = ok and type(desc) == "table"
                and tonumber(desc.anchorY) or nil
              if anchorY then
                textures.enemy.ay = math.max(
                  tonumber(textures.enemy.ay) or 0, anchorY)
                textures.enemy.__widescreenCharacterAnchorAdjusted = true
              end
            end
          end
          if battle.showPlayerBack then
          -- The same trainer is rendered in the final HUD pass, grounded on
          -- the Widescreen bottom panel. Remove only its 3D arena billboard;
          -- the player's Pokemon returns to the arena after send-out.
            textures.player = nil
          end
        end
        return textures
      end
    end
    BH.panel = function(rect, box, world, ...)
      if optionEnabled("battle_hud") then return true end
      return originalPanel(rect, box, world, ...)
    end
    battleProviderAdapters[providerId] = {
      overworldBattle = OB, battleHud = BH,
      originalTextures = originalTextures,
    }
    return true
  end

  local function patchDramaticShapeBattle(game)
    local dramatic = patchBattleProvider(game, "DRAMATIC_SHAPE")
    local battleArt = patchBattleProvider(game, "BATTLE_ART_VOXEL_FORK")
    return dramatic or battleArt
  end

  -- Install before the first render pass when the loader exposes the mod
  -- handle. Dramatic Shape builds its snapped HUD during world composition,
  -- which occurs before render.hud; waiting until that hook is one frame too
  -- late and can also miss the captured native draw closure entirely.
  patchDramaticShapeBattle(nil)

  -- The voxel providers capture the engine HUD into a private texture before
  -- render.hud. Patch them at battle creation as well, covering load orders in
  -- which their exported library was not yet available during this mod's init.
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("battle.started", function(payload)
      local battle = payload and payload.battle
      patchDramaticShapeBattle(battle and battle.game)
    end)
  end

  mod.hooks:wrap("battle.overlay", function(next, battle)
    patchDramaticShapeBattle(battle and battle.game)
    local result = next(battle)
    activeBattle = battle
    return result
  end, 11000)

  local activeStart
  local okPatch, patchErr = pcall(function()
    local StartMenu = require("src.ui.StartMenu")
    if StartMenu.__widescreenUiWrapped then return end
    local originalNew = StartMenu.new
    StartMenu.new = function(game, ...)
      local menu = originalNew(game, ...)
      menu.__widescreenUiStart = true
      menu.__widescreenUiOriginalDraw = menu.draw
      -- An instance method is intentional: it wins over other mods that wrap
      -- generic Menu.draw, so two final-pass START presenters cannot both arm
      -- themselves merely because of load order.
      menu.draw = function(self, ...)
        if not optionEnabled("start_menu") and self.__widescreenUiOriginalDraw then
          return self.__widescreenUiOriginalDraw(self, ...)
        end
      end
      activeStart = menu
      return menu
    end
    StartMenu.__widescreenUiWrapped = true
  end)

  if not okPatch then
    mod.log:error("Widescreen UI: START menu patch failed: %s",
                  tostring(patchErr))
  end

  local activeParty
  local PartyMenu
  local okPartyPatch, partyPatchErr = pcall(function()
    PartyMenu = require("src.ui.PartyMenu")
    if PartyMenu.__widescreenUiWrapped then return end
    local originalNew = PartyMenu.new
    PartyMenu.new = function(game, opts)
      local bag=topState(game)
      local selected=bag and bag.items and bag.items[bag.index or 1]
      local rareCandyPicker=type(opts)=="table" and opts.pickOnly and selected
        and selected.value=="RARE_CANDY" and not opts.keepOpen
      local menu = originalNew(game, opts)
      -- The engine correctly pops this picker before the candy sequence.
      -- Retain only its presentation model while the resulting TextBox and
      -- StatBox are active; never retain the state or alter Bag callbacks.
      menu.__widescreenRareCandyPicker=rareCandyPicker and true or nil
      menu.__widescreenUiParty = true
      menu.__widescreenUiOriginalDraw = menu.draw
      menu.draw = function(self, ...)
        if not optionEnabled("party_screen")
            and self.__widescreenUiOriginalDraw then
          return self.__widescreenUiOriginalDraw(self, ...)
        end
        activeParty = self
      end
      activeParty = menu
      return menu
    end
    PartyMenu.__widescreenUiWrapped = true
  end)

  if not okPartyPatch then
    mod.log:error("Widescreen UI: Pokemon screen patch failed: %s",
                  tostring(partyPatchErr))
  end

  local activeSummary
  local SummaryMenu
  local okSummaryPatch, summaryPatchErr = pcall(function()
    SummaryMenu = require("src.ui.SummaryMenu")
    if SummaryMenu.__widescreenUiWrapped then return end
    local originalNew = SummaryMenu.new
    SummaryMenu.new = function(game, mon, ...)
      local summary = originalNew(game, mon, ...)
      summary.__widescreenUiSummary = true
      summary.__widescreenUiOriginalDraw = summary.draw
      summary.draw = function(self, ...)
        if not optionEnabled("summary_screen")
            and self.__widescreenUiOriginalDraw then
          return self.__widescreenUiOriginalDraw(self, ...)
        end
        activeSummary = self
      end
      activeSummary = summary
      return summary
    end
    SummaryMenu.__widescreenUiWrapped = true
  end)

  if not okSummaryPatch then
    mod.log:error("Widescreen UI: stat screen patch failed: %s",
                  tostring(summaryPatchErr))
  end

  -- TitleState keeps animating beneath the menu, but its original 160x144
  -- Menu box must never be drawn once the final-resolution presenter owns the
  -- title flow. The callbacks/update path remain on the original Menu object.
  if MenuClass and type(MenuClass.draw) == "function"
      and not MenuClass.__widescreenUiTitleDrawWrapped then
    local originalMenuDraw = MenuClass.draw
    MenuClass.draw = function(self, ...)
      if optionEnabled("title_menu") and self and self.titleUiBox then return end
      return originalMenuDraw(self, ...)
    end
    MenuClass.__widescreenUiTitleDrawWrapped = true
  end
  PokedexProviderUI.suppressBagClassDraw = function(class, marker)
    if not (class and type(class.draw)=="function") or class[marker] then return end
    local original=class.draw
    class.draw=function(self,...)
      local nativeBag=PokedexProviderUI.nativeBagRange(self and self.game)
      if optionEnabled("bag_screen") and (nativeBag
          or bagProvider and PokedexProviderUI.bagOwnsState(self)) then return end
      return original(self,...)
    end
    class[marker]=true
  end
  PokedexProviderUI.routeBagClassUpdate = function(class, marker)
    if not (class and type(class.update)=="function") or class[marker] then return end
    local original=class.update
    class.update=function(self,dt,...)
      if bagProvider and PokedexProviderUI.bagOwnsState(self) then
        return mod.exports.updateBagProviderInput(self.game,self,dt)
      end
      return original(self,dt,...)
    end
    class[marker]=true
  end
  PokedexProviderUI.suppressBagClassDraw(ListMenuClass,"__widescreenUiBagDrawWrapped")
  PokedexProviderUI.suppressBagClassDraw(MenuClass,"__widescreenUiBagDrawWrapped")
  PokedexProviderUI.suppressBagClassDraw(PokedexProviderUI.quantityBoxClass,
    "__widescreenUiBagDrawWrapped")
  -- ChoiceBox is shared globally; suppress only while a native Bag owns the
  -- underlying stack. Its input/callback path remains unchanged.
  PokedexProviderUI.suppressBagClassDraw(ChoiceBoxClass,
    "__widescreenUiBagDrawWrapped")
  PokedexProviderUI.routeBagClassUpdate(ListMenuClass,
    "__widescreenUiBagUpdateWrapped")
  PokedexProviderUI.routeBagClassUpdate(MenuClass,
    "__widescreenUiBagUpdateWrapped")
  PokedexProviderUI.routeBagClassUpdate(PokedexProviderUI.quantityBoxClass,
    "__widescreenUiBagUpdateWrapped")
  -- Provider-owned states route semantics through callbacks; the vanilla Bag
  -- deliberately keeps ListMenu/Menu/QuantityBox/ChoiceBox native updates.
  if PokedexProviderUI.gameClass
      and type(PokedexProviderUI.gameClass.keypressed)=="function"
      and not PokedexProviderUI.gameClass.__widescreenUiBagKeyWrapped then
    local originalGameKeypressed=PokedexProviderUI.gameClass.keypressed
    PokedexProviderUI.gameClass.keypressed=function(self,key,...)
      local state=topState(self)
      if PokedexProviderUI.storageProvider
          and mod.exports.routePokemonStorageProviderKey(self,state,key) then return end
      if bagProvider and PokedexProviderUI.bagOwnsState(state)
          and mod.exports.routeBagProviderKey(self,state,key) then return end
      return originalGameKeypressed(self,key,...)
    end
    PokedexProviderUI.gameClass.__widescreenUiBagKeyWrapped=true
  end
  if love and type(love.textinput)=="function"
      and not PokedexProviderUI.bagTextInputWrapped then
    local originalTextInput=love.textinput
    love.textinput=function(value,...)
      local game=PokedexProviderUI.bagFocusedGame
      local state=PokedexProviderUI.bagFocusedState
      if bagProvider and PokedexProviderUI.bagOwnsState(state)
          and mod.exports.routeBagProviderText(game,state,value) then return end
      return originalTextInput(value,...)
    end
    PokedexProviderUI.bagTextInputWrapped=true
  end

  PokedexProviderUI.markPcConstructor = function(module, marker)
    if not (module and type(module.new)=="function") or module[marker] then return end
    local original=module.new
    module.new=function(game,...)
      local state=original(game,...)
      if type(state)=="table" then state.__widescreenUiPcRoot=true end
      return state
    end
    module[marker]=true
  end
  PokedexProviderUI.markPcConstructor(PokedexProviderUI.playerPcModule,
    "__widescreenUiPcWrapped")
  PokedexProviderUI.markPcConstructor(PokedexProviderUI.boxMenuModule,
    "__widescreenUiPcWrapped")
  PokedexProviderUI.suppressPcClassDraw = function(class,marker)
    if not (class and type(class.draw)=="function") or class[marker] then return end
    local original=class.draw
    class.draw=function(self,...)
      if optionEnabled("pc_ui") and PokedexProviderUI.pcSessionActive(self and self.game) then
        return
      end
      return original(self,...)
    end
    class[marker]=true
  end
  PokedexProviderUI.suppressPcClassDraw(ListMenuClass,"__widescreenUiPcDrawWrapped")
  PokedexProviderUI.suppressPcClassDraw(MenuClass,"__widescreenUiPcDrawWrapped")
  PokedexProviderUI.suppressPcClassDraw(PokedexProviderUI.quantityBoxClass,
    "__widescreenUiPcDrawWrapped")
  PokedexProviderUI.suppressPcClassDraw(ChoiceBoxClass,"__widescreenUiPcDrawWrapped")
  PokedexProviderUI.suppressStorageClassDraw=function(class,marker)
    if not (class and type(class.draw)=="function") or class[marker] then return end
    local original=class.draw
    class.draw=function(self,...)
      if PokedexProviderUI.storageOwnsState(self) then return end
      return original(self,...)
    end
    class[marker]=true
  end
  PokedexProviderUI.routeStorageClassUpdate=function(class,marker)
    if not (class and type(class.update)=="function") or class[marker] then return end
    local original=class.update
    class.update=function(self,dt,...)
      if PokedexProviderUI.storageOwnsState(self) then
        return mod.exports.updatePokemonStorageProviderInput(self.game,self,dt)
      end
      return original(self,dt,...)
    end
    class[marker]=true
  end
  PokedexProviderUI.suppressStorageClassDraw(ListMenuClass,
    "__widescreenUiStorageDrawWrapped")
  PokedexProviderUI.suppressStorageClassDraw(MenuClass,
    "__widescreenUiStorageDrawWrapped")
  PokedexProviderUI.routeStorageClassUpdate(ListMenuClass,
    "__widescreenUiStorageUpdateWrapped")
  PokedexProviderUI.routeStorageClassUpdate(MenuClass,
    "__widescreenUiStorageUpdateWrapped")

  local okPokedexPatch, pokedexPatchErr = pcall(function()
    if not PokedexMenuClass or PokedexMenuClass.__widescreenUiWrapped then return end
    local originalNew = PokedexMenuClass.new
    PokedexMenuClass.new = function(game, opts, ...)
      local list = originalNew(game, opts, ...)
      list.__widescreenUiPokedexRoot = true
      return list
    end
    PokedexMenuClass.__widescreenUiWrapped = true
  end)
  if not okPokedexPatch then
    mod.log:error("Widescreen UI: Pokedex presentation patch failed: %s",
                  tostring(pokedexPatchErr))
  end

  local function isNativePokedexList(state)
    if type(state) ~= "table" or getmetatable(state) ~= ListMenuClass then
      return false
    end
    local title = tostring(state.title or "")
      :gsub("é", "E"):gsub("É", "E"):upper():gsub("[^A-Z]", "")
    return title == "POKEDEX"
  end

  local function pokedexRootRange(game)
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" then return nil end
    for i, state in ipairs(states) do
      if state.__widescreenUiPokedexRoot or isNativePokedexList(state) then
        return i, #states
      end
    end
  end

  PokedexProviderUI.bagPresentation = function(game)
    PokedexProviderUI.bagFocusedGame=nil
    PokedexProviderUI.bagFocusedState=nil
    if not optionEnabled("bag_screen") then return nil end
    if not bagProvider then
      local bag,first,last=PokedexProviderUI.nativeBagRange(game)
      if not bag then return nil end
      return bag,PokedexProviderUI.nativeBagSnapshot(game,bag,topState(game)),
        nil,first,last,true
    end
    local state=topState(game)
    if not PokedexProviderUI.bagOwnsState(state) then return nil end
    PokedexProviderUI.bagFocusedGame=game
    PokedexProviderUI.bagFocusedState=state
    local fault=PokedexProviderUI.bagProviderFaults[state]
    if fault then return state,nil,fault end
    local ok,snapshot=pcall(bagProvider.snapshot,game,state)
    if not ok then
      local message="snapshot exception: "..tostring(snapshot)
      bagProviderLogError(message)
      return state,nil,message
    end
    local valid,reason=PokedexProviderUI.validateBagSnapshot(snapshot)
    if not valid then
      local message="invalid snapshot: "..tostring(reason)
      bagProviderLogError(message)
      return state,nil,message
    end
    PokedexProviderUI.bagLastValid[state]=valid
    PokedexProviderUI.bagProviderFaults[state]=nil
    return state,valid,nil,nil,nil,false
  end

  local function validatePokedexSnapshot(snapshot)
    if type(snapshot) ~= "table" then return nil, "snapshot must be a table" end
    local function finite(value)
      return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
    end
    local function integer(value)
      return finite(value) and value % 1 == 0
    end
    local function nonempty(value)
      return type(value) == "string" and value ~= ""
    end
    local function rowsCommon(rows, label)
      if type(rows) ~= "table" then return nil, label .. " rows must be a table" end
      for i, row in ipairs(rows) do
        if type(row) ~= "table" then
          return nil, label .. " row " .. tostring(i) .. " must be a table"
        end
      end
      return true
    end
    if snapshot.schemaVersion == PokedexProviderUI.compatVersion then
      if type(snapshot.screen) ~= "string" then
        return nil, "v1 snapshot screen must be a string"
      end
      local ok, reason = rowsCommon(snapshot.rows, "v1")
      if not ok then return nil, reason end
      if not finite(snapshot.selectedIndex) then
        return nil, "v1 snapshot selectedIndex must be numeric"
      end
      for i, row in ipairs(snapshot.rows) do
        if type(row.label) ~= "string" and type(row.name) ~= "string" then
          return nil, "v1 snapshot row " .. tostring(i)
            .. " must have a label or species name"
        end
      end
      return snapshot
    end
    if snapshot.schemaVersion ~= POKEDEX_PROVIDER_API_VERSION then
      return nil, "unsupported snapshot schemaVersion"
    end
    local screens = {
      pokedex = true, pokedex_habitat = true, pokedex_stats = true,
      pokedex_learnset = true, pokedex_evolution = true,
    }
    if not screens[snapshot.screen] then
      return nil, "unsupported v2 screen " .. tostring(snapshot.screen)
    end
    local okRows, rowsReason = rowsCommon(snapshot.rows, snapshot.screen)
    if not okRows then return nil, rowsReason end
    if not integer(snapshot.selectedIndex) then
      return nil, "v2 selectedIndex must be an integer"
    end
    if snapshot.scroll ~= nil and (not integer(snapshot.scroll) or snapshot.scroll < 0) then
      return nil, "v2 scroll must be a non-negative integer"
    end
    if snapshot.screen == "pokedex" then
      for i, row in ipairs(snapshot.rows) do
        if not nonempty(row.speciesId) or not nonempty(row.number)
            or type(row.seen) ~= "boolean" or type(row.owned) ~= "boolean"
            or type(row.hidden) ~= "boolean" then
          return nil, "pokedex row " .. tostring(i)
            .. " must define speciesId, number and privacy flags"
        end
        if row.owned and not row.seen then
          return nil, "pokedex row " .. tostring(i) .. " cannot be owned but unseen"
        end
        if row.seen and not nonempty(row.name) then
          return nil, "seen pokedex row " .. tostring(i) .. " requires a name"
        end
      end
      if type(snapshot.counts) ~= "table"
          or not integer(snapshot.counts.seen)
          or not integer(snapshot.counts.owned)
          or not integer(snapshot.counts.total) then
        return nil, "pokedex counts must contain integer seen/owned/total"
      end
      local detail = snapshot.detail
      if type(detail) ~= "table" or type(detail.portrait) ~= "table" then
        return nil, "pokedex detail and portrait are required"
      end
      if type(detail.seen) ~= "boolean" or type(detail.owned) ~= "boolean"
          or type(detail.hidden) ~= "boolean" or (detail.owned and not detail.seen) then
        return nil, "pokedex detail requires consistent privacy flags"
      end
      if detail.hidden or detail.seen == false then
        if detail.portrait.kind ~= "unknown" then
          return nil, "unseen detail must use an unknown portrait"
        end
      else
        if not nonempty(detail.speciesId) or not nonempty(detail.number)
            or not nonempty(detail.name) or detail.portrait.kind ~= "pokemon"
            or detail.portrait.speciesId ~= detail.speciesId
            or detail.portrait.side ~= "front"
            or detail.portrait.purpose ~= "pokedex"
            or type(detail.portrait.shiny) ~= "boolean"
            or (detail.portrait.shinyAvailable ~= nil
                and type(detail.portrait.shinyAvailable) ~= "boolean") then
          return nil, "seen detail requires matching Pokemon portrait data"
        end
        local shinyAvailable = detail.portrait.shinyAvailable == true
        if detail.portrait.shiny and not shinyAvailable then
          return nil, "shiny portrait requires shinyAvailable"
        end
        if shinyAvailable and detail.owned ~= true then
          return nil, "shiny availability requires a currently owned detail"
        end
        if shinyAvailable and not (pokedexProvider and pokedexProvider.actions
            and type(pokedexProvider.actions.toggleShiny) == "function") then
          return nil, "shiny availability requires toggleShiny action"
        end
      end
      if snapshot.submenu ~= nil then
        local submenu = snapshot.submenu
        local expected = { "habitat", "stats", "learnset", "evolution", "cry" }
        if type(submenu) ~= "table" or not integer(submenu.selectedIndex)
            or type(submenu.rows) ~= "table" or #submenu.rows ~= #expected then
          return nil, "submenu must contain selectedIndex and five ordered rows"
        end
        for i, id in ipairs(expected) do
          local row = submenu.rows[i]
          if type(row) ~= "table" or row.id ~= id or not nonempty(row.label) then
            return nil, "submenu row " .. tostring(i) .. " must be " .. id
          end
        end
      end
      return snapshot
    end

    if not nonempty(snapshot.speciesId) or not nonempty(snapshot.number)
        or not nonempty(snapshot.name) then
      return nil, snapshot.screen .. " requires speciesId, number and name"
    end
    if snapshot.gated then
      if not nonempty(snapshot.message) then
        return nil, snapshot.screen .. " gated state requires a message"
      end
      return snapshot
    end
    if #snapshot.rows == 0 then
      return nil, snapshot.screen .. " requires an explicit typed or message row"
    end
    if snapshot.screen == "pokedex_habitat" then
      for i, row in ipairs(snapshot.rows) do
        if row.kind == "habitat" then
          if not nonempty(row.mapId) or not nonempty(row.mapName)
              or not nonempty(row.method) or not integer(row.minLevel)
              or not integer(row.maxLevel) or row.minLevel > row.maxLevel
              or (row.slotChance ~= nil and not finite(row.slotChance))
              or (row.stepChance ~= nil and not finite(row.stepChance))
              or (row.conditions ~= nil and type(row.conditions) ~= "table") then
            return nil, "invalid habitat row " .. tostring(i)
          end
        elseif row.kind ~= "message" or not nonempty(row.label or row.message) then
          return nil, "habitat row " .. tostring(i) .. " has an unsupported kind"
        end
      end
    elseif snapshot.screen == "pokedex_stats" then
      if snapshot.types ~= nil and type(snapshot.types) ~= "table" then
        return nil, "stats types must be a table"
      end
      for i, row in ipairs(snapshot.rows) do
        if row.kind ~= "stat" and row.kind ~= "total" and row.kind ~= "message" then
          return nil, "stats row " .. tostring(i) .. " has an unsupported kind"
        end
        if not nonempty(row.label or row.id) then
          return nil, "stats row " .. tostring(i) .. " requires a label"
        end
        -- Malformed or absent stat values are valid semantic input: the
        -- presenter renders an em dash and never silently coerces them to 0.
      end
    elseif snapshot.screen == "pokedex_learnset" then
      for i, row in ipairs(snapshot.rows) do
        if row.kind == "move" then
          if not nonempty(row.moveId) or not nonempty(row.moveName)
              or not nonempty(row.typeId or row.typeName)
              or (row.power ~= nil and not finite(row.power))
              or (row.accuracy ~= nil and not finite(row.accuracy))
              or (row.pp ~= nil and not finite(row.pp)) then
            return nil, "invalid learnset move row " .. tostring(i)
          end
        elseif row.kind == "section" or row.kind == "message" then
          if not nonempty(row.label or row.message) then
            return nil, "learnset row " .. tostring(i) .. " requires a label"
          end
        else
          return nil, "learnset row " .. tostring(i) .. " has an unsupported kind"
        end
      end
    elseif snapshot.screen == "pokedex_evolution" then
      for i, row in ipairs(snapshot.rows) do
        if row.kind == "evolution" then
          if not nonempty(row.method) then
            return nil, "evolution row " .. tostring(i) .. " requires method text"
          end
          if not row.targetHidden and not nonempty(row.targetName or row.targetSpeciesId) then
            return nil, "visible evolution row " .. tostring(i) .. " requires a target"
          end
        elseif row.kind ~= "message" or not nonempty(row.label or row.message) then
          return nil, "evolution row " .. tostring(i) .. " has an unsupported kind"
        end
      end
    end
    return snapshot
  end

  local function invalidProviderPokedexSnapshot(reason)
    return {
      schemaVersion = POKEDEX_PROVIDER_API_VERSION,
      screen = "pokedex", title = "POKEDEX",
      rows = {}, selectedIndex = 1, scroll = 0,
      counts = { seen = 0, owned = 0, total = 0 },
      detail = {
        number = "---", seen = false, owned = false, hidden = true,
        portrait = { kind = "unknown" },
      },
      providerError = tostring(reason or "PROVIDER DATA UNAVAILABLE"),
    }
  end

  local function providerPokedexPresentation(game)
    local provider = pokedexProvider
    local states = game and game.stack and game.stack.states
    if not provider or type(states) ~= "table" then return nil end
    for i = #states, 1, -1 do
      local state = states[i]
      if pokedexProviderOwnsState(state) then
        local okSnapshot, value, reason = pcall(provider.snapshot, game, state)
        if not okSnapshot then
          pokedexProviderLogError("snapshot exception: " .. tostring(value))
          value, reason = nil, value
        end
        if value == nil then
          pokedexProviderLogError("provider returned no snapshot: " .. tostring(reason))
          PokedexProviderUI.providerFaults[state] = true
          local fallback = PokedexProviderUI.lastValid[state]
            or invalidProviderPokedexSnapshot(reason)
          return state, i, #states, fallback
        end
        local snapshot, invalid = validatePokedexSnapshot(value)
        if not snapshot or snapshot.schemaVersion ~= provider.apiVersion then
          invalid = invalid or ("snapshot schemaVersion does not match registered API "
            .. tostring(provider.apiVersion))
          pokedexProviderLogError("invalid snapshot: " .. tostring(invalid))
          PokedexProviderUI.providerFaults[state] = true
          local fallback = PokedexProviderUI.lastValid[state]
            or invalidProviderPokedexSnapshot(invalid)
          return state, i, #states, fallback
        end
        PokedexProviderUI.providerFaults[state] = nil
        PokedexProviderUI.lastValid[state] = snapshot
        return state, i, #states, snapshot
      end
    end
  end

  local function pokedexPresentation(game)
    if not optionEnabled("pokedex_screen") then return nil end
    local providerState, providerFirst, providerLast, snapshot =
      providerPokedexPresentation(game)
    if providerState then
      if snapshot.schemaVersion == POKEDEX_PROVIDER_API_VERSION then
        return "provider_v2", providerState, providerFirst, providerLast,
          snapshot
      end
      local rows = {}
      for _, row in ipairs(snapshot.rows) do
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        if not copy.label then
          local number = copy.number and (tostring(copy.number) .. " ") or ""
          copy.label = number .. (copy.hidden and "?????" or copy.name)
        end
        if copy.owned then copy.marker = true end
        rows[#rows + 1] = copy
      end
      local footer = snapshot.footer
      if not footer and type(snapshot.counts) == "table" then
        footer = ("SEEN %03d     OWN %03d     A OPEN     B BACK"):format(
          tonumber(snapshot.counts.seen) or 0,
          tonumber(snapshot.counts.owned) or 0)
      end
      local model = {
        title = snapshot.title or "POKEDEX",
        rows = rows,
        index = snapshot.selectedIndex,
        scroll = snapshot.scroll or 0,
        footer = footer,
      }
      return "list", providerState, providerFirst, providerLast, model
    end
    -- A newly caught species is presented by BattleState as a standalone
    -- DexEntryMenu. It never constructs PokedexMenu, so requiring the normal
    -- root marker here exposed the native 160x144 entry. Own any direct entry
    -- (plus its native dialogue overlays) before looking for a list root.
    local states = game and game.stack and game.stack.states
    if type(states) == "table" then
      local directIndex = #states
      while directIndex > 0 do
        local directType = getmetatable(states[directIndex])
        if directType == TextBoxClass or directType == ChoiceBoxClass then
          directIndex = directIndex - 1
        else
          break
        end
      end
      if directIndex > 0 and getmetatable(states[directIndex]) == DexEntryMenuClass then
        return "entry", states[directIndex], directIndex, #states
      end
    end
    local first, last = pokedexRootRange(game)
    if not first then return nil end
    states = game.stack.states
    local baseIndex = last
    while baseIndex > first do
      local mt = getmetatable(states[baseIndex])
      if mt == TextBoxClass or mt == ChoiceBoxClass then
        baseIndex = baseIndex - 1
      else
        break
      end
    end
    local state = states[baseIndex]
    local mt = getmetatable(state)
    if mt == DexEntryMenuClass then
      return "entry", state, baseIndex, last
    end
    if mt == ListMenuClass or mt == MenuClass then
      return "list", state, baseIndex, last, nil
    end
    return nil
  end

  local function titlePresentation(game)
    if not optionEnabled("title_menu") then return nil end
    if not (TitleStateClass and MenuClass) then return nil end
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" or #states < 1 then return nil end
    local title
    for _, state in ipairs(states) do
      if getmetatable(state) == TitleStateClass then title = state break end
    end
    if not title then return nil end
    local top = states[#states]
    if top == title then return "title", title, nil end
    if getmetatable(top) == MenuClass and top.titleUiBox then
      return "menu", title, top
    end
    if top.title == title and type(top.save) == "table" then
      return "continue", title, top
    end
  end

  local function loadReportPresentation(game)
    if not optionEnabled("load_report") then return nil end
    if not QuarantineReportClass then return nil end
    local state = topState(game)
    if state and getmetatable(state) == QuarantineReportClass then return state end
  end

  local function optionsPresentation(game)
    if not optionEnabled("options_menu") or not OptionsMenuClass then return nil end
    local state = topState(game)
    if state and getmetatable(state) == OptionsMenuClass then return state end
  end

  local function managerPresentation(game)
    if not optionEnabled("options_menu") or not ManagerStateClass then return nil end
    local state = topState(game)
    if state and getmetatable(state) == ManagerStateClass then return state end
  end

  -- Return the contiguous native dialogue/choice layer at the top of the
  -- stack. This is deliberately presentation-only: TextBox and ChoiceBox
  -- continue to own typing, text speed, page/control markers, input and every
  -- callback. A non-dialogue modal on top ends Widescreen ownership so an
  -- unknown third-party screen can retain its own native presentation.
  local function dialoguePresentation(game)
    if not optionEnabled("dialogue_boxes") then return nil end
    local states = game and game.stack and game.stack.states
    if type(states) ~= "table" or #states < 1 then return nil end
    local last = #states
    local first = last
    while first >= 1 do
      local mt = getmetatable(states[first])
      if mt ~= TextBoxClass and mt ~= ChoiceBoxClass then break end
      first = first - 1
    end
    if first == last then return nil end
    return first, last
  end

  local function levelUpPresentation(game)
    if not statBoxClass then return nil end
    local state = topState(game)
    if not (state and getmetatable(state)==statBoxClass) then return nil end
    if optionEnabled("battle_hud") and activeBattle
        and stateInStack(game,activeBattle) then return state,"battle" end
    if optionEnabled("party_screen") and activeParty
        and (stateInStack(game,activeParty)
          or activeParty.__widescreenRareCandyPicker) then return state,"party" end
    return nil
  end

  local function convertedDialogueRange(game, background)
    local first, last = presentationRange(game, background)
    if not first then return nil end
    local states = game.stack.states
    for i = first + 1, last do
      local mt = getmetatable(states[i])
      if mt ~= TextBoxClass and mt ~= ChoiceBoxClass then return nil end
    end
    return first, last
  end

  local function dialogueBackedState(game, class, predicate)
    if not class then return nil end
    local first, last = dialoguePresentation(game)
    if not first or first < 1 then return nil end
    local state = game.stack.states[first]
    if class and getmetatable(state) ~= class then return nil end
    if predicate and not predicate(state) then return nil end
    return state, first, last
  end

  local function evolutionPresentation(game)
    if not optionEnabled("evolution_screen") then return nil end
    local class = PokedexProviderUI.evolutionStateClass
    local states = game and game.stack and game.stack.states
    if not (class and type(states) == "table") then return nil end
    for i = #states, 1, -1 do
      if getmetatable(states[i]) == class then
        for above = i + 1, #states do
          local mt = getmetatable(states[above])
          if mt ~= TextBoxClass and mt ~= ChoiceBoxClass then return nil end
        end
        return states[i], i, #states
      end
    end
  end

  local function trainerCardPresentation(game)
    if not optionEnabled("trainer_card") then return nil end
    local class = PokedexProviderUI.trainerCardClass
    local states = game and game.stack and game.stack.states
    if not (class and type(states) == "table") then return nil end
    for i = #states, 1, -1 do
      if getmetatable(states[i]) == class then
        for above = i + 1, #states do
          local mt = getmetatable(states[above])
          if mt ~= TextBoxClass and mt ~= ChoiceBoxClass then return nil end
        end
        return states[i], i, #states
      end
    end
  end

  PokedexProviderUI.oakSpeechPresentation = function(game)
    if not optionEnabled("new_game_intro") then return nil end
    local speechClass = PokedexProviderUI.oakSpeechClass
    local namingClass = PokedexProviderUI.namingScreenClass
    local states = game and game.stack and game.stack.states
    if not (speechClass and type(states) == "table") then return nil end
    local speech, speechIndex
    for i = #states, 1, -1 do
      if getmetatable(states[i]) == speechClass then
        speech, speechIndex = states[i], i
        break
      end
    end
    if not speech then return nil end
    for i = speechIndex + 1, #states do
      if namingClass and getmetatable(states[i]) == namingClass then
        local menu = states[i + 1]
        if menu and getmetatable(menu) ~= MenuClass then return nil end
        if i + (menu and 1 or 0) ~= #states then return nil end
        return "naming", speech, states[i], menu, speechIndex, #states
      end
    end
    for i = speechIndex + 1, #states do
      local mt = getmetatable(states[i])
      if mt ~= TextBoxClass and mt ~= ChoiceBoxClass then return nil end
    end
    return "speech", speech, nil, nil, speechIndex, #states
  end

  -- Native TextBox and ChoiceBox render in the engine's 160x144 viewport.
  -- When one sits over a widescreen background, drawing it before our final
  -- presenter leaves a second box docked below the custom UI. Suppress only
  -- that native pass; drawPresentationOverlays recreates the active overlay
  -- afterward in 640x360 design space. Other game screens remain untouched.
  local function customBackgroundOwnsStack(game)
    if optionEnabled("start_menu") and activeStart
        and convertedDialogueRange(game, activeStart) then
      return true
    end
    if optionEnabled("summary_screen") and activeSummary
        and presentationRange(game, activeSummary) then
      return true
    end
    if optionEnabled("party_screen") and activeParty
        and presentationRange(game, activeParty) then
      return true
    end
    if optionEnabled("battle_hud") and activeBattle
        and convertedDialogueRange(game, activeBattle) then
      return true
    end
    if pokedexPresentation(game) then return true end
    if evolutionPresentation(game) then return true end
    if trainerCardPresentation(game) then return true end
    if PokedexProviderUI.oakSpeechPresentation
        and PokedexProviderUI.oakSpeechPresentation(game) then return true end
    if PokedexProviderUI.bagPresentation
        and PokedexProviderUI.bagPresentation(game) then return true end
    if PokedexProviderUI.storagePresentation
        and PokedexProviderUI.storagePresentation(game) then return true end
    if optionEnabled("pc_ui") and PokedexProviderUI.pcPresentation(game) then
      return true
    end
    return false
  end

  local function suppressNativeOverlayDraw(class, marker)
    if not (class and type(class.draw) == "function") or class[marker] then
      return
    end
    local originalDraw = class.draw
    class.draw = function(self, ...)
      local game = self and self.game
      if customBackgroundOwnsStack(game) or dialoguePresentation(game) then
        return
      end
      return originalDraw(self, ...)
    end
    class[marker] = true
  end
  suppressNativeOverlayDraw(TextBoxClass, "__widescreenUiTextDrawWrapped")
  suppressNativeOverlayDraw(ChoiceBoxClass, "__widescreenUiChoiceDrawWrapped")

  if statBoxClass and type(statBoxClass.draw) == "function"
      and not statBoxClass.__widescreenUiDrawWrapped then
    local originalStatBoxDraw = statBoxClass.draw
    statBoxClass.draw = function(self, ...)
      if levelUpPresentation(self and self.game) then return end
      return originalStatBoxDraw(self, ...)
    end
    statBoxClass.__widescreenUiDrawWrapped = true
  end

  if OptionsMenuClass and type(OptionsMenuClass.draw) == "function"
      and not OptionsMenuClass.__widescreenUiDrawWrapped then
    local originalOptionsDraw = OptionsMenuClass.draw
    OptionsMenuClass.draw = function(self, ...)
      if optionEnabled("options_menu") then return end
      return originalOptionsDraw(self, ...)
    end
    OptionsMenuClass.__widescreenUiDrawWrapped = true
  end
  if ManagerStateClass and type(ManagerStateClass.draw) == "function"
      and not ManagerStateClass.__widescreenUiDrawWrapped then
    local originalManagerDraw = ManagerStateClass.draw
    ManagerStateClass.draw = function(self, ...)
      if optionEnabled("options_menu") then
        local game = self and self.game
        local backed = dialogueBackedState(game, ManagerStateClass)
        if topState(game) == self or backed == self then return end
      end
      return originalManagerDraw(self, ...)
    end
    ManagerStateClass.__widescreenUiDrawWrapped = true
  end
  local evolutionClass = PokedexProviderUI.evolutionStateClass
  if evolutionClass and type(evolutionClass.new) == "function"
      and not evolutionClass.__widescreenUiNewWrapped then
    local originalEvolutionNew = evolutionClass.new
    evolutionClass.new = function(game, mon, ...)
      local state = originalEvolutionNew(game, mon, ...)
      if type(state) == "table" and type(mon) == "table" then
        state.__widescreenEvolutionOldSpecies = mon.species
      end
      return state
    end
    evolutionClass.__widescreenUiNewWrapped = true
  end
  if evolutionClass and type(evolutionClass.draw) == "function"
      and not evolutionClass.__widescreenUiDrawWrapped then
    local originalEvolutionDraw = evolutionClass.draw
    evolutionClass.draw = function(self, ...)
      if optionEnabled("evolution_screen") then return end
      return originalEvolutionDraw(self, ...)
    end
    evolutionClass.__widescreenUiDrawWrapped = true
  end
  local trainerCardClass = PokedexProviderUI.trainerCardClass
  if trainerCardClass and type(trainerCardClass.draw) == "function"
      and not trainerCardClass.__widescreenUiDrawWrapped then
    local originalTrainerCardDraw = trainerCardClass.draw
    trainerCardClass.draw = function(self, ...)
      if optionEnabled("trainer_card") then return end
      return originalTrainerCardDraw(self, ...)
    end
    trainerCardClass.__widescreenUiDrawWrapped = true
  end
  local oakSpeechClass = PokedexProviderUI.oakSpeechClass
  if oakSpeechClass and type(oakSpeechClass.buildSteps) == "function"
      and not oakSpeechClass.__widescreenUiPresetWrapped then
    local originalOakBuildSteps = oakSpeechClass.buildSteps
    oakSpeechClass.buildSteps = function(self, ...)
      local steps = originalOakBuildSteps(self, ...)
      local boot = self and self.game and self.game.data
        and self.game.data.field and self.game.data.field.boot
      local banks = boot and boot.namePresets
      local function contains(list, wanted)
        for _, value in ipairs(type(list) == "table" and list or {}) do
          if tostring(value):upper() == wanted then return true end
        end
        return false
      end
      -- Some extracted Red/Blue datasets expose the two named banks under
      -- opposite labels. Correct only that identifiable case, preserving
      -- total-conversion and already-correct preset ownership.
      local swapped = type(banks) == "table"
        and (contains(banks.player, "BLUE") or contains(banks.player, "GARY"))
        and (contains(banks.rival, "RED") or contains(banks.rival, "ASH"))
      if swapped then
        for _, step in ipairs(type(steps) == "table" and steps or {}) do
          if step.id == "name_player" then
            step.presetsWho = "rival"
          elseif step.id == "name_rival" then
            step.presetsWho = "player"
          end
        end
      end
      -- Yellow Legacy keeps HARD MODE available in Options; Widescreen's New
      -- Game presentation intentionally removes only its injected Oak prompt.
      for i=#(type(steps)=="table" and steps or {}),1,-1 do
        local step=steps[i]
        if step and (step.id=="hard_mode_choice"
            or step.saveKey=="hard_mode_choice") then
          table.remove(steps,i)
        end
      end
      return steps
    end
    oakSpeechClass.__widescreenUiPresetWrapped = true
  end
  if oakSpeechClass and type(oakSpeechClass.update) == "function"
      and not oakSpeechClass.__widescreenUiShrinkTimingWrapped then
    local originalOakUpdate = oakSpeechClass.update
    oakSpeechClass.update = function(self, ...)
      if optionEnabled("new_game_intro") and self and self.shrink then
        self.__widescreenFadeToHouse =
          (tonumber(self.__widescreenFadeToHouse) or 0) + 1
        if self.__widescreenFadeToHouse <= 240 then return end
        -- Skip the native shrink/walking frames only after the replacement
        -- fade is fully opaque. Native update still performs finish(), music
        -- routing and the transition into the player's house.
        self.shrink.frame = 102
      end
      return originalOakUpdate(self, ...)
    end
    oakSpeechClass.__widescreenUiShrinkTimingWrapped = true
  end
  if oakSpeechClass and type(oakSpeechClass.finish)=="function"
      and not oakSpeechClass.__widescreenUiFinishWrapped then
    local originalOakFinish=oakSpeechClass.finish
    oakSpeechClass.finish=function(self,...)
      local game=self and self.game
      local wantsFadeIn=optionEnabled("new_game_intro")
        and tonumber(self.__widescreenFadeToHouse)~=nil
      local result=originalOakFinish(self,...)
      if wantsFadeIn and game and game.stack then
        game.stack:push(PokedexProviderUI.IntroFadeInState.new(game))
      end
      return result
    end
    oakSpeechClass.__widescreenUiFinishWrapped=true
  end
  if oakSpeechClass and type(oakSpeechClass.draw) == "function"
      and not oakSpeechClass.__widescreenUiDrawWrapped then
    local originalOakSpeechDraw = oakSpeechClass.draw
    oakSpeechClass.draw = function(self, ...)
      if optionEnabled("new_game_intro") then return end
      return originalOakSpeechDraw(self, ...)
    end
    oakSpeechClass.__widescreenUiDrawWrapped = true
  end
  local namingScreenClass = PokedexProviderUI.namingScreenClass
  if namingScreenClass and type(namingScreenClass.draw) == "function"
      and not namingScreenClass.__widescreenUiDrawWrapped then
    local originalNamingDraw = namingScreenClass.draw
    namingScreenClass.draw = function(self, ...)
      local kind = PokedexProviderUI.oakSpeechPresentation
        and PokedexProviderUI.oakSpeechPresentation(self and self.game)
      if kind == "naming" then return end
      return originalNamingDraw(self, ...)
    end
    namingScreenClass.__widescreenUiDrawWrapped = true
  end
  if MenuClass and type(MenuClass.draw) == "function"
      and not MenuClass.__widescreenUiOakNamingWrapped then
    local previousMenuDraw = MenuClass.draw
    MenuClass.draw = function(self, ...)
      local kind, speech, naming, menu
      if PokedexProviderUI.oakSpeechPresentation then
        kind, speech, naming, menu =
          PokedexProviderUI.oakSpeechPresentation(self and self.game)
      end
      if kind == "naming" and menu == self then return end
      return previousMenuDraw(self, ...)
    end
    MenuClass.__widescreenUiOakNamingWrapped = true
  end

  mod.hooks:wrap("render.hud", function(next, game, viewport)
    patchDramaticShapeBattle(game)
    local result = next(game, viewport)
    if not fonts.body then return result end

    if activeStart and not stateInStack(game, activeStart) then
      activeStart = nil
    end
    if activeParty and not stateInStack(game, activeParty) then
      local activeTop=topState(game)
      local activeMt=getmetatable(activeTop)
      local retainRare=activeParty.__widescreenRareCandyPicker
        and (activeMt==TextBoxClass or activeMt==ChoiceBoxClass
          or activeMt==PokedexProviderUI.statBoxClass)
      if not retainRare then activeParty=nil end
    end
    if activeSummary and not stateInStack(game, activeSummary) then
      activeSummary = nil
    end
    if activeBattle and not stateInStack(game, activeBattle) then
      activeBattle = nil
    end

    local top = topState(game)
    local introFadeIn = top and getmetatable(top)==PokedexProviderUI.IntroFadeInState
      and top or nil
    local summaryFirst, summaryLast
    if optionEnabled("summary_screen") and activeSummary and SummaryMenu then
      summaryFirst, summaryLast = presentationRange(game, activeSummary)
    end
    local partyFirst, partyLast
    if optionEnabled("party_screen") and activeParty and PartyMenu then
      partyFirst, partyLast = presentationRange(game, activeParty)
    end
    local startFirst, startLast
    if optionEnabled("start_menu") and activeStart then
      startFirst, startLast = convertedDialogueRange(game, activeStart)
    end
    local battleFirst, battleLast
    if optionEnabled("battle_hud") and activeBattle then
      battleFirst, battleLast = convertedDialogueRange(game, activeBattle)
    end
    local dexKind, dexState, dexFirst, dexLast, dexModel = pokedexPresentation(game)
    local titleKind, titleState, titleOverlay = titlePresentation(game)
    local loadReport = loadReportPresentation(game)
    local optionsState = optionsPresentation(game)
    local managerState = managerPresentation(game)
    local dialogueFirst, dialogueLast = dialoguePresentation(game)
    local rareCandyDialogue=dialogueFirst and activeParty
      and activeParty.__widescreenRareCandyPicker
    local levelUpState,levelUpKind = levelUpPresentation(game)
    local evolutionState, evolutionFirst, evolutionLast =
      evolutionPresentation(game)
    local trainerCardState, trainerCardFirst, trainerCardLast =
      trainerCardPresentation(game)
    local pcState,pcFirst,pcLast,pcBase
    if optionEnabled("pc_ui") then
      pcState,pcFirst,pcLast,pcBase=PokedexProviderUI.pcPresentation(game)
    end
    PokedexProviderUI.currentBagView = nil
    if PokedexProviderUI.bagPresentation then
      PokedexProviderUI.currentBagView = {
        PokedexProviderUI.bagPresentation(game) }
    end
    local storageState,storageSnapshot,storageError,storageFirst,storageLast
    if PokedexProviderUI.storagePresentation then
      storageState,storageSnapshot,storageError,storageFirst,storageLast=
        PokedexProviderUI.storagePresentation(game)
    end
    local oakKind, oakState, oakNaming, oakMenu, oakFirst, oakLast
    if PokedexProviderUI.oakSpeechPresentation then
      oakKind, oakState, oakNaming, oakMenu, oakFirst, oakLast =
        PokedexProviderUI.oakSpeechPresentation(game)
    end
    local managerDialogue, managerDialogueFirst, managerDialogueLast =
      dialogueBackedState(game, ManagerStateClass)
    local optionsDialogue, optionsDialogueFirst, optionsDialogueLast =
      dialogueBackedState(game, OptionsMenuClass)
    local loadDialogue, loadDialogueFirst, loadDialogueLast =
      dialogueBackedState(game, QuarantineReportClass)
    local titleDialogue, titleDialogueFirst, titleDialogueLast =
      dialogueBackedState(game, MenuClass, function(state)
        return state and state.titleUiBox
      end)
    local dialogueTitleState
    if titleDialogue then
      for _, state in ipairs(game.stack.states) do
        if getmetatable(state) == TitleStateClass then
          dialogueTitleState = state
          break
        end
      end
    end
    if introFadeIn then
      drawInBattleSpace(function(viewW,viewH)
        PokedexProviderUI.drawIntroFadeIn(introFadeIn,viewW,viewH)
      end)
    elseif managerState then
      drawInBattleSpace(function(viewW, viewH)
        drawModManager(managerState, fonts, viewW, viewH)
      end)
    elseif PokedexProviderUI.currentBagView
        and PokedexProviderUI.currentBagView[1] then
      drawInBattleSpace(function(viewW,viewH)
        local bagView=PokedexProviderUI.currentBagView
        PokedexProviderUI.drawBagScreen(
          bagView[1],bagView[2],fonts,viewW,viewH,bagView[3])
      end)
    elseif storageState then
      drawInBattleSpace(function(viewW,viewH)
        PokedexProviderUI.drawPokemonStorageScreen(game,storageState,
          storageSnapshot,fonts,viewW,viewH,storageError)
        drawPresentationOverlays(game,storageFirst,storageLast,fonts,viewW,viewH)
      end)
    elseif pcState then
      drawInBattleSpace(function(viewW,viewH)
        PokedexProviderUI.drawPcScreen(game,pcState,fonts,viewW,viewH)
        drawPresentationOverlays(game,pcBase,pcLast,fonts,viewW,viewH)
      end)
    elseif managerDialogue then
      drawInBattleSpace(function(viewW, viewH)
        drawModManager(managerDialogue, fonts, viewW, viewH)
        drawPresentationOverlays(game, managerDialogueFirst,
          managerDialogueLast, fonts, viewW, viewH)
      end)
    elseif optionsState then
      drawInBattleSpace(function(viewW, viewH)
        drawOptionsMenu(optionsState, fonts, viewW, viewH)
      end)
    elseif optionsDialogue then
      drawInBattleSpace(function(viewW, viewH)
        drawOptionsMenu(optionsDialogue, fonts, viewW, viewH)
        drawPresentationOverlays(game, optionsDialogueFirst,
          optionsDialogueLast, fonts, viewW, viewH)
      end)
    elseif loadReport then
      drawInBattleSpace(function(viewW, viewH)
        drawLoadReport(loadReport, fonts, viewW, viewH)
      end)
    elseif loadDialogue then
      drawInBattleSpace(function(viewW, viewH)
        drawLoadReport(loadDialogue, fonts, viewW, viewH)
        drawPresentationOverlays(game, loadDialogueFirst,
          loadDialogueLast, fonts, viewW, viewH)
      end)
    elseif oakKind == "naming" then
      drawInDesignSpace(function()
        PokedexProviderUI.drawOakNaming(oakState, oakNaming, oakMenu, fonts)
      end)
    elseif oakKind == "speech" then
      drawInDesignSpace(function()
        PokedexProviderUI.drawOakSpeech(oakState, fonts)
        drawPresentationOverlays(game, oakFirst, oakLast, fonts,
          nil, nil, true)
      end)
    elseif titleKind then
      drawInBattleSpace(function(viewW, viewH)
        if titleKind == "continue" then
          drawContinueInfo(titleState, titleOverlay, fonts, viewW, viewH)
        elseif titleKind == "title" then
          drawTitleStandby(titleState, fonts, viewW, viewH)
        else
          drawTitleMenu(titleState, titleOverlay, fonts, viewW, viewH)
        end
      end)
    elseif titleDialogue and dialogueTitleState then
      drawInBattleSpace(function(viewW, viewH)
        drawTitleMenu(dialogueTitleState, titleDialogue, fonts, viewW, viewH)
        drawPresentationOverlays(game, titleDialogueFirst,
          titleDialogueLast, fonts, viewW, viewH)
      end)
    elseif levelUpState then
      drawInBattleSpace(function(viewW, viewH)
        if levelUpKind=="party" then
          drawPartyMenu(mod,activeParty,PartyMenu,fonts)
          PokedexProviderUI.drawLevelUpPanel(levelUpState,fonts,viewW,viewH)
        else
          PokedexProviderUI.drawBattleLevelUp(
            activeBattle, levelUpState, fonts, viewW, viewH)
        end
      end)
    elseif trainerCardState then
      drawInDesignSpace(function()
        PokedexProviderUI.drawTrainerCard(trainerCardState, fonts)
        drawPresentationOverlays(game, trainerCardFirst, trainerCardLast, fonts)
      end)
    elseif evolutionState then
      drawInDesignSpace(function()
        PokedexProviderUI.drawEvolutionScreen(evolutionState, fonts)
        drawPresentationOverlays(game, evolutionFirst, evolutionLast, fonts)
      end)
    elseif summaryFirst then
      drawInDesignSpace(function()
        drawSummaryMenu(activeSummary, fonts)
        drawPresentationOverlays(game, summaryFirst, summaryLast, fonts)
      end)
    elseif partyFirst then
      drawInDesignSpace(function()
        drawPartyMenu(mod, activeParty, PartyMenu, fonts)
        drawPresentationOverlays(game, partyFirst, partyLast, fonts)
      end)
    elseif dexKind then
      drawInDesignSpace(function()
        if dexKind == "provider_v2" then
          PokedexProviderUI.draw(game, dexState, dexModel, fonts)
        elseif dexKind == "entry" then
          drawPokedexEntry(dexState, fonts)
        else
          drawPokedexList(dexState, fonts, dexModel)
        end
        drawPresentationOverlays(game, dexFirst, dexLast, fonts)
      end)
    elseif startFirst then
      drawInDesignSpace(function()
        drawStartMenu(activeStart, fonts)
        drawPresentationOverlays(game, startFirst, startLast, fonts)
      end)
    elseif battleFirst then
      drawInBattleSpace(function(viewW, viewH)
        drawBattleHUD(activeBattle, fonts, viewW, viewH)
        drawPresentationOverlays(game, battleFirst, battleLast, fonts,
                                 viewW, viewH)
      end)
    elseif rareCandyDialogue then
      drawInDesignSpace(function()
        drawPartyMenu(mod,activeParty,PartyMenu,fonts)
        drawPresentationOverlays(game,dialogueFirst,dialogueLast,fonts)
      end)
    elseif dialogueFirst then
      drawInBattleSpace(function(viewW, viewH)
        drawPresentationOverlays(game, dialogueFirst, dialogueLast, fonts,
                                 viewW, viewH)
      end)
    end
    if #worldHudOverlayProviders > 0 then
      drawInBattleSpace(function(viewW, viewH)
        PokedexProviderUI.drawWorldExtensions(game, fonts, viewW, viewH)
      end)
    end
    return result
  end, 12000)

  PokedexProviderUI.designWidth = DESIGN_W
  PokedexProviderUI.designHeight = DESIGN_H
  mod.exports.designWidth = PokedexProviderUI.designWidth
  mod.exports.designHeight = PokedexProviderUI.designHeight
  mod.exports.resolve2dPokemonPortrait = PokedexProviderUI.resolve2dPokemonPortrait
  mod.exports.draw2dPokemonPortrait = PokedexProviderUI.draw2dPokemonPortrait
  mod.exports.portraitPolicy = "battle_art_2d_only"
  mod.exports.prototype = "title_start_party_summary_pokedex_report_and_battle"
  mod.exports.battleHud = "responsive_640x360"
  mod.exports.ownsBattleTrainerBack = function()
    return optionEnabled("battle_hud")
  end
  mod.exports.battleMoveInspectorContract = "v1"
  mod.exports.dialoguePresentation = "responsive_skin_and_overworld_pagination_v2"
  mod.exports.reflowWideDialogue = function(text, maxCols)
    return PokedexProviderUI.reflowWideDialogue(TextBoxClass, text, maxCols)
  end
  mod.exports.pokedexPresentation = "native_independent_style_v1"
  mod.exports.pokedexProviderContract = "v2_with_v1_compat"
end
