module terminal @feat(LINUX, DARWIN);

import libc;
import libc::termios;

Termios saved;

fn void rawMode()
{
    if (raw || scripted || piped()) return;
    libc::signal(2, &onSignal);
    libc::signal(15, &onSignal);
    libc::signal(1, &onSignal);
    listen();
    if (termios::tcgetattr(0, &saved) != 0) return;
    Termios t = saved;
    t.c_lflag.icanon = false;
    t.c_lflag.echo = false;
    t.c_lflag.iexten = false;
    t.c_iflag.ixon = false;
    t.c_cc[Control_Char.VINTR] = 0;
    t.c_cc[Control_Char.VSUSP] = 0;
    t.c_cc[Control_Char.VMIN] = 0;
    t.c_cc[Control_Char.VTIME] = 0;
    termios::tcsetattr(0, Tcactions.TCSANOW, &t);
    raw = true;
    out("\e[?25l");
}

fn void cooked()
{
    if (!raw) return;
    termios::tcsetattr(0, Tcactions.TCSANOW, &saved);
    raw = false;
    out("\e[?25h");
}
