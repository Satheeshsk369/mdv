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
};

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
    if (nested) span.children = spans(self.arena, text);
    self.out.push(span);
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
    if (close < 0 || close + 1 >= s.len || s[close + 1] != '(') return false;
    sz end = scanUrl(s, close + 2);
    if (end < 0) return false;
    return self.emit(kind, s[open + 1 : close - open - 1], s[close + 2 : end - close - 2], end + 1, kind == LINK);
}

fn bool Inline.math(&self)
{
    String s = self.src;
    sz i = self.at;
    bool twice = i + 1 < s.len && s[i + 1] == '$';
    sz start = twice ? i + 2 : i + 1;
    if (start >= s.len || space(s[start]) || s[start] == '\r' || s[start] == '\n') return false;
    for (sz e = start; e < s.len; e++)
    {
        if (s[e] != '$' || space(s[e - 1]) || s[e - 1] == '\\') continue;
        if (twice && (e + 1 >= s.len || s[e + 1] != '$')) continue;
        self.flush(i);
        self.out.push({ .kind = twice ? MATH_DISPLAY : MATH_INLINE, .text = tex::unicode(self.arena, s[start : e - start]) });
        self.at = twice ? e + 2 : e + 1;
        self.text = self.at;
        return true;
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
        default: return false;
    }
}

fn Span[] spans(ast::Arena* arena, String src)
{
    if (src.len == 0) return {};
    Inline p = { .arena = arena, .src = src };
    p.out.init(mem, 16);
    defer p.out.free();
    while (p.at < src.len) if (!p.step()) p.at++;
    p.flush(src.len);
    return keep(arena, &p.out);
}
