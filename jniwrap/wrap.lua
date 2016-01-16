local ffi = require "ffi"

return function(jniwrap)
	local instance = {}

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
		class = ffi.cast("jclass", jniwrap.env.NewGlobalRef(class))
		ffi.gc(class, function()
			jniwrap.env.DeleteGlobalRef(class)
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
			if v.constructor then
				name = "<init>"
			end

			if v.field then
				out[i] = jniwrap.wrapField(class, name, v, out, aliases)
			else
				out[i] = jniwrap.wrapMethod(class, name, v, out, aliases)
			end
		end

		setmetatable(out, {__call = jniwrap.wrapObject})
		return out
	end

	function jniwrap.unwrapObject(obj)
		return obj[instance]
	end
end
