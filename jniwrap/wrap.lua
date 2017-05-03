local ffi = require "ffi"

return function(jniwrap)
	local instance = {}

	local ThrowableDef =
	{
		class = {name = "java.lang.Throwable"},
		toString = {returnType = "String"},
	}

	local inException = false
	local Throwable
	local function errorOnException()
		if jniwrap.env.ExceptionCheck() == 0 then return end

		-- Deal with exceptions during exception handling
		if inException then
			error("Exception handling exception")
		end
		inException = true

		-- Now get and clear (!) our exception
		local exception = jniwrap.env.ExceptionOccurred()
		jniwrap.env.ExceptionDescribe()
		jniwrap.env.ExceptionClear()

		-- Try to wrap throwable
		if not Throwable then
			Throwable = jniwrap.wrapClass(ThrowableDef)
		end
		exception = Throwable(exception)

		-- Now finally we get to extract data
		local message = jniwrap.fromJavaString(exception:toString())

		-- We're safe, we've handled the exception
		inException = false

		-- And finally create an error
		error(message)
	end

	local function generateAutobox(type, input)
		local elementtype = type:match("^(.-)%[%]$")
		if elementtype then
			return ("jni.wrapArray(%q, %s)"):format(elementtype, input)
		elseif type == "java.lang.String" then
			return ("jni.fromJavaString(%s)"):format(input)
		elseif not jniwrap.simpleTypeSignatures[type] then
			return ("box(%q, %s)"):format(type, input)
		end
		return input
	end

	local function generateAutounbox(type, input)
		local elementtype = type:match("^(.-)%[%]$")
		if elementtype then
			return ("jni.unwrapArray(%s)"):format(input)
		elseif type == "java.lang.String" then
			return ("jni.toJavaString(%s)"):format(input)
		elseif not jniwrap.simpleTypeSignatures[type] then
			return ("unbox(%s)"):format(input)
		end
		return input
	end

	function jniwrap.wrapMethod(class, name, def, out, aliases, luaName)
		local signature, retsig, rettype = jniwrap.calculateSignature(def, aliases)

		local callf = ""
		local gmidf = "GetMethodID"

		callf = jniwrap.invSimpleTypeSignatures[retsig] or "Object"
		callf = callf:sub(1, 1):upper() .. callf:sub(2)

		if def.static then
			gmidf = "GetStaticMethodID"
			callf = "Static" .. callf
		end

		callf = "Call" .. callf .. "Method"

		local paramDef = {}
		local paramCall = {""}
		local classOrSelf = "class"

		if not def.static and not def.constructor then
			paramDef[1] = "self"
			classOrSelf = "unbox(self)"
		end
		if def.constructor then
			callf = "NewObject"
			rettype = aliases.self
		end

		local box = generateAutobox(rettype, "result")

		for i = 1, math.huge do
			local arg = "arg" .. i
			local type = def[arg] and jniwrap.resolveAliases(def[arg], aliases)
			if not type then break end
			table.insert(paramDef, arg)
			table.insert(paramCall, generateAutounbox(type, arg))
		end

		paramDef = table.concat(paramDef, ", ")
		paramCall = table.concat(paramCall, ", ")

		return ([[
			methodids.%s = env.%s(class, %q, %q)
			function wrapper.%s(%s)
				local result = env.%s(%s, methodids.%s%s)
				return %s
			end
		]]):format(luaName, gmidf, name, signature, luaName, paramDef, callf, classOrSelf, luaName, paramCall, box)
	end

	function jniwrap.wrapField(class, name, def, out, aliases, luaName)
		local signature = jniwrap.signatureFor(def.type, aliases)
		local rettype = jniwrap.resolveAliases(def.type, aliases)

		local gfidf = "GetFieldID"
		local callf = ""
		local self = "self, "
		local classOrInstance = "unbox(self)"

		local callf = jniwrap.invSimpleTypeSignatures[signature] or "Object"
		callf = callf:sub(1, 1):upper() .. callf:sub(2)
		callf = callf .. "Field"

		if def.static then
			fieldid = jniwrap.env.GetStaticFieldID(class, name, signature)
			gfidf = "GetStaticFieldID"
			callf = "Static" .. callf
			classOrInstance = "class"
			self = ""
		end

		local box = generateAutobox(rettype, "result")
		local setArg = generateAutounbox(rettype, "(...)")

		-- TODO: Separate getter/setter?
		return ([[
			fieldids.%s = env.%s(class, %q, %q)
			function wrapper.%s(%s...)
				if select("#", ...) > 0 then
					return env.Set%s(%s, fieldids.%s, %s)
				else
					local result = env.Get%s(%s, fieldids.%s)
					return %s
				end
			end
		]]):format(luaName, gfidf, name, signature, luaName, self, callf, classOrInstance, luaName, setArg, callf, classOrInstance, luaName, box)
	end

	function jniwrap.wrapClass(definition)
		if type(definition) == "string" then
			definition = jniwrap.parseIni(definition)
		end

		local out = {}
		local origclassname = definition.class.name
		local classname = definition.class.name:gsub("%.", "/")
		local class = jniwrap.env.FindClass(classname)
		errorOnException()

		class = ffi.cast("jclass", jniwrap.env.NewGlobalRef(class))
		ffi.gc(class, function()
			jniwrap.env.DeleteGlobalRef(class)
		end)

		out[1] = [[
			local jni, env, name, class = ...

			local box = jni.box
			local unbox = jni.unbox

			local fieldids, methodids = {}, {}
			local wrapper = jni.boxFor(name)
		]]

		definition.class = nil

		local aliases = {self = origclassname}
		if definition[":aliases:"] then
			for i, v in pairs(definition[":aliases:"]) do
				aliases[i] = v
			end
			definition[":aliases:"] = nil
		end

		for i, v in pairs(definition) do
			local name = v.name or i
			if v.constructor then
				name = "<init>"
			end

			if v.field then
				table.insert(out, jniwrap.wrapField(class, name, v, out, aliases, i))
				errorOnException()
			else
				table.insert(out, jniwrap.wrapMethod(class, name, v, out, aliases, i))
				errorOnException()
			end
		end

		table.insert(out, [[
			return wrapper
		]])

		local code = table.concat(out, "\n")
		--[[local lineNo = 0
		for line in code:gmatch("(.-)\n") do
			lineNo = lineNo + 1
			print(lineNo, line)
		end]]
		local f = loadstring(code, "Generated code for java class " .. origclassname)
		return f(jniwrap, jniwrap.env, origclassname, class)
	end

	local wrappers = {}
	local mts = {}
	function jniwrap.boxFor(className)
		if not wrappers[className] then
			wrappers[className] = {}
		end
		return wrappers[className]
	end

	function jniwrap.box(className, object)
		if not mts[className] then
			mts[className] = {__index = jniwrap.boxFor(className)}
		end
		jniwrap.doGc(object)
		return setmetatable({[instance] = object}, mts[className])
	end

	function jniwrap.unbox(obj)
		return obj[instance]
	end
end
