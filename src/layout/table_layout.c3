module layout;

import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import strutils;
import buffer;

alias EmitLineFn = fn void(void* ctx, String text, int src_line);

struct WrappedCellLine {
    String text;
    int display_width;
}

struct WrappedCell {
    List{WrappedCellLine} lines;
}

fn void measure_cell_metrics(Span[] spans, int* out_min_w, int* out_max_w)
{
    if (spans.len == 0) return;
    int total_w = 0;
    int max_word_w = 0;

    for (usz s = 0; s < spans.len; s++)
    {
        Span sp = spans[s];
        String txt = sp.text;
        usz p = 0;
        usz tlen = (usz)txt.len;

        while (p < tlen)
        {
            while (p < tlen && (txt[p] == ' ' || txt[p] == '\t')) p++;
            if (p >= tlen) break;

            usz w_start = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n') p++;
            String word = txt[w_start : p - w_start];
            int ww = strutils::string_display_width(word);
            if (ww > max_word_w) max_word_w = ww;
        }

        int sw = strutils::string_display_width(txt);
        total_w += sw;

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int uw = strutils::string_display_width(sp.url) + 3;
            if (uw > max_word_w) max_word_w = uw;
            total_w += uw;
        }
    }

    if (total_w > *out_max_w) *out_max_w = total_w;
    if (max_word_w > *out_min_w) *out_min_w = max_word_w;
}

fn void wrap_cell(logic::Arena* arena, Span[] spans, int max_w, bool plain, WrappedCell* out_cell)
{
    out_cell.lines.init(mem, 4);

    if (spans.len == 0 || max_w <= 0)
    {
        WrappedCellLine first_line;
        first_line.text = "";
        first_line.display_width = 0;
        out_cell.lines.push(first_line);
        return;
    }

    buffer::ByteBuffer cur_line;
    cur_line.init(256);
    defer cur_line.free();

    int cur_w = 0;

    for (usz s = 0; s < spans.len; s++)
    {
        Span sp = spans[s];

        char* style_start = "";
        char* style_end = "";
        if (!plain)
        {
            switch (sp.kind)
            {
                case SpanKind.BOLD: style_start = (char*)ansi::BOLD; style_end = (char*)ansi::RESET;
                case SpanKind.ITALIC: style_start = (char*)ansi::ITALIC; style_end = (char*)ansi::RESET;
                case SpanKind.STRIKETHROUGH: style_start = (char*)ansi::STRIKE; style_end = (char*)ansi::RESET;
                case SpanKind.CODE_INLINE: style_start = (char*)ansi::CODE_INLINE; style_end = (char*)ansi::RESET;
                case SpanKind.MATH_INLINE: style_start = ""; style_end = "";
                case SpanKind.FOOTNOTE_REF: style_start = (char*)ansi::FG_CYAN; style_end = (char*)ansi::RESET;
                case SpanKind.LINK: style_start = (char*)ansi::FG_CYAN; style_end = (char*)ansi::RESET;
                default: style_start = ""; style_end = "";
            }
        }

        String txt = sp.text;
        usz p = 0;
        usz tlen = (usz)txt.len;

        while (p < tlen)
        {
            while (p < tlen && (txt[p] == ' ' || txt[p] == '\t')) p++;
            if (p >= tlen) break;

            usz w_start = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n') p++;
            String word = txt[w_start : p - w_start];
            int word_w = strutils::string_display_width(word);

            if (cur_w + 1 + word_w > max_w && cur_w > 0)
            {
                WrappedCellLine wl;
                wl.text = arena.dup_string(cur_line.to_string());
                wl.display_width = cur_w;
                out_cell.lines.push(wl);

                cur_line.reset();
                cur_w = 0;
            }
            else if (cur_w > 0)
            {
                cur_line.append_char(' ');
                cur_w++;
            }

            if (style_start[0] != 0) cur_line.append_zstr(style_start);
            cur_line.append_slice(word);
            if (style_end[0] != 0) cur_line.append_zstr(style_end);
            cur_w += word_w;
        }

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int url_w = strutils::string_display_width(sp.url) + 3;
            if (cur_w + 1 + url_w > max_w && cur_w > 0)
            {
                WrappedCellLine wl;
                wl.text = arena.dup_string(cur_line.to_string());
                wl.display_width = cur_w;
                out_cell.lines.push(wl);

                cur_line.reset();
                cur_w = 0;
            }
            else if (cur_w > 0)
            {
                cur_line.append_char(' ');
                cur_w++;
            }

            if (!plain) cur_line.append_zstr((char*)ansi::FG_MUTED);
            cur_line.append_char('(');
            cur_line.append_slice(sp.url);
            cur_line.append_char(')');
            if (!plain) cur_line.append_zstr((char*)ansi::RESET);
            cur_w += url_w;
        }
    }

    if (cur_line.len > 0 || out_cell.lines.size == 0)
    {
        WrappedCellLine wl;
        wl.text = arena.dup_string(cur_line.to_string());
        wl.display_width = cur_w;
        out_cell.lines.push(wl);
    }
}

