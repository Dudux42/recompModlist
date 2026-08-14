-- Canonical ID normalization. Keep species, move, map, and trainer namespaces
-- distinct so a permissive alias in one cannot corrupt another.
local Normalize = {}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function token(value)
  local text = trim(value)
  text = text:gsub("♀", "_F"):gsub("♂", "_M")
  text = text:upper():gsub("[^A-Z0-9]+", "_")
  text = text:gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
  return text
end

local SPECIES_ALIASES = {
  NIDORANF = "NIDORAN_F",
  NIDORAN_FEMALE = "NIDORAN_F",
  NIDORANM = "NIDORAN_M",
  NIDORAN_MALE = "NIDORAN_M",
  FARFETCH_D = "FARFETCHD",
  MRMIME = "MR_MIME",
}

local MOVE_ALIASES = {
  PSYCHIC = "PSYCHIC_M",
  PSYCHIC_MOVE = "PSYCHIC_M",
}

function Normalize.token(value)
  return token(value)
end

function Normalize.species(value)
  local id = token(value)
  return SPECIES_ALIASES[id] or id
end

function Normalize.move(value)
  local id = token(value)
  return MOVE_ALIASES[id] or id
end

function Normalize.map(value)
  return token(value)
end

function Normalize.trainer(value)
  local id = token(value)
  if id ~= "" and id:sub(1, 4) ~= "OPP_" then id = "OPP_" .. id end
  return id
end

function Normalize.item(value)
  return token(value)
end

function Normalize.type(value)
  return token(value)
end

return Normalize
