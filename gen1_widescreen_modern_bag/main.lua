-- Widescreen Modern Bag
-- Version 0.1.0-alpha.5
-- Semantic Bag provider. Gen1 Widescreen UI performs all Bag drawing.

local Core
local IconCatalog

local OWNER="gen1_widescreen_modern_bag"
local API_VERSION=2
local PATCH_KEY="__gen1_widescreen_modern_bag_dispatch_v1"
local ADD_PATCH_KEY="__gen1_widescreen_modern_bag_add_dispatch_v1"

local function finiteInteger(value)
  return type(value)=="number" and value==value and value~=math.huge
    and value~=-math.huge and value%1==0
end

local function rootFor(state) return state and (state.__modernBagRoot or state) end

local function selectedId(root)
  local session=root and root.__modernBagSession
  local row=session and session.rows and session.rows[root.index or 1]
  return row and row.itemId or nil
end

local function pocketPosition(id)
  for i,pocket in ipairs(Core.POCKETS) do if pocket.id==id then return i end end
  return 1
end

local function rememberCursor(root)
  local session=root and root.__modernBagSession;if not session then return end
  session.cursors[session.pocketId]=root.index or 1
  session.scrolls[session.pocketId]=root.scroll or 0
end

local function bagOrder(session)
  return session.Bag.order(session.game.save)
end

