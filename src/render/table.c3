module render;

import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import text;

alias EmitLineFn = fn void(void* ctx, String text, int srcLine);

struct WrappedCellLine {
    String text;
    int displayWidth;
}

struct WrappedCell {
    List{WrappedCellLine} lines;
}

fn void measure(Span[] spans, int* outMinW, int* outMaxW)
{
    if (spans.len == 0) return;
    int totalW = 0;
    int maxWordW = 0;

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

            usz wStart = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n') p++;
            String word = txt[wStart : p - wStart];
            int ww = text::width(word);
            if (ww > maxWordW) maxWordW = ww;
        }

        int sw = text::width(txt);
        totalW += sw;

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int uw = text::width(sp.url) + 3;
            if (uw > maxWordW) maxWordW = uw;
            totalW += uw;
        }
    }

    if (totalW > *outMaxW) *outMaxW = totalW;
    if (maxWordW > *outMinW) *outMinW = maxWordW;
}

fn void wrapCell(ast::Arena* arena, Span[] spans, int maxW, bool plain, WrappedCell* outCell)
{
    outCell.lines.init(mem, 4);

    if (spans.len == 0 || maxW <= 0)
    {
        WrappedCellLine firstLine;
        firstLine.text = "";
        firstLine.displayWidth = 0;
        outCell.lines.push(firstLine);
        return;
    }

    DString curLine;
    curLine.init(mem, 256);
    defer curLine.free();

    int curW = 0;

    for (usz s = 0; s < spans.len; s++)
    {
        Span sp = spans[s];

        String style = plain ? "" : STYLES[sp.kind];

        String txt = sp.text;
        usz p = 0;
        usz tlen = (usz)txt.len;

        while (p < tlen)
        {
            while (p < tlen && (txt[p] == ' ' || txt[p] == '\t')) p++;
            if (p >= tlen) break;

            usz wStart = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n') p++;
            String word = txt[wStart : p - wStart];
            int wordW = text::width(word);

            if (curW + 1 + wordW > maxW && curW > 0)
            {
                WrappedCellLine wl;
                wl.text = arena.copy(curLine.str_view());
                wl.displayWidth = curW;
                outCell.lines.push(wl);

                curLine.clear();
                curW = 0;
            }
            else if (curW > 0)
            {
                curLine.append_char(' ');
                curW++;
            }

            curLine.append(style);
            curLine.append(word);
            if (style.len) curLine.append(ansi::RESET);
            curW += wordW;
        }

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int urlW = text::width(sp.url) + 3;
            if (curW + 1 + urlW > maxW && curW > 0)
            {
                WrappedCellLine wl;
                wl.text = arena.copy(curLine.str_view());
                wl.displayWidth = curW;
                outCell.lines.push(wl);

                curLine.clear();
                curW = 0;
            }
            else if (curW > 0)
            {
                curLine.append_char(' ');
                curW++;
            }

            if (!plain) curLine.append(ansi::MUTED);
            curLine.append_char('(');
            curLine.append_string(sp.url);
            curLine.append_char(')');
            if (!plain) curLine.append(ansi::RESET);
            curW += urlW;
        }
    }

    if (curLine.len() > 0 || outCell.lines.size == 0)
    {
        WrappedCellLine wl;
        wl.text = arena.copy(curLine.str_view());
        wl.displayWidth = curW;
        outCell.lines.push(wl);
    }
}

