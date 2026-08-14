-- Small compatibility helpers shared by every module. Lua 5.1 only.
local Compat = {}

local function fail(relative, message)
  error(("unable to load %s: %s"):format(tostring(relative), tostring(message)), 0)
end

function Compat.load(mod, relative)
  local body, readError = mod:read(relative)
  if type(body) ~= "string" then
    fail(relative, readError or "file is missing")
  end

  local loader = loadstring or load
  local chunk, syntaxError = loader(body, "@" .. relative)
  if not chunk then fail(relative, syntaxError or "syntax error") end

  local ok, value = pcall(chunk)
  if not ok then fail(relative, value) end
  if value == nil then fail(relative, "module returned nil") end
  return value
end

function Compat.count(value)
  local total = 0
  for _ in pairs(value or {}) do total = total + 1 end
  return total
end

function Compat.sortedKeys(value)
  local keys = {}
  for key in pairs(value or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

function Compat.deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[Compat.deepCopy(key, seen)] = Compat.deepCopy(item, seen)
  end
  return copy
end

return Compat
