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
local typeAliases =
{
	Boolean = "Ljava/lang/Boolean;",
	Byte = "Ljava/lang/Byte;",
	Character = "Ljava/lang/Character;",
	Class = "Ljava/lang/Class;",
	Double = "Ljava/lang/Double;",
	Exception = "Ljava/lang/Exception;",
	Float = "Ljava/lang/Float;",
	Integer = "Ljava/lang/Integer;",
	Long = "Ljava/lang/Long;",
	Object = "Ljava/lang/Object;",
	Short = "Ljava/lang/Short;",
	String = "Ljava/lang/String;",
	Throwable = "Ljava/lang/Throwable;",
	Void = "Ljava/lang/Void;",
}

for i, v in pairs(simpleTypeSignatures) do
	invSimpleTypeSignatures[v] = i
end

local jniwrap = {}
local env
local instance = {}

function jniwrap.setEnv(_env)
	env = _env
end

function jniwrap.signatureFor(typename, aliases)
	if simpleTypeSignatures[typename] then
		return simpleTypeSignatures[typename]
	end
	if typeAliases[typename] then
		return typeAliases[typename]
	end
	if aliases[typename] then
		return jniwrap.signatureFor(aliases[typename], aliases)
	end
	if typename:match("%[%]$") then
		return "[" .. jniwrap.signatureFor(typename:sub(1, -3))
	end
	return "L" .. typename:gsub("%.", "/") .. ";"
end

function jniwrap.calculateSignature(method, aliases)
	local args = {}
	for i = 1, math.huge do
		local arg = method["arg" .. i]
		if not arg then break end
		table.insert(args, jniwrap.signatureFor(arg, aliases))
	end

	local rettype = jniwrap.signatureFor(method.returnType or "void", aliases)

	return ("(%s)%s"):format(table.concat(args), rettype), rettype
end

function jniwrap.wrapObject(class, object)
	return setmetatable({[instance] = object}, {__index = class})
end

function jniwrap.wrapMethod(class, name, def, out, aliases)
	local signature, rettype = jniwrap.calculateSignature(def, aliases)
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
			return jniwrap.wrapObject(out, obj)
		end
	else
		return function(self, ...)
			return env[0][callf](env, self[instance], methodid, ...)
		end
	end
end

function jniwrap.wrapClass(definition)
	if type(definition) == "string" then
		definition = inifile.parse(definition)
	end

	local out = {}
	local classname = definition.class.name:gsub("%.", "/")
	local class = env[0].FindClass(env, classname)
	class = ffi.cast("jclass", env[0].NewGlobalRef(env, class))
	ffi.gc(class, function()
		env[0].DeleteGlobalRef(env, class)
	end)

	definition.class = nil

	local aliases = {self = classname}
	if definition[":aliases:"] then
		for i, v in pairs(definition[":aliases:"]) do
			aliases[i] = v
		end
		definition[":aliases:"] = nil
	end

	for i, v in pairs(definition) do
		local name = v.name or i
		local type = v.type or "method"
		if v.constructor then
			name = "<init>"
		end

		if type == "method" then
			out[i] = jniwrap.wrapMethod(class, name, v, out, aliases)
		end
	end

	setmetatable(out, {__call = jniwrap.wrapObject})
	return out
end

function jniwrap.fromJavaString(str)
	local chars = env[0].GetStringUTFChars(env, str, nil)
	local length = env[0].GetStringUTFLength(env, str)
	local luastr = ffi.string(chars, length)
	env[0].ReleaseStringUTFChars(env, str, chars)
	return (luastr:gsub(string.char(0xc0, 0x80), "\0"))
end

function jniwrap.toJavaString(str)
end

return jniwrap
