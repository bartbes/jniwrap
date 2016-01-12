local function main()
	local jni = require "jniwrap.init"
	local ffi = require "ffi"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()
	jni.setEnv(env)

	-- My own class, for testing
	local ExtraTest = jni.wrapClass("ExtraTest.ini")
	ExtraTest.someJava()
	local e = ExtraTest.ExtraTest()
	e:someMoreJava()

	-- java.util.UUID
	local UUID = jni.wrapClass("UUID.ini")
	local u = jni.wrapObject(UUID.randomUUID(), UUID)
	print(jni.fromJavaString(u:toString()))
end

-- The launcher doesn't have error checking, so here's an xpcall instead
xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
