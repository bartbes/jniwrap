local jni, import, classloader

local function main()
	jni = require "jniwrap.init"
	local ffi = require "ffi"
	import = require "jniwrap.import"
	classloader = require "jniwrap.classloader"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()
	jni.setEnv(env)

	import:setPrefix("def")

	classloader:setLoader("io")
	local cl = assert(classloader:load("ClassLoaderTest"), "Could not load class")
	print("Loaded " .. cl:getName())

	local ClassLoaderTest = jni.wrapClass(
	{
		class = {name = "ClassLoaderTest"},
		ClassLoaderTest = {constructor = true},
		run = {},
	})
	local instance = ClassLoaderTest.ClassLoaderTest()
	instance:run()
end

xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
