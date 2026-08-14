-- Widescreen Modern Bag core
-- Version 0.1.0-alpha.5
-- Pure inventory semantics. This module performs no drawing and never invokes
-- item effects.

local Core={}

Core.POCKETS={
  {id="medicine",label="MEDICINE"},
  {id="balls",label="POKE BALLS"},
  {id="machines",label="TM / HM"},
  {id="battle",label="BATTLE ITEMS"},
  {id="key",label="KEY ITEMS"},
  {id="items",label="ITEMS"},
}
Core.DEFAULT_POCKET="medicine"
Core.SORT_MODES={"alphabetical","type","quantity"}
Core.MAX_SAFE_STACK=9007199254740991
Core.MAX_DISTINCT_ITEMS=2147483647

local MEDICINE={
  POTION=true,SUPER_POTION=true,HYPER_POTION=true,MAX_POTION=true,
  FULL_RESTORE=true,ANTIDOTE=true,BURN_HEAL=true,ICE_HEAL=true,
  AWAKENING=true,PARLYZ_HEAL=true,PARALYZE_HEAL=true,FULL_HEAL=true,
  REVIVE=true,MAX_REVIVE=true,FRESH_WATER=true,SODA_POP=true,LEMONADE=true,
  ETHER=true,MAX_ETHER=true,ELIXER=true,MAX_ELIXER=true,
  ELIXIR=true,MAX_ELIXIR=true,HP_UP=true,PROTEIN=true,IRON=true,
  CALCIUM=true,CARBOS=true,RARE_CANDY=true,PP_UP=true,
}
local BALLS={MASTER_BALL=true,ULTRA_BALL=true,GREAT_BALL=true,
  POKE_BALL=true,SAFARI_BALL=true}
local BATTLE={X_ATTACK=true,X_DEFEND=true,X_DEFENSE=true,X_SPEED=true,
  X_SPECIAL=true,X_ACCURACY=true,DIRE_HIT=true,GUARD_SPEC=true,POKE_DOLL=true}
local ITEMS={REPEL=true,SUPER_REPEL=true,MAX_REPEL=true,ESCAPE_ROPE=true,
  LEAF_STONE=true,FIRE_STONE=true,WATER_STONE=true,THUNDER_STONE=true,
  MOON_STONE=true,HELIX_FOSSIL=true,DOME_FOSSIL=true,OLD_AMBER=true,NUGGET=true}
local PHYSICAL_TYPES={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,
  GROUND=true,ROCK=true,BUG=true,GHOST=true}

local HEAL_HP={POTION=true,SUPER_POTION=true,HYPER_POTION=true,MAX_POTION=true,
  FULL_RESTORE=true,FRESH_WATER=true,SODA_POP=true,LEMONADE=true}
local HEAL_STATUS={ANTIDOTE=true,BURN_HEAL=true,ICE_HEAL=true,AWAKENING=true,
  PARLYZ_HEAL=true,PARALYZE_HEAL=true,FULL_HEAL=true}
local REVIVAL={REVIVE=true,MAX_REVIVE=true}
local RESTORE_PP={ETHER=true,MAX_ETHER=true,ELIXER=true,MAX_ELIXER=true,
  ELIXIR=true,MAX_ELIXIR=true,PP_UP=true}
local VITAMINS={HP_UP=true,PROTEIN=true,IRON=true,CALCIUM=true,CARBOS=true}
local STONES={LEAF_STONE=true,FIRE_STONE=true,WATER_STONE=true,
  THUNDER_STONE=true,MOON_STONE=true}
local FOSSILS={HELIX_FOSSIL=true,DOME_FOSSIL=true,OLD_AMBER=true}
local REPELS={REPEL=true,SUPER_REPEL=true,MAX_REPEL=true}
local RODS={OLD_ROD=true,GOOD_ROD=true,SUPER_ROD=true}

