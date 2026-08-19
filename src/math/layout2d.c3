module math;

import std::core::mem;
import ast;
import strutils;

struct MathBox {
    int width;
    int height;
    int baseline;
    String[] rows;
}

struct MathRowBuilder {
    char[] buf;
    usz len;
    usz cap;
}

fn void MathRowBuilder.init(MathRowBuilder* mb, usz initial_cap = 512)
{
    mb.buf = mem::alloc_array(char, (sz)initial_cap);
    mb.len = 0;
    mb.cap = initial_cap;
}

fn void MathRowBuilder.append_char(MathRowBuilder* mb, char c)
{
    if (mb.len >= mb.cap - 1)
    {
        usz new_cap = mb.cap * 2;
        char[] new_buf = mem::alloc_array(char, (sz)new_cap);
        for (usz i = 0; i < mb.len; i++) new_buf[i] = mb.buf[i];
        mem::free(mb.buf);
        mb.buf = new_buf;
        mb.cap = new_cap;
    }
    mb.buf[mb.len++] = c;
}

fn void MathRowBuilder.append_zstr(MathRowBuilder* mb, char* s)
{
    if (s == null) return;
    usz i = 0;
    while (s[i] != 0)
    {
        mb.append_char(s[i++]);
    }
}

fn void MathRowBuilder.append_slice(MathRowBuilder* mb, String s)
{
    for (usz i = 0; i < (usz)s.len; i++)
    {
        mb.append_char(s[i]);
    }
}

fn void MathRowBuilder.append_spaces(MathRowBuilder* mb, int count)
{
    for (int i = 0; i < count; i++)
    {
        mb.append_char(' ');
    }
}

fn void MathRowBuilder.append_repeat(MathRowBuilder* mb, char* s, int count)
{
    for (int i = 0; i < count; i++)
    {
        mb.append_zstr(s);
    }
}

fn String MathRowBuilder.to_arena_string(MathRowBuilder* mb, ast::Arena* arena)
{
    if (mb.len == 0) return "";
    String s = (String)mb.buf[:mb.len];
    return arena.dup_string(s);
}

fn void MathRowBuilder.free(MathRowBuilder* mb)
{
    if (mb.buf.ptr != null)
    {
        mem::free(mb.buf);
        mb.buf = {};
        mb.len = 0;
        mb.cap = 0;
    }
}

fn MathBox box_empty(ast::Arena* arena)
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

fn MathBox box_from_string(ast::Arena* arena, String text)
{
    MathBox box;
    box.width = strutils::string_display_width(text);
    box.height = 1;
    box.baseline = 0;
    String* r = (String*)arena.alloc(String::size);
    r[0] = arena.dup_string(text);
    box.rows = r[0:1];
    return box;
}

fn MathBox box_from_zstr(ast::Arena* arena, char* text)
{
    if (text == null || text[0] == 0) return box_empty(arena);
    int len = strutils::str_len(text);
    String s = (String)text[:len];
    return box_from_string(arena, s);
}

fn MathBox box_spaces(ast::Arena* arena, int count)
{
    if (count <= 0) return box_empty(arena);
    MathRowBuilder mb;
    mb.init((usz)(count + 1));
    defer mb.free();
    mb.append_spaces(count);

    MathBox box;
    box.width = count;
    box.height = 1;
    box.baseline = 0;
    String* r = (String*)arena.alloc(String::size);
    r[0] = mb.to_arena_string(arena);
    box.rows = r[0:1];
    return box;
}

