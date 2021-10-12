import std.stdio;

int main()
{
	while (!stdin.eof)
	{
		char[] buffer = stdin.rawRead(new char[1]);
		write("you entered: ");
		writeln(buffer);
	}

	return 0;
}
