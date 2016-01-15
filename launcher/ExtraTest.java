public class ExtraTest
{
	public static void someJava()
	{
		System.out.println("Some java code runs!");
	}

	public void someMoreJava()
	{
		System.out.println("And an instance method, too!");
	}

	public void printString(String arg)
	{
		System.out.print("Input string: ");
		System.out.println(arg);
	}

	public int myIntField = 5;

	public void doubleInt()
	{
		myIntField = 2*myIntField;
	}
}