local DESCRIPTIONS={
  POKE_BALL="A capsule thrown at wild Pokemon to capture and safely store them.",
  GREAT_BALL="A high-performance Ball with a higher catch rate than a standard Poke Ball.",
  ULTRA_BALL="An ultra-performance Ball with a higher catch rate than a Great Ball.",
  MASTER_BALL="The ultimate Ball. It catches any wild Pokemon without fail.",
  SAFARI_BALL="A special Ball used in the Safari Zone to catch wild Pokemon.",
  BICYCLE="A folding bicycle that lets you travel faster than walking.",
  BIKE_VOUCHER="A voucher that can be exchanged for a Bicycle at the Cerulean Bike Shop.",
  CARD_KEY="A card-shaped key that opens the electronic doors in Silph Co.",
  COIN_CASE="A case used to hold coins won or purchased at the Game Corner.",
  DOME_FOSSIL="The fossil of an ancient Pokemon that lived in the sea long ago.",
  EXP_ALL="Shares experience points with every Pokemon in the party.",
  FIRE_STONE="A peculiar stone that evolves certain Pokemon. It has a fiery orange center.",
  GOLD_TEETH="A set of gold dentures lost by the Safari Zone Warden.",
  GOOD_ROD="A decent fishing rod used to catch Pokemon in bodies of water.",
  HELIX_FOSSIL="The fossil of an ancient Pokemon that lived in the sea long ago.",
  ITEMFINDER="A device that reacts when a hidden item is nearby.",
  LEAF_STONE="A peculiar stone that evolves certain Pokemon. It has an unmistakable leaf pattern.",
  LIFT_KEY="A key that operates the elevator in Team Rocket's hideout.",
  MOON_STONE="A strange stone that evolves certain Pokemon. It is dark like the night sky.",
  OAKS_PARCEL="A parcel from Viridian City's Poke Mart that must be delivered to Professor Oak.",
  OAK_PARCEL="A parcel from Viridian City's Poke Mart that must be delivered to Professor Oak.",
  PARCEL="A parcel from Viridian City's Poke Mart that must be delivered to Professor Oak.",
  OLD_AMBER="A piece of amber containing the genes of an ancient Pokemon.",
  OLD_ROD="An old fishing rod used to catch Pokemon in bodies of water.",
  POKE_FLUTE="A flute with a lovely tone that wakes sleeping Pokemon.",
  SECRET_KEY="A key that opens the locked entrance to the Cinnabar Gym.",
  SILPH_SCOPE="A scope that makes otherwise invisible Ghost Pokemon identifiable.",
  S_S_TICKET="A ticket required to board the S.S. Anne in Vermilion City.",
  SS_TICKET="A ticket required to board the S.S. Anne in Vermilion City.",
  SUPER_ROD="An excellent fishing rod used to catch powerful Pokemon in bodies of water.",
  THUNDER_STONE="A peculiar stone that evolves certain Pokemon. It has a distinct thunderbolt pattern.",
  TOWN_MAP="A convenient map that shows towns, cities and routes across Kanto.",
  WATER_STONE="A peculiar stone that evolves certain Pokemon. It is the blue of a clear pool.",
  POTION="Restores 20 HP to one Pokemon.",
  SUPER_POTION="Restores 50 HP to one Pokemon.",
  HYPER_POTION="Restores 200 HP to one Pokemon.",
  MAX_POTION="Fully restores one Pokemon's HP.",
  FULL_RESTORE="Fully restores HP and cures status conditions.",
  ANTIDOTE="Cures poison.",BURN_HEAL="Cures a burn.",ICE_HEAL="Thaws a frozen Pokemon.",
  AWAKENING="Wakes a sleeping Pokemon.",PARLYZ_HEAL="Cures paralysis.",
  PARALYZE_HEAL="Cures paralysis.",FULL_HEAL="Cures all status conditions.",
  REVIVE="Revives a fainted Pokemon with half of its HP.",
  MAX_REVIVE="Revives a fainted Pokemon with all of its HP.",
  FRESH_WATER="Restores 50 HP to one Pokemon.",
  SODA_POP="Restores 60 HP to one Pokemon.",LEMONADE="Restores 80 HP to one Pokemon.",
  ETHER="Restores 10 PP to one move.",MAX_ETHER="Fully restores PP to one move.",
  ELIXER="Restores 10 PP to every move.",MAX_ELIXER="Fully restores PP to every move.",
  ELIXIR="Restores 10 PP to every move.",MAX_ELIXIR="Fully restores PP to every move.",
  HP_UP="Raises a Pokemon's HP potential.",PROTEIN="Raises Attack potential.",
  IRON="Raises Defense potential.",CALCIUM="Raises Special potential.",
  CARBOS="Raises Speed potential.",PP_UP="Raises the maximum PP of one move.",
  RARE_CANDY="Raises one Pokemon by one level.",
  REPEL="Keeps weaker wild Pokemon away for 100 steps.",
  SUPER_REPEL="Keeps weaker wild Pokemon away for 200 steps.",
  MAX_REPEL="Keeps weaker wild Pokemon away for 250 steps.",
  ESCAPE_ROPE="Returns you to safety from many caves and dungeons.",
  POKE_DOLL="Can help escape from a wild Pokemon battle.",
  X_ATTACK="Raises Attack during battle.",X_DEFEND="Raises Defense during battle.",
  X_DEFENSE="Raises Defense during battle.",X_SPEED="Raises Speed during battle.",
  X_SPECIAL="Raises Special during battle.",X_ACCURACY="Raises accuracy during battle.",
  DIRE_HIT="Raises the chance of critical hits during battle.",
  GUARD_SPEC="Protects against stat reductions during battle.",
  NUGGET="A valuable item that can be sold for a high price.",
}

