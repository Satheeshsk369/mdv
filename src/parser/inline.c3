module parser;

import std::core::mem;
import std::collections::list;
import ast;
import tex;
import text;

struct Entity
{
    String entity;
    String symbol;
}

const Entity[] ENTITIES = {
    { "&copy;", "©" },
    { "&trade;", "™" },
    { "&reg;", "®" },
    { "&mdash;", "—" },
    { "&ndash;", "–" },
    { "&hellip;", "…" },
    { "&amp;", "&" },
    { "&lt;", "<" },
    { "&gt;", ">" },
    { "&quot;", "\"" },
    { "&apos;", "'" },
    { "&plusmn;", "±" },
    { "&times;", "×" },
    { "&divide;", "÷" },
    { "&deg;", "°" },
    { "&infin;", "∞" },
    { "&ne;", "≠" },
    { "&le;", "≤" },
    { "&ge;", "≥" },
    { "&euro;", "€" },
    { "&pound;", "£" },
    { "&yen;", "¥" },
    { "&check;", "✔" },
    { "&cross;", "✗" },
    { "&bull;", "•" },
    { "&nbsp;", " " },
};

const String[] TAGS = {
    "a", "abbr", "b", "br", "center", "code", "del", "details", "div", "em", "font", "i", "img", "ins",
    "kbd", "mark", "p", "pre", "s", "small", "span", "strong", "sub", "summary", "sup", "u",
};

fn bool find(Entry[] refs, String key, String* url)
{
    foreach (r : refs)
    {
        if (r.key.len != key.len || !text::same(r.key, key)) continue;
        *url = r.value;
        return true;
    }
    return false;
}

fn sz numeric(String t, Char32* code)
{
    if (t.len < 4 || t[0] != '&' || t[1] != '#') return 0;
    bool hex = t[2] == 'x' || t[2] == 'X';
    uint n;
    sz first = hex ? 3 : 2;
    for (sz i = first; i < t.len && i < 12; i++)
    {
        char c = t[i];
        if (c == ';')
        {
            *code = n;
            return n > 0 && i > first ? i + 1 : 0;
        }
        if (c.is_digit())
        {
            n = n * (hex ? 16 : 10) + c - '0';
        }
        else if (hex && c.is_xdigit())
        {
            n = n * 16 + text::lower(c) - 'a' + 10;
        }
        else
        {
            return 0;
        }
    }
    return 0;
}

fn bool alnum(char c) => c.is_alnum();

fn bool space(char c) => c == ' ' || c == '\t';

fn sz scanBracket(String s, sz from)
{
    for (sz p = from; p < s.len; p++) if (s[p] == ']') return p;
    return -1;
}

fn sz scanUrl(String s, sz from)
{
    int depth = 1;
    for (sz p = from; p < s.len; p++)
    {
        if (s[p] == '(') depth++;
        if (s[p] == ')' && --depth == 0) return p;
    }
    return -1;
}

struct Inline
{
    ast::Arena* arena;
    Entry[] refs;
    String src;
    sz at;
    sz text;
    List{Span} out;
}

fn void Inline.flush(&self, sz end)
{
    if (end <= self.text) return;
    DString decoded;
    decoded.init(mem, end - self.text + 32);
    defer decoded.free();
    String t = self.src[self.text : end - self.text];
    for (sz i = 0; i < t.len;)
    {
        bool hit;
        Char32 code;
        sz used = numeric(t[i..], &code);
        if (used > 0)
        {
            decoded.append_char32(code);
            i += used;
            continue;
        }
        foreach (e : ENTITIES)
        {
            if (t[i] != '&' || !t[i..].starts_with(e.entity)) continue;
            decoded.append(e.symbol);
            i += e.entity.len;
            hit = true;
            break;
        }
        if (!hit) decoded.append_char(t[i++]);
    }
    self.out.push({ .kind = TEXT, .text = decoded.keep(self.arena) });
}

