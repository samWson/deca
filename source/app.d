import std.ascii;
import std.stdio;
import core.sys.linux.termios;
import core.sys.linux.unistd;
import core.sys.linux.stdio;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;

// *** defines ***

char ctrlKey(char k) {
    return k & '\x1f';
}

// *** data ***

termios originalTermios;

// *** terminal ***

void die(const char* message) {
    perror(message);
    exit(1);
}

void disableRawMode() {
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios) == -1)
        die("tcsetattr");
}

void enableRawMode() {
    if (tcgetattr(STDIN_FILENO, &originalTermios) == -1)
        die("tcgetattr");

    termios raw = originalTermios;
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag &= ~(CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1;

    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1)
        die("tcsetattr");
}

char editorReadKey() {
    int nread;
    char c;

    while ((nread = read(STDIN_FILENO, &c, 1)) != 1) {
        if (nread == -1 && errno != EAGAIN)
            die("read");
    }

    return c;
}

// *** input ***

void editorProcessKeypress() {
    const char c = editorReadKey();

    switch (c) {
    case ctrlKey('q'):
        exit(0);
        break;
    }
}

// *** init ***

int main() {
    enableRawMode();
    scope (exit)
        disableRawMode();

    while (true) {
        editorProcessKeypress();
    }

    return 0;
}
