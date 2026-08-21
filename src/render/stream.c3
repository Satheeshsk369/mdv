module render;

import std::io;
import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import math;
import parser;
import strutils;
import buffer;

extern fn int read(int fd, void* buf, ulong count);

enum StreamState {
    IDLE,
    CODE_FENCE,
    MATH_BLOCK,
    TABLE,
    CALLOUT,
    BLOCKQUOTE
}

struct StreamContext {
    int width;
    bool plain;
    bool no_wrap;
    StreamState state;

    // Code fence state
    char fence_char;
    usz fence_len;
    char[64] code_lang;

    // Math block state
    bool math_is_dollar;
    buffer::ByteBuffer math_buf;

    // Table state
    List{String} table_lines;
    logic::Arena table_arena;

    // Callout state
    CalloutKind callout_kind;
    char[64] callout_title;
    buffer::ByteBuffer callout_buf;

    // Blockquote state
    buffer::ByteBuffer quote_buf;

    // Paragraph state
    buffer::ByteBuffer para_buf;
}

fn void emit_stream_line_cb(void* ctx_ptr, String text, int src_line)
{
    io::printn(text);
}

fn void flush_paragraph(StreamContext* ctx, logic::Arena* scratch)
{
    if (ctx.para_buf.len == 0) return;
    String ptext = ctx.para_buf.to_string();

    Span[] spans = parser::parse_inline(scratch, ptext);
    ctx.para_buf.reset();
    if (spans.len == 0) return;

    int max_w = ctx.width > 20 ? ctx.width - 2 : 80;
    render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, max_w, "", "", ctx.plain, ctx.no_wrap);
}

fn void flush_math_block(StreamContext* ctx, logic::Arena* scratch)
{
    if (ctx.math_buf.len == 0) return;
    String latex = ctx.math_buf.to_string();

    MathBox mbox = math::render_latex_to_box(scratch, latex);
    ctx.math_buf.reset();

    if (mbox.height > 0)
    {
        io::printn("");
        for (int r = 0; r < mbox.height; r++)
        {
            int pad = 4;
            for (int k = 0; k < pad; k++) io::print(" ");
            io::print(mbox.rows[r]);
            io::printn("");
        }
        io::printn("");
    }
}

fn void flush_callout(StreamContext* ctx, logic::Arena* scratch)
{
    if (ctx.callout_buf.len == 0) return;
    String ctext = ctx.callout_buf.to_string();

    CalloutTheme theme = logic::get_callout_theme(ctx.callout_kind);
    String title = (String)(&ctx.callout_title[0])[:strutils::str_len(&ctx.callout_title[0])];

    if (!ctx.plain)
    {
        io::print(theme.color);
        io::print(ansi::BOLD);
        io::print("│ ");
        io::print(theme.icon);
        io::print(" ");
        io::print(theme.label);
        io::print(ansi::RESET);
        io::printn("");
    }
    else
    {
        io::printfn("| [!%s]", title);
    }

    Span[] spans = parser::parse_inline(scratch, ctext);
    ctx.callout_buf.reset();
    if (spans.len > 0)
    {
        int max_w = ctx.width > 20 ? ctx.width - 6 : 76;
        render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, max_w, "│ ", "│ ", ctx.plain, ctx.no_wrap);
    }
}

fn void flush_blockquote(StreamContext* ctx, logic::Arena* scratch)
{
    if (ctx.quote_buf.len == 0) return;
    String qtext = ctx.quote_buf.to_string();

    Span[] spans = parser::parse_inline(scratch, qtext);
    ctx.quote_buf.reset();
    if (spans.len > 0)
    {
        int max_w = ctx.width > 20 ? ctx.width - 6 : 76;
        render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, max_w, "│ ", "│ ", ctx.plain, ctx.no_wrap);
    }
}

