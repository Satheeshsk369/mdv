module main;

import std::io;
import std::core::mem;
import ansi;
import ast;
import terminal;
import text;
import parser;
import render;
import app;


const String HELP = `mdv 0.3.0

Usage:
    mdv                       Pick a Markdown file in this folder
    mdv <file.md>[:line]      Live view, reloads on save
    mdv <file.md> -s          Print rendered text and exit
    cat file.md | mdv         Render stdin

Options:
    -s           Print to stdout
    -p           Plain text, no colour (implies -s)
    -nw          No wrapping
    -W <cols>    Wrap width
    -h           Help
    -v           Version`;

fn void print(String content, render::Config config)
{
    Document doc = parser::parse(content);
    defer doc.free();
    render::print(&doc, config);
}

fn int main(String[] args)
{
    terminal::play();
    bool stdout = false;
    bool noWrap = false;
    bool plain = false;
    int width = 0;
    int line = 0;
    String file;

    for (usz i = 1; i < args.len; i++)
    {
        switch (args[i])
        {
            case "-h":
                io::printn(HELP);
                return 0;
            case "-v":
                io::printn("mdv 0.3.0");
                return 0;
            case "-s":
                stdout = true;
            case "-p":
                plain = true;
                stdout = true;
            case "-nw":
                noWrap = true;
            case "-W":
                if (i + 1 < args.len) width = args[++i].to_int() ?? 0;
            default:
                if (try n = args[i].to_int())
                {
                    line = n;
                }
                else
                {
                    file = args[i];
                }
        }
    }

    if (width <= 0) width = terminal::width();

    render::Config config = { .width = width, .plain = plain, .noWrap = noWrap };

    if (file.len == 0 || file == "-")
    {
        if (terminal::piped() || file == "-")
        {
            char[]? input = io::read_fully(mem, io::stdin());
            if (catch input) return 1;
            defer free(input);
            print((String)input, config);
            return 0;
        }
        if (!terminal::tty())
        {
            io::printn(HELP);
            return 1;
        }
        app::Tree tree;
        tree.scan("");
        for (usz i = 0; i < tree.count; i++)
        {
            if (!tree.nodes[i].dir)
            {
                return app::run(tree.nodes[i].path, 0, noWrap, true) ? 0 : 1;
            }
        }
        io::printn("No Markdown files (*.md) found in this folder.");
        return 1;
    }

    sz colon = file.rindex_of_char(':') ?? -1;
    if (colon > 0)
    {
        if (try n = file[colon + 1..].to_int())
        {
            line = n;
            file = file[:colon];
        }
    }

    if (stdout || !terminal::tty())
    {
        char[]? content = io::file::load(mem, file);
        if (catch content)
        {
            io::eprintfn("mdv: cannot open '%s'", file);
            return 1;
        }
        defer free(content);
        print((String)content, config);
        return 0;
    }

    if (app::run(file, line, noWrap, false)) return 0;
    io::eprintfn("mdv: cannot open '%s'", file);
    return 1;
}
