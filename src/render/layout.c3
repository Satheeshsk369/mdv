module render;

import std::io;
import std::math;
import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import tex;
import text;

struct Banner
{
    String icon;
    String label;
    Role color;
}

const Banner[] BANNERS = {
    { "ℹ", "NOTE", CYAN },
    { "💡", "TIP", GREEN },
    { "⚠", "WARNING", ORANGE },
    { "🔔", "IMPORTANT", PURPLE },
    { "⛔", "CAUTION", PINK },
};

$assert(BANNERS.len == CalloutKind::len);

const String[] BULLETS = { "• ", "◦ ", "▪ " };

struct Renderer
{
    Page* page;
    Config config;
    int width;
    int block;
    List{Line} lines;
    List{Piece} pieces;
    DString buf;
}

fn void Renderer.emit(&self, String s, int src)
{
    self.lines.push({ self.page.arena.copy(s), src, self.block });
}

fn void Renderer.flush(&self, int src)
{
    self.emit(self.buf.str_view(), src);
    self.buf.clear();
}

fn void Renderer.rule(&self, int src)
{
    if (!self.config.plain) self.buf.append(ansi::style(MUTED));
    self.buf.repeat("─", self.width > 20 ? self.width - 4 : 76);
    if (!self.config.plain) self.buf.append(ansi::RESET);
    self.flush(src);
}

fn void Renderer.paragraph(&self, Span[] list, int src, int max, String first, String rest)
{
    if (list.len == 0)
    {
        if (first.len > 0) self.emit(first, src);
        return;
    }
    if (self.config.noWrap || max <= 20)
    {
        self.buf.append(first);
        spans(&self.buf, list, self.config.plain);
        @pool()
        {
            foreach (part : self.buf.str_view().tsplit("\n")) self.emit(part, src);
        };
        self.buf.clear();
        return;
    }
    self.pieces.clear();
    wrap(&self.pieces, &self.page.arena, list, max, first, rest, self.config.plain, false);
    foreach (p : self.pieces) self.lines.push({ p.text, src, self.block });
}

fn void Renderer.frontmatter(&self, Block* b)
{
    int keys = 5;
    foreach (e : b.entries) if (e.key.len <= 20) keys = max(keys, (int)e.key.len);
    bool plain = self.config.plain;
    foreach (i, e : b.entries)
    {
        if (!plain) self.buf.append(ansi::style(NOTE));
        self.buf.append(e.key);
        if (!plain) self.buf.append(ansi::RESET);
        self.buf.append(":");
        self.buf.spaces(max(keys - (int)e.key.len, 0) + 1);
        if (!plain) self.buf.append(ansi::style(TEXT));
        self.buf.append(e.value);
        if (!plain) self.buf.append(ansi::RESET);
        self.flush(b.start + 1 + (int)i);
    }
    self.rule(b.end);
}

fn void Renderer.heading(&self, Block* b)
{
    if (self.block > 0) self.emit("", max(b.start - 1, 0));
    if (self.config.plain)
    {
        self.buf.append_char_repeat('#', b.level);
        self.buf.append_char(' ');
    }
    else
    {
        self.buf.append(ansi::heading(math::clamp(b.level, 1, 6)));
    }
    spans(&self.buf, b.spans, self.config.plain);
    if (!self.config.plain) self.buf.append(ansi::RESET);
    self.page.anchors[self.block] = (int)self.lines.len();
    self.flush(b.start);
}

fn void Renderer.callout(&self, Block* b)
{
    if (self.config.plain)
    {
        self.buf.append("| [!");
        self.buf.append(b.callout.title);
        self.buf.append("]");
    }
    else
    {
        Banner banner = BANNERS[b.callout.kind];
        self.buf.append(ansi::style(banner.color));
        self.buf.append(ansi::BOLD);
        self.buf.append("│ ");
        self.buf.append(banner.icon);
        self.buf.append(" ");
        self.buf.append(banner.label);
        self.buf.append(ansi::RESET);
    }
    self.flush(b.start);
    self.nested(b.children, self.config.plain ? "" : ansi::style(BANNERS[b.callout.kind].color));
}

