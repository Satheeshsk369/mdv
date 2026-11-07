module tex;

import std::core::mem;
import ast;
import text;

struct Pair
{
    String key;
    String value;
}

const Pair[] ESCAPES = {
    { "{", "{" }, { "}", "}" }, { ",", "\u2009" }, { ":", "\u205F" }, { ";", "\u2005" },
    { "!", "" }, { " ", " " }, { "%", "%" }, { "$", "$" },
};

const Pair[] RAISED = {
    { "alpha", "ᵅ" }, { "beta", "ᵝ" }, { "gamma", "ᵞ" }, { "delta", "ᵟ" }, { "epsilon", "ᵋ" },
    { "theta", "ᶿ" }, { "phi", "ᵠ" }, { "chi", "ᵡ" }, { "infty", "∞" }, { "to", "→" }, { "rightarrow", "→" },
};

const Pair[] LOWERED = {
    { "beta", "ᵦ" }, { "gamma", "ᵧ" }, { "rho", "ᵨ" }, { "phi", "ᵩ" }, { "chi", "ᵪ" },
    { "infty", "∞" }, { "to", "→" }, { "rightarrow", "→" },
};

const Pair[] VULGAR = {
    { "1/2", "½" }, { "1/3", "⅓" }, { "2/3", "⅔" }, { "1/4", "¼" }, { "3/4", "¾" },
    { "1/5", "⅕" }, { "2/5", "⅖" }, { "3/5", "⅗" }, { "4/5", "⅘" }, { "1/6", "⅙" },
    { "5/6", "⅚" }, { "1/8", "⅛" }, { "3/8", "⅜" }, { "5/8", "⅝" }, { "7/8", "⅞" },
};

fn bool find(Pair[] table, String key, String* value)
{
    foreach (p : table)
    {
        if (p.key != key) continue;
        *value = p.value;
        return true;
    }
    return false;
}

fn bool operated(String s) => s.contains("+") || s.contains("-") || s.contains("=") || s.contains(" ");

struct Flat
{
    ast::Arena* arena;
    String s;
    usz i;
    DString out;
}

fn bool Flat.more(&self) => self.i < self.s.len;

fn bool Flat.at(&self, char c) => self.more() && self.s[self.i] == c;

fn void Flat.skip(&self, String chars)
{
    while (self.more() && chars.contains_char(self.s[self.i])) self.i++;
}

fn String Flat.name(&self)
{
    usz start = self.i;
    while (self.more() && self.s[self.i].is_alpha()) self.i++;
    return self.s[start : self.i - start];
}

fn String Flat.until(&self, char close)
{
    usz start = self.i;
    while (self.more() && self.s[self.i] != close) self.i++;
    String inside = self.s[start : self.i - start];
    if (self.at(close)) self.i++;
    return inside;
}

fn String Flat.nested(&self)
{
    usz start = self.i;
    int depth = 1;
    while (self.more())
    {
        if (self.s[self.i] == '{') depth++;
        if (self.s[self.i] == '}') depth--;
        if (depth == 0) break;
        self.i++;
    }
    String inside = self.s[start : self.i - start];
    if (self.at('}')) self.i++;
    return inside;
}

fn String Flat.sub(&self, String s) => unicode(self.arena, s);

fn bool Flat.fraction(&self)
{
    self.skip(" ");
    if (!self.at('{')) return false;
    self.i++;
    String num = self.nested();
    self.skip(" ");
    if (!self.at('{')) return false;
    self.i++;
    String n = self.sub(num);
    String d = self.sub(self.nested());
    String glyph;
    @pool()
    {
        if (find(VULGAR, string::tformat("%s/%s", n, d), &glyph))
        {
            self.out.append(glyph);
            return true;
        }
    };
    bool top = operated(n);
    bool bottom = operated(d);
    if (top) self.out.append_char('(');
    self.out.append(n);
    if (top) self.out.append_char(')');
    self.out.append_char('/');
    if (bottom) self.out.append_char('(');
    self.out.append(d);
    if (bottom) self.out.append_char(')');
    return true;
}

fn void Flat.root(&self)
{
    self.skip(" ");
    if (self.at('['))
    {
        self.i++;
        foreach (c : self.until(']'))
        {
            String raised = SUPER.map(c);
            if (raised.len)
            {
                self.out.append(raised);
            }
            else
            {
                self.out.append_char(c);
            }
        }
    }
    self.out.append("√");
    self.skip(" ");
    if (!self.at('{')) return;
    self.i++;
    String r = self.sub(self.nested());
    bool wrap = operated(r) && (r[0] != '(' || r[^1] != ')');
    if (wrap) self.out.append_char('(');
    self.out.append(r);
    if (wrap) self.out.append_char(')');
}

