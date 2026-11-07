module parser;

import std::core::mem;
import std::collections::list;
import ast;

struct Alert
{
    String tag;
    CalloutKind kind;
}

const Alert[] ALERTS = {
    { "> [!NOTE]", NOTE }, { "> [!INFO]", NOTE },
    { "> [!TIP]", TIP }, { "> [!SUCCESS]", TIP },
    { "> [!WARNING]", WARNING },
    { "> [!IMPORTANT]", IMPORTANT },
    { "> [!DANGER]", CAUTION }, { "> [!CAUTION]", CAUTION }, { "> [!ERROR]", CAUTION },
};

const String[] TITLES = { "NOTE", "TIP", "WARNING", "IMPORTANT", "CAUTION" };

$assert(TITLES.len == CalloutKind::len);

const String[] TASKS = { "- [ ] ", "* [ ] ", "- [x] ", "- [X] ", "* [x] ", "* [X] " };

const String[] STARTS = { "```", "~~~", "$$", "\\begin{", ">" };

const String[] ENVIRONMENTS = { "$$", "\\begin{equation}", "\\begin{align}", "\\begin{gather}", "\\begin{aligned}" };

fn bool thematic(String line)
{
    String t = line.trim();
    if (t.len < 3) return false;
    int dashes;
    int stars;
    int underscores;
    foreach (c : t)
    {
        switch (c)
        {
            case '-': dashes++;
            case '*': stars++;
            case '_': underscores++;
            case ' ':
            case '\t': break;
            default: return false;
        }
    }
    return dashes >= 3 || stars >= 3 || underscores >= 3;
}

fn bool separator(String line)
{
    String t = line.trim();
    if (t.len < 3) return false;
    bool dash;
    foreach (c : t)
    {
        if (c == '-')
        {
            dash = true;
        }
        else if (c != '|' && c != ':' && c != ' ' && c != '\t')
        {
            return false;
        }
    }
    return dash;
}

fn int indentOf(String line)
{
    int n;
    while (n < line.len && line[n] == ' ') n++;
    return n;
}

fn bool bullet(String line, int indent)
{
    return (sz)indent + 1 < line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ';
}

fn bool ordered(String line, int indent, int* number, int* prefix)
{
    int p = indent;
    if (p >= line.len || !line[p].is_digit()) return false;
    int n;
    for (; p < line.len && line[p].is_digit(); p++) n = n * 10 + line[p] - '0';
    if ((sz)p + 1 >= line.len || (line[p] != '.' && line[p] != ')') || (line[p + 1] != ' ' && line[p + 1] != '\t')) return false;
    *number = n;
    *prefix = p + 2;
    return true;
}

fn int level(String t)
{
    int h;
    while (h < t.len && t[h] == '#') h++;
    return h >= 1 && h <= 6 && h < t.len && (t[h] == ' ' || t[h] == '\t') ? h : 0;
}

fn bool headingPrefix(String s)
{
    if (s.len < 2 || s[0] != '#') return false;
    int h;
    while (h < s.len && s[h] == '#') h++;
    return h <= 6 && h < s.len && (s[h] == ' ' || s[h] == '\t');
}

fn sz footnoteColon(String t)
{
    if (!t.starts_with("[^")) return -1;
    sz p = 2;
    while (p + 1 < t.len && !(t[p] == ']' && t[p + 1] == ':')) p++;
    return p + 1 < t.len ? p : -1;
}

fn bool blockStart(String line)
{
    String t = line.trim();
    if (t.len == 0 || thematic(line) || headingPrefix(t)) return true;
    foreach (prefix : STARTS) if (t.starts_with(prefix)) return true;
    if (footnoteColon(t) >= 0) return true;
    int indent = indentOf(line);
    int number;
    int prefix;
    return bullet(line, indent) || ordered(line, indent, &number, &prefix);
}

fn Span[][] cells(ast::Arena* arena, String line, int* count)
{
    List{Span[]} list;
    list.init(mem, 8);
    defer list.free();
    String t = line.trim();
    sz i = t.len > 0 && t[0] == '|' ? 1 : 0;
    while (i < t.len)
    {
        sz start = i;
        while (i < t.len && t[i] != '|') i++;
        list.push(spans(arena, t[start : i - start].trim()));
        if (i < t.len) i++;
    }
    *count = (int)list.len();
    return keep(arena, &list);
}

fn Alignment[] alignments(ast::Arena* arena, String line, int columns)
{
    List{Alignment} list;
    list.init(mem, 8);
    defer list.free();
    String t = line.trim();
    sz i = t.len > 0 && t[0] == '|' ? 1 : 0;
    while (i < t.len)
    {
        sz start = i;
        while (i < t.len && t[i] != '|') i++;
        String spec = t[start : i - start].trim();
        if (spec.len > 0)
        {
            bool left = spec[0] == ':';
            bool right = spec[^1] == ':';
            list.push(left && right ? CENTER : right ? RIGHT : LEFT);
        }
        if (i < t.len) i++;
    }
    while (list.len() < columns) list.push(LEFT);
    return keep(arena, &list);
}