-- Concise original wording based on Pokemon Database's Generation I move
-- index and move pages, adjusted where early-generation behavior differs.
local MOVE_DESCRIPTIONS={
  MEGA_PUNCH="The user delivers a powerful punch.",
  RAZOR_WIND="The user whips up a cutting wind, then attacks on the next turn.",
  SWORDS_DANCE="A vigorous dance sharply raises the user's Attack.",
  WHIRLWIND="Blows away a wild Pokemon to end the battle. It fails in Trainer battles.",
  MEGA_KICK="The user launches an extremely powerful kick.",
  TOXIC="Badly poisons the target, causing increasing damage each turn.",
  HORN_DRILL="A drilling horn attack that knocks out the target if it hits.",
  BODY_SLAM="The user drops its full body onto the target and may cause paralysis.",
  TAKE_DOWN="A reckless full-body charge that also hurts the user.",
  DOUBLE_EDGE="A dangerous, powerful tackle that also hurts the user.",
  BUBBLE_BEAM="A forceful stream of bubbles that may lower the target's Speed.",
  BUBBLEBEAM="A forceful stream of bubbles that may lower the target's Speed.",
  WATER_GUN="The user blasts the target with a strong jet of water.",
  ICE_BEAM="An icy beam that may freeze the target.",
  BLIZZARD="A fierce snowstorm that may freeze the target.",
  HYPER_BEAM="A devastating beam. The user recharges next turn unless it knocks out the target.",
  PAY_DAY="Scatters coins while attacking. The coins are collected as money after battle.",
  SUBMISSION="A reckless fighting tackle that also hurts the user.",
  COUNTER="Returns twice the damage from the last Normal- or Fighting-type attack received.",
  SEISMIC_TOSS="Throws the target and deals damage equal to the user's level.",
  RAGE="Locks the user into repeated attacks. Its Attack rises whenever it is hit.",
  MEGA_DRAIN="Drains the target's energy and restores half the damage dealt as HP.",
  SOLAR_BEAM="Absorbs sunlight on the first turn, then fires a powerful beam on the next.",
  SOLARBEAM="Absorbs sunlight on the first turn, then fires a powerful beam on the next.",
  DRAGON_RAGE="Unleashes a shock wave that always deals exactly 40 HP of damage.",
  THUNDERBOLT="A strong electric blast that may paralyze the target.",
  THUNDER="A massive lightning strike that may paralyze the target.",
  EARTHQUAKE="A powerful quake that strikes the target from beneath.",
  FISSURE="Opens a deep fissure that knocks out the target if it hits.",
  DIG="The user burrows underground, then attacks on the next turn. It can also escape caves.",
  PSYCHIC="A powerful psychic attack that may lower the target's Special.",
  TELEPORT="Escapes from a wild battle. Outside battle, it returns to the last Pokemon Center.",
  MIMIC="Copies one of the target's moves for the rest of the battle.",
  DOUBLE_TEAM="Creates copies of the user to raise its evasiveness.",
  REFLECT="Creates a barrier that halves physical damage until the user leaves battle.",
  BIDE="The user endures attacks for 2 to 3 turns, then returns twice the damage taken.",
  METRONOME="Waggles a finger and uses almost any move at random.",
  SELF_DESTRUCT="The user explodes in a powerful attack, then faints.",
  SELFDESTRUCT="The user explodes in a powerful attack, then faints.",
  EGG_BOMB="Throws a large egg at the target with great force.",
  FIRE_BLAST="Engulfs the target in an intense fire blast that may cause a burn.",
  SWIFT="Fires star-shaped rays that ignore accuracy and evasiveness.",
  SKULL_BASH="Lowers the head on the first turn, then charges the target on the next.",
  SOFT_BOILED="Restores half of the user's maximum HP.",
  SOFTBOILED="Restores half of the user's maximum HP.",
  DREAM_EATER="Steals energy from a sleeping target and restores half the damage dealt as HP.",
  SKY_ATTACK="Prepares on the first turn, then launches a powerful flying attack on the next.",
  REST="Fully restores HP and cures status conditions, but puts the user to sleep for two turns.",
  THUNDER_WAVE="Sends a weak electric charge that paralyzes the target.",
  PSYWAVE="Attacks with an odd psychic wave whose damage varies with the user's level.",
  EXPLOSION="The user causes a huge explosion, then faints.",
  ROCK_SLIDE="Drops large rocks onto the target.",
  TRI_ATTACK="Fires three simultaneous beams at the target.",
  SUBSTITUTE="Uses one quarter of the user's maximum HP to create a decoy that takes hits.",
  CUT="Slashes the target with claws or blades. It can also cut small trees outside battle.",
  FLY="Flies high on the first turn, then strikes on the next. It also enables air travel.",
  SURF="Attacks with a powerful wave. It also carries the player across water.",
  STRENGTH="Strikes with tremendous force. It can also move heavy boulders outside battle.",
  FLASH="Creates a bright flash that lowers the target's accuracy and lights dark caves.",
}

