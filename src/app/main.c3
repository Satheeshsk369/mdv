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
import buffer;

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
    io::printn("    mdv <file.md>[#anchor] [line]    Live watch & render in viewer (Default)");
    io::printn("    mdv -s <file.md>                 Render text directly to stdout and exit");
    io::printn("    cat file.md | mdv [options]      Pipe from stdin");
    io::printn("");
    io::printn("Vim-Style CRUD Operations:");
    io::printn("    -y, --yank <target>              Yank / Query target (e.g. -y #install, -y c:python:1)");
    io::printn("    -d, --delete <target>            Delete target block/section cleanly from AST");
    io::printn("    -c, --change <target> [text]     Change / replace target body content with new text");
    io::printn("    -a, --append <target> [text]     Append content to end of section/block");
    io::printn("    -i, --insert <target> [text]     Insert content right after heading (top of section)");
    io::printn("    --rename <target> <title>        Rename section heading title");
    io::printn("    -w, --write, --in-place          Save mutations back to disk atomically (default: stdout)");
    io::printn("");
    io::printn("Target Nouns:");
    io::printn("    #slug, s:<title>                 Heading section + children (e.g. #installation, s:\"Quick Start\")");
    io::printn("    c:<lang>[:idx], code:<lang>      Code block (e.g. c:python:1, c:bash)");
    io::printn("    t:<idx>, table:<idx>             Table by 1-based index (e.g. t:1)");
    io::printn("    m:<idx>, math:<idx>              2D LaTeX math block by index (e.g. m:1)");
    io::printn("    k:<kind>, callout:<kind>         Callout by kind (e.g. k:warning, k:note)");
    io::printn("");
    io::printn("Query & Extraction Options:");
    io::printn("    -H, --section <title|slug>       Extract section by heading title or slug");
    io::printn("    -c, --code [lang[:idx]]          Extract code blocks");
    io::printn("    -T, --table, --tables [idx]      Extract Markdown tables");
    io::printn("    -M, --math [idx]                 Extract 2D LaTeX formulas");
    io::printn("    -g, --grep <pattern>             Filter blocks containing pattern");
    io::printn("    --toc, --outline                 Print structured document heading outline");
    io::printn("    --count, --stats                 Print document structure & block statistics");
    io::printn("    --word-count, --wc               Print section-by-section word count breakdown");
    io::printn("    --lint                           Run document structure & formatting quality checks");
    io::printn("    -r, --raw, --raw-code            Emit raw code/math content without markdown fences");
    io::printn("    --csv                            Emit table directly as CSV");
    io::printn("");
    io::printn("Viewer & Rendering Options:");
    io::printn("    -P, --play, --present            Interactive step-by-step presentation / story mode");
    io::printn("    -s, --stdout                     Print rendered text directly to stdout and exit");
    io::printn("    -p, --plain                      Print plain text without ANSI formatting");
    io::printn("    -nw, --no-wrap                   Disable line wrapping");
    io::printn("    -W, --width <cols>               Set rendering wrap width (default: terminal width)");
    io::printn("    -h, --help                       Show help");
    io::printn("    -v, --version                    Show version");
    io::printn("");
}

fn char* read_all_stdin()
{
    buffer::ByteBuffer bb;
    bb.init(65536);
    char[4096] chunk;
    while (true)
    {
        int n = read(0, (void*)&chunk[0], 4096);
        if (n <= 0) break;
        bb.ensure_space((usz)n);
        for (int i = 0; i < n; i++) bb.buf[bb.len++] = chunk[i];
        bb.buf[bb.len] = 0;
    }

    if (bb.len == 0)
    {
        bb.free();
        return null;
    }

    char[] res = mem::alloc_array(char, (sz)(bb.len + 1));
    for (usz i = 0; i < bb.len; i++) res[i] = bb.buf[i];
    res[bb.len] = 0;
    bb.free();
    return (char*)res.ptr;
}

