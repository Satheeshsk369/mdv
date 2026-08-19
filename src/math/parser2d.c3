module math;

import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import strutils;
import buffer;

alias MathBoxList = List{MathBox};

enum MathAtomKind {
    ORD,    // Ordinary symbol or variable (x, 2, \alpha)
    OP,     // Big operator or named function (\sum, \sin, \lim)
    BIN,    // Binary operator (+, -, \times, \cdot, \pm)
    REL,    // Relation (=, \le, \ge, \neq, \approx, \to)
    OPEN,   // Open delimiter ((, [, {, \langle)
    CLOSE,  // Close delimiter (), ], }, \rangle)
    PUNCT,  // Punctuation (,, ;, :)
    INNER   // Fractions, radicals, boxes
}

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

fn bool is_relational_sym(String name)
{
    if (strutils::string_eq(name, "leq") || strutils::string_eq(name, "le") || strutils::string_eq(name, "geq") || strutils::string_eq(name, "ge") || strutils::string_eq(name, "neq") || strutils::string_eq(name, "ne") || strutils::string_eq(name, "approx") || strutils::string_eq(name, "equiv") || strutils::string_eq(name, "sim") || strutils::string_eq(name, "simeq") || strutils::string_eq(name, "cong") || strutils::string_eq(name, "propto") || strutils::string_eq(name, "ll") || strutils::string_eq(name, "gg") || strutils::string_eq(name, "subset") || strutils::string_eq(name, "supset") || strutils::string_eq(name, "subseteq") || strutils::string_eq(name, "supseteq") || strutils::string_eq(name, "in") || strutils::string_eq(name, "notin") || strutils::string_eq(name, "ni") || strutils::string_eq(name, "models") || strutils::string_eq(name, "vdash") || strutils::string_eq(name, "perp") || strutils::string_eq(name, "parallel")) return true;
    if (strutils::string_eq(name, "to") || strutils::string_eq(name, "rightarrow") || strutils::string_eq(name, "leftarrow") || strutils::string_eq(name, "uparrow") || strutils::string_eq(name, "downarrow") || strutils::string_eq(name, "leftrightarrow") || strutils::string_eq(name, "Rightarrow") || strutils::string_eq(name, "Leftarrow") || strutils::string_eq(name, "Leftrightarrow") || strutils::string_eq(name, "implies") || strutils::string_eq(name, "iff") || strutils::string_eq(name, "mapsto") || strutils::string_eq(name, "longrightarrow") || strutils::string_eq(name, "longleftarrow") || strutils::string_eq(name, "Longrightarrow") || strutils::string_eq(name, "Longleftrightarrow")) return true;
    return false;
}

