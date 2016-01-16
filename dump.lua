local jni
local inifile = require "jniwrap.inifile"
local bit = require "bit"

local function main()
	jni = require "jniwrap.init"
	local ffi = require "ffi"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()
	jni.setEnv(env)

	print(inifile.save("", jni.dumpClass("java.lang.Math"), "memory"))
end

xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