local function finite(value)
  return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function integer(value) return finite(value) and value%1==0 end
local function upper(value) return tostring(value or ""):upper() end

function Core.normalized(value)
  return upper(value):gsub("Ã‰","E"):gsub("Ã©","E"):gsub("[^A-Z0-9]","")
end

function Core.safeCount(value)
  value=tonumber(value)
  if not finite(value) or value<=0 then return 0 end
  value=math.floor(value)
  return math.min(value,Core.MAX_SAFE_STACK)
end

function Core.pocketFor(id,def,overrides)
  def=type(def)=="table" and def or {}
  if type(def.machine)=="table" then return "machines" end
  if def.ball==true or BALLS[id] then return "balls" end
  local wanted=type(overrides)=="table" and overrides[id] or nil
  if wanted=="medicine" or wanted=="balls" or wanted=="machines"
      or wanted=="battle" or wanted=="key" or wanted=="items" then return wanted end
  if MEDICINE[id] then return "medicine" end
  if BATTLE[id] then return "battle" end
  if ITEMS[id] then return "items" end
  local effect=upper(def.effect or def.useEffect or def.effectId)
  local category=upper(def.category or def.pocket)
  if category=="MEDICINE" or category=="HEALING" then return "medicine" end
  if category=="BALL" or category=="BALLS" then return "balls" end
  if category=="BATTLE" then return "battle" end
  if effect:find("BALL",1,true) then return "balls" end
  if effect:find("HEAL",1,true) or effect:find("REVIVE",1,true)
      or effect:find("ETHER",1,true) or effect:find("ELIX",1,true)
      or effect:find("VITAMIN",1,true) or effect:find("PP_UP",1,true)
      or effect:find("CANDY",1,true) then return "medicine" end
  if def.keyItem==true or def.tossable==false then return "key" end
  return "items"
