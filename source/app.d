import std.stdio;
import core.sys.linux.termios;
import core.sys.linux.unistd;

void enableRawMode() {
	termios raw;

	tcgetattr(STDIN_FILENO, &raw);

	raw.c_lflag &= ~ECHO;

	tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int main()
{
	enableRawMode();

	char[] buffer;

	while (!stdin.eof && buffer != ['q'])
	{
		buffer = stdin.rawRead(new char[1]);

		write("you entered: ");
		writeln(buffer);
	}

	return 0;
}
