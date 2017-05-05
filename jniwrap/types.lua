local ffi = require "ffi"

return function(jniwrap)
	simpleTypeSignatures =
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
	invSimpleTypeSignatures = {}
	typeAliases =
	{
		["java.lang.Boolean"] = "Ljava/lang/Boolean;",
		["java.lang.Byte"] = "Ljava/lang/Byte;",
		["java.lang.Character"] = "Ljava/lang/Character;",
		["java.lang.Class"] = "Ljava/lang/Class;",
		["java.lang.Double"] = "Ljava/lang/Double;",
		["java.lang.Exception"] = "Ljava/lang/Exception;",
		["java.lang.Float"] = "Ljava/lang/Float;",
		["java.lang.Integer"] = "Ljava/lang/Integer;",
		["java.lang.Long"] = "Ljava/lang/Long;",
		["java.lang.Object"] = "Ljava/lang/Object;",
		["java.lang.Short"] = "Ljava/lang/Short;",
		["java.lang.String"] = "Ljava/lang/String;",
		["java.lang.Throwable"] = "Ljava/lang/Throwable;",
		["java.lang.Void"] = "Ljava/lang/Void;",
	}
	local globalAliases = {
		Boolean = "java.lang.Boolean",
		Byte = "java.lang.Byte",
		Character = "java.lang.Character",
		Class = "java.lang.Class",
		Double = "java.lang.Double",
		Exception = "java.lang.Exception",
		Float = "java.lang.Float",
		Integer = "java.lang.Integer",
		Long = "java.lang.Long",
		Object = "java.lang.Object",
		Short = "java.lang.Short",
		String = "java.lang.String",
		Throwable = "java.lang.Throwable",
		Void = "java.lang.Void",
	}

	for i, v in pairs(simpleTypeSignatures) do
		invSimpleTypeSignatures[v] = i
	end

	jniwrap.simpleTypeSignatures = simpleTypeSignatures
	jniwrap.invSimpleTypeSignatures = invSimpleTypeSignatures
	jniwrap.typeAliases = typeAliases

	function jniwrap.resolveAliases(typename, aliases)
		while aliases[typename] or globalAliases[typename] do
			typename = aliases[typename] or globalAliases[typename]
		end
		if typename:match("%[%]$") then
			return jniwrap.resolveAliases(typename:sub(1, -3), aliases) .. "[]"
		end
		return typename
	end

	function jniwrap.signatureFor(typename, aliases)
		typename = jniwrap.resolveAliases(typename, aliases)
		if simpleTypeSignatures[typename] then
			return simpleTypeSignatures[typename]
		end
		if typeAliases[typename] then
			return typeAliases[typename]
		end
		if typename:match("%[%]$") then
			return "[" .. jniwrap.signatureFor(typename:sub(1, -3), aliases)
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

		local rettype = jniwrap.resolveAliases(method.returnType or "void", aliases)
		local retsig = jniwrap.signatureFor(rettype, aliases)

		return ("(%s)%s"):format(table.concat(args), retsig), retsig, rettype
	end

	function jniwrap.fromJavaString(str)
		if str == nil then return nil end
		local chars = jniwrap.env.GetStringUTFChars(str, nil)
		local length = jniwrap.env.GetStringUTFLength(str)
		local luastr = ffi.string(chars, length)
		jniwrap.env.ReleaseStringUTFChars(str, chars)
		return (luastr:gsub(string.char(0xc0, 0x80), "\0"))
	end

	function jniwrap.toJavaString(str)
		if str == nil then return nil end
		local modified = str:gsub("%z", string.char(0xc0, 0x80))
		return jniwrap.env.NewStringUTF(modified)
	end
end
