module tex;

import std::core::mem;
import ast;
import text;

fn MathBox blank(ast::Arena* arena)
{
    MathBox box;
    box.width = 0;
    box.height = 1;
    box.baseline = 0;
    String* r = (String*)arena.alloc(String::size);
    r[0] = "";
    box.rows = r[0:1];
    return box;
}

fn MathBox atom(ast::Arena* arena, String text)
{
    MathBox box;
    box.width = text::width(text);
    box.height = 1;
    box.baseline = 0;
    String* r = (String*)arena.alloc(String::size);
    r[0] = arena.copy(text);
    box.rows = r[0:1];
    return box;
}

fn MathBox letter(ast::Arena* arena, char c)
{
    if (c == 0) return blank(arena);
    char[1] one = { c };
    return atom(arena, (String)one[..]);
}

fn MathBox gap(ast::Arena* arena, int count)
{
    if (count <= 0) return blank(arena);
    DString mb;
    mb.init(mem, (usz)(count + 1));
    defer mb.free();
    mb.spaces(count);

    MathBox box;
    box.width = count;
    box.height = 1;
    box.baseline = 0;
    String* r = (String*)arena.alloc(String::size);
    r[0] = mb.keep(arena);
    box.rows = r[0:1];
    return box;
}

fn MathBox beside(ast::Arena* arena, MathBox left, MathBox right, int gap = 0)
{
    if (left.width == 0 && left.height == 1 && left.rows[0].len == 0) return right;
    if (right.width == 0 && right.height == 1 && right.rows[0].len == 0) return left;

    int above = left.baseline > right.baseline ? left.baseline : right.baseline;
    int leftBelow = left.height - 1 - left.baseline;
    int rightBelow = right.height - 1 - right.baseline;
    int below = leftBelow > rightBelow ? leftBelow : rightBelow;

    int newH = above + 1 + below;
    int newBase = above;
    int newW = left.width + gap + right.width;

    String* rBuf = (String*)arena.alloc((usz)newH * String::size);

    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    for (int r = 0; r < newH; r++)
    {
        mb.clear();

        int lr = r - (above - left.baseline);
        if (lr >= 0 && lr < left.height)
        {
            mb.append_string(left.rows[lr]);
            int rowW = text::width(left.rows[lr]);
            int pad = left.width - rowW;
            if (pad > 0) mb.spaces(pad);
        }
        else
        {
            mb.spaces(left.width);
        }

        if (gap > 0) mb.spaces(gap);

        int rr = r - (above - right.baseline);
        if (rr >= 0 && rr < right.height)
        {
            mb.append_string(right.rows[rr]);
            int rowW = text::width(right.rows[rr]);
            int pad = right.width - rowW;
            if (pad > 0) mb.spaces(pad);
        }
        else
        {
            mb.spaces(right.width);
        }

        rBuf[r] = mb.keep(arena);
    }

    MathBox res;
    res.width = newW;
    res.height = newH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)newH];
    return res;
}

fn MathBox fraction(ast::Arena* arena, MathBox num, MathBox den)
{
    int w = max(num.width, den.width) + 2;
    return column(arena, { num, rule(arena, "─", w), den }, w, num.height);
}