fn bool execute_query_on_document(Document* doc, logic::QueryConfig* q, RenderConfig config, logic::Arena* arena)
{
    if (q.kind == logic::QueryKind.TOC)
    {
        logic::render_toc_stdout(doc, config.plain);
        return true;
    }
    if (q.kind == logic::QueryKind.COUNT)
    {
        logic::render_stats_stdout(doc, config.plain);
        return true;
    }
    if (q.kind == logic::QueryKind.WORD_COUNT)
    {
        logic::render_word_count_stdout(doc, config.plain);
        return true;
    }
    if (q.kind == logic::QueryKind.LINT)
    {
        logic::render_lint_stdout(doc, config.plain);
        return true;
    }
    if (q.kind == logic::QueryKind.CODE && q.raw)
    {
        logic::render_raw_code_stdout(doc, &q.lang[0], q.index);
        return true;
    }
    if (q.kind == logic::QueryKind.TABLE && q.csv)
    {
        logic::render_raw_table_csv_stdout(doc, q.index);
        return true;
    }
    if (q.kind == logic::QueryKind.MATH && q.raw)
    {
        logic::render_raw_math_stdout(doc, q.index);
        return true;
    }

    Document sliced;
    sliced.blocks = {};

    switch (q.kind)
    {
        case logic::QueryKind.SECTION:
            sliced = logic::query_section(doc, &q.query_str[0], arena);

        case logic::QueryKind.CODE:
            sliced = logic::query_code_blocks(doc, &q.lang[0], q.index, arena);

        case logic::QueryKind.TABLE:
            sliced = logic::query_tables(doc, q.index, arena);

        case logic::QueryKind.MATH:
            sliced = logic::query_math_blocks(doc, q.index, arena);

        case logic::QueryKind.GREP:
            sliced = logic::query_grep(doc, &q.query_str[0], arena);

        default:
            return false;
    }

    if (sliced.blocks.len == 0)
    {
        if (!config.plain) io::print((ZString)ansi::fg_pink);
        io::printn("No matching blocks found for query");
        if (!config.plain) io::print((ZString)ansi::RESET);
        return false;
    }

    render::render_to_stdout(&sliced, config);
    return true;
}