end

function Core.moveDamageClass(move)
  move=type(move)=="table" and move or {}
  local power=tonumber(move.power) or 0
  if not finite(power) or power<=0 then return "Status" end
  return PHYSICAL_TYPES[upper(move.type)] and "Physical" or "Special"
end

local function machineCode(id,def)
  local machine=type(def)=="table" and def.machine or {}
  local kind=upper(machine.kind)
  if kind~="TM" and kind~="HM" then kind=upper(tostring(id):match("^(%a%a)")) end
  if kind~="TM" and kind~="HM" then kind="TM" end
  local number=tonumber(machine.number) or tonumber(tostring(id):match("(%d+)$"))
  number=integer(number) and number or 999
  return kind..(number<100 and ("%02d"):format(number) or tostring(number)),kind,number
end

local function readableEffect(value)
  local text=upper(value)
  if text=="" or text=="NO_ADDITIONAL_EFFECT" then return nil end
  text=text:gsub("_EFFECT$",""):gsub("_"," "):lower()
  return text:sub(1,1):upper()..text:sub(2).."."
end

function Core.moveDescription(moveId,move)
  move=type(move)=="table" and move or {}
  local description=MOVE_DESCRIPTIONS[upper(moveId)]
    or move.description or move.desc or readableEffect(move.effect)
  if type(description)=="string" and description~="" then return description end
  return Core.moveDamageClass(move)=="Status"
    and "The user performs a status technique."
    or "The user attacks the target with this move."
end

function Core.machineInfo(game,id,def)
  def=type(def)=="table" and def or game and game.data and game.data.items and game.data.items[id]
  if type(def)~="table" or type(def.machine)~="table" then return nil end
  local moveId=def.machine.move
  local move=game and game.data and game.data.moves and game.data.moves[moveId]
  move=type(move)=="table" and move or {}
  local code,kind,number=machineCode(id,def)
  local power=tonumber(move.power) or 0;if not finite(power) then power=0 end
  local accuracy=tonumber(move.accuracy);if not finite(accuracy) then accuracy=nil end
  local pp=tonumber(move.pp) or 0;if not finite(pp) then pp=0 end
  local description=Core.moveDescription(moveId,move)
  return {itemId=id,moveId=moveId,code=code,kind=kind,number=number,
    numberKey=(kind=="HM" and 0 or 1000)+number,name=tostring(move.name or moveId or id),
    type=tostring(move.type or "Unknown"),damageClass=Core.moveDamageClass(move),
    power=math.floor(power),accuracy=accuracy and math.floor(accuracy) or nil,
    pp=math.floor(pp),description=description}
end

function Core.machineDetail(info)
  if type(info)~="table" then return nil end
  return {kind="machine",typeId=info.type,parameters={
    {label="MOVE",value=info.name},
    {label="CATEGORY",value=info.damageClass},
    {label="POWER",value=info.damageClass=="Status" and "--" or tostring(info.power)},
    {label="ACCURACY",value=info.accuracy and tostring(info.accuracy).."%" or "Varies"},
    {label="PP",value=tostring(info.pp)},
    {label="DESCRIPTION",value=info.description},
  }}
