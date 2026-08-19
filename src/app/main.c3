module main;

import std::io;
import std::core::mem;
import ansi;
import terminal;
import strutils;
import ast;
import parser;
import render;
import layout;
import app;

extern fn int isatty(int fd);
extern fn int read(int fd, void* buf, ulong count);

fn void print_version()
{
    io::printn("mdview 0.2.0");
}

fn void print_help()
{
    print_version();
    io::printn("");
    io::printn("Usage:");
    io::printn("    mdview <file.md> [line]");
    io::printn("    mdview [options] <file.md>");
    io::printn("    cat file.md | mdview");
    io::printn("");
    io::printn("Options:");
    io::printn("    -s, --stdout             Print rendered text directly to stdout");
    io::printn("    -p, --plain              Print plain text without ANSI formatting");
    io::printn("    -nw, --no-wrap           Disable line wrapping");
    io::printn("    -h, --help               Show help");
    io::printn("    -v, --version            Show version");
    io::printn("");
}

fn void render_file_stdout(char* filename, int width, bool no_wrap)
{
    char* content = strutils::load_file_string(filename);
    if (content == null)
    {
        if (!ansi::plain_mode) io::print(ansi::FG_PINK);
        io::printfn("Error: Could not open file '%s'", (ZString)filename);
        if (!ansi::plain_mode) io::print(ansi::RESET);
        return;
    }
    defer mem::free(content);

    render::RenderConfig config;
    config.width = width;
    config.plain = ansi::plain_mode;
    config.no_wrap = no_wrap;

    String content_str = (String)content[:strutils::str_len(content)];
    ast::Document doc = parser::parse_document(content_str);
    defer doc.free();

    render::render_to_stdout(&doc, config);
}

fn void read_and_render_stdin(int width, bool no_wrap)
{
    const usz MAX_TOTAL = 4 * 1024 * 1024; // 4MB
    char[] buf_slice = mem::alloc_array(char, (sz)MAX_TOTAL);
    defer mem::free(buf_slice);
    int total = 0;
    const int CHUNK = 65536;

    while (total < (int)MAX_TOTAL - CHUNK - 1)
    {
        int bytes = read(0, (void*)(buf_slice.ptr + total), (ulong)CHUNK);
        if (bytes <= 0) break;
        total += bytes;
    }
    buf_slice[total] = 0;

    if (total > 0)
    {
        render::RenderConfig config;
        config.width = width;
        config.plain = ansi::plain_mode;
        config.no_wrap = no_wrap;

        String content_str = (String)buf_slice[:total];
        ast::Document doc = parser::parse_document(content_str);
        defer doc.free();

        render::render_to_stdout(&doc, config);
    }
}

fn int main(String[] args)
{
    bool force_stdout = false;
    bool no_wrap = false;
    char* target_file = null;
    int target_line = 0;

    for (int i = 1; i < args.len; i++)
    {
        char* arg = (char*)args[i].ptr;
        if (strutils::str_eq(arg, "-h") || strutils::str_eq(arg, "--help"))
        {
            print_help();
            return 0;
        }
        if (strutils::str_eq(arg, "-v") || strutils::str_eq(arg, "--version"))
        {
            print_version();
            return 0;
        }
        if (strutils::str_eq(arg, "-nw") || strutils::str_eq(arg, "--no-wrap"))
        {
            no_wrap = true;
            continue;
        }
        if (strutils::str_eq(arg, "-w") || strutils::str_eq(arg, "--watch"))
        {
            continue;
        }
        if (strutils::str_eq(arg, "-s") || strutils::str_eq(arg, "--stdout"))
        {
            force_stdout = true;
            continue;
        }
        if (strutils::str_eq(arg, "-p") || strutils::str_eq(arg, "-P") || strutils::str_eq(arg, "--plain"))
        {
            ansi::set_plain(true);
            force_stdout = true;
            continue;
        }
        if (strutils::is_numeric(arg))
        {
            target_line = strutils::parse_int(arg);
            continue;
        }
        if (arg[0] != '-')
        {
            target_file = arg;
        }
        else if (strutils::str_eq(arg, "-"))
        {
            target_file = "-";
        }
    }

    int width = terminal::get_width();

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

        // 1. Direct stdout stream
        if (force_stdout || !terminal::is_tty())
        {
            render_file_stdout(target_file, width, no_wrap);
            return 0;
        }

        // 2. Default: Live watch viewer with auto line sync & full colors
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
