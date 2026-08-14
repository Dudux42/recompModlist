-- Gen1 Unified Quality of Life 0.1.0-alpha.6

return function(mod)
  local compile = loadstring or load

  local function loadModule(path)
    local source, readError = mod:read(path)
    if not source then
      mod.log:error("cannot read %s: %s", path, tostring(readError))
      error("cannot read " .. path, 0)
    end
    local chunk, compileError = compile(source, "@" .. mod.path .. "/" .. path)
    if not chunk then
      mod.log:error("cannot compile %s: %s", path, tostring(compileError))
      error("cannot compile " .. path, 0)
    end
    return chunk()
  end

  local options = loadModule("qol_options.lua").install(mod)
  local overlay = loadModule("qol_overlay.lua").new(mod, options)

  loadModule("qol_catch.lua").install(mod, options, overlay)
  loadModule("qol_exp.lua").install(mod, options)
  loadModule("qol_locations.lua").install(mod, options)
  local hmTm = loadModule("qol_hm_tm.lua").install(mod, options)
  loadModule("qol_field.lua").install(mod, options, hmTm)

  overlay:install()
  mod.exports.version = "0.1.0-alpha.6"
  mod.exports.optionValue = options.value
  mod.exports.screenId = options.screenId
  mod.log:info("Gen1 Unified Quality of Life 0.1.0-alpha.6 loaded")
end
