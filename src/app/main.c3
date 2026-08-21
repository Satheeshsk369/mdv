module main;

import std::io;
import std::core::mem;
import std::core::string;
import ansi;
import logic;
import terminal;
import strutils;
import parser;
import render;
import app;

extern fn int isatty(int fd);
extern fn int read(int fd, void* buf, ulong count);

fn void print_version()
{
    io::printn("mdv 0.2.0");
}

fn void print_help()
{
    print_version();
    io::printn("");
    io::printn("Usage:");
    io::printn("    mdv <file.md> [line]     Live watch & render in viewer (Default)");
    io::printn("    mdv -s <file.md>         Print rendered text directly to stdout and exit");
    io::printn("    cat file.md | mdv");
    io::printn("");
    io::printn("Options:");
    io::printn("    -s, --stdout             Print rendered text directly to stdout and exit");
    io::printn("    -p, --plain              Print plain text without ANSI formatting");
    io::printn("    -nw, --no-wrap           Disable line wrapping");
    io::printn("    --light                  Use light theme palette");
    io::printn("    --dark                   Use dark theme palette (default)");
    io::printn("    -h, --help               Show help");
    io::printn("    -v, --version            Show version");
    io::printn("");
}

fn void render_file_stdout(char* filename, int width, bool no_wrap)
{
    char* content = strutils::load_file_string(filename);
    if (content == null)
    {
        if (!ansi::plain_mode) io::print(ansi::fg_pink);
        io::printfn("Error: Could not open file '%s'", (ZString)filename);
        if (!ansi::plain_mode) io::print(ansi::RESET);
        return;
    }
    defer mem::free(content);

    RenderConfig config;
    config.width = width;
    config.plain = ansi::plain_mode;
    config.no_wrap = no_wrap;

    String content_str = (String)content[:strutils::str_len(content)];
    Document doc = parser::parse_document(content_str);
    defer doc.free();

    render::render_to_stdout(&doc, config);
}

fn void read_and_render_stdin(int width, bool no_wrap)
{
    render::render_and_stream_stdin(width, no_wrap);
}

fn int main(String[] args)
{
    bool force_stdout = false;
    bool no_wrap = false;
    char* target_file = null;
    int target_line = 0;

    for (int i = 1; i < args.len; i++)
    {
        String arg = args[i];
        if (arg == "-h" || arg == "--help")
        {
            print_help();
            return 0;
        }
        if (arg == "-v" || arg == "--version")
        {
            print_version();
            return 0;
        }
        if (arg == "-nw" || arg == "--no-wrap")
        {
            no_wrap = true;
            continue;
        }
        if (arg == "-w" || arg == "--watch")
        {
            continue;
        }
        if (arg == "-s" || arg == "--stdout")
        {
            force_stdout = true;
            continue;
        }
        if (arg == "-p" || arg == "-P" || arg == "--plain")
        {
            ansi::set_plain(true);
            force_stdout = true;
            continue;
        }
        if (arg == "--light" || arg == "-light")
        {
            ansi::set_theme(ansi::Theme.LIGHT);
            continue;
        }
        if (arg == "--dark" || arg == "-dark")
        {
            ansi::set_theme(ansi::Theme.DARK);
            continue;
        }
        if (strutils::is_numeric((char*)arg.ptr))
        {
            target_line = strutils::parse_int((char*)arg.ptr);
            continue;
        }
        if (!arg.starts_with("-"))
        {
            target_file = (char*)arg.ptr;
        }
        else if (arg == "-")
        {
            target_file = "-";
        }
    }

    int width = terminal::get_width();
    int height = terminal::get_height();

    logic::init_global_context(width, height);
    defer logic::free_global_context();

    logic::AppFlags flag_tty = { .is_tty };
    logic::AppFlags flag_wrap = { .no_wrap };
    logic::AppFlags flag_plain = { .plain_mode };
    logic::AppFlags flag_stdout = { .stdout_mode };

    logic::set_app_flag(terminal::is_tty(), flag_tty);
    logic::set_app_flag(no_wrap, flag_wrap);
    logic::set_app_flag(ansi::plain_mode, flag_plain);
    logic::set_app_flag(force_stdout, flag_stdout);

    if (target_file != null && !strutils::str_eq(target_file, "-"))
    {
        // Parse "filename:line" syntax
        int colon_pos = -1;
        int fn_len = strutils::str_len(target_file);
        for (int k = fn_len - 1; k >= 0; k--)
        {
            if (target_file[k] == ':') { colon_pos = k; break; }
        }
        if (colon_pos > 0 && colon_pos < fn_len - 1 && strutils::is_numeric(target_file + colon_pos + 1))
        {
            target_line = strutils::parse_int(target_file + colon_pos + 1);
            target_file[colon_pos] = 0;
        }

        // 1. Explicit stdout stream or non-interactive pipe
        if (force_stdout || !terminal::is_tty())
        {
            render_file_stdout(target_file, width, no_wrap);
            return 0;
        }

        // 2. Default: Live watch viewer with auto line sync, scroll retention & native mouse selection
        app::run_watch(target_file, target_line, no_wrap);
        return 0;
    }

    // If stdin is piped or '-' specified
    if (strutils::str_eq(target_file, "-") || isatty(0) == 0)
    {
        read_and_render_stdin(width, no_wrap);
        return 0;
    }

    // Default when run interactively without arguments: Open directly into File Switcher
    if (terminal::is_tty())
    {
        terminal::FileTree file_tree;
        terminal::scan_file_tree(null, &file_tree);
        if (file_tree.count > 0)
        {
            char* first_file = null;
            for (usz i = 0; i < file_tree.count; i++)
            {
                if (!file_tree.nodes[i].is_dir)
                {
                    first_file = &file_tree.nodes[i].path[0];
                    break;
                }
            }
            if (first_file != null)
            {
                app::run_watch(first_file, 0, no_wrap, true);
                return 0;
            }
        }

        io::printn("No Markdown files (*.md) found in the current directory.");
        io::printn("");
    }

    print_help();
    return 1;
}