macro keep(ast::Arena* arena, list)
{
    var view = list.array_view();
    usz n = (usz)view.len;
    var buf = ($Typeof(view[0])*)arena.alloc((n ?: 1) * $Typeof(view[0])::size);
    foreach (i, x : view) buf[i] = x;
    return buf[:n];
}

struct Parser
{
    Document* doc;
    String[] lines;
    int at;
    List{Block} blocks;
}

fn bool Parser.done(&self) => self.at >= self.lines.len;

fn String Parser.peek(&self, int ahead = 0) => self.lines[self.at + ahead];

fn ast::Arena* Parser.arena(&self) => &self.doc.arena;

fn void Parser.add(&self, Block b) => self.blocks.push(b);

fn void Parser.single(&self, BlockKind kind)
{
    self.add(ast::make(kind, self.at, self.at));
    self.at++;
}

fn void Parser.frontmatter(&self)
{
    int start = self.at++;
    List{Entry} entries;
    entries.init(mem, 16);
    defer entries.free();
    for (; !self.done(); self.at++)
    {
        String t = self.peek().trim();
        if (t == "---" || t == "...") break;
        sz colon = t.index_of_char(':') ?? -1;
        if (colon < 0) continue;
        String value = t[colon + 1..].trim();
        if (value.len >= 2 && (value[0] == '"' || value[0] == '\'') && value[^1] == value[0]) value = value[1 : value.len - 2];
        entries.push({ self.arena().copy(t[:colon].trim()), self.arena().copy(value) });
    }
    if (entries.len() > 0)
    {
        Block b = ast::make(FRONTMATTER, start, self.at);
        b.entries = keep(self.arena(), &entries);
        self.add(b);
    }
    self.at++;
}

fn bool closes(String t, char fence, int length)
{
    if (t.len < length || t[0] != fence) return false;
    int n;
    while (n < t.len && t[n] == fence) n++;
    return n >= length && t[n..].trim().len == 0;
}

fn void Parser.fence(&self)
{
    int start = self.at;
    String t = self.peek().trim();
    char fence = t[0];
    int length;
    while (length < t.len && t[length] == fence) length++;
    List{String} code;
    code.init(mem, 16);
    defer code.free();
    for (self.at++; !self.done() && !closes(self.peek().trim(), fence, length); self.at++)
    {
        code.push(self.arena().copy(self.peek()));
    }
    Block b = ast::make(CODE_BLOCK, start, self.at);
    b.code = { self.arena().copy(t[length..].trim()), keep(self.arena(), &code) };
    self.add(b);
    self.at++;
}

fn void Parser.math(&self)
{
    int start = self.at;
    String line = self.peek();
    String t = line.trim();
    bool dollar = t.starts_with("$$");
    if (dollar && t.len > 4 && t.ends_with("$$"))
    {
        Block b = ast::make(MATH_BLOCK, start, start);
        b.latex = self.arena().copy(t[2 : t.len - 4].trim());
        self.add(b);
        self.at++;
        return;
    }
    List{String} rows;
    rows.init(mem, 16);
    defer rows.free();
    if (!dollar) rows.push(line);
    if (dollar && t.len > 2) rows.push(t[2..]);
    for (self.at++; !self.done(); self.at++)
    {
        String row = self.peek();
        String r = row.trim();
        if (dollar && (r.ends_with("$$") || r.starts_with("$$")))
        {
            if (r.len > 2 && !r.starts_with("$$")) rows.push(r[:r.len - 2]);
            break;
        }
        rows.push(row);
        if (!dollar && r.starts_with("\\end{")) break;
    }
    DString latex;
    latex.init(mem, 512);
    defer latex.free();
    foreach (i, row : rows)
    {
        if (i > 0) latex.append_char(' ');
        latex.append(row);
    }
    Block b = ast::make(MATH_BLOCK, start, self.at);
    b.latex = latex.keep(self.arena());
    self.add(b);
    self.at++;
}

fn void Parser.table(&self)
{
    int start = self.at;
    int columns;
    Span[][] headers = cells(self.arena(), self.peek(), &columns);
    Alignment[] aligns = alignments(self.arena(), self.peek(1), columns);
    List{Span[][]} rows;
    rows.init(mem, 32);
    defer rows.free();
    int count;
    for (self.at += 2; !self.done() && self.peek().trim().starts_with("|"); self.at++)
    {
        rows.push(cells(self.arena(), self.peek(), &count));
    }
    Block b = ast::make(TABLE, start, self.at - 1);
    b.table = { columns, aligns, headers, keep(self.arena(), &rows) };
    self.add(b);
}

