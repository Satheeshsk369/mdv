module terminal @feat(LINUX, DARWIN, BSD);

import libc;

struct WinSize
{
    ushort rows;
    ushort columns;
    ushort xpixel;
    ushort ypixel;
}

struct PollFd
{
    CInt fd;
    short events;
    short revents;
}

extern fn CInt poll(PollFd* fds, ulong count, CInt timeout);

fn int[2] size()
{
    WinSize ws;
    if (libc::ioctl(1, env::DARWIN ? 0x40087468 : 0x5413, &ws) != 0) return { 0, 0 };
    return { ws.columns, ws.rows };
}

fn bool wait(int ms)
{
    if (scripted)
    {
        fake += (ulong)ms;
        return pendingLen > 0;
    }
    PollFd p = { .fd = 0, .events = 1 };
    return poll(&p, 1, ms) > 0 && (p.revents & 1) != 0;
}

fn void fill()
{
    sz n = libc::read(0, &pending[pendingLen], (usz)(pending.len - pendingLen));
    if (n > 0) pendingLen += (int)n;
}