fn bool Flat.command(&self, String cmd)
{
    switch (cmd)
    {
        case "quad": self.out.append("\u2003");
        case "qquad": self.out.append("\u2003\u2003");
        case "bmod": self.out.append(" mod ");
        case "pmod":
        case "pod":
            self.skip(" ");
            if (!self.at('{')) return false;
            self.i++;
            String inner = self.sub(self.until('}'));
            self.out.append(cmd == "pmod" ? " (mod " : " (");
            self.out.append(inner);
            self.out.append_char(')');
        case "operatorname":
        case "text":
        case "hspace":
        case "vspace":
            self.skip(" *");
            if (self.at('{'))
            {
                self.i++;
                String inner = self.until('}');
                if (cmd != "hspace" && cmd != "vspace") self.out.append(inner);
            }
            if (cmd == "operatorname") self.out.append_char(' ');
        case "frac":
        case "dfrac":
        case "tfrac":
            return self.fraction();
        case "sqrt":
            self.root();
        default:
            return false;
    }
    return true;
}

fn bool Flat.styled(&self, String cmd)
{
    Alphabet alphabet;
    if (!font(cmd, &alphabet)) return false;
    self.skip(" *");
    if (!self.at('{')) return true;
    self.i++;
    foreach (c : self.until('}'))
    {
        Char32 glyph = alphabet.map(c);
        if (glyph)
        {
            self.out.append_char32(glyph);
        }
        else
        {
            self.out.append_char(c);
        }
    }
    return true;
}

fn bool Flat.accented(&self, String cmd)
{
    MathAccent mark;
    String diacritic;
    if (!accent(cmd, &mark, &diacritic)) return false;
    self.skip(" ");
    if (self.at('{'))
    {
        self.i++;
        self.out.append(self.sub(self.until('}')));
        self.out.append(diacritic);
    }
    else if (self.more())
    {
        self.out.append_char(self.s[self.i++]);
        self.out.append(diacritic);
    }
    return true;
}

fn void Flat.control(&self)
{
    String glyph;
    if (self.i + 1 < self.s.len && find(ESCAPES, self.s[self.i + 1 : 1], &glyph))
    {
        self.out.append(glyph);
        self.i += 2;
        return;
    }
    self.i++;
    String cmd = self.name();
    usz end = self.i;
    if (self.command(cmd) || self.styled(cmd) || self.accented(cmd)) return;
    self.i = end;
    self.out.append(symbol(cmd, &glyph) ? glyph : cmd);
    if (self.more() && self.s[self.i].is_alnum()) self.out.append_char(' ');
}

fn void Flat.script(&self, Pair[] greek, Script script, char mark)
{
    self.i++;
    if (self.at('{'))
    {
        self.i++;
        while (self.more() && !self.at('}'))
        {
            if (self.at('\\'))
            {
                self.i++;
                String cmd = self.name();
                String glyph;
                self.out.append(find(greek, cmd, &glyph) || symbol(cmd, &glyph) ? glyph : cmd);
                continue;
            }
            String g = script.map(self.s[self.i]);
            if (g.len)
            {
                self.out.append(g);
            }
            else
            {
                self.out.append_char(self.s[self.i]);
            }
            self.i++;
        }
        if (self.at('}')) self.i++;
        return;
    }
    if (!self.more())
    {
        self.out.append_char(mark);
        return;
    }
    String g = script.map(self.s[self.i]);
    if (g.len)
    {
        self.out.append(g);
    }
    else
    {
        self.out.append_char(mark);
        self.out.append_char(self.s[self.i]);
    }
    self.i++;
}

fn String unicode(ast::Arena* arena, String input)
{
    if (input.len == 0) return "";
    Flat f = { .arena = arena, .s = input };
    f.out.init(mem, input.len * 4 + 256);
    defer f.out.free();
    while (f.more())
    {
        switch (input[f.i])
        {
            case '\\': f.control();
            case '^': f.script(RAISED, SUPER, '^');
            case '_': f.script(LOWERED, SUB, '_');
            case '\'':
                int count;
                for (; f.at('\''); f.i++) count++;
                f.out.append(count <= 3 ? PRIMES[count - 1] : "");
                if (count > 3) f.out.repeat("′", count);
            default:
                f.out.append_char(input[f.i++]);
        }
    }
    return f.out.keep(arena);
}
