module tex;

import std::core::mem;
import ast;
import text;

fn String unicode(ast::Arena* arena, String input)
{
    if (input.len == 0) return "";

    DString mb;
    mb.init(mem, (usz)input.len * 4 + 256);
    defer mb.free();

    usz i = 0;

    while (i < (usz)input.len)
    {
        char c = input[i];

        if (c == '\\')
        {
            if (i + 1 < (usz)input.len)
            {
                char nextC = input[i + 1];
                if (nextC == '{' || nextC == '}')
                {
                    mb.append_char(nextC);
                    i += 2;
                    continue;
                }
                if (nextC == ',')
                {
                    mb.append(" ");
                    i += 2;
                    continue;
                }
                if (nextC == ':')
                {
                    mb.append(" ");
                    i += 2;
                    continue;
                }
                if (nextC == ';')
                {
                    mb.append(" ");
                    i += 2;
                    continue;
                }
                if (nextC == '!')
                {
                    i += 2;
                    continue;
                }
                if (nextC == ' ')
                {
                    mb.append_char(' ');
                    i += 2;
                    continue;
                }
                if (nextC == '%')
                {
                    mb.append_char('%');
                    i += 2;
                    continue;
                }
                if (nextC == '$')
                {
                    mb.append_char('$');
                    i += 2;
                    continue;
                }
            }

            usz cmdStart = i + 1;
            usz cmdEnd = cmdStart;
            while (cmdEnd < (usz)input.len && ((input[cmdEnd] >= 'a' && input[cmdEnd] <= 'z') || (input[cmdEnd] >= 'A' && input[cmdEnd] <= 'Z')))
            {
                cmdEnd++;
            }

            String cmd = input[cmdStart : cmdEnd - cmdStart];

            if (cmd == "quad")
            {
                mb.append(" ");
                i = cmdEnd;
                continue;
            }
            if (cmd == "qquad")
            {
                mb.append("  ");
                i = cmdEnd;
                continue;
            }

            if (cmd == "pmod" || cmd == "pod")
            {
                i = cmdEnd;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz mStart = i;
                    while (i < (usz)input.len && input[i] != '}') i++;
                    String mContent = input[mStart : i - mStart];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String tM = unicode(arena, mContent);
                    mb.append(" (");
                    if (cmd == "pmod") mb.append("mod ");
                    mb.append_string(tM);
                    mb.append_char(')');
                    continue;
                }
            }
            if (cmd == "bmod")
            {
                mb.append(" mod ");
                i = cmdEnd;
                continue;
            }

            Alphabet alphabet;
            if (font(cmd, &alphabet))
            {
                i = cmdEnd;
                while (i < (usz)input.len && (input[i] == ' ' || input[i] == '*')) i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        char ch = input[i++];
                        Char32 glyph = alphabet.map(ch);
                        if (glyph)
                        {
                            mb.append_char32(glyph);
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

            if (cmd == "operatorname" || cmd == "text" || cmd == "hspace" || cmd == "vspace")
            {
                i = cmdEnd;
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

            MathAccent mark;
            String diacritic;
            if (accent(cmd, &mark, &diacritic))
            {
                i = cmdEnd;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz argStart = i;
                    while (i < (usz)input.len && input[i] != '}') i++;
                    String argContent = input[argStart : i - argStart];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String tArg = unicode(arena, argContent);
                    mb.append_string(tArg);
                    mb.append(diacritic);
                }
                else if (i < (usz)input.len)
                {
                    mb.append_char(input[i++]);
                    mb.append(diacritic);
                }
                continue;
            }

            if (cmd == "frac" || cmd == "dfrac" || cmd == "tfrac")
            {
                i = cmdEnd;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz nStart = i;
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
                    String num = input[nStart : i - nStart];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    while (i < (usz)input.len && input[i] == ' ') i++;
                    if (i < (usz)input.len && input[i] == '{')
                    {
                        i++;
                        usz dStart = i;
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
                        String den = input[dStart : i - dStart];
                        if (i < (usz)input.len && input[i] == '}') i++;

                        String tNum = unicode(arena, num);
                        String tDen = unicode(arena, den);

                        if (tNum == "1" && tDen == "2") { mb.append("½"); continue; }
                        if (tNum == "1" && tDen == "3") { mb.append("⅓"); continue; }
                        if (tNum == "2" && tDen == "3") { mb.append("⅔"); continue; }
                        if (tNum == "1" && tDen == "4") { mb.append("¼"); continue; }
                        if (tNum == "3" && tDen == "4") { mb.append("¾"); continue; }
                        if (tNum == "1" && tDen == "5") { mb.append("⅕"); continue; }
                        if (tNum == "2" && tDen == "5") { mb.append("⅖"); continue; }
                        if (tNum == "3" && tDen == "5") { mb.append("⅗"); continue; }
                        if (tNum == "4" && tDen == "5") { mb.append("⅘"); continue; }
                        if (tNum == "1" && tDen == "6") { mb.append("⅙"); continue; }
                        if (tNum == "5" && tDen == "6") { mb.append("⅚"); continue; }
                        if (tNum == "1" && tDen == "8") { mb.append("⅛"); continue; }
                        if (tNum == "3" && tDen == "8") { mb.append("⅜"); continue; }
                        if (tNum == "5" && tDen == "8") { mb.append("⅝"); continue; }
                        if (tNum == "7" && tDen == "8") { mb.append("⅞"); continue; }

                        bool hasOpNum = tNum.contains("+") || tNum.contains("-") || tNum.contains("=") || tNum.contains(" ");
                        bool hasOpDen = tDen.contains("+") || tDen.contains("-") || tDen.contains("=") || tDen.contains(" ");

                        if (hasOpNum) mb.append_char('(');
                        mb.append_string(tNum);
                        if (hasOpNum) mb.append_char(')');

                        mb.append_char('/');

                        if (hasOpDen) mb.append_char('(');
                        mb.append_string(tDen);
                        if (hasOpDen) mb.append_char(')');
                        continue;
                    }
                }
            }

            if (cmd == "sqrt")
            {
                i = cmdEnd;
                while (i < (usz)input.len && input[i] == ' ') i++;

                if (i < (usz)input.len && input[i] == '[')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != ']')
                    {
                        String deg = SUPER.map(input[i]);
                        if (deg.len)
                        {
                            mb.append(deg);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == ']') i++;
                }

                mb.append("√");

                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz radStart = i;
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
                    String rad = input[radStart : i - radStart];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String tRad = unicode(arena, rad);
                    bool hasOpRad = tRad.contains("+") || tRad.contains("-") || tRad.contains("=") || tRad.contains(" ");
                    if (hasOpRad && (tRad[0] != '(' || tRad[tRad.len - 1] != ')'))
                    {
                        mb.append_char('(');
                        mb.append_string(tRad);
                        mb.append_char(')');
                    }
                    else
                    {
                        mb.append_string(tRad);
                    }
                }
                continue;
            }

            String symGlyph;
            if (symbol(cmd, &symGlyph))
            {
                mb.append_string(symGlyph);
                if (cmdEnd < (usz)input.len && ((input[cmdEnd] >= 'a' && input[cmdEnd] <= 'z') || (input[cmdEnd] >= 'A' && input[cmdEnd] <= 'Z') || (input[cmdEnd] >= '0' && input[cmdEnd] <= '9')))
                {
                    mb.append_char(' ');
                }
                i = cmdEnd;
                continue;
            }

            mb.append_string(cmd);
            if (cmdEnd < (usz)input.len && ((input[cmdEnd] >= 'a' && input[cmdEnd] <= 'z') || (input[cmdEnd] >= 'A' && input[cmdEnd] <= 'Z') || (input[cmdEnd] >= '0' && input[cmdEnd] <= '9')))
            {
                mb.append_char(' ');
            }
            i = cmdEnd;
            continue;
        }

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
                        usz sStart = i + 1;
                        usz sEnd = sStart;
                        while (sEnd < (usz)input.len && ((input[sEnd] >= 'a' && input[sEnd] <= 'z') || (input[sEnd] >= 'A' && input[sEnd] <= 'Z'))) sEnd++;
                        String scmd = input[sStart : sEnd - sStart];
                        String sglyph;
                        if (scmd == "alpha") { mb.append("ᵅ"); }
                        else if (scmd == "beta") { mb.append("ᵝ"); }
                        else if (scmd == "gamma") { mb.append("ᵞ"); }
                        else if (scmd == "delta") { mb.append("ᵟ"); }
                        else if (scmd == "epsilon") { mb.append("ᵋ"); }
                        else if (scmd == "theta") { mb.append("ᶿ"); }
                        else if (scmd == "phi") { mb.append("ᵠ"); }
                        else if (scmd == "chi") { mb.append("ᵡ"); }
                        else if (scmd == "infty") { mb.append("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append("→"); }
                        else if (symbol(scmd, &sglyph))
                        {
                            mb.append_string(sglyph);
                        }
                        else
                        {
                            mb.append_string(scmd);
                        }
                        i = sEnd;
                        continue;
                    }

                    String sup = SUPER.map(input[i]);
                    if (sup.len)
                    {
                        mb.append(sup);
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
                String sup = SUPER.map(input[i]);
                if (sup.len)
                {
                    mb.append(sup);
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
                        usz sStart = i + 1;
                        usz sEnd = sStart;
                        while (sEnd < (usz)input.len && ((input[sEnd] >= 'a' && input[sEnd] <= 'z') || (input[sEnd] >= 'A' && input[sEnd] <= 'Z'))) sEnd++;
                        String scmd = input[sStart : sEnd - sStart];
                        String sglyph;
                        if (scmd == "beta") { mb.append("ᵦ"); }
                        else if (scmd == "gamma") { mb.append("ᵧ"); }
                        else if (scmd == "rho") { mb.append("ᵨ"); }
                        else if (scmd == "phi") { mb.append("ᵩ"); }
                        else if (scmd == "chi") { mb.append("ᵪ"); }
                        else if (scmd == "infty") { mb.append("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append("→"); }
                        else if (symbol(scmd, &sglyph))
                        {
                            mb.append_string(sglyph);
                        }
                        else
                        {
                            mb.append_string(scmd);
                        }
                        i = sEnd;
                        continue;
                    }

                    String sub = SUB.map(input[i]);
                    if (sub.len)
                    {
                        mb.append(sub);
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
                String sub = SUB.map(input[i]);
                if (sub.len)
                {
                    mb.append(sub);
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

        if (c == '\'')
        {
            int primeCount = 0;
            while (i < (usz)input.len && input[i] == '\'')
            {
                primeCount++;
                i++;
            }
            if (primeCount == 1)
            {
                mb.append("′");
            }
            else if (primeCount == 2)
            {
                mb.append("″");
            }
            else if (primeCount == 3)
            {
                mb.append("‴");
            }
            else
            {
                for (int p = 0; p < primeCount; p++) mb.append("′");
            }
            continue;
        }

        mb.append_char(c);
        i++;
    }

    return mb.keep(arena);
}