fn void flush_table(StreamContext* ctx, logic::Arena* scratch)
{
    if (ctx.table_lines.size == 0)
    {
        return;
    }
    if (ctx.table_lines.size == 1)
    {
        Span[] spans = parser::parse_inline(scratch, ctx.table_lines.entries[0]);
        render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, ctx.width > 20 ? ctx.width - 2 : 80, "", "", ctx.plain, ctx.no_wrap);
        ctx.table_lines.clear();
        ctx.table_arena.reset();
        return;
    }

    usz header_cols = 0;
    Span[][] header_row = parser::parse_table_row_cells(scratch, ctx.table_lines.entries[0], &header_cols);
    Alignment[] alignments = parser::parse_table_alignments(scratch, ctx.table_lines.entries[1], header_cols);

    Span[][]* body_rows = (Span[][]*)scratch.alloc((usz)(ctx.table_lines.size - 2) * Span[][]::size);

    for (sz r = 2; r < ctx.table_lines.size; r++)
    {
        usz rcols = 0;
        Span[][] cell_row = parser::parse_table_row_cells(scratch, ctx.table_lines.entries[r], &rcols);
        body_rows[r - 2] = cell_row;
    }

    TableBlock tbl;
    tbl.col_count = (int)header_cols;
    tbl.alignments = alignments;
    tbl.headers = header_row;
    tbl.rows = body_rows[0 : (usz)(ctx.table_lines.size - 2)];

    render_table(&tbl, 0, ctx.width, ctx.plain, null, fn void(void* c, String s, int l) {
        io::printn(s);
    });

    ctx.table_lines.clear();
    ctx.table_arena.reset();
}

