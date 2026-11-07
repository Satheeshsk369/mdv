module terminal;

import std::io;
import std::io::path;
import std::os::env;
import std::encoding::base64;
import std::io::file;
import std::time::clock;
import libc;

const int ESC = 27;
const int TAB = 9;
const int ENTER = 10;
const int BACKSPACE = 127;
const int CTRLA = 1;
const int CTRLC = 3;
const int CTRLD = 4;
const int CTRLE = 5;
const int CTRLF = 6;
const int CTRLG = 7;
const int CTRLH = 8;
const int CTRLK = 11;
const int CTRLN = 14;
const int CTRLO = 15;
const int CTRLQ = 17;
const int CTRLR = 18;
const int CTRLS = 19;
const int CTRLV = 22;
const int CTRLW = 23;
const int CTRLX = 24;
const int CTRLY = 25;
const int CTRLZ = 26;
const int DOWN = 1000;
const int UP = 1001;
const int PAGEDOWN = 1002;
const int PAGEUP = 1003;
const int LEFT = 1006;
const int RIGHT = 1007;
const int HOME = 1008;
const int END = 1009;
const int DELETE = 1010;
const int PASTE = 1011;
const int PASTED = 1014;
const int BACKTAB = 1015;
const int CLICK = 1016;
const int DRAG = 1017;
const int RELEASE = 1018;
const int DONE = 1019;
const int SHIFT = 1 << 16;
const int ALT = 1 << 17;
const int CTRL = 1 << 18;
const int KEY = 0xFFFF;
const int WHEELUP = 1012;
const int WHEELDOWN = 1013;

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

bool raw;
bool alternate;
int pointerColumn;
int pointerRow;

fn int env(String name, int fallback)
{
    @pool()
    {
        String? value = env::tget_var(name);
        if (catch value) return fallback;
        return value.to_int() ?? fallback;
    };
}

fn String? variable(String name) => env::tget_var(name);

fn int width() => scripted ? fixed[0] : max(size()[0], 0) ?: env("COLUMNS", 80);

fn int height() => scripted ? fixed[1] : max(size()[1], 0) ?: env("LINES", 24);

fn void enter()
{
    out("\e[?1049h\e[?7l\e[>1u\e[?2004h\e[2J\e[3J\e[H\e[?25l");
    alternate = true;
}

fn void leave()
{
    if (!alternate) return;
    out("\e[<u\e[?2004l\e[?1002l\e[?1006l\e[?7h\e[?1049l\e[?25h\e[0m");
    alternate = false;
}

fn void mouse(bool on)
{
    out(on ? "\e[?1002h\e[?1006h" : "\e[?1002l\e[?1006l");
}

fn void copy(String content)
{
    @pool()
    {
        out(string::tformat("\e]52;c;%s\e\\", base64::tencode(content)));
    };
}

bool scripted;
String[] script;
usz step;
ulong fake;
ulong due = 500;
int[2] fixed = { 100, 30 };

struct Named
{
    String name;
    String bytes;
}

const Named[] NAMED = {
    { "Up", "A" }, { "Down", "B" }, { "Right", "C" }, { "Left", "D" }, { "Home", "H" }, { "End", "F" },
};

const Named[] PLAIN = {
    { "Enter", "\r" }, { "Escape", "\e" }, { "Tab", "\t" }, { "BTab", "\e[Z" }, { "Space", " " },
    { "BSpace", "\x7f" }, { "DC", "\e[3~" }, { "PageDown", "\e[6~" }, { "PageUp", "\e[5~" },
};

fn void play()
{
    @pool()
    {
        String? keys = env::tget_var("MDV_KEYS");
        if (catch keys) return;
        String[] size = (env::tget_var("MDV_SIZE") ?? "100x30").tsplit("x");
        scripted = true;
        script = keys.copy(mem).split(mem, "\n");
        fixed = { size[0].to_int() ?? 100, size[1].to_int() ?? 30 };
    };
}

