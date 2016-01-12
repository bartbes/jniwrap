local jni = require "jniwrap"
local ffi = require "ffi"

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

	activity = ffi.C.SDL_AndroidGetActivity()
	print("Raw activity: ", activity)
	activity = Activity(activity)
	print("Wrapped activity: ", activity)
end

function love.update(dt)
	timer1 = math.max(timer1-dt, 0)
	timer2 = math.max(timer2-dt, 0)

	if timer1 == 0 and not switched then
		switched = true
		--activity:setRequestedOrientation(1)
	end

	if timer2 == 0 and not opened then
		opened = true
		local target = Uri.parse(jni.toJavaString("https://love2d.org"))
		local ACTION_VIEW = jni.toJavaString("android.intent.action.VIEW")
		local intent = Intent.Intent2(ACTION_VIEW, target)
		activity:startActivity(jni.unwrapObject(intent))
	end
end

function love.draw()
	love.graphics.print("Switching in " .. timer1, 10, 10)
	love.graphics.print("Browsing in " .. timer2, 10, 20)
end