end

function Core.subtypeFor(id,pocket,def)
  if pocket=="medicine" then
    if HEAL_HP[id] then return "HP recovery",1 end
    if HEAL_STATUS[id] then return "Status recovery",2 end
    if REVIVAL[id] then return "Revival",3 end
    if RESTORE_PP[id] then return "PP recovery",4 end
    if VITAMINS[id] then return "Vitamin",5 end
    if id=="RARE_CANDY" then return "Level item",6 end
    return "Medicine",7
  elseif pocket=="balls" then return "Poke Ball",1
  elseif pocket=="battle" then
    if id=="POKE_DOLL" then return "Escape item",2 end
    return "Battle boost",1
  elseif pocket=="key" then
    if id=="BICYCLE" or id=="TOWN_MAP" then return "Travel",1 end
    if RODS[id] then return "Fishing",2 end
    if id:find("KEY",1,true) then return "Access key",3 end
    return "Story item",4
  elseif pocket=="items" then
    if REPELS[id] then return "Repel",1 end
    if id=="ESCAPE_ROPE" then return "Travel item",2 end
    if STONES[id] then return "Evolution stone",3 end
    if FOSSILS[id] then return "Fossil",4 end
    if id=="NUGGET" then return "Valuable",5 end
    return "Item",6
  end
  return "Machine",1
end

