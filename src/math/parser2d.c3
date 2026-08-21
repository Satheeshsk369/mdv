module math;

import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import strutils;
import buffer;

alias MathBoxList = List{MathBox};

struct Math2DParser {
    logic::Arena* arena;
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

fn MathBox parse_math_term(Math2DParser* p, MathAtomKind* prev_atom)
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
        *prev_atom = MathAtomKind.INNER;
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
            *prev_atom = MathAtomKind.ORD;
            return box_from_zstr(p.arena, &ch[0]);
        }
        if (next_c == ',') { p.get(); return box_from_zstr(p.arena, " "); }
        if (next_c == ';') { p.get(); return box_from_zstr(p.arena, "  "); }
        if (next_c == ':') { p.get(); return box_from_zstr(p.arena, " "); }
        if (next_c == '!') { p.get(); return box_empty(p.arena); }
        if (next_c == ' ') { p.get(); return box_from_zstr(p.arena, " "); }
        if (next_c == '|') { p.get(); *prev_atom = MathAtomKind.ORD; return box_from_zstr(p.arena, "║"); }

        // Read command name
        usz cmd_start = p.pos;
        while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z')))
        {
            p.pos++;
        }
        String cmd = p.src[cmd_start : p.pos - cmd_start];

        // ── A. Font Styles via Enum ─────────────────────────────────────────
        MathFontStyle fstyle;
        if (logic::lookup_font_style(cmd, &fstyle))
        {
            p.skip_spaces();
            if (p.peek() == '*') p.get();
            p.skip_spaces();

            switch (fstyle)
            {
                case MATHBB:
                    if (p.peek() == '{')
                    {
                        p.get();
                        buffer::ByteBuffer mb;
                        mb.init(32);
                        defer mb.free();
                        while (!p.eof() && p.peek() != '}')
                        {
                            char* bb = logic::get_mathbb_char(p.get());
                            if (bb != null) mb.append_zstr(bb);
                        }
                        if (p.peek() == '}') p.get();
                        *prev_atom = MathAtomKind.ORD;
                        return box_from_string(p.arena, mb.to_arena_string(p.arena));
                    }
                    char single_bb = p.get();
                    char* bb = logic::get_mathbb_char(single_bb);
                    *prev_atom = MathAtomKind.ORD;
                    if (bb != null) return box_from_zstr(p.arena, bb);
                    char[2] ch_bb; ch_bb[0] = single_bb; ch_bb[1] = 0;
                    return box_from_zstr(p.arena, &ch_bb[0]);

                case MATHCAL:
                    if (p.peek() == '{')
                    {
                        p.get();
                        buffer::ByteBuffer mb;
                        mb.init(32);
                        defer mb.free();
                        while (!p.eof() && p.peek() != '}')
                        {
                            char* cal = logic::get_mathcal_char(p.get());
                            if (cal != null) mb.append_zstr(cal);
                        }
                        if (p.peek() == '}') p.get();
                        *prev_atom = MathAtomKind.ORD;
                        return box_from_string(p.arena, mb.to_arena_string(p.arena));
                    }
                    char single_cal = p.get();
                    char* cal = logic::get_mathcal_char(single_cal);
                    *prev_atom = MathAtomKind.ORD;
                    if (cal != null) return box_from_zstr(p.arena, cal);
                    char[2] ch_cal; ch_cal[0] = single_cal; ch_cal[1] = 0;
                    return box_from_zstr(p.arena, &ch_cal[0]);

                case MATHFRAK:
                    if (p.peek() == '{')
                    {
                        p.get();
                        buffer::ByteBuffer mb;
                        mb.init(32);
                        defer mb.free();
                        while (!p.eof() && p.peek() != '}')
                        {
                            char* fk = logic::get_mathfrak_char(p.get());
                            if (fk != null) mb.append_zstr(fk);
                        }
                        if (p.peek() == '}') p.get();
                        *prev_atom = MathAtomKind.ORD;
                        return box_from_string(p.arena, mb.to_arena_string(p.arena));
                    }
                    char single_fk = p.get();
                    char* fk = logic::get_mathfrak_char(single_fk);
                    *prev_atom = MathAtomKind.ORD;
                    if (fk != null) return box_from_zstr(p.arena, fk);
                    char[2] ch_fk; ch_fk[0] = single_fk; ch_fk[1] = 0;
                    return box_from_zstr(p.arena, &ch_fk[0]);

                default:
                    MathBox grp = parse_math_group(p);
                    *prev_atom = MathAtomKind.ORD;
                    return grp;
            }
        }

        // ── B. Accents via Lookup ──────────────────────────────────────────
        MathAccent accent;
        String combining;
        bool is_overline;
        bool is_underline;
        if (logic::lookup_accent(cmd, &accent, &combining, &is_overline, &is_underline))
        {
            MathBox inner = parse_math_group(p);
            if (is_overline)
            {
                *prev_atom = MathAtomKind.INNER;
                return box_overline(p.arena, inner);
            }
            if (is_underline)
            {
                *prev_atom = MathAtomKind.INNER;
                return box_underline(p.arena, inner);
            }

            buffer::ByteBuffer mb;
            mb.init(64);
            defer mb.free();
            if (inner.height > 0)
            {
                mb.append_slice(inner.rows[0]);
                mb.append_slice(combining);
            }
            *prev_atom = MathAtomKind.ORD;
            return box_from_string(p.arena, mb.to_arena_string(p.arena));
        }

        // ── C. Math Commands via Enum ───────────────────────────────────────
        MathCommand mcmd;
        if (logic::lookup_command(cmd, &mcmd))
        {
            switch (mcmd)
            {
                case TAG:
                    p.skip_spaces();
                    bool starred = false;
                    if (p.peek() == '*') { p.get(); starred = true; }
                    p.skip_spaces();
                    if (p.peek() == '{') p.get();
                    usz t_start = p.pos;
                    while (!p.eof() && p.peek() != '}') p.pos++;
                    String raw_tag = p.src[t_start : p.pos - t_start];
                    if (p.peek() == '}') p.get();

                    buffer::ByteBuffer tb;
                    tb.init(64);
                    defer tb.free();
                    if (!starred) tb.append_char('(');
                    tb.append_slice(raw_tag);
                    if (!starred) tb.append_char(')');
                    *prev_atom = MathAtomKind.ORD;
                    return box_from_string(p.arena, tb.to_arena_string(p.arena));

                case XRIGHTARROW:
                case XLEFTARROW:
                case XLEFTRIGHTARROW:
                    MathBox xsub = box_empty(p.arena);
                    p.skip_spaces();
                    if (p.peek() == '[')
                    {
                        p.get();
                        xsub = parse_math_expression(p, false, false, true);
                        p.skip_spaces();
                        if (p.peek() == ']') p.get();
                    }
                    MathBox xsup = parse_math_group(p);
                    char dir = 'R';
                    if (mcmd == MathCommand.XLEFTARROW)
                    {
                        dir = 'L';
                    }
                    else if (mcmd == MathCommand.XLEFTRIGHTARROW)
                    {
                        dir = 'B';
                    }
                    *prev_atom = MathAtomKind.REL;
                    return box_xarrow(p.arena, xsup, xsub, dir);

                case UNDERLINE:
                    MathBox un_inner = parse_math_group(p);
                    *prev_atom = MathAtomKind.INNER;
                    return box_underline(p.arena, un_inner);

                case OVERRIGHTARROW:
                case OVERLEFTARROW:
                    MathBox o_inner = parse_math_group(p);
                    bool is_right = (mcmd == MathCommand.OVERRIGHTARROW);
                    *prev_atom = MathAtomKind.INNER;
                    return box_overarrow(p.arena, o_inner, is_right);

                case CANCEL:
                case BCANCEL:
                case XCANCEL:
                    MathBox can_inner = parse_math_group(p);
                    *prev_atom = MathAtomKind.ORD;
                    return box_cancel(p.arena, can_inner);

                case COLOR:
                case TEXTCOLOR:
                case MATHCOLOR:
                    p.skip_spaces();
                    if (p.peek() == '{') p.get();
                    usz c_start = p.pos;
                    while (!p.eof() && p.peek() != '}') p.pos++;
                    String c_name = p.src[c_start : p.pos - c_start];
                    if (p.peek() == '}') p.get();

                    char* ansi_col = ansi::fg_cyan;
                    if (c_name == "red" || c_name == "pink") { ansi_col = ansi::fg_pink; }
                    else if (c_name == "green") { ansi_col = ansi::fg_green; }
                    else if (c_name == "orange") { ansi_col = ansi::fg_orange; }
                    else if (c_name == "yellow") { ansi_col = ansi::fg_yellow; }
                    else if (c_name == "purple" || c_name == "magenta") { ansi_col = ansi::fg_purple; }
                    else if (c_name == "gray" || c_name == "grey") { ansi_col = ansi::fg_muted; }

                    MathBox col_inner = parse_math_group(p);
                    *prev_atom = MathAtomKind.INNER;
                    return box_colorize(p.arena, col_inner, ansi_col);

                case FRAC:
                case DFRAC:
                case TFRAC:
                case CFRAC:
                    MathBox num = parse_math_group(p);
                    MathBox den = parse_math_group(p);
                    *prev_atom = MathAtomKind.INNER;
                    return box_fraction(p.arena, num, den);

                case BOXED:
                    MathBox b_inner = parse_math_group(p);
                    *prev_atom = MathAtomKind.INNER;
                    return box_boxed(p.arena, b_inner);

                case BINOM:
                case DBINOM:
                case TBINOM:
                    MathBox top_b = parse_math_group(p);
                    MathBox bot_b = parse_math_group(p);
                    MathBox[2] stack;
                    stack[0] = top_b;
                    stack[1] = bot_b;
                    MathBox binom_inner = box_vconcat_list(p.arena, stack[0:2]);
                    *prev_atom = MathAtomKind.INNER;
                    return box_delimiters(p.arena, binom_inner, '(', ')');

                case OVERSET:
                case STACKREL:
                    MathBox o_top = parse_math_group(p);
                    MathBox o_base = parse_math_group(p);
                    *prev_atom = MathAtomKind.ORD;
                    return box_limits_op(p.arena, o_base, box_empty(p.arena), o_top);

                case UNDERSET:
                    MathBox u_bot = parse_math_group(p);
                    MathBox u_base = parse_math_group(p);
                    *prev_atom = MathAtomKind.ORD;
                    return box_limits_op(p.arena, u_base, u_bot, box_empty(p.arena));

                case OVERBRACE:
                    MathBox ob_inner = parse_math_group(p);
                    MathBox ob_label = box_empty(p.arena);
                    p.skip_spaces();
                    if (p.peek() == '^')
                    {
                        p.get();
                        ob_label = parse_math_group(p);
                    }
                    *prev_atom = MathAtomKind.INNER;
                    return box_overbrace(p.arena, ob_inner, ob_label);

                case UNDERBRACE:
                    MathBox ub_inner = parse_math_group(p);
                    MathBox ub_label = box_empty(p.arena);
                    p.skip_spaces();
                    if (p.peek() == '_')
                    {
                        p.get();
                        ub_label = parse_math_group(p);
                    }
                    *prev_atom = MathAtomKind.INNER;
                    return box_underbrace(p.arena, ub_inner, ub_label);

                case SUBSTACK:
                    p.skip_spaces();
                    if (p.peek() == '{') p.get();
                    List{MathBox} lines;
                    lines.init(mem, 4);
                    defer lines.free();

                    while (!p.eof())
                    {
                        lines.push(parse_math_expression(p, false, true));
                        p.skip_spaces();
                        if (p.peek() == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\')
                        {
                            p.pos += 2;
                        }
                        else if (p.peek() == '}')
                        {
                            p.get();
                            break;
                        }
                        else
                        {
                            break;
                        }
                    }
                    *prev_atom = MathAtomKind.ORD;
                    return box_vconcat_list(p.arena, lines.entries[:(usz)lines.size]);

                case SQRT:
                    MathBox deg = box_empty(p.arena);
                    p.skip_spaces();
                    if (p.peek() == '[')
                    {
                        p.get();
                        deg = parse_math_expression(p, false, false, true);
                        p.skip_spaces();
                        if (p.peek() == ']') p.get();
                    }
                    MathBox sqrt_inner = parse_math_group(p);
                    *prev_atom = MathAtomKind.INNER;
                    return box_sqrt(p.arena, sqrt_inner, deg);

                case SUM:
                    MathBox s_sub = box_empty(p.arena);
                    MathBox s_sup = box_empty(p.arena);
                    for (int k = 0; k < 2; k++)
                    {
                        p.skip_spaces();
                        if (p.peek() == '_') { p.get(); s_sub = parse_math_group(p); }
                        else if (p.peek() == '^') { p.get(); s_sup = parse_math_group(p); }
                    }
                    *prev_atom = MathAtomKind.OP;
                    return box_summation_op(p.arena, s_sub, s_sup);

                case PROD:
                case COPROD:
                    MathBox pr_sub = box_empty(p.arena);
                    MathBox pr_sup = box_empty(p.arena);
                    for (int k = 0; k < 2; k++)
                    {
                        p.skip_spaces();
                        if (p.peek() == '_') { p.get(); pr_sub = parse_math_group(p); }
                        else if (p.peek() == '^') { p.get(); pr_sup = parse_math_group(p); }
                    }
                    *prev_atom = MathAtomKind.OP;
                    return box_product_op(p.arena, pr_sub, pr_sup);

                case BIG_UNION:
                case BIG_INTERSECTION:
                case BIG_PLUS:
                case BIG_TIMES:
                case BIG_DOT:
                case BIG_SQ_CUP:
                case BIG_VEE:
                case BIG_WEDGE:
                    MathBox b_sub = box_empty(p.arena);
                    MathBox b_sup = box_empty(p.arena);
                    for (int k = 0; k < 2; k++)
                    {
                        p.skip_spaces();
                        if (p.peek() == '_') { p.get(); b_sub = parse_math_group(p); }
                        else if (p.peek() == '^') { p.get(); b_sup = parse_math_group(p); }
                    }
                    *prev_atom = MathAtomKind.OP;
                    bool is_inter = (mcmd == MathCommand.BIG_INTERSECTION || mcmd == MathCommand.BIG_WEDGE);
                    return box_big_union_op(p.arena, b_sub, b_sup, is_inter);

                case INT:
                case IINT:
                case IIINT:
                case OINT:
                case OIINT:
                case OIIINT:
                    int order = 1;
                    if (mcmd == MathCommand.IINT || mcmd == MathCommand.OIINT) { order = 2; }
                    if (mcmd == MathCommand.IIINT || mcmd == MathCommand.OIIINT) { order = 3; }

                    MathBox int_sub = box_empty(p.arena);
                    MathBox int_sup = box_empty(p.arena);
                    for (int k = 0; k < 2; k++)
                    {
                        p.skip_spaces();
                        if (p.peek() == '_') { p.get(); int_sub = parse_math_group(p); }
                        else if (p.peek() == '^') { p.get(); int_sup = parse_math_group(p); }
                    }
                    *prev_atom = MathAtomKind.OP;
                    return box_integral_op(p.arena, int_sub, int_sup, order);

                case LIM:
                case LIMINF:
                case LIMSUP:
                case MAX:
                case MIN:
                case SUP:
                case INF:
                case ARGMAX:
                case ARGMIN:
                    String op_name = cmd;
                    if (mcmd == MathCommand.LIMINF) { op_name = "lim inf"; }
                    else if (mcmd == MathCommand.LIMSUP) { op_name = "lim sup"; }
                    else if (mcmd == MathCommand.ARGMAX) { op_name = "arg max"; }
                    else if (mcmd == MathCommand.ARGMIN) { op_name = "arg min"; }

                    MathBox op_box = box_from_string(p.arena, op_name);
                    MathBox lim_sub = box_empty(p.arena);
                    MathBox lim_sup = box_empty(p.arena);
                    for (int k = 0; k < 2; k++)
                    {
                        p.skip_spaces();
                        if (p.peek() == '_') { p.get(); lim_sub = parse_math_group(p); }
                        else if (p.peek() == '^') { p.get(); lim_sup = parse_math_group(p); }
                    }
                    *prev_atom = MathAtomKind.OP;
                    return box_limits_op(p.arena, op_box, lim_sub, lim_sup);

                case PMOD:
                case POD:
                    MathBox m_box = parse_math_group(p);
                    buffer::ByteBuffer pmod_mb;
                    pmod_mb.init(64);
                    defer pmod_mb.free();
                    pmod_mb.append_zstr(" (");
                    if (mcmd == MathCommand.PMOD) pmod_mb.append_zstr("mod ");
                    if (m_box.rows.len > 0) pmod_mb.append_slice(m_box.rows[0]);
                    pmod_mb.append_char(')');
                    *prev_atom = MathAtomKind.ORD;
                    return box_from_string(p.arena, pmod_mb.to_arena_string(p.arena));

                case BMOD:
                    *prev_atom = MathAtomKind.BIN;
                    return box_from_zstr(p.arena, " mod ");

                case QUAD:
                    return box_spaces(p.arena, 4);

                case QQUAD:
                    return box_spaces(p.arena, 8);

                case LEFT:
                    p.skip_spaces();
                    char open_ch = p.get();
                    if (open_ch == '\\')
                    {
                        usz d_start = p.pos;
                        while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
                        String d_name = p.src[d_start : p.pos - d_start];

                        if (d_name == "lfloor") { open_ch = 'F'; }
                        else if (d_name == "lceil") { open_ch = 'C'; }
                        else if (d_name == "langle") { open_ch = '<'; }
                        else if (d_name == "lbrace" || d_name == "{") { open_ch = '{'; }
                        else if (d_name == "rbrace" || d_name == "}") { open_ch = '}'; }
                        else if (d_name == "vert" || d_name == "|") { open_ch = '|'; }
                        else if (d_name == "Vert") { open_ch = 'V'; }
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
                        if (r_cmd == "right")
                        {
                            p.skip_spaces();
                            close_ch = p.get();
                            if (close_ch == '\\')
                            {
                                usz rd_start = p.pos;
                                while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
                                String rd_name = p.src[rd_start : p.pos - rd_start];

                                if (rd_name == "rfloor") { close_ch = 'F'; }
                                else if (rd_name == "rceil") { close_ch = 'C'; }
                                else if (rd_name == "rangle") { close_ch = '>'; }
                                else if (rd_name == "lbrace" || rd_name == "{") { close_ch = '{'; }
                                else if (rd_name == "rbrace" || rd_name == "}") { close_ch = '}'; }
                                else if (rd_name == "vert" || rd_name == "|") { close_ch = '|'; }
                                else if (rd_name == "Vert") { close_ch = 'V'; }
                            }
                            if (close_ch == '.') close_ch = 0;
                        }
                    }

                    *prev_atom = MathAtomKind.INNER;
                    return box_delimiters(p.arena, inner, open_ch, close_ch);

                case BEGIN:
                    p.skip_spaces();
                    if (p.peek() == '{') p.get();
                    usz env_start = p.pos;
                    while (!p.eof() && p.peek() != '}') p.pos++;
                    String env_name = p.src[env_start : p.pos - env_start];
                    if (p.peek() == '}') p.get();

                    if (env_name == "array")
                    {
                        p.skip_spaces();
                        if (p.peek() == '{')
                        {
                            p.get();
                            while (!p.eof() && p.peek() != '}') p.pos++;
                            if (p.peek() == '}') p.get();
                        }
                    }

                    List{MathBoxList} env_rows;
                    env_rows.init(mem, 8);
                    defer {
                        for (sz r = 0; r < env_rows.size; r++) env_rows.entries[r].free();
                        env_rows.free();
                    }

                    MathBoxList cur_row;
                    cur_row.init(mem, 4);

                    int max_cols = 0;

                    while (!p.eof())
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
                            if (check_cmd == "end")
                            {
                                p.skip_spaces();
                                if (p.peek() == '{') p.get();
                                while (!p.eof() && p.peek() != '}') p.pos++;
                                if (p.peek() == '}') p.get();
                                if (cur_row.size > 0)
                                {
                                    if ((int)cur_row.size > max_cols) max_cols = (int)cur_row.size;
                                    env_rows.push(cur_row);
                                    cur_row.init(mem, 4);
                                }
                                break;
                            }
                            else if (save_pos + 1 < (usz)p.src.len && p.src[save_pos + 1] == '\\') // double backslash \\
                            {
                                p.pos = save_pos + 2;
                                if ((int)cur_row.size > max_cols) max_cols = (int)cur_row.size;
                                env_rows.push(cur_row);
                                cur_row.init(mem, 4);
                                continue;
                            }
                            else
                            {
                                p.pos = save_pos;
                            }
                        }

                        MathBox cell = parse_math_expression(p, true, true);
                        cur_row.push(cell);

                        p.skip_spaces();
                        if (p.peek() == '&')
                        {
                            p.get(); // consume '&'
                        }
                        else if (p.peek() == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\')
                        {
                            p.pos += 2;
                            if ((int)cur_row.size > max_cols) max_cols = (int)cur_row.size;
                            env_rows.push(cur_row);
                            cur_row.init(mem, 4);
                        }
                    }

                    if (cur_row.size > 0)
                    {
                        if ((int)cur_row.size > max_cols) max_cols = (int)cur_row.size;
                        env_rows.push(cur_row);
                    }
                    else
                    {
                        cur_row.free();
                    }

                    int num_rows = (int)env_rows.size;
                    int num_cols = max_cols > 0 ? max_cols : 1;

                    // Flatten into 1D array of size num_rows * num_cols
                    MathBox* flat_buf = (MathBox*)p.arena.alloc((usz)(num_rows * num_cols) * MathBox::size);
                    for (int r = 0; r < num_rows; r++)
                    {
                        MathBoxList row = env_rows.entries[(usz)r];
                        for (int col = 0; col < num_cols; col++)
                        {
                            flat_buf[(usz)(r * num_cols + col)] = (col < (int)row.size) ? row.entries[(usz)col] : box_empty(p.arena);
                        }
                    }
                    MathBox[] flat_grid = flat_buf[: (usz)(num_rows * num_cols)];

                    *prev_atom = MathAtomKind.INNER;

                    MathEnvironment menv;
                    MathEnvFlags env_flags;
                    if (logic::lookup_environment(env_name, &menv, &env_flags))
                    {
                        MathBox inner = box_grid_layout(p.arena, flat_grid, num_rows, num_cols, env_flags.align_mode, (int)env_flags.col_gap);
                        if (env_flags.delim_left != 0 || env_flags.delim_right != 0)
                        {
                            return box_delimiters(p.arena, inner, env_flags.delim_left, env_flags.delim_right);
                        }
                        return inner;
                    }

                    return box_grid_layout(p.arena, flat_grid, num_rows, num_cols, 'C', 2);

                case TEXT:
                    p.skip_spaces();
                    if (p.peek() == '{')
                    {
                        p.get();
                        usz txt_start = p.pos;
                        while (!p.eof() && p.peek() != '}') p.pos++;
                        String txt = p.src[txt_start : p.pos - txt_start];
                        if (p.peek() == '}') p.get();
                        *prev_atom = MathAtomKind.ORD;
                        return box_from_string(p.arena, txt);
                    }
                    *prev_atom = MathAtomKind.ORD;
                    return box_from_string(p.arena, "text");

                case OPERATORNAME:
                    MathBox op_box = parse_math_group(p);
                    *prev_atom = MathAtomKind.OP;
                    return op_box;
            }
        }

        // ── D. Symbol Table Lookup via Modular Table ─────────────────────────
        String sym_glyph;
        MathAtomKind sym_kind;
        if (logic::lookup_symbol(cmd, &sym_glyph, &sym_kind))
        {
            *prev_atom = sym_kind;
            if (sym_kind == MathAtomKind.REL || sym_kind == MathAtomKind.BIN)
            {
                buffer::ByteBuffer mb;
                mb.init(32);
                defer mb.free();
                mb.append_char(' ');
                mb.append_slice(sym_glyph);
                mb.append_char(' ');
                return box_from_string(p.arena, mb.to_arena_string(p.arena));
            }
            return box_from_string(p.arena, sym_glyph);
        }

        *prev_atom = MathAtomKind.ORD;
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
        *prev_atom = MathAtomKind.ORD;
        return box_from_string(p.arena, num_str);
    }

    // 4. Primes: ', '', '''
    if (c == '\'')
    {
        int prime_count = 0;
        while (!p.eof() && p.peek() == '\'')
        {
            prime_count++;
            p.get();
        }
        *prev_atom = MathAtomKind.ORD;
        if (prime_count == 1) return box_from_zstr(p.arena, "′");
        if (prime_count == 2) return box_from_zstr(p.arena, "″");
        if (prime_count == 3) return box_from_zstr(p.arena, "‴");
        buffer::ByteBuffer pb;
        pb.init(16);
        defer pb.free();
        for (int k = 0; k < prime_count; k++) pb.append_zstr("′");
        return box_from_string(p.arena, pb.to_arena_string(p.arena));
    }

    // 5. Optical Operators & Relations
    if (c == '=')
    {
        p.get();
        *prev_atom = MathAtomKind.REL;
        return box_from_zstr(p.arena, " = ");
    }
    if (c == '+')
    {
        p.get();
        if (*prev_atom == MathAtomKind.ORD || *prev_atom == MathAtomKind.CLOSE || *prev_atom == MathAtomKind.INNER)
        {
            *prev_atom = MathAtomKind.BIN;
            return box_from_zstr(p.arena, " + ");
        }
        *prev_atom = MathAtomKind.ORD;
        return box_from_zstr(p.arena, "+");
    }
    if (c == '-')
    {
        p.get();
        if (*prev_atom == MathAtomKind.ORD || *prev_atom == MathAtomKind.CLOSE || *prev_atom == MathAtomKind.INNER)
        {
            *prev_atom = MathAtomKind.BIN;
            return box_from_zstr(p.arena, " - ");
        }
        *prev_atom = MathAtomKind.ORD;
        return box_from_zstr(p.arena, "-");
    }
    if (c == '<') { p.get(); *prev_atom = MathAtomKind.REL; return box_from_zstr(p.arena, " < "); }
    if (c == '>') { p.get(); *prev_atom = MathAtomKind.REL; return box_from_zstr(p.arena, " > "); }
    if (c == '*') { p.get(); *prev_atom = MathAtomKind.BIN; return box_from_zstr(p.arena, " * "); }
    if (c == ',') { p.get(); *prev_atom = MathAtomKind.PUNCT; return box_from_zstr(p.arena, ", "); }
    if (c == ';') { p.get(); *prev_atom = MathAtomKind.PUNCT; return box_from_zstr(p.arena, "; "); }
    if (c == '(' || c == '[') { p.get(); *prev_atom = MathAtomKind.OPEN; char[2] ch; ch[0] = c; ch[1] = 0; return box_from_zstr(p.arena, &ch[0]); }
    if (c == ')' || c == ']') { p.get(); *prev_atom = MathAtomKind.CLOSE; char[2] ch; ch[0] = c; ch[1] = 0; return box_from_zstr(p.arena, &ch[0]); }

    // 6. Normal character
    p.get();
    *prev_atom = MathAtomKind.ORD;
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

    // Single-token argument (e.g. \frac 1 2, \sqrt 2, \vec v, x^2)
    MathAtomKind atom = MathAtomKind.ORD;
    return parse_math_term(p, &atom);
}

fn MathBox parse_math_expression(Math2DParser* p, bool stop_at_amp = false, bool stop_at_bslash = false, bool stop_at_rbracket = false)
{
    MathBox res = box_empty(p.arena);
    MathAtomKind prev_atom = MathAtomKind.OPEN; // Start of expression

    while (!p.eof())
    {
        p.skip_spaces();
        if (p.eof()) break;

        char c = p.peek();
        if (c == '}') break;
        if (stop_at_rbracket && c == ']') break;
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

            if (check_cmd == "right" || check_cmd == "end")
            {
                break;
            }
        }

        // Parse base term with optical atom tracking
        MathBox term = parse_math_term(p, &prev_atom);

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
        res = box_hconcat(p.arena, res, term, 0);
    }

    return res;
}

fn MathBox render_latex_to_box(logic::Arena* arena, String latex)
{
    Math2DParser parser;
    parser.arena = arena;
    parser.src = latex;
    parser.pos = 0;

    return parse_math_expression(&parser, false, false);
}