fn void emit_wrapped_row(
    buffer::ByteBuffer* tb,
    WrappedCell[] wrapped_cells,
    Alignment[] alignments,
    int[] col_widths,
    int cols,
    int gap,
    bool is_header,
    bool plain,
    int src_line,
    void* ctx,
    EmitLineFn emit_fn
)
{
    int max_lines = 1;
    for (int c = 0; c < cols; c++)
    {
        if ((int)wrapped_cells[c].lines.size > max_lines)
        {
            max_lines = (int)wrapped_cells[c].lines.size;
        }
    }

    for (int l = 0; l < max_lines; l++)
    {
        tb.reset();

        for (int c = 0; c < cols; c++)
        {
            int w = col_widths[c];
            Alignment align = (c < (int)alignments.len) ? alignments[c] : Alignment.LEFT;

            if (l < (int)wrapped_cells[c].lines.size)
            {
                WrappedCellLine* line_info = &wrapped_cells[c].lines.entries[(usz)l];
                int dw = line_info.display_width;
                int pad = w - dw;
                if (pad < 0) pad = 0;

                if (is_header && !plain)
                {
                    tb.append_zstr((char*)ansi::FG_CYAN);
                    tb.append_zstr((char*)ansi::BOLD);
                }

                if (align == Alignment.CENTER)
                {
                    int lpad = pad / 2;
                    int rpad = pad - lpad;
                    tb.append_spaces(lpad);
                    tb.append_slice(line_info.text);
                    tb.append_spaces(rpad);
                }
                else if (align == Alignment.RIGHT)
                {
                    tb.append_spaces(pad);
                    tb.append_slice(line_info.text);
                }
                else // LEFT
                {
                    tb.append_slice(line_info.text);
                    tb.append_spaces(pad);
                }

                if (is_header && !plain)
                {
                    tb.append_zstr((char*)ansi::RESET);
                }
            }
            else
            {
                tb.append_spaces(w);
            }

            if (c < cols - 1) tb.append_spaces(gap);
        }

        emit_fn(ctx, tb.to_string(), src_line);
    }
}

