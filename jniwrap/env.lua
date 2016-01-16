return function(jniwrap)
	local env

	local initenv

	function jniwrap.setEnv(_env)
		env = _env
		initenv()
	end

	local mt =
	{
		__index = function(self, name)
			if not env[0][name] then return nil end
			local function wrapper(...)
				return env[0][name](env, ...)
			end
			rawset(self, name, wrapper)
			return wrapper
		end,
	}

	function initenv()
		jniwrap.env = setmetatable({}, mt)
	end
end