fn int main(String[] args)
{
    bool force_stdout = false;
    bool no_wrap = false;
    int explicit_width = 0;
    char* target_file = null;
    int target_line = 0;

    logic::QueryConfig query;
    query.kind = logic::QueryKind.NONE;
    query.query_str[0] = 0;
    query.lang[0] = 0;
    query.index = 0;
    query.raw = false;
    query.csv = false;

    logic::MutationVerb mutation_verb = logic::MutationVerb.NONE;
    char[128] mutation_target;
    mutation_target[0] = 0;
    char* mutation_content = null;
    bool write_in_place = false;
    bool play_mode = false;

    for (int i = 1; i < (int)args.len; i++)
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
        if (arg == "-w" || arg == "--write" || arg == "--in-place")
        {
            write_in_place = true;
            force_stdout = true;
            continue;
        }
        if (arg == "-s" || arg == "--stdout")
        {
            force_stdout = true;
            continue;
        }
        if (arg == "-P" || arg == "--play" || arg == "--present" || arg == "--slides")
        {
            play_mode = true;
            continue;
        }
        if (arg == "-p" || arg == "--plain")
        {
            ansi::set_plain(true);
            force_stdout = true;
            continue;
        }
        if (arg == "-r" || arg == "--raw" || arg == "--raw-code")
        {
            query.raw = true;
            force_stdout = true;
            continue;
        }
        if (arg == "--csv")
        {
            query.csv = true;
            force_stdout = true;
            continue;
        }
        if (arg == "--toc" || arg == "--outline")
        {
            query.kind = logic::QueryKind.TOC;
            force_stdout = true;
            continue;
        }
        if (arg == "--count" || arg == "--stats")
        {
            query.kind = logic::QueryKind.COUNT;
            force_stdout = true;
            continue;
        }
        if (arg == "--word-count" || arg == "--wc")
        {
            query.kind = logic::QueryKind.WORD_COUNT;
            force_stdout = true;
            continue;
        }
        if (arg == "--lint")
        {
            query.kind = logic::QueryKind.LINT;
            force_stdout = true;
            continue;
        }
        if (arg == "--rename")
        {
            if (i + 1 < (int)args.len)
            {
                mutation_verb = logic::MutationVerb.RENAME;
                strutils::copy_str(&mutation_target[0], (char*)args[++i].ptr, 128);
                if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
                {
                    mutation_content = (char*)args[++i].ptr;
                }
                force_stdout = true;
            }
            continue;
        }
        if (arg == "-W" || arg == "--width")
        {
            if (i + 1 < (int)args.len)
            {
                explicit_width = strutils::parse_int((char*)args[++i].ptr);
            }
            continue;
        }

        // ── Vim-Style Verbs: -y, -d, -c, -a, -i ──────────────────────────────
        if (arg == "-y" || arg == "--yank" || arg == "--get")
        {
            if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
            {
                char* target_spec = (char*)args[++i].ptr;
                logic::TargetSpec spec = logic::parse_target_spec(target_spec);
                switch (spec.kind)
                {
                    case logic::TargetKind.SECTION:
                        query.kind = logic::QueryKind.SECTION;
                        strutils::copy_str(&query.query_str[0], &spec.pattern[0], 128);
                    case logic::TargetKind.CODE:
                        query.kind = logic::QueryKind.CODE;
                        strutils::copy_str(&query.lang[0], &spec.lang[0], 64);
                        query.index = spec.index;
                    case logic::TargetKind.TABLE:
                        query.kind = logic::QueryKind.TABLE;
                        query.index = spec.index;
                    case logic::TargetKind.MATH:
                        query.kind = logic::QueryKind.MATH;
                        query.index = spec.index;
                    case logic::TargetKind.CALLOUT:
                        query.kind = logic::QueryKind.CALLOUT;
                        strutils::copy_str(&query.query_str[0], &spec.pattern[0], 128);
                }
                force_stdout = true;
            }
            continue;
        }

        if (arg == "-d" || arg == "--delete")
        {
            if (i + 1 < (int)args.len)
            {
                mutation_verb = logic::MutationVerb.DELETE;
                strutils::copy_str(&mutation_target[0], (char*)args[++i].ptr, 128);
                force_stdout = true;
            }
            continue;
        }

        if (arg == "-c" || arg == "--change" || arg == "--replace")
        {
            if (i + 1 < (int)args.len)
            {
                mutation_verb = logic::MutationVerb.CHANGE;
                strutils::copy_str(&mutation_target[0], (char*)args[++i].ptr, 128);
                if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
                {
                    mutation_content = (char*)args[++i].ptr;
                }
                force_stdout = true;
            }
            continue;
        }

        if (arg == "-a" || arg == "--append" || arg == "--append-to")
        {
            if (i + 1 < (int)args.len)
            {
                mutation_verb = logic::MutationVerb.APPEND;
                strutils::copy_str(&mutation_target[0], (char*)args[++i].ptr, 128);
                if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
                {
                    mutation_content = (char*)args[++i].ptr;
                }
                force_stdout = true;
            }
            continue;
        }

        if (arg == "-i" || arg == "--insert" || arg == "--prepend")
        {
            if (i + 1 < (int)args.len)
            {
                mutation_verb = logic::MutationVerb.INSERT;
                strutils::copy_str(&mutation_target[0], (char*)args[++i].ptr, 128);
                if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
                {
                    mutation_content = (char*)args[++i].ptr;
                }
                force_stdout = true;
            }
            continue;
        }

        // ── Query Flags ──────────────────────────────────────────────────────
        if (arg == "-H" || arg == "--section" || arg == "--heading")
        {
            if (i + 1 < (int)args.len)
            {
                query.kind = logic::QueryKind.SECTION;
                strutils::copy_str(&query.query_str[0], (char*)args[++i].ptr, 128);
                force_stdout = true;
            }
            continue;
        }
        if (arg == "--code")
        {
            query.kind = logic::QueryKind.CODE;
            force_stdout = true;
            if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
            {
                char* next_val = (char*)args[++i].ptr;
                strutils::parse_lang_and_index(next_val, &query.lang[0], 64, &query.index);
            }
            continue;
        }
        if (arg.starts_with("--code="))
        {
            query.kind = logic::QueryKind.CODE;
            force_stdout = true;
            char* val = (char*)arg.ptr + 7;
            strutils::parse_lang_and_index(val, &query.lang[0], 64, &query.index);
            continue;
        }
        if (arg == "-T" || arg == "--table" || arg == "--tables")
        {
            query.kind = logic::QueryKind.TABLE;
            force_stdout = true;
            if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
            {
                char* next_val = (char*)args[++i].ptr;
                if (strutils::is_numeric(next_val)) query.index = strutils::parse_int(next_val);
            }
            continue;
        }
        if (arg == "-M" || arg == "--math")
        {
            query.kind = logic::QueryKind.MATH;
            force_stdout = true;
            if (i + 1 < (int)args.len && !args[i + 1].starts_with("-"))
            {
                char* next_val = (char*)args[++i].ptr;
                if (strutils::is_numeric(next_val)) query.index = strutils::parse_int(next_val);
            }
            continue;
        }
        if (arg == "-g" || arg == "--grep" || arg == "--filter")
        {
            if (i + 1 < (int)args.len)
            {
                query.kind = logic::QueryKind.GREP;
                strutils::copy_str(&query.query_str[0], (char*)args[++i].ptr, 128);
                force_stdout = true;
            }
            continue;
        }

        if (strutils::is_numeric((char*)arg.ptr))
        {
            target_line = strutils::parse_int((char*)arg.ptr);
            continue;
        }
        if (!arg.starts_with("-"))
        {
            if (target_file == null)
            {
                target_file = (char*)arg.ptr;
            }
            else if (mutation_verb != logic::MutationVerb.NONE && mutation_content == null)
            {
                mutation_content = (char*)arg.ptr;
            }
        }
        else if (arg == "-")
        {
            target_file = "-";
        }
    }

    int width = explicit_width > 0 ? explicit_width : terminal::get_width();
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

    RenderConfig config;
    config.width = width;
    config.plain = ansi::plain_mode;
    config.no_wrap = no_wrap;

    // Check if filename has anchor: "file.md#anchor-name"
    char[256] clean_filename;
    char[128] file_anchor;
    if (target_file != null && !strutils::str_eq(target_file, "-"))
    {
        if (strutils::split_file_and_anchor(target_file, &clean_filename[0], &file_anchor[0], 256))
        {
            target_file = &clean_filename[0];
            if (query.kind == logic::QueryKind.NONE && mutation_verb == logic::MutationVerb.NONE && file_anchor[0] != 0)
            {
                query.kind = logic::QueryKind.SECTION;
                strutils::copy_str(&query.query_str[0], &file_anchor[0], 128);
                force_stdout = true;
            }
        }
    }

    // 1. Target file specified
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

        // Handle AST Mutations (-d, -c, -a, -i)
        if (mutation_verb != logic::MutationVerb.NONE)
        {
            char* content = strutils::load_file_string(target_file);
            if (content == null)
            {
                if (!ansi::plain_mode) io::print((ZString)ansi::fg_pink);
                io::printfn("Error: Could not open file '%s'", (ZString)target_file);
                if (!ansi::plain_mode) io::print((ZString)ansi::RESET);
                return 1;
            }
            defer mem::free(content);

            // If mutation content not provided as CLI argument, read from piped stdin
            char* piped_input = null;
            if (mutation_content == null && (mutation_verb == logic::MutationVerb.CHANGE || mutation_verb == logic::MutationVerb.APPEND || mutation_verb == logic::MutationVerb.INSERT))
            {
                if (isatty(0) == 0)
                {
                    piped_input = read_all_stdin();
                    mutation_content = piped_input;
                }
            }

            String content_str = (String)content[:strutils::str_len(content)];
            Document doc = parser::parse_document(content_str);
            defer doc.free();

            logic::Arena mut_arena;
            mut_arena.init(65536);
            defer mut_arena.free();

            bool success = false;
            char* mutated = logic::execute_mutation(content, &doc, mutation_verb, &mutation_target[0], mutation_content, &mut_arena, &success);

            if (piped_input != null) mem::free(piped_input);

            if (!success)
            {
                if (!ansi::plain_mode) io::print((ZString)ansi::fg_pink);
                io::printfn("Error: Target '%s' not found for mutation", (ZString)&mutation_target[0]);
                if (!ansi::plain_mode) io::print((ZString)ansi::RESET);
                return 1;
            }

            if (write_in_place)
            {
                bool saved = strutils::save_file_string(target_file, mutated);
                if (saved)
                {
                    if (terminal::is_tty())
                    {
                        io::print((ZString)ansi::fg_green);
                        io::print((ZString)ansi::BOLD);
                        io::printfn("✔ Saved changes to %s", (ZString)target_file);
                        io::print((ZString)ansi::RESET);
                    }
                    return 0;
                }
                else
                {
                    io::print((ZString)ansi::fg_pink);
                    io::printfn("Error: Failed to write to file '%s'", (ZString)target_file);
                    io::print((ZString)ansi::RESET);
                    return 1;
                }
            }

            // Output mutated Markdown to stdout
            io::printn((ZString)mutated);
            return 0;
        }

        // If a query (section/code/table/math/toc/count/grep) is active or force_stdout is set
        if (query.kind != logic::QueryKind.NONE || force_stdout || !terminal::is_tty())
        {
            char* content = strutils::load_file_string(target_file);
            if (content == null)
            {
                if (!ansi::plain_mode) io::print((ZString)ansi::fg_pink);
                io::printfn("Error: Could not open file '%s'", (ZString)target_file);
                if (!ansi::plain_mode) io::print((ZString)ansi::RESET);
                return 1;
            }
            defer mem::free(content);

            String content_str = (String)content[:strutils::str_len(content)];
            Document doc = parser::parse_document(content_str);
            defer doc.free();

            if (query.kind != logic::QueryKind.NONE)
            {
                logic::Arena query_arena;
                query_arena.init(65536);
                defer query_arena.free();
                bool ok = execute_query_on_document(&doc, &query, config, &query_arena);
                return ok ? 0 : 1;
            }

            render::render_to_stdout(&doc, config);
            return 0;
        }

        // Default: Live watch viewer with auto line sync, scroll retention & accelerated navigation
        app::run_watch(target_file, target_line, no_wrap, false, play_mode);
        return 0;
    }

    // 2. Stdin pipe (cat doc.md | mdv ...)
    if (strutils::str_eq(target_file, "-") || isatty(0) == 0)
    {
        if (mutation_verb != logic::MutationVerb.NONE)
        {
            char* stdin_content = read_all_stdin();
            if (stdin_content != null)
            {
                defer mem::free(stdin_content);
                String c_str = (String)stdin_content[:strutils::str_len(stdin_content)];
                Document doc = parser::parse_document(c_str);
                defer doc.free();

                logic::Arena mut_arena;
                mut_arena.init(65536);
                defer mut_arena.free();

                bool success = false;
                char* mutated = logic::execute_mutation(stdin_content, &doc, mutation_verb, &mutation_target[0], mutation_content, &mut_arena, &success);
                if (success)
                {
                    io::printn((ZString)mutated);
                    return 0;
                }
                return 1;
            }
            return 0;
        }

        if (query.kind != logic::QueryKind.NONE)
        {
            char* stdin_content = read_all_stdin();
            if (stdin_content != null)
            {
                defer mem::free(stdin_content);
                String c_str = (String)stdin_content[:strutils::str_len(stdin_content)];
                Document doc = parser::parse_document(c_str);
                defer doc.free();

                logic::Arena query_arena;
                query_arena.init(65536);
                defer query_arena.free();
                bool ok = execute_query_on_document(&doc, &query, config, &query_arena);
                return ok ? 0 : 1;
            }
            return 0;
        }

        render::render_and_stream_stdin(width, no_wrap);
        return 0;
    }

    // 3. Default when run interactively without arguments: Open directly into File Switcher
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
                app::run_watch(first_file, 0, no_wrap, true, play_mode);
                return 0;
            }
        }

        io::printn("No Markdown files (*.md) found in the current directory.");
        io::printn("");
    }

    print_help();
    return 1;
}