fn void render_table(TableBlock* table, int src_line, int term_width, bool plain, void* ctx, EmitLineFn emit_fn)
{
    if (table.col_count <= 0) return;
    int cols = table.col_count;

    logic::LocalScratchScope scope = logic::enter_scratch_scope(&logic::g_ctx.scratch_arena);
    defer scope.exit();

    int* max_w_ptr = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);
    int* min_w_ptr = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);
    int* col_widths_ptr = (int*)logic::g_ctx.scratch_arena.alloc((usz)cols * int::size);

    int[] max_w = max_w_ptr[0 : (usz)cols];
    int[] min_w = min_w_ptr[0 : (usz)cols];
    int[] col_widths = col_widths_ptr[0 : (usz)cols];

    for (int c = 0; c < cols; c++)
    {
        max_w[c] = 3;
        min_w[c] = 3;
    }

    // 1. Measure header cells
    for (int c = 0; c < cols && c < (int)table.headers.len; c++)
    {
        measure_cell_metrics(table.headers[c], &min_w[c], &max_w[c]);
    }

    // 2. Measure body cells
    for (usz r = 0; r < table.rows.len; r++)
    {
        Span[][] row = table.rows[r];
        for (int c = 0; c < cols && c < (int)row.len; c++)
        {
            measure_cell_metrics(row[c], &min_w[c], &max_w[c]);
        }
    }

    for (int c = 0; c < cols; c++)
    {
        if (min_w[c] > max_w[c]) min_w[c] = max_w[c];
        if (min_w[c] < 3) min_w[c] = 3;
    }

    // 3. Compute available text width
    int gap = 2;
    int max_avail = term_width > 20 ? term_width - 2 : 80;
    int avail_budget = max_avail - (cols - 1) * gap;
    if (avail_budget < cols * 3) avail_budget = cols * 3;

    int sum_max = 0;
    int sum_min = 0;
    for (int c = 0; c < cols; c++)
    {
        sum_max += max_w[c];
        sum_min += min_w[c];
    }

    // 4. Intelligent column allocation:
    if (sum_max <= avail_budget)
    {
        // Everything fits without wrapping!
        for (int c = 0; c < cols; c++)
        {
            col_widths[c] = max_w[c];
        }
    }
    else if (sum_min <= avail_budget)
    {
        // Start by giving each column its min_w (so words don't get broken)
        for (int c = 0; c < cols; c++)
        {
            col_widths[c] = min_w[c];
        }

        int remaining_budget = avail_budget - sum_min;

        // Iteratively satisfy short columns whose full max_w can be met
        bool changed = true;
        bool* satisfied_ptr = (bool*)logic::g_ctx.scratch_arena.alloc((usz)cols * bool::size);
        bool[] satisfied = satisfied_ptr[0 : (usz)cols];
        for (int c = 0; c < cols; c++) satisfied[c] = (col_widths[c] >= max_w[c]);

        while (changed && remaining_budget > 0)
        {
            changed = false;
            int best_c = -1;
            int min_need = 999999;
            for (int c = 0; c < cols; c++)
            {
                if (!satisfied[c])
                {
                    int need = max_w[c] - col_widths[c];
                    if (need > 0 && need < min_need)
                    {
                        min_need = need;
                        best_c = c;
                    }
                }
            }

            if (best_c >= 0 && min_need <= remaining_budget)
            {
                col_widths[best_c] += min_need;
                remaining_budget -= min_need;
                satisfied[best_c] = true;
                changed = true;
            }
        }

        // If there is still budget left, distribute it proportionally among remaining columns
        if (remaining_budget > 0)
        {
            int sum_unsatisfied_need = 0;
            for (int c = 0; c < cols; c++)
            {
                if (!satisfied[c])
                {
                    sum_unsatisfied_need += (max_w[c] - col_widths[c]);
                }
            }

            if (sum_unsatisfied_need > 0)
            {
                int allocated = 0;
                for (int c = 0; c < cols; c++)
                {
                    if (!satisfied[c])
                    {
                        int need = max_w[c] - col_widths[c];
                        int add = (remaining_budget * need) / sum_unsatisfied_need;
                        col_widths[c] += add;
                        allocated += add;
                    }
                }

                int rem = remaining_budget - allocated;
                while (rem > 0)
                {
                    int best_c = -1;
                    int best_need = 0;
                    for (int c = 0; c < cols; c++)
                    {
                        int need = max_w[c] - col_widths[c];
                        if (need > best_need)
                        {
                            best_need = need;
                            best_c = c;
                        }
                    }
                    if (best_c >= 0)
                    {
                        col_widths[best_c]++;
                        rem--;
                    }
                    else
                    {
                        break;
                    }
                }
            }
        }
    }
    else
    {
        // Extremely narrow terminal: scale min_w down proportionally
        int distributed = 0;
        for (int c = 0; c < cols; c++)
        {
            if (sum_min > 0)
            {
                col_widths[c] = (min_w[c] * avail_budget) / sum_min;
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

    // 5. Wrap header row
    bool any_wrapped = false;
    WrappedCell* hcells = (WrappedCell*)logic::g_ctx.scratch_arena.alloc((usz)cols * WrappedCell::size);
    for (int c = 0; c < cols; c++)
    {
        Span[] hspans = (c < (int)table.headers.len) ? table.headers[c] : {};
        wrap_cell(&logic::g_ctx.scratch_arena, hspans, col_widths[c], plain, &hcells[c]);
        if (hcells[c].lines.size > 1) any_wrapped = true;
    }

    // 6. Wrap all body rows and detect if any row wrapped
    usz num_rows = table.rows.len;
    WrappedCell[]* all_body_rows = (WrappedCell[]*)logic::g_ctx.scratch_arena.alloc(num_rows * WrappedCell[]::size);

    for (usz r = 0; r < num_rows; r++)
    {
        Span[][] row = table.rows[r];
        WrappedCell* rcells = (WrappedCell*)logic::g_ctx.scratch_arena.alloc((usz)cols * WrappedCell::size);
        for (int c = 0; c < cols; c++)
        {
            Span[] cspans = (c < (int)row.len) ? row[c] : {};
            wrap_cell(&logic::g_ctx.scratch_arena, cspans, col_widths[c], plain, &rcells[c]);
            if (rcells[c].lines.size > 1) any_wrapped = true;
        }
        all_body_rows[r] = rcells[0 : (usz)cols];
    }

    // 7. Emit header row
    emit_wrapped_row(&tb, hcells[0 : (usz)cols], table.alignments, col_widths, cols, gap, true, plain, src_line, ctx, emit_fn);
    for (int c = 0; c < cols; c++) hcells[c].lines.free();

    // 8. Separator line under header
    tb.reset();
    if (!plain) tb.append_zstr((char*)ansi::FG_MUTED);
    for (int c = 0; c < cols; c++)
    {
        tb.append_repeat("─", col_widths[c]);
        if (c < cols - 1) tb.append_spaces(gap);
    }
    if (!plain) tb.append_zstr((char*)ansi::RESET);
    emit_fn(ctx, tb.to_string(), src_line + 1);

    // 9. Emit body rows (with 1 blank line between rows ONLY if at least one row wrapped)
    for (usz r = 0; r < num_rows; r++)
    {
        WrappedCell[] rcells = all_body_rows[r];
        emit_wrapped_row(&tb, rcells, table.alignments, col_widths, cols, gap, false, plain, src_line + 2 + (int)r, ctx, emit_fn);
        for (int c = 0; c < cols; c++) rcells[c].lines.free();

        if (any_wrapped && r + 1 < num_rows)
        {
            emit_fn(ctx, "", src_line + 2 + (int)r);
        }
    }
}
