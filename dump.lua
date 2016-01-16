local jni
local inifile = require "jniwrap.inifile"
local bit = require "bit"

local function main()
	jni = require "jniwrap.init"
	local ffi = require "ffi"

	ffi.cdef [[
	JNIEnv *getGlobalEnv();
	]]

	local env = ffi.C.getGlobalEnv()
	jni.setEnv(env)

	Class = jni.wrapClass("def/Class.ini")
	Field = jni.wrapClass("def/Field.ini")
	Method = jni.wrapClass("def/Method.ini")
	Constructor = jni.wrapClass("def/Constructor.ini")
	Modifier = jni.wrapClass("def/Modifier.ini")

	local Math = Class(Class.forName(jni.toJavaString("java.lang.Math")))
	print(dumpClass(Math))
end

function dumpClass(class)
	local t = {}
	t.class = {}
	t.class.name = jni.fromJavaString(class:getName())
	local simpleName = t.class.name:match("[^%.$]+$")

	local constructors = class:getConstructors()
	local fields = class:getFields()
	local methods = class:getMethods()

	local function appendElem(name, elem)
		elem = elem or {}
		elem.name = name

		-- Deal with overloads, poorly
		if t[name] or t[name..1] then
			if t[name] then t[name..1], t[name] = t[name] end
			for i = 2, math.huge do
				if not t[name..i] then
					name = name..i
					break
				end
			end
		end
		t[name] = elem
		return elem
	end

	local function addModifiers(elem, modifiers)
		elem.static = bit.band(modifiers, Modifier.STATIC()) ~= 0 or nil
		elem.final = bit.band(modifiers, Modifier.FINAL()) ~= 0 or nil

		if bit.band(modifiers, Modifier.PUBLIC()) ~= 0 then
			elem.access = "public"
		elseif bit.band(modifiers, Modifier.PROTECTED()) ~= 0 then
			elem.access = "protected"
		elseif bit.band(modifiers, Modifier.PRIVATE()) ~= 0 then
			elem.access = "private"
		end
	end

	for i = 0, jni.env.GetArrayLength(fields)-1 do
		local v = Field(jni.env.GetObjectArrayElement(fields, i))
		local name = jni.fromJavaString(v:getName())

		local e = appendElem(name, {field = true})
		addModifiers(e, v:getModifiers())
		e.type = jni.fromJavaString(Class(v:getType()):getName())
	end

	for i = 0, jni.env.GetArrayLength(methods)-1 do
		local v = Method(jni.env.GetObjectArrayElement(methods, i))
		local name = jni.fromJavaString(v:getName())

		local e = appendElem(name)
		addModifiers(e, v:getModifiers())
		e.returnType = jni.fromJavaString(Class(v:getReturnType()):getName())

		local params = v:getParameterTypes()
		for j = 1, jni.env.GetArrayLength(params) do
			local w = Class(jni.env.GetObjectArrayElement(params, j-1))
			e["arg"..j] = jni.fromJavaString(w:getName())
		end
	end

	for i = 0, jni.env.GetArrayLength(constructors)-1 do
		local v = Constructor(jni.env.GetObjectArrayElement(constructors, i))

		local e = appendElem(simpleName)
		addModifiers(e, v:getModifiers())

		local params = v:getParameterTypes()
		for j = 1, jni.env.GetArrayLength(params) do
			local w = Class(jni.env.GetObjectArrayElement(params, j-1))
			e["arg"..j] = jni.fromJavaString(w:getName())
		end
	end

	return inifile.save("", t, "memory")
end

xpcall(main, function(err)
	print("ERROR: ", err)
	print(debug.traceback())
end)
