module logic;

import std::io;
import std::core::mem;
import std::collections::list;
import strutils;
import buffer;
import render;
import ansi;

enum QueryKind {
    NONE,
    SECTION,
    CODE,
    TABLE,
    MATH,
    CALLOUT,
    TOC,
    COUNT,
    GREP
}

struct QueryConfig {
    QueryKind kind;
    char[128] query_str;
    char[64] lang;
    int index;      // 1-based (0 = all matches)
    bool raw;       // Raw text output (no ANSI, no fences/markup)
    bool csv;       // CSV formatted table output
}

fn String get_heading_plain_title(HeadingBlock* h, Arena* arena)
{
    buffer::ByteBuffer tb;
    tb.init(128);
    defer tb.free();

    for (usz s = 0; s < h.spans.len; s++)
    {
        tb.append_slice(h.spans[s].text);
    }
    return tb.to_arena_string(arena);
}

fn String get_spans_plain_text(Span[] spans, Arena* arena)
{
    buffer::ByteBuffer tb;
    tb.init(128);
    defer tb.free();

    for (usz s = 0; s < spans.len; s++)
    {
        tb.append_slice(spans[s].text);
        if (spans[s].children.len > 0)
        {
            String child_txt = get_spans_plain_text(spans[s].children, arena);
            tb.append_slice(child_txt);
        }
    }
    return tb.to_arena_string(arena);
}

fn Document query_section(Document* doc, char* target_query, Arena* arena)
{
    Document res;
    res.blocks = {};
    if (doc == null || doc.blocks.len == 0 || target_query == null || target_query[0] == 0) return res;

    int query_len = strutils::str_len(target_query);
    String q_str = (String)target_query[:(usz)query_len];

    usz start_idx = 0;
    bool found = false;
    int target_level = 1;

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.HEADING)
        {
            String title = get_heading_plain_title(&b.heading, arena);
            if (strutils::slug_match(q_str, title))
            {
                start_idx = i;
                target_level = b.heading.level;
                found = true;
                break;
            }
        }
    }

    if (!found) return res;

    usz end_idx = doc.blocks.len;
    for (usz j = start_idx + 1; j < doc.blocks.len; j++)
    {
        Block* b = &doc.blocks[j];
        if (b.kind == BlockKind.HEADING && b.heading.level <= target_level)
        {
            end_idx = j;
            break;
        }
    }

    usz count = end_idx - start_idx;
    Block* block_buf = (Block*)arena.alloc(count * Block::size);
    for (usz k = 0; k < count; k++)
    {
        block_buf[k] = doc.blocks[start_idx + k];
    }

    res.blocks = block_buf[0 : count];
    return res;
}

fn Document query_code_blocks(Document* doc, char* lang_filter, int target_idx, Arena* arena)
{
    Document res;
    res.blocks = {};
    if (doc == null || doc.blocks.len == 0) return res;

    List{Block} matches;
    matches.init(mem, 32);
    defer matches.free();

    int match_count = 0;
    int lang_len = strutils::str_len(lang_filter);
    String target_lang = lang_filter != null && lang_len > 0 ? (String)lang_filter[:(usz)lang_len] : "";

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.CODE_BLOCK)
        {
            bool lang_match = true;
            if (target_lang.len > 0)
            {
                lang_match = strutils::string_contains_case_insensitive(b.code.language, target_lang);
            }

            if (lang_match)
            {
                match_count++;
                if (target_idx <= 0 || match_count == target_idx)
                {
                    matches.push(*b);
                }
            }
        }
    }

    if (matches.size == 0) return res;

    Block* block_buf = (Block*)arena.alloc((usz)matches.size * Block::size);
    for (usz k = 0; k < (usz)matches.size; k++)
    {
        block_buf[k] = matches.entries[k];
    }

    res.blocks = block_buf[0 : (usz)matches.size];
    return res;
}