fn bool is_binary_sym(String name)
{
    if (strutils::string_eq(name, "pm") || strutils::string_eq(name, "mp") || strutils::string_eq(name, "times") || strutils::string_eq(name, "cdot") || strutils::string_eq(name, "div") || strutils::string_eq(name, "oplus") || strutils::string_eq(name, "ominus") || strutils::string_eq(name, "otimes") || strutils::string_eq(name, "odot") || strutils::string_eq(name, "cap") || strutils::string_eq(name, "cup") || strutils::string_eq(name, "setminus") || strutils::string_eq(name, "ast") || strutils::string_eq(name, "star") || strutils::string_eq(name, "circ") || strutils::string_eq(name, "bullet")) return true;
    return false;
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

        // ── Tag: \tag{label}, \tag*{label} ──────────────────────────────────
        if (strutils::string_eq(cmd, "tag"))
        {
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
        }

        // ── Long Vectors: \overrightarrow{AB}, \overleftarrow{AB} ───────────
        if (strutils::string_eq(cmd, "overrightarrow") || strutils::string_eq(cmd, "overleftarrow"))
        {
            MathBox inner = parse_math_group(p);
            bool is_right = strutils::string_eq(cmd, "overrightarrow");
            *prev_atom = MathAtomKind.INNER;
            return box_overarrow(p.arena, inner, is_right);
        }

        // ── Cancellation: \cancel{x}, \bcancel, \xcancel ────────────────────
        if (strutils::string_eq(cmd, "cancel") || strutils::string_eq(cmd, "bcancel") || strutils::string_eq(cmd, "xcancel"))
        {
            MathBox inner = parse_math_group(p);
            *prev_atom = MathAtomKind.ORD;
            return box_cancel(p.arena, inner);
        }

        // ── Color: \color{name}{expr}, \textcolor, \mathcolor ───────────────
        if (strutils::string_eq(cmd, "color") || strutils::string_eq(cmd, "textcolor") || strutils::string_eq(cmd, "mathcolor"))
        {
            p.skip_spaces();
            if (p.peek() == '{') p.get();
            usz c_start = p.pos;
            while (!p.eof() && p.peek() != '}') p.pos++;
            String c_name = p.src[c_start : p.pos - c_start];
            if (p.peek() == '}') p.get();

            char* ansi_col = (char*)ansi::FG_CYAN;
            if (strutils::string_eq(c_name, "red") || strutils::string_eq(c_name, "pink")) { ansi_col = (char*)ansi::FG_PINK; }
            else if (strutils::string_eq(c_name, "green")) { ansi_col = (char*)ansi::FG_GREEN; }
            else if (strutils::string_eq(c_name, "orange")) { ansi_col = (char*)ansi::FG_ORANGE; }
            else if (strutils::string_eq(c_name, "yellow")) { ansi_col = (char*)ansi::FG_YELLOW; }
            else if (strutils::string_eq(c_name, "purple") || strutils::string_eq(c_name, "magenta")) { ansi_col = (char*)ansi::FG_PURPLE; }
            else if (strutils::string_eq(c_name, "gray") || strutils::string_eq(c_name, "grey")) { ansi_col = (char*)ansi::FG_MUTED; }

            MathBox inner = parse_math_group(p);
            *prev_atom = MathAtomKind.INNER;
            return box_colorize(p.arena, inner, ansi_col);
        }

        // ── Fractions: \frac{num}{den}, \dfrac, \tfrac, \cfrac ──────────────
        if (strutils::string_eq(cmd, "frac") || strutils::string_eq(cmd, "dfrac") || strutils::string_eq(cmd, "tfrac") || strutils::string_eq(cmd, "cfrac"))
        {
            MathBox num = parse_math_group(p);
            MathBox den = parse_math_group(p);
            *prev_atom = MathAtomKind.INNER;
            return box_fraction(p.arena, num, den);
        }

        // ── Boxed: \boxed{expr} ──────────────────────────────────────────────
        if (strutils::string_eq(cmd, "boxed"))
        {
            MathBox inner = parse_math_group(p);
            *prev_atom = MathAtomKind.INNER;
            return box_boxed(p.arena, inner);
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
            *prev_atom = MathAtomKind.INNER;
            return box_delimiters(p.arena, inner, '(', ')');
        }

        // ── Overset & Underset: \overset{top}{base}, \underset{bot}{base} ────
        if (strutils::string_eq(cmd, "overset") || strutils::string_eq(cmd, "stackrel"))
        {
            MathBox top_b = parse_math_group(p);
            MathBox base_b = parse_math_group(p);
            *prev_atom = MathAtomKind.ORD;
            return box_limits_op(p.arena, base_b, box_empty(p.arena), top_b);
        }
        if (strutils::string_eq(cmd, "underset"))
        {
            MathBox bot_b = parse_math_group(p);
            MathBox base_b = parse_math_group(p);
            *prev_atom = MathAtomKind.ORD;
            return box_limits_op(p.arena, base_b, bot_b, box_empty(p.arena));
        }

        // ── Overbrace & Underbrace ───────────────────────────────────────────
        if (strutils::string_eq(cmd, "overbrace"))
        {
            MathBox inner = parse_math_group(p);
            MathBox label = box_empty(p.arena);
            p.skip_spaces();
            if (p.peek() == '^')
            {
                p.get();
                label = parse_math_group(p);
            }
            *prev_atom = MathAtomKind.INNER;
            return box_overbrace(p.arena, inner, label);
        }
        if (strutils::string_eq(cmd, "underbrace"))
        {
            MathBox inner = parse_math_group(p);
            MathBox label = box_empty(p.arena);
            p.skip_spaces();
            if (p.peek() == '_')
            {
                p.get();
                label = parse_math_group(p);
            }
            *prev_atom = MathAtomKind.INNER;
            return box_underbrace(p.arena, inner, label);
        }

        // ── Substack: \substack{line1 \\ line2} ──────────────────────────────
        if (strutils::string_eq(cmd, "substack"))
        {
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
        }

        // ── Square Root: \sqrt[n]{expr} ──────────────────────────────────────
        if (strutils::string_eq(cmd, "sqrt"))
        {
            MathBox deg = box_empty(p.arena);
            p.skip_spaces();
            if (p.peek() == '[')
            {
                p.get();
                deg = parse_math_expression(p, false, false);
                p.skip_spaces();
                if (p.peek() == ']') p.get();
            }
            MathBox inner = parse_math_group(p);
            *prev_atom = MathAtomKind.INNER;
            return box_sqrt(p.arena, inner, deg);
        }

        // ── Summation: \sum ──────────────────────────────────────────────────
        if (strutils::string_eq(cmd, "sum"))
        {
            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_') { p.get(); sub = parse_math_group(p); }
                else if (p.peek() == '^') { p.get(); sup = parse_math_group(p); }
            }
            *prev_atom = MathAtomKind.OP;
            return box_summation_op(p.arena, sub, sup);
        }

        // ── Product & Coproduct: \prod, \coprod ──────────────────────────────
        if (strutils::string_eq(cmd, "prod") || strutils::string_eq(cmd, "coprod"))
        {
            MathBox sub = box_empty(p.arena);
            MathBox sup = box_empty(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skip_spaces();
                if (p.peek() == '_') { p.get(); sub = parse_math_group(p); }
                else if (p.peek() == '^') { p.get(); sup = parse_math_group(p); }
            }
            *prev_atom = MathAtomKind.OP;
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
            *prev_atom = MathAtomKind.OP;
            return box_integral_op(p.arena, sub, sup, order);
        }

        // ── Limits: \lim, \max, \min, \sup, \inf, \argmax, \argmin ───────────
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
            *prev_atom = MathAtomKind.OP;
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
                else if (next_delim == '|') { open_ch = 'V'; }
                else if (next_delim == '<' || next_delim == 'l') { open_ch = '<'; }
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

            *prev_atom = MathAtomKind.INNER;
            return box_delimiters(p.arena, inner, open_ch, close_ch);
        }

        // ── Multi-Equation Environments & Matrices ───────────────────────────
        if (strutils::string_eq(cmd, "begin"))
        {
            p.skip_spaces();
            if (p.peek() == '{') p.get();
            usz env_start = p.pos;
            while (!p.eof() && p.peek() != '}') p.pos++;
            String env_name = p.src[env_start : p.pos - env_start];
            if (p.peek() == '}') p.get();

            // Optional array column format e.g. {c c c}
            if (strutils::string_eq(env_name, "array"))
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
                    if (strutils::string_eq(check_cmd, "end"))
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

            // 1. Cases
            if (strutils::string_eq(env_name, "cases"))
            {
                MathBox inner = box_grid_layout(p.arena, flat_grid[: (usz)(num_rows * num_cols)], num_rows, num_cols, 'L', 3);
                return box_delimiters(p.arena, inner, '{', (char)0);
            }

            // 2. Align / Aligned / Split / Array
            if (strutils::string_eq(env_name, "align") || strutils::string_eq(env_name, "align*") || strutils::string_eq(env_name, "aligned") || strutils::string_eq(env_name, "split") || strutils::string_eq(env_name, "array"))
            {
                return box_grid_layout(p.arena, flat_grid[: (usz)(num_rows * num_cols)], num_rows, num_cols, 'A', 0);
            }

            // 3. Gather / Gather*
            if (strutils::string_eq(env_name, "gather") || strutils::string_eq(env_name, "gather*"))
            {
                return box_grid_layout(p.arena, flat_grid[: (usz)(num_rows * num_cols)], num_rows, num_cols, 'C', 0);
            }

            // 4. Matrices: matrix, pmatrix, bmatrix, vmatrix, Vmatrix, Bmatrix, smallmatrix
            char bracket_type = 'm';
            if (strutils::string_eq(env_name, "pmatrix")) { bracket_type = 'p'; }
            else if (strutils::string_eq(env_name, "bmatrix")) { bracket_type = 'b'; }
            else if (strutils::string_eq(env_name, "vmatrix")) { bracket_type = 'v'; }
            else if (strutils::string_eq(env_name, "Vmatrix")) { bracket_type = 'V'; }
            else if (strutils::string_eq(env_name, "Bmatrix")) { bracket_type = 'B'; }

            MathBox inner = box_grid_layout(p.arena, flat_grid[: (usz)(num_rows * num_cols)], num_rows, num_cols, 'C', 2);

            char open_b = '['; char close_b = ']';
            if (bracket_type == 'p') { open_b = '('; close_b = ')'; }
            else if (bracket_type == 'v') { open_b = '|'; close_b = '|'; }
            else if (bracket_type == 'V') { open_b = 'V'; close_b = 'V'; }
            else if (bracket_type == 'B') { open_b = '{'; close_b = '}'; }
            else if (bracket_type == 'm') { return inner; }

            return box_delimiters(p.arena, inner, open_b, close_b);
        }

        // ── Text / Style Wrappers: \text, \mathbf, \mathbb, \operatorname ───
        if (strutils::string_eq(cmd, "text"))
        {
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                usz t_start = p.pos;
                while (!p.eof() && p.peek() != '}') p.pos++;
                String txt = p.src[t_start : p.pos - t_start];
                if (p.peek() == '}') p.get();
                *prev_atom = MathAtomKind.ORD;
                return box_from_string(p.arena, txt);
            }
        }
        if (strutils::string_eq(cmd, "mathbf") || strutils::string_eq(cmd, "mathrm") || strutils::string_eq(cmd, "operatorname") || strutils::string_eq(cmd, "mathit") || strutils::string_eq(cmd, "mathsf") || strutils::string_eq(cmd, "mathtt"))
        {
            p.skip_spaces();
            if (p.peek() == '*') p.get();
            MathBox grp = parse_math_group(p);
            *prev_atom = MathAtomKind.ORD;
            return grp;
        }
        if (strutils::string_eq(cmd, "mathbb"))
        {
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                buffer::ByteBuffer mb;
                mb.init(32);
                defer mb.free();
                while (!p.eof() && p.peek() != '}')
                {
                    char* bb = get_mathbb_char(p.get());
                    if (bb != null) mb.append_zstr(bb);
                }
                if (p.peek() == '}') p.get();
                *prev_atom = MathAtomKind.ORD;
                return box_from_string(p.arena, mb.to_arena_string(p.arena));
            }
            char single_c = p.get();
            char* bb = get_mathbb_char(single_c);
            *prev_atom = MathAtomKind.ORD;
            if (bb != null) return box_from_zstr(p.arena, bb);
            char[2] ch; ch[0] = single_c; ch[1] = 0;
            return box_from_zstr(p.arena, &ch[0]);
        }
        if (strutils::string_eq(cmd, "mathcal") || strutils::string_eq(cmd, "mathscr"))
        {
            p.skip_spaces();
            if (p.peek() == '{')
            {
                p.get();
                buffer::ByteBuffer mb;
                mb.init(32);
                defer mb.free();
                while (!p.eof() && p.peek() != '}')
                {
                    char* cal = get_mathcal_char(p.get());
                    if (cal != null) mb.append_zstr(cal);
                }
                if (p.peek() == '}') p.get();
                *prev_atom = MathAtomKind.ORD;
                return box_from_string(p.arena, mb.to_arena_string(p.arena));
            }
            char single_c = p.get();
            char* cal = get_mathcal_char(single_c);
            *prev_atom = MathAtomKind.ORD;
            if (cal != null) return box_from_zstr(p.arena, cal);
            char[2] ch; ch[0] = single_c; ch[1] = 0;
            return box_from_zstr(p.arena, &ch[0]);
        }

        // ── Accents: \vec, \hat, \bar, \dot, \ddot, \tilde, \overline ───────
        if (strutils::string_eq(cmd, "overline"))
        {
            MathBox inner = parse_math_group(p);
            *prev_atom = MathAtomKind.INNER;
            return box_overline(p.arena, inner);
        }
        if (strutils::string_eq(cmd, "vec") || strutils::string_eq(cmd, "hat") || strutils::string_eq(cmd, "bar") || strutils::string_eq(cmd, "dot") || strutils::string_eq(cmd, "ddot") || strutils::string_eq(cmd, "tilde"))
        {
            MathBox inner = parse_math_group(p);
            char* combining = "⃗";
            if (strutils::string_eq(cmd, "hat")) { combining = "̂"; }
            else if (strutils::string_eq(cmd, "bar")) { combining = "̄"; }
            else if (strutils::string_eq(cmd, "dot")) { combining = "̇"; }
            else if (strutils::string_eq(cmd, "ddot")) { combining = "̈"; }
            else if (strutils::string_eq(cmd, "tilde")) { combining = "̃"; }

            buffer::ByteBuffer mb;
            mb.init(64);
            defer mb.free();
            if (inner.height > 0)
            {
                mb.append_slice(inner.rows[0]);
                mb.append_zstr(combining);
            }
            *prev_atom = MathAtomKind.ORD;
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
                if (is_relational_sym(cmd))
                {
                    *prev_atom = MathAtomKind.REL;
                    buffer::ByteBuffer mb;
                    mb.init(32);
                    defer mb.free();
                    mb.append_char(' ');
                    mb.append_slice(SYMBOLS[s].glyph);
                    mb.append_char(' ');
                    return box_from_string(p.arena, mb.to_arena_string(p.arena));
                }
                if (is_binary_sym(cmd))
                {
                    // Optical unary vs binary distinction
                    if (*prev_atom == MathAtomKind.ORD || *prev_atom == MathAtomKind.CLOSE || *prev_atom == MathAtomKind.INNER)
                    {
                        *prev_atom = MathAtomKind.BIN;
                        buffer::ByteBuffer mb;
                        mb.init(32);
                        defer mb.free();
                        mb.append_char(' ');
                        mb.append_slice(SYMBOLS[s].glyph);
                        mb.append_char(' ');
                        return box_from_string(p.arena, mb.to_arena_string(p.arena));
                    }
                    else
                    {
                        *prev_atom = MathAtomKind.ORD;
                        return box_from_string(p.arena, SYMBOLS[s].glyph);
                    }
                }
                *prev_atom = MathAtomKind.ORD;
                return box_from_string(p.arena, SYMBOLS[s].glyph);
            }
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

    // 4. Optical Operators & Relations
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

    // 5. Normal character
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

fn MathBox parse_math_expression(Math2DParser* p, bool stop_at_amp = false, bool stop_at_bslash = false)
{
    MathBox res = box_empty(p.arena);
    MathAtomKind prev_atom = MathAtomKind.OPEN; // Start of expression

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

fn MathBox render_latex_to_box(ast::Arena* arena, String latex)
{
    Math2DParser parser;
    parser.arena = arena;
    parser.src = latex;
    parser.pos = 0;

    return parse_math_expression(&parser, false, false);
}
