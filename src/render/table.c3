module render;

import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import text;

const int GAP = 2;

fn bool blankChar(char c) => c == ' ' || c == '\t';

fn void measure(Span[] list, int* least, int* most)
{
    if (list.len == 0) return;
    int total;
    int word;
    foreach (s : list)
    {
        String t = s.text;
        sz p;
        while (p < t.len)
        {
            while (p < t.len && blankChar(t[p])) p++;
            if (p >= t.len) break;
            sz start = p;
            while (p < t.len && !blankChar(t[p]) && t[p] != '\n') p++;
            word = max(word, text::width(t[start : p - start]));
        }
        total += text::width(t);
        if (s.kind == SpanKind.LINK && s.url.len > 0)
        {
            int u = text::width(s.url) + 3;
            word = max(word, u);
            total += u;
        }
    }
    *most = max(*most, total);
    *least = max(*least, word);
}

fn void grow(int[] widths, int[] least, int[] most, bool[] done, int budget)
{
    int cols = (int)widths.len;
    int sumMost;
    int sumLeast;
    for (int c = 0; c < cols; c++)
    {
        sumMost += most[c];
        sumLeast += least[c];
    }
    if (sumMost <= budget)
    {
        widths[..] = most[..];
        return;
    }
    if (sumLeast > budget)
    {
        int given;
        for (int c = 0; c < cols; c++)
        {
            widths[c] = max(sumLeast > 0 ? least[c] * budget / sumLeast : budget / cols, 3);
            given += widths[c];
        }
        if (widths[cols - 1] + budget - given >= 3) widths[cols - 1] += budget - given;
        return;
    }
    widths[..] = least[..];
    int left = budget - sumLeast;
    for (int c = 0; c < cols; c++) done[c] = widths[c] >= most[c];
    while (left > 0)
    {
        int best = -1;
        int need = 999999;
        for (int c = 0; c < cols; c++)
        {
            int n = most[c] - widths[c];
            if (!done[c] && n > 0 && n < need)
            {
                need = n;
                best = c;
            }
        }
        if (best < 0 || need > left) break;
        widths[best] += need;
        left -= need;
        done[best] = true;
    }
    if (left <= 0) return;
    int open;
    for (int c = 0; c < cols; c++) if (!done[c]) open += most[c] - widths[c];
    if (open <= 0) return;
    int given;
    for (int c = 0; c < cols; c++)
    {
        if (done[c]) continue;
        int add = left * (most[c] - widths[c]) / open;
        widths[c] += add;
        given += add;
    }
    for (int rem = left - given; rem > 0; rem--)
    {
        int best = -1;
        int need;
        for (int c = 0; c < cols; c++)
        {
            if (most[c] - widths[c] > need)
            {
                need = most[c] - widths[c];
                best = c;
            }
        }
        if (best < 0) break;
        widths[best]++;
    }
}

struct Cell
{
    List{Piece} lines;
}

fn void Cell.fill(&self, ast::Arena* arena, Span[] list, int width, bool plain)
{
    self.lines.init(mem, 4);
    if (width <= 0)
    {
        self.lines.push({ "", 0 });
        return;
    }
    wrap(&self.lines, arena, list, width, "", "", plain, true);
}

fn void Renderer.row(&self, Cell[] cells, Alignment[] aligns, int[] widths, bool header, int src)
{
    int height = 1;
    foreach (&c : cells) height = max(height, (int)c.lines.len());
    bool bold = header && !self.config.plain;
    for (int l = 0; l < height; l++)
    {
        foreach (c, &cell : cells)
        {
            int w = widths[c];
            if (l >= cell.lines.len())
            {
                self.buf.spaces(w);
            }
            else
            {
                Piece piece = cell.lines[l];
                int pad = max(w - piece.width, 0);
                Alignment align = c < aligns.len ? aligns[c] : LEFT;
                int before = align == CENTER ? pad / 2 : align == RIGHT ? pad : 0;
                if (bold) self.buf.append(ansi::style(NOTE));
                self.buf.spaces(before);
                self.buf.append(piece.text);
                self.buf.spaces(pad - before);
                if (bold) self.buf.append(ansi::RESET);
            }
            if (c < cells.len - 1) self.buf.spaces(GAP);
        }
        self.flush(src);
    }
}

fn void Renderer.table(&self, ast::Table* t, int src)
{
    int cols = t.columns;
    if (cols <= 0) return;
    ast::Arena scratch;
    scratch.init(32768);
    defer scratch.free();
    int* most = scratch.alloc((usz)cols * int::size);
    int* least = scratch.alloc((usz)cols * int::size);
    int* widths = scratch.alloc((usz)cols * int::size);
    for (int c = 0; c < cols; c++)
    {
        most[c] = 3;
        least[c] = 3;
    }
    for (int c = 0; c < cols && c < t.headers.len; c++) measure(t.headers[c], &least[c], &most[c]);
    foreach (row : t.rows)
    {
        for (int c = 0; c < cols && c < row.len; c++) measure(row[c], &least[c], &most[c]);
    }
    for (int c = 0; c < cols; c++) least[c] = max(min(least[c], most[c]), 3);
    int avail = self.width > 20 ? self.width - 2 : 80;
    bool* done = scratch.alloc((usz)cols * bool::size);
    grow(widths[:cols], least[:cols], most[:cols], done[:cols], max(avail - (cols - 1) * GAP, cols * 3));

    bool plain = self.config.plain;
    int count = (int)t.rows.len + 1;
    Cell* cells = scratch.alloc((usz)(count * cols) * Cell::size);
    bool wrapped;
    for (int r = 0; r < count; r++)
    {
        Span[][] row = r == 0 ? t.headers : t.rows[r - 1];
        for (int c = 0; c < cols; c++)
        {
            Cell* cell = &cells[r * cols + c];
            cell.fill(&scratch, c < row.len ? row[c] : {}, widths[c], plain);
            wrapped = wrapped || cell.lines.len() > 1;
        }
    }
    self.row(cells[:cols], t.aligns, widths[:cols], true, src);
    if (!plain) self.buf.append(ansi::style(MUTED));
    for (int c = 0; c < cols; c++)
    {
        self.buf.repeat("─", widths[c]);
        if (c < cols - 1) self.buf.spaces(GAP);
    }
    if (!plain) self.buf.append(ansi::RESET);
    self.flush(src + 1);
    for (int r = 1; r < count; r++)
    {
        int line = src + 1 + r;
        self.row(cells[r * cols : cols], t.aligns, widths[:cols], false, line);
        if (wrapped && r + 1 < count) self.emit("", line);
    }
    for (int i = 0; i < count * cols; i++) cells[i].lines.free();
}
