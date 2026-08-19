module layout;

import std::core::mem;
import ast;
import ansi;
import strutils;

alias EmitLineFn = fn void(void* ctx, String text, int src_line);

struct TableRowBuffer {
    char[] buf;
    usz len;
    usz cap;
}

fn void TableRowBuffer.init(TableRowBuffer* b, usz initial_cap)
{
    b.buf = mem::alloc_array(char, (sz)initial_cap);
    b.len = 0;
    b.cap = initial_cap;
}

fn void TableRowBuffer.append_char(TableRowBuffer* b, char c)
{
    if (b.len < b.cap - 1)
    {
        b.buf[b.len++] = c;
    }
}

fn void TableRowBuffer.append_str(TableRowBuffer* b, char* s)
{
    if (s == null) return;
    usz sl = 0;
    while (s[sl] != 0 && b.len < b.cap - 1)
    {
        b.buf[b.len++] = s[sl++];
    }
}

fn void TableRowBuffer.append_slice(TableRowBuffer* b, String s)
{
    for (usz i = 0; i < (usz)s.len && b.len < b.cap - 1; i++)
    {
        b.buf[b.len++] = s[i];
    }
}

fn void TableRowBuffer.append_spaces(TableRowBuffer* b, int count)
{
    for (int i = 0; i < count; i++)
    {
        b.append_char(' ');
    }
}

fn void TableRowBuffer.append_repeat(TableRowBuffer* b, char* s, int count)
{
    for (int i = 0; i < count; i++)
    {
        b.append_str(s);
    }
}

fn void TableRowBuffer.flush(TableRowBuffer* b, void* ctx, int src_line, EmitLineFn emit_fn)
{
    String str_line = (String)b.buf[:b.len];
    emit_fn(ctx, str_line, src_line);
    b.len = 0;
}

fn void TableRowBuffer.free(TableRowBuffer* b)
{
    if (b.buf.ptr != null)
    {
        mem::free(b.buf);
        b.buf = {};
        b.len = 0;
        b.cap = 0;
    }
}

fn void render_single_row(
    TableRowBuffer* tb,
    ast::TableBlock* table,
    ast::Span[][] cells,
    int[64]* col_widths,
    int cols,
    bool is_header,
    bool plain,
    int src_line,
    void* ctx,
    EmitLineFn emit_fn
)
{
    if (!plain) tb.append_str((char*)ansi::fg_muted);
    tb.append_str("│");
    if (!plain) tb.append_str((char*)ansi::RESET);

    for (int c = 0; c < cols; c++)
    {
        int w = (*col_widths)[c];
        ast::Span[] cspans = (c < (int)cells.len) ? cells[c] : {};

        int dw = 0;
        for (usz s = 0; s < cspans.len; s++)
        {
            dw += strutils::string_display_width(cspans[s].text);
        }
        int pad = w - dw;
        if (pad < 0) pad = 0;

        ast::Alignment align = (c < (int)table.alignments.len) ? table.alignments[c] : ast::Alignment.LEFT;

        tb.append_str(" ");
        if (!plain)
        {
            if (is_header)
            {
                tb.append_str((char*)ansi::fg_cyan);
                tb.append_str((char*)ansi::BOLD);
            }
            else
            {
                tb.append_str((char*)ansi::fg_text);
            }
        }

        if (align == ast::Alignment.CENTER)
        {
            int lpad = pad / 2;
            int rpad = pad - lpad;
            tb.append_spaces(lpad);
            for (usz s = 0; s < cspans.len; s++) tb.append_slice(cspans[s].text);
            tb.append_spaces(rpad);
        }
        else if (align == ast::Alignment.RIGHT)
        {
            tb.append_spaces(pad);
            for (usz s = 0; s < cspans.len; s++) tb.append_slice(cspans[s].text);
        }
        else // Left
        {
            for (usz s = 0; s < cspans.len; s++) tb.append_slice(cspans[s].text);
            tb.append_spaces(pad);
        }

        if (!plain) tb.append_str((char*)ansi::RESET);
        tb.append_str(" ");

        if (!plain) tb.append_str((char*)ansi::fg_muted);
        tb.append_str("│");
        if (!plain) tb.append_str((char*)ansi::RESET);
    }
    tb.flush(ctx, src_line, emit_fn);
}

fn void render_table(ast::TableBlock* table, int src_line, int term_width, bool plain, void* ctx, EmitLineFn emit_fn)
{
    if (table.col_count <= 0) return;
    int cols = table.col_count;

    const usz MAX_COLS = 64;
    if (cols > (int)MAX_COLS) cols = (int)MAX_COLS;

    int[MAX_COLS] col_widths;
    for (int c = 0; c < cols; c++)
    {
        col_widths[c] = 3;
    }

    // Measure headers
    for (int c = 0; c < cols && c < (int)table.headers.len; c++)
    {
        ast::Span[] hspans = table.headers[c];
        int w = 0;
        for (usz s = 0; s < hspans.len; s++)
        {
            w += strutils::string_display_width(hspans[s].text);
        }
        if (w > col_widths[c]) col_widths[c] = w;
    }

    // Measure body rows
    for (usz r = 0; r < table.rows.len; r++)
    {
        ast::Span[][] row = table.rows[r];
        for (int c = 0; c < cols && c < (int)row.len; c++)
        {
            ast::Span[] cspans = row[c];
            int w = 0;
            for (usz s = 0; s < cspans.len; s++)
            {
                w += strutils::string_display_width(cspans[s].text);
            }
            if (w > col_widths[c]) col_widths[c] = w;
        }
    }

    // Adjust for terminal width
    int total_w = 1;
    for (int c = 0; c < cols; c++)
    {
        total_w += col_widths[c] + 3;
    }

    if (total_w > term_width - 2 && term_width > 20)
    {
        int available = term_width - 2 - (cols * 3 + 1);
        if (available > cols * 4)
        {
            int fixed_w = 0;
            for (int c = 0; c < cols - 1; c++)
            {
                if (col_widths[c] > 20) col_widths[c] = 20;
                fixed_w += col_widths[c];
            }
            int last_col = cols - 1;
            int rem = available - fixed_w;
            if (rem >= 6)
            {
                col_widths[last_col] = rem;
            }
        }
    }

    TableRowBuffer tb;
    tb.init(4096);
    defer tb.free();

    // Top border: ┌──────┬──────┐
    if (!plain) tb.append_str((char*)ansi::fg_muted);
    tb.append_str("┌");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_str("┬");
    }
    tb.append_str("┐");
    if (!plain) tb.append_str((char*)ansi::RESET);
    tb.flush(ctx, src_line, emit_fn);

    // Header row
    render_single_row(&tb, table, table.headers, &col_widths, cols, true, plain, src_line, ctx, emit_fn);

    // Middle border: ├──────┼──────┤
    if (!plain) tb.append_str((char*)ansi::fg_muted);
    tb.append_str("├");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_str("┼");
    }
    tb.append_str("┤");
    if (!plain) tb.append_str((char*)ansi::RESET);
    tb.flush(ctx, src_line, emit_fn);

    // Body rows
    for (usz r = 0; r < table.rows.len; r++)
    {
        render_single_row(&tb, table, table.rows[r], &col_widths, cols, false, plain, src_line, ctx, emit_fn);
    }

    // Bottom border: └──────┴──────┘
    if (!plain) tb.append_str((char*)ansi::fg_muted);
    tb.append_str("└");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_str("┴");
    }
    tb.append_str("┘");
    if (!plain) tb.append_str((char*)ansi::RESET);
    tb.flush(ctx, src_line, emit_fn);
}
