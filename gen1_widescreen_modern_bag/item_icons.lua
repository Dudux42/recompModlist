-- Stable item-icon catalog for Widescreen Modern Bag.
-- Asset files are flat/root-only. The current alpha source intentionally
-- reports them missing until the supplied strips pass extraction/provenance QA.

local Catalog={API_VERSION=1}

local MAP={
  ANTIDOTE="bag_item_antidote.png", AWAKENING="bag_item_awakening.png",
  BICYCLE="bag_item_bicycle.png", BIKE_VOUCHER="bag_item_bike_voucher.png",
  BURN_HEAL="bag_item_burn_heal.png", CALCIUM="bag_item_calcium.png",
  CARBOS="bag_item_carbos.png", CARD_KEY="bag_item_card_key.png",
  COIN_CASE="bag_item_coin_case.png", DIRE_HIT="bag_item_dire_hit.png",
  DOME_FOSSIL="bag_item_dome_fossil.png", ITEMFINDER="bag_item_itemfinder.png",
  ELIXER="bag_item_elixer.png", ESCAPE_ROPE="bag_item_escape_rope.png",
  ETHER="bag_item_ether.png", EXP_ALL="bag_item_exp_all.png",
  FIRE_STONE="bag_item_fire_stone.png", FRESH_WATER="bag_item_fresh_water.png",
  FULL_HEAL="bag_item_full_heal.png", FULL_RESTORE="bag_item_full_restore.png",
  GOLD_TEETH="bag_item_gold_teeth.png", GOOD_ROD="bag_item_good_rod.png",
  GREAT_BALL="bag_item_great_ball.png", GUARD_SPEC="bag_item_guard_spec.png",
  HELIX_FOSSIL="bag_item_helix_fossil.png", HP_UP="bag_item_hp_up.png",
  HYPER_POTION="bag_item_hyper_potion.png", ICE_HEAL="bag_item_ice_heal.png",
  IRON="bag_item_iron.png", LEAF_STONE="bag_item_leaf_stone.png",
  LEMONADE="bag_item_lemonade.png", LIFT_KEY="bag_item_lift_key.png",
  MASTER_BALL="bag_item_master_ball.png", MAX_ELIXER="bag_item_max_elixer.png",
  MAX_ETHER="bag_item_max_ether.png", MAX_POTION="bag_item_max_potion.png",
  MAX_REPEL="bag_item_max_repel.png", MAX_REVIVE="bag_item_max_revive.png",
  MOON_STONE="bag_item_moon_stone.png", NUGGET="bag_item_nugget.png",
  OLD_AMBER="bag_item_old_amber.png", OLD_ROD="bag_item_old_rod.png",
  PARLYZ_HEAL="bag_item_parlyz_heal.png", OAKS_PARCEL="bag_item_oaks_parcel.png",
  POKE_BALL="bag_item_poke_ball.png", POKE_DOLL="bag_item_poke_doll.png",
  POKE_FLUTE="bag_item_poke_flute.png", POTION="bag_item_potion.png",
  PP_UP="bag_item_pp_up.png", PROTEIN="bag_item_protein.png",
  RARE_CANDY="bag_item_rare_candy.png", REPEL="bag_item_repel.png",
  REVIVE="bag_item_revive.png", SAFARI_BALL="bag_item_safari_ball.png",
  SECRET_KEY="bag_item_secret_key.png", SILPH_SCOPE="bag_item_silph_scope.png",
  SODA_POP="bag_item_soda_pop.png", S_S_TICKET="bag_item_ss_ticket.png",
  SUPER_POTION="bag_item_super_potion.png", SUPER_REPEL="bag_item_super_repel.png",
  SUPER_ROD="bag_item_super_rod.png", THUNDER_STONE="bag_item_thunder_stone.png",
  TOWN_MAP="bag_item_town_map.png", ULTRA_BALL="bag_item_ultra_ball.png",
  WATER_STONE="bag_item_water_stone.png", X_ACCURACY="bag_item_x_accuracy.png",
  X_ATTACK="bag_item_x_attack.png", X_DEFEND="bag_item_x_defend.png",
  X_SPECIAL="bag_item_x_special.png", X_SPEED="bag_item_x_speed.png",
}

local ALIASES={
  PARALYZE_HEAL="PARLYZ_HEAL",ELIXIR="ELIXER",MAX_ELIXIR="MAX_ELIXER",
  OAK_PARCEL="OAKS_PARCEL",PARCEL="OAKS_PARCEL",SS_TICKET="S_S_TICKET",
  X_DEFENSE="X_DEFEND",
}

Catalog.baseMapping=MAP

local function sortedKeys(value)
  local out={}
  for key in pairs(value) do out[#out+1]=key end
  table.sort(out)
  return out
end

function Catalog.new(mod)
  local paths={}
  for id,path in pairs(MAP) do paths[id]=path end
  for alias,canonical in pairs(ALIASES) do paths[alias]=MAP[canonical] end
  local cache={}
  local api={}

  function api.registerGame(game)
    local items=game and game.data and game.data.items or {}
    for id,def in pairs(items) do
      if type(id)=="string" and type(def)=="table" and type(def.machine)=="table" then
        local kind=tostring(def.machine.kind or ""):upper()
        if kind~="TM" and kind~="HM" then
          kind=tostring(id):upper():match("^(TM)") or tostring(id):upper():match("^(HM)")
        end
        if kind=="TM" then paths[id]="bag_item_tm.png"
        elseif kind=="HM" then paths[id]="bag_item_hm.png" end
      end
    end
  end

  local function exists(path)
    if cache[path]~=nil then return cache[path] end
    local ok,value=pcall(function() return mod:read(path) end)
    cache[path]=ok and value~=nil and value~=false
    return cache[path]
  end

  function api.resolveItemIcon(itemId,category)
    local path=paths[itemId]
    if path and exists(path) then
      local resolved=mod.assets and type(mod.assets.path)=="function"
        and mod.assets:path(path) or path
      return {itemId=itemId,imagePath=resolved,sourceW=32,sourceH=32,
        fallback=false,category=category}
    end
    return {itemId=itemId,fallback=true,category=category or "items"}
  end

  function api.hasDedicatedItemIcon(itemId)
    return paths[itemId]~=nil and exists(paths[itemId])
  end

  function api.auditItemIcons(game)
    api.registerGame(game)
    local missing,mapped,fallback={},{},{}
    local items=game and game.data and game.data.items or {}
    for id,def in pairs(items) do
      if type(id)=="string" and type(def)=="table" then
        if paths[id] then
          mapped[#mapped+1]=id
          if not exists(paths[id]) then missing[#missing+1]=id end
        elseif not tostring(id):find("BADGE",1,true) then fallback[#fallback+1]=id end
      end
    end
    table.sort(missing);table.sort(mapped);table.sort(fallback)
    return {missing=missing,mapped=mapped,fallback=fallback,
      declared=sortedKeys(paths),excluded={}}
  end

  function api.invalidateItemIconCache()
    cache={}
  end

  function api.mapping()
    local out={};for id,path in pairs(paths) do out[id]=path end;return out
  end
  return api
end

return Catalog