fn void emitRow(
    DString* tb,
    WrappedCell[] wrappedCells,
    Alignment[] alignments,
    int[] colWidths,
    int cols,
    int gap,
    bool isHeader,
    bool plain,
    int srcLine,
    void* ctx,
    EmitLineFn emitFn
)
{
    int maxLines = 1;
    for (int c = 0; c < cols; c++)
    {
        if ((int)wrappedCells[c].lines.size > maxLines)
        {
            maxLines = (int)wrappedCells[c].lines.size;
        }
    }

    for (int l = 0; l < maxLines; l++)
    {
        tb.clear();

        for (int c = 0; c < cols; c++)
        {
            int w = colWidths[c];
            Alignment align = (c < (int)alignments.len) ? alignments[c] : Alignment.LEFT;

            if (l < (int)wrappedCells[c].lines.size)
            {
                WrappedCellLine* lineInfo = &wrappedCells[c].lines.entries[(usz)l];
                int dw = lineInfo.displayWidth;
                int pad = w - dw;
                if (pad < 0) pad = 0;

                if (isHeader && !plain)
                {
                    tb.append(ansi::CYAN);
                    tb.append(ansi::BOLD);
                }

                if (align == Alignment.CENTER)
                {
                    int lpad = pad / 2;
                    int rpad = pad - lpad;
                    tb.spaces(lpad);
                    tb.append_string(lineInfo.text);
                    tb.spaces(rpad);
                }
                else if (align == Alignment.RIGHT)
                {
                    tb.spaces(pad);
                    tb.append_string(lineInfo.text);
                }
                else
                {
                    tb.append_string(lineInfo.text);
                    tb.spaces(pad);
                }

                if (isHeader && !plain)
                {
                    tb.append(ansi::RESET);
                }
            }
            else
            {
                tb.spaces(w);
            }

            if (c < cols - 1) tb.spaces(gap);
        }

        emitFn(ctx, tb.str_view(), srcLine);
    }
}

