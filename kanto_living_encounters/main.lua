-- Kanto Living Encounters 0.1.0-alpha.4
-- Visible wild entities only. Native step encounters remain untouched.

return function(mod)
  local function loadModule(name)
    local body = mod:read(name)
    assert(type(body) == "string", name .. " is missing")
    local chunk, err = loadstring(body, "@" .. name)
    assert(chunk, err)
    return chunk()
  end

  local Core = loadModule("kle_core.lua")
  local Tables = loadModule("kle_tables.lua")(Core)
  local Runtime = loadModule("kle_runtime.lua")(Core, Tables)

  mod.options:define({
    {
      key = "enabled", type = "toggle", label = "VISIBLE POKEMON",
      default = true,
      help = "Show visible wild Pokemon. Classic random encounters are unchanged.",
    },
    {
      key = "aggressive", type = "toggle", label = "AGGRESSIVE POKEMON",
      default = true,
      help = "Allow wild Pokemon to notice, rush, and battle the player.",
    },
    {
      key = "amount", type = "choice", label = "AMOUNT", default = "regular",
      choices = {
        { "Few (2-4)", "few" },
        { "Regular (5-8)", "regular" },
        { "Many (9-12)", "many" },
      },
      help = "Target visible count; unsafe or crowded maps may contain fewer.",
    },
    {
      key = "towns", type = "toggle", label = "TOWN POKEMON", default = true,
      help = "Show cosmetic town Pokemon drawn from explicit surrounding routes.",
    },
    {
      key = "debug", type = "toggle", label = "DEBUG OVERLAY", default = false,
      help = "Show area, live-table, cell, target, and active-spawn diagnostics.",
    },
  })

  local runtime = Runtime.install(mod)
  mod.exports.version = Core.VERSION
  mod.exports.schemaVersion = Core.SCHEMA_VERSION
  mod.exports.resolveSpawnTable = runtime.resolveSpawnTable
  mod.exports.getSpawnSnapshot = runtime.getSpawnSnapshot
  mod.exports.getEffectiveSpawnSnapshot = runtime.getEffectiveSpawnSnapshot
  mod.exports.invalidateSpawnTables = runtime.invalidate
  mod.exports.restore = runtime.restore

  if mod.log then
    mod.log:info("Kanto Living Encounters %s loaded", Core.VERSION)
  end
end
