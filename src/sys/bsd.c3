module terminal @feat(BSD);

import libc;

struct Termios
{
    uint iflag;
    uint oflag;
    uint cflag;
    uint lflag;
    char[20] cc;
    uint ispeed;
    uint ospeed;
}

const uint ICANON = 0x100;
const uint ECHO = 0x8;
const uint IEXTEN = 0x400;
const uint IXON = 0x200;
const int VINTR = 8;
const int VSUSP = 10;
const int VMIN = 16;
const int VTIME = 17;

extern fn CInt tcgetattr(CInt fd, Termios* t);
extern fn CInt tcsetattr(CInt fd, CInt action, Termios* t);

Termios saved;

fn void rawMode()
{
    if (raw || scripted || piped()) return;
    libc::signal(2, &onSignal);
    libc::signal(15, &onSignal);
    libc::signal(1, &onSignal);
    if (tcgetattr(0, &saved) != 0) return;
    Termios t = saved;
    t.lflag &= ~(ICANON | ECHO | IEXTEN);
    t.iflag &= ~IXON;
    t.cc[VINTR] = 0;
    t.cc[VSUSP] = 0;
    t.cc[VMIN] = 0;
    t.cc[VTIME] = 0;
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