fn MathBox box_hconcat(ast::Arena* arena, MathBox left, MathBox right, int gap = 0)
{
    if (left.width == 0 && left.height == 1 && left.rows[0].len == 0) return right;
    if (right.width == 0 && right.height == 1 && right.rows[0].len == 0) return left;

    int above = left.baseline > right.baseline ? left.baseline : right.baseline;
    int left_below = left.height - 1 - left.baseline;
    int right_below = right.height - 1 - right.baseline;
    int below = left_below > right_below ? left_below : right_below;

    int new_h = above + 1 + below;
    int new_base = above;
    int new_w = left.width + gap + right.width;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);

    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < new_h; r++)
    {
        mb.len = 0;

        // Left part
        int lr = r - (above - left.baseline);
        if (lr >= 0 && lr < left.height)
        {
            mb.append_slice(left.rows[lr]);
            int row_w = strutils::string_display_width(left.rows[lr]);
            int pad = left.width - row_w;
            if (pad > 0) mb.append_spaces(pad);
        }
        else
        {
            mb.append_spaces(left.width);
        }

        // Gap
        if (gap > 0) mb.append_spaces(gap);

        // Right part
        int rr = r - (above - right.baseline);
        if (rr >= 0 && rr < right.height)
        {
            mb.append_slice(right.rows[rr]);
            int row_w = strutils::string_display_width(right.rows[rr]);
            int pad = right.width - row_w;
            if (pad > 0) mb.append_spaces(pad);
        }
        else
        {
            mb.append_spaces(right.width);
        }

        r_buf[r] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = new_w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_fraction(ast::Arena* arena, MathBox num, MathBox den)
{
    int max_w = num.width > den.width ? num.width : den.width;
    int w = max_w + 2;

    int new_h = num.height + 1 + den.height;
    int new_base = num.height;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);

    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    // Numerator rows (centered)
    for (int r = 0; r < num.height; r++)
    {
        mb.len = 0;
        int row_w = strutils::string_display_width(num.rows[r]);
        int total_pad = w - row_w;
        int lpad = total_pad / 2;
        int rpad = total_pad - lpad;
        if (lpad > 0) mb.append_spaces(lpad);
        mb.append_slice(num.rows[r]);
        if (rpad > 0) mb.append_spaces(rpad);
        r_buf[r] = mb.to_arena_string(arena);
    }

    // Fraction bar
    mb.len = 0;
    mb.append_repeat("─", w);
    r_buf[num.height] = mb.to_arena_string(arena);

    // Denominator rows (centered)
    for (int r = 0; r < den.height; r++)
    {
        mb.len = 0;
        int row_w = strutils::string_display_width(den.rows[r]);
        int total_pad = w - row_w;
        int lpad = total_pad / 2;
        int rpad = total_pad - lpad;
        if (lpad > 0) mb.append_spaces(lpad);
        mb.append_slice(den.rows[r]);
        if (rpad > 0) mb.append_spaces(rpad);
        r_buf[num.height + 1 + r] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_sqrt(ast::Arena* arena, MathBox inner, MathBox degree)
{
    int deg_w = degree.width;
    int left_w = (deg_w > 0 ? deg_w + 1 : 1);
    int w = left_w + 1 + inner.width;
    int new_h = inner.height + 1;
    int new_base = inner.baseline + 1;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);

    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    // Top vinculum overline: [deg_spaces] ┌───
    mb.len = 0;
    if (deg_w > 0) mb.append_spaces(deg_w);
    mb.append_spaces(left_w - deg_w);
    mb.append_zstr("┌");
    mb.append_repeat("─", inner.width + 1);
    r_buf[0] = mb.to_arena_string(arena);

    // Inner rows with radical symbol
    for (int r = 0; r < inner.height; r++)
    {
        mb.len = 0;
        if (r == inner.height - 1)
        {
            if (deg_w > 0)
            {
                mb.append_slice(degree.rows[0]);
                mb.append_zstr("√ ");
            }
            else
            {
                mb.append_zstr("√ ");
            }
        }
        else
        {
            mb.append_spaces(left_w);
            mb.append_zstr("│ ");
        }

        mb.append_slice(inner.rows[r]);
        int row_w = strutils::string_display_width(inner.rows[r]);
        int pad = inner.width - row_w;
        if (pad > 0) mb.append_spaces(pad);

        r_buf[r + 1] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = w + 1;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_summation_op(ast::Arena* arena, MathBox sub, MathBox sup)
{
    int sym_w = 5;
    int max_w = sym_w;
    if (sub.width > max_w) max_w = sub.width;
    if (sup.width > max_w) max_w = sup.width;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + 5 + sub_h;
    int base = sup_h + 2;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sup.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Sigma glyph (5 rows)
    char*[5] sig = { " ─── ", " \\   ", "  >  ", " /   ", " ─── " };
    for (int i = 0; i < 5; i++)
    {
        mb.len = 0;
        int pad = (max_w - sym_w) / 2;
        mb.append_spaces(pad);
        mb.append_zstr(sig[i]);
        mb.append_spaces(max_w - sym_w - pad);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Sub on bottom
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sub.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_product_op(ast::Arena* arena, MathBox sub, MathBox sup)
{
    int sym_w = 5;
    int max_w = sym_w;
    if (sub.width > max_w) max_w = sub.width;
    if (sup.width > max_w) max_w = sup.width;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + 5 + sub_h;
    int base = sup_h + 2;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sup.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Pi glyph (5 rows)
    char*[5] pi_lines = { " ─── ", " ┬ ┬ ", " │ │ ", " │ │ ", " ┴ ┴ " };
    for (int i = 0; i < 5; i++)
    {
        mb.len = 0;
        int pad = (max_w - sym_w) / 2;
        mb.append_spaces(pad);
        mb.append_zstr(pi_lines[i]);
        mb.append_spaces(max_w - sym_w - pad);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Sub on bottom
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sub.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_integral_op(ast::Arena* arena, MathBox sub, MathBox sup, int int_order = 1)
{
    int h = 3;
    int sym_w = int_order == 1 ? 3 : (int_order == 2 ? 4 : 5);
    int max_w = sym_w;
    if (sub.width + sym_w > max_w) max_w = sub.width + sym_w;
    if (sup.width + sym_w > max_w) max_w = sup.width + sym_w;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + h + sub_h;
    int base = sup_h + (h / 2);

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.len = 0;
            mb.append_spaces(sym_w);
            mb.append_slice(sup.rows[r]);
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = max_w - sym_w - rw;
            if (pad > 0) mb.append_spaces(pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Integral rows
    for (int r = 0; r < h; r++)
    {
        mb.len = 0;
        if (int_order == 1)
        {
            if (r == 0) { mb.append_zstr(" ⌠ "); }
            else if (r == h - 1) { mb.append_zstr(" ⌡ "); }
            else { mb.append_zstr(" │ "); }
        }
        else if (int_order == 2)
        {
            if (r == 0) { mb.append_zstr(" ⌠⌠ "); }
            else if (r == h - 1) { mb.append_zstr(" ⌡⌡ "); }
            else { mb.append_zstr(" ││ "); }
        }
        else
        {
            if (r == 0) { mb.append_zstr(" ⌠⌠⌠ "); }
            else if (r == h - 1) { mb.append_zstr(" ⌡⌡⌡ "); }
            else { mb.append_zstr(" │││ "); }
        }

        mb.append_spaces(max_w - sym_w);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Sub on bottom
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.len = 0;
            mb.append_spaces(sym_w);
            mb.append_slice(sub.rows[r]);
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = max_w - sym_w - rw;
            if (pad > 0) mb.append_spaces(pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_limits_op(ast::Arena* arena, MathBox op, MathBox sub, MathBox sup)
{
    int max_w = op.width;
    if (sub.width > max_w) max_w = sub.width;
    if (sup.width > max_w) max_w = sup.width;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + op.height + sub_h;
    int base = sup_h + op.baseline;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sup.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Op in middle
    for (int r = 0; r < op.height; r++)
    {
        mb.len = 0;
        int rw = strutils::string_display_width(op.rows[r]);
        int pad = (max_w - rw) / 2;
        mb.append_spaces(pad);
        mb.append_slice(op.rows[r]);
        mb.append_spaces(max_w - rw - pad);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Sub on bottom
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.len = 0;
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sub.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_supsub(ast::Arena* arena, MathBox base, MathBox sup, MathBox sub)
{
    if (sup.width == 0 && sub.width == 0) return base;

    int script_w = sup.width > sub.width ? sup.width : sub.width;
    int sup_h = sup.width > 0 ? sup.height : 0;
    int sub_h = sub.width > 0 ? sub.height : 0;

    int total_h = sup_h + base.height + sub_h;
    int new_base = sup_h + base.baseline;
    int new_w = base.width + script_w;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup rows (aligned right above base)
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.len = 0;
            mb.append_spaces(base.width);
            mb.append_slice(sup.rows[r]);
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = script_w - rw;
            if (pad > 0) mb.append_spaces(pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Base rows
    for (int r = 0; r < base.height; r++)
    {
        mb.len = 0;
        mb.append_slice(base.rows[r]);
        int rw = strutils::string_display_width(base.rows[r]);
        int pad = base.width - rw;
        if (pad > 0) mb.append_spaces(pad);
        mb.append_spaces(script_w);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Sub rows (aligned below base)
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.len = 0;
            mb.append_spaces(base.width);
            mb.append_slice(sub.rows[r]);
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = script_w - rw;
            if (pad > 0) mb.append_spaces(pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = new_w;
    res.height = total_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_delimiters(ast::Arena* arena, MathBox inner, char open_ch, char close_ch)
{
    if (inner.height <= 1)
    {
        char[8] l_delim; l_delim[0] = open_ch; l_delim[1] = 0;
        char[8] r_delim; r_delim[0] = close_ch; r_delim[1] = 0;
        if (open_ch == '{') { l_delim[0] = '{'; l_delim[1] = 0; }
        if (close_ch == '}') { r_delim[0] = '}'; r_delim[1] = 0; }

        MathBox l_box = (open_ch != 0) ? box_from_zstr(arena, &l_delim[0]) : box_empty(arena);
        MathBox r_box = (close_ch != 0) ? box_from_zstr(arena, &r_delim[0]) : box_empty(arena);
        MathBox mid = (open_ch != 0) ? box_hconcat(arena, l_box, inner, 1) : inner;
        return (close_ch != 0) ? box_hconcat(arena, mid, r_box, 1) : mid;
    }

    int h = inner.height;
    int l_pad = (open_ch != 0) ? 2 : 0;
    int r_pad = (close_ch != 0) ? 2 : 0;
    int new_w = inner.width + l_pad + r_pad;

    String* r_buf = (String*)arena.alloc((usz)h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < h; r++)
    {
        mb.len = 0;

        // Left delimiter
        if (open_ch == '(')
        {
            if (r == 0) { mb.append_zstr("⎛ "); }
            else if (r == h - 1) { mb.append_zstr("⎝ "); }
            else { mb.append_zstr("⎜ "); }
        }
        else if (open_ch == '[')
        {
            if (r == 0) { mb.append_zstr("⎡ "); }
            else if (r == h - 1) { mb.append_zstr("⎣ "); }
            else { mb.append_zstr("⎢ "); }
        }
        else if (open_ch == '{')
        {
            if (r == 0) { mb.append_zstr("⎧ "); }
            else if (r == h - 1) { mb.append_zstr("⎩ "); }
            else if (r == h / 2) { mb.append_zstr("⎨ "); }
            else { mb.append_zstr("⎪ "); }
        }
        else if (open_ch == '|')
        {
            mb.append_zstr("│ ");
        }
        else if (open_ch == 'V') // Norm \|
        {
            mb.append_zstr("║ ");
        }
        else if (open_ch != 0)
        {
            mb.append_char(open_ch);
            mb.append_char(' ');
        }

        // Inner row
        mb.append_slice(inner.rows[r]);
        int row_w = strutils::string_display_width(inner.rows[r]);
        int pad = inner.width - row_w;
        if (pad > 0) mb.append_spaces(pad);

        // Right delimiter
        if (close_ch == ')')
        {
            if (r == 0) { mb.append_zstr(" ⎞"); }
            else if (r == h - 1) { mb.append_zstr(" ⎠"); }
            else { mb.append_zstr(" ⎟"); }
        }
        else if (close_ch == ']')
        {
            if (r == 0) { mb.append_zstr(" ⎤"); }
            else if (r == h - 1) { mb.append_zstr(" ⎦"); }
            else { mb.append_zstr(" ⎥"); }
        }
        else if (close_ch == '}')
        {
            if (r == 0) { mb.append_zstr(" ⎫"); }
            else if (r == h - 1) { mb.append_zstr(" ⎭"); }
            else if (r == h / 2) { mb.append_zstr(" ⎬"); }
            else { mb.append_zstr(" ⎪"); }
        }
        else if (close_ch == '|')
        {
            mb.append_zstr(" │");
        }
        else if (close_ch == 'V')
        {
            mb.append_zstr(" ║");
        }
        else if (close_ch != 0)
        {
            mb.append_char(' ');
            mb.append_char(close_ch);
        }

        r_buf[r] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = new_w;
    res.height = h;
    res.baseline = inner.baseline;
    res.rows = r_buf[0 : (usz)h];
    return res;
}

fn MathBox box_vconcat_list(ast::Arena* arena, MathBox[] list)
{
    if (list.len == 0) return box_empty(arena);
    if (list.len == 1) return list[0];

    int max_w = 0;
    int total_h = 0;
    for (usz i = 0; i < list.len; i++)
    {
        if (list[i].width > max_w) max_w = list[i].width;
        total_h += list[i].height;
    }

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    MathRowBuilder mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;
    for (usz i = 0; i < list.len; i++)
    {
        MathBox b = list[i];
        for (int r = 0; r < b.height; r++)
        {
            mb.len = 0;
            mb.append_slice(b.rows[r]);
            int rw = strutils::string_display_width(b.rows[r]);
            int pad = max_w - rw;
            if (pad > 0) mb.append_spaces(pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = total_h / 2;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2D LaTeX Math Parser
// ─────────────────────────────────────────────────────────────────────────────

struct Math2DParser {
    ast::Arena* arena;
    String src;
    usz pos;
}

fn bool Math2DParser.eof(Math2DParser* p)
{
    return p.pos >= (usz)p.src.len;
}

fn char Math2DParser.peek(Math2DParser* p)
{
    if (p.eof()) return 0;
    return p.src[p.pos];
}

fn char Math2DParser.get(Math2DParser* p)
{
    if (p.eof()) return 0;
    return p.src[p.pos++];
}

fn void Math2DParser.skip_spaces(Math2DParser* p)
{
    while (!p.eof() && (p.src[p.pos] == ' ' || p.src[p.pos] == '\t' || p.src[p.pos] == '\r' || p.src[p.pos] == '\n'))
    {
        p.pos++;
    }
}

fn MathBox parse_math_term(Math2DParser* p)
{
    p.skip_spaces();
    if (p.eof()) return box_empty(p.arena);

    char c = p.peek();

    // 1. Group { ... }
    if (c == '{')
    {
        p.get();
        MathBox grp = parse_math_expression(p, false, false);
        p.skip_spaces();
        if (p.peek() == '}') p.get();
        return grp;
    }

    // 2. Command \cmd
    if (c == '\\')
    {
        p.get(); // consume '\'
        if (p.eof()) return box_from_zstr(p.arena, "\\");

        char next_c = p.peek();
        if (next_c == '{' || next_c == '}' || next_c == '%' || next_c == '$')
        {
            p.get();
            char[2] ch; ch[0] = next_c; ch[1] = 0;
            return box_from_zstr(p.arena, &ch[0]);
        }
        if (next_c == ',') { p.get(); return box_from_zstr(p.arena, " "); }
        if (next_c == ';') { p.get(); return box_from_zstr(p.arena, "  "); }
        if (next_c == ':') { p.get(); return box_from_zstr(p.arena, " "); }
        if (next_c == '!') { p.get(); return box_empty(p.arena); }
        if (next_c == ' ') { p.get(); return box_from_zstr(p.arena, " "); }

        // Read command name
        usz cmd_start = p.pos;
        while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z')))
        {
            p.pos++;
        }
        String cmd = p.src[cmd_start : p.pos - cmd_start];

        // ── Fractions: \frac{num}{den} ───────────────────────────────────────
        if (strutils::string_eq(cmd, "frac") || strutils::string_eq(cmd, "dfrac") || strutils::string_eq(cmd, "tfrac"))
        {
            MathBox num = parse_math_group(p);
            MathBox den = parse_math_group(p);
            return box_fraction(p.arena, num, den);
        }

        // ── Square Root: \sqrt[deg]{inner} ───────────────────────────────────
        if (strutils::string_eq(cmd, "sqrt"))
        {
            p.skip_spaces();
            MathBox deg = box_empty(p.arena);
            if (p.peek() == '[')
            {
                p.get(); // consume '['
                usz d_start = p.pos;
                while (!p.eof() && p.peek() != ']') p.pos++;
                String d_str = p.src[d_start : p.pos - d_start];
                if (p.peek() == ']') p.get();
                deg = box_from_string(p.arena, d_str);
            }
            MathBox inner = parse_math_group(p);
            return box_sqrt(p.arena, inner, deg);
        }

        // ── Summation: \sum ──────────────────────────────────────────────────
        if (strutils::string_eq(cmd, "sum"))
        {
            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);

            // Read attached _ and ^
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_')
                {
                    p.get();
                    sub = parse_math_group(p);
                }
                else if (p.peek() == '^')
                {
                    p.get();
                    sup = parse_math_group(p);
                }
            }
            return box_summation_op(p.arena, sub, sup);
        }

        // ── Product: \prod ───────────────────────────────────────────────────
        if (strutils::string_eq(cmd, "prod"))
        {
            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_') { p.get(); sub = parse_math_group(p); }
                else if (p.peek() == '^') { p.get(); sup = parse_math_group(p); }
            }
            return box_product_op(p.arena, sub, sup);
        }

        // ── Integrals: \int, \iint, \iiint, \oint ────────────────────────────
        if (strutils::string_eq(cmd, "int") || strutils::string_eq(cmd, "iint") || strutils::string_eq(cmd, "iiint") || strutils::string_eq(cmd, "oint"))
        {
            int order = 1;
            if (strutils::string_eq(cmd, "iint")) { order = 2; }
            if (strutils::string_eq(cmd, "iiint")) { order = 3; }

            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_') { p.get(); sub = parse_math_group(p); }
                else if (p.peek() == '^') { p.get(); sup = parse_math_group(p); }
            }
            return box_integral_op(p.arena, sub, sup, order);
        }

        // ── Limits: \lim, \max, \min, \sup, \inf ─────────────────────────────
        if (strutils::string_eq(cmd, "lim") || strutils::string_eq(cmd, "liminf") || strutils::string_eq(cmd, "limsup") || strutils::string_eq(cmd, "max") || strutils::string_eq(cmd, "min") || strutils::string_eq(cmd, "sup") || strutils::string_eq(cmd, "inf") || strutils::string_eq(cmd, "argmax") || strutils::string_eq(cmd, "argmin"))
        {
            String op_name = cmd;
            if (strutils::string_eq(cmd, "liminf")) { op_name = "lim inf"; }
            else if (strutils::string_eq(cmd, "limsup")) { op_name = "lim sup"; }
            else if (strutils::string_eq(cmd, "argmax")) { op_name = "arg max"; }
            else if (strutils::string_eq(cmd, "argmin")) { op_name = "arg min"; }

            MathBox op_box = box_from_string(p.arena, op_name);
            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_') { p.get(); sub = parse_math_group(p); }
                else if (p.peek() == '^') { p.get(); sup = parse_math_group(p); }
            }
            return box_limits_op(p.arena, op_box, sub, sup);
        }

        // ── Delimiters: \left ... \right ─────────────────────────────────────
        if (strutils::string_eq(cmd, "left"))
        {
            p.skip_spaces();
            char open_ch = p.get();
            if (open_ch == '\\')
            {
                char next_delim = p.get();
                if (next_delim == '{') { open_ch = '{'; }
                else if (next_delim == '}') { open_ch = '}'; }
                else if (next_delim == '|') { open_ch = 'V'; } // norm \|
            }
            if (open_ch == '.') open_ch = 0;

            MathBox inner = parse_math_expression(p, false, false);

            char close_ch = ')';
            p.skip_spaces();
            if (p.peek() == '\\')
            {
                p.get();
                usz r_start = p.pos;
                while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
                String r_cmd = p.src[r_start : p.pos - r_start];
                if (strutils::string_eq(r_cmd, "right"))
                {
                    p.skip_spaces();
                    close_ch = p.get();
                    if (close_ch == '\\')
                    {
                        char next_delim = p.get();
                        if (next_delim == '{') { close_ch = '{'; }
                        else if (next_delim == '}') { close_ch = '}'; }
                        else if (next_delim == '|') { close_ch = 'V'; }
                    }
                    if (close_ch == '.') close_ch = 0;
                }
            }

            return box_delimiters(p.arena, inner, open_ch, close_ch);
        }

        // ── Environments: \begin{matrix}, \begin{cases}, etc. ────────────────
        if (strutils::string_eq(cmd, "begin"))
        {
            p.skip_spaces();
            if (p.peek() == '{') p.get();
            usz env_start = p.pos;
            while (!p.eof() && p.peek() != '}') p.pos++;
            String env_name = p.src[env_start : p.pos - env_start];
            if (p.peek() == '}') p.get();

            const usz MAX_ENV_ROWS = 16;
            const usz MAX_ENV_COLS = 16;
            MathBox[MAX_ENV_COLS][MAX_ENV_ROWS] grid;
            int num_rows = 0;
            int num_cols = 0;

            int cur_col = 0;
            while (!p.eof() && num_rows < (int)MAX_ENV_ROWS)
            {
                p.skip_spaces();

                // Check for \end{env}
                if (p.peek() == '\\')
                {
                    usz save_pos = p.pos;
                    p.get();
                    usz check_start = p.pos;
                    while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
                    String check_cmd = p.src[check_start : p.pos - check_start];
                    if (strutils::string_eq(check_cmd, "end"))
                    {
                        p.skip_spaces();
                        if (p.peek() == '{') p.get();
                        while (!p.eof() && p.peek() != '}') p.pos++;
                        if (p.peek() == '}') p.get();
                        if (cur_col > 0) num_rows++;
                        break;
                    }
                    else if (p.src[save_pos + 1] == '\\') // double backslash \\
                    {
                        p.pos = save_pos + 2;
                        num_rows++;
                        cur_col = 0;
                        continue;
                    }
                    else
                    {
                        p.pos = save_pos;
                    }
                }

                MathBox cell = parse_math_expression(p, true, true);
                if (cur_col < (int)MAX_ENV_COLS)
                {
                    grid[num_rows][cur_col] = cell;
                    cur_col++;
                    if (cur_col > num_cols) num_cols = cur_col;
                }

                p.skip_spaces();
                if (p.peek() == '&')
                {
                    p.get(); // consume '&'
                }
                else if (p.peek() == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\')
                {
                    p.pos += 2;
                    num_rows++;
                    cur_col = 0;
                }
            }

            if (strutils::string_eq(env_name, "cases"))
            {
                MathBox[16] row_list;
                for (int r = 0; r < num_rows; r++)
                {
                    MathBox rbox = box_empty(p.arena);
                    for (int col_idx = 0; col_idx < num_cols; col_idx++)
                    {
                        rbox = box_hconcat(p.arena, rbox, grid[r][col_idx], col_idx > 0 ? 3 : 0);
                    }
                    row_list[r] = rbox;
                }
                MathBox inner = box_vconcat_list(p.arena, row_list[: (usz)num_rows]);
                return box_delimiters(p.arena, inner, '{', (char)0);
            }

            char bracket_type = 'm';
            if (strutils::string_eq(env_name, "pmatrix")) { bracket_type = 'p'; }
            else if (strutils::string_eq(env_name, "bmatrix")) { bracket_type = 'b'; }
            else if (strutils::string_eq(env_name, "vmatrix")) { bracket_type = 'v'; }
            else if (strutils::string_eq(env_name, "Vmatrix")) { bracket_type = 'V'; }
            else if (strutils::string_eq(env_name, "Bmatrix")) { bracket_type = 'B'; }

            MathBox[16] row_list;
            for (int r = 0; r < num_rows; r++)
            {
                MathBox rbox = box_empty(p.arena);
                for (int col_idx = 0; col_idx < num_cols; col_idx++)
                {
                    rbox = box_hconcat(p.arena, rbox, grid[r][col_idx], col_idx > 0 ? 2 : 0);
                }
                row_list[r] = rbox;
            }
            MathBox inner = box_vconcat_list(p.arena, row_list[: (usz)num_rows]);

            char open_b = '['; char close_b = ']';
            if (bracket_type == 'p') { open_b = '('; close_b = ')'; }
            else if (bracket_type == 'v') { open_b = '|'; close_b = '|'; }
            else if (bracket_type == 'V') { open_b = 'V'; close_b = 'V'; }
            else if (bracket_type == 'B') { open_b = '{'; close_b = '}'; }
            else if (bracket_type == 'm') { return inner; }

            return box_delimiters(p.arena, inner, open_b, close_b);
        }

        // ── Text / Style Wrappers: \mathbf, \mathbb, \text, \operatorname ───
        if (strutils::string_eq(cmd, "mathbf") || strutils::string_eq(cmd, "mathrm") || strutils::string_eq(cmd, "text") || strutils::string_eq(cmd, "operatorname") || strutils::string_eq(cmd, "mathit") || strutils::string_eq(cmd, "mathsf") || strutils::string_eq(cmd, "mathtt"))
        {
            p.skip_spaces();
            if (p.peek() == '*') p.get();
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                usz t_start = p.pos;
                while (!p.eof() && p.peek() != '}') p.pos++;
                String txt = p.src[t_start : p.pos - t_start];
                if (p.peek() == '}') p.get();
                return box_from_string(p.arena, txt);
            }
        }
        if (strutils::string_eq(cmd, "mathbb"))
        {
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                MathRowBuilder mb;
                mb.init(32);
                defer mb.free();
                while (!p.eof() && p.peek() != '}')
                {
                    char* bb = get_mathbb_char(p.get());
                    if (bb != null) mb.append_zstr(bb);
                }
                if (p.peek() == '}') p.get();
                return box_from_string(p.arena, mb.to_arena_string(p.arena));
            }
        }
        if (strutils::string_eq(cmd, "mathcal") || strutils::string_eq(cmd, "mathscr"))
        {
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                MathRowBuilder mb;
                mb.init(32);
                defer mb.free();
                while (!p.eof() && p.peek() != '}')
                {
                    char* cal = get_mathcal_char(p.get());
                    if (cal != null) mb.append_zstr(cal);
                }
                if (p.peek() == '}') p.get();
                return box_from_string(p.arena, mb.to_arena_string(p.arena));
            }
        }

        // ── Accents: \vec, \hat, \bar, \dot, \ddot, \tilde ───────────────────
        if (strutils::string_eq(cmd, "vec") || strutils::string_eq(cmd, "hat") || strutils::string_eq(cmd, "bar") || strutils::string_eq(cmd, "dot") || strutils::string_eq(cmd, "ddot") || strutils::string_eq(cmd, "tilde") || strutils::string_eq(cmd, "overline"))
        {
            MathBox inner = parse_math_group(p);
            char* combining = "⃗";
            if (strutils::string_eq(cmd, "hat")) { combining = "̂"; }
            else if (strutils::string_eq(cmd, "bar") || strutils::string_eq(cmd, "overline")) { combining = "̄"; }
            else if (strutils::string_eq(cmd, "dot")) { combining = "̇"; }
            else if (strutils::string_eq(cmd, "ddot")) { combining = "̈"; }
            else if (strutils::string_eq(cmd, "tilde")) { combining = "̃"; }

            MathRowBuilder mb;
            mb.init(64);
            defer mb.free();
            if (inner.height > 0)
            {
                mb.append_slice(inner.rows[0]);
                mb.append_zstr(combining);
            }
            return box_from_string(p.arena, mb.to_arena_string(p.arena));
        }

        // ── Spacing: \quad, \qquad ───────────────────────────────────────────
        if (strutils::string_eq(cmd, "quad")) return box_spaces(p.arena, 4);
        if (strutils::string_eq(cmd, "qquad")) return box_spaces(p.arena, 8);

        // ── Symbol Table Lookup ──────────────────────────────────────────────
        for (usz s = 0; s < SYMBOLS.len; s++)
        {
            if (strutils::string_eq(cmd, SYMBOLS[s].name))
            {
                return box_from_string(p.arena, SYMBOLS[s].glyph);
            }
        }

        return box_from_string(p.arena, cmd);
    }

    // 3. Digits / Numbers
    if (c >= '0' && c <= '9')
    {
        usz num_start = p.pos;
        while (!p.eof() && ((p.peek() >= '0' && p.peek() <= '9') || p.peek() == '.'))
        {
            p.pos++;
        }
        String num_str = p.src[num_start : p.pos - num_start];
        return box_from_string(p.arena, num_str);
    }

    // 4. Multi-character operators
    if (c == '+' || c == '-' || c == '=' || c == '<' || c == '>' || c == '*' || c == '/')
    {
        p.get();
        char[2] ch; ch[0] = c; ch[1] = 0;
        return box_from_zstr(p.arena, &ch[0]);
    }

    // 5. Normal character
    p.get();
    char[2] ch; ch[0] = c; ch[1] = 0;
    return box_from_zstr(p.arena, &ch[0]);
}

fn MathBox parse_math_group(Math2DParser* p)
{
    p.skip_spaces();
    if (p.eof()) return box_empty(p.arena);

    if (p.peek() == '{')
    {
        p.get();
        MathBox res = parse_math_expression(p, false, false);
        p.skip_spaces();
        if (p.peek() == '}') p.get();
        return res;
    }

    return parse_math_term(p);
}

fn MathBox parse_math_expression(Math2DParser* p, bool stop_at_amp = false, bool stop_at_bslash = false)
{
    MathBox res = box_empty(p.arena);

    while (!p.eof())
    {
        p.skip_spaces();
        if (p.eof()) break;

        char c = p.peek();
        if (c == '}' || c == ']') break;
        if (stop_at_amp && c == '&') break;
        if (stop_at_bslash && c == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\') break;

        // Check for \right or \end
        if (c == '\\')
        {
            usz save_pos = p.pos;
            p.get();
            usz check_start = p.pos;
            while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
            String check_cmd = p.src[check_start : p.pos - check_start];
            p.pos = save_pos;

            if (strutils::string_eq(check_cmd, "right") || strutils::string_eq(check_cmd, "end"))
            {
                break;
            }
        }

        // Parse base term
        MathBox term = parse_math_term(p);

        // Check for superscripts and subscripts attached to term
        MathBox sup = box_empty(p.arena);
        MathBox sub = box_empty(p.arena);
        bool has_script = false;

        while (true)
        {
            p.skip_spaces();
            if (p.peek() == '^')
            {
                p.get();
                sup = parse_math_group(p);
                has_script = true;
            }
            else if (p.peek() == '_')
            {
                p.get();
                sub = parse_math_group(p);
                has_script = true;
            }
            else
            {
                break;
            }
        }

        if (has_script)
        {
            term = box_supsub(p.arena, term, sup, sub);
        }

        // Concatenate with existing expression
        int gap = 0;
        if (res.width > 0)
        {
            gap = 0;
        }
        res = box_hconcat(p.arena, res, term, gap);
    }

    return res;
}

fn MathBox render_latex_to_box(ast::Arena* arena, String latex)
{
    Math2DParser parser;
    parser.arena = arena;
    parser.src = latex;
    parser.pos = 0;

    return parse_math_expression(&parser, false, false);
}
