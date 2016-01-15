local jni = require "jniwrap"
local ffi = require "ffi"

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

	ffi.cdef [[
		JNIEnv *SDL_AndroidGetJNIEnv();
		jobject SDL_AndroidGetActivity();
	]]

	local env = ffi.C.SDL_AndroidGetJNIEnv()
	jni.setEnv(env)

	Activity = jni.wrapClass("android/Activity.ini")
	Intent = jni.wrapClass("android/Intent.ini")
	Uri = jni.wrapClass("android/Uri.ini")
	UriBuilder = jni.wrapClass("android/UriBuilder.ini")
	ActivityInfo = jni.wrapClass("android/ActivityInfo.ini")

	activity = ffi.C.SDL_AndroidGetActivity()
	log("Raw activity: %s", tostring(activity))
	activity = Activity(activity)
	log("Wrapped activity: %s", tostring(activity))
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
		local target = Uri.parse(jni.toJavaString("https://love2d.org/"))
		log("Target: %s", tostring(target))

		local intent = Intent.Intent1(Intent.ACTION_VIEW())
		intent:setData(target)
		intent:addFlags(Intent.FLAG_ACTIVITY_NEW_TASK())

		log("Starting intent: %s", tostring(jni.unwrapObject(intent)))
		activity:startActivity(jni.unwrapObject(intent))
	end
end

function love.draw()
	love.graphics.print("Switching in " .. timer1, 10, 10)
	love.graphics.print("Browsing in " .. timer2, 10, 20)
	love.graphics.print(logMsg, 10, 35)
end
