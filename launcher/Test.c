#include <stdio.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "Test.h"

static JNIEnv *genv;

JNIEnv *getGlobalEnv()
{
	return genv;
}

JNIEXPORT void JNICALL Java_Test_nativeInit(JNIEnv *env, jclass test, jstring filename)
{
	printf("Started native code!\n");
	genv = env;

	lua_State *L = luaL_newstate();
	luaL_openlibs(L);

	const char *filename_utf = (*env)->GetStringUTFChars(env, filename, NULL);
	printf("Loaded lua, launching...\n");
	luaL_dofile(L, filename_utf);
	(*env)->ReleaseStringUTFChars(env, filename, filename_utf);

	printf("Finished, returning to java...\n");
	lua_close(L);
}