fn Document query_tables(Document* doc, int target_idx, Arena* arena)
{
    Document res;
    res.blocks = {};
    if (doc == null || doc.blocks.len == 0) return res;

    List{Block} matches;
    matches.init(mem, 16);
    defer matches.free();

    int match_count = 0;
    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.TABLE)
        {
            match_count++;
            if (target_idx <= 0 || match_count == target_idx)
            {
                matches.push(*b);
            }
        }
    }

    if (matches.size == 0) return res;

    Block* block_buf = (Block*)arena.alloc((usz)matches.size * Block::size);
    for (usz k = 0; k < (usz)matches.size; k++)
    {
        block_buf[k] = matches.entries[k];
    }

    res.blocks = block_buf[0 : (usz)matches.size];
    return res;
}

fn Document query_math_blocks(Document* doc, int target_idx, Arena* arena)
{
    Document res;
    res.blocks = {};
    if (doc == null || doc.blocks.len == 0) return res;

    List{Block} matches;
    matches.init(mem, 16);
    defer matches.free();

    int match_count = 0;
    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.MATH_BLOCK)
        {
            match_count++;
            if (target_idx <= 0 || match_count == target_idx)
            {
                matches.push(*b);
            }
        }
    }

    if (matches.size == 0) return res;

    Block* block_buf = (Block*)arena.alloc((usz)matches.size * Block::size);
    for (usz k = 0; k < (usz)matches.size; k++)
    {
        block_buf[k] = matches.entries[k];
    }

    res.blocks = block_buf[0 : (usz)matches.size];
    return res;
}

fn Document query_grep(Document* doc, char* pattern, Arena* arena)
{
    Document res;
    res.blocks = {};
    if (doc == null || doc.blocks.len == 0 || pattern == null || pattern[0] == 0) return res;

    int pat_len = strutils::str_len(pattern);
    String pat_str = (String)pattern[:(usz)pat_len];

    List{Block} matches;
    matches.init(mem, 32);
    defer matches.free();

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        bool matched = false;

        switch (b.kind)
        {
            case BlockKind.HEADING:
                String h_title = get_heading_plain_title(&b.heading, arena);
                matched = strutils::string_contains_case_insensitive(h_title, pat_str);

            case BlockKind.PARAGRAPH:
                String p_text = get_spans_plain_text(b.paragraph.spans, arena);
                matched = strutils::string_contains_case_insensitive(p_text, pat_str);

            case BlockKind.CODE_BLOCK:
                for (usz l = 0; l < b.code.lines.len; l++)
                {
                    if (strutils::string_contains_case_insensitive(b.code.lines[l], pat_str))
                    {
                        matched = true;
                        break;
                    }
                }

            case BlockKind.CALLOUT:
                if (strutils::string_contains_case_insensitive(b.callout.title, pat_str))
                {
                    matched = true;
                }
                else
                {
                    String c_text = get_spans_plain_text(b.callout.spans, arena);
                    matched = strutils::string_contains_case_insensitive(c_text, pat_str);
                }

            case BlockKind.MATH_BLOCK:
                matched = strutils::string_contains_case_insensitive(b.math_block.latex, pat_str);

            case BlockKind.LIST_ITEM:
                String l_text = get_spans_plain_text(b.list_item.spans, arena);
                matched = strutils::string_contains_case_insensitive(l_text, pat_str);

            default:
                matched = false;
        }

        if (matched)
        {
            matches.push(*b);
        }
    }

    if (matches.size == 0) return res;

    Block* block_buf = (Block*)arena.alloc((usz)matches.size * Block::size);
    for (usz k = 0; k < (usz)matches.size; k++)
    {
        block_buf[k] = matches.entries[k];
    }

    res.blocks = block_buf[0 : (usz)matches.size];
    return res;
}

