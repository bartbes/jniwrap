public class Test
{
	private static native void nativeInit(String filename);

	public static void main(String[] args)
	{
		String filename = "test.lua";
		if (args.length > 0)
			filename = args[0];
		nativeInit(filename);
	}

	static
	{
		System.loadLibrary("Test");
	}
}