local function ensureOrder(session)
  local order=bagOrder(session);local seen={}
  for _,id in ipairs(order) do seen[id]=true end
  local extras={}
  for id,count in pairs(session.game.save.inventory or {}) do
    local badge=type(session.Bag.isBadge)=="function" and session.Bag.isBadge(id)
      or tostring(id):find("BADGE",1,true)~=nil
    if type(id)=="string" and Core.safeCount(count)>0 and not badge and not seen[id] then
      extras[#extras+1]=id
    end
  end
  table.sort(extras)
  for _,id in ipairs(extras) do order[#order+1]=id end
  return order
end

local function currentHints(session)
  if session.moveId then return "SELECT PLACE ITEM   B CANCEL MOVE" end
  if session.pocketId=="machines" then
    return "A SELECT   B BACK   HM/TM NUMBER ORDER"
  end
  local mode=session.sortModes[session.pocketId]
  return "A SELECT   B BACK   START SORT"..(mode and (": "..mode:upper()) or "")
    .."   SELECT MOVE"
end

local function refreshRoot(root,keepId)
  local session=root.__modernBagSession
  local order=ensureOrder(session)
  session.options.order=order
  session.options.mode=session.mode
  local rows=Core.rows(root.game,session.pocketId,session.options)
  session.rows=rows
  root.items={}
  for i,row in ipairs(rows) do
    root.items[i]={value=row.itemId,label=row.label,right="x"..tostring(row.count)}
  end
  local wanted
  if keepId then for i,row in ipairs(rows) do if row.itemId==keepId then wanted=i break end end end
  root.index=wanted or math.max(1,math.min(#rows,
    tonumber(session.cursors[session.pocketId]) or tonumber(root.index) or 1))
  root.scroll=math.max(0,tonumber(session.scrolls[session.pocketId]) or 0)
  session.hints=currentHints(session)
  return rows
end

local function inventorySignature(game)
  local values={}
  for id,count in pairs(game and game.save and game.save.inventory or {}) do
    if type(id)=="string" and not id:find("BADGE",1,true) then
      values[#values+1]=id.."="..tostring(Core.safeCount(count))
    end
  end
  table.sort(values);return table.concat(values,"\0")
end

local function modalLines(state)
  local out={};for _,entry in ipairs(state.items or {}) do
    out[#out+1]=tostring(entry.label or entry.value or "OPTION") end
  return out
end

local function providerSnapshot(game,state)
  local root=rootFor(state);local session=root and root.__modernBagSession
  if not session then error("Modern Bag state has no session") end
  local signature=inventorySignature(game)
  if signature~=session.inventorySignature then
    local keep=selectedId(root);session.inventorySignature=signature;refreshRoot(root,keep)
  end
  local view={screen=session.screen,mode=session.mode,pocketId=session.pocketId,
    index=root.index,scroll=root.scroll,modalLines=session.modalLines,
    modalIndex=session.modalIndex,hints=session.hints}
  if state~=root then
    view.screen=state.__modernBagScreen or "item_confirmation"
    view.modalLines=state.__modernBagLines or modalLines(state)
    view.modalIndex=tonumber(state.index) or 1
  end
  local snapshot=Core.snapshot(game,view,session.options)
  return snapshot
end

local function switchPocket(root,delta,wanted)
  local session=root.__modernBagSession;rememberCursor(root)
  local position=wanted and pocketPosition(wanted) or pocketPosition(session.pocketId)+delta
  position=((position-1)%#Core.POCKETS)+1
  session.pocketId=Core.POCKETS[position].id
  session.screen,session.modalLines,session.modalIndex="bag",nil,nil
  session.moveId=nil
  refreshRoot(root)
  return true
end

local function moveCursor(root,delta)
  local rows=root.__modernBagSession.rows or {};if #rows==0 then return false end
  root.index=((root.index-1+delta)%#rows)+1
  rememberCursor(root);return true
end

local function markBagModal(root,state,screen,lines)
  if not state or state==root then return state end
  state.__modernBag=true;state.__widescreenBagOwned=true;state.__modernBagRoot=root
  state.__modernBagScreen=screen;state.__modernBagLines=lines
  return state
end

local function convertChoiceToMenu(root,choice)
  if not (choice and type(choice.onChoose)=="function") then return choice end
  local game=root.game;if game.stack:top()==choice then game.stack:pop() end
  local Menu=require("src.ui.Menu")
  local menu=Menu.new(game,{
    {label="YES",onSelect=function() choice.onChoose(true) end},
    {label="NO",onSelect=function() choice.onChoose(false) end},
  },{cancelable=true,onCancel=function() choice.onChoose(false) end})
  game.stack:push(menu)
  return markBagModal(root,menu,"item_confirmation",{"YES","NO"})
end

local function markTopModal(root)
  local top=root.game.stack:top();if not top or top==root then return top end
  if type(top.qty)=="number" and type(top.onDone)=="function" then
    return markBagModal(root,top,"item_confirmation",{
      "QUANTITY x"..tostring(top.qty),"MAX x"..tostring(top.max or 1)})
  end
  if type(top.onChoose)=="function" and top.index and not top.items then
    return convertChoiceToMenu(root,top)
  end
  return top
end

local function invokeNativeOption(root,optionIndex)
  local session=root.__modernBagSession;local id=selectedId(root)
  if not id or type(session.nativeChoose)~="function" then return false end
  session.nativeChoose({value=id,label=id},root)
  local menu=root.game.stack:top()
  if not (menu and menu~=root and type(menu.items)=="table") then markTopModal(root);return true end
  local entry=menu.items[optionIndex];if not entry then return false end
  root.game.stack:pop();if type(entry.onSelect)=="function" then entry.onSelect() end
  markTopModal(root);return true
end

local function beginOrFinishMove(root)
  local session=root.__modernBagSession
  if session.pocketId=="machines" or session.screen~="bag" then return false end
  local id=selectedId(root);if not id then return false end
  if not session.moveId then
    session.moveId=id;session.hints=currentHints(session);return true
  end
  local source=session.moveId;local target=id;local order=bagOrder(session)
  local from,to
  for i,value in ipairs(order) do
    if value==source then from=i end;if value==target then to=i end
  end
  if from and to then order[from],order[to]=order[to],order[from] end
  session.moveId=nil;refreshRoot(root,source);return from~=nil and to~=nil
end

local function applyNextSort(root)
  local session=root.__modernBagSession
  if session.pocketId=="machines" or session.screen~="bag" or session.moveId then return false end
  local previous=session.sortModes[session.pocketId]
  local index=0;for i,mode in ipairs(Core.SORT_MODES) do if mode==previous then index=i end end
  local mode=Core.SORT_MODES[index%#Core.SORT_MODES+1]
  local keep=selectedId(root)
  local rows=Core.rows(root.game,session.pocketId,session.options)
  local sorted=Core.sortedRows(rows,mode,session.pocketId)
  Core.applyPocketOrder(bagOrder(session),rows,sorted)
  session.sortModes[session.pocketId]=mode
  refreshRoot(root,keep);return true
end

local Actions={}

function Actions.up(game,state)
  local root=rootFor(state)
  if state~=root and state.qty then
    state.qty=state.qty+1;if state.qty>state.max then state.qty=1 end
    state.__modernBagLines={"QUANTITY x"..state.qty,"MAX x"..state.max};return true
  end
  if state~=root and type(state.items)=="table" and #state.items>0 then
    state.index=((tonumber(state.index) or 1)-2)%#state.items+1;return true
  end
  local session=root.__modernBagSession
  if session.screen~="bag" then
    local n=#(session.modalLines or {});if n>0 then
      session.modalIndex=((session.modalIndex or 1)-2)%n+1;return true end
  end
  return moveCursor(root,-1)
end

function Actions.down(game,state)
  local root=rootFor(state)
  if state~=root and state.qty then
    state.qty=state.qty-1;if state.qty<1 then state.qty=state.max end
    state.__modernBagLines={"QUANTITY x"..state.qty,"MAX x"..state.max};return true
  end
  if state~=root and type(state.items)=="table" and #state.items>0 then
    state.index=(tonumber(state.index) or 1)%#state.items+1;return true
  end
  local session=root.__modernBagSession
  if session.screen~="bag" then
    local n=#(session.modalLines or {});if n>0 then
      session.modalIndex=(session.modalIndex or 1)%n+1;return true end
  end
  return moveCursor(root,1)
end

function Actions.back(game,state)
  local root=rootFor(state)
  if state~=root then
    if game.stack:top()==state then game.stack:pop() end
    if state.qty and state.onDone then state.onDone(nil) end
    if not state.qty and type(state.onCancel)=="function" then state.onCancel() end
    return true
  end
  local session=root.__modernBagSession
  if session.screen~="bag" then
    session.screen,session.modalLines,session.modalIndex="bag",nil,nil;return true
  end
  if session.moveId then session.moveId=nil;session.hints=currentHints(session);return true end
  if game.stack:top()==root then game.stack:pop() end
  if type(session.nativeCancel)=="function" then session.nativeCancel() end
  return true
end

function Actions.select(game,state)
  local root=rootFor(state)
  if state~=root then
    if state.qty and state.onDone then
      if game.stack:top()==state then game.stack:pop() end
      state.onDone(state.qty);markTopModal(root);return true
    end
    local entry=state.items and state.items[state.index or 1]
    if entry then
      if game.stack:top()==state then game.stack:pop() end
      if type(entry.onSelect)=="function" then entry.onSelect() end
      markTopModal(root);return true
    end
    return false
  end
  local session=root.__modernBagSession
  if session.screen=="item_options" then
    local index=session.modalIndex or 1
    session.screen,session.modalLines,session.modalIndex="bag",nil,nil
    if index==1 then return invokeNativeOption(root,1)
    elseif index==2 then return invokeNativeOption(root,2) end
    return true
  end
  if session.moveId then return false end
  if session.mode=="battle" then
    local id=selectedId(root)
    if id and type(session.nativeChoose)=="function" then
      session.nativeChoose({value=id,label=id},root);return true end
    return false
  end
  if not selectedId(root) then return false end
  session.screen,session.modalIndex="item_options",1
  session.modalLines={"USE","TOSS","CANCEL"}
  return true
end

function Actions.pocketLeft(game,state) return switchPocket(rootFor(state),-1) end
function Actions.pocketRight(game,state) return switchPocket(rootFor(state),1) end
function Actions.pocket(game,state,id) return switchPocket(rootFor(state),0,id) end
function Actions.selectIndex(game,state,index)
  local root=rootFor(state);index=tonumber(index)
  if index and finiteInteger(index) and index>=1 and index<=#root.__modernBagSession.rows then
    root.index=index;rememberCursor(root);return true end
  return false
end
function Actions.modalIndex(game,state,index)
  local root=rootFor(state);local session=root.__modernBagSession;index=tonumber(index)
  if not (index and finiteInteger(index)) then return false end
  if state~=root and state.items and state.items[index] then state.index=index
  elseif session.modalLines and session.modalLines[index] then session.modalIndex=index
  else return false end
  return Actions.select(game,state)
end
function Actions.options(game,state)
  local root=rootFor(state);if state~=root then return false end
  return beginOrFinishMove(root)
end
function Actions.search(game,state)
  local root=rootFor(state);if state~=root then return false end
  return applyNextSort(root)
end
function Actions.info() return false end

local function installUnlimitedInventory(game)
  local ok,Bag=pcall(require,"src.inventory.Bag")
  if not ok or type(Bag)~="table" then return nil,"src.inventory.Bag unavailable" end
  game.data.constants=game.data.constants or {};game.data.constants.bagSize=Core.MAX_DISTINCT_ITEMS
  Bag.CAPACITY=Core.MAX_DISTINCT_ITEMS
  local dispatch=rawget(_G,ADD_PATCH_KEY)
  if not dispatch then
    dispatch={baseAdd=Bag.add,baseCapacity=Bag.capacity};rawset(_G,ADD_PATCH_KEY,dispatch)
    if type(Bag.capacity)=="function" then Bag.capacity=function() return Core.MAX_DISTINCT_ITEMS end end
    if type(Bag.add)=="function" then
      Bag.add=function(save,id,qty,data,...)
        return dispatch.add and dispatch.add(save,id,qty,data,...)
          or dispatch.baseAdd(save,id,qty,data,...)
      end
    end
  end
  dispatch.add=function(save,id,qty,data,...)
    local amount=qty==nil and 1 or qty
    local inventory=type(save)=="table" and save.inventory or nil
    local defs=type(data)=="table" and data.items or nil
    local current=inventory and inventory[id]
    if type(id)~="string" or id=="" or not inventory or not defs
        or type(defs[id])~="table" or not finiteInteger(amount) or amount<=0
        or (current~=nil and (not finiteInteger(current) or current<0)) then
      return dispatch.baseAdd(save,id,qty,data,...)
    end
    current=current or 0;if current>Core.MAX_SAFE_STACK-amount then return false end
    local isNew=current==0;inventory[id]=current+amount
    local badge=type(Bag.isBadge)=="function" and Bag.isBadge(id)
    if isNew and not badge then
      local order=Bag.order(save);local present=false
      for _,value in ipairs(order) do if value==id then present=true break end end
      if not present then order[#order+1]=id end
    end
    return true
  end
  return true,Bag
end

local function decorateBag(game,opts,list,mod,Bag)
  if type(list)~="table" then return list end
  list.__modernBag=true;list.__widescreenBagOwned=true;list.__modernBagRoot=list
  list.__modernBagSession={mod=mod,game=game,Bag=Bag,
    mode=opts and opts.battle and "battle" or "field",screen="bag",
    pocketId=Core.DEFAULT_POCKET,cursors={},scrolls={},sortModes={},
    nativeChoose=list.onChoose,nativeCancel=list.onCancel,
    options={classificationOverrides=mod.__classificationOverrides,
      isBadge=function(id) return type(Bag.isBadge)=="function" and Bag.isBadge(id) end,
      resolveIcon=function(id,category)
        return mod.__itemIcons.resolveItemIcon(id,category)
      end}}
  refreshRoot(list);list.__modernBagSession.inventorySignature=inventorySignature(game)
  return list
end

return function(mod)
  local compile=loadstring or load
  local function loadModule(path)
    local source,readError=mod:read(path)
    if not source then error("cannot read "..path..": "..tostring(readError),0) end
    local chunk,compileError=compile(source,"@"..tostring(mod.path or OWNER).."/"..path)
    if not chunk then error("cannot compile "..path..": "..tostring(compileError),0) end
    return chunk()
  end
  Core=loadModule("bag_core.lua")
  IconCatalog=loadModule("item_icons.lua")
  mod.__classificationOverrides=mod.__classificationOverrides or {}
  mod.__itemIcons=mod.__itemIcons or IconCatalog.new(mod)
  local registered=false
  local function logOnce(message)
    mod.__modernBagLogs=mod.__modernBagLogs or {};if mod.__modernBagLogs[message] then return end
    mod.__modernBagLogs[message]=true
    if mod.log then mod.log:error("Widescreen Modern Bag: %s",message) end
  end
  local function ensureProvider()
    local widescreen=type(mod.find)=="function" and mod:find("gen1_widescreen_ui") or nil
    local exports=widescreen and widescreen.exports
    if type(exports)~="table" or exports.bagProviderApiVersion~=API_VERSION
        or type(exports.registerBagProvider)~="function" then
      registered=false;logOnce("requires Gen1 Widescreen UI Bag Provider API v2");return false
    end
    if registered and type(exports.activeBagProviderOwner)=="function"
        and exports.activeBagProviderOwner()==OWNER then return true end
    local ok,reason=exports.registerBagProvider({owner=OWNER,apiVersion=API_VERSION,
      match=function(state) return type(state)=="table" and state.__modernBag==true end,
      snapshot=providerSnapshot,actions=Actions})
    if not ok then registered=false;logOnce("provider registration failed: "..tostring(reason));return false end
    registered=true;return true
  end
  local function install(game)
    if not game or not ensureProvider() then return false end
    mod.__itemIcons.registerGame(game)
    local unlimited,Bag=installUnlimitedInventory(game)
    if not unlimited then logOnce(Bag);return false end
    local ok,BagMenu=pcall(require,"src.ui.BagMenu")
    if not ok or type(BagMenu)~="table" or type(BagMenu.new)~="function" then
      logOnce("src.ui.BagMenu unavailable");return false end
    local dispatch=rawget(_G,PATCH_KEY)
    if not dispatch then
      dispatch={baseNew=BagMenu.new};rawset(_G,PATCH_KEY,dispatch)
      BagMenu.new=function(currentGame,opts,...)
        local list=dispatch.baseNew(currentGame,opts,...)
        return dispatch.decorate and dispatch.decorate(currentGame,opts or {},list) or list
      end
    end
    dispatch.decorate=function(currentGame,opts,list)
      return decorateBag(currentGame,opts,list,mod,Bag)
    end
    return true
  end

  mod.exports.apiVersion=2
  mod.exports.itemIconApiVersion=IconCatalog.API_VERSION
  mod.exports.core=Core;mod.exports.actions=Actions;mod.exports.snapshot=providerSnapshot
  mod.exports.ensureProvider=ensureProvider
  mod.exports.resolveItemIcon=mod.__itemIcons.resolveItemIcon
  mod.exports.hasDedicatedItemIcon=mod.__itemIcons.hasDedicatedItemIcon
  mod.exports.auditItemIcons=mod.__itemIcons.auditItemIcons
  mod.exports.invalidateItemIconCache=mod.__itemIcons.invalidateItemIconCache
  mod.exports.registerClassification=function(id,pocket)
    if type(id)~="string" or id=="" then return false end
    if pocket~="medicine" and pocket~="balls" and pocket~="machines"
        and pocket~="battle" and pocket~="key" and pocket~="items" then return false end
    mod.__classificationOverrides[id]=pocket;return true
  end
  if mod.events and type(mod.events.on)=="function" then
    mod.events:on("game.ready",function(event)
      if install(event and event.game) and mod.log then
        mod.log:info("Widescreen Modern Bag alpha 5 installed") end
    end)
    mod.events:on("mods.loaded",function() ensureProvider() end)
  end
  ensureProvider()
end
