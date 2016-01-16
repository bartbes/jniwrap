local basename = ...
if basename:match("init$") then
	basename = basename:sub(1, -5)
else
	basename = basename .. "."
end

require(basename .. "cdefs")
local inifile = require(basename .. "inifile")

local jniwrap = {}
local env

function jniwrap.parseIni(filename)
	return inifile.parse(filename)
end

for i, v in ipairs{"env", "types", "wrap", "dump"} do
	local f = require(basename .. v)
	f(jniwrap)
end

return jniwrap
