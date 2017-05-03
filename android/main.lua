local jni = require "jniwrap"
local lovejni = require "jniwrap.love"
local import = require "jniwrap.import"

import:setPrefix("")
local Activity = import "android.app.Activity"
local Intent = import "android.content.Intent"
local Uri = import "android.net.Uri"
local UriBuilder = import "android.net.Uri.Builder"
local ActivityInfo = import "android.content.pm.ActivityInfo"

local logMsg = ""
local function log(fmt, ...)
	local msg = fmt:format(...)
	print(msg)
	logMsg = logMsg .. "\n" .. msg
end

function love.load()
	timer1 = 5
	timer2 = 10
	switched = false
	opened = false

	activity = jniwrap.box("android.app.Activity", lovejni.activity)
end

function love.update(dt)
	timer1 = math.max(timer1-dt, 0)
	timer2 = math.max(timer2-dt, 0)

	if timer1 == 0 and not switched then
		switched = true
		log("Requested new orientation")
		--activity:setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT())
		log("  Skipped (bugged)")
	end

	if timer2 == 0 and not opened then
		opened = true
		local target = Uri.parse("https://love2d.org/")
		log("Target: %s", tostring(target))

		local intent = Intent.Intent1(Intent.ACTION_VIEW())
		intent:setData(target)
		intent:addFlags(Intent.FLAG_ACTIVITY_NEW_TASK())

		log("Starting intent: %s", tostring(jni.unbox(intent)))
		activity:startActivity(intent)
	end
end

function love.draw()
	love.graphics.print("Switching in " .. timer1, 10, 10)
	love.graphics.print("Browsing in " .. timer2, 10, 20)
	love.graphics.print(logMsg, 10, 35)
end
