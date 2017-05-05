local path = ...
local basename = path:match("^(.+)%.classloader$")
local jniwrap = require(basename .. ".init")
local ffi = require "ffi"

local cl = {}

cl.loaders = {}
function cl.loaders.io(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local contents = f:read("*a")
	f:close()
	return contents
end

function cl.loaders.love(path)
	if not love.filesystem.isFile(path) then return nil end
	return love.filesystem.read(path)
end

function cl:setLoader(nameOrLoader)
	if type(nameOrLoader) == "string" then
		self.loader = assert(self.loaders[nameOrLoader], "No such loader")
	elseif type(nameOrLoader) == "function" then
		self.loader = nameOrLoader
	else
		error("Invalid argument")
	end
end

cl.isAndroid = false
cl.prefix = "."
function cl:setPrefix(prefix)
	self.prefix = prefix
end

function cl:setAndroid(android)
	self.isAndroid = android
end

local function load(className)
	local ext = ".class"
	if cl.isAndroid then
		ext = ".dex"
	end
	local path = cl.prefix .. "/" .. className:gsub("%.", "/") .. ext
	assert(cl.loader, "No loader set, call setLoader first!")
	return cl.loader(path)
end

local javaClassLoaderDef =
{
	class = {name = "java.lang.ClassLoader"},
	getSystemClassLoader = {static = true, returnType = "self"},
}

local customClassLoaderName = "com.bartbes.jniwrap.ClassLoader"
local customClassLoaderDef =
{
	class = {name = customClassLoaderName},
	ClassLoader = {constructor = true},
	findClass = {arg1 = "String", returnType = "Class"},
	loadClass = {arg1 = "String", returnType = "Class"},
}

local ClassDef =
{
	class = {name = "java.lang.Class"},
	forNameWithLoader = {name = "forName", static = true, arg1 = "String", arg2 = "boolean", arg3 = "java.lang.ClassLoader", returnType = "self"},
	getName = {returnType = "String"},
}

local customClassLoader, Class

function cl:inject()
	local javaClassLoader = jniwrap.wrapClass(javaClassLoaderDef)
	local systemClassLoader = javaClassLoader.getSystemClassLoader()

	local bytecode = assert(load(customClassLoaderName), "Could not find com.bartbes.jniwrap.ClassLoader")
	local loader = jniwrap.env.DefineClass(customClassLoaderName:gsub("%.", "/"), jniwrap.unbox(systemClassLoader), bytecode, #bytecode)

	local methods = ffi.new("JNINativeMethod[1]")
	methods[0].name = "luaLoad"
	methods[0].signature = jniwrap.calculateSignature({arg1 = "String", returnType = "byte[]"}, {})
	methods[0].fnPtr = ffi.cast("void*(*)(void*, void*, void*)", function(env, object, name)
		local bytecode = load(jniwrap.fromJavaString(name))
		if not bytecode then return nil end

		local arr = jniwrap.newArray("byte", #bytecode)
		for i = 1, #bytecode do
			arr[i-1] = bytecode:byte(i)
		end

		return jniwrap.unwrapArray(arr)
	end)

	jniwrap.env.RegisterNatives(loader, methods, 1)

	local CustomClassLoader = jniwrap.wrapClass(customClassLoaderDef)
	customClassLoader = CustomClassLoader.ClassLoader()
	Class = jniwrap.wrapClass(ClassDef)

	function jniwrap.findClass(name)
		return jniwrap.unbox(self:load(name))
	end
end

function cl:load(class)
	if not customClassLoader then
		self:inject()
	end
	return Class.forNameWithLoader(class, true, customClassLoader)
end

return cl
