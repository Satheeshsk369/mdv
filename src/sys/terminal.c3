module terminal;

import std::io;
import std::encoding::base64;

const int ESC = 27;
const int TAB = 9;
const int ENTER = 10;
const int BACKSPACE = 127;
const int DOWN = 1000;
const int UP = 1001;
const int PAGEDOWN = 1002;
const int PAGEUP = 1003;
const int HALFDOWN = 1004;
const int HALFUP = 1005;
const int LEFT = 1006;
const int RIGHT = 1007;
const int HOME = 1008;
const int END = 1009;
const int WHEELUP = 1012;
const int WHEELDOWN = 1013;
const int SHIFTSPACE = 1014;

struct WinSize
{
    ushort ws_row;
    ushort ws_col;
    ushort ws_xpixel;
    ushort ws_ypixel;
}

struct Stat
{
    ulong st_dev;
    ulong st_ino;
    ulong st_nlink;
    uint st_mode;
    uint st_uid;
    uint st_gid;
    uint pad;
    ulong st_rdev;
    long st_size;
    long st_blksize;
    long st_blocks;
    long st_atime;
    ulong st_atime_nsec;
    long st_mtime;
    ulong st_mtime_nsec;
    long st_ctime;
    ulong st_ctime_nsec;
    long[3] reserved;
}

struct Termios
{
    uint c_iflag;
    uint c_oflag;
    uint c_cflag;
    uint c_lflag;
    char c_line;
    char[32] c_cc;
    uint c_ispeed;
    uint c_ospeed;
}

struct PollFd
{
    int fd;
    short events;
    short revents;
}

struct TimeVal
{
    long tv_sec;
    long tv_usec;
}

struct Stamp
{
    ulong inode;
    long size;
    long mtime;
    ulong nsec;
}

fn bool Stamp.same(self, Stamp other)
{
    return self.inode == other.inode && self.size == other.size && self.mtime == other.mtime && self.nsec == other.nsec;
}

alias SignalHandler = fn void(int sig);

extern fn int ioctl(int fd, ulong request, ...);
extern fn int isatty(int fd);
extern fn char* getenv(char* name);
extern fn int stat(char* path, Stat* buf);
extern fn int gettimeofday(TimeVal* tv, void* tz);
extern fn int tcgetattr(int fd, Termios* termios);
extern fn int tcsetattr(int fd, int actions, Termios* termios);
extern fn int read(int fd, void* buf, ulong count);
extern fn int write(int fd, void* buf, ulong count);
extern fn int system(char* command);
extern fn char* getcwd(char* buf, ulong size);
extern fn int chdir(char* path);
extern fn int poll(PollFd* fds, ulong nfds, int timeout);
extern fn void exit(int status);
extern fn SignalHandler signal(int signum, SignalHandler handler);

Termios saved;
bool raw;
bool alternate;

fn void out(String s)
{
    write(1, s.ptr, s.len);
}

fn int env(ZString name, int fallback)
{
    char* value = getenv(name);
    if (value == null) return fallback;
    int n = 0;
    for (int i = 0; value[i] >= '0' && value[i] <= '9'; i++) n = n * 10 + value[i] - '0';
    return n > 0 ? n : fallback;
}

fn WinSize size()
{
    WinSize ws;
    if (ioctl(1, 0x5413, &ws) != 0 && ioctl(1, 0x40087468, &ws) != 0) return {};
    return ws;
}

fn int width()
{
    ushort cols = size().ws_col;
    return cols > 0 ? cols : env("COLUMNS", 80);
}

fn int height()
{
    ushort rows = size().ws_row;
    return rows > 0 ? rows : env("LINES", 24);
}

fn bool tty()
{
    return isatty(1) != 0;
}

fn void onSignal(int sig)
{
    cooked();
    leave();
    exit(128 + sig);
}

fn void enter()
{
    out("\e[?1049h\e[?7l\e[>1u\e[2J\e[3J\e[H\e[?25l");
    alternate = true;
}

fn void leave()
{
    if (!alternate) return;
    out("\e[<u\e[?7h\e[?1049l\e[?25h\e[0m");
    alternate = false;
}

fn void rawMode()
{
    if (raw || isatty(0) == 0) return;
    signal(2, &onSignal);
    signal(15, &onSignal);
    signal(1, &onSignal);
    if (tcgetattr(0, &saved) != 0) return;
    Termios t = saved;
    t.c_lflag &= ~0x000Au;
    t.c_cc[6] = 0;
    t.c_cc[5] = 0;
    tcsetattr(0, 0, &t);
    raw = true;
    out("\e[?25l");
}

fn void cooked()
{
    if (!raw) return;
    tcsetattr(0, 0, &saved);
    raw = false;
    out("\e[?25h");
}

