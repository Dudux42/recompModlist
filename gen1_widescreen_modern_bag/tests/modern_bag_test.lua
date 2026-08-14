local source=debug.getinfo(1,"S").source:sub(2)
local root=source:match("^(.*)[/\\]tests[/\\]")
package.path=root.."/?.lua;"..package.path

local function eq(actual,expected,label)
  assert(actual==expected,(label or "value")..": expected "..tostring(expected)
    ..", got "..tostring(actual))
end

local Core=require("bag_core")
local IconCatalog=require("item_icons")

eq(#Core.POCKETS,6,"pocket count")
eq(Core.DEFAULT_POCKET,"medicine","default pocket")
eq(Core.pocketFor("POTION",{}),"medicine")
eq(Core.pocketFor("MASTER_BALL",{}),"balls")
eq(Core.pocketFor("TM_MEGA_PUNCH",{machine={kind="TM",number=1,move="MEGA_PUNCH"}}),"machines")
eq(Core.pocketFor("CUSTOM",{keyItem=true}),"key")
eq(Core.pocketFor("BROKEN",{}),"items","unknown fallback")
eq(Core.pocketFor("CUSTOM",{keyItem=true},{CUSTOM="battle"}),"battle")
eq(Core.moveDamageClass({power=40,type="NORMAL"}),"Physical")
eq(Core.moveDamageClass({power=40,type="WATER"}),"Special")
eq(Core.moveDamageClass({power=0,type="NORMAL"}),"Status")

local baseIconCount=0;for _ in pairs(IconCatalog.baseMapping) do baseIconCount=baseIconCount+1 end
eq(baseIconCount,70,"individual icon roles")
for id in pairs(IconCatalog.baseMapping) do
  local pocket=Core.pocketFor(id,{})
  local description=Core.descriptionFor(nil,id,{},pocket,"field")
  assert(description~="No additional information is available.",
    id.." still uses the generic description")
end

local game={save={money=1234,inventory={
  POTION=4,SUPER_POTION=2,ANTIDOTE=7,ETHER=1,MASTER_BALL=1,
  TM_MEGA_PUNCH=1,HM_CUT=1,BICYCLE=1,NUGGET=3,BOULDERBADGE=1,
}},data={constants={bagSize=20},items={
  POTION={name="Potion"},SUPER_POTION={name="Super Potion"},
  ANTIDOTE={name="Antidote"},ETHER={name="Ether"},
  MASTER_BALL={name="Master Ball",ball=true},
  TM_MEGA_PUNCH={name="TM01",machine={kind="TM",number=1,move="MEGA_PUNCH"}},
  HM_CUT={name="HM01",machine={kind="HM",number=1,move="CUT"}},
  BICYCLE={name="Bicycle",keyItem=true,tossable=false},NUGGET={name="Nugget"},
},moves={
  MEGA_PUNCH={name="Mega Punch",type="NORMAL",power=80,accuracy=85,pp=20},
  CUT={name="Cut",type="NORMAL",power=50,accuracy=95,pp=30},
}}}

local order={"ETHER","POTION","ANTIDOTE","SUPER_POTION","MASTER_BALL",
  "TM_MEGA_PUNCH","HM_CUT","BICYCLE","NUGGET"}
local options={order=order,mode="field"}
local medicine=Core.rows(game,"medicine",options)
eq(medicine[1].itemId,"ETHER","engine order preserved")
eq(#medicine,4,"medicine count")
local alpha=Core.sortedRows(medicine,"alphabetical","medicine")
eq(alpha[1].itemId,"ANTIDOTE","alphabetical sort")
local typed=Core.sortedRows(medicine,"type","medicine")
eq(typed[1].itemId,"POTION","HP recovery first")
eq(typed[3].itemId,"ANTIDOTE","status recovery after HP")
eq(typed[4].itemId,"ETHER","PP recovery after status")
local quantity=Core.sortedRows(medicine,"quantity","medicine")
eq(quantity[1].itemId,"ANTIDOTE","quantity descending")
local reordered={};for i,id in ipairs(order) do reordered[i]=id end
Core.applyPocketOrder(reordered,medicine,alpha)
eq(reordered[1],"ANTIDOTE","pocket sort writes first occupied global slot")
eq(reordered[5],"MASTER_BALL","pocket sort preserves other pocket slots")

local machines=Core.rows(game,"machines",options)
eq(machines[1].itemId,"HM_CUT","HM before TM")
eq(machines[2].itemId,"TM_MEGA_PUNCH","TM numeric after HM")
local info=Core.descriptionFor(game,"TM_MEGA_PUNCH",game.data.items.TM_MEGA_PUNCH,
  "machines","field")
assert(info:find("teaches Mega Punch",1,true) and info:find("Power 80",1,true)
  and info:find("Accuracy 85%",1,true),"plain TM details incomplete")
local machineDetail=Core.machineDetail(Core.machineInfo(
  game,"TM_MEGA_PUNCH",game.data.items.TM_MEGA_PUNCH))
eq(machineDetail.kind,"machine");eq(machineDetail.typeId,"NORMAL")
eq(machineDetail.parameters[1].label,"MOVE");eq(machineDetail.parameters[1].value,"Mega Punch")
eq(machineDetail.parameters[4].label,"ACCURACY");eq(machineDetail.parameters[4].value,"85%")
eq(machineDetail.parameters[6].label,"DESCRIPTION")
assert(machineDetail.parameters[6].value:find("powerful punch",1,true),
  "Mega Punch description missing")
local bideDescription=Core.moveDescription("BIDE",{power=0,type="NORMAL"})
assert(bideDescription:find("2 to 3 turns",1,true)
    and bideDescription:find("twice the damage",1,true),
  "Bide mechanic description missing")
local machineMoves={"MEGA_PUNCH","RAZOR_WIND","SWORDS_DANCE","WHIRLWIND",
  "MEGA_KICK","TOXIC","HORN_DRILL","BODY_SLAM","TAKE_DOWN","DOUBLE_EDGE",
  "BUBBLE_BEAM","WATER_GUN","ICE_BEAM","BLIZZARD","HYPER_BEAM","PAY_DAY",
  "SUBMISSION","COUNTER","SEISMIC_TOSS","RAGE","MEGA_DRAIN","SOLAR_BEAM",
  "DRAGON_RAGE","THUNDERBOLT","THUNDER","EARTHQUAKE","FISSURE","DIG",
  "PSYCHIC","TELEPORT","MIMIC","DOUBLE_TEAM","REFLECT","BIDE","METRONOME",
  "SELF_DESTRUCT","EGG_BOMB","FIRE_BLAST","SWIFT","SKULL_BASH","SOFT_BOILED",
  "DREAM_EATER","SKY_ATTACK","REST","THUNDER_WAVE","PSYWAVE","EXPLOSION",
  "ROCK_SLIDE","TRI_ATTACK","SUBSTITUTE","CUT","FLY","SURF","STRENGTH","FLASH"}
eq(#machineMoves,55,"Gen 1 machine move count")
for _,moveId in ipairs(machineMoves) do
  local description=Core.moveDescription(moveId,{power=40,type="NORMAL"})
  assert(description~="The user attacks the target with this move.",
    moveId.." is missing its dedicated description")
end
assert(Core.descriptionFor(game,"POKE_BALL",{},"balls","field"):find(
  "capture and safely store",1,true),"Poke Ball description missing")
assert(Core.descriptionFor(game,"SAFARI_BALL",{},"balls","field"):find(
  "Safari Zone",1,true),"Safari Ball description missing")
local battleInfo=Core.descriptionFor(game,"X_ATTACK",{},"battle","field")
assert(battleInfo:find("battle only",1,true),"field battle-item availability missing")
local activeBattleInfo=Core.descriptionFor(game,"X_ATTACK",{},"battle","battle")
assert(activeBattleInfo:find("game will check",1,true),"battle availability missing")

local snapshot=Core.snapshot(game,{screen="bag",mode="field",pocketId="medicine",
  index=1,scroll=0},options)
eq(snapshot.schemaVersion,2);eq(snapshot.selectedPocketId,"medicine")
eq(#snapshot.pockets,6);eq(snapshot.rows[1].favorite,false);eq(snapshot.rows[1].pinned,false)
assert(snapshot.inventory==nil and snapshot.save==nil and snapshot.game==nil,
  "snapshot leaked live state")

local callbacks={}
local stack={states={}}
function stack:push(value) self.states[#self.states+1]=value end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end
game.stack=stack;game.input={wasPressed=function() return false end}

local Bag={}
local baseAddCalls=0
local orders=setmetatable({},{__mode="k"});orders[game.save]=order
function Bag.order(save) orders[save]=orders[save] or {};return orders[save] end
function Bag.isBadge(id) return id:find("BADGE",1,true)~=nil end
function Bag.capacity() return 20 end
function Bag.add(save,id,qty,data)
  baseAddCalls=baseAddCalls+1
  if not data.items[id] then return false end
  save.inventory[id]=math.min(99,(save.inventory[id] or 0)+(qty or 1));return true
end
package.preload["src.inventory.Bag"]=function() return Bag end

local BagMenu={}
function BagMenu.new(currentGame,opts)
  local list={game=currentGame,kind="bag",items={},index=1,scroll=0}
  list.onChoose=function(item) callbacks.chosen=item.value end
  list.onCancel=function() callbacks.cancelled=true end
  return list
end
package.preload["src.ui.BagMenu"]=function() return BagMenu end

local provider
local widescreen={exports={bagProviderApiVersion=2,
  registerBagProvider=function(spec) provider=spec return true,"registered" end,
  activeBagProviderOwner=function() return provider and provider.owner end}}
local mod={exports={},save={},assets={path=function(_,path) return path end}}
mod.path=root
function mod:read(path)
  local file=io.open(root.."/"..path,"rb")
  if not file then return nil,"missing" end
  local content=file:read("*a");file:close();return content
end
function mod:find(id) if id=="gen1_widescreen_ui" then return widescreen end end
mod.log={error=function() end,info=function() end}
mod.events={on=function(_,name,fn) callbacks[name]=fn end}

assert(loadfile(root.."/main.lua"))()(mod)
assert(provider and provider.owner=="gen1_widescreen_modern_bag","provider registration")
eq(provider.apiVersion,2,"provider API version")
callbacks["game.ready"]({game=game})
eq(Bag.capacity(),Core.MAX_DISTINCT_ITEMS,"expanded capacity")
assert(Bag.add(game.save,"POTION",100,game.data));eq(game.save.inventory.POTION,104,"stack >99")
assert(Bag.add(game.save,"POTION",1000000,game.data));eq(game.save.inventory.POTION,1000104,"large finite stack")
assert(not Bag.add(game.save,"MISSING",1,game.data),"invalid ID must delegate")
local beforeDelegation=baseAddCalls
Bag.add(game.save,"POTION",1.5,game.data)
eq(baseAddCalls,beforeDelegation+1,"fractional amount must delegate")
beforeDelegation=baseAddCalls;Bag.add(game.save,"POTION",0,game.data)
eq(baseAddCalls,beforeDelegation+1,"zero amount must delegate")

local bag=BagMenu.new(game,{});stack:push(bag)
assert(bag.__modernBag and bag.__widescreenBagOwned,"provider ownership")
eq(bag.__modernBagSession.pocketId,"medicine")
eq(provider.snapshot(game,bag).screen,"bag")

provider.actions.select(game,bag)
local optionSnapshot=provider.snapshot(game,bag)
eq(optionSnapshot.screen,"item_options","field options screen")
eq(optionSnapshot.item.selectedIndex,1,"initial modal focus")
provider.actions.down(game,bag)
eq(provider.snapshot(game,bag).item.selectedIndex,2,"modal focus follows controller")
provider.actions.back(game,bag)

-- A quantity refresh never changes order automatically.
local beforeRefresh=table.concat(Bag.order(game.save),"|")
game.save.inventory.ANTIDOTE=99
provider.snapshot(game,bag)
eq(table.concat(Bag.order(game.save),"|"),beforeRefresh,"quantity refresh reordered Bag")

-- SELECT performs a persistent vanilla-style swap through Bag.order.
provider.actions.options(game,bag)
local moveSource=bag.__modernBagSession.moveId;assert(moveSource,"move did not begin")
provider.actions.down(game,bag)
local target=bag.__modernBagSession.rows[bag.index].itemId
local oldSourcePos,oldTargetPos
for i,id in ipairs(Bag.order(game.save)) do
  if id==moveSource then oldSourcePos=i end;if id==target then oldTargetPos=i end
end
provider.actions.options(game,bag)
assert(not bag.__modernBagSession.moveId,"move did not finish")
local sourcePos,targetPos
for i,id in ipairs(Bag.order(game.save)) do
  if id==moveSource then sourcePos=i end;if id==target then targetPos=i end
end
assert(sourcePos and targetPos,"manual order was not persisted")
eq(sourcePos,oldTargetPos,"source was not swapped to target slot")
eq(targetPos,oldSourcePos,"target was not swapped to source slot")

-- START applies explicit sorts and cycles modes; it never runs on inventory change.
provider.actions.search(game,bag)
eq(bag.__modernBagSession.sortModes.medicine,"alphabetical","first START sort")
provider.actions.search(game,bag)
eq(bag.__modernBagSession.sortModes.medicine,"type","second START sort")
provider.actions.search(game,bag)
eq(bag.__modernBagSession.sortModes.medicine,"quantity","third START sort")
provider.actions.pocket(game,bag,"machines")
assert(not provider.actions.search(game,bag),"TM/HM sorting must stay fixed")
local machineSnapshot=provider.snapshot(game,bag)
eq(machineSnapshot.rows[1].itemId,"HM_CUT")
eq(machineSnapshot.rows[1].detail.kind,"machine","machine detail snapshot")

local battleBag=BagMenu.new(game,{battle={trainer=true}});stack:push(battleBag)
eq(provider.snapshot(game,battleBag).mode,"battle","battle snapshot mode")
provider.actions.pocket(game,battleBag,"battle")
game.save.inventory.X_ATTACK=1;game.data.items.X_ATTACK={name="X Attack"}
provider.snapshot(game,battleBag)
provider.actions.select(game,battleBag)
eq(callbacks.chosen,"X_ATTACK","battle action did not delegate")

eq(mod.exports.itemIconApiVersion,1)
assert(not mod.exports.resolveItemIcon("POTION","medicine").fallback)
eq(#mod.exports.auditItemIcons(game).missing,0,"dedicated icon coverage")
assert(mod.exports.registerClassification("CUSTOM","items"))
assert(not mod.exports.registerClassification("CUSTOM","favorites"))

print("Widescreen Modern Bag tests passed")
