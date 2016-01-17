local function main()
	local jni = require "jniwrap.init"
	local import = require "jniwrap.import"
	local ffi = require "ffi"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()
	jni.setEnv(env)

	import:setPrefix("def")

	-- My own class, for testing
	local ExtraTest = import "ExtraTest"
	ExtraTest.someJava()
	local e = ExtraTest.ExtraTest()
	e:someMoreJava()
	e:printString(jni.toJavaString("Hello, world!"))

	print(e:myIntField())
	e:myIntField(21)
	e:doubleInt()
	assert(e:myIntField() == 42)

	local ints = jni.wrapArray("int", e:getIntValues())
	for i, v in ints:ipairs() do
		print(("Integer %d: %d"):format(i+1, v))
	end

	local constants = jni.wrapArray("double", e:mathConstants())
	assert(math.pi-constants[0] < 0.1)
	constants[2] = 2
	assert(e:getSqrtTwo() == 2)

	-- java.util.UUID
	local UUID = import "java.util.UUID"
	local u = UUID(UUID.randomUUID())
	print(jni.fromJavaString(u:toString()))
end

-- The launcher doesn't have error checking, so here's an xpcall instead
xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
