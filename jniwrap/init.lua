local basename = ...
if basename:match("init$") then
	basename = basename:sub(1, -5)
else
	basename = basename .. "."
end

require(basename .. "cdefs")
local inifile = require(basename .. "inifile")
local ffi = require "ffi"

local jniwrap = {}
local env

function jniwrap.parseIni(filename)
	return inifile.parse(filename)
end

function jniwrap.doGc(ref)
	return ffi.gc(ref, jniwrap.env.DeleteLocalRef)
end

for i, v in ipairs{"env", "types", "wrap", "array", "dump"} do
	local f = require(basename .. v)
	f(jniwrap)
end

return jniwrap
