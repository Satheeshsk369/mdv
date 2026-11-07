module terminal @feat(LINUX, DARWIN, BSD, WIN32);

import std::io;
import std::io::file;
import std::time::clock;
import libc;

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