fn void render_toc_stdout(Document* doc, bool plain)
{
    if (doc == null) return;
    Arena local_arena;
    local_arena.init(16384);
    defer local_arena.free();

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.HEADING)
        {
            String title = get_heading_plain_title(&b.heading, &local_arena);
            char[256] slug;
            strutils::slugify(title, &slug[0], 256);

            if (!plain)
            {
                for (int lv = 1; lv < b.heading.level; lv++) io::print("  ");
                switch (b.heading.level)
                {
                    case 1: io::print((ZString)ansi::fg_h1);
                    case 2: io::print((ZString)ansi::fg_h2);
                    case 3: io::print((ZString)ansi::fg_h3);
                    case 4: io::print((ZString)ansi::fg_h4);
                    default: io::print((ZString)ansi::fg_h5);
                }
                io::printf("%s", title);
                io::print((ZString)ansi::RESET);
                io::print((ZString)ansi::fg_muted);
                io::printfn("  (#%s : line %d)", (ZString)&slug[0], b.src_line_start + 1);
                io::print((ZString)ansi::RESET);
            }
            else
            {
                for (int lv = 1; lv < b.heading.level; lv++) io::print("  ");
                io::printfn("- %s (#%s : line %d)", title, (ZString)&slug[0], b.src_line_start + 1);
            }
        }
    }
}

fn void render_stats_stdout(Document* doc, bool plain)
{
    if (doc == null) return;
    int headings = 0;
    int code_blocks = 0;
    int tables = 0;
    int math_blocks = 0;
    int callouts = 0;
    int paragraphs = 0;
    int list_items = 0;

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        switch (doc.blocks[i].kind)
        {
            case BlockKind.HEADING: headings++;
            case BlockKind.CODE_BLOCK: code_blocks++;
            case BlockKind.TABLE: tables++;
            case BlockKind.MATH_BLOCK: math_blocks++;
            case BlockKind.CALLOUT: callouts++;
            case BlockKind.PARAGRAPH: paragraphs++;
            case BlockKind.LIST_ITEM: list_items++;
            default: break;
        }
    }

    if (!plain)
    {
        io::print((ZString)ansi::fg_cyan);
        io::print((ZString)ansi::BOLD);
        io::printn("Document Structure Statistics:");
        io::print((ZString)ansi::RESET);
        io::printfn("  • Headings:    %d", headings);
        io::printfn("  • Code Blocks: %d", code_blocks);
        io::printfn("  • Tables:      %d", tables);
        io::printfn("  • Math Blocks: %d", math_blocks);
        io::printfn("  • Callouts:    %d", callouts);
        io::printfn("  • Paragraphs:  %d", paragraphs);
        io::printfn("  • List Items:  %d", list_items);
    }
    else
    {
        io::printn("Document Structure Statistics:");
        io::printfn("Headings:    %d", headings);
        io::printfn("Code Blocks: %d", code_blocks);
        io::printfn("Tables:      %d", tables);
        io::printfn("Math Blocks: %d", math_blocks);
        io::printfn("Callouts:    %d", callouts);
        io::printfn("Paragraphs:  %d", paragraphs);
        io::printfn("List Items:  %d", list_items);
    }
}

fn void render_raw_code_stdout(Document* doc, char* lang_filter, int target_idx)
{
    if (doc == null) return;
    int match_count = 0;
    int lang_len = strutils::str_len(lang_filter);
    String target_lang = lang_filter != null && lang_len > 0 ? (String)lang_filter[:(usz)lang_len] : "";

    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.CODE_BLOCK)
        {
            bool lang_match = true;
            if (target_lang.len > 0)
            {
                lang_match = strutils::string_contains_case_insensitive(b.code.language, target_lang);
            }

            if (lang_match)
            {
                match_count++;
                if (target_idx <= 0 || match_count == target_idx)
                {
                    for (usz l = 0; l < b.code.lines.len; l++)
                    {
                        io::printfn("%s", b.code.lines[l]);
                    }
                }
            }
        }
    }
}

