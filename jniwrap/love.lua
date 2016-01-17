local jniwrap = require((...):match("^(.+)%.love$") .. ".init")
local ffi = require "ffi"

ffi.cdef [[
	JNIEnv *SDL_AndroidGetJNIEnv();
	jobject SDL_AndroidGetActivity();
]]

local env = ffi.C.SDL_AndroidGetJNIEnv()
jniwrap.setEnv(env)

local activity = ffi.C.SDL_AndroidGetActivity()

return {env = env, activity = activity}
