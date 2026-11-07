module terminal @feat(WIN32);

import std::core::string::conv;
import libc;

const uint STD_INPUT = 0xFFFFFFF6;
const uint STD_OUTPUT = 0xFFFFFFF5;
const uint VT_INPUT = 0x0200;
const uint VT_OUTPUT = 0x0004;
const uint LINE_INPUT = 0x0002;
const uint ECHO_INPUT = 0x0004;
const uint PROCESSED_INPUT = 0x0001;
const uint UTF8 = 65001;

struct Coord
{
    short x;
    short y;
}

struct ScreenInfo
{
    Coord size;
    Coord cursor;
    ushort attributes;
    short left;
    short top;
    short right;
    short bottom;
    Coord maximum;
}

struct KeyRecord
{
    ushort type;
    ushort pad;
    int down;
    ushort repeat;
    ushort virtualKey;
    ushort scan;
    ushort unicode;
    uint control;
}

extern fn void* getStdHandle(uint which) @cname("GetStdHandle");
extern fn int getConsoleMode(void* handle, uint* mode) @cname("GetConsoleMode");
extern fn int setConsoleMode(void* handle, uint mode) @cname("SetConsoleMode");
extern fn int setConsoleCP(uint page) @cname("SetConsoleCP");
extern fn int setConsoleOutputCP(uint page) @cname("SetConsoleOutputCP");
extern fn int getConsoleScreenBufferInfo(void* handle, ScreenInfo* info) @cname("GetConsoleScreenBufferInfo");
extern fn uint waitForSingleObject(void* handle, uint ms) @cname("WaitForSingleObject");
extern fn int getNumberOfConsoleInputEvents(void* handle, uint* count) @cname("GetNumberOfConsoleInputEvents");
extern fn int readConsoleInputW(void* handle, KeyRecord* records, uint length, uint* read) @cname("ReadConsoleInputW");

uint savedInput;
uint savedOutput;
ushort surrogate;

fn int[2] size()
{
    ScreenInfo info;
    if (getConsoleScreenBufferInfo(getStdHandle(STD_OUTPUT), &info) == 0) return { 0, 0 };
    return { info.right - info.left + 1, info.bottom - info.top + 1 };
}

fn void rawMode()
{
    if (raw || scripted || piped()) return;
    void* input = getStdHandle(STD_INPUT);
    void* output = getStdHandle(STD_OUTPUT);
    getConsoleMode(input, &savedInput);
    getConsoleMode(output, &savedOutput);
    setConsoleMode(input, (savedInput & ~(LINE_INPUT | ECHO_INPUT | PROCESSED_INPUT)) | VT_INPUT);
    setConsoleMode(output, savedOutput | VT_OUTPUT);
    setConsoleCP(UTF8);
    setConsoleOutputCP(UTF8);
    libc::signal(15, &onSignal);
    raw = true;
    out("\e[?25l");
}

fn void cooked()
{
    if (!raw) return;
    setConsoleMode(getStdHandle(STD_INPUT), savedInput);
    setConsoleMode(getStdHandle(STD_OUTPUT), savedOutput);
    raw = false;
    out("\e[?25h");
}

fn bool wait(int ms)
{
    if (scripted)
    {
        fake += (ulong)ms;
        return pendingLen > 0;
    }
    return waitForSingleObject(getStdHandle(STD_INPUT), (uint)ms) == 0;
}

fn void fill()
{
    void* input = getStdHandle(STD_INPUT);
    uint count;
    if (getNumberOfConsoleInputEvents(input, &count) == 0 || count == 0) return;
    KeyRecord[32] records;
    uint read;
    if (readConsoleInputW(input, &records[0], min(count, 32u), &read) == 0) return;
    foreach (r : records[:read])
    {
        if (r.type != 1 || r.down == 0 || r.unicode == 0) continue;
        uint code = r.unicode;
        if (code >= 0xD800 && code < 0xDC00)
        {
            surrogate = r.unicode;
            continue;
        }
        if (code >= 0xDC00 && code < 0xE000) code = 0x10000 + ((uint)(surrogate - 0xD800) << 10) + (code - 0xDC00);
        char[4] bytes;
        sz n = conv::char32_to_utf8((Char32)code, &bytes)!!;
        if (pendingLen + (int)n > (int)pending.len) return;
        foreach (c : bytes[:n]) pending[pendingLen++] = c;
    }
}