fn void edit(String path, int line)
{
    cooked();
    leave();
    char* editor = getenv("EDITOR");
    if (editor == null || editor[0] == 0) editor = getenv("VISUAL");
    if (editor == null || editor[0] == 0) editor = "nano";
    @pool()
    {
        system(string::tformat("%s +%d '%s'", (ZString)editor, line, path).zstr_tcopy());
    };
    rawMode();
    enter();
}

fn void copy(String content)
{
    @pool()
    {
        out(string::tformat("\e]52;c;%s\e\\", base64::tencode(content)));
    };
}

fn ulong now()
{
    TimeVal tv;
    gettimeofday(&tv, null);
    return (ulong)tv.tv_sec * 1000 + (ulong)(tv.tv_usec / 1000);
}

fn bool wait(int ms)
{
    PollFd p = { .fd = 0, .events = 1 };
    return poll(&p, 1, ms) > 0 && (p.revents & 1) != 0;
}

fn Stamp stamp(ZString path)
{
    Stat st;
    if (stat(path, &st) != 0) return {};
    return { st.st_ino, st.st_size, st.st_mtime, st.st_mtime_nsec };
}

const char[] ARROWS = { 'A', 'B', 'C', 'D', 'H', 'F' };
const int[] ARROWKEYS = { UP, DOWN, RIGHT, LEFT, HOME, END };
const char[] CONTROL = { 0x04, 0x15, 0x06, 0x02, 0x09, '\r', '\n', 0x7f, 0x08, 0x03 };
const int[] CONTROLKEYS = { HALFDOWN, HALFUP, PAGEDOWN, PAGEUP, TAB, ENTER, ENTER, BACKSPACE, BACKSPACE, 'q' };

fn int arrow(char a, char b, bool lower)
{
    foreach (i, c : ARROWS)
    {
        if (i >= 4 && lower) break;
        if (a == c || b == c || (lower && (a == c + 32 || b == c + 32))) return ARROWKEYS[i];
    }
    return 0;
}

fn int wheel(int button)
{
    if (button == 64) return WHEELUP;
    if (button == 65) return WHEELDOWN;
    return 0;
}

char[256] pending;
int pendingLen;

fn void fill()
{
    int n = read(0, &pending[pendingLen], (ulong)(pending.len - pendingLen));
    if (n > 0) pendingLen += n;
}

fn int length(char[] b)
{
    if (b[0] != ESC || b.len == 1) return 1;
    if (b[1] == 'O') return min(3, (int)b.len);
    if (b[1] != '[') return 2;
    if (b.len >= 3 && b[2] == 'M') return min(6, (int)b.len);
    for (int i = 2; i < b.len; i++) if (b[i] >= 0x40 && b[i] <= 0x7E) return i + 1;
    return (int)b.len;
}

fn int decode(char[] buf)
{
    int n = (int)buf.len;
    if (buf[0] != ESC)
    {
        foreach (i, c : CONTROL) if (buf[0] == c) return CONTROLKEYS[i];
        return buf[0];
    }
    if (n == 1) return ESC;
    if (n >= 6 && buf[1] == '[' && buf[2] == '<')
    {
        int button = 0;
        for (int p = 3; p < n && buf[p] >= '0' && buf[p] <= '9'; p++) button = button * 10 + buf[p] - '0';
        return wheel(button);
    }
    if (n >= 6 && buf[1] == '[' && buf[2] == 'M') return wheel(buf[3] - 32);
    if (n >= 5 && buf[1] == '[' && buf[2] == '3' && buf[3] == '2') return SHIFTSPACE;
    if (n == 2 && buf[1] == ' ') return SHIFTSPACE;
    char last = buf[n - 1];
    if (n >= 3 && buf[1] == 'O') return arrow(buf[2], last, false);
    if (n < 3 || buf[1] != '[') return ESC;
    int k = arrow(buf[2], last, true);
    if (k) return k;
    if (buf[2] == '5' && n >= 4 && buf[3] == '~') return PAGEUP;
    if (buf[2] == '6' && n >= 4 && buf[3] == '~') return PAGEDOWN;
    if (buf[2] == 'H' || last == 'H' || (last == '~' && (buf[2] == '1' || buf[2] == '7'))) return HOME;
    if (buf[2] == 'F' || last == 'F' || (last == '~' && (buf[2] == '4' || buf[2] == '8'))) return END;
    return ESC;
}

fn int key()
{
    while (true)
    {
        if (pendingLen == 0) fill();
        if (pendingLen == 0) return 0;
        bool partial = pending[0] == ESC && (pendingLen == 1 || (pendingLen == 2 && (pending[1] == '[' || pending[1] == 'O')));
        if (partial && wait(20)) fill();
        int len = length(pending[:pendingLen]);
        int k = decode(pending[:len]);
        pendingLen -= len;
        mem::move(&pending, &pending[len], pendingLen);
        if (k) return k;
    }
}