fn void table(TableBlock* table, int srcLine, int termWidth, bool plain, void* ctx, EmitLineFn emitFn)
{
    if (table.colCount <= 0) return;
    int cols = table.colCount;

    ast::Arena scratch;
    scratch.init(32768);
    defer scratch.free();

    int* maxWPtr = (int*)scratch.alloc((usz)cols * int::size);
    int* minWPtr = (int*)scratch.alloc((usz)cols * int::size);
    int* colWidthsPtr = (int*)scratch.alloc((usz)cols * int::size);

    int[] maxW = maxWPtr[0 : (usz)cols];
    int[] minW = minWPtr[0 : (usz)cols];
    int[] colWidths = colWidthsPtr[0 : (usz)cols];

    for (int c = 0; c < cols; c++)
    {
        maxW[c] = 3;
        minW[c] = 3;
    }

    for (int c = 0; c < cols && c < (int)table.headers.len; c++)
    {
        measure(table.headers[c], &minW[c], &maxW[c]);
    }

    for (usz r = 0; r < table.rows.len; r++)
    {
        Span[][] row = table.rows[r];
        for (int c = 0; c < cols && c < (int)row.len; c++)
        {
            measure(row[c], &minW[c], &maxW[c]);
        }
    }

    for (int c = 0; c < cols; c++)
    {
        if (minW[c] > maxW[c]) minW[c] = maxW[c];
        if (minW[c] < 3) minW[c] = 3;
    }

    int gap = 2;
    int maxAvail = termWidth > 20 ? termWidth - 2 : 80;
    int availBudget = maxAvail - (cols - 1) * gap;
    if (availBudget < cols * 3) availBudget = cols * 3;

    int sumMax = 0;
    int sumMin = 0;
    for (int c = 0; c < cols; c++)
    {
        sumMax += maxW[c];
        sumMin += minW[c];
    }

    if (sumMax <= availBudget)
    {
        for (int c = 0; c < cols; c++)
        {
            colWidths[c] = maxW[c];
        }
    }
    else if (sumMin <= availBudget)
    {
        for (int c = 0; c < cols; c++)
        {
            colWidths[c] = minW[c];
        }

        int remainingBudget = availBudget - sumMin;

        bool changed = true;
        bool* satisfiedPtr = (bool*)scratch.alloc((usz)cols * bool::size);
        bool[] satisfied = satisfiedPtr[0 : (usz)cols];
        for (int c = 0; c < cols; c++) satisfied[c] = (colWidths[c] >= maxW[c]);

        while (changed && remainingBudget > 0)
        {
            changed = false;
            int bestC = -1;
            int minNeed = 999999;
            for (int c = 0; c < cols; c++)
            {
                if (!satisfied[c])
                {
                    int need = maxW[c] - colWidths[c];
                    if (need > 0 && need < minNeed)
                    {
                        minNeed = need;
                        bestC = c;
                    }
                }
            }

            if (bestC >= 0 && minNeed <= remainingBudget)
            {
                colWidths[bestC] += minNeed;
                remainingBudget -= minNeed;
                satisfied[bestC] = true;
                changed = true;
            }
        }

        if (remainingBudget > 0)
        {
            int sumUnsatisfiedNeed = 0;
            for (int c = 0; c < cols; c++)
            {
                if (!satisfied[c])
                {
                    sumUnsatisfiedNeed += (maxW[c] - colWidths[c]);
                }
            }

            if (sumUnsatisfiedNeed > 0)
            {
                int allocated = 0;
                for (int c = 0; c < cols; c++)
                {
                    if (!satisfied[c])
                    {
                        int need = maxW[c] - colWidths[c];
                        int add = (remainingBudget * need) / sumUnsatisfiedNeed;
                        colWidths[c] += add;
                        allocated += add;
                    }
                }

                int rem = remainingBudget - allocated;
                while (rem > 0)
                {
                    int bestC = -1;
                    int bestNeed = 0;
                    for (int c = 0; c < cols; c++)
                    {
                        int need = maxW[c] - colWidths[c];
                        if (need > bestNeed)
                        {
                            bestNeed = need;
                            bestC = c;
                        }
                    }
                    if (bestC >= 0)
                    {
                        colWidths[bestC]++;
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
        int distributed = 0;
        for (int c = 0; c < cols; c++)
        {
            if (sumMin > 0)
            {
                colWidths[c] = (minW[c] * availBudget) / sumMin;
            }
            else
            {
                colWidths[c] = availBudget / cols;
            }
            if (colWidths[c] < 3) colWidths[c] = 3;
            distributed += colWidths[c];
        }
        int diff = availBudget - distributed;
        if (cols > 0 && colWidths[cols - 1] + diff >= 3)
        {
            colWidths[cols - 1] += diff;
        }
    }

    DString tb;
    tb.init(mem, 4096);
    defer tb.free();

    bool anyWrapped = false;
    WrappedCell* hcells = (WrappedCell*)scratch.alloc((usz)cols * WrappedCell::size);
    for (int c = 0; c < cols; c++)
    {
        Span[] hspans = (c < (int)table.headers.len) ? table.headers[c] : {};
        wrapCell(&scratch, hspans, colWidths[c], plain, &hcells[c]);
        if (hcells[c].lines.size > 1) anyWrapped = true;
    }

    usz numRows = table.rows.len;
    WrappedCell[]* allBodyRows = (WrappedCell[]*)scratch.alloc(numRows * WrappedCell[]::size);

    for (usz r = 0; r < numRows; r++)
    {
        Span[][] row = table.rows[r];
        WrappedCell* rcells = (WrappedCell*)scratch.alloc((usz)cols * WrappedCell::size);
        for (int c = 0; c < cols; c++)
        {
            Span[] cspans = (c < (int)row.len) ? row[c] : {};
            wrapCell(&scratch, cspans, colWidths[c], plain, &rcells[c]);
            if (rcells[c].lines.size > 1) anyWrapped = true;
        }
        allBodyRows[r] = rcells[0 : (usz)cols];
    }

    emitRow(&tb, hcells[0 : (usz)cols], table.alignments, colWidths, cols, gap, true, plain, srcLine, ctx, emitFn);
    for (int c = 0; c < cols; c++) hcells[c].lines.free();

    tb.clear();
    if (!plain) tb.append(ansi::MUTED);
    for (int c = 0; c < cols; c++)
    {
        tb.repeat("─", colWidths[c]);
        if (c < cols - 1) tb.spaces(gap);
    }
    if (!plain) tb.append(ansi::RESET);
    emitFn(ctx, tb.str_view(), srcLine + 1);

    for (usz r = 0; r < numRows; r++)
    {
        WrappedCell[] rcells = allBodyRows[r];
        emitRow(&tb, rcells, table.alignments, colWidths, cols, gap, false, plain, srcLine + 2 + (int)r, ctx, emitFn);
        for (int c = 0; c < cols; c++) rcells[c].lines.free();

        if (anyWrapped && r + 1 < numRows)
        {
            emitFn(ctx, "", srcLine + 2 + (int)r);
        }
    }
}
