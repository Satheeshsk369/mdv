module tex;

import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import text;

alias MathBoxList = List{MathBox};

struct Reader {
    ast::Arena* arena;
    String src;
    usz pos;
}

fn bool Reader.eof(Reader* p)
{
    return p.pos >= (usz)p.src.len;
}

fn char Reader.peek(Reader* p)
{
    if (p.eof()) return 0;
    return p.src[p.pos];
}

fn char Reader.get(Reader* p)
{
    if (p.eof()) return 0;
    return p.src[p.pos++];
}

fn void Reader.skipSpaces(Reader* p)
{
    while (!p.eof() && (p.src[p.pos] == ' ' || p.src[p.pos] == '\t' || p.src[p.pos] == '\r' || p.src[p.pos] == '\n'))
    {
        p.pos++;
    }
}

fn void Reader.skipLimits(&self)
{
    while (true)
    {
        self.skipSpaces();
        usz save = self.pos;
        if (self.peek() != '\\') return;
        self.pos++;
        String name = self.name();
        if (name == "limits" || name == "nolimits") continue;
        self.pos = save;
        return;
    }
}

fn MathBox negated(Reader* p, MathAtomKind* prevAtom)
{
    p.skipSpaces();
    usz start = p.pos;
    String key;
    if (p.peek() == '\\')
    {
        p.get();
        key = p.name();
    }
    else
    {
        p.get();
        key = p.src[start : p.pos - start];
    }
    String glyph = negate(key);
    MathAtomKind kind = MathAtomKind.REL;
    DString mb;
    mb.init(mem, 32);
    defer mb.free();
    if (glyph.len == 0)
    {
        if (!symbol(key, &glyph, &kind)) glyph = key;
        mb.append(glyph);
        mb.append("\u0338");
        *prevAtom = kind;
        return atom(p.arena, mb.keep(p.arena));
    }
    *prevAtom = kind;
    mb.append_char(' ');
    mb.append(glyph);
    mb.append_char(' ');
    return atom(p.arena, mb.keep(p.arena));
}

fn MathBox styled(Reader* p, MathAtomKind* prevAtom, Alphabet alphabet)
{
    p.skipSpaces();
    if (p.peek() == '*') p.get();
    p.skipSpaces();
    *prevAtom = MathAtomKind.ORD;
    MathBox inner = group(p);
    if (alphabet.upper == 0) return inner;
    String* rows = (String*)p.arena.alloc((usz)inner.height * String::size);
    foreach (i, row : inner.rows) rows[i] = alphabet.apply(p.arena, row);
    inner.rows = rows[:inner.height];
    return inner;
}

fn MathBox accented(Reader* p, MathAtomKind* prevAtom, String diacritic, bool isOverline, bool isUnderline)
{
    MathBox inner = group(p);
    if (isOverline)
    {
        *prevAtom = MathAtomKind.INNER;
        return overline(p.arena, inner);
    }
    if (isUnderline)
    {
        *prevAtom = MathAtomKind.INNER;
        return underline(p.arena, inner);
    }

    DString mb;
    mb.init(mem, 64);
    defer mb.free();
    if (inner.height > 0)
    {
        mb.append_string(inner.rows[0]);
        mb.append_string(diacritic);
    }
    *prevAtom = MathAtomKind.ORD;
    return atom(p.arena, mb.keep(p.arena));
}

struct Fence
{
    String name;
    char code;
}

const Fence[] FENCES = {
    { "lfloor", 'F' }, { "rfloor", 'F' }, { "lceil", 'C' }, { "rceil", 'C' }, { "langle", '<' }, { "rangle", '>' },
    { "lbrace", '{' }, { "{", '{' }, { "rbrace", '}' }, { "}", '}' }, { "vert", '|' }, { "lvert", '|' }, { "rvert", '|' },
    { "|", 'V' }, { "Vert", 'V' }, { "lVert", 'V' }, { "rVert", 'V' },
};

