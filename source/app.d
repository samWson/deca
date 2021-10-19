import std.ascii;
import std.stdio;
import core.sys.linux.termios;
import core.sys.linux.unistd;
import core.sys.linux.stdio;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;

// *** defines ***

enum escapeSequence {
    clearEntireScreen = ['\x1b', '[', '2', 'J'],
    cursorToTopLeft = ['\x1b', '[', 'H']
}

char ctrlKey(char k) {
    return k & '\x1f';
}

// *** data ***

struct EditorConfig {
    termios originalTermios;
}

EditorConfig E;

// *** terminal ***

void die(const char* message) {
    std.stdio.stdout.rawWrite(escapeSequence.clearEntireScreen);
    std.stdio.stdout.rawWrite(escapeSequence.cursorToTopLeft);
    std.stdio.stdout.flush();

    perror(message);

    exit(1);
}

void disableRawMode() {
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &E.originalTermios) == -1)
        die("tcsetattr");
}

void enableRawMode() {
    if (tcgetattr(STDIN_FILENO, &E.originalTermios) == -1)
        die("tcgetattr");

    termios raw = E.originalTermios;
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
    long nread;
    char c;

    while ((nread = read(STDIN_FILENO, &c, 1)) != 1) {
        if (nread == -1 && errno != EAGAIN)
            die("read");
    }

    return c;
}

void exitProgram(int status) {
    std.stdio.stdout.rawWrite(escapeSequence.clearEntireScreen);
    std.stdio.stdout.rawWrite(escapeSequence.cursorToTopLeft);
    std.stdio.stdout.flush();

    disableRawMode();

    exit(status);
}

// *** output ***

void editorDrawRows() {
    const char[] leftGutter = ['~', '\r', '\n'];
    int y;

    for (y = 0; y < 24; y++) {
        std.stdio.stdout.rawWrite(leftGutter);
    }
}

void editorRefreshScreen() {
    const char[] clearEntireScreen = ['\x1b', '[', '2', 'J'];
    const char[] cursorToTopLeft = ['\x1b', '[', 'H'];

    std.stdio.stdout.rawWrite(clearEntireScreen);
    std.stdio.stdout.rawWrite(cursorToTopLeft);
    std.stdio.stdout.flush();

    editorDrawRows();

    std.stdio.stdout.rawWrite(cursorToTopLeft);
    std.stdio.stdout.flush();
}

// *** input ***

void editorProcessKeypress() {
    const char c = editorReadKey();

    switch (c) {
    case ctrlKey('q'):
        exitProgram(0);
        break;
    default:
        break;
    }
}

// *** init ***

int main() {
    enableRawMode();

    while (true) {
        editorRefreshScreen();
        editorProcessKeypress();
    }
}
