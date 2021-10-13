import std.stdio;

int main()
{
	char[] buffer;

	while (!stdin.eof && buffer != ['q'])
	{
		buffer = stdin.rawRead(new char[1]);

		write("you entered: ");
		writeln(buffer);
	}

	return 0;
}