fn char delimiter(Reader* p)
{
    usz start = p.pos;
    while (!p.eof() && p.src[p.pos].is_alpha()) p.pos++;
    if (p.pos == start && !p.eof()) p.pos++;
    String name = p.src[start : p.pos - start];
    foreach (f : FENCES) if (f.name == name) return f.code;
    return '\\';
}

fn MathBox paired(Reader* p, MathAtomKind* prevAtom)
{
    p.skipSpaces();
    char openCh = p.get();
    if (openCh == '\\') openCh = delimiter(p);
    if (openCh == '.') openCh = 0;

    MathBox inner = expression(p, false, false);

    char closeCh = ')';
    p.skipSpaces();
    if (p.peek() == '\\')
    {
        p.get();
        usz rStart = p.pos;
        while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
        String rCmd = p.src[rStart : p.pos - rStart];
        if (rCmd == "right")
        {
            p.skipSpaces();
            closeCh = p.get();
            if (closeCh == '\\') closeCh = delimiter(p);
            if (closeCh == '.') closeCh = 0;
        }
    }

    *prevAtom = MathAtomKind.INNER;
    return delimit(p.arena, inner, openCh, closeCh);
}

fn MathBox block(Reader* p, MathAtomKind* prevAtom)
{
    p.skipSpaces();
    if (p.peek() == '{') p.get();
    usz envStart = p.pos;
    while (!p.eof() && p.peek() != '}') p.pos++;
    String envName = p.src[envStart : p.pos - envStart];
    if (p.peek() == '}') p.get();
    MathEnvironment menv;
    MathEnvFlags envFlags;
    bool known = environment(envName, &menv, &envFlags);
    if (known && envFlags.argument)
    {
        p.skipSpaces();
        if (p.peek() == '{')
        {
            p.get();
            while (!p.eof() && p.peek() != '}') p.pos++;
            if (p.peek() == '}') p.get();
        }
    }

    List{MathBoxList} envRows;
    envRows.init(mem, 8);
    defer {
        for (sz r = 0; r < envRows.size; r++) envRows.entries[r].free();
        envRows.free();
    }

    MathBoxList curRow;
    curRow.init(mem, 4);

    int maxCols = 0;

    while (!p.eof())
    {
        p.skipSpaces();
        usz begin = p.pos;

        if (p.peek() == '\\')
        {
            usz savePos = p.pos;
            p.get();
            usz checkStart = p.pos;
            while (!p.eof() && ((p.src[p.pos] >= 'a' && p.src[p.pos] <= 'z') || (p.src[p.pos] >= 'A' && p.src[p.pos] <= 'Z'))) p.pos++;
            String checkCmd = p.src[checkStart : p.pos - checkStart];
            if (checkCmd == "end")
            {
                p.skipSpaces();
                if (p.peek() == '{') p.get();
                while (!p.eof() && p.peek() != '}') p.pos++;
                if (p.peek() == '}') p.get();
                if (curRow.size > 0)
                {
                    if ((int)curRow.size > maxCols) maxCols = (int)curRow.size;
                    envRows.push(curRow);
                    curRow.init(mem, 4);
                }
                break;
            }
            else if (savePos + 1 < (usz)p.src.len && p.src[savePos + 1] == '\\')
            {
                p.pos = savePos + 2;
                if ((int)curRow.size > maxCols) maxCols = (int)curRow.size;
                envRows.push(curRow);
                curRow.init(mem, 4);
                continue;
            }
            else
            {
                p.pos = savePos;
            }
        }

        MathBox cell = expression(p, true, true);
        curRow.push(cell);

        p.skipSpaces();
        if (p.peek() == '&')
        {
            p.get();
        }
        else if (p.peek() == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\')
        {
            p.pos += 2;
            if ((int)curRow.size > maxCols) maxCols = (int)curRow.size;
            envRows.push(curRow);
            curRow.init(mem, 4);
        }
        else if (p.pos == begin)
        {
            p.pos++;
        }
    }

    if (curRow.size > 0)
    {
        if ((int)curRow.size > maxCols) maxCols = (int)curRow.size;
        envRows.push(curRow);
    }
    else
    {
        curRow.free();
    }

    int numRows = (int)envRows.size;
    int numCols = maxCols > 0 ? maxCols : 1;

    MathBox* flatBuf = (MathBox*)p.arena.alloc((usz)(numRows * numCols) * MathBox::size);
    for (int r = 0; r < numRows; r++)
    {
        MathBoxList row = envRows.entries[(usz)r];
        for (int col = 0; col < numCols; col++)
        {
            flatBuf[(usz)(r * numCols + col)] = (col < (int)row.size) ? row.entries[(usz)col] : blank(p.arena);
        }
    }
    MathBox[] flatGrid = flatBuf[: (usz)(numRows * numCols)];

    *prevAtom = MathAtomKind.INNER;
    if (known)
    {
        MathBox inner = grid(p.arena, flatGrid, numRows, numCols, envFlags.alignMode, (int)envFlags.colGap);
        if (envFlags.delimLeft != 0 || envFlags.delimRight != 0)
        {
            return delimit(p.arena, inner, envFlags.delimLeft, envFlags.delimRight);
        }
        return inner;
    }

    return grid(p.arena, flatGrid, numRows, numCols, 'C', 2);
}

struct Large
{
    MathCommand command;
    String glyph;
}

const Large[] LARGE = {
    { SUM, "∑" }, { PROD, "∏" }, { COPROD, "∐" }, { BIG_UNION, "⋃" }, { BIG_INTERSECTION, "⋂" },
    { BIG_PLUS, "⨁" }, { BIG_TIMES, "⨂" }, { BIG_DOT, "⨀" }, { BIG_SQ_CUP, "⨆" }, { BIG_UPLUS, "⨄" }, { BIG_VEE, "⋁" },
    { BIG_WEDGE, "⋀" }, { INT, "∫" }, { IINT, "∬" }, { IIINT, "∭" }, { IIIINT, "⨌" }, { OINT, "∮" }, { OIINT, "∯" }, { OIIINT, "∰" },
    { LIM, "lim" }, { LIMINF, "lim inf" }, { LIMSUP, "lim sup" }, { MAX, "max" }, { MIN, "min" },
    { SUP, "sup" }, { INF, "inf" }, { ARGMAX, "arg max" }, { ARGMIN, "arg min" },
};

fn String glyph(MathCommand command)
{
    foreach (l : LARGE) if (l.command == command) return l.glyph;
    return "";
}

fn MathBox commanded(Reader* p, MathAtomKind* prevAtom, MathCommand mcmd, String cmd)
{
    switch (mcmd)
    {
        case TAG:
            p.skipSpaces();
            bool starred = false;
            if (p.peek() == '*') { p.get(); starred = true; }
            p.skipSpaces();
            if (p.peek() == '{') p.get();
            usz tStart = p.pos;
            while (!p.eof() && p.peek() != '}') p.pos++;
            String rawTag = p.src[tStart : p.pos - tStart];
            if (p.peek() == '}') p.get();

            DString tb;
            tb.init(mem, 64);
            defer tb.free();
            if (!starred) tb.append_char('(');
            tb.append_string(rawTag);
            if (!starred) tb.append_char(')');
            *prevAtom = MathAtomKind.ORD;
            return atom(p.arena, tb.keep(p.arena));

        case XRIGHTARROW:
        case XLEFTARROW:
        case XLEFTRIGHTARROW:
            MathBox xsub = blank(p.arena);
            p.skipSpaces();
            if (p.peek() == '[')
            {
                p.get();
                xsub = expression(p, false, false, true);
                p.skipSpaces();
                if (p.peek() == ']') p.get();
            }
            MathBox xsup = group(p);
            char dir = 'R';
            if (mcmd == MathCommand.XLEFTARROW)
            {
                dir = 'L';
            }
            else if (mcmd == MathCommand.XLEFTRIGHTARROW)
            {
                dir = 'B';
            }
            *prevAtom = MathAtomKind.REL;
            return xarrow(p.arena, xsup, xsub, dir);

        case UNDERLINE:
            MathBox unInner = group(p);
            *prevAtom = MathAtomKind.INNER;
            return underline(p.arena, unInner);

        case OVERRIGHTARROW:
        case OVERLEFTARROW:
            MathBox oInner = group(p);
            bool isRight = (mcmd == MathCommand.OVERRIGHTARROW);
            *prevAtom = MathAtomKind.INNER;
            return overarrow(p.arena, oInner, isRight);

        case CANCEL:
        case BCANCEL:
        case XCANCEL:
            MathBox canInner = group(p);
            *prevAtom = MathAtomKind.ORD;
            return cancel(p.arena, canInner);

        case COLOR:
        case TEXTCOLOR:
        case MATHCOLOR:
            p.skipSpaces();
            if (p.peek() == '{') p.get();
            usz cStart = p.pos;
            while (!p.eof() && p.peek() != '}') p.pos++;
            String cName = p.src[cStart : p.pos - cStart];
            if (p.peek() == '}') p.get();

            MathBox colInner = group(p);
            *prevAtom = MathAtomKind.INNER;
            return colorize(p.arena, colInner, ansi::named(cName));

        case FRAC:
        case DFRAC:
        case TFRAC:
        case CFRAC:
            MathBox num = group(p);
            MathBox den = group(p);
            *prevAtom = MathAtomKind.INNER;
            return fraction(p.arena, num, den);

        case BOXED:
            MathBox bInner = group(p);
            *prevAtom = MathAtomKind.INNER;
            return boxed(p.arena, bInner);

        case BINOM:
        case DBINOM:
        case TBINOM:
            MathBox topB = group(p);
            MathBox botB = group(p);
            MathBox[2] pair = { topB, botB };
            MathBox binomInner = stack(p.arena, pair[0:2]);
            *prevAtom = MathAtomKind.INNER;
            return delimit(p.arena, binomInner, '(', ')');

        case OVERSET:
        case STACKREL:
            MathBox oTop = group(p);
            MathBox oBase = group(p);
            *prevAtom = MathAtomKind.ORD;
            return limits(p.arena, oBase, blank(p.arena), oTop);

        case UNDERSET:
            MathBox uBot = group(p);
            MathBox uBase = group(p);
            *prevAtom = MathAtomKind.ORD;
            return limits(p.arena, uBase, uBot, blank(p.arena));

        case OVERBRACE:
            MathBox obInner = group(p);
            MathBox obLabel = blank(p.arena);
            p.skipSpaces();
            if (p.peek() == '^')
            {
                p.get();
                obLabel = group(p);
            }
            *prevAtom = MathAtomKind.INNER;
            return overbrace(p.arena, obInner, obLabel);

        case UNDERBRACE:
            MathBox ubInner = group(p);
            MathBox ubLabel = blank(p.arena);
            p.skipSpaces();
            if (p.peek() == '_')
            {
                p.get();
                ubLabel = group(p);
            }
            *prevAtom = MathAtomKind.INNER;
            return underbrace(p.arena, ubInner, ubLabel);

        case SUBSTACK:
            p.skipSpaces();
            if (p.peek() == '{') p.get();
            List{MathBox} lines;
            lines.init(mem, 4);
            defer lines.free();

            while (!p.eof())
            {
                lines.push(expression(p, false, true));
                p.skipSpaces();
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
            *prevAtom = MathAtomKind.ORD;
            return stack(p.arena, lines.entries[:(usz)lines.size]);

        case SQRT:
            MathBox deg = blank(p.arena);
            p.skipSpaces();
            if (p.peek() == '[')
            {
                p.get();
                deg = expression(p, false, false, true);
                p.skipSpaces();
                if (p.peek() == ']') p.get();
            }
            MathBox sqrtInner = group(p);
            *prevAtom = MathAtomKind.INNER;
            return root(p.arena, sqrtInner, deg);

        case SUM:
        case PROD:
        case COPROD:
        case BIG_UNION:
        case BIG_INTERSECTION:
        case BIG_PLUS:
        case BIG_TIMES:
        case BIG_DOT:
        case BIG_SQ_CUP:
        case BIG_UPLUS:
        case BIG_VEE:
        case BIG_WEDGE:
        case INT:
        case IINT:
        case IIINT:
        case IIIINT:
        case OINT:
        case OIINT:
        case OIIINT:
            MathBox lower = blank(p.arena);
            MathBox upper = blank(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skipLimits();
                if (p.peek() == '_')
                {
                    p.get();
                    lower = group(p);
                }
                else if (p.peek() == '^')
                {
                    p.get();
                    upper = group(p);
                }
            }
            *prevAtom = MathAtomKind.OP;
            return bigop(p.arena, lower, upper, glyph(mcmd));

        case LIM:
        case LIMINF:
        case LIMSUP:
        case MAX:
        case MIN:
        case SUP:
        case INF:
        case ARGMAX:
        case ARGMIN:
            String opName = glyph(mcmd);

            MathBox opBox = atom(p.arena, opName);
            MathBox limSub = blank(p.arena);
            MathBox limSup = blank(p.arena);
            for (int k = 0; k < 2; k++)
            {
                p.skipLimits();
                if (p.peek() == '_') { p.get(); limSub = group(p); }
                else if (p.peek() == '^') { p.get(); limSup = group(p); }
            }
            *prevAtom = MathAtomKind.OP;
            return limits(p.arena, opBox, limSub, limSup);

        case PMOD:
        case POD:
            MathBox mBox = group(p);
            DString pmodMb;
            pmodMb.init(mem, 64);
            defer pmodMb.free();
            pmodMb.append(" (");
            if (mcmd == MathCommand.PMOD) pmodMb.append("mod ");
            if (mBox.rows.len > 0) pmodMb.append_string(mBox.rows[0]);
            pmodMb.append_char(')');
            *prevAtom = MathAtomKind.ORD;
            return atom(p.arena, pmodMb.keep(p.arena));

        case BMOD:
            *prevAtom = MathAtomKind.BIN;
            return atom(p.arena, " mod ");

        case QUAD:
            return gap(p.arena, 4);

        case QQUAD:
            return gap(p.arena, 8);

        case LEFT: return paired(p, prevAtom);
        case BEGIN: return block(p, prevAtom);

        case TEXT:
            p.skipSpaces();
            if (p.peek() == '{')
            {
                p.get();
                usz txtStart = p.pos;
                while (!p.eof() && p.peek() != '}') p.pos++;
                String txt = p.src[txtStart : p.pos - txtStart];
                if (p.peek() == '}') p.get();
                *prevAtom = MathAtomKind.ORD;
                MathBox words = atom(p.arena, txt);
                foreach (&c : words.rows[0]) if (*c == '~') *c = ' ';
                return words;
            }
            *prevAtom = MathAtomKind.ORD;
            return atom(p.arena, "text");

        case OPERATORNAME:
            p.skipSpaces();
            if (p.peek() == '*') p.get();
            MathBox opBox = group(p);
            *prevAtom = MathAtomKind.OP;
            return opBox;

        case PHANTOM:
            return gap(p.arena, group(p).width);
    }
}

struct Op
{
    char c;
    String glyph;
    MathAtomKind kind;
}

const Op[] OPS = {
    { '=', " = ", REL }, { '<', " < ", REL }, { '>', " > ", REL },
    { '*', " * ", BIN }, { ',', ", ", PUNCT }, { ';', "; ", PUNCT },
};

struct Space
{
    char c;
    String glyph;
}

const Space[] SPACES = { { ',', " " }, { ';', "  " }, { ':', " " }, { ' ', " " } };

const String[] PRIMES = { "′", "″", "‴" };

fn String Reader.name(&self)
{
    usz start = self.pos;
    while (!self.eof() && self.src[self.pos].is_alpha()) self.pos++;
    return self.src[start : self.pos - start];
}

fn MathBox control(Reader* p, MathAtomKind* prevAtom)
{
    p.get();
    if (p.eof()) return atom(p.arena, "\\");
    char c = p.peek();
    if (c == '{' || c == '}' || c == '%' || c == '$')
    {
        p.get();
        *prevAtom = c == '{' ? MathAtomKind.OPEN : c == '}' ? MathAtomKind.CLOSE : MathAtomKind.ORD;
        return letter(p.arena, c);
    }
    if (c == '!')
    {
        p.get();
        return blank(p.arena);
    }
    if (c == '|')
    {
        p.get();
        *prevAtom = MathAtomKind.ORD;
        return atom(p.arena, "║");
    }
    foreach (space : SPACES)
    {
        if (space.c != c) continue;
        p.get();
        return atom(p.arena, space.glyph);
    }
    String cmd = p.name();
    if (cmd == "not") return negated(p, prevAtom);
    Alphabet alphabet;
    if (font(cmd, &alphabet)) return styled(p, prevAtom, alphabet);
    MathAccent mark;
    String diacritic;
    bool isOverline;
    bool isUnderline;
    if (accent(cmd, &mark, &diacritic, &isOverline, &isUnderline)) return accented(p, prevAtom, diacritic, isOverline, isUnderline);
    MathCommand mcmd;
    if (command(cmd, &mcmd)) return commanded(p, prevAtom, mcmd, cmd);

    String symGlyph;
    MathAtomKind symKind;
    if (symbol(cmd, &symGlyph, &symKind))
    {
        *prevAtom = symKind;
        if (symKind == MathAtomKind.REL || symKind == MathAtomKind.BIN)
        {
            DString mb;
            mb.init(mem, 32);
            defer mb.free();
            mb.append_char(' ');
            mb.append_string(symGlyph);
            mb.append_char(' ');
            return atom(p.arena, mb.keep(p.arena));
        }
        return atom(p.arena, symGlyph);
    }

    *prevAtom = MathAtomKind.ORD;
    return atom(p.arena, cmd);
}

fn MathBox term(Reader* p, MathAtomKind* prevAtom)
{
    p.skipSpaces();
    if (p.eof()) return blank(p.arena);
    char c = p.peek();
    if (c == '{')
    {
        p.get();
        MathBox inner = expression(p, false, false);
        p.skipSpaces();
        if (p.peek() == '}') p.get();
        *prevAtom = MathAtomKind.INNER;
        return inner;
    }
    if (c == '\\') return control(p, prevAtom);
    MathAtomKind prev = *prevAtom;
    *prevAtom = MathAtomKind.ORD;
    if (c.is_digit())
    {
        usz start = p.pos;
        while (!p.eof() && (p.peek().is_digit() || p.peek() == '.')) p.pos++;
        return atom(p.arena, p.src[start : p.pos - start]);
    }
    if (c == '\'')
    {
        int count;
        for (; p.peek() == '\''; p.get()) count++;
        if (count <= 3) return atom(p.arena, PRIMES[count - 1]);
        DString primes;
        primes.init(mem, 16);
        defer primes.free();
        primes.repeat("′", count);
        return atom(p.arena, primes.keep(p.arena));
    }
    p.get();
    foreach (op : OPS)
    {
        if (op.c != c) continue;
        *prevAtom = op.kind;
        return atom(p.arena, op.glyph);
    }
    if ((c == '+' || c == '-') && (prev == MathAtomKind.ORD || prev == MathAtomKind.CLOSE || prev == MathAtomKind.INNER))
    {
        *prevAtom = MathAtomKind.BIN;
        return atom(p.arena, c == '+' ? " + " : " - ");
    }
    if (c == '(' || c == '[') *prevAtom = MathAtomKind.OPEN;
    if (c == ')' || c == ']') *prevAtom = MathAtomKind.CLOSE;
    return letter(p.arena, c);
}

fn MathBox group(Reader* p)
{
    p.skipSpaces();
    if (p.eof()) return blank(p.arena);

    if (p.peek() == '{')
    {
        p.get();
        MathBox res = expression(p, false, false);
        p.skipSpaces();
        if (p.peek() == '}') p.get();
        return res;
    }

    MathAtomKind atom = MathAtomKind.ORD;
    return term(p, &atom);
}

const String[] FUNCTIONS = {
    "arccos", "arcsin", "arctan", "arg", "cos", "cosh", "cot", "coth", "csc", "deg", "det", "dim", "exp", "gcd", "hom", "ker",
    "lg", "ln", "log", "Pr", "sec", "sin", "sinh", "tan", "tanh",
};

fn bool named(Reader* p)
{
    usz start = p.pos + 1;
    usz end = start;
    while (end < p.src.len && p.src[end].is_alpha()) end++;
    String name = p.src[start : end - start];
    foreach (f : FUNCTIONS) if (f == name) return true;
    return false;
}

fn bool joins(MathAtomKind kind) => kind == MathAtomKind.ORD || kind == MathAtomKind.CLOSE || kind == MathAtomKind.INNER || kind == MathAtomKind.OP;

struct Piece
{
    MathBox base;
    MathBox sup;
    MathBox sub;
    bool gap;
}

fn MathBox expression(Reader* p, bool stopAtAmp = false, bool stopAtBslash = false, bool stopAtRbracket = false)
{
    List{Piece} pieces;
    pieces.init(mem, 16);
    defer pieces.free();
    MathAtomKind prevAtom = MathAtomKind.OPEN;
    bool raise;
    bool function;
    while (!p.eof())
    {
        p.skipSpaces();
        if (p.eof()) break;
        bool spaced = p.pos > 0 && p.src[p.pos - 1].is_space() && joins(prevAtom);
        char c = p.peek();
        if (c == '}') break;
        if (stopAtRbracket && c == ']') break;
        if (stopAtAmp && c == '&') break;
        if (stopAtBslash && c == '\\' && p.pos + 1 < (usz)p.src.len && p.src[p.pos + 1] == '\\') break;
        if (c == '\\')
        {
            usz save = p.pos;
            p.get();
            String name = p.name();
            bool argument;
            if (skip(name, &argument))
            {
                if (argument) group(p);
                continue;
            }
            if (name == "over" || name == "choose" || name == "atop")
            {
                MathBox left = assemble(p.arena, pieces.array_view(), raise);
                MathBox right = expression(p, stopAtAmp, stopAtBslash, stopAtRbracket);
                if (name == "over") return fraction(p.arena, left, right);
                MathBox[2] pair = { left, right };
                MathBox stacked = stack(p.arena, pair[0:2]);
                return name == "choose" ? delimit(p.arena, stacked, '(', ')') : stacked;
            }
            p.pos = save;
            if (name == "right" || name == "end") break;
        }
        bool after = function;
        function = c == '\\' && named(p);
        Piece piece = { .base = term(p, &prevAtom), .sup = blank(p.arena), .sub = blank(p.arena) };
        while (true)
        {
            usz mark = p.pos;
            p.skipSpaces();
            char s = p.peek();
            if (s != '^' && s != '_')
            {
                p.pos = mark;
                break;
            }
            p.get();
            MathBox* slot = s == '^' ? &piece.sup : &piece.sub;
            *slot = group(p);
        }
        bool scripted = piece.sup.width > 0 || piece.sub.width > 0;
        raise = raise || (scripted && !flat(piece.base, piece.sup, piece.sub));
        piece.gap = (spaced && joins(prevAtom) && prevAtom != MathAtomKind.CLOSE) || (after && prevAtom != MathAtomKind.OPEN && prevAtom != MathAtomKind.PUNCT);
        pieces.push(piece);
    }
    return assemble(p.arena, pieces.array_view(), raise);
}

fn MathBox assemble(ast::Arena* arena, Piece[] pieces, bool raise)
{
    MathBox res = blank(arena);
    foreach (piece : pieces)
    {
        MathBox next = scripts(arena, piece.base, piece.sup, piece.sub, raise);
        res = beside(arena, res, next, piece.gap && res.width > 0 ? 1 : 0);
    }
    return res;
}

fn MathBox latex(ast::Arena* arena, String latex)
{
    Reader parser;
    parser.arena = arena;
    parser.src = degrees(arena, latex);
    parser.pos = 0;

    return expression(&parser, false, false);
}
