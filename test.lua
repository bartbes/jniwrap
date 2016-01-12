local function main()
	local jni = require "jniwrap.init"
	local ffi = require "ffi"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()

	local ExtraTest = jni.wrapClass(env, "ExtraTest.ini")
	ExtraTest.someJava()
	local e = ExtraTest.ExtraTest()
	e:someMoreJava()

	local UUID = jni.wrapClass(env, "UUID.ini")
	local u = jni.wrapObject(UUID.randomUUID(), UUID)
	print(jni.fromJavaString(env, u:toString()))
end

xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
