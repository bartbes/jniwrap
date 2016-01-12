local basename = ...
if basename:match("init$") then
	basename = basename:sub(1, -5)
else
	basename = basename .. "."
end

require(basename .. "cdefs")
local inifile = require(basename .. "inifile")
local ffi = require "ffi"

local simpleTypeSignatures =
{
	boolean = "Z",
	byte = "B",
	char = "C",
	short = "S",
	int = "I",
	long = "J",
	float = "F",
	double = "D",
	void = "V",
}
local invSimpleTypeSignatures = {}
local instance = {}

for i, v in pairs(simpleTypeSignatures) do
	invSimpleTypeSignatures[v] = i
end

local jniwrap = {}

function jniwrap.signatureFor(typename)
	if simpleTypeSignatures[typename] then
		return simpleTypeSignatures[typename]
	end
	if typename:match("%[%]$") then
		return "[" .. jniwrap.signatureFor(typename:sub(1, -3))
	end
	return "L" .. typename:gsub("%.", "/") .. ";"
end

function jniwrap.calculateSignature(method)
	local args = {}
	for i = 1, math.huge do
		local arg = method["arg" .. i]
		if not arg then break end
		table.insert(args, jniwrap.signatureFor(arg))
	end

	local rettype = jniwrap.signatureFor(method.returnType or "void")

	return ("(%s)%s"):format(table.concat(args), rettype), rettype
end

function jniwrap.wrapObject(object, class)
	return setmetatable({[instance] = object}, {__index = class})
end

function jniwrap.wrapMethod(env, class, name, def, out)
	local signature, rettype = jniwrap.calculateSignature(def)
	print("Signature for ", name, " is ", signature)

	local methodid
	local callf = "Call"
	if def.static then
		methodid = env[0].GetStaticMethodID(env, class, name, signature)
		callf = callf .. "Static"
	else
		methodid = env[0].GetMethodID(env, class, name, signature)
	end

	rettype = invSimpleTypeSignatures[rettype] or "object"
	rettype = rettype:sub(1, 1):upper() .. rettype:sub(2)
	callf = callf .. rettype .. "Method"

	if def.static then
		return function(...)
			return env[0][callf](env, class, methodid, ...)
		end
	elseif def.constructor then
		return function(...)
			local obj = env[0].NewObject(env, class, methodid, ...)
			return jniwrap.wrapObject(obj, out)
		end
	else
		return function(self, ...)
			return env[0][callf](env, self[instance], methodid, ...)
		end
	end
end

function jniwrap.wrapClass(env, definition)
	if type(definition) == "string" then
		definition = inifile.parse(definition)
	end

	local out = {}
	local classname = definition.class.name:gsub("%.", "/")
	local class = env[0].FindClass(env, classname)
	class = ffi.cast("jclass", env[0].NewGlobalRef(env, class))
	-- TODO DeleteGlobalRef

	definition.class = nil

	for i, v in pairs(definition) do
		local name = v.name or i
		local type = v.type or "method"
		if v.constructor then
			name = "<init>"
		end

		if type == "method" then
			out[i] = jniwrap.wrapMethod(env, class, name, v, out)
		end
	end

	return out
end

function jniwrap.fromJavaString(env, str)
	local isCopy = ffi.new("jboolean[1]")
	local chars = env[0].GetStringUTFChars(env, str, isCopy)
	local length = env[0].GetStringUTFLength(env, str)

	local luastr = ffi.string(chars, length)
	return (luastr:gsub(string.char(0xc0, 0x80), "\0"))
end

function jniwrap.toJavaString(env, str)
end

return jniwrap
