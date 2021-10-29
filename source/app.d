import std.algorithm;
import std.ascii;
import std.format.read;
import std.stdio;
import std.string;
import core.sys.posix.sys.ioctl;
import core.sys.linux.termios;
import core.sys.linux.unistd;
import core.sys.linux.stdio;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;

// *** defines ***

immutable decaVersion = "2021.10.29";

enum EscapeSequence {
    clearEntireScreen = ['\x1b', '[', '2', 'J'],
    cursorTo999BottomRight = ['\x1b', '[', '9', '9', '9', 'C', '\x1b', '[', '9', '9', '9', 'B'],
    cursorToTopLeft = ['\x1b', '[', 'H'],
    reportCursorPosition = ['\x1b', '[', '6', 'n']
}

char ctrlKey(char k) {
    return k & '\x1f';
}

// *** data ***

struct EditorConfig {
    int cx, cy;
    int screenRows;
    int screenColumns;
    termios originalTermios;
}

EditorConfig E;

// *** terminal ***

void die(const char* message) {
    std.stdio.stdout.rawWrite(EscapeSequence.clearEntireScreen);
    std.stdio.stdout.rawWrite(EscapeSequence.cursorToTopLeft);
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
    std.stdio.stdout.rawWrite(EscapeSequence.clearEntireScreen);
    std.stdio.stdout.rawWrite(EscapeSequence.cursorToTopLeft);
    std.stdio.stdout.flush();

    disableRawMode();

    exit(status);
}

int getCursorPosition(ref int rows, ref int cols) {
    std.stdio.stdout.rawWrite(EscapeSequence.reportCursorPosition);
    scope(failure) return -1;

    char[] buffer = std.stdio.stdin.rawRead(new char[32]);

    const long index = buffer.indexOf('R');

    char[] parsedResponse = buffer[0..index];

    if (parsedResponse[0] != '\x1b' || parsedResponse[1] != '[')
        return -1;

    if (formattedRead(parsedResponse[2..$], "%d;%d", rows, cols) != 2)
        return -1;

    return 0;
}

int getWindowSize(ref int rows, ref int cols) {
    winsize ws;

    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
        std.stdio.stdout.rawWrite(EscapeSequence.cursorTo999BottomRight);
        scope(failure) return -1;

        return getCursorPosition(rows, cols);
    } else {
        cols = ws.ws_col;
        rows = ws.ws_row;

        return 0;
    }
}

// *** output ***

void editorDrawRows(ref char[] appendbuffer) {
    const char[] leftGutter = ['~'];
    const char[] lineEnd = ['\r', '\n'];
    const char[] clearToEndLine = ['\x1b', '[', 'K'];

    for (int y = 0; y < E.screenRows; y++) {
        if (y == E.screenRows / 3) {
            string welcome = format("Deca editor -- version %s", decaVersion);

            ulong padding = (E.screenColumns - welcome.length) / 2;

            if (padding > 0) {
                appendbuffer ~= leftGutter;
                padding--;
            }

            while (padding > 0) {
               appendbuffer ~= " ";
               padding--;
            }

            if (welcome.length > E.screenColumns)
                welcome.length = E.screenColumns;

            appendbuffer ~= welcome;
        } else {
            appendbuffer ~= leftGutter;
        }

        appendbuffer ~= clearToEndLine;

        if (y < E.screenRows -1) {
            appendbuffer ~= lineEnd;
        }
    }
}

void editorRefreshScreen() {
    string cursorPosition(int row = 0, int column = 0) {
        return format("\x1b[%s;%sH", row, column);
    }

    char[] appendbuffer = new char[165];
    const char[] showCursor = ['\x1b', '[', '?', '2', '5', 'h'];
    const char[] hideCursor = ['\x1b', '[', '?', '2', '5', 'l'];

    appendbuffer ~= hideCursor;
    appendbuffer ~= cursorPosition();

    editorDrawRows(appendbuffer);

    appendbuffer ~= cursorPosition(E.cy + 1, E.cx + 1);

    appendbuffer ~= showCursor;

    std.stdio.stdout.rawWrite(appendbuffer);
    std.stdio.stdout.flush();
}

// *** input ***

void editorMoveCursor(char key) {
    final switch(key) {
        case 'a':
            E.cx--;
            break;
        case 'd':
            E.cx++;
            break;
        case 'w':
            E.cy--;
            break;
        case 's':
            E.cy++;
            break;
    }
}

void editorProcessKeypress() {
    const char c = editorReadKey();

    final switch (c) {
    case ctrlKey('q'):
        exitProgram(0);
        break;
    case 'w':
    case 's':
    case 'a':
    case 'd':
        editorMoveCursor(c);
        break;
    }
}

// *** init ***

void initEditor() {
    E.cx = 0;
    E.cx = 0;

    if (getWindowSize(E.screenRows, E.screenColumns) == -1)
        die("getWindowSize");
}

int main() {
    enableRawMode();
    initEditor();

    while (true) {
        editorRefreshScreen();
        editorProcessKeypress();
    }
}
