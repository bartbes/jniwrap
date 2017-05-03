local ffi = require "ffi"

return function(jniwrap)
	local instance = {}
	local private = {}

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

	function jniwrap.wrapMethod(class, name, def, out, aliases, luaName)
		local signature, rettype = jniwrap.calculateSignature(def, aliases)

		local callf = "Call"
		local gmidf = "GetMethodID"
		if def.static then
			gmidf = "GetStaticMethodID"
			callf = callf .. "Static"
		end

		rettype = jniwrap.invSimpleTypeSignatures[rettype] or "object"
		rettype = rettype:sub(1, 1):upper() .. rettype:sub(2)
		callf = callf .. rettype .. "Method"

		local paramDef = {}
		local paramCall = {""}
		local box = ""
		local classOrSelf = "class"

		if not def.static and not def.constructor then
			paramDef[1] = "self"
			classOrSelf = "unbox(self)"
		end
		if def.constructor then
			callf = "NewObject"
		end
		-- TODO: "Box" strings
		-- TODO: Box arrays
		-- TODO: Box to right type
		if rettype == "Object" or def.constructor then
			box = "result = box(result)" -- TODO
		end

		for i = 1, math.huge do
			local arg = "arg" .. i
			if not def[arg] then break end
			table.insert(paramDef, arg)
			if jniwrap.simpleTypeSignatures[def[arg]] then
				table.insert(paramCall, arg)
			elseif def[arg] == "String" then -- TODO canonicalize to java.lang.String
				table.insert(paramCall, "jni.toJavaString(" .. arg .. ")")
			else
				table.insert(paramCall, "unbox(" .. arg .. ")") -- TODO
			end
		end

		paramDef = table.concat(paramDef, ", ")
		paramCall = table.concat(paramCall, ", ")

		return ([[
			methodids.%s = env.%s(class, %q, %q)
			function wrapper.%s(%s)
				local result = env.%s(%s, methodids.%s%s)
				%s
				return result
			end
		]]):format(luaName, gmidf, name, signature, luaName, paramDef, callf, classOrSelf, luaName, paramCall, box)
	end

	function jniwrap.wrapField(class, name, def, out, aliases, luaName)
		local signature = jniwrap.signatureFor(def.type, aliases)

		local gfidf = "GetFieldID"
		local callf = ""
		local self = "self, "
		local classOrInstance = "unbox(self)"

		if def.static then
			fieldid = jniwrap.env.GetStaticFieldID(class, name, signature)
			gfidf = "GetStaticFieldID"
			callf = callf .. "Static"
			classOrInstance = "class"
			self = ""
		end

		local rettype = jniwrap.invSimpleTypeSignatures[signature] or "object"
		rettype = rettype:sub(1, 1):upper() .. rettype:sub(2)
		callf = callf .. rettype .. "Field"

		local box = ""
		if rettype == "Object" then
			box = "result = box(result)" -- TODO
		end

		local setArg = "(...)" -- TODO: Autounboxing

		-- TODO: Separate getter/setter?
		return ([[
			fieldids.%s = env.%s(class, %q, %q)
			function wrapper.%s(%s...)
				if select("#", ...) > 0 then
					return env.Set%s(%s, fieldids.%s, %s)
				else
					local result = env.Get%s(%s, fieldids.%s)
					%s
					return result
				end
			end
		]]):format(luaName, gfidf, name, signature, luaName, self, callf, classOrInstance, luaName, setArg, callf, classOrInstance, luaName, box)
	end

	function jniwrap.wrapClass(definition)
		if type(definition) == "string" then
			definition = jniwrap.parseIni(definition)
		end

		local out = {}
		local classname = definition.class.name:gsub("%.", "/")
		local class = jniwrap.env.FindClass(classname)
		errorOnException()

		class = ffi.cast("jclass", jniwrap.env.NewGlobalRef(class))
		ffi.gc(class, function()
			jniwrap.env.DeleteGlobalRef(class)
		end)

		out[1] = [[
			local jni, env, name, class = ...

			local function box(v)
				return jni.box(name, v)
			end

			local unbox = jni.unbox

			local fieldids, methodids = {}, {}
			local wrapper = jni.boxFor(name)
		]]

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
		local lineNo = 0
		for line in code:gmatch("(.-)\n") do
			lineNo = lineNo + 1
			print(lineNo, line)
		end
		local f = loadstring(code, "Generated code for java class " .. classname)
		return f(private, jniwrap.env, classname, class)
	end

	local wrappers = {}
	local mts = {}
	function private.boxFor(className)
		if not wrappers[className] then
			wrappers[className] = {}
		end
		return wrappers[className]
	end

	function private.box(className, object)
		if not mts[className] then
			mts[className] = {__index = private.boxFor(className)}
		end
		jniwrap.doGc(object)
		return setmetatable({[instance] = object}, mts[className])
	end

	function private.unbox(obj)
		return obj[instance]
	end

	private.toJavaString = jniwrap.toJavaString
end
