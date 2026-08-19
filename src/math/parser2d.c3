module math;

import std::core::mem;
import ast;
import strutils;

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

fn bool is_relational_or_binary_sym(String name)
{
    if (strutils::string_eq(name, "pm") || strutils::string_eq(name, "mp") || strutils::string_eq(name, "times") || strutils::string_eq(name, "cdot") || strutils::string_eq(name, "div") || strutils::string_eq(name, "oplus") || strutils::string_eq(name, "ominus") || strutils::string_eq(name, "otimes") || strutils::string_eq(name, "odot") || strutils::string_eq(name, "cap") || strutils::string_eq(name, "cup") || strutils::string_eq(name, "setminus")) return true;
    if (strutils::string_eq(name, "leq") || strutils::string_eq(name, "le") || strutils::string_eq(name, "geq") || strutils::string_eq(name, "ge") || strutils::string_eq(name, "neq") || strutils::string_eq(name, "ne") || strutils::string_eq(name, "approx") || strutils::string_eq(name, "equiv") || strutils::string_eq(name, "sim") || strutils::string_eq(name, "simeq") || strutils::string_eq(name, "cong") || strutils::string_eq(name, "propto") || strutils::string_eq(name, "ll") || strutils::string_eq(name, "gg") || strutils::string_eq(name, "subset") || strutils::string_eq(name, "supset") || strutils::string_eq(name, "subseteq") || strutils::string_eq(name, "supseteq") || strutils::string_eq(name, "in") || strutils::string_eq(name, "notin") || strutils::string_eq(name, "ni") || strutils::string_eq(name, "models") || strutils::string_eq(name, "vdash") || strutils::string_eq(name, "perp") || strutils::string_eq(name, "parallel")) return true;
    if (strutils::string_eq(name, "to") || strutils::string_eq(name, "rightarrow") || strutils::string_eq(name, "leftarrow") || strutils::string_eq(name, "uparrow") || strutils::string_eq(name, "downarrow") || strutils::string_eq(name, "leftrightarrow") || strutils::string_eq(name, "Rightarrow") || strutils::string_eq(name, "Leftarrow") || strutils::string_eq(name, "Leftrightarrow") || strutils::string_eq(name, "implies") || strutils::string_eq(name, "iff") || strutils::string_eq(name, "mapsto") || strutils::string_eq(name, "longrightarrow") || strutils::string_eq(name, "longleftarrow") || strutils::string_eq(name, "Longrightarrow") || strutils::string_eq(name, "Longleftrightarrow")) return true;
    return false;
}

fn MathBox parse_math_term(Math2DParser* p, bool is_first_term = false)
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

        // ── Binomial: \binom{n}{k} ───────────────────────────────────────────
        if (strutils::string_eq(cmd, "binom") || strutils::string_eq(cmd, "dbinom") || strutils::string_eq(cmd, "tbinom"))
        {
            MathBox top_b = parse_math_group(p);
            MathBox bot_b = parse_math_group(p);
            MathBox[2] stack;
            stack[0] = top_b;
            stack[1] = bot_b;
            MathBox inner = box_vconcat_list(p.arena, stack[0:2]);
            return box_delimiters(p.arena, inner, '(', ')');
        }

        // ── Overset & Underset: \overset{top}{base}, \underset{bot}{base} ────
        if (strutils::string_eq(cmd, "overset") || strutils::string_eq(cmd, "stackrel"))
        {
            MathBox top_b = parse_math_group(p);
            MathBox base_b = parse_math_group(p);
            return box_limits_op(p.arena, base_b, box_empty(p.arena), top_b);
        }
        if (strutils::string_eq(cmd, "underset"))
        {
            MathBox bot_b = parse_math_group(p);
            MathBox base_b = parse_math_group(p);
            return box_limits_op(p.arena, base_b, bot_b, box_empty(p.arena));
        }

        // ── Modulo: \pmod{m} ─────────────────────────────────────────────────
        if (strutils::string_eq(cmd, "pmod"))
        {
            MathBox inner = parse_math_group(p);
            MathBox mod_txt = box_from_zstr(p.arena, " (mod ");
            MathBox r_paren = box_from_zstr(p.arena, ")");
            MathBox mid = box_hconcat(p.arena, mod_txt, inner, 0);
            return box_hconcat(p.arena, mid, r_paren, 0);
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
                if (is_relational_or_binary_sym(cmd))
                {
                    MathRowBuilder mb;
                    mb.init(32);
                    defer mb.free();
                    mb.append_char(' ');
                    mb.append_slice(SYMBOLS[s].glyph);
                    mb.append_char(' ');
                    return box_from_string(p.arena, mb.to_arena_string(p.arena));
                }
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

    // 4. Multi-character operators and relations
    if (c == '=') { p.get(); return box_from_zstr(p.arena, " = "); }
    if (c == '+')
    {
        p.get();
        if (is_first_term) return box_from_zstr(p.arena, "+");
        return box_from_zstr(p.arena, " + ");
    }
    if (c == '-')
    {
        p.get();
        if (is_first_term) return box_from_zstr(p.arena, "-");
        return box_from_zstr(p.arena, " - ");
    }
    if (c == '<') { p.get(); return box_from_zstr(p.arena, " < "); }
    if (c == '>') { p.get(); return box_from_zstr(p.arena, " > "); }
    if (c == '*') { p.get(); return box_from_zstr(p.arena, " * "); }
    if (c == ',') { p.get(); return box_from_zstr(p.arena, ", "); }

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

    return parse_math_term(p, true);
}

fn MathBox parse_math_expression(Math2DParser* p, bool stop_at_amp = false, bool stop_at_bslash = false)
{
    MathBox res = box_empty(p.arena);
    bool first_term = true;

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
        MathBox term = parse_math_term(p, first_term);
        first_term = false;

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

fn MathBox render_latex_to_box(ast::Arena* arena, String latex)
{
    Math2DParser parser;
    parser.arena = arena;
    parser.src = latex;
    parser.pos = 0;

    return parse_math_expression(&parser, false, false);
}