fn void process_stream_line(StreamContext* ctx, String line, logic::Arena* scratch)
{
    String trimmed = strutils::string_trim(line);

    // ── CODE FENCE STATE ─────────────────────────────────────────────────────
    if (ctx.state == StreamState.CODE_FENCE)
    {
        if ((usz)trimmed.len >= ctx.fence_len && trimmed[0] == ctx.fence_char)
        {
            usz close_len = 0;
            while (close_len < (usz)trimmed.len && trimmed[close_len] == ctx.fence_char) close_len++;
            if (close_len >= ctx.fence_len)
            {
                ctx.state = StreamState.IDLE;
                return;
            }
        }

        // Highlight code line live without leading spaces for easy copy-paste
        buffer::ByteBuffer cl;
        cl.init(512);
        defer cl.free();
        String code_lang = (String)(&ctx.code_lang[0])[:strutils::str_len(&ctx.code_lang[0])];
        highlight_code_line(&cl, line, code_lang, ctx.plain);
        io::printn(cl.to_string());
        return;
    }

    // ── MATH BLOCK STATE ─────────────────────────────────────────────────────
    if (ctx.state == StreamState.MATH_BLOCK)
    {
        if (ctx.math_is_dollar)
        {
            if (strutils::string_ends_with(trimmed, "$$") || strutils::string_starts_with(trimmed, "$$"))
            {
                if (trimmed.len > 2 && !strutils::string_starts_with(trimmed, "$$"))
                {
                    if (ctx.math_buf.len > 0) ctx.math_buf.append_char(' ');
                    ctx.math_buf.append_slice(trimmed[0 : (usz)trimmed.len - 2]);
                }
                flush_math_block(ctx, scratch);
                ctx.state = StreamState.IDLE;
                return;
            }
        }
        else
        {
            if (strutils::string_starts_with(trimmed, "\\end{"))
            {
                if (ctx.math_buf.len > 0) ctx.math_buf.append_char(' ');
                ctx.math_buf.append_slice(line);
                flush_math_block(ctx, scratch);
                ctx.state = StreamState.IDLE;
                return;
            }
        }

        if (ctx.math_buf.len > 0) ctx.math_buf.append_char(' ');
        ctx.math_buf.append_slice(line);
        return;
    }

    // ── TABLE STATE ──────────────────────────────────────────────────────────
    if (ctx.state == StreamState.TABLE)
    {
        if (strutils::string_starts_with(trimmed, "|") && trimmed.len > 0)
        {
            ctx.table_lines.push(ctx.table_arena.dup_string(line));
            return;
        }
        else
        {
            flush_table(ctx, scratch);
            ctx.state = StreamState.IDLE;
        }
    }

    // ── CALLOUT STATE ────────────────────────────────────────────────────────
    if (ctx.state == StreamState.CALLOUT)
    {
        if (strutils::string_starts_with(trimmed, ">"))
        {
            String qtext = trimmed[1..];
            if (qtext.len > 0 && qtext[0] == ' ') qtext = qtext[1..];
            if (ctx.callout_buf.len > 0) ctx.callout_buf.append_char(' ');
            ctx.callout_buf.append_slice(qtext);
            return;
        }
        else
        {
            flush_callout(ctx, scratch);
            ctx.state = StreamState.IDLE;
        }
    }

    // ── BLOCKQUOTE STATE ─────────────────────────────────────────────────────
    if (ctx.state == StreamState.BLOCKQUOTE)
    {
        if (strutils::string_starts_with(trimmed, ">"))
        {
            String qtext = trimmed[1..];
            if (qtext.len > 0 && qtext[0] == ' ') qtext = qtext[1..];
            if (ctx.quote_buf.len > 0) ctx.quote_buf.append_char(' ');
            ctx.quote_buf.append_slice(qtext);
            return;
        }
        else
        {
            flush_blockquote(ctx, scratch);
            ctx.state = StreamState.IDLE;
        }
    }

    // ── IDLE / NORMAL STATE ──────────────────────────────────────────────────
    // 1. Blank line
    if (trimmed.len == 0)
    {
        flush_paragraph(ctx, scratch);
        io::printn("");
        return;
    }

    // 2. Fenced Code Block: ```lang or ~~~lang
    if (strutils::string_starts_with(trimmed, "```") || strutils::string_starts_with(trimmed, "~~~"))
    {
        flush_paragraph(ctx, scratch);
        char fchar = trimmed[0];
        usz flen = 0;
        while (flen < (usz)trimmed.len && trimmed[flen] == fchar) flen++;
        String lang = strutils::string_trim(trimmed[flen..]);

        ctx.state = StreamState.CODE_FENCE;
        ctx.fence_char = fchar;
        ctx.fence_len = flen;
        usz llen = (usz)lang.len < 63 ? (usz)lang.len : 63;
        if (llen > 0)
        {
            mem::copy(&ctx.code_lang[0], lang.ptr, (sz)llen);
        }
        ctx.code_lang[llen] = 0;
        return;
    }

    // 3. Math Block: $$ ... $$
    if (strutils::string_starts_with(trimmed, "$$") || strutils::string_starts_with(trimmed, "\\begin{"))
    {
        flush_paragraph(ctx, scratch);
        if (strutils::string_starts_with(trimmed, "$$") && trimmed.len >= 4 && strutils::string_ends_with(trimmed, "$$") && trimmed.len > 4)
        {
            String mcontent = strutils::string_trim(trimmed[2 : (usz)trimmed.len - 4]);
            ctx.math_buf.reset();
            ctx.math_buf.append_slice(mcontent);
            flush_math_block(ctx, scratch);
            return;
        }

        ctx.state = StreamState.MATH_BLOCK;
        ctx.math_is_dollar = strutils::string_starts_with(trimmed, "$$");
        ctx.math_buf.reset();
        if (ctx.math_is_dollar)
        {
            if (trimmed.len > 2)
            {
                ctx.math_buf.append_slice(trimmed[2..]);
            }
        }
        else
        {
            ctx.math_buf.append_slice(line);
        }
        return;
    }

    // 4. Table header: |...|
    if (strutils::string_starts_with(trimmed, "|"))
    {
        flush_paragraph(ctx, scratch);
        ctx.state = StreamState.TABLE;
        ctx.table_lines.clear();
        ctx.table_arena.reset();
        ctx.table_lines.push(ctx.table_arena.dup_string(line));
        return;
    }

    // 5. Callouts: > [!NOTE], > [!TIP], > [!WARNING], > [!IMPORTANT], > [!CAUTION]
    if (strutils::string_starts_with(trimmed, "> [!"))
    {
        flush_paragraph(ctx, scratch);
        CalloutKind kind = CalloutKind.NOTE;
        String title = "NOTE";

        if (strutils::string_starts_with(trimmed, "> [!NOTE]") || strutils::string_starts_with(trimmed, "> [!INFO]")) { kind = CalloutKind.NOTE; title = "NOTE"; }
        else if (strutils::string_starts_with(trimmed, "> [!TIP]") || strutils::string_starts_with(trimmed, "> [!SUCCESS]")) { kind = CalloutKind.TIP; title = "TIP"; }
        else if (strutils::string_starts_with(trimmed, "> [!WARNING]")) { kind = CalloutKind.WARNING; title = "WARNING"; }
        else if (strutils::string_starts_with(trimmed, "> [!IMPORTANT]")) { kind = CalloutKind.IMPORTANT; title = "IMPORTANT"; }
        else if (strutils::string_starts_with(trimmed, "> [!DANGER]") || strutils::string_starts_with(trimmed, "> [!CAUTION]") || strutils::string_starts_with(trimmed, "> [!ERROR]")) { kind = CalloutKind.CAUTION; title = "CAUTION"; }

        ctx.state = StreamState.CALLOUT;
        ctx.callout_kind = kind;
        usz tlen = (usz)title.len < 63 ? (usz)title.len : 63;
        mem::copy(&ctx.callout_title[0], title.ptr, (sz)tlen);
        ctx.callout_title[tlen] = 0;
        ctx.callout_buf.reset();
        return;
    }

    // 6. Blockquote: > ...
    if (strutils::string_starts_with(trimmed, ">"))
    {
        flush_paragraph(ctx, scratch);
        ctx.state = StreamState.BLOCKQUOTE;
        ctx.quote_buf.reset();
        String qtext = trimmed[1..];
        if (qtext.len > 0 && qtext[0] == ' ') qtext = qtext[1..];
        ctx.quote_buf.append_slice(qtext);
        return;
    }

    // 7. Thematic Break: ---, ***, ___
    if (parser::is_thematic_break(line))
    {
        flush_paragraph(ctx, scratch);
        buffer::ByteBuffer tb;
        tb.init(256);
        defer tb.free();
        if (!ctx.plain) tb.append_zstr(ansi::fg_muted);
        int bar_len = ctx.width > 20 ? ctx.width - 4 : 76;
        tb.append_repeat("─", bar_len);
        if (!ctx.plain) tb.append_zstr(ansi::RESET);
        io::printn(tb.to_string());
        return;
    }

    // 8. Headings: # through ######
    if (strutils::string_starts_with(trimmed, "# ") || strutils::string_starts_with(trimmed, "## ") || strutils::string_starts_with(trimmed, "### ") || strutils::string_starts_with(trimmed, "#### ") || strutils::string_starts_with(trimmed, "##### ") || strutils::string_starts_with(trimmed, "###### "))
    {
        flush_paragraph(ctx, scratch);
        int hlevel = 0;
        while ((usz)hlevel < (usz)trimmed.len && trimmed[hlevel] == '#') hlevel++;
        String htext = strutils::string_trim(trimmed[(usz)hlevel..]);

        buffer::ByteBuffer hb;
        hb.init(256);
        defer hb.free();

        if (!ctx.plain)
        {
            switch (hlevel)
            {
                case 1: hb.append_zstr(ansi::fg_h1);
                case 2: hb.append_zstr(ansi::fg_h2);
                case 3: hb.append_zstr(ansi::fg_h3);
                case 4: hb.append_zstr(ansi::fg_h4);
                case 5: hb.append_zstr(ansi::fg_h5);
                default: hb.append_zstr(ansi::fg_h6);
            }
        }
        else
        {
            for (int k = 0; k < hlevel; k++) hb.append_char('#');
            hb.append_char(' ');
        }
        Span[] hspans = parser::parse_inline(scratch, htext);
        render_spans(&hb, hspans, ctx.plain);
        if (!ctx.plain) hb.append_zstr(ansi::RESET);
        io::printn(hb.to_string());
        return;
    }

    // 9. Task lists / Checkboxes: - [ ] or - [x]
    usz indent = 0;
    while (indent < (usz)line.len && line[indent] == ' ') indent++;
    if (indent + 5 < (usz)line.len)
    {
        String sub = line[indent..];
        if (strutils::string_starts_with(sub, "- [ ] ") || strutils::string_starts_with(sub, "* [ ] "))
        {
            flush_paragraph(ctx, scratch);
            String task_txt = sub[6..];
            Span[] tspans = parser::parse_inline(scratch, task_txt);

            buffer::ByteBuffer pfx;
            pfx.init(32);
            defer pfx.free();
            pfx.append_spaces((int)indent);
            pfx.append_zstr("☐  ");

            buffer::ByteBuffer cpfx;
            cpfx.init(32);
            defer cpfx.free();
            cpfx.append_spaces((int)indent + 3);

            int max_w = ctx.width > 20 ? ctx.width - (int)indent - 4 : 76;
            render_wrapped_spans(null, &emit_stream_line_cb, tspans, 0, max_w, cpfx.to_string(), pfx.to_string(), ctx.plain, ctx.no_wrap);
            return;
        }
        if (strutils::string_starts_with(sub, "- [x] ") || strutils::string_starts_with(sub, "- [X] ") || strutils::string_starts_with(sub, "* [x] ") || strutils::string_starts_with(sub, "* [X] "))
        {
            flush_paragraph(ctx, scratch);
            String task_txt = sub[6..];
            Span[] tspans = parser::parse_inline(scratch, task_txt);

            buffer::ByteBuffer pfx;
            pfx.init(32);
            defer pfx.free();
            pfx.append_spaces((int)indent);
            if (!ctx.plain) pfx.append_zstr(ansi::fg_green);
            pfx.append_zstr("✔  ");
            if (!ctx.plain) pfx.append_zstr(ansi::RESET);

            buffer::ByteBuffer cpfx;
            cpfx.init(32);
            defer cpfx.free();
            cpfx.append_spaces((int)indent + 3);

            int max_w = ctx.width > 20 ? ctx.width - (int)indent - 4 : 76;
            render_wrapped_spans(null, &emit_stream_line_cb, tspans, 0, max_w, cpfx.to_string(), pfx.to_string(), ctx.plain, ctx.no_wrap);
            return;
        }
    }

    // 10. Bullet lists: * , - , +
    if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ')
    {
        flush_paragraph(ctx, scratch);
        String itxt = line[indent + 2..];
        Span[] spans = parser::parse_inline(scratch, itxt);

        char* b_glyph = "• ";
        if (indent >= 4)
        {
            b_glyph = "▪ ";
        }
        else if (indent >= 2)
        {
            b_glyph = "◦ ";
        }

        buffer::ByteBuffer pfx;
        pfx.init(32);
        defer pfx.free();
        pfx.append_spaces((int)indent);
        pfx.append_zstr(b_glyph);

        buffer::ByteBuffer cpfx;
        cpfx.init(32);
        defer cpfx.free();
        cpfx.append_spaces((int)indent + 2);

        int max_w = ctx.width > 20 ? ctx.width - (int)indent - 4 : 76;
        render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, max_w, cpfx.to_string(), pfx.to_string(), ctx.plain, ctx.no_wrap);
        return;
    }

    // 11. Ordered lists: 1. , 2.
    int ord_num = 0;
    usz ord_len = 0;
    if (parser::is_ordered_list(line, indent, &ord_num, &ord_len))
    {
        flush_paragraph(ctx, scratch);
        String itxt = line[ord_len..];
        Span[] spans = parser::parse_inline(scratch, itxt);

        buffer::ByteBuffer pfx;
        pfx.init(32);
        defer pfx.free();
        pfx.append_spaces((int)indent);
        pfx.append_int(ord_num);
        pfx.append_zstr(". ");

        int pfx_w = strutils::string_display_width(pfx.to_string());
        buffer::ByteBuffer cpfx;
        cpfx.init(32);
        defer cpfx.free();
        cpfx.append_spaces(pfx_w);

        int max_w = ctx.width > 20 ? ctx.width - pfx_w - 2 : 76;
        render_wrapped_spans(null, &emit_stream_line_cb, spans, 0, max_w, cpfx.to_string(), pfx.to_string(), ctx.plain, ctx.no_wrap);
        return;
    }

    // 12. Normal paragraph line: accumulate for live word-reflow
    if (ctx.para_buf.len > 0) ctx.para_buf.append_char(' ');
    ctx.para_buf.append_slice(trimmed);
}

