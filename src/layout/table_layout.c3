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

struct WrappedCellLine {
    char[256] text;
    int len;
    int display_width;
}

struct WrappedCell {
    WrappedCellLine[12] lines;
    int count;
}

fn void wrap_cell(ast::Span[] spans, int max_w, WrappedCell* out_cell)
{
    out_cell.count = 0;
    if (spans.len == 0 || max_w <= 0)
    {
        out_cell.count = 1;
        out_cell.lines[0].text[0] = 0;
        out_cell.lines[0].len = 0;
        out_cell.lines[0].display_width = 0;
        return;
    }

    int cur_line = 0;
    out_cell.lines[0].len = 0;
    out_cell.lines[0].display_width = 0;
    out_cell.lines[0].text[0] = 0;

    for (usz s = 0; s < spans.len; s++)
    {
        String txt = spans[s].text;
        usz p = 0;
        usz tlen = (usz)txt.len;

        while (p < tlen)
        {
            while (p < tlen && (txt[p] == ' ' || txt[p] == '\t'))
            {
                p++;
            }
            if (p >= tlen) break;

            usz w_start = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n')
            {
                p++;
            }
            String word = txt[w_start : p - w_start];
            int word_w = strutils::string_display_width(word);

            WrappedCellLine* cl = &out_cell.lines[cur_line];

            if (cl.display_width > 0 && cl.display_width + 1 + word_w > max_w && cur_line < 11)
            {
                cl.text[cl.len] = 0;
                cur_line++;
                cl = &out_cell.lines[cur_line];
                cl.len = 0;
                cl.display_width = 0;
                cl.text[0] = 0;
            }
            else if (cl.display_width > 0)
            {
                if (cl.len < 250)
                {
                    cl.text[cl.len++] = ' ';
                }
                cl.display_width++;
            }

            for (usz k = 0; k < (usz)word.len && cl.len < 250; k++)
            {
                cl.text[cl.len++] = word[k];
            }
            cl.text[cl.len] = 0;
            cl.display_width += word_w;
        }
    }

    out_cell.lines[cur_line].text[out_cell.lines[cur_line].len] = 0;
    out_cell.count = cur_line + 1;
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
    WrappedCell[16] wrapped;
    int max_lines = 1;

    for (int c = 0; c < cols && c < 16; c++)
    {
        int w = (*col_widths)[c];
        ast::Span[] cspans = (c < (int)cells.len) ? cells[c] : {};
        wrap_cell(cspans, w, &wrapped[c]);
        if (wrapped[c].count > max_lines)
        {
            max_lines = wrapped[c].count;
        }
    }

    for (int line_idx = 0; line_idx < max_lines; line_idx++)
    {
        if (!plain) tb.append_str((char*)ansi::FG_MUTED);
        tb.append_str("│");
        if (!plain) tb.append_str((char*)ansi::RESET);

        for (int c = 0; c < cols && c < 16; c++)
        {
            int w = (*col_widths)[c];
            ast::Alignment align = (c < (int)table.alignments.len) ? table.alignments[c] : ast::Alignment.LEFT;

            tb.append_str(" ");
            if (!plain)
            {
                if (is_header)
                {
                    tb.append_str((char*)ansi::FG_CYAN);
                    tb.append_str((char*)ansi::BOLD);
                }
                else
                {
                    tb.append_str((char*)ansi::FG_TEXT);
                }
            }

            if (line_idx < wrapped[c].count)
            {
                WrappedCellLine* cl = &wrapped[c].lines[line_idx];
                int dw = cl.display_width;
                int pad = w - dw;
                if (pad < 0) pad = 0;

                String cell_text = (String)cl.text[:cl.len];

                if (align == ast::Alignment.CENTER)
                {
                    int lpad = pad / 2;
                    int rpad = pad - lpad;
                    tb.append_spaces(lpad);
                    tb.append_slice(cell_text);
                    tb.append_spaces(rpad);
                }
                else if (align == ast::Alignment.RIGHT)
                {
                    tb.append_spaces(pad);
                    tb.append_slice(cell_text);
                }
                else // Left
                {
                    tb.append_slice(cell_text);
                    tb.append_spaces(pad);
                }
            }
            else
            {
                tb.append_spaces(w);
            }

            if (!plain) tb.append_str((char*)ansi::RESET);
            tb.append_str(" ");

            if (!plain) tb.append_str((char*)ansi::FG_MUTED);
            tb.append_str("│");
            if (!plain) tb.append_str((char*)ansi::RESET);
        }

        tb.flush(ctx, src_line, emit_fn);
    }
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
    int total_nat = 1;
    int sum_col_w = 0;
    for (int c = 0; c < cols; c++)
    {
        sum_col_w += col_widths[c];
        total_nat += col_widths[c] + 3;
    }

    int max_avail_table = term_width - 2;
    if (max_avail_table < 20) max_avail_table = 20;

    if (total_nat > max_avail_table)
    {
        int avail_text_budget = max_avail_table - (cols * 3 + 1);
        if (avail_text_budget < cols * 3) avail_text_budget = cols * 3;

        int distributed = 0;
        for (int c = 0; c < cols; c++)
        {
            if (sum_col_w > 0)
            {
                col_widths[c] = (col_widths[c] * avail_text_budget) / sum_col_w;
            }
            else
            {
                col_widths[c] = avail_text_budget / cols;
            }
            if (col_widths[c] < 3) col_widths[c] = 3;
            distributed += col_widths[c];
        }

        // Fix rounding drift on the last column
        int diff = avail_text_budget - distributed;
        if (cols > 0 && col_widths[cols - 1] + diff >= 3)
        {
            col_widths[cols - 1] += diff;
        }
    }

    TableRowBuffer tb;
    tb.init(4096);
    defer tb.free();

    // Top border: ┌──────┬──────┐
    if (!plain) tb.append_str((char*)ansi::FG_MUTED);
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
    if (!plain) tb.append_str((char*)ansi::FG_MUTED);
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
        if (r + 1 < table.rows.len)
        {
            if (!plain) tb.append_str((char*)ansi::FG_MUTED);
            tb.append_str("├");
            for (int c = 0; c < cols; c++)
            {
                tb.append_repeat("─", col_widths[c] + 2);
                if (c < cols - 1) tb.append_str("┼");
            }
            tb.append_str("┤");
            if (!plain) tb.append_str((char*)ansi::RESET);
            tb.flush(ctx, src_line, emit_fn);
        }
    }

    // Bottom border: └──────┴──────┘
    if (!plain) tb.append_str((char*)ansi::FG_MUTED);
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
