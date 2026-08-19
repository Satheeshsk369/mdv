module install;

import std::io;
import ansi;
import strutils;

extern fn int system(char* command);
extern fn char* getenv(char* name);

fn int main(String[] args)
{
    io::print(ansi::fg_cyan);
    io::printn("==> Building mdview target…");
    io::print(ansi::RESET);

    int res = system("c3c build mdview");
    if (res != 0)
    {
        io::print(ansi::fg_pink);
        io::printn("Error: Failed to build mdview target");
        io::print(ansi::RESET);
        return 1;
    }

    char* home = getenv("HOME");
    if (home == null || home[0] == 0)
    {
        io::print(ansi::fg_pink);
        io::printn("Error: HOME environment variable is not set");
        io::print(ansi::RESET);
        return 1;
    }

    char[1024] cmd;
    strutils::copy_str(&cmd[0], "mkdir -p ", 1024);
    strutils::append_str(&cmd[0], home, 1024);
    strutils::append_str(&cmd[0], "/.local/bin && rm -f ", 1024);
    strutils::append_str(&cmd[0], home, 1024);
    strutils::append_str(&cmd[0], "/.local/bin/mdview && cp build/mdview ", 1024);
    strutils::append_str(&cmd[0], home, 1024);
    strutils::append_str(&cmd[0], "/.local/bin/mdview && chmod 755 ", 1024);
    strutils::append_str(&cmd[0], home, 1024);
    strutils::append_str(&cmd[0], "/.local/bin/mdview", 1024);

    int copy_res = system(&cmd[0]);
    if (copy_res != 0)
    {
        io::print(ansi::fg_pink);
        io::printn("Error: Failed to copy binary to ~/.local/bin/mdview");
        io::print(ansi::RESET);
        return 1;
    }

    io::print(ansi::fg_green);
    io::print(ansi::BOLD);
    io::print("✔ Successfully installed mdview to ");
    io::print(ansi::RESET);
    io::print(ansi::fg_cyan);
    io::printfn("%s/.local/bin/mdview", (ZString)home);
    io::print(ansi::RESET);
    return 0;
}
