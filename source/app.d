import std.ascii;
import std.stdio;
import core.sys.linux.termios;
import core.sys.linux.unistd;
import core.sys.linux.stdio;

termios originalTermios;

void disableRawMode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios);
}

void enableRawMode() {
    tcgetattr(STDIN_FILENO, &originalTermios);

    termios raw = originalTermios;
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag &= ~(CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1;

    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int main() {
    enableRawMode();
    scope (exit)
        disableRawMode();

    while (true) {
        char c = '\0';
        read(STDIN_FILENO, &c, 1);

        if (isControl(c)) {
            writefln("%d\r", c);
        } else {
            writefln("%d ('%c')\r", c, c);
        }

        if (c == 'q') break;
    }

    return 0;
}
