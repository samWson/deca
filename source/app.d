import std.ascii;
import std.stdio;
import core.sys.linux.termios;
import core.sys.linux.unistd;

termios originalTermios;

void disableRawMode() {
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios);
}

void enableRawMode() {
	tcgetattr(STDIN_FILENO, &originalTermios);

	termios raw = originalTermios;
	raw.c_lflag &= ~(ECHO | ICANON);

	tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int main()
{
	enableRawMode();
	scope(exit) disableRawMode();

	char[] buffer;

	while (!stdin.eof && buffer != ['q'])
	{
		buffer = stdin.rawRead(new char[1]);
		char c = buffer[0];

		if (isControl(c)) {
			writefln("%d", c);
		} else {
			writefln("%d ('%c')", c, c);
		}
	}

	return 0;
}
