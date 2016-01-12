#!/bin/sh

JNI_INCLUDE_PATH=/usr/lib/jvm/default/include

echo 'require("ffi").cdef[['

cpp \
		-D__attribute__\(x\)="" \
		-I "$JNI_INCLUDE_PATH" \
		-I "$JNI_INCLUDE_PATH/linux" \
		"$JNI_INCLUDE_PATH/jni.h" |\
	sed -n -e '/typedef/,$p' |\
	sed -e '/^\s*#/d' -e '/^\s*$/d'

echo ']]'
