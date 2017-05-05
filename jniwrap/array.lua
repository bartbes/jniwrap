local ffi = require "ffi"

return function(jniwrap)
	local mts = {}

	local function validateIndex(arr, index)
		assert(index >= 0 and index < jniwrap.env.GetArrayLength(arr), "Invalid array index")
	end

	mts.Object = {}
	function mts.Object.__index(self, index)
		validateIndex(self.arr, index)
		return jniwrap.doGc(jniwrap.env.GetObjectArrayElement(self.arr, index))
	end

	function mts.Object.__newindex(self, index, value)
		validateIndex(self.arr, index)
		return jniwrap.env.SetObjectArrayElement(self.arr, index, value)
	end

	function mts.Object.ipairs(self)
		local len = jniwrap.env.GetArrayLength(self.arr)
		return function(state, i)
			i = i + 1
			if i >= len then return nil end
			return i, jniwrap.doGc(jniwrap.env.GetObjectArrayElement(self.arr, i))
		end, nil, -1
	end

	local function newPrimitiveMt(type)
		local common = type:sub(1, 1):upper() .. type:sub(2) .. "Array"
		local getter, setter = "Get" .. common .. "Region", "Set" .. common .. "Region"
		local getall, relall = "Get" .. common .. "Elements", "Release" .. common .. "Elements"
		local ffitype = ffi.typeof("j" .. type .. "[1]")

		local mt = {}
		function mt.__index(self, index)
			validateIndex(self.arr, index)
			local value = ffitype()
			jniwrap.env[getter](self.arr, index, 1, value)
			return value[0]
		end

		function mt.__newindex(self, index, value)
			validateIndex(self.arr, index)
			local ref = ffitype()
			ref[0] = value
			jniwrap.env[setter](self.arr, index, 1, ref)
		end

		function mt.ipairs(self)
			-- Prevent lots of copies and get all elements at once
			local len = jniwrap.env.GetArrayLength(self.arr)
			local elems = jniwrap.env[getall](self.arr, nil)
			ffi.gc(elems, jniwrap.env[relall])
			return function(state, i)
				i = i + 1
				if i >= len then return nil end
				return i, elems[i]
			end, nil, -1
		end

		function mt.length(self)
			return jniwrap.env.GetArrayLength(self.arr)
		end

		return mt
	end

	local function newBoxedMt(wrapf)
		local mt = {}
		function mt.__index(self, index)
			validateIndex(self.arr, index)
			return wrapf(jniwrap.env.GetObjectArrayElement(self.arr, index))
		end

		function mt.__newindex(self, index, value)
			validateIndex(self.arr, index)
			return jniwrap.env.SetObjectArrayElement(self.arr, index, jniwrap.unbox(value))
		end

		function mt.ipairs(self)
			local len = jniwrap.env.GetArrayLength(self.arr)
			return function(state, i)
				i = i + 1
				if i >= len then return nil end
				return i, wrapf(jniwrap.env.GetObjectArrayElement(self.arr, i))
			end, nil, -1
		end

		function mt.length(self)
			return jniwrap.env.GetArrayLength(self.arr)
		end

		return mt
	end

	function jniwrap.wrapArray(type, arr)
		if arr == nil then return nil end
		if not mts[type] then
			if jniwrap.simpleTypeSignatures[type] then
				mts[type] = newPrimitiveMt(type)
			else
				mts[type] = newBoxedMt(function(obj) return jniwrap.box(type, obj) end)
			end
		end

		jniwrap.doGc(arr)
		local t = {arr = arr, ipairs = mts[type].ipairs, length = mts[type].length}
		return setmetatable(t, mts[type])
	end

	function jniwrap.unwrapArray(arr)
		if arr == nil then return nil end
		return arr.arr
	end

	function jniwrap.newArray(type, length)
		type = jniwrap.resolveAliases(type, {})

		-- Primitive arrays are easy...
		if jniwrap.simpleTypeSignatures[type] then
			local newf = "New" .. type:sub(1,1):upper() .. type:sub(2) .. "Array"
			local arr = jniwrap.env[newf](length)
			return jniwrap.wrapArray(type, arr)
		end

		-- Object arrays require type info.
		local classname = type:gsub("%.", "/")
		local class = jniwrap.env.FindClass(classname)
		local arr = jniwrap.env.NewObjectArray(length, class, nil)
		return jniwrap.wrapArray(type, arr)
	end
end
