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

immutable decaVersion = "2021.10.30";

enum EscapeSequence {
    clearEntireScreen = ['\x1b', '[', '2', 'J'],
    cursorTo999BottomRight = ['\x1b', '[', '9', '9', '9', 'C', '\x1b', '[', '9', '9', '9', 'B'],
    cursorToTopLeft = ['\x1b', '[', 'H'],
    reportCursorPosition = ['\x1b', '[', '6', 'n']
}

char ctrlKey(char k) {
    return k & '\x1f';
}

enum EditorKey {
    arrowLeft = 1000,
    arrowRight,
    arrowUp,
    arrowDown,
    delKey,
    homeKey,
    endKey,
    pageUp,
    pageDown
}

// *** data ***

struct Erow {
    string chars;
}

struct EditorConfig {
    int cx, cy;
    int screenRows;
    int screenColumns;
    int numrows;
    Erow*[] rows;
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

int editorReadKey() {
    long nread;
    char c;

    while ((nread = read(STDIN_FILENO, &c, 1)) != 1) {
        if (nread == -1 && errno != EAGAIN)
            die("read");
    }

    if (c == '\x1b') {
        char[3] seq;

        if (read(STDIN_FILENO, &seq[0], 1) != 1) return '\x1b';
        if (read(STDIN_FILENO, &seq[1], 1) != 1) return '\x1b';

        if (seq[0] == '[') {
            if (seq[1] >= '0' && seq[1] <= '9') {
                if (read(STDIN_FILENO, &seq[2], 1) != 1) return '\x1b';
                if (seq[2] == '~') {
                    final switch (seq[1]) {
                        case '1': return EditorKey.homeKey;
                        case '3': return EditorKey.delKey;
                        case '4': return EditorKey.endKey;
                        case '5': return EditorKey.pageUp;
                        case '6': return EditorKey.pageDown;
                        case '7': return EditorKey.homeKey;
                        case '8': return EditorKey.endKey;
                    }
                }
            } else {
                final switch (seq[1]) {
                    case 'A': return EditorKey.arrowUp;
                    case 'B': return EditorKey.arrowDown;
                    case 'C': return EditorKey.arrowRight;
                    case 'D': return EditorKey.arrowLeft;
                    case 'H': return EditorKey.homeKey;
                    case 'F': return EditorKey.endKey;
                }
            }
        } else if (seq[0] == 'O') {
            final switch (seq[1]) {
                case 'H': return EditorKey.homeKey;
                case 'F': return EditorKey.endKey;
            }
        }

        return '\x1b';
    } else {
        return c;
    }
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

// *** row operations ***

void editorAppendRow(string s) {
    auto row = new Erow(s.strip());

    E.rows ~= row;
    E.numrows++;
}

// *** file i/o ***

void editorOpen(string filename) {
    auto file = File(filename, "r");
    if (!file.isOpen())
        die("file open");

    scope(exit)
        file.close();

    editorAppendRow(file.readln());
}

// *** output ***

void editorDrawRows(ref char[] appendbuffer) {
    const char[] leftGutter = ['~'];
    const char[] lineEnd = ['\r', '\n'];
    const char[] clearToEndLine = ['\x1b', '[', 'K'];

    for (int y = 0; y < E.screenRows; y++) {
        if (y >= E.numrows) {
            if (E.numrows == 0 && y == E.screenRows / 3) {
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
        } else {
            appendbuffer ~= E.rows[y].chars;
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

void editorMoveCursor(int key) {
    final switch(key) {
        case EditorKey.arrowLeft:
            if (E.cx != 0) {
                E.cx--;
            }
            break;
        case EditorKey.arrowRight:
            if (E.cx != E.screenColumns - 1) {
                E.cx++;
            }
            break;
        case EditorKey.arrowUp:
            if (E.cy != 0) {
                E.cy--;
            }
            break;
        case EditorKey.arrowDown:
            if (E.cy != E.screenRows - 1) {
                E.cy++;
            }
            break;
    }
}

void editorProcessKeypress() {
    const int c = editorReadKey();

    final switch (c) {
    case ctrlKey('q'):
        exitProgram(0);
        break;

    case EditorKey.homeKey:
        E.cx = 0;
        break;

    case EditorKey.endKey:
        E.cx = E.screenColumns - 1;
        break;

    case EditorKey.pageUp:
    case EditorKey.pageDown:
        {
            for (int times = E.screenRows; times > 0; times--) {
                editorMoveCursor(c == EditorKey.pageUp ? EditorKey.arrowUp : EditorKey.arrowDown);
            }
        }
        break;

    case EditorKey.arrowUp:
    case EditorKey.arrowDown:
    case EditorKey.arrowLeft:
    case EditorKey.arrowRight:
        editorMoveCursor(c);
        break;
    }
}

// *** init ***

void initEditor() {
    E.cx = 0;
    E.cx = 0;
    E.numrows = 0;
    E.rows = new Erow*[E.screenRows];

    if (getWindowSize(E.screenRows, E.screenColumns) == -1)
        die("getWindowSize");
}

int main(string[] args) {
    enableRawMode();
    initEditor();

    if (args.length >= 2)
        editorOpen(args[1]);

    while (true) {
        editorRefreshScreen();
        editorProcessKeypress();
    }
}
