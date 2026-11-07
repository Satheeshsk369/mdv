module render;

import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import text;

const String[] STYLES = { "", ansi::BOLD, ansi::ITALIC, ansi::STRIKE, ansi::INLINE, "", "", ansi::CYAN, ansi::CYAN, "" };

$assert(STYLES.len == SpanKind::len);

struct Look
{
    String prefix;
    String open;
    String left;
    String right;
    String close;
    bool nested;
    bool url;
}

const Look[] LOOKS = {
    { "", "", "", "", "", false, false },
    { "", ansi::BOLD, "", "", ansi::RESET, true, false },
    { "", ansi::ITALIC, "", "", ansi::RESET, true, false },
    { "", ansi::STRIKE +++ ansi::MUTED, "", "", ansi::RESET, true, false },
    { "", ansi::INLINE +++ " ", "", "", " " +++ ansi::RESET, false, false },
    { "", "", "", "", "", false, false },
    { "", "", "", "", "", false, false },
    { "", ansi::CYAN +++ ansi::UNDERLINE, "", "", ansi::RESET, true, true },
    { "", ansi::CYAN +++ ansi::BOLD, "[", "]", ansi::RESET, false, false },
    { "🖼  ", ansi::CYAN +++ ansi::BOLD, "[", "]", ansi::RESET, false, true },
};

$assert(LOOKS.len == SpanKind::len);

fn void span(DString* b, Span s, bool plain)
{
    Look look = LOOKS[s.kind];
    bool link = !plain && s.kind == SpanKind.LINK && s.url.len > 0;
    b.append(look.prefix);
    if (link)
    {
        b.append("\e]8;;");
        b.append(s.url);
        b.append("\e\\");
    }
    if (!plain) b.append(look.open);
    b.append(look.left);
    if (look.nested && s.children.len > 0)
    {
        spans(b, s.children, plain);
    }
    else
    {
        b.append(s.text);
    }
    b.append(look.right);
    if (!plain) b.append(look.close);
    if (link) b.append("\e]8;;\e\\");
    if (!look.url || s.url.len == 0) return;
    b.append_char(' ');
    if (!plain) b.append(ansi::MUTED);
    b.append_char('(');
    b.append(s.url);
    b.append_char(')');
    if (!plain) b.append(ansi::RESET);
}

fn void spans(DString* b, Span[] list, bool plain)
{
    foreach (s : list) span(b, s, plain);
}

struct Piece
{
    String text;
    int width;
}

struct Wrap
{
    List{Piece}* out;
    ast::Arena* arena;
    DString line;
    String rest;
    int indent;
    int width;
    int max;
    bool plain;
    bool cell;
    bool gap;
}

fn void Wrap.flush(&self)
{
    self.out.push({ self.arena.copy(self.line.str_view()), self.width });
    self.line.clear();
    self.line.append(self.rest);
    self.width = self.indent;
}

fn void Wrap.word(&self, String word, int w, String style)
{
    int space = self.gap ? 1 : 0;
    if (self.width + space + w > self.max && self.width > self.indent)
    {
        self.flush();
    }
    else if (self.width > self.indent && self.gap)
    {
        self.line.append_char(' ');
        self.width++;
    }
    self.gap = false;
    self.line.append(style);
    self.line.append(word);
    if (style.len) self.line.append(ansi::RESET);
    self.width += w;
}

fn void Wrap.url(&self, String url)
{
    int w = text::width(url) + 3;
    if (self.width + w + (self.cell ? 1 : 0) > self.max && self.width > self.indent)
    {
        self.flush();
    }
    else if (!self.cell || self.width > 0)
    {
        self.line.append_char(' ');
        self.width++;
    }
    if (!self.plain) self.line.append(ansi::MUTED);
    self.line.append_char('(');
    self.line.append(url);
    self.line.append_char(')');
    if (!self.plain) self.line.append(ansi::RESET);
    self.width += w;
}

fn bool blank(char c) => c == ' ' || c == '\t';

fn void wrap(List{Piece}* out, ast::Arena* arena, Span[] list, int max, String first, String rest, bool plain, bool cell)
{
    Wrap w = { .out = out, .arena = arena, .rest = rest, .indent = text::width(rest), .width = text::width(first), .max = max, .plain = plain, .cell = cell };
    w.line.init(mem, 4096);
    defer w.line.free();
    w.line.append(first);
    foreach (s : list)
    {
        String style = plain ? "" : STYLES[s.kind];
        String t = s.text;
        sz p;
        while (p < t.len)
        {
            sz from = p;
            while (p < t.len && blank(t[p])) p++;
            if (p > from) w.gap = true;
            if (p >= t.len) break;
            sz start = p;
            while (p < t.len && !blank(t[p]) && t[p] != '\n') p++;
            String word = t[start : p - start];
            w.word(word, text::width(word), style);
        }
        if (s.kind == SpanKind.LINK && s.url.len > 0)
        {
            w.url(s.url);
            w.gap = false;
        }
    }
    if (w.line.len() > 0 || (cell && out.len() == 0)) out.push({ arena.copy(w.line.str_view()), w.width });
}
