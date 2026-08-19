module layout;

import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import strutils;
import buffer;

alias EmitLineFn = fn void(void* ctx, String text, int src_line);

struct WrappedCellLine {
    buffer::ByteBuffer text;
    int display_width;
}

struct WrappedCell {
    List{WrappedCellLine} lines;
}

fn void WrappedCell.init(WrappedCell* cell)
{
    cell.lines.init(mem, 4);
}

fn void WrappedCell.free(WrappedCell* cell)
{
    for (sz i = 0; i < cell.lines.size; i++)
    {
        cell.lines.entries[i].text.free();
    }
    cell.lines.free();
}

fn void wrap_cell(Span[] spans, int max_w, WrappedCell* out_cell)
{
    out_cell.init();

    if (spans.len == 0 || max_w <= 0)
    {
        WrappedCellLine first_line;
        first_line.text.init(32);
        first_line.display_width = 0;
        out_cell.lines.push(first_line);
        return;
    }

    WrappedCellLine cur_line;
    cur_line.text.init(64);
    cur_line.display_width = 0;

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

            if (cur_line.display_width > 0 && cur_line.display_width + 1 + word_w > max_w)
            {
                out_cell.lines.push(cur_line);
                cur_line.text.init(64);
                cur_line.display_width = 0;
            }
            else if (cur_line.display_width > 0)
            {
                cur_line.text.append_char(' ');
                cur_line.display_width++;
            }

            cur_line.text.append_slice(word);
            cur_line.display_width += word_w;
        }
    }

    out_cell.lines.push(cur_line);
}

fn void render_single_row(
    buffer::ByteBuffer* tb,
    TableBlock* table,
    Span[][] cells,
    int[] col_widths,
    int cols,
    bool is_header,
    bool plain,
    int src_line,
    void* ctx,
    EmitLineFn emit_fn
)
{
    WrappedCell* wrapped_ptr = (WrappedCell*)logic::g_ctx.scratch_arena.alloc((usz)cols * WrappedCell::size);
    WrappedCell[] wrapped = wrapped_ptr[0 : (usz)cols];
    for (int c = 0; c < cols; c++) wrapped[c].init();
    defer {
        for (int c = 0; c < cols; c++) wrapped[c].free();
    }

    int max_lines = 1;

    for (int c = 0; c < cols; c++)
    {
        int w = col_widths[c];
        Span[] cspans = (c < (int)cells.len) ? cells[c] : {};
        wrap_cell(cspans, w, &wrapped[c]);
        if ((int)wrapped[c].lines.size > max_lines)
        {
            max_lines = (int)wrapped[c].lines.size;
        }
    }

    for (int line_idx = 0; line_idx < max_lines; line_idx++)
    {
        tb.reset();

        if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
        tb.append_zstr("│");
        if (!plain) tb.append_zstr((char*)ansi::RESET);

        for (int c = 0; c < cols; c++)
        {
            int w = col_widths[c];
            Alignment align = (c < (int)table.alignments.len) ? table.alignments[c] : Alignment.LEFT;

            tb.append_zstr(" ");
            if (!plain)
            {
                if (is_header)
                {
                    tb.append_zstr((char*)ansi::FG_CYAN);
                    tb.append_zstr((char*)ansi::BOLD);
                }
                else
                {
                    tb.append_zstr((char*)ansi::FG_TEXT);
                }
            }

            if (line_idx < (int)wrapped[c].lines.size)
            {
                WrappedCellLine* cl = &wrapped[c].lines.entries[(usz)line_idx];
                int dw = cl.display_width;
                int pad = w - dw;
                if (pad < 0) pad = 0;

                String cell_text = cl.text.to_string();

                if (align == Alignment.CENTER)
                {
                    int lpad = pad / 2;
                    int rpad = pad - lpad;
                    tb.append_spaces(lpad);
                    tb.append_slice(cell_text);
                    tb.append_spaces(rpad);
                }
                else if (align == Alignment.RIGHT)
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

            if (!plain) tb.append_zstr((char*)ansi::RESET);
            tb.append_zstr(" ");

            if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
            tb.append_zstr("│");
            if (!plain) tb.append_zstr((char*)ansi::RESET);
        }

        String str_line = tb.to_string();
        emit_fn(ctx, str_line, src_line);
    }
}

fn void render_table(TableBlock* table, int src_line, int term_width, bool plain, void* ctx, EmitLineFn emit_fn)
{
    if (table.col_count <= 0) return;
    int cols = table.col_count;

    logic::LocalScratchScope scope = logic::enter_scratch_scope(&logic::g_ctx.scratch_arena);
    defer scope.exit();

    int* col_widths_ptr = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);
    int[] col_widths = col_widths_ptr[0 : (usz)cols];

    for (int c = 0; c < cols; c++)
    {
        col_widths[c] = 3;
    }

    // Measure headers
    for (int c = 0; c < cols && c < (int)table.headers.len; c++)
    {
        Span[] hspans = table.headers[c];
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
        Span[][] row = table.rows[r];
        for (int c = 0; c < cols && c < (int)row.len; c++)
        {
            Span[] cspans = row[c];
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

    buffer::ByteBuffer tb;
    tb.init(4096);
    defer tb.free();

    // Top border: ┌──────┬──────┐
    if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
    tb.append_zstr("┌");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_zstr("┬");
    }
    tb.append_zstr("┐");
    if (!plain) tb.append_zstr((char*)ansi::RESET);
    emit_fn(ctx, tb.to_string(), src_line);

    // Header row
    render_single_row(&tb, table, table.headers, col_widths, cols, true, plain, src_line, ctx, emit_fn);

    // Middle border: ├──────┼──────┤
    tb.reset();
    if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
    tb.append_zstr("├");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_zstr("┼");
    }
    tb.append_zstr("┤");
    if (!plain) tb.append_zstr((char*)ansi::RESET);
    emit_fn(ctx, tb.to_string(), src_line);

    // Body rows
    for (usz r = 0; r < table.rows.len; r++)
    {
        render_single_row(&tb, table, table.rows[r], col_widths, cols, false, plain, src_line, ctx, emit_fn);
        if (r + 1 < table.rows.len)
        {
            tb.reset();
            if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
            tb.append_zstr("├");
            for (int c = 0; c < cols; c++)
            {
                tb.append_repeat("─", col_widths[c] + 2);
                if (c < cols - 1) tb.append_zstr("┼");
            }
            tb.append_zstr("┤");
            if (!plain) tb.append_zstr((char*)ansi::RESET);
            emit_fn(ctx, tb.to_string(), src_line);
        }
    }

    // Bottom border: └──────┴──────┘
    tb.reset();
    if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
    tb.append_zstr("└");
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c] + 2);
        if (c < cols - 1) tb.append_zstr("┴");
    }
    tb.append_zstr("┘");
    if (!plain) tb.append_zstr((char*)ansi::RESET);
    emit_fn(ctx, tb.to_string(), src_line);
}
