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
extern fn CInt pipe(CInt* fds);
extern fn CInt fcntl(CInt fd, CInt command, ...);
extern fn CInt inotify_init1(CInt flags) @feat(LINUX);
extern fn CInt inotify_add_watch(CInt fd, ZString path, uint mask) @feat(LINUX);
extern fn CInt inotify_rm_watch(CInt fd, CInt watch) @feat(LINUX);
extern fn CInt kqueue() @feat(DARWIN);
extern fn CInt kevent(CInt queue, Kevent* changes, CInt count, Kevent* events, CInt size, libc::TimeSpec* timeout) @feat(DARWIN);
extern fn CInt open(ZString path, CInt flags, ...) @feat(DARWIN);

struct Kevent @feat(DARWIN)
{
    uptr ident;
    short filter;
    ushort flags;
    uint fflags;
    iptr data;
    void* udata;
}

CInt[2] bell = { -1, -1 };
CInt changes = -1;
CInt folder = -1;
CInt[2] opened = { -1, -1 };
char[4096] scratch;

fn void ring(CInt sig)
{
    char c;
    libc::write(bell[1], &c, 1);
}

fn void listen()
{
    if (bell[0] >= 0 || pipe(&bell) != 0) return;
    foreach (fd : bell) fcntl(fd, 4, env::LINUX ? 0x800 : 0x4);
    libc::signal(28, &ring);
}

fn void follow(String file)
{
    sz slash = file.rindex_of_char('/') ?? -1;
    String dir = slash < 0 ? "." : slash == 0 ? "/" : file[:slash];
    $switch:
        $case env::LINUX:
            if (changes < 0) changes = inotify_init1(0x800);
            if (folder >= 0) inotify_rm_watch(changes, folder);
            @pool()
            {
                folder = inotify_add_watch(changes, dir.zstr_tcopy(), 0x2 | 0x4 | 0x8 | 0x80 | 0x100 | 0x200);
            };
        $case env::DARWIN:
            if (changes < 0) changes = kqueue();
            String[2] paths = { dir, file };
            foreach (i, path : paths)
            {
                if (opened[i] >= 0) libc::close(opened[i]);
                @pool()
                {
                    opened[i] = open(path.zstr_tcopy(), 0x8000);
                };
                if (opened[i] < 0) continue;
                Kevent change = { .ident = (uptr)opened[i], .filter = -4, .flags = 0x1 | 0x20, .fflags = 0x1 | 0x2 | 0x4 | 0x8 | 0x20 };
                kevent(changes, &change, 1, null, 0, null);
            }
    $endswitch
}

fn void clear(CInt fd)
{
    $if env::DARWIN:
        if (fd == changes)
        {
            Kevent[8] events;
            libc::TimeSpec zero;
            while (kevent(fd, null, 0, &events, events.len, &zero) > 0) {}
            return;
        }
    $endif
    while (libc::read(fd, &scratch, scratch.len) > 0) {}
}

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
        fake += (ulong)(ms < 0 ? 30 : min(ms, 30));
        return pendingLen > 0;
    }
    if (!env::LINUX && !env::DARWIN && (ms < 0 || ms > 30)) ms = 30;
    PollFd[3] p = { { .fd = 0, .events = 1 }, { .fd = bell[0], .events = 1 }, { .fd = changes, .events = 1 } };
    if (poll(&p, 3, ms) <= 0) return false;
    foreach (q : p[1..]) if (q.revents != 0) clear(q.fd);
    return (p[0].revents & 1) != 0;
}

fn void fill()
{
    sz n = libc::read(0, &pending[pendingLen], (usz)(pending.len - pendingLen));
    if (n > 0) pendingLen += (int)n;
}
