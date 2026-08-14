-- External test adapter for the unstamped engine source checkout.
-- This file is deliberately outside the mod, so it grants the shipped mod no
-- private-engine dependency or engine_internals permission.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Version = require("src.core.Version")
local originalEngineVersion = Version.engine
Version.engine = "0.1.71"

local ok, err = pcall(dofile, "mods/gen1_balances/tests.lua")
Version.engine = originalEngineVersion
if not ok then error(err, 0) end