fn bool Inline.emit(&self, SpanKind kind, String text, String url, sz next, bool nested)
{
    self.flush(self.at);
    Span span = { .kind = kind, .text = self.arena.copy(text), .url = self.arena.copy(url) };
    if (nested) span.children = spans(self.arena, text, self.refs);
    self.out.push(span);
    self.at = next;
    self.text = next;
    return true;
}

fn bool Inline.skip(&self, sz next)
{
    self.flush(self.at);
    self.at = next;
    self.text = next;
    return true;
}

fn bool Inline.formula(&self, SpanKind kind, String latex, sz next)
{
    self.flush(self.at);
    self.out.push({ .kind = kind, .text = tex::unicode(self.arena, latex) });
    self.at = next;
    self.text = next;
    return true;
}

fn bool Inline.footnote(&self)
{
    String s = self.src;
    sz i = self.at;
    if (s[i] != '[' || i + 1 >= s.len || s[i + 1] != '^') return false;
    sz e = i + 2;
    while (e < s.len && !space(s[e]) && s[e] != '\n' && s[e] != ']') e++;
    if (e >= s.len || s[e] != ']') return false;
    return self.emit(FOOTNOTE_REF, s[i + 2 : e - i - 2], "", e + 1, false);
}

fn bool Inline.link(&self, SpanKind kind, sz open)
{
    String s = self.src;
    sz close = scanBracket(s, open + 1);
    if (close < 0) return false;
    String label = s[open + 1 : close - open - 1];
    sz next = close + 1;
    if (next < s.len && s[next] == '(')
    {
        sz end = scanUrl(s, next + 1);
        if (end >= 0) return self.emit(kind, label, s[next + 1 : end - next - 1], end + 1, kind == LINK);
    }
    String key = label;
    if (next < s.len && s[next] == '[')
    {
        sz end = scanBracket(s, next + 1);
        if (end > next + 1) key = s[next + 1 : end - next - 1];
        if (end >= 0) next = end + 1;
    }
    String url;
    if (!find(self.refs, key, &url)) return false;
    return self.emit(kind, label, url, next, kind == LINK);
}

fn bool Inline.angle(&self)
{
    String s = self.src;
    sz i = self.at;
    if (s[i..].starts_with("<!--"))
    {
        sz end = s[i..].index_of("-->") ?? -1;
        return end >= 0 && self.skip(i + end + 3);
    }
    sz close = s[i..].index_of_char('>') ?? -1;
    if (close < 2) return false;
    String inner = s[i + 1 : close - 1];
    sz next = i + close + 1;
    if (!inner.contains(" ") && (inner.contains("://") || inner.contains("@"))) return self.emit(LINK, inner, inner, next, false);
    String name = inner[0] == '/' ? inner[1..] : inner;
    sz end;
    while (end < name.len && name[end].is_alnum()) end++;
    if (end < name.len && name[end] != ' ' && name[end] != '/') return false;
    foreach (tag : TAGS)
    {
        if (!text::same(tag, name[:end]) || tag.len != end) continue;
        self.skip(next);
        if (tag == "br") self.out.push({ .kind = TEXT, .text = "\n" });
        return true;
    }
    return false;
}

fn bool Inline.escaped(&self)
{
    String s = self.src;
    sz i = self.at;
    if (i + 1 >= s.len) return false;
    char c = s[i + 1];
    if (c == '(' || c == '[')
    {
        sz end = s[i + 2..].index_of(c == '(' ? "\\)" : "\\]") ?? -1;
        if (end >= 0) return self.formula(c == '(' ? MATH_INLINE : MATH_DISPLAY, s[i + 2 : end], i + end + 4);
    }
    if (!c.is_punct()) return false;
    self.flush(i);
    self.at = i + 2;
    self.text = i + 1;
    return true;
}

fn bool signals(String latex)
{
    foreach (c : latex) if ("\\^_{}=+-*/<>()|".contains_char(c)) return true;
    return false;
}

