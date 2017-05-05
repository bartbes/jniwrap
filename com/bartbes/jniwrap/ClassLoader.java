package com.bartbes.jniwrap;

public class ClassLoader extends java.lang.ClassLoader
{
	private native byte[] luaLoad(String name);

	public Class findClass(String name)
	{
		byte[] b = luaLoad(name);
		if (b == null)
			return null;
		return defineClass(name, b, 0, b.length);
	}
}