fn void render_raw_table_csv_stdout(Document* doc, int target_idx)
{
    if (doc == null) return;
    Arena local_arena;
    local_arena.init(16384);
    defer local_arena.free();

    int match_count = 0;
    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.TABLE)
        {
            match_count++;
            if (target_idx <= 0 || match_count == target_idx)
            {
                // Emit headers
                for (usz c = 0; c < b.table.headers.len; c++)
                {
                    String h_txt = get_spans_plain_text(b.table.headers[c], &local_arena);
                    if (strutils::string_contains(h_txt, ",") || strutils::string_contains(h_txt, "\""))
                    {
                        io::printf("\"%s\"", h_txt);
                    }
                    else
                    {
                        io::printf("%s", h_txt);
                    }
                    if (c < b.table.headers.len - 1) io::print(",");
                }
                io::printn("");

                // Emit rows
                for (usz r = 0; r < b.table.rows.len; r++)
                {
                    Span[][] row = b.table.rows[r];
                    for (usz c = 0; c < row.len; c++)
                    {
                        String c_txt = get_spans_plain_text(row[c], &local_arena);
                        if (strutils::string_contains(c_txt, ",") || strutils::string_contains(c_txt, "\""))
                        {
                            io::printf("\"%s\"", c_txt);
                        }
                        else
                        {
                            io::printf("%s", c_txt);
                        }
                        if (c < row.len - 1) io::print(",");
                    }
                    io::printn("");
                }
            }
        }
    }
}

fn void render_raw_math_stdout(Document* doc, int target_idx)
{
    if (doc == null) return;
    int match_count = 0;
    for (usz i = 0; i < doc.blocks.len; i++)
    {
        Block* b = &doc.blocks[i];
        if (b.kind == BlockKind.MATH_BLOCK)
        {
            match_count++;
            if (target_idx <= 0 || match_count == target_idx)
            {
                io::printfn("%s", b.math_block.latex);
            }
        }
    }
}

// ── Vim-Style AST Mutation Engine (Delete, Change, Append, Insert) ─────────

enum MutationVerb {
    NONE,
    YANK,
    DELETE,
    CHANGE,
    APPEND,
    INSERT
}

enum TargetKind {
    SECTION,
    CODE,
    TABLE,
    MATH,
    CALLOUT
}

struct TargetSpec {
    TargetKind kind;
    char[128] pattern;
    char[64] lang;
    int index;
}

fn TargetSpec parse_target_spec(char* target)
{
    TargetSpec spec;
    spec.kind = TargetKind.SECTION;
    spec.pattern[0] = 0;
    spec.lang[0] = 0;
    spec.index = 0;
    if (target == null || target[0] == 0) return spec;

    if (target[0] == '#')
    {
        spec.kind = TargetKind.SECTION;
        strutils::copy_str(&spec.pattern[0], target + 1, 128);
        return spec;
    }
    if (strutils::str_starts_with(target, "s:") || strutils::str_starts_with(target, "sec:") || strutils::str_starts_with(target, "section:"))
    {
        spec.kind = TargetKind.SECTION;
        int p = 0;
        while (target[p] != 0 && target[p] != ':') p++;
        if (target[p] == ':') p++;
        strutils::copy_str(&spec.pattern[0], target + p, 128);
        return spec;
    }
    if (strutils::str_starts_with(target, "c:") || strutils::str_starts_with(target, "code:"))
    {
        spec.kind = TargetKind.CODE;
        int p = 0;
        while (target[p] != 0 && target[p] != ':') p++;
        if (target[p] == ':') p++;
        strutils::parse_lang_and_index(target + p, &spec.lang[0], 64, &spec.index);
        return spec;
    }
    if (strutils::str_starts_with(target, "t:") || strutils::str_starts_with(target, "table:") || strutils::str_starts_with(target, "tables:"))
    {
        spec.kind = TargetKind.TABLE;
        int p = 0;
        while (target[p] != 0 && target[p] != ':') p++;
        if (target[p] == ':') p++;
        spec.index = strutils::parse_int(target + p);
        return spec;
    }
    if (strutils::str_starts_with(target, "m:") || strutils::str_starts_with(target, "math:"))
    {
        spec.kind = TargetKind.MATH;
        int p = 0;
        while (target[p] != 0 && target[p] != ':') p++;
        if (target[p] == ':') p++;
        spec.index = strutils::parse_int(target + p);
        return spec;
    }
    if (strutils::str_starts_with(target, "k:") || strutils::str_starts_with(target, "callout:"))
    {
        spec.kind = TargetKind.CALLOUT;
        int p = 0;
        while (target[p] != 0 && target[p] != ':') p++;
        if (target[p] == ':') p++;
        strutils::copy_str(&spec.pattern[0], target + p, 128);
        return spec;
    }

    // Default fallback: section match
    spec.kind = TargetKind.SECTION;
    strutils::copy_str(&spec.pattern[0], target, 128);
    return spec;
}

