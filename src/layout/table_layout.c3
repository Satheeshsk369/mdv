module layout;

import std::core::mem;
import logic;
import ansi;
import strutils;
import buffer;
import render;

alias EmitLineFn = fn void(void* ctx, String text, int src_line);

fn String render_cell_text(logic::Arena* arena, Span[] spans, bool plain, int* out_display_w)
{
    if (spans.len == 0)
    {
        *out_display_w = 0;
        return "";
    }
    buffer::ByteBuffer b;
    b.init(256);
    defer b.free();

    render::render_spans(&b, spans, plain);
    String res = b.to_string();
    *out_display_w = strutils::string_display_width(res);
    return arena.dup_string(res);
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

    // Pre-render and measure headers
    String* header_texts_ptr = (String*)logic::g_ctx.scratch_arena.alloc((usz)cols * String::size);
    int* header_widths_ptr = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);

    for (int c = 0; c < cols; c++)
    {
        Span[] hspans = (c < (int)table.headers.len) ? table.headers[c] : {};
        int dw = 0;
        header_texts_ptr[c] = render_cell_text(&logic::g_ctx.scratch_arena, hspans, plain, &dw);
        header_widths_ptr[c] = dw;
        if (dw > col_widths[c]) col_widths[c] = dw;
    }

    // Pre-render and measure body rows
    usz num_rows = table.rows.len;
    String[]* body_cells_ptr = (String[]*)logic::g_ctx.scratch_arena.alloc(num_rows * String[]::size);
    int[]* body_widths_ptr = (int[]*)logic::g_ctx.scratch_arena.alloc(num_rows * int[]::size);

    for (usz r = 0; r < num_rows; r++)
    {
        Span[][] row = table.rows[r];
        String* r_texts = (String*)logic::g_ctx.scratch_arena.alloc((usz)cols * String::size);
        int* r_widths = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);

        for (int c = 0; c < cols; c++)
        {
            Span[] cspans = (c < (int)row.len) ? row[c] : {};
            int dw = 0;
            r_texts[c] = render_cell_text(&logic::g_ctx.scratch_arena, cspans, plain, &dw);
            r_widths[c] = dw;
            if (dw > col_widths[c]) col_widths[c] = dw;
        }

        body_cells_ptr[r] = r_texts[0 : (usz)cols];
        body_widths_ptr[r] = r_widths[0 : (usz)cols];
    }

    // Adjust for terminal width if needed (2 spaces gap between columns)
    int gap = 2;
    int total_width = 0;
    for (int c = 0; c < cols; c++)
    {
        total_width += col_widths[c];
        if (c < cols - 1) total_width += gap;
    }

    int max_avail = term_width > 20 ? term_width - 2 : 80;
    if (total_width > max_avail)
    {
        int avail_budget = max_avail - (cols - 1) * gap;
        if (avail_budget < cols * 3) avail_budget = cols * 3;
        int sum_w = 0;
        for (int c = 0; c < cols; c++) sum_w += col_widths[c];
        int distributed = 0;
        for (int c = 0; c < cols; c++)
        {
            if (sum_w > 0)
            {
                col_widths[c] = (col_widths[c] * avail_budget) / sum_w;
            }
            else
            {
                col_widths[c] = avail_budget / cols;
            }
            if (col_widths[c] < 3) col_widths[c] = 3;
            distributed += col_widths[c];
        }
        int diff = avail_budget - distributed;
        if (cols > 0 && col_widths[cols - 1] + diff >= 3)
        {
            col_widths[cols - 1] += diff;
        }
    }

    buffer::ByteBuffer tb;
    tb.init(4096);
    defer tb.free();

    // 1. Header row
    for (int c = 0; c < cols; c++)
    {
        int w = col_widths[c];
        int dw = header_widths_ptr[c];
        int pad = w - dw;
        if (pad < 0) pad = 0;
        String text = header_texts_ptr[c];
        Alignment align = (c < (int)table.alignments.len) ? table.alignments[c] : Alignment.LEFT;

        if (!plain)
        {
            tb.append_zstr((char*)ansi::FG_CYAN);
            tb.append_zstr((char*)ansi::BOLD);
        }

        if (align == Alignment.CENTER)
        {
            int lpad = pad / 2;
            int rpad = pad - lpad;
            tb.append_spaces(lpad);
            tb.append_slice(text);
            tb.append_spaces(rpad);
        }
        else if (align == Alignment.RIGHT)
        {
            tb.append_spaces(pad);
            tb.append_slice(text);
        }
        else // LEFT
        {
            tb.append_slice(text);
            tb.append_spaces(pad);
        }

        if (!plain) tb.append_zstr((char*)ansi::RESET);
        if (c < cols - 1) tb.append_spaces(gap);
    }
    emit_fn(ctx, tb.to_string(), src_line);

    // 2. Separator line
    tb.reset();
    if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c]);
        if (c < cols - 1) tb.append_spaces(gap);
    }
    if (!plain) tb.append_zstr((char*)ansi::RESET);
    emit_fn(ctx, tb.to_string(), src_line);

    // 3. Body rows
    for (usz r = 0; r < num_rows; r++)
    {
        tb.reset();
        String[] r_texts = body_cells_ptr[r];
        int[] r_widths = body_widths_ptr[r];

        for (int c = 0; c < cols; c++)
        {
            int w = col_widths[c];
            int dw = r_widths[c];
            int pad = w - dw;
            if (pad < 0) pad = 0;
            String text = r_texts[c];
            Alignment align = (c < (int)table.alignments.len) ? table.alignments[c] : Alignment.LEFT;

            if (align == Alignment.CENTER)
            {
                int lpad = pad / 2;
                int rpad = pad - lpad;
                tb.append_spaces(lpad);
                tb.append_slice(text);
                tb.append_spaces(rpad);
            }
            else if (align == Alignment.RIGHT)
            {
                tb.append_spaces(pad);
                tb.append_slice(text);
            }
            else // LEFT
            {
                tb.append_slice(text);
                tb.append_spaces(pad);
            }

            if (c < cols - 1) tb.append_spaces(gap);
        }
        emit_fn(ctx, tb.to_string(), src_line + 2 + (int)r);
    }
}