fn MathBox root(ast::Arena* arena, MathBox inner, MathBox degree)
{
    int h = inner.height;
    int d = degree.width;
    String mark = d > 0 ? degree.rows[0] : "";
    String* rows = arena.alloc((usz)(h + 1) * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();
    if (h == 1 && (d == 0 || (degree.height == 1 && SUPER.fits(mark))))
    {
        String r = inner.rows[0].trim();
        bool wrap = operated(r) && (r[0] != '(' || r[^1] != ')');
        if (d > 0) mb.append(SUPER.apply(arena, mark));
        mb.append("√");
        if (wrap) mb.append_char('(');
        mb.append(r);
        if (wrap) mb.append_char(')');
        return atom(arena, mb.str_view());
    }
    if (h == 1)
    {
        mb.append(mark);
        mb.append(" ┌");
        mb.repeat("─", inner.width);
        rows[0] = mb.keep(arena);
        mb.clear();
        mb.spaces(d);
        mb.append("√ ");
        mb.append(inner.rows[0]);
        mb.spaces(inner.width - text::width(inner.rows[0]));
        rows[1] = mb.keep(arena);
        return { d + 2 + inner.width, 2, inner.baseline + 1, rows[:2] };
    }
    mb.spaces(d + 1);
    mb.append("┌");
    mb.repeat("─", inner.width);
    rows[0] = mb.keep(arena);
    for (int r = 0; r < h; r++)
    {
        mb.clear();
        if (r == h - 2)
        {
            mb.append(mark);
        }
        else
        {
            mb.spaces(d);
        }
        mb.append(r == h - 1 ? "╲│" : " │");
        mb.append(inner.rows[r]);
        mb.spaces(inner.width - text::width(inner.rows[r]));
        rows[r + 1] = mb.keep(arena);
    }
    return { d + 2 + inner.width, h + 1, inner.baseline + 1, rows[:h + 1] };
}

fn MathBox present(MathBox b)
{
    return b.width > 0 ? b : (MathBox){};
}

fn MathBox rule(ast::Arena* arena, String glyph, int count)
{
    DString mb;
    mb.init(mem, 64);
    defer mb.free();
    mb.repeat(glyph, count);
    return atom(arena, mb.str_view());
}

fn MathBox column(ast::Arena* arena, MathBox[] parts, int width, int baseline)
{
    int height;
    foreach (b : parts) height += b.height;
    String* rows = arena.alloc((usz)max(height, 1) * String::size);
    int r;
    foreach (b : parts)
    {
        for (int i = 0; i < b.height; i++) rows[r++] = centered(arena, b.rows[i], width);
    }
    return { width, height, baseline, rows[:height] };
}

fn String centered(ast::Arena* arena, String row, int width)
{
    DString mb;
    mb.init(mem, 512);
    defer mb.free();
    int w = text::width(row);
    int pad = (width - w) / 2;
    mb.spaces(pad);
    mb.append(row);
    mb.spaces(width - w - pad);
    return mb.keep(arena);
}

fn MathBox bigop(ast::Arena* arena, MathBox sub, MathBox sup, String glyph)
{
    DString mb;
    mb.init(mem, 16);
    defer mb.free();
    mb.append(" ");
    mb.append(glyph);
    mb.append(" ");
    MathBox op = atom(arena, mb.str_view());
    int supH = sup.width > 0 ? sup.height : 0;
    return column(arena, { present(sup), op, present(sub) }, max(op.width, sub.width, sup.width), supH);
}

fn MathBox limits(ast::Arena* arena, MathBox op, MathBox sub, MathBox sup)
{
    int supH = sup.width > 0 ? sup.height : 0;
    return column(arena, { present(sup), op, present(sub) }, max(op.width, sub.width, sup.width), supH + op.baseline);
}

fn bool flat(MathBox base, MathBox sup, MathBox sub)
{
    if (base.height != 1 || sup.height > 1 || sub.height > 1) return false;
    return (sup.width == 0 || SUPER.fits(sup.rows[0])) && (sub.width == 0 || SUB.fits(sub.rows[0]));
}

fn MathBox scripts(ast::Arena* arena, MathBox base, MathBox sup, MathBox sub, bool raise = false)
{
    if (sup.width == 0 && sub.width == 0) return base;
    if (!raise && flat(base, sup, sub))
    {
        DString mb;
        mb.init(mem, 128);
        defer mb.free();
        mb.append(base.rows[0]);
        if (sub.width > 0) mb.append(SUB.apply(arena, sub.rows[0]));
        if (sup.width > 0) mb.append(SUPER.apply(arena, sup.rows[0]));
        return atom(arena, mb.str_view());
    }

    int scriptW = sup.width > sub.width ? sup.width : sub.width;
    int supH = sup.width > 0 ? sup.height : 0;
    int subH = sub.width > 0 ? sub.height : 0;

    int totalH = supH + base.height + subH;
    int newBase = supH + base.baseline;
    int newW = base.width + scriptW;

    String* rBuf = (String*)arena.alloc((usz)totalH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    int curR = 0;

    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.clear();
            mb.spaces(base.width);
            mb.append_string(sup.rows[r]);
            int rw = text::width(sup.rows[r]);
            int pad = scriptW - rw;
            if (pad > 0) mb.spaces(pad);
            rBuf[curR++] = mb.keep(arena);
        }
    }

    for (int r = 0; r < base.height; r++)
    {
        mb.clear();
        mb.append_string(base.rows[r]);
        int rw = text::width(base.rows[r]);
        int pad = base.width - rw;
        if (pad > 0) mb.spaces(pad);
        mb.spaces(scriptW);
        rBuf[curR++] = mb.keep(arena);
    }

    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.clear();
            mb.spaces(base.width);
            mb.append_string(sub.rows[r]);
            int rw = text::width(sub.rows[r]);
            int pad = scriptW - rw;
            if (pad > 0) mb.spaces(pad);
            rBuf[curR++] = mb.keep(arena);
        }
    }

    MathBox res;
    res.width = newW;
    res.height = totalH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)totalH];
    return res;
}

