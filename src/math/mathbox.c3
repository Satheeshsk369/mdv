module math;

import std::core::mem;
import logic;
import strutils;
import buffer;

fn MathBox box_empty(logic::Arena* arena)
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

fn MathBox box_from_string(logic::Arena* arena, String text)
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

fn MathBox box_from_zstr(logic::Arena* arena, char* text)
{
    if (text == null || text[0] == 0) return box_empty(arena);
    int len = strutils::str_len(text);
    String s = (String)text[:len];
    return box_from_string(arena, s);
}

fn MathBox box_spaces(logic::Arena* arena, int count)
{
    if (count <= 0) return box_empty(arena);
    buffer::ByteBuffer mb;
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

fn MathBox box_hconcat(logic::Arena* arena, MathBox left, MathBox right, int gap = 0)
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

    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < new_h; r++)
    {
        mb.reset();

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

fn MathBox box_fraction(logic::Arena* arena, MathBox num, MathBox den)
{
    int max_w = num.width > den.width ? num.width : den.width;
    int w = max_w + 2;

    int new_h = num.height + 1 + den.height;
    int new_base = num.height;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);

    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    // Numerator rows (centered)
    for (int r = 0; r < num.height; r++)
    {
        mb.reset();
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
    mb.reset();
    mb.append_repeat("─", w);
    r_buf[num.height] = mb.to_arena_string(arena);

    // Denominator rows (centered)
    for (int r = 0; r < den.height; r++)
    {
        mb.reset();
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

fn MathBox box_sqrt(logic::Arena* arena, MathBox inner, MathBox degree)
{
    int deg_w = degree.width;
    int prefix_w = deg_w + 2;
    int w = prefix_w + inner.width;
    int new_h = inner.height + 1;
    int new_base = inner.baseline + 1;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);

    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    // Top row 0 (vinculum overline): [deg] ┌───
    mb.reset();
    if (deg_w > 0)
    {
        mb.append_slice(degree.rows[0]);
    }
    mb.append_char(' ');
    mb.append_zstr("┌");
    mb.append_repeat("─", inner.width);
    r_buf[0] = mb.to_arena_string(arena);

    // Inner rows (1 .. inner.height)
    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        if (deg_w > 0) mb.append_spaces(deg_w);

        if (r == inner.height - 1)
        {
            mb.append_zstr("√ ");
        }
        else
        {
            mb.append_zstr("│ ");
        }

        mb.append_slice(inner.rows[r]);
        int row_w = strutils::string_display_width(inner.rows[r]);
        int pad = inner.width - row_w;
        if (pad > 0) mb.append_spaces(pad);

        r_buf[r + 1] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_summation_op(logic::Arena* arena, MathBox sub, MathBox sup)
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
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
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
        mb.reset();
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
            mb.reset();
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

fn MathBox box_product_op(logic::Arena* arena, MathBox sub, MathBox sup)
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
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
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
        mb.reset();
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
            mb.reset();
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

fn MathBox box_big_union_op(logic::Arena* arena, MathBox sub, MathBox sup, bool is_intersection = false)
{
    int sym_w = 5;
    int max_w = sym_w;
    if (sub.width > max_w) max_w = sub.width;
    if (sup.width > max_w) max_w = sup.width;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + 3 + sub_h;
    int base = sup_h + 1;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sup.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    char*[3] glyph = is_intersection ? { " ╭─╮ ", " │ │ ", " ╵ ╵ " } : { " ╷ ╷ ", " │ │ ", " ╰─╯ " };
    for (int i = 0; i < 3; i++)
    {
        mb.reset();
        int pad = (max_w - sym_w) / 2;
        mb.append_spaces(pad);
        mb.append_zstr(glyph[i]);
        mb.append_spaces(max_w - sym_w - pad);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.reset();
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

fn MathBox box_integral_op(logic::Arena* arena, MathBox sub, MathBox sup, int int_order = 1)
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
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
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
        mb.reset();
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
            mb.reset();
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

fn MathBox box_limits_op(logic::Arena* arena, MathBox op, MathBox sub, MathBox sup)
{
    int max_w = op.width;
    if (sub.width > max_w) max_w = sub.width;
    if (sup.width > max_w) max_w = sup.width;

    int sup_h = (sup.width > 0 ? sup.height : 0);
    int sub_h = (sub.width > 0 ? sub.height : 0);
    int total_h = sup_h + op.height + sub_h;
    int base = sup_h + op.baseline;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup on top
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
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
        mb.reset();
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
            mb.reset();
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

fn MathBox box_supsub(logic::Arena* arena, MathBox base, MathBox sup, MathBox sub)
{
    if (sup.width == 0 && sub.width == 0) return base;

    // Compact single-line Unicode subscripts for simple index when there is no superscript
    if (sup.width == 0 && base.height == 1 && sub.height <= 1)
    {
        String sub_txt = (sub.width > 0) ? sub.rows[0] : "";
        String u_sub = (sub.width > 0) ? try_unicode_subscript(arena, sub_txt) : "";
        if (u_sub.len > 0)
        {
            buffer::ByteBuffer mb;
            mb.init(128);
            defer mb.free();
            mb.append_slice(base.rows[0]);
            mb.append_slice(u_sub);
            return box_from_string(arena, mb.to_arena_string(arena));
        }
    }

    int script_w = sup.width > sub.width ? sup.width : sub.width;
    int sup_h = sup.width > 0 ? sup.height : 0;
    int sub_h = sub.width > 0 ? sub.height : 0;

    int total_h = sup_h + base.height + sub_h;
    int new_base = sup_h + base.baseline;
    int new_w = base.width + script_w;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Sup rows (aligned right above base)
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
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
        mb.reset();
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
            mb.reset();
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

fn MathBox box_xarrow(logic::Arena* arena, MathBox sup, MathBox sub, char arrow_dir = 'R')
{
    int max_w = sup.width > sub.width ? sup.width : sub.width;
    int arrow_w = max_w + 4;
    if (arrow_w < 6) arrow_w = 6;

    int sup_h = sup.width > 0 ? sup.height : 0;
    int sub_h = sub.width > 0 ? sub.height : 0;
    int total_h = sup_h + 1 + sub_h;
    int base = sup_h;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Top label (centered)
    if (sup.width > 0)
    {
        for (int r = 0; r < sup.height; r++)
        {
            mb.reset();
            int rw = strutils::string_display_width(sup.rows[r]);
            int pad = (arrow_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sup.rows[r]);
            mb.append_spaces(arrow_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Arrow line: ───→, ←───, ←───→
    mb.reset();
    if (arrow_dir == 'R')
    {
        mb.append_repeat("─", arrow_w - 1);
        mb.append_zstr("→");
    }
    else if (arrow_dir == 'L')
    {
        mb.append_zstr("←");
        mb.append_repeat("─", arrow_w - 1);
    }
    else // 'B' (Both)
    {
        mb.append_zstr("←");
        mb.append_repeat("─", arrow_w - 2);
        mb.append_zstr("→");
    }
    r_buf[cur_r++] = mb.to_arena_string(arena);

    // Bottom label (centered)
    if (sub.width > 0)
    {
        for (int r = 0; r < sub.height; r++)
        {
            mb.reset();
            int rw = strutils::string_display_width(sub.rows[r]);
            int pad = (arrow_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(sub.rows[r]);
            mb.append_spaces(arrow_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = arrow_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_underline(logic::Arena* arena, MathBox inner)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int new_h = inner.height + 1;
    int new_base = inner.baseline;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        r_buf[r] = inner.rows[r];
    }

    mb.reset();
    mb.append_repeat("─", w);
    r_buf[inner.height] = mb.to_arena_string(arena);

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_overarrow(logic::Arena* arena, MathBox inner, bool right_dir = true)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int new_h = inner.height + 1;
    int new_base = inner.baseline + 1;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    mb.reset();
    if (right_dir)
    {
        if (w > 1) mb.append_repeat("─", w - 1);
        mb.append_zstr("→");
    }
    else
    {
        mb.append_zstr("←");
        if (w > 1) mb.append_repeat("─", w - 1);
    }
    r_buf[0] = mb.to_arena_string(arena);

    for (int r = 0; r < inner.height; r++)
    {
        r_buf[r + 1] = inner.rows[r];
    }

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_with_tag(logic::Arena* arena, MathBox eq, String tag_str)
{
    if (tag_str.len == 0) return eq;
    MathBox tag_box = box_from_string(arena, tag_str);
    return box_hconcat(arena, eq, tag_box, 6);
}

fn MathBox box_cancel(logic::Arena* arena, MathBox inner)
{
    if (inner.height == 0) return inner;
    String* r_buf = (String*)arena.alloc((usz)inner.height * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        String row = inner.rows[r];
        for (usz i = 0; i < (usz)row.len; i++)
        {
            mb.append_char(row[i]);
            if (row[i] != ' ')
            {
                mb.append_zstr("̸");
            }
        }
        r_buf[r] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = inner.width;
    res.height = inner.height;
    res.baseline = inner.baseline;
    res.rows = r_buf[0 : (usz)inner.height];
    return res;
}

fn MathBox box_colorize(logic::Arena* arena, MathBox inner, char* ansi_color)
{
    if (inner.height == 0 || ansi_color == null) return inner;
    String* r_buf = (String*)arena.alloc((usz)inner.height * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        mb.append_zstr(ansi_color);
        mb.append_slice(inner.rows[r]);
        mb.append_zstr("\x1b[0m\x1b[38;2;255;216;102m\x1b[1m");
        r_buf[r] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = inner.width;
    res.height = inner.height;
    res.baseline = inner.baseline;
    res.rows = r_buf[0 : (usz)inner.height];
    return res;
}

fn MathBox box_delimiters(logic::Arena* arena, MathBox inner, char open_ch, char close_ch)
{
    if (inner.height <= 1)
    {
        char[8] l_delim; l_delim[0] = open_ch; l_delim[1] = 0;
        char[8] r_delim; r_delim[0] = close_ch; r_delim[1] = 0;
        if (open_ch == '{') { l_delim[0] = '{'; l_delim[1] = 0; }
        if (close_ch == '}') { r_delim[0] = '}'; r_delim[1] = 0; }
        if (open_ch == 'F') { l_delim[0] = 0; l_delim[1] = 0; }
        if (close_ch == 'F') { r_delim[0] = 0; r_delim[1] = 0; }

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
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    for (int r = 0; r < h; r++)
    {
        mb.reset();

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
        else if (open_ch == 'F') // Floor \lfloor
        {
            if (r == h - 1) { mb.append_zstr("⎣ "); }
            else { mb.append_zstr("⎢ "); }
        }
        else if (open_ch == 'C') // Ceil \lceil
        {
            if (r == 0) { mb.append_zstr("⎡ "); }
            else { mb.append_zstr("⎢ "); }
        }
        else if (open_ch == '<') // Angle \langle
        {
            if (r == 0 || r == h - 1) { mb.append_zstr("⟨ "); }
            else { mb.append_zstr("│ "); }
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
        else if (close_ch == 'F') // Floor \rfloor
        {
            if (r == h - 1) { mb.append_zstr(" ⎦"); }
            else { mb.append_zstr(" ⎥"); }
        }
        else if (close_ch == 'C') // Ceil \rceil
        {
            if (r == 0) { mb.append_zstr(" ⎤"); }
            else { mb.append_zstr(" ⎥"); }
        }
        else if (close_ch == '>') // Angle \rangle
        {
            if (r == 0 || r == h - 1) { mb.append_zstr(" ⟩"); }
            else { mb.append_zstr(" │"); }
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

fn MathBox box_vconcat_list(logic::Arena* arena, MathBox[] list)
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
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;
    for (usz i = 0; i < list.len; i++)
    {
        MathBox b = list[i];
        for (int r = 0; r < b.height; r++)
        {
            mb.reset();
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

fn MathBox box_boxed(logic::Arena* arena, MathBox inner)
{
    int w = inner.width + 4;
    int new_h = inner.height + 2;
    int new_base = inner.baseline + 1;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    // Top border: ┌───┐
    mb.reset();
    mb.append_zstr("┌");
    mb.append_repeat("─", inner.width + 2);
    mb.append_zstr("┐");
    r_buf[0] = mb.to_arena_string(arena);

    // Inner rows: │ text │
    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        mb.append_zstr("│ ");
        mb.append_slice(inner.rows[r]);
        int rw = strutils::string_display_width(inner.rows[r]);
        int pad = inner.width - rw;
        if (pad > 0) mb.append_spaces(pad);
        mb.append_zstr(" │");
        r_buf[r + 1] = mb.to_arena_string(arena);
    }

    // Bottom border: └───┘
    mb.reset();
    mb.append_zstr("└");
    mb.append_repeat("─", inner.width + 2);
    mb.append_zstr("┘");
    r_buf[new_h - 1] = mb.to_arena_string(arena);

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_overline(logic::Arena* arena, MathBox inner)
{
    if (inner.width == 0) return inner;
    int w = inner.width;
    int new_h = inner.height + 1;
    int new_base = inner.baseline + 1;

    String* r_buf = (String*)arena.alloc((usz)new_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    mb.reset();
    mb.append_repeat("─", w);
    r_buf[0] = mb.to_arena_string(arena);

    for (int r = 0; r < inner.height; r++)
    {
        r_buf[r + 1] = inner.rows[r];
    }

    MathBox res;
    res.width = w;
    res.height = new_h;
    res.baseline = new_base;
    res.rows = r_buf[0 : (usz)new_h];
    return res;
}

fn MathBox box_overbrace(logic::Arena* arena, MathBox inner, MathBox label)
{
    int max_w = inner.width > label.width ? inner.width : label.width;
    int lab_h = label.width > 0 ? label.height : 0;
    int total_h = lab_h + 1 + inner.height;
    int base = lab_h + 1 + inner.baseline;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Label rows (centered)
    if (label.width > 0)
    {
        for (int r = 0; r < label.height; r++)
        {
            mb.reset();
            int rw = strutils::string_display_width(label.rows[r]);
            int pad = (max_w - rw) / 2;
            mb.append_spaces(pad);
            mb.append_slice(label.rows[r]);
            mb.append_spaces(max_w - rw - pad);
            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    // Overbrace glyph: ⏞ or ───┴───
    mb.reset();
    int pad = (max_w - inner.width) / 2;
    mb.append_spaces(pad);
    mb.append_repeat("⏞", inner.width);
    mb.append_spaces(max_w - inner.width - pad);
    r_buf[cur_r++] = mb.to_arena_string(arena);

    // Inner rows
    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        int rw = strutils::string_display_width(inner.rows[r]);
        int pad2 = (max_w - rw) / 2;
        mb.append_spaces(pad2);
        mb.append_slice(inner.rows[r]);
        mb.append_spaces(max_w - rw - pad2);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    MathBox res;
    res.width = max_w;
    res.height = total_h;
    res.baseline = base;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}

fn MathBox box_underbrace(logic::Arena* arena, MathBox inner, MathBox label)
{
    int max_w = inner.width > label.width ? inner.width : label.width;
    int lab_h = label.width > 0 ? label.height : 0;
    int total_h = inner.height + 1 + lab_h;
    int base = inner.baseline;

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;

    // Inner rows
    for (int r = 0; r < inner.height; r++)
    {
        mb.reset();
        int rw = strutils::string_display_width(inner.rows[r]);
        int pad = (max_w - rw) / 2;
        mb.append_spaces(pad);
        mb.append_slice(inner.rows[r]);
        mb.append_spaces(max_w - rw - pad);
        r_buf[cur_r++] = mb.to_arena_string(arena);
    }

    // Underbrace glyph: ⏟ or ───┬───
    mb.reset();
    int pad = (max_w - inner.width) / 2;
    mb.append_spaces(pad);
    mb.append_repeat("⏟", inner.width);
    mb.append_spaces(max_w - inner.width - pad);
    r_buf[cur_r++] = mb.to_arena_string(arena);

    // Label rows (centered)
    if (label.width > 0)
    {
        for (int r = 0; r < label.height; r++)
        {
            mb.reset();
            int rw = strutils::string_display_width(label.rows[r]);
            int pad2 = (max_w - rw) / 2;
            mb.append_spaces(pad2);
            mb.append_slice(label.rows[r]);
            mb.append_spaces(max_w - rw - pad2);
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

fn MathBox box_grid_layout(logic::Arena* arena, MathBox[] grid, int num_rows, int num_cols, char align_mode, int col_gap = 2)
{
    if (num_rows <= 0 || num_cols <= 0 || grid.len < (usz)(num_rows * num_cols)) return box_empty(arena);

    int* col_w = (int*)arena.alloc((usz)num_cols * int::size);

    for (int c = 0; c < num_cols; c++)
    {
        int max_cw = 0;
        for (int r = 0; r < num_rows; r++)
        {
            MathBox cell = grid[(usz)(r * num_cols + c)];
            if (cell.width > max_cw) max_cw = cell.width;
        }
        col_w[c] = max_cw;
    }

    int* row_above = (int*)arena.alloc((usz)num_rows * int::size);
    int* row_below = (int*)arena.alloc((usz)num_rows * int::size);
    int* row_h = (int*)arena.alloc((usz)num_rows * int::size);

    int total_h = 0;

    for (int r = 0; r < num_rows; r++)
    {
        int max_above = 0;
        int max_below = 0;
        for (int c = 0; c < num_cols; c++)
        {
            MathBox cell = grid[(usz)(r * num_cols + c)];
            if (cell.baseline > max_above) max_above = cell.baseline;
            int below = cell.height - 1 - cell.baseline;
            if (below > max_below) max_below = below;
        }
        row_above[r] = max_above;
        row_below[r] = max_below;
        row_h[r] = max_above + 1 + max_below;
        total_h += row_h[r];
    }

    int total_w = 0;
    for (int c = 0; c < num_cols; c++)
    {
        total_w += col_w[c];
        if (c > 0) total_w += col_gap;
    }

    String* r_buf = (String*)arena.alloc((usz)total_h * String::size);
    buffer::ByteBuffer mb;
    mb.init(512);
    defer mb.free();

    int cur_r = 0;
    for (int r = 0; r < num_rows; r++)
    {
        int rh = row_h[r];
        int rabove = row_above[r];

        for (int sub_r = 0; sub_r < rh; sub_r++)
        {
            mb.reset();

            for (int c = 0; c < num_cols; c++)
            {
                if (c > 0) mb.append_spaces(col_gap);

                MathBox cell = grid[(usz)(r * num_cols + c)];
                int cell_r = sub_r - (rabove - cell.baseline);
                int target_w = col_w[c];

                if (cell_r >= 0 && cell_r < cell.height)
                {
                    String row_str = cell.rows[cell_r];
                    int rw = strutils::string_display_width(row_str);
                    int pad = target_w - rw;
                    if (pad < 0) pad = 0;

                    // Alignment mode:
                    // 'A' = aligned/align* (even col right-aligned, odd col left-aligned)
                    // 'C' = center-aligned (matrix)
                    // 'L' = left-aligned (cases, array)
                    // 'R' = right-aligned
                    if (align_mode == 'A')
                    {
                        if (c % 2 == 0) // Right aligned
                        {
                            mb.append_spaces(pad);
                            mb.append_slice(row_str);
                        }
                        else // Left aligned
                        {
                            mb.append_slice(row_str);
                            mb.append_spaces(pad);
                        }
                    }
                    else if (align_mode == 'C')
                    {
                        int lpad = pad / 2;
                        int rpad = pad - lpad;
                        mb.append_spaces(lpad);
                        mb.append_slice(row_str);
                        mb.append_spaces(rpad);
                    }
                    else if (align_mode == 'R')
                    {
                        mb.append_spaces(pad);
                        mb.append_slice(row_str);
                    }
                    else // 'L'
                    {
                        mb.append_slice(row_str);
                        mb.append_spaces(pad);
                    }
                }
                else
                {
                    mb.append_spaces(target_w);
                }
            }

            r_buf[cur_r++] = mb.to_arena_string(arena);
        }
    }

    MathBox res;
    res.width = total_w;
    res.height = total_h;
    res.baseline = total_h / 2;
    res.rows = r_buf[0 : (usz)total_h];
    return res;
}