/**
 * High-performance non-blocking progressive stream renderer.
 * Formats and streams LLM / stdin token responses in real-time.
 */
fn void render_and_stream_stdin(int width, bool no_wrap)
{
    logic::Arena scratch;
    scratch.init(65536);
    defer scratch.free();

    StreamContext ctx;
    ctx.width = width > 20 ? width : 80;
    ctx.plain = ansi::plain_mode;
    ctx.no_wrap = no_wrap;
    ctx.state = StreamState.IDLE;
    ctx.code_lang[0] = 0;
    ctx.callout_title[0] = 0;
    ctx.math_buf.init(1024);
    defer ctx.math_buf.free();
    ctx.table_lines.init(mem, 32);
    defer ctx.table_lines.free();
    ctx.table_arena.init(16384);
    defer ctx.table_arena.free();
    ctx.callout_buf.init(1024);
    defer ctx.callout_buf.free();
    ctx.quote_buf.init(1024);
    defer ctx.quote_buf.free();
    ctx.para_buf.init(2048);
    defer ctx.para_buf.free();

    buffer::ByteBuffer line_accum;
    line_accum.init(4096);
    defer line_accum.free();

    char[4096] chunk;

    while (true)
    {
        int bytes = read(0, (void*)&chunk[0], 4096);
        if (bytes <= 0) break;

        for (int i = 0; i < bytes; i++)
        {
            char c = chunk[i];
            if (c == '\n')
            {
                String cur_l = line_accum.to_string();
                if (cur_l.len > 0 && cur_l[cur_l.len - 1] == '\r')
                {
                    cur_l = cur_l[0 : cur_l.len - 1];
                }

                logic::ArenaMark mark = scratch.mark();
                process_stream_line(&ctx, cur_l, &scratch);
                line_accum.reset();
                scratch.reset_to(mark);
            }
            else
            {
                line_accum.append_char(c);
            }
        }
    }

    // Flush any remaining partial line on EOF
    if (line_accum.len > 0)
    {
        logic::ArenaMark mark = scratch.mark();
        process_stream_line(&ctx, line_accum.to_string(), &scratch);
        scratch.reset_to(mark);
    }

    // Flush any open multi-line blocks
    logic::ArenaMark mark = scratch.mark();
    if (ctx.state == StreamState.MATH_BLOCK)
    {
        flush_math_block(&ctx, &scratch);
    }
    else if (ctx.state == StreamState.TABLE)
    {
        flush_table(&ctx, &scratch);
    }
    else if (ctx.state == StreamState.CALLOUT)
    {
        flush_callout(&ctx, &scratch);
    }
    else if (ctx.state == StreamState.BLOCKQUOTE)
    {
        flush_blockquote(&ctx, &scratch);
    }
    flush_paragraph(&ctx, &scratch);
    scratch.reset_to(mark);
}
