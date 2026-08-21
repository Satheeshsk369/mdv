module math;

import std::core::mem;
import logic;
import strutils;
import buffer;

fn String transform_math(logic::Arena* arena, String input)
{
    if (input.len == 0) return "";

    buffer::ByteBuffer mb;
    mb.init((usz)input.len * 4 + 256);
    defer mb.free();

    usz i = 0;

    while (i < (usz)input.len)
    {
        char c = input[i];

        // ── 1. LaTeX Math Backslash Commands & Spaces ────────────────────────
        if (c == '\\')
        {
            if (i + 1 < (usz)input.len)
            {
                char next_c = input[i + 1];
                if (next_c == '{' || next_c == '}')
                {
                    mb.append_char(next_c);
                    i += 2;
                    continue;
                }
                if (next_c == ',')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ':')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ';')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == '!')
                {
                    i += 2;
                    continue;
                }
                if (next_c == ' ')
                {
                    mb.append_char(' ');
                    i += 2;
                    continue;
                }
                if (next_c == '%')
                {
                    mb.append_char('%');
                    i += 2;
                    continue;
                }
                if (next_c == '$')
                {
                    mb.append_char('$');
                    i += 2;
                    continue;
                }
            }

            // Command name scanner
            usz cmd_start = i + 1;
            usz cmd_end = cmd_start;
            while (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z')))
            {
                cmd_end++;
            }

            String cmd = input[cmd_start : cmd_end - cmd_start];

            // ── Quad Spacing ─────────────────────────────────────────────────
            if (cmd == "quad")
            {
                mb.append_zstr(" ");
                i = cmd_end;
                continue;
            }
            if (cmd == "qquad")
            {
                mb.append_zstr("  ");
                i = cmd_end;
                continue;
            }

            // ── Modulo ───────────────────────────────────────────────────────
            if (cmd == "pmod" || cmd == "pod")
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz m_start = i;
                    while (i < (usz)input.len && input[i] != '}') i++;
                    String m_content = input[m_start : i - m_start];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_m = transform_math(arena, m_content);
                    mb.append_zstr(" (");
                    if (cmd == "pmod") mb.append_zstr("mod ");
                    mb.append_slice(t_m);
                    mb.append_char(')');
                    continue;
                }
            }
            if (cmd == "bmod")
            {
                mb.append_zstr(" mod ");
                i = cmd_end;
                continue;
            }

            // ── Font Styles via Enum ─────────────────────────────────────────
            MathFontStyle fstyle;
            if (logic::lookup_font_style(cmd, &fstyle))
            {
                i = cmd_end;
                while (i < (usz)input.len && (input[i] == ' ' || input[i] == '*')) i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        char ch = input[i++];
                        char* mapped = null;
                        switch (fstyle)
                        {
                            case MATHBB: mapped = logic::get_mathbb_char(ch);
                            case MATHCAL: mapped = logic::get_mathcal_char(ch);
                            case MATHFRAK: mapped = logic::get_mathfrak_char(ch);
                            default: mapped = null;
                        }
                        if (mapped != null)
                        {
                            mb.append_zstr(mapped);
                        }
                        else
                        {
                            mb.append_char(ch);
                        }
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                }
                continue;
            }

            // ── Operatorname / Text / Style Wrappers ─────────────────────────
            if (cmd == "operatorname" || cmd == "text" || cmd == "hspace" || cmd == "vspace")
            {
                i = cmd_end;
                while (i < (usz)input.len && (input[i] == ' ' || input[i] == '*')) i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        if (cmd != "hspace" && cmd != "vspace")
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                }
                if (cmd == "operatorname") mb.append_char(' ');
                continue;
            }

            // ── Accents via Enum ─────────────────────────────────────────────
            MathAccent accent;
            if (logic::lookup_accent(cmd, &accent))
            {
                char* combining = logic::get_accent_combining(accent);
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz arg_start = i;
                    while (i < (usz)input.len && input[i] != '}') i++;
                    String arg_content = input[arg_start : i - arg_start];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_arg = transform_math(arena, arg_content);
                    mb.append_slice(t_arg);
                    mb.append_zstr(combining);
                }
                else if (i < (usz)input.len)
                {
                    mb.append_char(input[i++]);
                    mb.append_zstr(combining);
                }
                continue;
            }

            // ── Fractions: \frac{num}{den} ───────────────────────────────────
            if (cmd == "frac" || cmd == "dfrac" || cmd == "tfrac")
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz n_start = i;
                    int depth = 1;
                    while (i < (usz)input.len && depth > 0)
                    {
                        if (input[i] == '{')
                        {
                            depth++;
                        }
                        else if (input[i] == '}')
                        {
                            depth--;
                        }
                        if (depth > 0) i++;
                    }
                    String num = input[n_start : i - n_start];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    while (i < (usz)input.len && input[i] == ' ') i++;
                    if (i < (usz)input.len && input[i] == '{')
                    {
                        i++;
                        usz d_start = i;
                        depth = 1;
                        while (i < (usz)input.len && depth > 0)
                        {
                            if (input[i] == '{')
                            {
                                depth++;
                            }
                            else if (input[i] == '}')
                            {
                                depth--;
                            }
                            if (depth > 0) i++;
                        }
                        String den = input[d_start : i - d_start];
                        if (i < (usz)input.len && input[i] == '}') i++;

                        String t_num = transform_math(arena, num);
                        String t_den = transform_math(arena, den);

                        if (t_num == "1" && t_den == "2") { mb.append_zstr("½"); continue; }
                        if (t_num == "1" && t_den == "3") { mb.append_zstr("⅓"); continue; }
                        if (t_num == "2" && t_den == "3") { mb.append_zstr("⅔"); continue; }
                        if (t_num == "1" && t_den == "4") { mb.append_zstr("¼"); continue; }
                        if (t_num == "3" && t_den == "4") { mb.append_zstr("¾"); continue; }
                        if (t_num == "1" && t_den == "5") { mb.append_zstr("⅕"); continue; }
                        if (t_num == "2" && t_den == "5") { mb.append_zstr("⅖"); continue; }
                        if (t_num == "3" && t_den == "5") { mb.append_zstr("⅗"); continue; }
                        if (t_num == "4" && t_den == "5") { mb.append_zstr("⅘"); continue; }
                        if (t_num == "1" && t_den == "6") { mb.append_zstr("⅙"); continue; }
                        if (t_num == "5" && t_den == "6") { mb.append_zstr("⅚"); continue; }
                        if (t_num == "1" && t_den == "8") { mb.append_zstr("⅛"); continue; }
                        if (t_num == "3" && t_den == "8") { mb.append_zstr("⅜"); continue; }
                        if (t_num == "5" && t_den == "8") { mb.append_zstr("⅝"); continue; }
                        if (t_num == "7" && t_den == "8") { mb.append_zstr("⅞"); continue; }

                        bool has_op_num = strutils::string_contains(t_num, "+") || strutils::string_contains(t_num, "-") || strutils::string_contains(t_num, "=") || strutils::string_contains(t_num, " ");
                        bool has_op_den = strutils::string_contains(t_den, "+") || strutils::string_contains(t_den, "-") || strutils::string_contains(t_den, "=") || strutils::string_contains(t_den, " ");

                        if (has_op_num) mb.append_char('(');
                        mb.append_slice(t_num);
                        if (has_op_num) mb.append_char(')');

                        mb.append_char('/');

                        if (has_op_den) mb.append_char('(');
                        mb.append_slice(t_den);
                        if (has_op_den) mb.append_char(')');
                        continue;
                    }
                }
            }

            // ── Roots: \sqrt[n]{...} or \sqrt{...} ───────────────────────────
            if (cmd == "sqrt")
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;

                // Optional degree: [n]
                if (i < (usz)input.len && input[i] == '[')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != ']')
                    {
                        char* deg = get_superscript_char(input[i]);
                        if (deg != null)
                        {
                            mb.append_zstr(deg);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == ']') i++;
                }

                mb.append_zstr("√");

                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz rad_start = i;
                    int depth = 1;
                    while (i < (usz)input.len && depth > 0)
                    {
                        if (input[i] == '{')
                        {
                            depth++;
                        }
                        else if (input[i] == '}')
                        {
                            depth--;
                        }
                        if (depth > 0) i++;
                    }
                    String rad = input[rad_start : i - rad_start];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_rad = transform_math(arena, rad);
                    bool has_op_rad = strutils::string_contains(t_rad, "+") || strutils::string_contains(t_rad, "-") || strutils::string_contains(t_rad, "=") || strutils::string_contains(t_rad, " ");
                    if (has_op_rad && (t_rad[0] != '(' || t_rad[t_rad.len - 1] != ')'))
                    {
                        mb.append_char('(');
                        mb.append_slice(t_rad);
                        mb.append_char(')');
                    }
                    else
                    {
                        mb.append_slice(t_rad);
                    }
                }
                continue;
            }

            // ── Symbol Table Lookup via Modular Table ─────────────────────────
            String sym_glyph;
            if (logic::lookup_symbol(cmd, &sym_glyph))
            {
                mb.append_slice(sym_glyph);
                if (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z') || (input[cmd_end] >= '0' && input[cmd_end] <= '9')))
                {
                    mb.append_char(' ');
                }
                i = cmd_end;
                continue;
            }

            // If unknown command, emit clean command name with space
            mb.append_slice(cmd);
            if (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z') || (input[cmd_end] >= '0' && input[cmd_end] <= '9')))
            {
                mb.append_char(' ');
            }
            i = cmd_end;
            continue;
        }

        // ── 2. Superscripts: ^2, ^{n+1}, etc. ────────────────────────────────
        if (c == '^')
        {
            i++;
            if (i < (usz)input.len && input[i] == '{')
            {
                i++;
                while (i < (usz)input.len && input[i] != '}')
                {
                    if (input[i] == '\\')
                    {
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start : s_end - s_start];
                        String sglyph;
                        if (scmd == "alpha") { mb.append_zstr("ᵅ"); }
                        else if (scmd == "beta") { mb.append_zstr("ᵝ"); }
                        else if (scmd == "gamma") { mb.append_zstr("ᵞ"); }
                        else if (scmd == "delta") { mb.append_zstr("ᵟ"); }
                        else if (scmd == "epsilon") { mb.append_zstr("ᵋ"); }
                        else if (scmd == "theta") { mb.append_zstr("ᶿ"); }
                        else if (scmd == "phi") { mb.append_zstr("ᵠ"); }
                        else if (scmd == "chi") { mb.append_zstr("ᵡ"); }
                        else if (scmd == "infty") { mb.append_zstr("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append_zstr("→"); }
                        else if (logic::lookup_symbol(scmd, &sglyph))
                        {
                            mb.append_slice(sglyph);
                        }
                        else
                        {
                            mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sup = get_superscript_char(input[i]);
                    if (sup != null)
                    {
                        mb.append_zstr(sup);
                    }
                    else
                    {
                        mb.append_char(input[i]);
                    }
                    i++;
                }
                if (i < (usz)input.len && input[i] == '}') i++;
                continue;
            }
            else if (i < (usz)input.len)
            {
                char* sup = get_superscript_char(input[i]);
                if (sup != null)
                {
                    mb.append_zstr(sup);
                    i++;
                    continue;
                }
                else
                {
                    mb.append_char('^');
                    mb.append_char(input[i++]);
                    continue;
                }
            }
            mb.append_char('^');
            continue;
        }

        // ── 3. Subscripts: _i, _{10}, etc. ───────────────────────────────────
        if (c == '_')
        {
            i++;
            if (i < (usz)input.len && input[i] == '{')
            {
                i++;
                while (i < (usz)input.len && input[i] != '}')
                {
                    if (input[i] == '\\')
                    {
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start : s_end - s_start];
                        String sglyph;
                        if (scmd == "beta") { mb.append_zstr("ᵦ"); }
                        else if (scmd == "gamma") { mb.append_zstr("ᵧ"); }
                        else if (scmd == "rho") { mb.append_zstr("ᵨ"); }
                        else if (scmd == "phi") { mb.append_zstr("ᵩ"); }
                        else if (scmd == "chi") { mb.append_zstr("ᵪ"); }
                        else if (scmd == "infty") { mb.append_zstr("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append_zstr("→"); }
                        else if (logic::lookup_symbol(scmd, &sglyph))
                        {
                            mb.append_slice(sglyph);
                        }
                        else
                        {
                            mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sub = get_subscript_char(input[i]);
                    if (sub != null)
                    {
                        mb.append_zstr(sub);
                    }
                    else
                    {
                        mb.append_char(input[i]);
                    }
                    i++;
                }
                if (i < (usz)input.len && input[i] == '}') i++;
                continue;
            }
            else if (i < (usz)input.len)
            {
                char* sub = get_subscript_char(input[i]);
                if (sub != null)
                {
                    mb.append_zstr(sub);
                    i++;
                    continue;
                }
                else
                {
                    mb.append_char('_');
                    mb.append_char(input[i++]);
                    continue;
                }
            }
            mb.append_char('_');
            continue;
        }

        // ── 4. Primes: ', '', ''' ───────────────────────────────────────────
        if (c == '\'')
        {
            int prime_count = 0;
            while (i < (usz)input.len && input[i] == '\'')
            {
                prime_count++;
                i++;
            }
            if (prime_count == 1)
            {
                mb.append_zstr("′");
            }
            else if (prime_count == 2)
            {
                mb.append_zstr("″");
            }
            else if (prime_count == 3)
            {
                mb.append_zstr("‴");
            }
            else
            {
                for (int p = 0; p < prime_count; p++) mb.append_zstr("′");
            }
            continue;
        }

        // ── Normal Characters ────────────────────────────────────────────────
        mb.append_char(c);
        i++;
    }

    return mb.to_arena_string(arena);
}
