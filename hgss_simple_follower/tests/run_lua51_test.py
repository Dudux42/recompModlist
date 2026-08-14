"""Run a Lua smoke test with Gen1Recomp's Lua 5.1 DLL."""
import ctypes
import os
import sys

dll = ctypes.CDLL(os.environ.get("GEN1RECOMP_LUA51", r"F:\Games\gen1recomp-win64\lua51.dll"))
path = os.path.abspath(sys.argv[1])
dll.luaL_newstate.restype = ctypes.c_void_p
dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
dll.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
dll.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
dll.lua_tolstring.restype = ctypes.c_char_p
dll.lua_close.argtypes = [ctypes.c_void_p]
state = dll.luaL_newstate()
dll.luaL_openlibs(state)
status = dll.luaL_loadfile(state, os.fsencode(path))
if status == 0:
    status = dll.lua_pcall(state, 0, 0, 0)
if status:
    size = ctypes.c_size_t()
    message = dll.lua_tolstring(state, -1, ctypes.byref(size))
    print(message.decode("utf-8", errors="replace") if message else "unknown Lua error")
dll.lua_close(state)
raise SystemExit(status)