fn char* execute_mutation(
    char* orig_src,
    Document* doc,
    MutationVerb verb,
    char* target_str,
    char* new_content,
    Arena* arena,
    bool* out_success
)
{
    if (out_success != null) *out_success = false;
    if (orig_src == null || doc == null || doc.blocks.len == 0 || verb == MutationVerb.NONE || verb == MutationVerb.YANK)
    {
        return orig_src;
    }

    TargetSpec spec = parse_target_spec(target_str);

    // 1. Split original source into line slices
    List{String} src_lines;
    src_lines.init(mem, 256);
    defer src_lines.free();

    usz p = 0;
    usz orig_len = (usz)strutils::str_len(orig_src);
    while (p < orig_len)
    {
        usz l_start = p;
        while (p < orig_len && orig_src[p] != '\n') p++;
        src_lines.push((String)orig_src[l_start : p - l_start]);
        if (p < orig_len && orig_src[p] == '\n') p++;
    }

    int total_lines = (int)src_lines.size;
    int target_start_line = -1;
    int target_end_line = -1;
    int insert_line = -1;

    // 2. Resolve AST node and line boundaries
    switch (spec.kind)
    {
        case TargetKind.SECTION:
            int h_match_idx = -1;
            int h_level = 1;
            int q_len = strutils::str_len(&spec.pattern[0]);
            String q_str = (String)(&spec.pattern[0])[:(usz)q_len];

            for (usz i = 0; i < doc.blocks.len; i++)
            {
                Block* b = &doc.blocks[i];
                if (b.kind == BlockKind.HEADING)
                {
                    String title = get_heading_plain_title(&b.heading, arena);
                    if (strutils::slug_match(q_str, title))
                    {
                        h_match_idx = (int)i;
                        h_level = b.heading.level;
                        break;
                    }
                }
            }

            if (h_match_idx < 0) return orig_src;

            target_start_line = doc.blocks[(usz)h_match_idx].src_line_start;
            int last_child_line = doc.blocks[(usz)h_match_idx].src_line_end;

            // Find section end (next heading of equal or higher level)
            for (usz j = (usz)h_match_idx + 1; j < doc.blocks.len; j++)
            {
                Block* b = &doc.blocks[j];
                if (b.kind == BlockKind.HEADING && b.heading.level <= h_level)
                {
                    target_end_line = b.src_line_start - 1;
                    break;
                }
                last_child_line = b.src_line_end;
            }

            if (target_end_line < 0)
            {
                target_end_line = last_child_line < total_lines ? last_child_line : total_lines - 1;
            }

            if (verb == MutationVerb.INSERT)
            {
                insert_line = doc.blocks[(usz)h_match_idx].src_line_end + 1;
            }
            else if (verb == MutationVerb.APPEND)
            {
                insert_line = target_end_line + 1;
            }

        case TargetKind.CODE:
            int c_match_count = 0;
            int lang_len = strutils::str_len(&spec.lang[0]);
            String target_lang = lang_len > 0 ? (String)(&spec.lang[0])[:(usz)lang_len] : "";

            for (usz i = 0; i < doc.blocks.len; i++)
            {
                Block* b = &doc.blocks[i];
                if (b.kind == BlockKind.CODE_BLOCK)
                {
                    bool l_match = true;
                    if (target_lang.len > 0)
                    {
                        l_match = strutils::string_contains_case_insensitive(b.code.language, target_lang);
                    }
                    if (l_match)
                    {
                        c_match_count++;
                        if (spec.index <= 0 || c_match_count == spec.index)
                        {
                            target_start_line = b.src_line_start;
                            target_end_line = b.src_line_end;
                            insert_line = (verb == MutationVerb.INSERT) ? b.src_line_start : b.src_line_end + 1;
                            break;
                        }
                    }
                }
            }

        case TargetKind.TABLE:
            int t_match_count = 0;
            for (usz i = 0; i < doc.blocks.len; i++)
            {
                Block* b = &doc.blocks[i];
                if (b.kind == BlockKind.TABLE)
                {
                    t_match_count++;
                    if (spec.index <= 0 || t_match_count == spec.index)
                    {
                        target_start_line = b.src_line_start;
                        target_end_line = b.src_line_end;
                        insert_line = (verb == MutationVerb.INSERT) ? b.src_line_start : b.src_line_end + 1;
                        break;
                    }
                }
            }

        case TargetKind.MATH:
            int m_match_count = 0;
            for (usz i = 0; i < doc.blocks.len; i++)
            {
                Block* b = &doc.blocks[i];
                if (b.kind == BlockKind.MATH_BLOCK)
                {
                    m_match_count++;
                    if (spec.index <= 0 || m_match_count == spec.index)
                    {
                        target_start_line = b.src_line_start;
                        target_end_line = b.src_line_end;
                        insert_line = (verb == MutationVerb.INSERT) ? b.src_line_start : b.src_line_end + 1;
                        break;
                    }
                }
            }

        case TargetKind.CALLOUT:
            for (usz i = 0; i < doc.blocks.len; i++)
            {
                Block* b = &doc.blocks[i];
                if (b.kind == BlockKind.CALLOUT)
                {
                    target_start_line = b.src_line_start;
                    target_end_line = b.src_line_end;
                    insert_line = (verb == MutationVerb.INSERT) ? b.src_line_start : b.src_line_end + 1;
                    break;
                }
            }
    }

    if (target_start_line < 0 && insert_line < 0)
    {
        return orig_src;
    }

    // 3. Assemble mutated document
    buffer::ByteBuffer mb;
    mb.init(orig_len + (new_content != null ? (usz)strutils::str_len(new_content) : 0) + 512);
    defer mb.free();

    if (verb == MutationVerb.DELETE)
    {
        for (int l = 0; l < total_lines; l++)
        {
            if (l < target_start_line || l > target_end_line)
            {
                mb.append_slice(src_lines.entries[(usz)l]);
                mb.append_char('\n');
            }
        }
    }
    else if (verb == MutationVerb.CHANGE)
    {
        for (int l = 0; l < target_start_line && l < total_lines; l++)
        {
            mb.append_slice(src_lines.entries[(usz)l]);
            mb.append_char('\n');
        }

        if (new_content != null && new_content[0] != 0)
        {
            mb.append_zstr(new_content);
            int nlen = strutils::str_len(new_content);
            if (new_content[nlen - 1] != '\n') mb.append_char('\n');
        }

        for (int l = target_end_line + 1; l < total_lines; l++)
        {
            mb.append_slice(src_lines.entries[(usz)l]);
            mb.append_char('\n');
        }
    }
    else if (verb == MutationVerb.INSERT || verb == MutationVerb.APPEND)
    {
        int ins = insert_line >= 0 ? insert_line : target_start_line;
        if (ins > total_lines) ins = total_lines;

        for (int l = 0; l < ins && l < total_lines; l++)
        {
            mb.append_slice(src_lines.entries[(usz)l]);
            mb.append_char('\n');
        }

        if (new_content != null && new_content[0] != 0)
        {
            mb.append_zstr(new_content);
            int nlen = strutils::str_len(new_content);
            if (new_content[nlen - 1] != '\n') mb.append_char('\n');
        }

        for (int l = ins; l < total_lines; l++)
        {
            mb.append_slice(src_lines.entries[(usz)l]);
            mb.append_char('\n');
        }
    }

    if (out_success != null) *out_success = true;
    return (char*)mb.to_arena_string(arena).ptr;
}
