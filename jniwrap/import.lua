local path = ...
local basename = path:match("^(.+)%.import$")
local jniwrap = require(basename .. ".init")
local inifile = require(basename .. ".inifile")

local import = {}
import.prefix = "java"
import.cache = {}

local function importer(self, className)
	local path = self.prefix .. "/" .. className:gsub("%.", "/") .. ".ini"
	local definition = inifile.parse(path)
	return jniwrap.wrapClass(definition)
end

function import:import(className)
	if not self.cache[className] then
		self.cache[className] = importer(self, className)
	end

	return self.cache[className]
end

function import:setPrefix(prefix)
	self.prefix = prefix
end

setmetatable(import, {__call = import.import})
return import