fn void push(String bytes)
{
    foreach (c : bytes) if (pendingLen < pending.len) pending[pendingLen++] = c;
}

fn void press(String token)
{
    int mods;
    while (token.len > 2 && token[1] == '-' && (token[0] == 'C' || token[0] == 'M' || token[0] == 'S'))
    {
        mods |= token[0] == 'S' ? 1 : token[0] == 'M' ? 2 : 4;
        token = token[2..];
    }
    foreach (n : NAMED)
    {
        if (n.name != token) continue;
        @pool()
        {
            push(mods == 0 ? string::tformat("\e[%s", n.bytes) : string::tformat("\e[1;%d%s", mods + 1, n.bytes));
        };
        return;
    }
    foreach (n : PLAIN)
    {
        if (n.name != token) continue;
        push(n.bytes);
        return;
    }
    if (mods == 4 && token.len == 1)
    {
        char c = token[0] & 0x1f;
        push((String)(&c)[:1]);
        return;
    }
    if (mods == 2) push("\e");
    push(token);
}

fn void feed()
{
    if (pendingLen > 0 || fake < due || step >= script.len) return;
    String token = script[step++];
    due = fake + 300;
    if (token.starts_with("!"))
    {
        shell(token[1..]);
        due = fake + 500;
        return;
    }
    if (token.starts_with("resize:"))
    {
        String[] size = token[7..].tsplit("x");
        fixed = { size[0].to_int() ?? 80, size[1].to_int() ?? 24 };
        return;
    }
    if (token.starts_with("\e"))
    {
        push(token);
        return;
    }
    press(token);
}

fn String here()
{
    Path? cwd = path::tcwd();
    if (try cwd) return (String)cwd;
    return ".";
}

fn void move(String dir) => (void)path::chdir(dir);

const char[] ARROWS = { 'A', 'B', 'C', 'D', 'H', 'F' };
const int[] ARROWKEYS = { UP, DOWN, RIGHT, LEFT, HOME, END };
const char[] CONTROL = { 0x09, '\r', '\n', 0x7f };
const int[] CONTROLKEYS = { TAB, ENTER, ENTER, BACKSPACE };

fn int control(int c)
{
    foreach (i, k : CONTROL) if (c == k) return CONTROLKEYS[i];
    return c;
}

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
        return control(buf[0]);
    }
    if (n == 1) return ESC;
    if (n >= 6 && buf[1] == '[' && buf[2] == '<')
    {
        int[3] value;
        int field;
        for (int p = 3; p < n - 1; p++)
        {
            if (buf[p] == ';')
            {
                if (++field > 2) break;
                continue;
            }
            if (buf[p].is_digit()) value[field] = value[field] * 10 + buf[p] - '0';
        }
        int button = value[0];
        pointerColumn = value[1];
        pointerRow = value[2];
        if ((button & 64) != 0) return wheel(button);
        if (buf[n - 1] == 'm') return RELEASE;
        if ((button & 3) != 0) return 0;
        if ((button & 32) != 0) return DRAG;
        return (button & 4) != 0 ? CLICK | SHIFT : CLICK;
    }
    if (n >= 6 && buf[1] == '[' && buf[2] == 'M') return wheel(buf[3] - 32);
    char last = buf[n - 1];
    if (n >= 3 && buf[1] == 'O') return arrow(buf[2], last, false);
    if (n < 3 || buf[1] != '[') return ESC;
    if (n == 6 && buf[2] == '2' && buf[3] == '0' && buf[4] == '0' && buf[5] == '~') return PASTE;
    if (n == 6 && buf[2] == '2' && buf[3] == '0' && buf[4] == '1' && buf[5] == '~') return PASTED;
    if (last == 'Z') return BACKTAB;
    int code;
    int p = 2;
    for (; p < n && buf[p].is_digit(); p++) code = code * 10 + buf[p] - '0';
    int mods;
    if (p < n && buf[p] == ';') for (p++; p < n && buf[p].is_digit(); p++) mods = mods * 10 + buf[p] - '0';
    int m = max(mods - 1, 0);
    int flags = ((m & 1) != 0 ? SHIFT : 0) | ((m & 2) != 0 ? ALT : 0) | ((m & 4) != 0 ? CTRL : 0);
    if (last == 'u')
    {
        if ((flags & CTRL) != 0 && code >= 'a' && code <= 'z') return code & 0x1f;
        return control(code) | (flags & (CTRL | ALT));
    }
    int k = arrow(buf[2], last, true);
    if (k == 0 && last == '~')
    {
        switch (code)
        {
            case 1:
            case 7: k = HOME;
            case 3: k = DELETE;
            case 4:
            case 8: k = END;
            case 5: k = PAGEUP;
            case 6: k = PAGEDOWN;
        }
    }
    if (k == 0 && (last == 'H' || buf[2] == 'H')) k = HOME;
    if (k == 0 && (last == 'F' || buf[2] == 'F')) k = END;
    return k == 0 ? ESC : k | flags;
}