fn void Renderer.nested(&self, Block[] children, String color)
{
    sz from = self.lines.len();
    self.width -= 2;
    foreach (&c : children) self.render(c);
    self.width += 2;
    foreach (&line : self.lines.array_view()[from..])
    {
        self.buf.append(color);
        self.buf.append("│");
        if (color.len > 0) self.buf.append(ansi::RESET);
        if (line.text.len > 0)
        {
            self.buf.append_char(' ');
            self.buf.append(line.text);
        }
        line.text = self.page.arena.copy(self.buf.str_view());
        self.buf.clear();
    }
}

fn void Renderer.item(&self, Block* b)
{
    DString first;
    DString rest;
    first.init(mem, 64);
    rest.init(mem, 64);
    defer first.free();
    defer rest.free();
    int indent = b.item.indent;
    first.spaces(indent);
    rest.spaces(indent);
    switch (b.item.kind)
    {
        case TASK_UNCHECKED:
            first.append("☐  ");
            rest.append("   ");
        case TASK_CHECKED:
            first.append("✔  ");
            rest.append("   ");
        case ORDERED:
            first.appendf("%d. ", b.item.number);
            rest.spaces(text::width(first.str_view()) - indent);
        case BULLET:
            String bullet = BULLETS[min(indent / 2, 2)];
            first.append(bullet);
            rest.spaces(text::width(bullet));
    }
    self.paragraph(b.spans, b.start, self.width - 4, first.str_view(), rest.str_view());
}

fn void Renderer.footnote(&self, Block* b)
{
    DString first;
    first.init(mem, 64);
    defer first.free();
    first.appendf("  [%s] ", b.label);
    DString rest;
    rest.init(mem, 64);
    defer rest.free();
    rest.spaces(text::width(first.str_view()));
    self.paragraph(b.spans, b.start, self.width - 4, first.str_view(), rest.str_view());
}

fn void Renderer.math(&self, Block* b)
{
    MathBox box = tex::latex(&self.page.arena, b.latex);
    self.emit("", b.start);
    foreach (row : box.rows[:box.height])
    {
        self.buf.spaces(4);
        if (self.config.plain)
        {
            self.buf.bare(row);
        }
        else
        {
            self.buf.append(row);
        }
        self.flush(b.start);
    }
    self.emit("", b.end);
}

fn void Renderer.render(&self, Block* b)
{
    switch (b.kind)
    {
        case FRONTMATTER: self.frontmatter(b);
        case FOOTNOTE_DEF: self.footnote(b);
        case BLANK: self.emit("", b.start);
        case THEMATIC_BREAK: self.rule(b.start);
        case HEADING: self.heading(b);
        case CODE_BLOCK:
            foreach (i, line : b.code.lines)
            {
                highlight(&self.buf, line, b.code.language, self.config.plain);
                self.flush(b.start + (int)i);
            }
        case CALLOUT: self.callout(b);
        case BLOCKQUOTE: self.nested(b.children, "");
        case LIST_ITEM: self.item(b);
        case TABLE: self.table(&b.table, b.start);
        case MATH_BLOCK: self.math(b);
        case PARAGRAPH: self.paragraph(b.spans, b.start, self.width - 2, "", "");
    }
}

fn Page layout(Document* doc, Config config)
{
    Page page;
    page.arena.init(65536);
    int* anchors = page.arena.alloc(((usz)doc.blocks.len ?: 1) * int::size);
    page.anchors = anchors[:doc.blocks.len];
    Renderer r = { .page = &page, .config = config, .width = config.width < 20 ? 80 : config.width };
    r.lines.init(mem, 256);
    r.pieces.init(mem, 16);
    r.buf.init(mem, 4096);
    defer r.lines.free();
    defer r.pieces.free();
    defer r.buf.free();
    foreach (i, &b : doc.blocks)
    {
        r.block = (int)i;
        page.anchors[i] = (int)r.lines.len();
        r.render(b);
    }
    usz n = (usz)r.lines.len();
    Line* lines = page.arena.alloc((n ?: 1) * Line::size);
    foreach (i, line : r.lines) lines[i] = line;
    page.lines = lines[:n];
    return page;
}

fn void print(Document* doc, Config config)
{
    Page page = layout(doc, config);
    defer page.free();
    foreach (line : page.lines) io::printn(line.text);
}