fn MathBox xarrow(ast::Arena* arena, MathBox sup, MathBox sub, char arrowDir = 'R')
{
    int w = max(max(sup.width, sub.width) + 4, 6);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();
    if (arrowDir != 'R') mb.append("←");
    mb.repeat("─", w - (arrowDir == 'R' || arrowDir == 'L' ? 1 : 2));
    if (arrowDir != 'L') mb.append("→");
    MathBox arrow = atom(arena, mb.str_view());
    return column(arena, { present(sup), arrow, present(sub) }, w, sup.width > 0 ? sup.height : 0);
}

fn MathBox underline(ast::Arena* arena, MathBox inner)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int newH = inner.height + 1;
    int newBase = inner.baseline;

    String* rBuf = (String*)arena.alloc((usz)newH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        rBuf[r] = inner.rows[r];
    }

    mb.clear();
    mb.repeat("─", w);
    rBuf[inner.height] = mb.keep(arena);

    MathBox res;
    res.width = w;
    res.height = newH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)newH];
    return res;
}

fn MathBox overarrow(ast::Arena* arena, MathBox inner, bool rightDir = true)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int newH = inner.height + 1;
    int newBase = inner.baseline + 1;

    String* rBuf = (String*)arena.alloc((usz)newH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    mb.clear();
    if (rightDir)
    {
        if (w > 1) mb.repeat("─", w - 1);
        mb.append("→");
    }
    else
    {
        mb.append("←");
        if (w > 1) mb.repeat("─", w - 1);
    }
    rBuf[0] = mb.keep(arena);

    for (int r = 0; r < inner.height; r++)
    {
        rBuf[r + 1] = inner.rows[r];
    }

    MathBox res;
    res.width = w;
    res.height = newH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)newH];
    return res;
}

fn MathBox cancel(ast::Arena* arena, MathBox inner)
{
    if (inner.height == 0) return inner;
    String* rBuf = (String*)arena.alloc((usz)inner.height * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        mb.clear();
        String row = inner.rows[r];
        for (usz i = 0; i < (usz)row.len; i++)
        {
            mb.append_char(row[i]);
            if (row[i] != ' ')
            {
                mb.append("̸");
            }
        }
        rBuf[r] = mb.keep(arena);
    }

    MathBox res;
    res.width = inner.width;
    res.height = inner.height;
    res.baseline = inner.baseline;
    res.rows = rBuf[0 : (usz)inner.height];
    return res;
}

