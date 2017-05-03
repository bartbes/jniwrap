return function(jniwrap)
	local Class =
	{
		class = {name = "java.lang.Class"},
		forName = {static = true, arg1 = "String", returnType = "self"},
		getName = {returnType = "String"},
		getConstructors = {returnType = "java.lang.reflect.Constructor[]"},
		getFields = {returnType = "java.lang.reflect.Field[]"},
		getMethods = {returnType = "java.lang.reflect.Method[]"},
	}

	local Field =
	{
		class = {name = "java.lang.reflect.Field"},
		getName = {returnType = "String"},
		getType = {returnType = "Class"},
		getModifiers = {returnType = "int"},
	}

	local Method =
	{
		class = {name = "java.lang.reflect.Method"},
		getName = {returnType = "String"},
		getReturnType = {returnType = "Class"},
		getModifiers = {returnType = "int"},
		getParameterTypes = {returnType = "Class[]"},
	}

	local Constructor =
	{
		class = {name = "java.lang.reflect.Constructor"},
		getModifiers = {returnType = "int"},
		getParameterTypes = {returnType = "Class[]"},
	}

	local Modifier =
	{
		class = {name = "java.lang.reflect.Modifier"},
		STATIC = {field = true, static = true, type = "int"},
		FINAL = {field = true, static = true, type = "int"},
		PUBLIC = {field = true, static = true, type = "int"},
		PROTECTED = {field = true, static = true, type = "int"},
		PRIVATE = {field = true, static = true, type = "int"},
	}

	local inited = false
	local function init()
		if inited then return end
		inited = true

		Class = jniwrap.wrapClass(Class)
		Field = jniwrap.wrapClass(Field)
		Method = jniwrap.wrapClass(Method)
		Constructor = jniwrap.wrapClass(Constructor)
		Modifier = jniwrap.wrapClass(Modifier)
	end

	function jniwrap.dumpClass(className)
		init()
		local class = Class.forName(className)

		local t = {}
		t.class = {}
		t.class.name = class:getName()
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

		for i, v in fields:ipairs() do
			local name = v:getName()

			local e = appendElem(name, {field = true})
			addModifiers(e, v:getModifiers())
			e.type = v:getType():getName()
		end

		for i, v in methods:ipairs() do
			local name = v:getName()

			local e = appendElem(name)
			addModifiers(e, v:getModifiers())
			e.returnType = v:getReturnType():getName()

			local params = v:getParameterTypes()
			for j, w in params:ipairs() do
				e["arg"..j+1] = w:getName()
			end
		end

		for i, v in constructors:ipairs() do
			local e = appendElem(simpleName)
			addModifiers(e, v:getModifiers())

			local params = v:getParameterTypes()
			for j, w in params:ipairs() do
				e["arg"..j] = w:getName()
			end
		end

		collectgarbage()

		return t
	end
end
