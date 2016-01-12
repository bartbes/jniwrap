public class Test
{
	private static native void nativeInit();

	public static void main(String[] args)
	{
		nativeInit();
	}

	static
	{
		System.loadLibrary("Test");
	}
}
