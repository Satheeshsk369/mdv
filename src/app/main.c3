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
extern fn int system(char* command);

fn void print_version()
{
    if (!ansi::plain_mode) io::print(ansi::FG_CYAN);
    io::print("  mdview ");
    if (!ansi::plain_mode) io::print(ansi::RESET);
    io::printn("v0.1.0 — High Performance C3 Markdown & LaTeX Terminal Viewer");
}

fn void print_help()
{
    print_version();
    io::printn("");
    if (!ansi::plain_mode) io::print(ansi::BOLD);
    io::printn("USAGE:");
    if (!ansi::plain_mode) io::print(ansi::RESET);
    io::printn("    mdview <file.md> [line_number]     Live watch preview with instant line sync & colors");
    io::printn("    mdview <file.md:line>              Live watch synchronized to line (e.g. doc.md:42)");
    io::printn("    mdview -p, --pager <file.md>       Open in 'less -R -S' one-shot pager");
    io::printn("    mdview -s, --stdout <file.md>      Output raw rendered text directly to stdout");
    io::printn("    mdview -P, --plain <file.md>       Output plain Unicode text without ANSI codes");
    io::printn("    cat file.md | mdview               Read from stdin and render");
    io::printn("");
    if (!ansi::plain_mode) io::print(ansi::BOLD);
    io::printn("FAST NAVIGATION (WATCH MODE):");
    if (!ansi::plain_mode) io::print(ansi::RESET);
    io::printn("    j / ↓              Scroll down 1 line");
    io::printn("    k / ↑              Scroll up 1 line");
    io::printn("    d / Ctrl+D         Half page down");
    io::printn("    u / Ctrl+U         Half page up");
    io::printn("    Space / Ctrl+F     Full page down");
    io::printn("    Ctrl+B             Full page up");
    io::printn("    g / G              Jump to Top / Bottom");
    io::printn("    q / Esc / Ctrl+C   Exit viewer");
    io::printn("");
}

fn void render_file_stdout(char* filename, int width)
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

    String content_str = (String)content[:strutils::str_len(content)];
    ast::Document doc = parser::parse_document(content_str);
    defer doc.free();

    render::render_to_stdout(&doc, config);
}

fn void render_file_pager(char* filename, int target_line, int width)
{
    int v_line = target_line;
    if (target_line > 0)
    {
        char* content = strutils::load_file_string(filename);
        if (content != null)
        {
            render::RenderConfig config;
            config.width = width;
            config.plain = ansi::plain_mode;

            String content_str = (String)content[:strutils::str_len(content)];
            ast::Document doc = parser::parse_document(content_str);
            layout::VisualDocument vdoc = render::render_document(&doc, config);
            v_line = vdoc.find_visual_line(target_line - 1) + 1;

            doc.free();
            vdoc.free();
            mem::free(content);
        }
    }

    char[1024] cmd;
    strutils::copy_str(&cmd[0], "mdview --stdout '", 1024);
    strutils::append_str(&cmd[0], filename, 1024);
    strutils::append_str(&cmd[0], "' | less -R -S", 1024);

    if (v_line > 1)
    {
        strutils::append_str(&cmd[0], " +", 1024);
        char[32] num_buf;
        int p = 0;
        int temp = v_line;
        while (temp > 0)
        {
            num_buf[p++] = (char)('0' + (temp % 10));
            temp /= 10;
        }
        for (int i = p - 1; i >= 0; i--)
        {
            char[2] ch; ch[0] = num_buf[i]; ch[1] = 0;
            strutils::append_str(&cmd[0], &ch[0], 1024);
        }
    }

    system(&cmd[0]);
}

fn void read_and_render_stdin(int width)
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

        String content_str = (String)buf_slice[:total];
        ast::Document doc = parser::parse_document(content_str);
        defer doc.free();

        render::render_to_stdout(&doc, config);
    }
}

fn int main(String[] args)
{
    bool force_stdout = false;
    bool pager_mode = false;
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
        if (strutils::str_eq(arg, "-w") || strutils::str_eq(arg, "--watch"))
        {
            continue;
        }
        if (strutils::str_eq(arg, "-p") || strutils::str_eq(arg, "--pager"))
        {
            pager_mode = true;
            continue;
        }
        if (strutils::str_eq(arg, "-s") || strutils::str_eq(arg, "--stdout"))
        {
            force_stdout = true;
            continue;
        }
        if (strutils::str_eq(arg, "-P") || strutils::str_eq(arg, "--plain"))
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

        // 1. One-shot static pager
        if (pager_mode)
        {
            render_file_pager(target_file, target_line, width);
            return 0;
        }

        // 2. Direct stdout stream
        if (force_stdout || !terminal::is_tty())
        {
            render_file_stdout(target_file, width);
            return 0;
        }

        // 3. Default: Live watch viewer with auto line sync & full colors
        app::run_watch(target_file, target_line);
        return 0;
    }

    // If stdin is piped or '-' specified
    if (strutils::str_eq(target_file, "-") || isatty(0) == 0)
    {
        read_and_render_stdin(width);
        return 0;
    }

    print_help();
    return 1;
}