fn int key()
{
    while (true)
    {
        if (scripted)
        {
            feed();
            if (pendingLen == 0) return step >= script.len && fake >= due ? DONE : 0;
        }
        else if (pendingLen == 0)
        {
            fill();
        }
        if (pendingLen == 0) return 0;
        bool partial = pending[0] == ESC && (pendingLen == 1 || (pendingLen == 2 && (pending[1] == '[' || pending[1] == 'O')));
        if (partial && wait(20) && !scripted) fill();
        int len = length(pending[:pendingLen]);
        int k = decode(pending[:len]);
        pendingLen -= len;
        mem::move(&pending, &pending[len], pendingLen);
        if (k) return k;
    }
}

fn void out(String s)
{
    if (scripted) return;
    io::stdout().write(s)!!;
    io::stdout().flush()!!;
}

fn bool tty() => scripted || io::stdout().isatty();

fn bool piped() => !scripted && !io::stdin().isatty();

fn void onSignal(CInt sig)
{
    cooked();
    leave();
    libc::exit(128 + sig);
}

fn void edit(String path, int line)
{
    cooked();
    leave();
    @pool()
    {
        String editor = variable("EDITOR") ?? variable("VISUAL") ?? "nano";
        if (editor.len == 0) editor = "nano";
        libc::system(string::tformat("%s +%d \"%s\"", editor, line, path).zstr_tcopy());
    };
    rawMode();
    enter();
}

fn ulong now() => scripted ? fake : (ulong)clock::now() / 1_000_000;

fn Stamp stamp(String file)
{
    $if env::WIN32:
        long? size = file::get_size(file);
        Time? time = file::last_modified(file);
        if (catch size) return {};
        if (catch time) return {};
        return { 1, size, (long)time, 0 };
    $else
        Stat st;
        @pool()
        {
            if (libc::stat(file.zstr_tcopy(), &st) != 0) return {};
        };
        $switch:
            $case env::DARWIN:
                return { st.st_ino, st.st_size, st.st_mtimespec.s, (ulong)st.st_mtimespec.ns };
            $case $defined(st.st_mtime_nsec):
                return { st.st_ino, st.st_size, st.st_mtime, (ulong)st.st_mtime_nsec };
            $case $defined(st.st_mtimensec):
                return { st.st_ino, st.st_size, st.st_mtime, (ulong)st.st_mtimensec };
            $default:
                return { st.st_ino, st.st_size, st.st_mtime.s, (ulong)st.st_mtime.ns };
        $endswitch
    $endif
}


fn void shell(String command)
{
    @pool()
    {
        libc::system(command.zstr_tcopy());
    };
}

fn bool store(String name, String text) => @ok(file::save(name, text));