fn bool Inline.math(&self)
{
    String s = self.src;
    sz i = self.at;
    bool twice = i + 1 < s.len && s[i + 1] == '$';
    sz start = twice ? i + 2 : i + 1;
    if (start >= s.len || s[start] == '\r' || s[start] == '\n') return false;
    bool padded = space(s[start]);
    for (sz e = start + 1; e < s.len; e++)
    {
        if (s[e] != '$' || space(s[e - 1]) != padded || s[e - 1] == '\\') continue;
        if (twice && (e + 1 >= s.len || s[e + 1] != '$')) continue;
        if (padded && e + 1 < s.len && s[e + 1].is_digit()) continue;
        String latex = s[start : e - start].trim();
        if (latex.len == 0) return false;
        if (padded && latex.contains_char(' ') && !signals(latex)) return false;
        return self.formula(twice ? MATH_DISPLAY : MATH_INLINE, latex, twice ? e + 2 : e + 1);
    }
    return false;
}

fn bool Inline.code(&self)
{
    sz end = self.src[self.at + 1..].index_of_char('`') ?? -1;
    if (end < 0) return false;
    return self.emit(CODE_INLINE, self.src[self.at + 1 : end], "", self.at + end + 2, false);
}

fn bool Inline.strong(&self)
{
    String s = self.src;
    sz i = self.at;
    char m = s[i];
    if (i + 1 >= s.len || s[i + 1] != m || (m == '_' && i > 0 && alnum(s[i - 1]))) return false;
    for (sz e = i + 2; e + 1 < s.len; e++)
    {
        if (s[e] != m || s[e + 1] != m) continue;
        if (m == '_' && e + 2 < s.len && alnum(s[e + 2])) continue;
        return self.emit(BOLD, s[i + 2 : e - i - 2], "", e + 2, true);
    }
    return false;
}

fn bool Inline.strike(&self)
{
    String s = self.src;
    sz i = self.at;
    if (i + 1 >= s.len || s[i + 1] != '~') return false;
    for (sz e = i + 2; e + 1 < s.len; e++)
    {
        if (s[e] == '~' && s[e + 1] == '~') return self.emit(STRIKETHROUGH, s[i + 2 : e - i - 2], "", e + 2, true);
    }
    return false;
}

fn bool Inline.emphasis(&self)
{
    String s = self.src;
    sz i = self.at;
    char m = s[i];
    if (i + 1 >= s.len || space(s[i + 1]) || (m == '_' && i > 0 && alnum(s[i - 1]))) return false;
    for (sz e = i + 1; e < s.len; e++)
    {
        if (s[e] != m || (e + 1 < s.len && s[e + 1] == m)) continue;
        if (m == '_' && e + 1 < s.len && alnum(s[e + 1])) continue;
        if (!space(s[e - 1])) return self.emit(ITALIC, s[i + 1 : e - i - 1], "", e + 1, true);
    }
    return false;
}

fn bool Inline.step(&self)
{
    switch (self.src[self.at])
    {
        case '[': return self.footnote() || self.link(LINK, self.at);
        case '!': return self.at + 1 < self.src.len && self.src[self.at + 1] == '[' && self.link(IMAGE, self.at + 1);
        case '$': return self.math();
        case '`': return self.code();
        case '*': return self.strong() || self.emphasis();
        case '_': return self.strong() || self.emphasis();
        case '~': return self.strike();
        case '<': return self.angle();
        case '\\': return self.escaped();
        default: return false;
    }
}

fn Span[] spans(ast::Arena* arena, String src, Entry[] refs = {})
{
    if (src.len == 0) return {};
    Inline p = { .arena = arena, .refs = refs, .src = src };
    p.out.init(mem, 16);
    defer p.out.free();
    while (p.at < src.len) if (!p.step()) p.at++;
    p.flush(src.len);
    return keep(arena, &p.out);
}
