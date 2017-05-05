public class ClassLoaderTest implements Runnable
{
	public void run()
	{
		System.out.println("This class runs");
		ClassLoaderTestHelper.helper();
	}
}
