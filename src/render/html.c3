module render;

import std::core::mem;
import ast;
import ansi;
import tex;

struct Tag
{
    String open;
    String close;
}

const Tag[] TAGS = {
    { "", "" },
    { "<strong>", "</strong>" },
    { "<em>", "</em>" },
    { "<del>", "</del>" },
    { "<code>", "</code>" },
    { "<span class=\"math\">", "</span>" },
    { "<span class=\"math\">", "</span>" },
    { "", "</a>" },
    { "", "</a></sup>" },
    { "", "" },
};

$assert(TAGS.len == SpanKind::len);

const String[] ALIGNS = { "left", "center", "right" };

const String[] CALLOUTS = { "note", "tip", "warning", "important", "caution" };

$assert(CALLOUTS.len == CalloutKind::len);

const String[] VARIABLES = {
    "text", "muted", "faint", "red", "green", "orange", "yellow", "purple", "cyan",
    "panel", "deep", "row", "focus", "selection", "match",
};

fn uint[15] roles(Palette p) => { p.text, p.muted, p.faint, p.red, p.green, p.orange, p.yellow, p.purple, p.cyan, p.panel, p.deep, p.row, p.focus, p.selection, p.match };

fn void escape(DString* out, String text)
{
    foreach (c : text)
    {
        switch (c)
        {
            case '&': out.append("&amp;");
            case '<': out.append("&lt;");
            case '>': out.append("&gt;");
            case '"': out.append("&quot;");
            case '\n': out.append("<br>");
            default: out.append_char(c);
        }
    }
}

fn void color(DString* out, String property, uint rgb)
{
    uint[15] known = roles(ansi::MDV);
    foreach (i, k : known)
    {
        if (k != rgb) continue;
        out.appendf("%s:var(--%s);", property, VARIABLES[i]);
        return;
    }
    out.appendf("%s:#%06x;", property, rgb);
}

struct Pen
{
    uint fg;
    uint bg;
    bool fore;
    bool back;
    bool bold;
    bool italic;
    bool underline;
    bool strike;
}

fn bool Pen.plain(&self) => !self.fore && !self.back && !self.bold && !self.italic && !self.underline && !self.strike;

fn void Pen.apply(&self, int[] codes)
{
    for (usz i = 0; i < codes.len; i++)
    {
        switch (codes[i])
        {
            case 0: *self = {};
            case 1: self.bold = true;
            case 3: self.italic = true;
            case 4: self.underline = true;
            case 9: self.strike = true;
            case 22: self.bold = false;
            case 23: self.italic = false;
            case 24: self.underline = false;
            case 29: self.strike = false;
            case 39: self.fore = false;
            case 49: self.back = false;
            case 38:
            case 48:
                if (i + 4 >= codes.len || codes[i + 1] != 2) break;
                uint rgb = (uint)codes[i + 2] << 16 | (uint)codes[i + 3] << 8 | (uint)codes[i + 4];
                if (codes[i] == 38)
                {
                    self.fg = rgb;
                    self.fore = true;
                }
                else
                {
                    self.bg = rgb;
                    self.back = true;
                }
                i += 4;
        }
    }
}

fn void Pen.open(&self, DString* out)
{
    out.append("<span style=\"");
    if (self.fore) color(out, "color", self.fg);
    if (self.back) color(out, "background", self.bg);
    if (self.bold) out.append("font-weight:bold;");
    if (self.italic) out.append("font-style:italic;");
    if (self.underline) out.append("text-decoration:underline;");
    if (self.strike) out.append("text-decoration:line-through;");
    out.append("\">");
}

fn void paint(DString* out, String line)
{
    Pen pen;
    bool open;
    usz i;
    while (i < line.len)
    {
        if (line[i] == '\e' && i + 1 < line.len && line[i + 1] == ']')
        {
            i += 2;
            while (i < line.len && line[i] != '\a' && !(line[i] == '\e' && i + 1 < line.len && line[i + 1] == '\\')) i++;
            i += i < line.len && line[i] == '\a' ? 1 : 2;
            continue;
        }
        if (line[i] != '\e' || i + 1 >= line.len || line[i + 1] != '[')
        {
            usz start = i;
            while (i < line.len && line[i] != '\e') i++;
            escape(out, line[start : i - start]);
            continue;
        }
        i += 2;
        int[16] codes;
        int count;
        int value;
        while (i < line.len && !line[i].is_alpha())
        {
            if (line[i] == ';')
            {
                if (count < 16) codes[count++] = value;
                value = 0;
            }
            else if (line[i].is_digit())
            {
                value = value * 10 + line[i] - '0';
            }
            i++;
        }
        if (count < 16) codes[count++] = value;
        char final = i < line.len ? line[i] : 'm';
        i++;
        if (final != 'm') continue;
        pen.apply(codes[:count]);
        if (open) out.append("</span>");
        open = !pen.plain();
        if (open) pen.open(out);
    }
    if (open) out.append("</span>");
}

