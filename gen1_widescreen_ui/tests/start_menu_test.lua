local draws = 0
local nativeIconDraws = 0
local shinyIconDraws = 0
local shinyStarImageDraws = 0
local trainerBadgeImageDraws = 0
trainerFaceImageDraws = 0
trainerProviderPlayerDraws = 0
trainerProviderLeaderDraws = 0
local modAssetImageCalls = {}
local modAssetImageFail = false
local assetsReload
local iconImage
local externalIconImage
local externalShinyIconImage
local shinyStarImage
local trainerBadgeImage
trainerFaceImage = nil
trainerProviderPlayerImage = nil
trainerProviderLeaderImage = nil
local paletteShaderActive = false
local paletteDraws = 0
local printedTexts = {}
local titleSpriteImages
local titleSpriteXs = { {}, {} }
local titleAnimationFrame
local titleSpriteFrames = {}
local statusMarkLines = 0
local animatedTitleDraws = 0
local animatedImage
local titleRandomQueue = {}

local function font(size)
  return {
    size = size,
    setFilter = function() end,
    getWidth = function(_, text) return #tostring(text) * 6 end,
    getHeight = function() return size end,
  }
end

love = {
  textinput = function() end,
  keyboard = { isDown = function() return false end },
  math = {
    random = function(low, high)
      local value = table.remove(titleRandomQueue, 1)
      if value == nil then value = low end
      return math.max(low, math.min(high, value))
    end,
  },
  timer = {
    getTime = (function()
      local now = 0
      return function() now = now + 1 / 60; return now end
    end)(),
  },
  graphics = {
    newFont = function(_, size) return font(size) end,
    setColor = function() end,
    setFont = function() end,
    getDimensions = function() return 1920, 1080 end,
    rectangle = function() draws = draws + 1 end,
    ellipse = function() draws = draws + 1 end,
    circle = function() draws = draws + 1 end,
    polygon = function() draws = draws + 1 end,
    line = function() draws = draws + 1; statusMarkLines = statusMarkLines + 1 end,
    setLineWidth = function() end,
    print = function(text)
      draws = draws + 1
      printedTexts[#printedTexts + 1] = tostring(text)
    end,
    push = function() end,
    pop = function() end,
    translate = function() end,
    scale = function() end,
    setShader = function(shader) paletteShaderActive = shader ~= nil end,
    draw = function(image, a, b)
      draws = draws + 1
      if paletteShaderActive then paletteDraws = paletteDraws + 1 end
      if image == externalIconImage then nativeIconDraws = nativeIconDraws + 1 end
      if image == externalShinyIconImage then shinyIconDraws = shinyIconDraws + 1 end
      if image == shinyStarImage then shinyStarImageDraws = shinyStarImageDraws + 1 end
      if image == trainerBadgeImage then trainerBadgeImageDraws = trainerBadgeImageDraws + 1 end
      if image == trainerFaceImage then trainerFaceImageDraws = trainerFaceImageDraws + 1 end
      if image == trainerProviderPlayerImage then
        trainerProviderPlayerDraws = trainerProviderPlayerDraws + 1
      end
      if image == trainerProviderLeaderImage then
        trainerProviderLeaderDraws = trainerProviderLeaderDraws + 1
      end
      if image == animatedImage then animatedTitleDraws = animatedTitleDraws + 1 end
      if titleSpriteImages then
        for i = 1, 2 do
          if image == titleSpriteImages[i] then
            local x = type(a) == "number" and a or b
            titleSpriteXs[i][#titleSpriteXs[i] + 1] = x
            if titleAnimationFrame then
              titleSpriteFrames[titleAnimationFrame] =
                titleSpriteFrames[titleAnimationFrame] or {}
              titleSpriteFrames[titleAnimationFrame][i] = true
            end
          end
        end
      end
    end,
    newQuad = function() return {} end,
  },
}

local StartMenu = {}
function StartMenu.new(game)
  return {
    game = game,
    index = 2,
    items = {
      { label = "POKEDEX" },
      { label = "POKEMON" },
      { label = "ITEM" },
      { label = "QUESTS" },
    },
    draw = function() error("native START draw should be suppressed") end,
  }
end

package.preload["src.ui.StartMenu"] = function() return StartMenu end
package.preload["src.ui.BagMenu"] = function() return {} end

local PartyMenu = {}
function PartyMenu.drawIcon()
  draws = draws + 1
  return true
end
function PartyMenu.new(game, opts)
  return {
    game = game,
    opts = opts,
    party = opts and opts.party,
    index = 1,
    blink = 0,
    draw = function() error("native party draw should be suppressed") end,
    bottomMessage = function() return "Choose a POKEMON." end,
  }
end
package.preload["src.ui.PartyMenu"] = function() return PartyMenu end

local nativeEvolutionDraws = 0
local evolutionUpdateCalls = 0
local EvolutionState = {}
EvolutionState.__index = EvolutionState
function EvolutionState.new(game, mon, newSpecies)
  return setmetatable({
    game = game, mon = mon, newSpecies = newSpecies,
    oldName = mon.nickname or mon.species, t = 0, done = false,
    canceled = false, cancelable = true,
  }, EvolutionState)
end
function EvolutionState:update()
  evolutionUpdateCalls = evolutionUpdateCalls + 1
end
function EvolutionState:draw()
  nativeEvolutionDraws = nativeEvolutionDraws + 1
end
package.preload["src.ui.EvolutionState"] = function() return EvolutionState end

local portraitImage = {
  getDimensions = function() return 56, 56 end,
  setFilter = function() end,
}
introOakImage = { getDimensions = function() return 59, 90 end,
  setFilter = function() end }
introRedImage = { getDimensions = function() return 37, 84 end,
  setFilter = function() end }
introRivalImage = { getDimensions = function() return 36, 84 end,
  setFilter = function() end }
trainerFaceImage = {
  getDimensions = function() return 16, 256 end,
  setFilter = function() end,
}
trainerProviderPlayerImage = {
  getDimensions = function() return 56, 56 end,
  setFilter = function() end,
}
trainerProviderLeaderImage = {
  getDimensions = function() return 32, 32 end,
  setFilter = function() end,
}
local nativeTrainerCardDraws = 0
local trainerCardUpdates = 0
local TrainerCard = {}
TrainerCard.__index = TrainerCard
function TrainerCard.new(game)
  local quads = {}
  for i = 0, 7 do quads[i] = {} end
  return setmetatable({
    game = game,
    pic = portraitImage,
    faces = { img = trainerFaceImage, quads = quads },
  }, TrainerCard)
end
function TrainerCard:update()
  trainerCardUpdates = trainerCardUpdates + 1
end
function TrainerCard:draw()
  nativeTrainerCardDraws = nativeTrainerCardDraws + 1
end
package.preload["src.ui.TrainerCard"] = function() return TrainerCard end
nativeOakDraws = 0
OakSpeechClass = {}
OakSpeechClass.__index = OakSpeechClass
function OakSpeechClass:draw() nativeOakDraws = nativeOakDraws + 1 end
function OakSpeechClass:update() self.updateCalls = (self.updateCalls or 0) + 1 end
function OakSpeechClass:finish()
  self.game.stack:pop()
  self.finished=true
end
function OakSpeechClass:buildSteps()
  return { {id="legend",kind="say"},
    {id="hard_mode_choice",kind="yesno",saveKey="hard_mode_choice"},
    {id="shrink",kind="shrink"} }
end
package.preload["src.ui.OakSpeech"] = function() return OakSpeechClass end
nativeNamingDraws = 0
NamingScreenClass = {}
NamingScreenClass.__index = NamingScreenClass
function NamingScreenClass:draw() nativeNamingDraws = nativeNamingDraws + 1 end
function NamingScreenClass:update() self.updateCalls = (self.updateCalls or 0) + 1 end
function NamingScreenClass:grid()
  return { { "A", "B", "C" }, { "D", "E", "F" } }
end
package.preload["src.ui.NamingScreen"] = function() return NamingScreenClass end
package.preload["src.inventory.Badges"] = function()
  return {
    list = function()
      return { "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8" }
    end,
    itemFor = function(id) return "ITEM_" .. id end,
  }
end
titleSpriteImages = {
  { getDimensions = function() return 56, 56 end, setFilter = function() end },
  { getDimensions = function() return 56, 56 end, setFilter = function() end },
}
iconImage = {
  getDimensions = function() return 512, 640 end,
  setFilter = function() end,
  setWrap = function() end,
}
externalIconImage = {
  getDimensions = function() return 32, 64 end,
  setFilter = function() end,
  setWrap = function() end,
}
externalShinyIconImage = {
  getDimensions = function() return 32, 64 end,
  setFilter = function() end,
  setWrap = function() end,
}
shinyStarImage = {
  getDimensions = function() return 32, 31 end,
  setFilter = function() end,
}
trainerBadgeImage = {
  getDimensions = function() return 512, 64 end,
  setFilter = function() end,
}
animatedImage = {
  getDimensions = function() return 96, 96 end,
  setFilter = function() end,
}
local hdOverworldImage = {
  getDimensions = function() return 32, 192 end,
  setFilter = function() end,
  setWrap = function() end,
}
local battleArtCalls = 0
local standaloneBattleArtCalls = 0
local standaloneTitleArtCalls = 0
local engineEvolutionSpriteCalls = 0
local providerPresentationPurposes = {}
local providerPresentationTokens = {}
local providerPresentationTokensStable = true
local providerPresentationReturnsNil = false
local providerPresentationLatestShiny = {}
local titlePresentationRequests = {}
local animatedBattleArtCalls = 0
local animatedPositiveDelta = false
local battleArtMode = "static"
local battleArt = {
  setting = { get = function() return battleArtMode end },
  image = function(species, side)
    battleArtCalls = battleArtCalls + 1
    assert(species == "PIKACHU" or species == "EEVEE"
      or species == "CHARIZARD" or species == "BLASTOISE")
    assert(side == "front")
    return portraitImage
  end,
  metrics = function()
    return { x0 = 2, x1 = 53, y0 = 1, y1 = 55 }
  end,
}
local animatedBattleArt = {
  update = function(battle, dt)
    animatedBattleArtCalls = animatedBattleArtCalls + 1
    if (dt or 0) > 0 then animatedPositiveDelta = true end
    battle.enemy.sprite = animatedImage
  end,
  finish = function() end,
}
package.preload["src.pokemon.Sprites"] = function()
  return {
    path = function(_, species, side, context)
      assert(species == "PIKACHU" or species == "EEVEE")
      assert(side == "front")
      assert(context and context.kind == "battle")
      if species == "EEVEE" then
        engineEvolutionSpriteCalls = engineEvolutionSpriteCalls + 1
      end
      return "active/front/" .. species .. ".png", true
    end,
  }
end
package.preload["src.render.Assets"] = function()
  return {
    image = function(path)
      if path == "party_icons.png" then return iconImage end
      if path == "modern/PIKACHU.png" then return externalIconImage end
      if path == "modern/PIKACHU_SHINY.png" then return externalShinyIconImage end
      assert(not tostring(path):find("shiny_star.png", 1, true),
        "mod-owned shiny star was incorrectly sent through Assets.image")
      if tostring(path):find("hgss_runtime_hd", 1, true) then
        return hdOverworldImage
      end
      return portraitImage
    end,
    register = function(callback) assetsReload = callback end,
  }
end
package.preload["src.render.PaletteFX"] = function()
  local palette = {
    { 255, 255, 255 }, { 180, 210, 255 },
    { 40, 90, 180 }, { 0, 0, 0 },
  }
  return {
    shader = function() return { send = function() end } end,
    keyedShader = function() return { send = function() end } end,
    sendColors = function(shader, colors) shader:send("c0", colors[1]) end,
    pal = function() return palette end,
    monPal = function() return palette end,
    monPalName = function() return nil end,
    spriteObp = function() return palette end,
    usesGbcPack = function() return false end,
    markTrueColor = function() end,
  }
end
package.preload["src.core.SaveData"] = function()
  return {
    modsDiffNotice = function()
      return "This save was made with 34 mods; 12 are no longer active, "
        .. "3 changed version, 5 newly active"
    end,
  }
end
package.preload["src.render.Font"] = function()
  return {
    split = function(value)
      local out = {}
      value = tostring(value or "")
      for i = 1, #value do out[#out + 1] = { from = i, to = i } end
      return out
    end,
  }
end
local TextBoxClass = {}
TextBoxClass.__index = TextBoxClass
local nativeTextDraws = 0
function TextBoxClass:draw() nativeTextDraws = nativeTextDraws + 1 end
function TextBoxClass.substitute(_, text) return text end
function TextBoxClass.paginate(text, maxCols)
  local pages, contBefore = {}, {}
  for part in (text .. "\f"):gmatch("(.-)\f") do
    if part ~= "" then
      local lines, conts = {}, {}
      local pos, wait = 1, false
      while true do
        local marker = part:find("[\n\v]", pos)
        local raw = marker and part:sub(pos, marker - 1) or part:sub(pos)
        while #raw > maxCols do
          local cut = maxCols
          for i = maxCols, 1, -1 do
            if raw:sub(i, i) == " " then cut = i break end
          end
          lines[#lines + 1] = raw:sub(1, cut):gsub("%s+$", "")
          conts[#conts + 1] = wait
          wait = false
          raw = raw:sub(cut + 1):gsub("^%s+", "")
        end
        lines[#lines + 1] = raw
        conts[#conts + 1] = wait
        if not marker then break end
        wait = part:sub(marker, marker) == "\v"
        pos = marker + 1
      end
      pages[#pages + 1], contBefore[#contBefore + 1] = lines, conts
    end
  end
  if #pages == 0 then pages, contBefore = { { "" } }, { { false } } end
  pages.contBefore = contBefore
  return pages
end
function TextBoxClass:beginLine()
  self.codes = {}
  self.shown[#self.shown + 1] = {}
end
function TextBoxClass.new(game, text, onDone, opts)
  local state = setmetatable({
    game = game, onDone = onDone, auto = opts and opts.auto,
    choice = opts and opts.choice, stay = opts and opts.stay,
    pages = TextBoxClass.paginate(text, 18), pageIndex = 1, lineIndex = 1,
    charIndex = 0, shown = {}, waiting = false, done = false, blink = 0,
  }, TextBoxClass)
  state:beginLine()
  return state
end
package.preload["src.render.TextBox"] = function() return TextBoxClass end
local ChoiceBoxClass = {}
ChoiceBoxClass.__index = ChoiceBoxClass
function ChoiceBoxClass:draw() error("native ChoiceBox draw should be suppressed") end
package.preload["src.ui.ChoiceBox"] = function() return ChoiceBoxClass end

local ListMenuClass = {}
ListMenuClass.__index = ListMenuClass
nativeListDraws = 0
function ListMenuClass:update() self.updateCalls = (self.updateCalls or 0) + 1 end
function ListMenuClass:draw() nativeListDraws = nativeListDraws + 1 end
package.preload["src.ui.ListMenu"] = function() return ListMenuClass end
local MenuClass = {}
MenuClass.__index = MenuClass
local nativeTitleMenuDraws = 0
function MenuClass:draw() nativeTitleMenuDraws = nativeTitleMenuDraws + 1 end
package.preload["src.ui.Menu"] = function() return MenuClass end
PlayerPC = {}
function PlayerPC.new(game)
  return setmetatable({ game=game,index=1,items={
    {label="WITHDRAW ITEM"},{label="DEPOSIT ITEM"},
    {label="TOSS ITEM"},{label="LOG OFF"},
  } }, MenuClass)
end
package.preload["src.ui.PlayerPC"] = function() return PlayerPC end
BoxMenu = {}
function BoxMenu.new(game)
  return setmetatable({ game=game,index=1,items={
    {label="WITHDRAW <PK><MN>"},{label="DEPOSIT <PK><MN>"},
    {label="RELEASE <PK><MN>"},{label="CHANGE BOX"},{label="SEE YA!"},
  } }, MenuClass)
end
package.preload["src.ui.BoxMenu"] = function() return BoxMenu end
local PokedexMenuClass = {}
function PokedexMenuClass.new(game)
  return setmetatable({
    game = game, title = "POKEDEX", index = 1, scroll = 0,
    footer = "SEEN 001  OWN 001",
    items = {
      { label = "001 BULBASAUR", ball = true, value = "BULBASAUR" },
      { label = "002 -----" },
    },
  }, ListMenuClass)
end
package.preload["src.ui.PokedexMenu"] = function() return PokedexMenuClass end
local DexEntryMenuClass = {}
DexEntryMenuClass.__index = DexEntryMenuClass
package.preload["src.ui.DexEntryMenu"] = function() return DexEntryMenuClass end
local TitleStateClass = {}
TitleStateClass.__index = TitleStateClass
local titleSpriteIndices = {}
function TitleStateClass:update() self.updateCalls = (self.updateCalls or 0) + 1 end
function TitleStateClass:currentSprite()
  local index = self.cycleIndex or 1
  titleSpriteIndices[index] = true
  return titleSpriteImages[index]
end
package.preload["src.ui.TitleState"] = function() return TitleStateClass end
local OptionsMenuClass = {}
OptionsMenuClass.__index = OptionsMenuClass
local nativeOptionsDraws = 0
function OptionsMenuClass:update()
  self.updateCalls = (self.updateCalls or 0) + 1
end
function OptionsMenuClass:draw() nativeOptionsDraws = nativeOptionsDraws + 1 end
package.preload["src.ui.OptionsMenu"] = function() return OptionsMenuClass end
local ManagerStateClass = {}
ManagerStateClass.__index = ManagerStateClass
local nativeManagerDraws = 0
function ManagerStateClass:update()
  self.updateCalls = (self.updateCalls or 0) + 1
end
function ManagerStateClass:draw() nativeManagerDraws = nativeManagerDraws + 1 end
function ManagerStateClass:rowsForScreen() return self.testRows or {} end
function ManagerStateClass:isStaged(modInfo) return modInfo.staged == true end
function ManagerStateClass:stagedList() return self.testStaged or {} end
package.preload["src.mods.ManagerState"] = function() return ManagerStateClass end
local QuarantineReportClass = {}
QuarantineReportClass.__index = QuarantineReportClass
function QuarantineReportClass:update() self.updateCalls = (self.updateCalls or 0) + 1 end
package.preload["src.ui.QuarantineReport"] = function() return QuarantineReportClass end

local SummaryMenu = { isOpaque = true }
SummaryMenu.__index = SummaryMenu
function SummaryMenu.new(game, mon)
  return setmetatable({
    game = game,
    mon = mon,
    page = 1,
  }, SummaryMenu)
end
function SummaryMenu:draw()
  error("native summary draw should be suppressed")
end
package.preload["src.ui.SummaryMenu"] = function() return SummaryMenu end
package.preload["src.pokemon.Growth"] = function()
  return {
    expForLevel = function(_, level) return level * level * level end,
  }
end
package.preload["src.pokemon.Stats"] = function()
  return { isShiny = function(dvs) return dvs == "shiny" end }
end
nativeStatBoxDraws = 0
StatBoxClass = {}
StatBoxClass.__index = StatBoxClass
function StatBoxClass.new(game,mon)
  return setmetatable({game=game,mon=mon},StatBoxClass)
end
function StatBoxClass:draw() nativeStatBoxDraws=nativeStatBoxDraws+1 end
local BattleState = {
  wideLayout = function() return true end,
  drawHUDs = function() end,
  drawTextArea = function() end,
  StatBox = StatBoxClass,
}
package.preload["src.battle.BattleState"] = function() return BattleState end

local hudHook
local battleHook
local pointerHook
local optionEnabled = true
local billboardBaseMesh = {}
local billboardModule = {
  mesh = function() return billboardBaseMesh end,
  invalidate = function() end,
}
billboardModule.shadowQuad = billboardModule.mesh
local voxelDrawTexture
local voxelModule = {
  pushQuad = function(indices) indices[1] = 1 end,
  newMesh = function(vertices, indices)
    return { vertices = vertices, indices = indices }
  end,
  draw = function(_, texture) voxelDrawTexture = texture end,
}
local shadowModule = { draw = function() end }
local dramaticLib = {
  require = function(name)
    if name == "SpriteBillboards" then return billboardModule end
    if name == "Voxel3D" then return voxelModule end
    if name == "ShadowMap" then return shadowModule end
    if name == "OverworldBattle" then
      return {
        snapHUDs = function() return false end,
        drawHudPanels = function() end,
      }
    end
    if name == "BattleHud" then
      return { panel = function() return false end }
    end
    error("unexpected Dramatic Shape module " .. tostring(name))
  end,
}
local loggedErrors = {}
local mod = {
  options = {
    define = function() end,
    get = function() return optionEnabled end,
  },
  hooks = {
    wrap = function(_, name, fn, priority)
      if name == "render.hud" then
        assert(priority == 12000)
        hudHook = fn
      elseif name == "battle.overlay" then
        assert(priority == 11000)
        battleHook = fn
      elseif name == "input.pointer" then
        assert(priority == 12000)
        pointerHook = fn
      elseif name == "screen.render_visible" then
        assert(priority == 12000)
        screenVisibleHook = fn
      else
        error("unexpected hook " .. tostring(name))
      end
    end,
  },
  log = {
    info = function() end,
    warn = function() end,
    error = function(_, message) loggedErrors[#loggedErrors + 1] = tostring(message) end,
  },
  assets = {
    path = function(_, path)
      return "mods/gen1_widescreen_ui/assets/" .. path
    end,
    image = function(_, relative)
      modAssetImageCalls[#modAssetImageCalls + 1] = relative
      if modAssetImageFail and relative == "assets/shiny_star.png" then
        error("simulated missing shiny star")
      end
      if relative == "assets/shiny_star.png" then return shinyStarImage end
      if relative == "assets/trainer_badges.png" then return trainerBadgeImage end
      if relative == "assets/intro_oak_frlg.png" then return introOakImage end
      if relative == "assets/intro_red_frlg.png" then return introRedImage end
      if relative == "assets/intro_rival_frlg.png" then return introRivalImage end
      error("unexpected mod asset " .. tostring(relative))
    end,
  },
  find = function(_, id)
    if id == "gen1_shiny_system" then
      return { exports = {
        isShiny = function(mon)
          if mon.shiny~=nil then return mon.shiny==true end
          return nil
        end,
        shouldUseShinyArt = function(mon) return mon.shiny == true end,
        battleImage = function() return nil end,
      } }
    end
    if id == "DRAMATIC_SHAPE" then
      return { exports = { lib = dramaticLib } }
    end
  end,
  exports = {},
}

local init = assert(loadfile("gen1_widescreen_ui/main.lua"))()
init(mod)
assert(type(hudHook) == "function", "HUD hook was not registered")
assert(type(battleHook) == "function", "battle hook was not registered")
-- pointer hook assertion follows provider-registration coverage below.
assert(mod.exports.designWidth == 640 and mod.exports.designHeight == 360)
if mod.exports.trainerCardPortraitApiVersion ~= 1 then
  local keys={}; for k in pairs(mod.exports) do keys[#keys+1]=tostring(k) end
  table.sort(keys); error("missing trainer export; keys="..table.concat(keys,","))
end
local game = { stack = { states = {} } }
function game.stack:top() return self.states[#self.states] end
function game.stack:pop() return table.remove(self.states) end
function game.stack:push(state)
  self.states[#self.states+1]=state
  if state.enter then state:enter() end
  return state
end

local menu = StartMenu.new(game)
game.stack.states[1] = menu
menu:draw()

local downstream = 0
local result = hudHook(function(receivedGame)
  assert(receivedGame == game)
  downstream = downstream + 1
  return "kept"
end, game, {})

assert(result == "kept", "HUD wrapper did not preserve downstream result")
assert(downstream == 1, "HUD wrapper did not call downstream exactly once")
assert(draws > 10, "responsive START menu did not draw")

local before = draws
local overlay = {}
game.stack.states[2] = overlay
hudHook(function() end, game, {})
assert(draws == before, "START presenter drew over a different top state")

-- Disabling the feature must restore the captured native draw instead of
-- leaving the START menu invisible.
local nativeFallback = false
local oldMenu = StartMenu.__widescreenUiWrapped
assert(oldMenu == true)
menu.__widescreenUiOriginalDraw = function() nativeFallback = true end
optionEnabled = false
menu:draw()
assert(nativeFallback, "disabled option did not restore native START drawing")

-- The party presenter must preserve the PartyMenu state and draw in the same
-- final HUD pass, including the engine icon method used by icon/follower mods.
optionEnabled = true
local startText = setmetatable({
  game = game,
  shown = { { 1, 2, 3, 4 } },
  pages = { { "START MESSAGE" } },
  pageIndex = 1,
  lineIndex = 1,
  done = true,
  blink = 0,
}, TextBoxClass)
game.stack.states = { menu, startText }
startText:draw()
assert(nativeTextDraws == 0,
       "native TextBox was not suppressed over widescreen START")
local beforeStartText = draws
hudHook(function() end, game, {})
assert(draws > beforeStartText,
       "widescreen START did not compose beneath TextBox")

local party = PartyMenu.new(game, {
  party = {
    {
      species = "PIKACHU", nickname = "SPARK", level = 25, hp = 61,
      exp = 16000, stats = { hp = 72 },
      moves = { { id = "THUNDERBOLT", pp = 15 } },
    },
    {
      species = "EEVEE", level = 20, hp = 45,
      stats = { hp = 50 }, moves = {},
    },
  },
})
game.data = {
  icons = { bySpecies = {
    PIKACHU = {
      image = "modern/PIKACHU.png",
      shinyImage = "modern/PIKACHU_SHINY.png",
    },
  } },
  pokemon = {
    CHARIZARD = { name = "CHARIZARD", dex = 6, tmhm = {},
      types = { "FIRE", "FLYING" } },
    BLASTOISE = { name = "BLASTOISE", dex = 9, tmhm = {},
      types = { "WATER" } },
    PIKACHU = { name = "PIKACHU", dex = 25, tmhm = {},
      growthRate = "MEDIUM_FAST", types = { "ELECTRIC" } },
    EEVEE = { name = "EEVEE", dex = 133, tmhm = {}, types = { "NORMAL" } },
  },
  moves = { THUNDERBOLT = {
    name = "THUNDERBOLT", pp = 15, type = "ELECTRIC",
  } },
}
game.mods = {
  exports = {
    BATTLE_ART_VOXEL_FORK = {
      lib = {
        require = function(name)
          if name == "BattleArt" then return battleArt end
          if name == "AnimatedBattleArt" then return animatedBattleArt end
        end,
      },
    },
  },
}
game.save = { party = party.party, player = { name = "RED", id = 12345 } }
game.stack.states = { party }
party:draw()
local beforeParty = draws
hudHook(function() end, game, {})
assert(draws > beforeParty, "responsive Pokemon screen did not draw")
assert(nativeIconDraws > 0,
       "widescreen Pokemon screen did not draw a 32x32 icon natively")
assert(shinyStarImageDraws == 0,
       "normal Pokemon details drew a shiny star icon")
-- Field Rare Candy keeps its target Party menu as the visual background for
-- both the growth message and the presenter-owned stat-gain panel.
rareBag=setmetatable({game=game,index=1,items={{value="RARE_CANDY"}}},ListMenuClass)
game.stack.states={rareBag}
rareParty=PartyMenu.new(game,{pickOnly=true})
assert(rareParty.__widescreenRareCandyPicker==true
    and rareParty.opts.keepOpen~=true,
  "Rare Candy target Party presentation was not retained safely")
rareParty.party=party.party
game.stack.states={rareBag,rareParty}
rareParty:draw()
rareGrowthText=TextBoxClass.new(game,"SPARK grew\nto level 26!")
game.stack.states[#game.stack.states+1]=rareGrowthText
game.stack.states={rareBag,rareGrowthText}
beforeRareGrowth=draws; hudHook(function()end,game,{})
assert(draws>beforeRareGrowth,
  "Rare Candy growth notification did not retain Widescreen Party background")
rareStat=StatBoxClass.new(game,party.party[1])
rareStat.__widescreenLevelUp={level=26,
  stats={hp=75,attack=46,defense=37,speed=64,special=52},
  gains={hp=3,attack=2,defense=2,speed=3,special=2}}
game.stack.states={rareBag,rareParty,rareStat}
beforeNativeRareStat=nativeStatBoxDraws; printedTexts={}
rareStat:draw(); hudHook(function()end,game,{})
assert(nativeStatBoxDraws==beforeNativeRareStat
    and table.concat(printedTexts,"\n"):find("LEVEL UP",1,true)
    and table.concat(printedTexts,"\n"):find("+3",1,true),
  "Rare Candy stat gains did not use the Widescreen level-up panel")
game.stack.states={party}
party:draw()
party.party[1].dvs = "ordinary"
party.party[1].shiny = true
local shinyStarsBeforeParty = shinyStarImageDraws
hudHook(function() end, game, {})
assert(shinyIconDraws > 0,
       "widescreen Pokemon screen ignored the explicit shiny mod flag")
assert(shinyStarImageDraws == shinyStarsBeforeParty + 1,
       "shiny Pokemon details did not draw exactly one supplied star icon")
assert(modAssetImageCalls[1] == "assets/shiny_star.png",
       "runtime star loader did not call mod.assets:image with the relative name")
local assetCallsAfterSuccess = #modAssetImageCalls
hudHook(function() end, game, {})
assert(#modAssetImageCalls == assetCallsAfterSuccess,
       "successful shiny-star load was not cached")

-- A runtime load failure is safe, retryable and diagnosed once per distinct
-- failure even when multiple shiny panels attempt to draw it.
assert(type(assetsReload) == "function", "asset reload callback was not registered")
assetsReload()
modAssetImageFail = true
local failedAssetErrors = #loggedErrors
local failedAssetCalls = #modAssetImageCalls
hudHook(function() end, game, {})
hudHook(function() end, game, {})
assert(#modAssetImageCalls == failedAssetCalls + 2,
       "failed shiny-star load was cached instead of retried")
assert(#loggedErrors == failedAssetErrors + 1,
       "shiny-star failure diagnostic was not deduplicated")
modAssetImageFail = false
hudHook(function() end, game, {})
assert(shinyStarImageDraws >= shinyStarsBeforeParty + 3,
       "shiny-star loader did not recover after a transient failure")
assert(battleArtCalls > 0,
       "Pokemon details did not consult BATTLE_ART_VOXEL_FORK")

battleArtMode = "animated"
hudHook(function() end, game, {})
hudHook(function() end, game, {})
assert(animatedBattleArtCalls > 0,
       "Pokemon details did not consult AnimatedBattleArt")
assert(animatedPositiveDelta,
       "Pokemon details did not advance AnimatedBattleArt timing")

local standaloneProvider = { exports = {
  presentationApiVersion = 1,
  resolvePokemonPresentation = function(receivedGame, mon, side, context)
    standaloneBattleArtCalls = standaloneBattleArtCalls + 1
    assert(receivedGame == game and mon and mon.species and side == "front")
    assert(type(context) == "table" and type(context.token) == "table")
    local purpose = context.purpose
    assert(purpose == "title" or purpose == "party"
      or purpose == "summary" or purpose == "pokedex"
      or purpose == "evolution" or purpose == "oak_speech"
      or purpose == "storage")
    providerPresentationPurposes[purpose] =
      (providerPresentationPurposes[purpose] or 0) + 1
    providerPresentationLatestShiny[purpose] = mon.shiny == true
    if purpose == "title" then
      titlePresentationRequests[#titlePresentationRequests + 1] = {
        species = mon.species, shiny = mon.shiny == true,
      }
    end
    local key = purpose .. ":" .. mon.species
    if providerPresentationTokens[key]
        and providerPresentationTokens[key] ~= context.token then
      providerPresentationTokensStable = false
    end
    providerPresentationTokens[key] = providerPresentationTokens[key]
      or context.token
    if providerPresentationReturnsNil then return nil end
    local image = portraitImage
    if purpose == "title" then
      standaloneTitleArtCalls = standaloneTitleArtCalls + 1
      image = mon.species == "EEVEE" and titleSpriteImages[2]
        or titleSpriteImages[1]
    end
    return {
      image = image, trueColor = true, animated = true,
      mode = "animated", artSet = "gen5", frameIndex = 2,
    }
  end,
  resolvePokemonImage = function() error("Presentation API should win") end,
} }
game.mods.exports.gen1_battle_art_replacer = standaloneProvider
hudHook(function() end, game, {})
hudHook(function() end, game, {})
assert(standaloneBattleArtCalls > 0,
       "Pokemon details did not consult the standalone battle-art provider")
assert(providerPresentationPurposes.party and providerPresentationTokensStable,
       "Party did not retain a stable Battle Art presentation token")
providerPresentationReturnsNil = true
local beforeProviderOwnedFallback = battleArtCalls
hudHook(function() end, game, {})
assert(battleArtCalls == beforeProviderOwnedFallback,
       "provider-owned ROM/missing result leaked into legacy Battle Art")
providerPresentationReturnsNil = false

-- Non-opaque confirmation messages must retain the widescreen Party screen
-- underneath instead of restoring PartyMenu's native 160x144 draw.
local text = setmetatable({
  game = game,
  shown = { { 1, 2, 3, 4, 5 } },
  pages = { { "SPARK is now following you!" } },
  pageIndex = 1,
  lineIndex = 1,
  done = true,
  blink = 0,
}, TextBoxClass)
game.stack.states = { party, text }
text:draw()
assert(nativeTextDraws == 0,
       "native TextBox was not suppressed over widescreen Party")
local beforeText = draws
hudHook(function() end, game, {})
assert(draws > beforeText,
       "widescreen Party screen did not compose beneath TextBox")

-- Every normal caller constructs the same SummaryMenu module. Wrapping its
-- constructor therefore covers Party, PC/Box, scripts and other mods without
-- maintaining a fragile list of entry points.
local summary = SummaryMenu.new(game, party.party[1])
game.stack.states = { party, summary }
summary:draw()
local beforeSummary = draws
local shinyStarsBeforeSummary = shinyStarImageDraws
hudHook(function() end, game, {})
assert(draws > beforeSummary, "responsive stat screen did not draw")
assert(providerPresentationPurposes.summary,
       "stat screen did not use Battle Art Presentation API v1")
assert(shinyStarImageDraws == shinyStarsBeforeSummary + 1,
       "shiny Pokemon summary did not draw exactly one supplied star icon")

-- Evolution remains behavior-owned by the engine, but Widescreen owns its
-- final-resolution movie and resolves both alternating forms through the same
-- Battle Art Presentation API as Party and Summary.
local evolution = EvolutionState.new(game, party.party[1], "EEVEE")
game.stack.states = { evolution }
evolution:draw()
assert(nativeEvolutionDraws == 0,
       "native 160x144 evolution draw was not suppressed")
evolution:update(1 / 60)
assert(evolutionUpdateCalls == 1,
       "Widescreen evolution presentation replaced native update behavior")
local evolutionProviderBefore = providerPresentationPurposes.evolution or 0
hudHook(function() end, game, {})
assert((providerPresentationPurposes.evolution or 0) == evolutionProviderBefore + 1,
       "evolution old form did not use Battle Art Presentation API v1")
evolution.t = 28
hudHook(function() end, game, {})
assert((providerPresentationPurposes.evolution or 0) == evolutionProviderBefore + 2,
       "evolution new form did not use Battle Art Presentation API v1")

local standaloneEvolutionProvider = game.mods.exports.gen1_battle_art_replacer
local legacyEvolutionProvider = game.mods.exports.BATTLE_ART_VOXEL_FORK
game.mods.exports.gen1_battle_art_replacer = nil
game.mods.exports.BATTLE_ART_VOXEL_FORK = nil
local engineEvolutionBefore = engineEvolutionSpriteCalls
hudHook(function() end, game, {})
assert(engineEvolutionSpriteCalls == engineEvolutionBefore + 1,
       "evolution did not fall back to the active ROM front sprite")
game.mods.exports.gen1_battle_art_replacer = standaloneEvolutionProvider
game.mods.exports.BATTLE_ART_VOXEL_FORK = legacyEvolutionProvider

local evolutionText = setmetatable({
  game = game, shown = { { 1, 2, 3 } },
  pages = { { "Congratulations!" } }, pageIndex = 1, lineIndex = 1,
  done = true, blink = 0,
}, TextBoxClass)
evolution.done = true
game.stack.states = { evolution, evolutionText }
local beforeEvolutionText = draws
hudHook(function() end, game, {})
assert(draws > beforeEvolutionText,
       "evolution completion dialogue restored the native evolution screen")

-- Trainer Card keeps engine behavior/input but replaces the 160x144 draw with
-- a responsive card and the supplied eight-badge sheet.
game.save.money = 54321
game.save.playTime = 3723
game.save.inventory = { ITEM_B1 = 1, ITEM_B8 = 1 }
local trainerCard = TrainerCard.new(game)
game.stack.states = { trainerCard }
trainerCard:draw()
assert(nativeTrainerCardDraws == 0,
       "native 160x144 Trainer Card draw was not suppressed")
trainerCard:update(1 / 60)
assert(trainerCardUpdates == 1,
       "Widescreen Trainer Card replaced native input/update behavior")
local badgesBefore = trainerBadgeImageDraws
facesBefore = trainerFaceImageDraws
palettesBeforeTrainerCard = paletteDraws
hudHook(function() end, game, {})
assert(trainerBadgeImageDraws == badgesBefore + 8,
       "responsive Trainer Card did not draw all eight supplied badge sprites")
assert(trainerFaceImageDraws == facesBefore + 8,
       "responsive Trainer Card did not draw all eight native leader portraits")
assert(paletteDraws > palettesBeforeTrainerCard,
       "ROM Trainer Card portraits were not colorized through engine palettes")

registeredPortraits, portraitReason =
  mod.exports.registerTrainerCardPortraitProvider({
    owner = "character_fixture",
    apiVersion = 1,
    resolvePlayer = function(_, _, context)
      assert(context.kind == "player")
      return { image = trainerProviderPlayerImage, trueColor = true }
    end,
    resolveLeader = function(_, _, context)
      assert(context.kind == "leader")
      assert(context.trainerId and context.badgeIndex)
      return { image = trainerProviderLeaderImage, trueColor = true }
    end,
  })
assert(registeredPortraits and portraitReason == "registered")
assert(mod.exports.activeTrainerCardPortraitProviderOwner() == "character_fixture")
providerPlayerBefore = trainerProviderPlayerDraws
providerLeaderBefore = trainerProviderLeaderDraws
hudHook(function() end, game, {})
assert(trainerProviderPlayerDraws == providerPlayerBefore + 1,
       "Trainer Card portrait provider did not replace the player portrait")
assert(trainerProviderLeaderDraws == providerLeaderBefore + 8,
       "Trainer Card portrait provider did not replace all leader portraits")
assert(mod.exports.unregisterTrainerCardPortraitProvider("character_fixture"))
assert(mod.exports.activeTrainerCardPortraitProviderOwner() == nil)

summary = SummaryMenu.new(game, party.party[1])
game.stack.states = { party, summary }

summary.page = 2
local beforeMoves = draws
hudHook(function() end, game, {})
assert(draws > beforeMoves, "responsive stat moves page did not draw")

local summaryText = setmetatable({
  game = game,
  shown = { { 1, 2, 3 } },
  pages = { { "Summary message" } },
  pageIndex = 1,
  lineIndex = 1,
  done = true,
  blink = 0,
}, TextBoxClass)
game.stack.states = { party, summary, summaryText }
summaryText:draw()
assert(nativeTextDraws == 0,
       "native TextBox was not suppressed over widescreen Summary")
local beforeSummaryText = draws
hudHook(function() end, game, {})
assert(draws > beforeSummaryText,
       "widescreen Summary did not compose beneath TextBox")

-- Alpha 10 changes only Pokédex presentation. The native list's own update
-- method and data remain untouched, while list and entry states are redrawn.
-- Ordinary world dialogue is also presented at final resolution. Its native
-- update state remains authoritative, while the native 160x144 draw is
-- suppressed and the retained-line scroll countdown continues in the new
-- presenter. A YES/NO state stacked above it must remain responsive too.
local worldBase = { game = game }
worldBase.isOverworld = true
game.overworld = worldBase
game.stack.states = { worldBase }
local reflowedNpc = TextBoxClass.new(game,
  "You're making an\nencyclopedia on\vPOKEMON. That is a useful project.")
assert(reflowedNpc.__widescreenUiReflowed == true)
assert(#reflowedNpc.pages == 1 and #reflowedNpc.pages[1] <= 2,
       "wide NPC dialogue retained an obsolete continuation page")
assert(not reflowedNpc.pages.contBefore[1][2],
       "wide NPC dialogue retained an obsolete CONT button press")
assert(table.concat(reflowedNpc.pages[1], " "):find(
  "You're making an encyclopedia on POKEMON", 1, true),
  "wide NPC dialogue did not normalize native line markers")
local paragraphNpc = TextBoxClass.new(game, "FIRST PARAGRAPH.\fSECOND PARAGRAPH.")
assert(#paragraphNpc.pages == 2,
       "semantic paragraph/page boundary was removed")
game.stack.states = { menu }
local nonWorldText = TextBoxClass.new(game, "MENU\vMESSAGE")
assert(nonWorldText.__widescreenUiReflowed == nil,
       "non-overworld dialogue was repaginated")

local worldText = setmetatable({
  game = game,
  shown = { { 1, 2, 3 }, { 1, 2, 3, 4 } },
  pages = { { "OLD LINE", "NEW LINE" } },
  pageIndex = 1,
  lineIndex = 2,
  scrollPx = 8,
  waiting = true,
  blink = 0,
}, TextBoxClass)
local worldChoice = setmetatable({ game = game, index = 2 }, ChoiceBoxClass)
game.stack.states = { worldBase, worldText, worldChoice }
worldText:draw()
worldChoice:draw()
assert(nativeTextDraws == 0,
       "native TextBox was not suppressed over the overworld")
local beforeWorldDialogue = draws
hudHook(function() end, game, {})
assert(draws > beforeWorldDialogue,
       "responsive overworld dialogue did not draw")
assert(worldText.scrollPx == 6,
       "responsive dialogue did not preserve retained-line scrolling")
local foundYes, foundNo = false, false
for _, value in ipairs(printedTexts) do
  if value == "YES" then foundYes = true end
  if value == "NO" then foundNo = true end
end
assert(foundYes and foundNo,
       "responsive YES/NO choice labels were not drawn")

-- Normal world dialogue uses the same Nidoran/trainer gender symbols as the
-- battle presenter. They must be drawn as vectors with Pixelify Sans.
printedTexts = {}
beforeWorldGenderShapes = draws
worldText.pages = { { "TRAINER\226\153\130 met NIDORAN\226\153\128." } }
worldText.shown = { { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
  27, 28, 29, 30, 31, 32 } }
worldText.lineIndex = 1
hudHook(function() end, game, {})
assert(draws > beforeWorldGenderShapes,
       "world dialogue did not vector-render gender symbols")
worldGenderText = table.concat(printedTexts, "|")
assert(not worldGenderText:find("\226\153\128", 1, true)
       and not worldGenderText:find("\226\153\130", 1, true),
       "world dialogue passed unsupported gender glyphs to the font")

-- Disabling only the Widescreen presenter restores TextBox's captured native
-- draw. (The test harness shares one toggle value across all schema keys.)
optionEnabled = false
local beforeNativeDialogue = nativeTextDraws
worldText:draw()
assert(nativeTextDraws == beforeNativeDialogue + 1,
       "disabled dialogue option did not restore native TextBox drawing")
optionEnabled = true

local dex = PokedexMenuClass.new(game)
-- Reproduce an unmarked native ListMenu, as seen when another load order
-- constructs the screen before Widescreen wraps PokedexMenu.new.
dex.__widescreenUiPokedexRoot = nil
game.stack.states = { dex }
dex:update()
assert(dex.updateCalls == 1, "Pokedex navigation owner was replaced")
local beforeDex = draws
hudHook(function() end, game, {})
assert(draws > beforeDex, "responsive Pokedex list did not draw")
local dexEntry = setmetatable({
  game = game,
  def = {
    id = "BULBASAUR", name = "BULBASAUR", dex = 1,
    dexEntry = { kind = "SEED POKEMON", text = "DEX_BULBASAUR" },
  },
  forceOwned = true,
  sprite = portraitImage,
}, DexEntryMenuClass)
game.data.text = { DEX_BULBASAUR = "A strange seed was planted on its back." }
game.data.constants = { dexDigits = 3 }
game.stack.states = { dex, dexEntry }
local beforeEntry = draws
hudHook(function() end, game, {})
assert(draws > beforeEntry, "responsive Pokedex entry did not draw")
assert(providerPresentationPurposes.pokedex,
       "Pokedex entry did not use Battle Art Presentation API v1")
game.mods.exports.gen1_battle_art_replacer = nil
local beforeDexFallbackPalette = paletteDraws
hudHook(function() end, game, {})
assert(paletteDraws > beforeDexFallbackPalette,
       "native Pokedex fallback bypassed active colorization")
game.mods.exports.gen1_battle_art_replacer = standaloneProvider

-- BattleState opens a newly caught species as a standalone DexEntryMenu,
-- without a PokedexMenu root. That path must still use Widescreen.
game.stack.states = { { game = game, kind = "battle" }, dexEntry }
beforeCaughtEntry = draws
hudHook(function() end, game, {})
assert(draws > beforeCaughtEntry,
       "standalone post-capture Pokedex entry reverted to native UI")

-- Provider API v2 owns semantic snapshots and actions while Widescreen owns
-- every pixel, focus region and mapped input. No Pokedex+ adapter is involved.
assert(mod.exports.pokedexProviderApiVersion == 2)
local providerState = { game = game, kind = "future_pokedex" }
local actionCalls = {}
local currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = {
    { speciesId = "PIKACHU", number = "025", name = "PIKACHU",
      seen = true, owned = true, hidden = false },
    { speciesId = "EEVEE", number = "133", name = "?????",
      seen = false, owned = false, hidden = true },
  },
  selectedSpeciesId = "PIKACHU",
  counts = { seen = 1, owned = 1, total = 151 },
  detail = {
    speciesId = "PIKACHU", number = "025", name = "PIKACHU",
    kind = "MOUSE POKEMON", entry = "It keeps its tail raised to monitor its surroundings.",
    seen = true, owned = true, hidden = false,
    height = { metres = 0.4 }, weight = { kilograms = 6.0 },
    portrait = { kind = "pokemon", speciesId = "PIKACHU",
      side = "front", purpose = "pokedex", shiny = false },
  },
}
local providerActions = {}
for _, id in ipairs({ "up", "down", "pageUp", "pageDown", "select", "back",
                       "selectRow", "selectSubmenu", "scroll", "toggleShiny" }) do
  providerActions[id] = function(_, _, value)
    actionCalls[id] = (actionCalls[id] or 0) + 1
    actionCalls.lastValue = value
    return true
  end
end
local registered, registerReason = mod.exports.registerPokedexProvider({
  owner = "gen1_widescreen_pokedex", apiVersion = 2,
  match = function(state) return state.kind == "future_pokedex" end,
  snapshot = function() return currentSnapshot end,
  actions = providerActions,
})
assert(registered and registerReason == "registered")
assert(mod.exports.activePokedexProviderOwner() == "gen1_widescreen_pokedex")
local conflict = mod.exports.registerPokedexProvider({
  owner = "another_pokedex", apiVersion = 2,
  match = function() return false end, snapshot = function() return nil end,
  actions = {},
})
assert(not conflict, "competing Pokedex provider was accepted")
game.stack.states = { providerState }
local beforeProvider = draws
hudHook(function() end, game, {})
assert(draws > beforeProvider, "registered Pokedex v2 provider was not presented")
assert(providerPresentationPurposes.pokedex,
       "Pokedex v2 portrait did not use Battle Art Presentation API v1")

local pressed = { down = true }
game.input = { wasPressed = function(_, id) return pressed[id] == true end }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.down == 1, "mapped Pokedex down input was not dispatched")
pressed = { right = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.pageDown == 1, "mapped Pokedex page input was not dispatched")
pressed = { left = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.pageUp == 1, "mapped Pokedex page-up input was not dispatched")
pressed = { a = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.select == 1, "mapped Pokedex select input was not dispatched")
pressed = { b = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.back == 1, "mapped Pokedex back input was not dispatched")
pressed = {}

-- Pointer coordinates are physical-window units (the harness is 1920x1080,
-- exactly 3x the 640x360 design surface). Tap the second visible list row.
local pointerDownstream = 0
local consumed = pointerHook(function()
  pointerDownstream = pointerDownstream + 1
  return false
end, game, { phase = "pressed", source = "mouse", button = 1,
             x = 45 * 3, y = 100 * 3 })
assert(consumed and pointerDownstream == 0 and actionCalls.selectRow == 1
       and actionCalls.lastValue == 2,
       "Pokedex pointer row selection was not dispatched: consumed="
       .. tostring(consumed) .. " downstream=" .. tostring(pointerDownstream)
       .. " calls=" .. tostring(actionCalls.selectRow)
       .. " value=" .. tostring(actionCalls.lastValue))

-- Alpha 14.1 gives long main-entry text a bounded, presenter-owned five-line
-- viewport. SELECT focuses it without stealing normal provider navigation.
local providerMainSnapshot = currentSnapshot
providerMainSnapshot.detail.entry = table.concat({
  "ENTRY_LINE_1", "ENTRY_LINE_2", "ENTRY_LINE_3", "ENTRY_LINE_4",
  "ENTRY_LINE_5", "ENTRY_LINE_6", "ENTRY_LINE_7", "ENTRY_LINE_8",
}, "\n")
local function printedHas(value)
  for _, printed in ipairs(printedTexts) do
    if printed == value then return true end
  end
  return false
end
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("ENTRY_LINE_1") and printedHas("ENTRY_LINE_5")
       and not printedHas("ENTRY_LINE_6"),
       "long Pokedex entry did not open at the bounded first five lines")
local providerDownBeforeEntry = actionCalls.down
pressed = { select = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
       "SELECT did not focus the long Pokedex entry")
for _ = 1, 3 do
  pressed = { down = true }
  assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
         "focused Pokedex entry did not consume downward scrolling")
end
assert(actionCalls.down == providerDownBeforeEntry,
       "focused Pokedex entry leaked Down to species-list navigation")
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("ENTRY_LINE_4") and printedHas("ENTRY_LINE_8")
       and not printedHas("ENTRY_LINE_3"),
       "final wrapped Pokedex entry line was not reachable")
pressed = { down = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("ENTRY_LINE_4") and printedHas("ENTRY_LINE_8"),
       "Pokedex entry viewport was not clamped at its lower bound")
pressed = { left = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("ENTRY_LINE_1") and not printedHas("ENTRY_LINE_6"),
       "Pokedex entry viewport was not clamped at its upper bound")
pressed = { a = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
       "A did not leave Pokedex entry focus")

-- The clickable lower affordance uses the same local scroll path.
printedTexts = {}
hudHook(function() end, game, {})
consumed = pointerHook(function() return false end, game,
  { phase = "pressed", source = "mouse", button = 1,
    x = 602 * 3, y = 285 * 3 })
assert(consumed, "Pokedex entry scroll affordance did not consume pointer input")
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("ENTRY_LINE_2") and printedHas("ENTRY_LINE_6"),
       "Pokedex entry pointer affordance did not advance one line")
pressed = { b = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
       "B did not leave pointer-entered Pokedex entry focus")

-- A different species starts at line one and a short entry exposes no focus
-- path. Ordinary Down input therefore returns to the provider unchanged.
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = { { speciesId = "EEVEE", number = "133", name = "EEVEE",
    seen = true, owned = true, hidden = false } },
  selectedSpeciesId = "EEVEE",
  counts = { seen = 2, owned = 2, total = 151 },
  detail = { speciesId = "EEVEE", number = "133", name = "EEVEE",
    kind = "EVOLUTION POKEMON", entry = "SHORT_ENTRY",
    seen = true, owned = true, hidden = false,
    portrait = { kind = "pokemon", speciesId = "EEVEE",
      side = "front", purpose = "pokedex", shiny = false } },
}
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("SHORT_ENTRY") and not printedHas("ENTRY_LINE_2"),
       "new species inherited the previous Pokedex entry offset")
pressed = { select = true }
assert(not mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
       "short Pokedex entry exposed a misleading focus path")
pressed = { down = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(actionCalls.down == providerDownBeforeEntry + 1,
       "short-entry Down input did not preserve species-list navigation")
pressed = {}

-- Alpha 14.2 draws real gender symbols without asking Pixelify Sans for its
-- missing glyphs, and accepts an owned-only provider shiny presentation.
local genericToggleShiny = providerActions.toggleShiny
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = {
    { speciesId = "NIDORAN_F", number = "029", name = "NIDORAN♀",
      seen = true, owned = true, hidden = false },
    { speciesId = "NIDORAN_M", number = "032", name = "NIDORAN♂",
      seen = true, owned = true, hidden = false },
  },
  selectedSpeciesId = "NIDORAN_F",
  counts = { seen = 2, owned = 2, total = 151 },
  detail = {
    speciesId = "NIDORAN_F", number = "029", name = "NIDORAN♀",
    kind = "POISON PIN POKEMON",
    entry = table.concat({
      "SHINY_ENTRY_1", "SHINY_ENTRY_2", "SHINY_ENTRY_3", "SHINY_ENTRY_4",
      "SHINY_ENTRY_5", "SHINY_ENTRY_6", "SHINY_ENTRY_7", "SHINY_ENTRY_8",
    }, "\n"),
    seen = true, owned = true, hidden = false,
    portrait = { kind = "pokemon", speciesId = "NIDORAN_F",
      side = "front", purpose = "pokedex", shinyAvailable = true,
      shiny = false },
  },
}
providerActions.toggleShiny = function()
  actionCalls.toggleShiny = (actionCalls.toggleShiny or 0) + 1
  currentSnapshot.detail.portrait.shiny =
    not currentSnapshot.detail.portrait.shiny
  return true
end
local genderLinesBefore = statusMarkLines
local shinyStarsBefore = shinyStarImageDraws
printedTexts = {}
hudHook(function() end, game, {})
assert(statusMarkLines >= genderLinesBefore + 6,
       "NIDORAN gender symbols were not drawn in both rows and detail")
assert(providerPresentationLatestShiny.pokedex == false
       and printedHas("SELECT SHINY     START ENTRY     A DETAILS")
       and not printedHas("SELECT: SHINY"),
       "normal owned-shiny control was not footer-only")
assert(shinyStarImageDraws == shinyStarsBefore,
       "normal Pokedex portrait drew an active-shiny star")
pressed = { select = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(currentSnapshot.detail.portrait.shiny == true,
       "Select did not dispatch the provider shiny toggle")
printedTexts = {}
hudHook(function() end, game, {})
assert(providerPresentationLatestShiny.pokedex == true
       and printedHas("SELECT NORMAL     START ENTRY     A DETAILS")
       and not printedHas("SELECT: NORMAL"),
       "shiny portrait or footer-only normal control was incorrect")
assert(shinyStarImageDraws == shinyStarsBefore + 1,
       "active shiny Pokedex portrait did not draw exactly one gold star")
local shinyFixture = currentSnapshot
currentSnapshot = providerMainSnapshot
hudHook(function() end, game, {})
assert(shinyStarImageDraws == shinyStarsBefore + 1,
       "changing species retained the previous active-shiny star")
currentSnapshot = shinyFixture
hudHook(function() end, game, {})
assert(shinyStarImageDraws == shinyStarsBefore + 2,
       "returning to the active shiny species did not restore its star")
pressed = { select = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
assert(currentSnapshot.detail.portrait.shiny == false,
       "second Select did not restore the normal Pokedex portrait")
hudHook(function() end, game, {})
assert(shinyStarImageDraws == shinyStarsBefore + 2,
       "normal toggle retained the active-shiny star")

currentSnapshot.detail.portrait.shiny = true
currentSnapshot.submenu = {
  selectedIndex = 1,
  rows = {
    { id = "habitat", label = "HABITAT" },
    { id = "stats", label = "STATS" },
    { id = "learnset", label = "LEARNSET" },
    { id = "evolution", label = "EVOLUTION" },
    { id = "cry", label = "CRY", action = true },
  },
}
hudHook(function() end, game, {})
assert(shinyStarImageDraws == shinyStarsBefore + 2,
       "Pokedex submenu leaked the active-shiny star")
currentSnapshot.submenu = nil
currentSnapshot.detail.portrait.shiny = false
hudHook(function() end, game, {})
assert(shinyStarImageDraws == shinyStarsBefore + 2,
       "closing the Pokedex submenu retained the active-shiny star")

-- START is the unambiguous controller focus gesture when Select owns shiny.
pressed = { start = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60),
       "START did not focus a long shiny-capable entry")
for _ = 1, 3 do
  pressed = { down = true }
  assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
end
printedTexts = {}
hudHook(function() end, game, {})
assert(printedHas("SHINY_ENTRY_8"),
       "shiny Select mapping made the final long-entry line unreachable")
pressed = { b = true }
assert(mod.exports.updatePokedexProviderInput(game, providerState, 1 / 60))
providerActions.toggleShiny = genericToggleShiny
pressed = {}
currentSnapshot = providerMainSnapshot

currentSnapshot.submenu = {
  selectedIndex = 1,
  rows = {
    { id = "habitat", label = "HABITAT" },
    { id = "stats", label = "STATS" },
    { id = "learnset", label = "LEARNSET" },
    { id = "evolution", label = "EVOLUTION" },
    { id = "cry", label = "CRY", action = true },
  },
}
hudHook(function() end, game, {})
consumed = pointerHook(function() return false end, game,
  { phase = "pressed", source = "touch", x = 410 * 3, y = 145 * 3 })
assert(consumed and actionCalls.selectSubmenu == 1
       and actionCalls.lastValue == 1,
       "Pokedex pointer submenu activation was not dispatched")
consumed = pointerHook(function() return false end, game,
  { phase = "pressed", source = "touch", x = 410 * 3, y = 260 * 3 })
assert(consumed and actionCalls.selectSubmenu == 2
       and actionCalls.lastValue == 5 and currentSnapshot.submenu ~= nil,
       "Pokedex CRY activation was not dispatched without closing submenu")

local researchFixtures = {
  {
    schemaVersion = 2, screen = "pokedex_habitat", title = "HABITAT",
    speciesId = "PIKACHU", number = "025", name = "PIKACHU",
    selectedIndex = 1, scroll = 0,
    rows = { { kind = "habitat", mapId = "VIRIDIAN_FOREST",
      mapName = "VIRIDIAN FOREST", method = "GRASS", minLevel = 3,
      maxLevel = 5, slotChance = 10, conditions = {} } },
  },
  {
    schemaVersion = 2, screen = "pokedex_stats", title = "STATS",
    speciesId = "PIKACHU", number = "025", name = "PIKACHU",
    selectedIndex = 1, scroll = 0, types = { { id = "ELECTRIC", name = "ELECTRIC" } },
    rows = { { kind = "stat", id = "hp", label = "HP", value = 35, display = "35" },
      { kind = "total", id = "total", label = "TOTAL", value = 300, display = "300" } },
  },
  {
    schemaVersion = 2, screen = "pokedex_learnset", title = "LEARNSET",
    speciesId = "PIKACHU", number = "025", name = "PIKACHU",
    selectedIndex = 2, scroll = 0,
    rows = { { kind = "section", id = "level", label = "LEVEL-UP MOVES" },
      { kind = "move", moveId = "THUNDERBOLT", moveName = "THUNDERBOLT",
        typeId = "ELECTRIC", levelLabel = "TM24", power = 95,
        accuracy = 100, pp = 15 } },
  },
  {
    schemaVersion = 2, screen = "pokedex_evolution", title = "EVOLUTION",
    speciesId = "PIKACHU", number = "025", name = "PIKACHU",
    selectedIndex = 1, scroll = 0,
    rows = { { kind = "evolution", targetSpeciesId = "RAICHU",
      targetName = "RAICHU", targetHidden = false,
      methodId = "ITEM", method = "USE THUNDER STONE" } },
  },
}
for _, fixture in ipairs(researchFixtures) do
  currentSnapshot = fixture
  local beforeResearch = draws
  hudHook(function() end, game, {})
  assert(draws > beforeResearch, fixture.screen .. " was not presented")
end

currentSnapshot = {
  schemaVersion = 2, screen = "pokedex_stats", title = "STATS",
  speciesId = "PIKACHU", number = "025", name = "PIKACHU",
  selectedIndex = 1, scroll = 0, gated = true,
  message = "RESEARCH DATA LOCKED - CATCH THIS POKEMON",
  rows = { { kind = "message", label = "RESEARCH DATA LOCKED" } },
}
local beforeGated = draws
hudHook(function() end, game, {})
assert(draws > beforeGated, "gated research state was not presented")

-- An unseen entry may carry placeholder strings, but its unknown portrait
-- must prevent any identifying Battle Art lookup.
local beforeUnknownPortrait = standaloneBattleArtCalls
local starsBeforePrivacy = shinyStarImageDraws
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = { { speciesId = "EEVEE", number = "133", name = "?????",
    seen = false, owned = false, hidden = true } },
  counts = { seen = 0, owned = 0, total = 151 },
  detail = { number = "133", seen = false, owned = false, hidden = true,
    portrait = { kind = "unknown" } },
}
hudHook(function() end, game, {})
assert(standaloneBattleArtCalls == beforeUnknownPortrait,
       "unseen Pokedex detail resolved identifying art")
assert(shinyStarImageDraws == starsBeforePrivacy,
       "unseen Pokedex detail leaked an active-shiny star")

local beforeUnownedPortrait = standaloneBattleArtCalls
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = { { speciesId = "EEVEE", number = "133", name = "EEVEE",
    seen = true, owned = false, hidden = false } },
  counts = { seen = 1, owned = 0, total = 151 },
  detail = { speciesId = "EEVEE", number = "133", name = "EEVEE",
    seen = true, owned = false, hidden = false,
    entry = "DATA UNKNOWN - CATCH THIS POKEMON",
    portrait = { kind = "pokemon", speciesId = "EEVEE", side = "front",
      purpose = "pokedex", shiny = false } },
}
hudHook(function() end, game, {})
assert(standaloneBattleArtCalls > beforeUnownedPortrait,
       "seen/unowned Pokedex detail did not draw its normal portrait")
assert(shinyStarImageDraws == starsBeforePrivacy,
       "seen/unowned Pokedex detail leaked an active-shiny star")
local validUnownedSnapshot = currentSnapshot
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex", title = "POKEDEX",
  selectedIndex = 1, scroll = 0,
  rows = { { speciesId = "EEVEE", number = "133", name = "EEVEE",
    seen = true, owned = false, hidden = false } },
  counts = { seen = 1, owned = 0, total = 151 },
  detail = { speciesId = "EEVEE", number = "133", name = "EEVEE",
    seen = true, owned = false, hidden = false, entry = "LOCKED",
    portrait = { kind = "pokemon", speciesId = "EEVEE", side = "front",
      purpose = "pokedex", shinyAvailable = true, shiny = false } },
}
local privacyErrorsBefore = #loggedErrors
hudHook(function() end, game, {})
assert(#loggedErrors == privacyErrorsBefore + 1,
       "seen/unowned detail was allowed to advertise shiny availability")
currentSnapshot = validUnownedSnapshot

local longMoves = { { kind = "section", id = "level", label = "LEVEL-UP MOVES" } }
for i = 1, 14 do
  longMoves[#longMoves + 1] = { kind = "move", moveId = "MOVE_" .. i,
    moveName = "LONG MOVE NAME " .. i, typeId = "NORMAL",
    levelLabel = tostring(i), power = 40 + i, accuracy = 100, pp = 20 }
end
currentSnapshot = {
  schemaVersion = 2, screen = "pokedex_learnset", title = "LEARNSET",
  speciesId = "PIKACHU", number = "025", name = "PIKACHU",
  selectedIndex = #longMoves, scroll = 0, rows = longMoves,
}
local beforeLongList = draws
hudHook(function() end, game, {})
assert(draws > beforeLongList, "long Pokedex research list did not render")

currentSnapshot = {
  schemaVersion = 2, screen = "pokedex_stats", title = "STATS",
  speciesId = "PIKACHU", number = "025", name = "PIKACHU",
  selectedIndex = 1, scroll = 0,
  rows = { { kind = "stat", id = "hp", label = "HP", value = "MALFORMED" } },
}
local beforeMalformed = #printedTexts
hudHook(function() end, game, {})
local foundDash = false
for i = beforeMalformed + 1, #printedTexts do
  if printedTexts[i] == "—" then foundDash = true break end
end
assert(foundDash, "malformed Pokedex stat was not rendered as an em dash")

-- A registered provider forces the presentation on even if the saved
-- Widescreen Pokedex toggle is disabled.
optionEnabled = false
local beforeForcedProvider = draws
hudHook(function() end, game, {})
assert(draws > beforeForcedProvider,
       "registered Pokedex provider did not force its presenter on")
optionEnabled = true

local actionErrorsBefore = #loggedErrors
providerActions.scroll = function() error("fixture action failure") end
assert(not mod.exports.invokePokedexProviderAction("scroll", game, providerState, 1))
assert(not mod.exports.invokePokedexProviderAction("scroll", game, providerState, 1))
assert(#loggedErrors == actionErrorsBefore + 1,
       "Pokedex action exception was not isolated and deduplicated")
providerActions.scroll = function() return true end

-- Invalid data never exposes a native layer: after one valid frame the last
-- valid immutable snapshot remains visible and one actionable error is logged.
currentSnapshot = { schemaVersion = 2, screen = "unsupported", rows = {},
  selectedIndex = 1 }
local beforeInvalid = draws
local errorsBeforeInvalid = #loggedErrors
hudHook(function() end, game, {})
assert(draws > beforeInvalid and #loggedErrors == errorsBeforeInvalid + 1,
       "invalid Pokedex snapshot was not isolated behind the last valid view")
assert(shinyStarImageDraws == starsBeforePrivacy,
       "provider-error Pokedex state leaked an active-shiny star")
assert(not mod.exports.invokePokedexProviderAction("missing", game, providerState),
       "unsupported Pokedex provider action did not fail safely")

assert(mod.exports.unregisterPokedexProvider("gen1_widescreen_pokedex"))
assert(mod.exports.activePokedexProviderOwner() == nil)

-- API v1 fixtures remain presentable for compatibility, while the published
-- version and all new dependent work target v2.
local legacyState = { game = game, kind = "legacy_pokedex" }
assert(mod.exports.registerPokedexProvider({
  owner = "legacy_fixture", apiVersion = 1,
  match = function(state) return state.kind == "legacy_pokedex" end,
  snapshot = function() return {
    schemaVersion = 1, screen = "pokedex", selectedIndex = 1,
    rows = { { number = "025", name = "PIKACHU", owned = true } },
  } end,
  actions = {},
}))
game.stack.states = { legacyState }
local beforeLegacy = draws
hudHook(function() end, game, {})
assert(draws > beforeLegacy, "Pokedex Provider API v1 compatibility regressed")
assert(mod.exports.unregisterPokedexProvider("legacy_fixture"))

-- Title menu, Continue summary and Load Report retain their native update
-- owners while Widescreen replaces only the final draw.
battleArtMode = "static"
titleRandomQueue = { 4, 1, 1, 64 }
titlePresentationRequests = {}
local title = setmetatable({
  game = game, title = { copyrightText = "TEST BUILD" },
  logo = portraitImage, player = portraitImage,
  blue = true, cycleSpecies = { "PIKACHU", "EEVEE" }, cycleIndex = 1,
}, TitleStateClass)
local titleMenu = setmetatable({
  game = game, titleUiBox = { 0, 0, 12, 9 }, index = 1,
  items = {
    { label = "CONTINUE" }, { label = "NEW GAME" },
    { label = "OPTION" }, { label = "EXIT GAME" },
  },
}, MenuClass)
game.stack.states = { title }
local beforeStandaloneTitle = draws
hudHook(function() end, game, {})
assert(draws > beforeStandaloneTitle,
       "first-frame title still fell back to the native 160x144 page")
assert(titlePresentationRequests[1]
       and titlePresentationRequests[1].species == "BLASTOISE"
       and titlePresentationRequests[1].shiny == false,
       "Blue title did not open on its normal box-art mascot")
game.stack.states = { title, titleMenu }
title:update()
assert(title.updateCalls == 1, "title animation/input owner was replaced")
titleMenu:draw()
assert(nativeTitleMenuDraws == 0, "native title menu fallback was still drawn")
local beforeTitle = draws
hudHook(function() end, game, {})
assert(draws > beforeTitle, "responsive main menu did not draw")
assert(paletteDraws > 1, "title art bypassed active colorization")
for frame = 1, 245 do
  titleAnimationFrame = frame
  hudHook(function() end, game, {})
end
titleAnimationFrame = nil
assert(titleSpriteIndices[2] and titleSpriteIndices[4],
       "title Pokemon did not cycle while the menu was open")
assert(#titleSpriteXs[1] > 1 and #titleSpriteXs[2] > 1,
       "title transition did not draw outgoing and incoming Pokemon")
local function extent(values)
  local lo, hi = values[1], values[1]
  for i = 2, #values do
    lo, hi = math.min(lo, values[i]), math.max(hi, values[i])
  end
  return lo, hi
end
local oldLo, oldHi = extent(titleSpriteXs[1])
local newLo, newHi = extent(titleSpriteXs[2])
assert(oldLo < oldHi, "outgoing title Pokemon did not slide left")
assert(newLo < newHi, "incoming title Pokemon did not slide in from the right")
assert(titleSpriteXs[1][1] >= 330,
       "title Pokemon still rests against the left edge of its art slot: "
       .. tostring(titleSpriteXs[1][1]))
local lastOld, firstNew
for frame = 1, 245 do
  local seen = titleSpriteFrames[frame] or {}
  assert(not (seen[1] and seen[2]),
         "vanilla title transition must not cross-fade both Pokemon")
  if seen[1] then lastOld = frame end
  if seen[2] and not firstNew then firstNew = frame end
end
assert(lastOld and firstNew and firstNew - lastOld >= 2,
       "vanilla one-frame blank pause between outgoing/incoming Pokemon is missing")
assert(standaloneTitleArtCalls > 0,
       "title Pokemon did not consult the standalone battle-art provider")
assert(providerPresentationPurposes.title and providerPresentationTokensStable,
       "title Pokemon did not retain per-species presentation tokens")
local sawRandomShiny = false
for _, request in ipairs(titlePresentationRequests) do
  if request.species == "EEVEE" and request.shiny then
    sawRandomShiny = true
    break
  end
end
assert(sawRandomShiny,
       "forced 1-in-64 title roll did not request a random shiny sprite")

-- The other versions use their own box-art mascot before random cycling.
local redTitle = setmetatable({
  game = game, title = { copyrightText = "TEST BUILD" },
  logo = portraitImage, player = portraitImage,
  cycleSpecies = { "PIKACHU", "EEVEE" }, cycleIndex = 1,
}, TitleStateClass)
local beforeRedRequest = #titlePresentationRequests
game.stack.states = { redTitle }
hudHook(function() end, game, {})
assert(titlePresentationRequests[beforeRedRequest + 1]
       and titlePresentationRequests[beforeRedRequest + 1].species == "CHARIZARD"
       and not titlePresentationRequests[beforeRedRequest + 1].shiny,
       "Red title did not open on its normal box-art mascot")
local yellowTitle = setmetatable({
  game = game, title = { copyrightText = "TEST BUILD" },
  logo = portraitImage, player = portraitImage,
  yellow = true, yellowLayout = true, phase = "loop",
  yellowPikachu = portraitImage,
  cycleSpecies = { "PIKACHU" }, cycleIndex = 1,
}, TitleStateClass)
local beforeYellowRequest = #titlePresentationRequests
game.stack.states = { yellowTitle }
hudHook(function() end, game, {})
assert(titlePresentationRequests[beforeYellowRequest + 1]
       and titlePresentationRequests[beforeYellowRequest + 1].species == "PIKACHU"
       and not titlePresentationRequests[beforeYellowRequest + 1].shiny,
       "Yellow title did not open on its normal box-art mascot")

-- If the modern still-image provider declines the title surface, preserve
-- Battle Art Voxel's selected animated atlas instead of freezing its sprite.
game.mods.exports.gen1_battle_art_replacer = nil
battleArtMode = "animated"
local animatedTitle = setmetatable({
  game = game, title = { copyrightText = "TEST BUILD" },
  logo = portraitImage, player = portraitImage,
  cycleSpecies = { "PIKACHU", "EEVEE" }, cycleIndex = 1,
}, TitleStateClass)
game.stack.states = { animatedTitle }
local beforeAnimatedTitle = animatedBattleArtCalls
local beforeAnimatedTitleDraws = animatedTitleDraws
hudHook(function() end, game, {})
hudHook(function() end, game, {})
assert(animatedBattleArtCalls > beforeAnimatedTitle,
       "title Pokemon did not advance Battle Art Voxel animation")
assert(animatedTitleDraws > beforeAnimatedTitleDraws,
       "title Pokemon did not draw the animated Battle Art frame")
game.mods.exports.gen1_battle_art_replacer = standaloneProvider
battleArtMode = "static"

local continueInfo = {
  game = game, title = title,
  save = {
    player = { name = "INVOKER" }, pokedex = { owned = { PIKACHU = true } },
    playTime = 7380,
  },
}
game.stack.states = { title, continueInfo }
local beforeContinue = draws
hudHook(function() end, game, {})
assert(draws > beforeContinue, "responsive Continue summary did not draw")

local report = setmetatable({
  game = game, offset = 0,
  report = {
    lostItems = { { id = "OLD_ITEM", count = 2 } },
    remappedMaps = { { id = "OLD_MAP", to = "PALLET_TOWN" } },
    modsDiff = { added = { "A" }, removed = { "B" }, changed = { "C" } },
  },
  lines = { "ITEMS REMOVED", " OLD_ITEM x2" },
}, QuarantineReportClass)
game.stack.states = { report }
report:update()
assert(report.updateCalls == 1, "Load Report input owner was replaced")
local beforeReport = draws
hudHook(function() end, game, {})
assert(draws > beforeReport, "responsive Load Report did not draw")
local printed = table.concat(printedTexts, "\n")
assert(printed:find("This save was made with 34 mods", 1, true),
       "Load Report omitted the saved-mod total row")
assert(printed:find("12 are no longer active", 1, true)
    and printed:find("3 changed version", 1, true)
    and printed:find("5 newly active", 1, true),
       "Load Report did not split mod changes into independent rows")
assert(not printed:find("mods; 12", 1, true),
       "Load Report retained the compact semicolon statement")

-- Options keeps its native semantic rows and update owner, while Widescreen
-- presents more rows and a contextual value/help panel at final resolution.
local options = setmetatable({
  game = game, index = 2, scroll = 0,
  rows = {
    { id = "textSpeed", label = "TEXT SPEED",
      value = function() return "FAST" end, step = function() return true end },
    { id = "battleStyle", label = "BATTLE STYLE",
      value = function() return "SET" end, step = function() return true end },
    { id = "mods", label = "MODS", value = function() return "34 INSTALLED" end,
      activate = function() end },
    { id = "thirdParty", label = "MOD OPTION",
      value = function() return "ENABLED" end, step = function() return true end },
  },
}, OptionsMenuClass)
game.stack.states = { options }
options:update()
assert(options.updateCalls == 1, "Options input/update owner was replaced")
options:draw()
assert(nativeOptionsDraws == 0, "native Options fallback was still drawn")
local beforeOptions = draws
hudHook(function() end, game, {})
assert(draws > beforeOptions, "responsive Options menu did not draw")
local optionsText = table.concat(printedTexts, "\n")
assert(optionsText:find("BATTLE STYLE", 1, true)
    and optionsText:find("SET", 1, true)
    and optionsText:find("LEFT / RIGHT CHANGE", 1, true),
       "Options contextual parameter panel omitted selected-row data")
optionEnabled = false
options:draw()
assert(nativeOptionsDraws == 1,
       "disabled Widescreen Options did not restore the native draw")
optionEnabled = true

-- The manager and its per-mod schema screen share the responsive chrome while
-- retaining ManagerState's own navigation, staging and option callbacks.
managedMod = {
  id = "example_mod", name = "EXAMPLE MOD", version = "1.2.3",
  category = "UI", enabled = true, staged = true,
  description = "An example mod used to verify responsive manager details.",
}
disabledManagedMod = {
  id = "disabled_mod", name = "DISABLED MOD", version = "1.0.0",
  category = "UI", enabled = false,
}
manager = setmetatable({
  game = game, screen = "list", tab = 1, cursor = 2, scroll = 1,
  testRows = {
    { header = true, label = "UI" },
    { mod = managedMod, label = "EXAMPLE MOD", glyph = "." },
    { mod = disabledManagedMod, label = "DISABLED MOD", glyph = " " },
  },
}, ManagerStateClass)
game.stack.states = { manager }
manager:update()
assert(manager.updateCalls == 1, "Mod Manager update owner was replaced")
manager:draw()
assert(nativeManagerDraws == 0, "native Mod Manager fallback was still drawn")
beforeManager = draws
beforeStatusMarks = statusMarkLines
hudHook(function() end, game, {})
assert(draws > beforeManager, "responsive Mod Manager did not draw")
assert(statusMarkLines - beforeStatusMarks >= 4,
       "Mod Manager omitted enabled checkmark or disabled X")
manager.screen = "options"
manager.currentMod = managedMod
manager.cursor = 1
manager.optionRows = {
  { id = "enabled", label = "EXAMPLE SETTING",
    value = function() return "ON" end, step = function() return true end },
  { id = "__reset", label = "RESET DEFAULTS", value = function() return "" end,
    activate = function() end },
}
beforeModOptions = draws
hudHook(function() end, game, {})
assert(draws > beforeModOptions, "responsive per-mod Options did not draw")
managerText = table.concat(printedTexts, "\n")
assert(managerText:find("EXAMPLE MOD OPTIONS", 1, true)
    and managerText:find("EXAMPLE SETTING", 1, true),
       "per-mod Options omitted its mod title or semantic row")
optionEnabled = false
manager:draw()
assert(nativeManagerDraws == 1,
       "disabled Widescreen manager did not restore native draw")
optionEnabled = true

-- New Game keeps OakSpeech/NamingScreen as the semantic owners while the
-- Widescreen pass draws the extracted FRLG characters and Battle Art demo.
oakPicImage = { getDimensions = function() return 56, 56 end,
  setFilter = function() end }
demoPicImage = { getDimensions = function() return 56, 56 end,
  setFilter = function() end }
playerPicImage = { getDimensions = function() return 56, 56 end,
  setFilter = function() end }
rivalPicImage = { getDimensions = function() return 56, 56 end,
  setFilter = function() end }
oakSpeech = setmetatable({
  game = game, pic = oakPicImage, oakPic = oakPicImage,
  playerPic = playerPicImage, rivalPic = rivalPicImage,
  demoPic = demoPicImage, demoSpecies = "NIDORINO",
}, OakSpeechClass)
game.stack.states = { oakSpeech }
oakSpeech:update()
assert(oakSpeech.updateCalls == 1, "OakSpeech native update owner was replaced")
oakBuiltSteps=oakSpeech:buildSteps()
assert(#oakBuiltSteps==2 and oakBuiltSteps[1].id=="legend"
    and oakBuiltSteps[2].id=="shrink",
       "Oak hard-mode inquiry was not removed")
oakSpeech:draw()
assert(nativeOakDraws == 0, "native OakSpeech draw was not suppressed")
hudHook(function() end, game, {})
oakSpeech.shrink={frame=0}; oakSpeech.updateCalls=0
oakSpeech.__widescreenFadeToHouse=239
oakSpeech:update()
assert(oakSpeech.updateCalls==0 and oakSpeech.shrink.frame==0,
       "extended fade advanced native shrink frames")
oakSpeech:update()
assert(oakSpeech.updateCalls==1 and oakSpeech.shrink.frame==102,
       "extended fade did not hand completion back to OakSpeech")
oakSpeech.shrink=nil
game.stack.states={oakSpeech}
oakSpeech:finish()
introFadeState=game.stack:top()
assert(oakSpeech.finished and introFadeState~=oakSpeech,
       "house fade-in was not pushed after OakSpeech completion")
assert(introFadeState.duration==90,
       "house fade-in does not last 1.5 seconds")
introFadeState.frame=89
introFadeState:update()
assert(game.stack:top()~=introFadeState,
       "house fade-in did not release player control after 90 frames")
game.stack.states={oakSpeech}
oakSpeech.pic = demoPicImage
hudHook(function() end, game, {})
assert((providerPresentationPurposes.oak_speech or 0) > 0,
       "Oak demo Pokemon did not use the Battle Art presentation API")
providerPresentationReturnsNil = true
hudHook(function() end, game, {})
providerPresentationReturnsNil = false

oakNaming = setmetatable({ game = game, title = "YOUR NAME?",
  row = 1, col = 2, name = "RED" }, NamingScreenClass)
oakNameMenu = setmetatable({ game = game, index = 1,
  items = { { label = "NEW NAME" }, { label = "RED" } } }, MenuClass)
game.stack.states = { oakSpeech, oakNaming, oakNameMenu }
oakNaming:update()
assert(oakNaming.updateCalls == 1, "NamingScreen native update owner was replaced")
beforeOakNameMenuNative = nativeTitleMenuDraws
oakNaming:draw()
oakNameMenu:draw()
assert(nativeNamingDraws == 0 and nativeTitleMenuDraws == beforeOakNameMenuNative,
       "native Oak naming presentation was still drawn")
hudHook(function() end, game, {})
loadedIntroAssets = table.concat(modAssetImageCalls, "\n")
assert(loadedIntroAssets:find("assets/intro_oak_frlg.png", 1, true)
    and loadedIntroAssets:find("assets/intro_red_frlg.png", 1, true)
    and loadedIntroAssets:find("assets/intro_rival_frlg.png", 1, true),
       "New Game did not load all extracted FRLG character assets")

-- Bag Provider API v1 has deterministic one-owner registration, immutable
-- semantic snapshots, forced presentation, native suppression and action
-- parity through the exported dispatcher.
assert(mod.exports.bagProviderApiVersion == 2
    and mod.exports.bagProviderCompatibleApiVersions[1]
    and mod.exports.bagProviderCompatibleApiVersions[2],
       "Bag Provider API version was not published")
bagActionCalls = {}
bagState = setmetatable({ game=game, providerBag=true }, ListMenuClass)
bagSnapshot = {
  schemaVersion=1, screen="bag", mode="field", title="BAG",
  pockets={ {id="medicine",label="MEDICINE",enabled=true},
    {id="balls",label="BALLS",enabled=true} },
  selectedPocketId="medicine", selectedIndex=1, scroll=0, money=2541,
  rows={ {itemId="POTION",label="POTION",count=4,enabled=true,
    favorite=true,pinned=false,category="medicine",
    description="Restores HP.",icon={image=portraitImage}} },
  hints="A SELECT   B BACK",
}
bagProviderSpec = { owner="modern_bag_test",apiVersion=1,
  match=function(state) return state.providerBag==true end,
  snapshot=function() return bagSnapshot end,
  actions=setmetatable({}, {__index=function(_,action)
    return function(_,_,value)
      bagActionCalls[#bagActionCalls+1]={action=action,value=value}
      return true
    end
  end}) }
bagProviderSpec.actions.select=function()
  bagActionCalls[#bagActionCalls+1]={action="select"}; return true end
bagProviderSpec.actions.back=function()
  bagActionCalls[#bagActionCalls+1]={action="back"}; return true end
bagProviderSpec.actions.up=function()
  bagActionCalls[#bagActionCalls+1]={action="up"}; return true end
bagProviderSpec.actions.down=function()
  bagActionCalls[#bagActionCalls+1]={action="down"}; return true end
bagProviderSpec.actions.pocketLeft=function()
  bagActionCalls[#bagActionCalls+1]={action="pocketLeft"}; return true end
bagProviderSpec.actions.pocketRight=function()
  bagActionCalls[#bagActionCalls+1]={action="pocketRight"}; return true end
assert(mod.exports.registerBagProvider(bagProviderSpec)==true,
       "Bag provider registration failed")
assert(mod.exports.activeBagProviderOwner()=="modern_bag_test")
assert(select(2,mod.exports.registerBagProvider({owner="competitor",apiVersion=1,
  match=function() return true end,snapshot=function() return bagSnapshot end,
  actions={}})):find("already owned",1,true),
       "competing Bag owner was not rejected")
game.stack.states={bagState}
bagState:draw()
assert(nativeListDraws==0,"native Bag layer was not suppressed")
hudHook(function() end,game,{})
assert(mod.exports.invokeBagProviderAction("select",game,bagState)==true
    and bagActionCalls[#bagActionCalls].action=="select",
       "Bag action dispatcher failed")
bagSnapshot.rows[1].count=math.huge
loggedBeforeInvalid=#loggedErrors
hudHook(function() end,game,{})
hudHook(function() end,game,{})
assert(#loggedErrors==loggedBeforeInvalid+1,
       "invalid Bag snapshot error was not deduplicated")
bagSnapshot.rows[1].count=4
assert(mod.exports.unregisterBagProvider("modern_bag_test")==true)

bagV2Calls={}
bagV2State=setmetatable({game=game,providerBagV2=true},ListMenuClass)
bagV2Snapshot={schemaVersion=2,screen="search",mode="field",title="SEARCH",
  pockets={{id="all",label="ALL",enabled=true}},selectedPocketId="all",
  selectedIndex=1,scroll=0,rows={{itemId="POTION",label="POTION",count=4,
    enabled=true,favorite=false,pinned=false,category="medicine"}},
  search={query="",keyboard={columns=3,selectedIndex=1,selectedKeyId="a",
    keys={{id="a",label="A",value="A"},{id="b",label="B",value="B"},
      {id="delete",label="DEL",action="delete"}}}}}
bagV2Actions=setmetatable({}, {__index=function(_,action)
  return function(_,_,value)
    bagV2Calls[#bagV2Calls+1]={action=action,value=value}; return true
  end
end})
assert(mod.exports.registerBagProvider({owner="modern_bag_v2_test",apiVersion=2,
  match=function(state)return state.providerBagV2==true end,
  snapshot=function()return bagV2Snapshot end,actions=bagV2Actions})==true,
  "Bag Provider API v2 registration failed")
game.stack.states={bagV2State}
hudHook(function()end,game,{})
bagV2TypeIndex=1
while bagV2TypeIndex<=12 do
  assert(mod.exports.routeBagProviderText(game,bagV2State,"A")==true)
  bagV2TypeIndex=bagV2TypeIndex+1
end
assert(#bagV2Calls==12 and bagV2Calls[12].action=="textInput"
    and bagV2Calls[12].value=="A",
  "physical 12-character Bag query was not routed")
assert(mod.exports.routeBagProviderKey(game,bagV2State,"backspace")==true
    and bagV2Calls[#bagV2Calls].action=="delete",
  "Bag search Backspace was not routed")
love.keyboard.isDown=function(key)return key=="lctrl" end
assert(mod.exports.routeBagProviderKey(game,bagV2State,"delete")==true
    and bagV2Calls[#bagV2Calls].action=="clear",
  "Bag search clear chord was not routed")
love.keyboard.isDown=function()return false end
pressed={a=true}; bagV2State:update()
assert(bagV2Calls[#bagV2Calls].action=="keyboardKey"
    and bagV2Calls[#bagV2Calls].value=="a",
  "controller activation did not call the semantic keyboard key")
pressed={left=true}; bagV2State:update()
assert(bagV2Calls[#bagV2Calls].action=="left",
  "search Left was incorrectly presented as a pocket change")
bagV2Snapshot.screen="bag"; bagV2Snapshot.search=nil
hudHook(function()end,game,{})
pressed={left=true}; bagV2State:update()
assert(bagV2Calls[#bagV2Calls].action=="pocketLeft",
  "main Bag Left did not retain pocket navigation")

-- Optional v2 machine detail is presenter-owned and uses authoritative
-- provider strings. Every scalar occupies its own line; DESCRIPTION is the
-- only measured multiline field and must not be sent through ellipsis.
bagV2Snapshot.rows[1].detail={kind="machine",typeId="NORMAL",parameters={
  {label="MOVE",value="Bide"},{label="CATEGORY",value="Physical"},
  {label="POWER",value="--"},{label="ACCURACY",value="Varies"},
  {label="PP",value="10"},{label="DESCRIPTION",value=
    "The user endures attacks for two turns, then strikes back with twice the damage received."},
}}
printedTexts={}
hudHook(function()end,game,{})
machineDetailText=table.concat(printedTexts,"\n")
assert(machineDetailText:find("MOVE:",1,true)
    and machineDetailText:find("CATEGORY:",1,true)
    and machineDetailText:find("ACCURACY:",1,true)
    and machineDetailText:find("DESCRIPTION:",1,true)
    and machineDetailText:find("twice the damage",1,true)
    and machineDetailText:find("received.",1,true)
    and not machineDetailText:find("..",1,true),
  "structured machine detail did not render complete multiline parameters: "
    ..machineDetailText)
bagV2Snapshot.rows[1].detail.parameters[1].value=string.rep("X",129)
loggedBeforeMachineDetail=#loggedErrors
hudHook(function()end,game,{});hudHook(function()end,game,{})
assert(#loggedErrors==loggedBeforeMachineDetail+1,
  "invalid structured machine detail was not opaque and deduplicated")
bagV2Snapshot.rows[1].detail=nil
bagV2Snapshot.screen="item_options"
bagV2Snapshot.item={selectedIndex=2,selectedId="pin",options={
  {id="use",label="USE"},{id="pin",label="PIN"}}}
beforeBagModal=draws; hudHook(function()end,game,{})
assert(draws>beforeBagModal,"focused Bag modal was not rendered")
bagV2Snapshot.screen="machine_filter"; bagV2Snapshot.item=nil
bagV2Snapshot.machineFilter={selectedIndex=1,selectedId="missing",
  rows={{id="all",label="ALL"},{id="water",label="WATER"}}}
loggedBeforeBadGrid=#loggedErrors
hudHook(function()end,game,{}); hudHook(function()end,game,{})
assert(#loggedErrors==loggedBeforeBadGrid+1,
  "invalid v2 modal schema was not opaque and deduplicated")
assert(mod.exports.unregisterBagProvider("modern_bag_v2_test")==true)

-- Pokemon Storage Provider API v1: Widescreen owns the grid, Party drawer,
-- detail, popup, semantic input and pointer hit regions while the provider
-- remains the only mutation authority.
assert(mod.exports.pokemonStorageProviderApiVersion==1,
  "Pokemon Storage Provider API v1 was not published")
storageState={game=game,providerStorage=true,
  draw=function() error("native provider storage draw leaked") end,
  update=function() error("native provider storage update leaked") end}
storageCalls={}
storageSnapshot={schemaVersion=1,screen="move",title="MOVE POKEMON",
  selectedRegion="grid",box={viewedIndex=1,activeIndex=1,occupancy=1,capacity=20},
  grid={columns=5,rows=4,selectedIndex=1,cells={}},
  party={open=true,selectedIndex=1,slots={}},
  partyButton={label="PARTY",selected=false,enabled=true},
  detail={identityToken="stored-1",speciesId="PIKACHU",name="SPARK",
    speciesName="PIKACHU",nicknamed=true,gender="female",
    level=25,hp=61,maxHp=72,shiny=true,status="OK",
    stats={hp=72,attack=44,defense=35,speed=61,special=50},
    types={"ELECTRIC"},moves={{name="THUNDERBOLT",pp=15,maxPp=15}},
    presentation={species="PIKACHU",nickname="SPARK",level=25,hp=61,
      stats={hp=72},shiny=true}},
  popup={title="ACTIONS",selectedIndex=1,rows={
    {id="move",label="MOVE",enabled=true},{id="cancel",label="CANCEL",enabled=true}}},
  statusText="Choose a Pokemon.",hints="A SELECT   B BACK   L/R BOX"}
for i=1,20 do storageSnapshot.grid.cells[i]=i==1 and {
  identityToken="stored-1",speciesId="PIKACHU",name="SPARK",enabled=true,
  state="held_origin",icon={image=externalIconImage},
  presentation={species="PIKACHU",shiny=true}}
  or {empty=true,state=i==2 and "valid_target" or "empty"} end
for i=1,6 do storageSnapshot.party.slots[i]=i==1 and {
  identityToken="party-1",speciesId="EEVEE",name="EEVEE",enabled=true,
  icon={image=externalIconImage},presentation={species="EEVEE"}}
  or {empty=true} end
storageActions={}
storageSnapshotCalls=0
for _,action in ipairs({"up","down","left","right","previousBox","nextBox",
    "select","back","selectCell","selectPartySlot","selectPopup"}) do
  storageActions[action]=function(_,_,value)
    storageCalls[#storageCalls+1]={action=action,value=value}; return true end
end
storageActions.selectPartyButton=function(_,_,value)
  storageCalls[#storageCalls+1]={action="selectPartyButton",value=value}; return true end
assert(mod.exports.registerPokemonStorageProvider({owner="grid_box_test",apiVersion=1,
  match=function(state)return state.providerStorage==true end,
  snapshot=function()storageSnapshotCalls=storageSnapshotCalls+1;return storageSnapshot end,
  actions=storageActions})==true,
  "Pokemon Storage provider registration failed")
assert(mod.exports.activePokemonStorageProviderOwner()=="grid_box_test")
assert(select(2,mod.exports.registerPokemonStorageProvider({owner="competitor",
  apiVersion=1,match=function()return true end,snapshot=function()return storageSnapshot end,
  actions=storageActions})):find("already owned",1,true),
  "competing Pokemon Storage owner was not rejected")
game.stack.states={storageState}; printedTexts={}; storageStarsBefore=shinyStarImageDraws
assert(screenVisibleHook(function()return true end,storageState)==false,
  "provider-owned Pokemon Storage state was not hidden from native rendering")
hudHook(function()end,game,{})
storageText=table.concat(printedTexts,"\n")
assert(storageText:find("MOVE POKEMON",1,true)
    and storageText:find("BOX 01",1,true)
    and storageText:find("ACTIVE",1,true)
    and storageText:find("PARTY",1,true)
    and storageText:find("ACTIONS",1,true)
    and storageText:find("PIKACHU",1,true),
  "Pokemon Storage active badge/detail/grid/Party/popup were not composed")
assert(shinyStarImageDraws==storageStarsBefore+1,
  "shiny selected storage detail did not draw one star")
assert((providerPresentationPurposes.storage or 0)>0,
  "selected storage portrait did not use Battle Art Presentation API v1")
storageText=setmetatable({game=game,shown={{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}},
  pages={{"STORAGE MESSAGE"}},pageIndex=1,lineIndex=1,done=true,blink=0},TextBoxClass)
storageChoice=setmetatable({game=game,index=1},ChoiceBoxClass)
game.stack.states={storageState,storageText,storageChoice}; printedTexts={}
hudHook(function()end,game,{})
storageOverlayText=table.concat(printedTexts,"\n")
assert(storageOverlayText:find("MOVE POKEMON",1,true)
    and storageOverlayText:find("STORAGE MESSAGE",1,true)
    and storageOverlayText:find("YES",1,true),
  "Pokemon Storage TextBox/ChoiceBox did not compose over the opaque grid")
storageSummary=SummaryMenu.new(game,storageSnapshot.detail.presentation)
storageSnapshotBeforeSummary=storageSnapshotCalls
game.stack.states={storageState,storageSummary}; hudHook(function()end,game,{})
assert(storageSnapshotCalls==storageSnapshotBeforeSummary,
  "Pokemon Summary did not remain an opaque destination above storage")
game.stack.states={storageState}
assert(mod.exports.invokePokemonStorageProviderAction("selectCell",game,storageState,1)
    and storageCalls[#storageCalls].action=="selectCell",
  "Pokemon Storage semantic action dispatch failed")
pressed={right=true}; mod.exports.updatePokemonStorageProviderInput(game,storageState,0)
assert(storageCalls[#storageCalls].action=="right",
  "Pokemon Storage controller input did not route semantically")
assert(storageSnapshot.box.activeIndex==1,
  "presenter input incorrectly changed the active capture Box")
assert(mod.exports.routePokemonStorageProviderKey(game,storageState,"pageup")
    and storageCalls[#storageCalls].action=="previousBox",
  "Pokemon Storage keyboard input did not route semantically")
storagePointerFellThrough=false
assert(game.stack:top()==storageState
    and mod.exports.activePokemonStorageProviderOwner()=="grid_box_test",
  "Pokemon Storage pointer fixture lost provider focus")
hudHook(function()end,game,{})
storagePointerFellThrough=false
assert(pointerHook~=nil,"Pokemon Storage pointer hook was not registered")
assert(type(storageState.__widescreenStorageHitRegions)=="table"
    and #storageState.__widescreenStorageHitRegions>=30,
  "Pokemon Storage hit regions were not retained after redraw")
love.graphics.getDimensions=function()return 640,360 end
assert((function()local a,b=love.graphics.getDimensions();return a==640 and b==360 end)(),
  "Pokemon Storage pointer fixture did not set design dimensions")
assert(mod.exports.invokePokemonStorageProviderAction~=nil)
assert(type(storageState.__widescreenStorageHitRegions[#storageState.__widescreenStorageHitRegions].action)=="string")
storagePopupRegion=nil
storagePartyButtonRegion=nil
for _,storageRegion in ipairs(storageState.__widescreenStorageHitRegions) do
  if storageRegion.action=="selectPopup" and storageRegion.value==1 then
    storagePopupRegion=storageRegion; break
  elseif storageRegion.action=="selectPartyButton" then
    storagePartyButtonRegion=storageRegion
  end
end
assert(storagePopupRegion,"Pokemon Storage popup pointer region is missing")
assert(storagePartyButtonRegion,"Pokemon Storage PARTY pointer region is missing")
assert(storagePopupRegion.w>0 and storagePopupRegion.h>0,
  "Pokemon Storage popup pointer region has invalid geometry")
assert(storagePopupRegion.x+2>=storagePopupRegion.x
    and storagePopupRegion.x+2<=storagePopupRegion.x+storagePopupRegion.w,
  "Pokemon Storage popup pointer probe is outside its region")
storagePointerHandled=mod.exports.routePokemonStorageProviderPointer(game,storageState,{
  phase="pressed",source="mouse",button=1,
  x=storagePartyButtonRegion.x+storagePartyButtonRegion.w/2,
  y=storagePartyButtonRegion.y+storagePartyButtonRegion.h/2})
love.graphics.getDimensions=function()return 1920,1080 end
assert(storageCalls[#storageCalls].action=="selectPartyButton"
    and storagePointerHandled==true,
  "Pokemon Storage pointer did not select the semantic PARTY button: "
    ..tostring(storageCalls[#storageCalls].action).."/"
    ..tostring(storageCalls[#storageCalls].value).."/"
    ..tostring(storagePointerHandled))
love.graphics.getDimensions=function()return 960,540 end
storageTouchHandled=mod.exports.routePokemonStorageProviderPointer(game,storageState,{
  phase="pressed",source="touch",
  x=(storagePartyButtonRegion.x+storagePartyButtonRegion.w/2)*1.5,
  y=(storagePartyButtonRegion.y+storagePartyButtonRegion.h/2)*1.5})
assert(storageTouchHandled==true
    and storageCalls[#storageCalls].action=="selectPartyButton",
  "Pokemon Storage touch routing failed at a non-integer host scale")
storageActions.selectPartyButton=nil
love.graphics.getDimensions=function()return 640,360 end
assert(mod.exports.routePokemonStorageProviderPointer(game,storageState,{
  phase="pressed",source="mouse",button=1,
  x=storagePartyButtonRegion.x+2,y=storagePartyButtonRegion.y+2})==true
    and storageCalls[#storageCalls].action=="select",
  "legacy v1 provider did not fall back from PARTY pointer activation to select")
love.graphics.getDimensions=function()return 1920,1080 end
storageSnapshot.box.activeIndex=2; printedTexts={}; hudHook(function()end,game,{})
assert(not table.concat(printedTexts,"\n"):find("ACTIVE",1,true),
  "inactive viewed Box incorrectly drew the ACTIVE badge")
storageSnapshot.box.activeIndex=1
storageSnapshot.grid.selectedIndex=2
storageSnapshot.grid.cells[2].state="invalid_target"
storageSnapshot.grid.cells[2].enabled=false
storageSnapshot.grid.cells[2].disabledReason="Dense tail is unavailable."
printedTexts={}; hudHook(function()end,game,{})
assert(table.concat(printedTexts,"\n"):find("Dense tail is unavailable.",1,true),
  "disabled grid target reason was not presented")
storageSnapshot.grid.selectedIndex=1
storageSnapshot.selectedRegion="party"
storageSnapshot.party.slots[2]={empty=true,state="invalid_target",enabled=false,
  disabledReason="The last healthy party Pokemon cannot be deposited."}
storageSnapshot.party.selectedIndex=2; printedTexts={}; hudHook(function()end,game,{})
assert(table.concat(printedTexts,"\n"):find("last healthy",1,true),
  "disabled Party target reason was not presented")
storageSnapshot.selectedRegion="popup"; storageSnapshot.popup.selectedIndex=2
storageSnapshot.popup.rows[2].enabled=false
storageSnapshot.popup.rows[2].disabledReason="Finish moving the held Pokemon first."
printedTexts={}; hudHook(function()end,game,{})
assert(table.concat(printedTexts,"\n"):find("Finish moving",1,true),
  "disabled popup reason was not presented")
storageSnapshot.selectedRegion="grid"; storageSnapshot.party.selectedIndex=1
storageSnapshot.party.slots[2]={empty=true}; storageSnapshot.popup.selectedIndex=1
storageSnapshot.popup.rows[2].enabled=true
storageSnapshot.popup.rows[2].disabledReason=nil
for _,storageAction in ipairs({"up","down","left","right","previousBox",
    "nextBox","select","back","selectCell","selectPartySlot","selectPopup"}) do
  assert(mod.exports.invokePokemonStorageProviderAction(
    storageAction,game,storageState,1)==true
    and storageCalls[#storageCalls].action==storageAction,
    "Pokemon Storage action parity failed for "..storageAction)
end
storageSnapshot.box.capacity=19; storageLoggedBefore=#loggedErrors
hudHook(function()end,game,{}); hudHook(function()end,game,{})
assert(#loggedErrors==storageLoggedBefore+1,
  "invalid Pokemon Storage snapshot was not retained and deduplicated")
storageSnapshot.box.capacity=20
assert(mod.exports.unregisterPokemonStorageProvider("wrong")==nil,
  "non-owner unregistration unexpectedly removed Pokemon Storage provider")
assert(mod.exports.unregisterPokemonStorageProvider("grid_box_test")==true)
assert(mod.exports.activePokemonStorageProviderOwner()==nil)

-- With no expanded provider, the engine's own kind=bag ListMenu receives the
-- Widescreen style while preserving native update/actions and modal behavior.
vanillaBag=setmetatable({game=game,kind="bag",title="ITEMS",index=1,scroll=0,
  items={{value="POTION",label="POTION",right="x4"}}},ListMenuClass)
game.data.items={POTION={name="POTION",description="Restores HP."}}
game.save.inventory={POTION=4}
game.save.money=2541
game.stack.states={vanillaBag}
beforeNativeBagDraw=nativeListDraws
vanillaBag:draw()
assert(nativeListDraws==beforeNativeBagDraw,
       "native vanilla Bag draw was not suppressed")
hudHook(function() end,game,{})
assert(table.concat(printedTexts,"\n"):find("Restores 20 HP",1,true),
       "vanilla Bag did not derive the canonical Potion description")

-- The complete native PC session is presentation-only: engine Menu/List/
-- Quantity/Choice update paths remain authoritative while every PC layer is
-- suppressed and redrawn on the responsive surface.
game.save.party={{species="PIKACHU"}}
game.save.boxes={{}}
game.save.currentBox=1
pcMenu=PlayerPC.new(game)
assert(pcMenu.__widescreenUiPcRoot==true,
       "Player PC constructor was not marked as a presentation root")
game.stack.states={pcMenu}
beforePcNative=nativeTitleMenuDraws
pcMenu:draw()
assert(nativeTitleMenuDraws==beforePcNative,
       "native Player PC root was not suppressed")
printedTexts={}
hudHook(function() end,game,{})
assert(table.concat(printedTexts,"\n"):find("PC STORAGE",1,true)
    and table.concat(printedTexts,"\n"):find("WITHDRAW ITEM",1,true),
       "responsive Player PC presenter was not drawn")
boxMenu=BoxMenu.new(game)
assert(boxMenu.__widescreenUiPcRoot==true,
       "Box PC constructor was not marked as a presentation root")
game.stack.states={boxMenu}
boxMenu:draw()
printedTexts={}
hudHook(function() end,game,{})
boxRootText=table.concat(printedTexts,"\n")
assert(boxRootText:find("CHANGE BOX",1,true),
       "responsive Box PC presenter was not drawn")
assert(boxRootText:find("WITHDRAW POKEMON",1,true)
    and not boxRootText:find("<PK>",1,true),
       "Box PC control tags leaked into the Widescreen labels")

-- A selected Box Pokemon keeps the list as the primary screen, uses the
-- compact Battle-Art portrait/stat detail, and draws its native action Menu
-- as a bottom-right popup rather than replacing the complete PC page.
game.save.boxes={{ {species="PIKACHU",nickname="SPARK",level=25,hp=61,
  stats={hp=72,attack=44,defense=35,speed=61,special=50},moves={}} }}
boxList=setmetatable({game=game,title="BOX 1 (WITHDRAW)",index=1,scroll=0,
  items={{label="SPARK :L25",value=1}}},ListMenuClass)
boxActions=setmetatable({game=game,index=1,items={{label="WITHDRAW"},
  {label="STATS"},{label="CANCEL"}}},MenuClass)
game.stack.states={boxMenu,boxList,boxActions}
printedTexts={}
hudHook(function() end,game,{})
boxActionText=table.concat(printedTexts,"\n")
assert(boxActionText:find("BOX 1 (WITHDRAW)",1,true)
    and boxActionText:find("ACTIONS",1,true)
    and boxActionText:find("ATK",1,true)
    and boxActionText:find("44",1,true),
       "Box Pokemon detail/action popup was not composed over its list")
pcStarsBefore=shinyStarImageDraws
game.save.boxes[1][1].shiny=true
hudHook(function()end,game,{})
assert(shinyStarImageDraws==pcStarsBefore+1,
  "shiny Box Pokemon did not draw exactly one PC detail star with popup open")
game.save.boxes[1][1].shiny=false
hudHook(function()end,game,{})
assert(shinyStarImageDraws==pcStarsBefore+1,
  "normal Box Pokemon incorrectly drew a PC detail star")
game.save.boxes[1][1].shiny=nil
game.save.boxes[1][1].dvs="shiny"
hudHook(function()end,game,{})
assert(shinyStarImageDraws==pcStarsBefore+2,
  "native shiny DVs did not draw the PC detail star")
game.save.boxes[1][1].dvs=nil

-- Item storage rows may also use numeric-looking indices, but DEPOSIT ITEM
-- must never resolve those rows against party slots or draw Pokemon details.
itemDeposit=setmetatable({game=game,title="DEPOSIT ITEM",index=1,scroll=0,
  items={{label="ANTIDOTE",value="ANTIDOTE",right="x4"}}},ListMenuClass)
game.stack.states={pcMenu,itemDeposit}
printedTexts={}
hudHook(function() end,game,{})
itemDepositText=table.concat(printedTexts,"\n")
assert(itemDepositText:find("ANTIDOTE",1,true)
    and not itemDepositText:find("ATK",1,true)
    and not itemDepositText:find("NIDORINO",1,true),
       "DEPOSIT ITEM leaked party Pokemon detail presentation")

-- Summary is an opaque destination, even when a PC root remains beneath it.
-- It must take presentation ownership so STATS does more than play a cry.
pcSummary=SummaryMenu.new(game,game.save.boxes[1][1])
game.stack.states={boxMenu,boxList,boxActions,pcSummary}
printedTexts={}
hudHook(function() end,game,{})
assert(table.concat(printedTexts,"\n"):find("POKEMON SUMMARY",1,true),
       "PC STATS destination was swallowed by the PC presenter")

-- Native PC error/confirmation text remains the semantic owner and must be
-- visible. This covers empty boxes, full parties, release/change-box prompts,
-- and Professor Oak's PC dialogue while retaining their original callbacks.
pcNotice=setmetatable({game=game,shown={{1,2,3,4,5,6,7,8,9,10,11}},
  pages={{"The party is full!"}},pageIndex=1,lineIndex=1,done=true,blink=0},
  TextBoxClass)
game.stack.states={boxMenu,pcNotice}
printedTexts={}
hudHook(function() end,game,{})
assert(table.concat(printedTexts,"\n"):find("The party",1,true),
       "PC TextBox context was hidden behind the PC presenter: "
         ..table.concat(printedTexts,"|"))

print("start_menu_test: OK")
