"""Run Lua with Gen1Recomp's exact Lua 5.1 DLL and a release-version stamp."""

import ctypes
import os
import sys


dll_path = os.environ.get(
    "GEN1RECOMP_LUA51", r"F:\Games\gen1recomp-win64\lua51.dll"
)
script_path = os.path.abspath(sys.argv[1])

lua = ctypes.CDLL(dll_path)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]

state = lua.luaL_newstate()
if not state:
    raise SystemExit("could not allocate Lua state")

lua.luaL_openlibs(state)
stamp = b'require("src.core.Version").engine = "0.1.71"'
status = lua.luaL_loadstring(state, stamp)
if status == 0:
    status = lua.lua_pcall(state, 0, 0, 0)
if status == 0:
    status = lua.luaL_loadfile(state, os.fsencode(script_path))
if status == 0:
    status = lua.lua_pcall(state, 0, 0, 0)

if status != 0:
    size = ctypes.c_size_t()
    message = lua.lua_tolstring(state, -1, ctypes.byref(size))
    print(message.decode("utf-8", errors="replace") if message else "unknown Lua error")

lua.lua_close(state)
raise SystemExit(status)
