print("Hello from lua!")

local ffi = require "ffi"

local function main()
	local f = io.open("jni.def", "r")
	local contents = f:read("*a")
	ffi.cdef(contents)
	f:close()

	ffi.cdef [[
		JNIEnv *getGlobalEnv();
	]]

	local realenv = ffi.C.getGlobalEnv()
	local env = setmetatable({},
	{
		__index = function(self, name, value)
			local actual = realenv[0][name]
			if not actual then return end
			local wrapper = function(...)
				return actual(realenv, ...)
			end
			rawset(self, name, wrapper)
			return wrapper
		end,
	})

	print(("%x"):format(env.GetVersion()))

	local ExtraTest = env.FindClass("ExtraTest")
	local ExtraTest_someJava = env.GetStaticMethodID(ExtraTest, "someJava", "()V")
	env.CallStaticVoidMethod(ExtraTest, ExtraTest_someJava)

	local ExtraTest_constructor = env.GetMethodID(ExtraTest, "<init>", "()V")
	local instance = env.NewObject(ExtraTest, ExtraTest_constructor)
	local ExtraTest_someMoreJava = env.GetMethodID(ExtraTest, "someMoreJava", "()V")
	env.CallVoidMethod(instance, ExtraTest_someMoreJava)
end

xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