fn void phrase(DString* out, Span[] list)
{
    foreach (s : list)
    {
        switch (s.kind)
        {
            case LINK:
                out.append("<a href=\"");
                escape(out, s.url);
                out.append("\">");
            case FOOTNOTE_REF:
                out.append("<sup><a class=\"ref\" href=\"#fn-");
                escape(out, s.text);
                out.append("\">");
            case IMAGE:
                out.append("<img src=\"");
                escape(out, s.url);
                out.append("\" alt=\"");
                escape(out, s.text);
                out.append("\">");
                continue;
            default:
                out.append(TAGS[s.kind].open);
        }
        if (s.kind == MATH_INLINE || s.kind == MATH_DISPLAY)
        {
            paint(out, s.text);
        }
        else if (s.children.len > 0 && s.kind != CODE_INLINE)
        {
            phrase(out, s.children);
        }
        else
        {
            escape(out, s.text);
        }
        out.append(TAGS[s.kind].close);
    }
}

fn void html(DString* out, ast::Arena* arena, Block[] blocks)
{
    foreach (i, &b : blocks)
    {
        switch (b.kind)
        {
            case BLANK:
                continue;
            case FRONTMATTER:
                out.append("<dl class=\"front\">");
                foreach (e : b.entries)
                {
                    out.append("<dt>");
                    escape(out, e.key);
                    out.append("</dt><dd>");
                    escape(out, e.value);
                    out.append("</dd>");
                }
                out.append("</dl>\n");
            case HEADING:
                out.appendf("<h%d id=\"line-%d\">", b.level, b.start);
                phrase(out, b.spans);
                out.appendf("</h%d>\n", b.level);
            case PARAGRAPH:
                out.append("<p>");
                phrase(out, b.spans);
                out.append("</p>\n");
            case CODE_BLOCK:
                out.append("<pre class=\"code\"><code>");
                DString line;
                line.init(mem, 256);
                defer line.free();
                foreach (text : b.code.lines)
                {
                    line.clear();
                    highlight(&line, text, b.code.language, false);
                    paint(out, line.str_view());
                    out.append_char('\n');
                }
                out.append("</code></pre>\n");
            case BLOCKQUOTE:
                out.append("<blockquote>");
                html(out, arena, b.children);
                out.append("</blockquote>\n");
            case CALLOUT:
                out.appendf("<blockquote class=\"callout %s\"><div class=\"title\">%s</div>", CALLOUTS[b.callout.kind], b.callout.title);
                html(out, arena, b.children);
                out.append("</blockquote>\n");
            case LIST_ITEM:
                out.appendf("<div class=\"item\" style=\"--depth:%d\"><span class=\"marker\">", b.item.indent);
                switch (b.item.kind)
                {
                    case BULLET: out.append(BULLETS[min(b.item.indent / 2, 2)]);
                    case ORDERED: out.appendf("%d.", b.item.number);
                    case TASK_CHECKED: out.append("✔");
                    case TASK_UNCHECKED: out.append("☐");
                }
                out.append("</span><span>");
                phrase(out, b.spans);
                out.append("</span></div>\n");
            case TABLE:
                out.append("<table><thead><tr>");
                foreach (c, cell : b.table.headers)
                {
                    out.appendf("<th style=\"text-align:%s\">", ALIGNS[c < b.table.aligns.len ? b.table.aligns[c] : Alignment.LEFT]);
                    phrase(out, cell);
                    out.append("</th>");
                }
                out.append("</tr></thead><tbody>");
                foreach (row : b.table.rows)
                {
                    out.append("<tr>");
                    foreach (c, cell : row)
                    {
                        out.appendf("<td style=\"text-align:%s\">", ALIGNS[c < b.table.aligns.len ? b.table.aligns[c] : Alignment.LEFT]);
                        phrase(out, cell);
                        out.append("</td>");
                    }
                    out.append("</tr>");
                }
                out.append("</tbody></table>\n");
            case THEMATIC_BREAK:
                out.append("<hr>\n");
            case MATH_BLOCK:
                MathBox box = tex::latex(arena, b.latex);
                out.append("<pre class=\"math\">");
                foreach (row : box.rows[:box.height])
                {
                    paint(out, row);
                    out.append_char('\n');
                }
                out.append("</pre>\n");
            case FOOTNOTE_DEF:
                out.append("<div class=\"footnote\" id=\"fn-");
                escape(out, b.label);
                out.append("\"><sup>");
                escape(out, b.label);
                out.append("</sup> ");
                phrase(out, b.spans);
                out.append("</div>\n");
        }
    }
}

fn void theme(DString* out, Palette p)
{
    uint[15] values = roles(p);
    out.append(":root{");
    foreach (i, v : values) out.appendf("--%s:#%06x;", VARIABLES[i], v);
    out.appendf("--bg:#%06x;", p.background ?: 0x1B1B1B);
    out.append("}");
}
