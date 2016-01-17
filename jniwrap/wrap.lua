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

	function jniwrap.wrapObject(class, object)
		return setmetatable({[instance] = object}, {__index = class})
	end

	function jniwrap.wrapMethod(class, name, def, out, aliases)
		local signature, rettype = jniwrap.calculateSignature(def, aliases)

		local methodid
		local callf = "Call"
		if def.static then
			methodid = jniwrap.env.GetStaticMethodID(class, name, signature)
			callf = callf .. "Static"
		else
			methodid = jniwrap.env.GetMethodID(class, name, signature)
		end

		rettype = jniwrap.invSimpleTypeSignatures[rettype] or "object"
		rettype = rettype:sub(1, 1):upper() .. rettype:sub(2)
		callf = callf .. rettype .. "Method"

		if def.static then
			return function(...)
				return jniwrap.env[callf](class, methodid, ...)
			end
		elseif def.constructor then
			return function(...)
				local obj = jniwrap.env.NewObject(class, methodid, ...)
				return jniwrap.wrapObject(out, obj)
			end
		else
			return function(self, ...)
				return jniwrap.env[callf](self[instance], methodid, ...)
			end
		end
	end

	function jniwrap.wrapField(class, name, def, out, aliases)
		local signature = jniwrap.signatureFor(def.type, aliases)

		local fieldid
		local callf = ""
		if def.static then
			fieldid = jniwrap.env.GetStaticFieldID(class, name, signature)
			callf = callf .. "Static"
		else
			fieldid = jniwrap.env.GetFieldID(class, name, signature)
		end

		local rettype = jniwrap.invSimpleTypeSignatures[signature] or "object"
		rettype = rettype:sub(1, 1):upper() .. rettype:sub(2)
		callf = callf .. rettype .. "Field"

		local getf = "Get" .. callf
		local setf = "Set" .. callf

		if def.static then
			return function(...)
				if select("#", ...) > 0 then
					return jniwrap.env[setf](class, fieldid, (...))
				else
					return jniwrap.env[getf](class, fieldid)
				end
			end
		else
			return function(self, ...)
				if select("#", ...) > 0 then
					return jniwrap.env[setf](self[instance], fieldid, (...))
				else
					return jniwrap.env[getf](self[instance], fieldid)
				end
			end
		end
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
		out.class = class

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
				out[i] = jniwrap.wrapField(class, name, v, out, aliases)
				errorOnException()
			else
				out[i] = jniwrap.wrapMethod(class, name, v, out, aliases)
				errorOnException()
			end
		end

		setmetatable(out, {__call = jniwrap.wrapObject})
		return out
	end

	function jniwrap.unwrapObject(obj)
		return obj[instance]
	end
end
