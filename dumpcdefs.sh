#!/bin/sh

JNI_INCLUDE_PATH=/usr/lib/jvm/default/include
JNI_H="$JNI_INCLUDE_PATH/jni.h"

if [ "$1" != "" ]; then
	JNI_H="$1"
fi

echo 'require("ffi").cdef[['

cpp \
		-D__attribute__\(x\)="" \
		-I "$JNI_INCLUDE_PATH" \
		-I "$JNI_INCLUDE_PATH/linux" \
		"$JNI_H" |\
	sed -n -e '/typedef/,$p' |\
	sed -e '/^\s*#/d' -e '/^\s*$/d'

echo ']]'
