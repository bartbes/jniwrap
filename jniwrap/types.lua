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

	jniwrap.simpleTypeSignatures = simpleTypeSignatures
	jniwrap.invSimpleTypeSignatures = invSimpleTypeSignatures
	jniwrap.typeAliases = typeAliases

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

		local rettype = jniwrap.signatureFor(method.returnType or "void", aliases)

		return ("(%s)%s"):format(table.concat(args), rettype), rettype
	end

	function jniwrap.fromJavaString(str)
		local chars = jniwrap.env.GetStringUTFChars(str, nil)
		local length = jniwrap.env.GetStringUTFLength(str)
		local luastr = ffi.string(chars, length)
		jniwrap.env.ReleaseStringUTFChars(str, chars)
		return (luastr:gsub(string.char(0xc0, 0x80), "\0"))
	end

	function jniwrap.toJavaString(str)
		local modified = str:gsub("%z", string.char(0xc0, 0x80))
		return jniwrap.env.NewStringUTF(modified)
	end
end