function Core.descriptionFor(game,id,def,pocket,mode)
  def=type(def)=="table" and def or {}
  if pocket=="machines" then
    local info=Core.machineInfo(game,id,def)
    if not info then return "Teaches a Pokemon a move." end
    local parts={info.code.." teaches "..info.name..".",
      info.type.." "..info.damageClass.." move."}
    if info.damageClass~="Status" then parts[#parts+1]="Power "..tostring(info.power).."." end
    parts[#parts+1]="Accuracy "..(info.accuracy and tostring(info.accuracy).."%" or "varies").."."
    parts[#parts+1]="PP "..tostring(info.pp).."."
    if info.description then parts[#parts+1]=info.description end
    return table.concat(parts," ")
  end
  local text=DESCRIPTIONS[id] or def.description or def.desc
  if type(text)~="string" or text=="" then text="No additional information is available." end
  if pocket=="battle" then
    local availability=mode=="battle"
      and "Availability: this is a battle item; the game will check whether it can be used now."
      or "Availability: battle only."
    text=text.." "..availability
  end
  return text
end

local function isBadge(id,options)
  if options and type(options.isBadge)=="function" then
    local ok,result=pcall(options.isBadge,id);if ok then return result==true end
  end
  return tostring(id):find("BADGE",1,true)~=nil
end

local function orderedIds(inventory,options)
  local out,seen={},{}
  for _,id in ipairs(type(options.order)=="table" and options.order or {}) do
    if type(id)=="string" and Core.safeCount(inventory[id])>0 and not seen[id] then
      seen[id]=true;out[#out+1]=id
    end
  end
  local extras={}
  for id,count in pairs(inventory) do
    if type(id)=="string" and Core.safeCount(count)>0 and not seen[id] then extras[#extras+1]=id end
  end
  table.sort(extras)
  for _,id in ipairs(extras) do out[#out+1]=id end
  return out
end

function Core.rows(game,pocketId,options)
  options=type(options)=="table" and options or {}
  local save=game and type(game.save)=="table" and game.save or {}
  local inventory=type(save.inventory)=="table" and save.inventory or {}
  local items=game and game.data and type(game.data.items)=="table" and game.data.items or {}
  local rows={}
  for _,id in ipairs(orderedIds(inventory,options)) do
    if not isBadge(id,options) then
      local def=type(items[id])=="table" and items[id] or {}
      local pocket=Core.pocketFor(id,def,options.classificationOverrides)
      if pocket==pocketId then
        local subtype,typeRank=Core.subtypeFor(id,pocket,def)
        rows[#rows+1]={itemId=id,value=id,label=tostring(def.name or id),
          count=Core.safeCount(inventory[id]),enabled=true,category=pocket,
          subtype=subtype,typeRank=typeRank,machine=Core.machineInfo(game,id,def),
          description=Core.descriptionFor(game,id,def,pocket,options.mode)}
      end
    end
  end
  if pocketId=="machines" then
    table.sort(rows,function(a,b)
      if a.machine.numberKey~=b.machine.numberKey then return a.machine.numberKey<b.machine.numberKey end
      return a.itemId<b.itemId
    end)
  end
  return rows
end

function Core.sortedRows(rows,mode,pocketId)
  local out={};for i,row in ipairs(rows or {}) do out[i]=row end
  if pocketId=="machines" then return out end
  table.sort(out,function(a,b)
    if mode=="type" and a.typeRank~=b.typeRank then return a.typeRank<b.typeRank end
    if mode=="quantity" and a.count~=b.count then return a.count>b.count end
    local an,bn=Core.normalized(a.label),Core.normalized(b.label)
    if an~=bn then return an<bn end
    return a.itemId<b.itemId
  end)
  return out
end

function Core.applyPocketOrder(globalOrder,pocketRows,sortedRows)
  local slots,wanted={},{}
  for _,row in ipairs(pocketRows or {}) do wanted[row.itemId]=true end
  for i,id in ipairs(globalOrder or {}) do if wanted[id] then slots[#slots+1]=i end end
  for i,slot in ipairs(slots) do globalOrder[slot]=sortedRows[i].itemId end
  return globalOrder
end

local function iconCopy(icon)
  if type(icon)~="table" then return nil end
  local out={}
  if type(icon.imagePath)=="string" then out.imagePath=icon.imagePath end
  if type(icon.path)=="string" then out.path=icon.path end
  if icon.image and type(icon.image.getDimensions)=="function" then out.image=icon.image end
  return next(out) and out or nil
end

function Core.snapshot(game,state,options)
  options=type(options)=="table" and options or {};options.mode=state.mode
  local rows=Core.rows(game,state.pocketId or Core.DEFAULT_POCKET,options)
  local semantic={}
  for i,row in ipairs(rows) do
    local icon=options.resolveIcon and options.resolveIcon(row.itemId,row.category)
    semantic[i]={itemId=row.itemId,label=row.label,count=row.count,enabled=true,
      favorite=false,pinned=false,category=row.category,description=row.description,
      detail=Core.machineDetail(row.machine),icon=iconCopy(icon)}
  end
  local selected=tonumber(state.index) or 1
  selected=#semantic>0 and math.max(1,math.min(#semantic,selected)) or 1
  local snapshot={schemaVersion=2,screen=state.screen or "bag",
    mode=state.mode=="battle" and "battle" or "field",title="BAG",pockets={},
    selectedPocketId=state.pocketId or Core.DEFAULT_POCKET,rows=semantic,
    selectedIndex=selected,scroll=math.max(0,math.floor(tonumber(state.scroll) or 0)),
    money=Core.safeCount(game and game.save and game.save.money),
    description=semantic[selected] and semantic[selected].description or "",
    hints=state.hints or "A SELECT   B BACK   START SORT   SELECT MOVE",
    actions={{id="select",label="SELECT"},{id="options",label="MOVE"}}}
  for i,pocket in ipairs(Core.POCKETS) do snapshot.pockets[i]={id=pocket.id,label=pocket.label,enabled=true} end
  if snapshot.screen=="item_options" or snapshot.screen=="item_confirmation" then
    local lines=state.modalLines or {}
    local modalIndex=tonumber(state.modalIndex) or 1
    modalIndex=#lines>0 and math.max(1,math.min(#lines,modalIndex)) or 1
    snapshot.item={lines=lines,selectedIndex=modalIndex}
  end
  return snapshot,rows
end

return Core