fn MathBox colorize(ast::Arena* arena, MathBox inner, String color)
{
    if (inner.height == 0) return inner;
    String* rBuf = (String*)arena.alloc((usz)inner.height * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        mb.clear();
        mb.append(color);
        mb.append_string(inner.rows[r]);
        mb.append("\x1b[0m\x1b[38;2;255;216;102m\x1b[1m");
        rBuf[r] = mb.keep(arena);
    }

    MathBox res;
    res.width = inner.width;
    res.height = inner.height;
    res.baseline = inner.baseline;
    res.rows = rBuf[0 : (usz)inner.height];
    return res;
}

fn MathBox delimit(ast::Arena* arena, MathBox inner, char openCh, char closeCh)
{
    if (inner.height <= 1)
    {
        MathBox lBox = letter(arena, openCh == 'F' ? 0 : openCh);
        MathBox rBox = letter(arena, closeCh == 'F' ? 0 : closeCh);
        MathBox mid = (openCh != 0) ? beside(arena, lBox, inner, 1) : inner;
        return (closeCh != 0) ? beside(arena, mid, rBox, 1) : mid;
    }

    int h = inner.height;
    int lPad = (openCh != 0) ? 2 : 0;
    int rPad = (closeCh != 0) ? 2 : 0;
    int newW = inner.width + lPad + rPad;

    String* rBuf = (String*)arena.alloc((usz)h * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    for (int r = 0; r < h; r++)
    {
        mb.clear();

        if (openCh == '(')
        {
            if (r == 0) { mb.append("⎛ "); }
            else if (r == h - 1) { mb.append("⎝ "); }
            else { mb.append("⎜ "); }
        }
        else if (openCh == '[')
        {
            if (r == 0) { mb.append("⎡ "); }
            else if (r == h - 1) { mb.append("⎣ "); }
            else { mb.append("⎢ "); }
        }
        else if (openCh == '{')
        {
            if (r == 0) { mb.append("⎧ "); }
            else if (r == h - 1) { mb.append("⎩ "); }
            else if (r == h / 2) { mb.append("⎨ "); }
            else { mb.append("⎪ "); }
        }
        else if (openCh == 'F')
        {
            if (r == h - 1) { mb.append("⎣ "); }
            else { mb.append("⎢ "); }
        }
        else if (openCh == 'C')
        {
            if (r == 0) { mb.append("⎡ "); }
            else { mb.append("⎢ "); }
        }
        else if (openCh == '<')
        {
            if (r == 0 || r == h - 1) { mb.append("⟨ "); }
            else { mb.append("│ "); }
        }
        else if (openCh == '|')
        {
            mb.append("│ ");
        }
        else if (openCh == 'V')
        {
            mb.append("║ ");
        }
        else if (openCh != 0)
        {
            mb.append_char(openCh);
            mb.append_char(' ');
        }

        mb.append_string(inner.rows[r]);
        int rowW = text::width(inner.rows[r]);
        int pad = inner.width - rowW;
        if (pad > 0) mb.spaces(pad);

        if (closeCh == ')')
        {
            if (r == 0) { mb.append(" ⎞"); }
            else if (r == h - 1) { mb.append(" ⎠"); }
            else { mb.append(" ⎟"); }
        }
        else if (closeCh == ']')
        {
            if (r == 0) { mb.append(" ⎤"); }
            else if (r == h - 1) { mb.append(" ⎦"); }
            else { mb.append(" ⎥"); }
        }
        else if (closeCh == '}')
        {
            if (r == 0) { mb.append(" ⎫"); }
            else if (r == h - 1) { mb.append(" ⎭"); }
            else if (r == h / 2) { mb.append(" ⎬"); }
            else { mb.append(" ⎪"); }
        }
        else if (closeCh == 'F')
        {
            if (r == h - 1) { mb.append(" ⎦"); }
            else { mb.append(" ⎥"); }
        }
        else if (closeCh == 'C')
        {
            if (r == 0) { mb.append(" ⎤"); }
            else { mb.append(" ⎥"); }
        }
        else if (closeCh == '>')
        {
            if (r == 0 || r == h - 1) { mb.append(" ⟩"); }
            else { mb.append(" │"); }
        }
        else if (closeCh == '|')
        {
            mb.append(" │");
        }
        else if (closeCh == 'V')
        {
            mb.append(" ║");
        }
        else if (closeCh != 0)
        {
            mb.append_char(' ');
            mb.append_char(closeCh);
        }

        rBuf[r] = mb.keep(arena);
    }

    MathBox res;
    res.width = newW;
    res.height = h;
    res.baseline = inner.baseline;
    res.rows = rBuf[0 : (usz)h];
    return res;
}

fn MathBox stack(ast::Arena* arena, MathBox[] list)
{
    if (list.len == 0) return blank(arena);
    if (list.len == 1) return list[0];

    int maxW = 0;
    int totalH = 0;
    for (usz i = 0; i < list.len; i++)
    {
        if (list[i].width > maxW) maxW = list[i].width;
        totalH += list[i].height;
    }

    String* rBuf = (String*)arena.alloc((usz)totalH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    int curR = 0;
    for (usz i = 0; i < list.len; i++)
    {
        MathBox b = list[i];
        for (int r = 0; r < b.height; r++)
        {
            mb.clear();
            mb.append_string(b.rows[r]);
            int rw = text::width(b.rows[r]);
            int pad = maxW - rw;
            if (pad > 0) mb.spaces(pad);
            rBuf[curR++] = mb.keep(arena);
        }
    }

    MathBox res;
    res.width = maxW;
    res.height = totalH;
    res.baseline = totalH / 2;
    res.rows = rBuf[0 : (usz)totalH];
    return res;
}

fn MathBox boxed(ast::Arena* arena, MathBox inner)
{
    int w = inner.width + 4;
    int newH = inner.height + 2;
    int newBase = inner.baseline + 1;

    String* rBuf = (String*)arena.alloc((usz)newH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    mb.clear();
    mb.append("┌");
    mb.repeat("─", inner.width + 2);
    mb.append("┐");
    rBuf[0] = mb.keep(arena);

    for (int r = 0; r < inner.height; r++)
    {
        mb.clear();
        mb.append("│ ");
        mb.append_string(inner.rows[r]);
        int rw = text::width(inner.rows[r]);
        int pad = inner.width - rw;
        if (pad > 0) mb.spaces(pad);
        mb.append(" │");
        rBuf[r + 1] = mb.keep(arena);
    }

    mb.clear();
    mb.append("└");
    mb.repeat("─", inner.width + 2);
    mb.append("┘");
    rBuf[newH - 1] = mb.keep(arena);

    MathBox res;
    res.width = w;
    res.height = newH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)newH];
    return res;
}

fn MathBox overline(ast::Arena* arena, MathBox inner)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int newH = inner.height + 1;
    int newBase = inner.baseline + 1;

    String* rBuf = (String*)arena.alloc((usz)newH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    mb.clear();
    mb.repeat("─", w);
    rBuf[0] = mb.keep(arena);

    for (int r = 0; r < inner.height; r++)
    {
        rBuf[r + 1] = inner.rows[r];
    }

    MathBox res;
    res.width = w;
    res.height = newH;
    res.baseline = newBase;
    res.rows = rBuf[0 : (usz)newH];
    return res;
}

fn MathBox overbrace(ast::Arena* arena, MathBox inner, MathBox label)
{
    int labH = label.width > 0 ? label.height : 0;
    return column(arena, { present(label), rule(arena, "⏞", inner.width), inner }, max(inner.width, label.width), labH + 1 + inner.baseline);
}

fn MathBox underbrace(ast::Arena* arena, MathBox inner, MathBox label)
{
    return column(arena, { inner, rule(arena, "⏟", inner.width), present(label) }, max(inner.width, label.width), inner.baseline);
}

fn MathBox grid(ast::Arena* arena, MathBox[] grid, int numRows, int numCols, char alignMode, int colGap = 2)
{
    if (numRows <= 0 || numCols <= 0 || grid.len < (usz)(numRows * numCols)) return blank(arena);

    int* colW = (int*)arena.alloc((usz)numCols * int::size);

    for (int c = 0; c < numCols; c++)
    {
        int maxCw = 0;
        for (int r = 0; r < numRows; r++)
        {
            MathBox cell = grid[(usz)(r * numCols + c)];
            if (cell.width > maxCw) maxCw = cell.width;
        }
        colW[c] = maxCw;
    }

    int* rowAbove = (int*)arena.alloc((usz)numRows * int::size);
    int* rowBelow = (int*)arena.alloc((usz)numRows * int::size);
    int* rowH = (int*)arena.alloc((usz)numRows * int::size);

    int totalH = 0;

    for (int r = 0; r < numRows; r++)
    {
        int maxAbove = 0;
        int maxBelow = 0;
        for (int c = 0; c < numCols; c++)
        {
            MathBox cell = grid[(usz)(r * numCols + c)];
            if (cell.baseline > maxAbove) maxAbove = cell.baseline;
            int below = cell.height - 1 - cell.baseline;
            if (below > maxBelow) maxBelow = below;
        }
        rowAbove[r] = maxAbove;
        rowBelow[r] = maxBelow;
        rowH[r] = maxAbove + 1 + maxBelow;
        totalH += rowH[r];
    }

    int totalW = 0;
    for (int c = 0; c < numCols; c++)
    {
        totalW += colW[c];
        if (c > 0) totalW += colGap;
    }

    String* rBuf = (String*)arena.alloc((usz)totalH * String::size);
    DString mb;
    mb.init(mem, 512);
    defer mb.free();

    int curR = 0;
    for (int r = 0; r < numRows; r++)
    {
        int rh = rowH[r];
        int rabove = rowAbove[r];

        for (int subR = 0; subR < rh; subR++)
        {
            mb.clear();

            for (int c = 0; c < numCols; c++)
            {
                if (c > 0) mb.spaces(colGap);

                MathBox cell = grid[(usz)(r * numCols + c)];
                int cellR = subR - (rabove - cell.baseline);
                int targetW = colW[c];

                if (cellR >= 0 && cellR < cell.height)
                {
                    String rowStr = cell.rows[cellR];
                    int rw = text::width(rowStr);
                    int pad = targetW - rw;
                    if (pad < 0) pad = 0;

                    if (alignMode == 'A')
                    {
                        if (c % 2 == 0)
                        {
                            mb.spaces(pad);
                            mb.append_string(rowStr);
                        }
                        else
                        {
                            mb.append_string(rowStr);
                            mb.spaces(pad);
                        }
                    }
                    else if (alignMode == 'C')
                    {
                        int lpad = pad / 2;
                        int rpad = pad - lpad;
                        mb.spaces(lpad);
                        mb.append_string(rowStr);
                        mb.spaces(rpad);
                    }
                    else if (alignMode == 'R')
                    {
                        mb.spaces(pad);
                        mb.append_string(rowStr);
                    }
                    else
                    {
                        mb.append_string(rowStr);
                        mb.spaces(pad);
                    }
                }
                else
                {
                    mb.spaces(targetW);
                }
            }

            rBuf[curR++] = mb.keep(arena);
        }
    }

    MathBox res;
    res.width = totalW;
    res.height = totalH;
    res.baseline = totalH / 2;
    res.rows = rBuf[0 : (usz)totalH];
    return res;
}