fn void Parser.heading(&self)
{
    String t = self.peek().trim();
    int n = level(t);
    Block b = ast::make(HEADING, self.at, self.at, spans(self.arena(), t[n + 1..].trim()));
    b.level = n;
    self.add(b);
    self.at++;
}

fn String Parser.quoted(&self, bool alerts, int* last)
{
    DString body;
    body.init(mem, 512);
    defer body.free();
    for (; !self.done(); self.at++)
    {
        String t = self.peek().trim();
        if (!t.starts_with(">") || (alerts && t.starts_with("> [!"))) break;
        String rest = t[1..];
        if (rest.len > 0 && rest[0] == ' ') rest = rest[1..];
        if (body.len() > 0) body.append_char(' ');
        body.append(rest);
        *last = self.at;
    }
    return body.keep(self.arena());
}

fn void Parser.callout(&self)
{
    int start = self.at;
    String t = self.peek().trim();
    CalloutKind kind = NOTE;
    foreach (a : ALERTS)
    {
        if (!t.starts_with(a.tag)) continue;
        kind = a.kind;
        break;
    }
    int last = start;
    self.at++;
    String body = self.quoted(false, &last);
    Block b = ast::make(CALLOUT, start, last, spans(self.arena(), body));
    b.callout = { kind, TITLES[kind] };
    self.add(b);
}

fn void Parser.quote(&self)
{
    int start = self.at;
    int last = start;
    String body = self.quoted(true, &last);
    self.add(ast::make(BLOCKQUOTE, start, last, spans(self.arena(), body)));
}

fn void Parser.footnote(&self, sz colon)
{
    String t = self.peek().trim();
    Block b = ast::make(FOOTNOTE_DEF, self.at, self.at, spans(self.arena(), t[colon + 2..].trim()));
    b.label = self.arena().copy(t[2 : colon - 2]);
    self.add(b);
    self.at++;
}

fn void Parser.item(&self, ListKind kind, int indent, int number, String rest)
{
    Block b = ast::make(LIST_ITEM, self.at, self.at, spans(self.arena(), rest));
    b.item = { kind, indent, number };
    self.add(b);
    self.at++;
}

fn void Parser.paragraph(&self)
{
    int start = self.at;
    DString body;
    body.init(mem, 512);
    defer body.free();
    do
    {
        if (body.len() > 0) body.append_char(' ');
        body.append(self.peek().trim());
        self.at++;
    }
    while (!self.done() && !blockStart(self.peek()));
    self.add(ast::make(PARAGRAPH, start, self.at - 1, spans(self.arena(), body.str_view())));
}

fn bool Parser.list(&self, String line)
{
    int indent = indentOf(line);
    if ((sz)indent + 5 < line.len)
    {
        foreach (i, task : TASKS)
        {
            if (!line[indent..].starts_with(task)) continue;
            self.item(i < 2 ? TASK_UNCHECKED : TASK_CHECKED, indent, 0, line[indent + 6..]);
            return true;
        }
    }
    if (bullet(line, indent))
    {
        self.item(BULLET, indent, 0, line[indent + 2..]);
        return true;
    }
    int number;
    int prefix;
    if (!ordered(line, indent, &number, &prefix)) return false;
    self.item(ORDERED, indent, number, line[prefix..]);
    return true;
}

fn void Parser.block(&self)
{
    String line = self.peek();
    String t = line.trim();
    sz colon = footnoteColon(t);
    bool math;
    foreach (env : ENVIRONMENTS) math = math || t.starts_with(env);
    switch
    {
        case self.at == 0 && t == "---": self.frontmatter();
        case t.len == 0: self.single(BLANK);
        case t.starts_with("```") || t.starts_with("~~~"): self.fence();
        case math: self.math();
        case t.starts_with("|") && (sz)self.at + 1 < self.lines.len && separator(self.peek(1)): self.table();
        case thematic(line): self.single(THEMATIC_BREAK);
        case level(t) > 0: self.heading();
        case t.starts_with("> [!"): self.callout();
        case colon >= 0: self.footnote(colon);
        case t.starts_with("> ") || t == ">": self.quote();
        default: if (!self.list(line)) self.paragraph();
    }
}

fn String[] split(String content, List{String}* out)
{
    sz at;
    while (at < content.len)
    {
        sz end = content[at..].index_of_char('\n') ?? (content.len - at);
        String line = content[at : end];
        if (line.len > 0 && line[line.len - 1] == '\r') line = line[:line.len - 1];
        out.push(line);
        at += end + 1;
    }
    return out.array_view();
}

fn Document parse(String content)
{
    Document doc;
    doc.arena.init(65536);
    List{String} lines;
    lines.init(mem, 128);
    defer lines.free();
    Parser p = { .doc = &doc, .lines = split(content, &lines) };
    p.blocks.init(mem, 64);
    defer p.blocks.free();
    while (!p.done()) p.block();
    doc.blocks = keep(&doc.arena, &p.blocks);
    return doc;
}
