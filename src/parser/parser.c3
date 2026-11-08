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

const String[] STARTS = { "```", "~~~", "$$", "\\[", "\\begin{", ">", "<!--" };

const String[] ENVIRONMENTS = { "$$", "\\[", "\\begin{equation}", "\\begin{align}", "\\begin{gather}", "\\begin{aligned}" };

struct Delimiter
{
    String open;
    String close;
}

const Delimiter[] DISPLAYS = { { "$$", "$$" }, { "\\[", "\\]" } };

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

fn int setext(String line)
{
    String t = line.trim();
    if (t.len == 0 || (t[0] != '=' && t[0] != '-')) return 0;
    foreach (c : t) if (c != t[0]) return 0;
    return t[0] == '=' ? 1 : 2;
}

fn bool definition(String t, Entry* entry)
{
    if (t.len < 4 || t[0] != '[' || t[1] == '^') return false;
    sz close = t.index_of("]:") ?? -1;
    if (close < 2) return false;
    String url = t[close + 2..].trim();
    sz end = url.index_of_char(' ') ?? url.len;
    url = url[:end];
    if (url.len >= 2 && url[0] == '<' && url[^1] == '>') url = url[1 : url.len - 2];
    if (url.len == 0) return false;
    *entry = { t[1 : close - 1], url };
    return true;
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

fn Span[][] cells(ast::Arena* arena, Entry[] refs, String line, int* count)
{
    List{Span[]} list;
    list.init(mem, 8);
    defer list.free();
    String t = line.trim();
    sz i = t.len > 0 && t[0] == '|' ? 1 : 0;
    while (i < t.len)
    {
        sz start = i;
        while (i < t.len && (t[i] != '|' || t[i - 1] == '\\')) i++;
        list.push(spans(arena, t[start : i - start].trim(), refs));
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
    Entry[] refs;
    int at;
    int base;
    List{Block} blocks;
}

fn bool Parser.done(&self) => self.at >= self.lines.len;

fn String Parser.peek(&self, int ahead = 0) => self.lines[self.at + ahead];

fn ast::Arena* Parser.arena(&self) => &self.doc.arena;

fn Span[] Parser.spans(&self, String src) => spans(self.arena(), src, self.refs);

fn void Parser.add(&self, Block b)
{
    b.start += self.base;
    b.end += self.base;
    self.blocks.push(b);
}

fn Block[] Parser.inner(&self, String[] lines, int base)
{
    Parser p = { .doc = self.doc, .lines = lines, .refs = self.refs, .base = self.base + base };
    p.blocks.init(mem, 16);
    defer p.blocks.free();
    while (!p.done()) p.block();
    return keep(self.arena(), &p.blocks);
}

fn String Parser.join(&self, String[] rows)
{
    DString latex;
    latex.init(mem, 512);
    defer latex.free();
    foreach (i, row : rows)
    {
        if (i > 0) latex.append_char(' ');
        latex.append(row);
    }
    return latex.keep(self.arena());
}

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
    String language = t[length..].trim();
    Block b = ast::make(language == "math" ? MATH_BLOCK : CODE_BLOCK, start, self.at);
    if (language == "math")
    {
        b.latex = self.join(code.array_view());
    }
    else
    {
        b.code = { self.arena().copy(language), keep(self.arena(), &code) };
    }
    self.add(b);
    self.at++;
}

fn void Parser.indented(&self)
{
    int start = self.at;
    int last = start;
    for (; !self.done(); self.at++)
    {
        String line = self.peek();
        if (line.trim().len == 0) continue;
        if (!line.starts_with("    ") && !line.starts_with("\t")) break;
        last = self.at;
    }
    List{String} code;
    code.init(mem, 16);
    defer code.free();
    foreach (line : self.lines[start..last])
    {
        String body = line.starts_with("\t") ? line[1..] : line.len >= 4 ? line[4..] : "";
        code.push(self.arena().copy(body));
    }
    Block b = ast::make(CODE_BLOCK, start, last);
    b.code = { "", keep(self.arena(), &code) };
    self.add(b);
    self.at = last + 1;
}

fn bool Parser.standalone(&self, String line)
{
    if (!line.starts_with("    ") && !line.starts_with("\t")) return false;
    Block[] seen = self.blocks.array_view();
    if (seen.len > 0 && seen[^1].kind != BLANK) return false;
    foreach_r (b : seen) if (b.kind != BLANK) return b.kind != LIST_ITEM;
    return true;
}

fn void Parser.comment(&self)
{
    while (!self.done() && !self.peek().contains("-->")) self.at++;
    self.drop();
}

fn void Parser.drop(&self)
{
    self.at++;
    Block[] seen = self.blocks.array_view();
    if (seen.len > 0 && seen[^1].kind == BLANK && !self.done() && self.peek().trim().len == 0) self.at++;
}

fn void Parser.math(&self)
{
    int start = self.at;
    String line = self.peek();
    String t = line.trim();
    Delimiter d;
    foreach (x : DISPLAYS) if (t.starts_with(x.open)) d = x;
    bool delimited = d.open.len > 0;
    String rest = t[d.open.len..];
    if (delimited && rest.len > d.close.len && rest.ends_with(d.close))
    {
        Block b = ast::make(MATH_BLOCK, start, start);
        b.latex = self.arena().copy(rest[:rest.len - d.close.len].trim());
        self.add(b);
        self.at++;
        return;
    }
    List{String} rows;
    rows.init(mem, 16);
    defer rows.free();
    if (!delimited) rows.push(line);
    if (delimited && rest.len > 0) rows.push(rest);
    for (self.at++; !self.done(); self.at++)
    {
        String row = self.peek();
        String r = row.trim();
        if (delimited && (r.ends_with(d.close) || r.starts_with(d.close)))
        {
            if (r.len > d.close.len && !r.starts_with(d.close)) rows.push(r[:r.len - d.close.len]);
            break;
        }
        rows.push(row);
        if (!delimited && r.starts_with("\\end{")) break;
    }
    Block b = ast::make(MATH_BLOCK, start, self.at);
    b.latex = self.join(rows.array_view());
    self.add(b);
    self.at++;
}

fn void Parser.table(&self)
{
    int start = self.at;
    int columns;
    Span[][] headers = cells(self.arena(), self.refs, self.peek(), &columns);
    Alignment[] aligns = alignments(self.arena(), self.peek(1), columns);
    List{Span[][]} rows;
    rows.init(mem, 32);
    defer rows.free();
    int count;
    for (self.at += 2; !self.done() && self.peek().trim().starts_with("|"); self.at++)
    {
        rows.push(cells(self.arena(), self.refs, self.peek(), &count));
    }
    Block b = ast::make(TABLE, start, self.at - 1);
    b.table = { columns, aligns, headers, keep(self.arena(), &rows) };
    self.add(b);
}

fn void Parser.heading(&self)
{
    String t = self.peek().trim();
    int n = level(t);
    Block b = ast::make(HEADING, self.at, self.at, self.spans(t[n + 1..].trim()));
    b.level = n;
    self.add(b);
    self.at++;
}

fn Block[] Parser.quoted(&self, bool alerts, int* last)
{
    int base = self.at;
    List{String} rows;
    rows.init(mem, 16);
    defer rows.free();
    for (; !self.done(); self.at++)
    {
        String t = self.peek().trim();
        if (!t.starts_with(">") || (alerts && t.starts_with("> [!"))) break;
        String rest = t[1..];
        if (rest.len > 0 && rest[0] == ' ') rest = rest[1..];
        rows.push(rest);
        *last = self.at;
    }
    return self.inner(rows.array_view(), base);
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
    Block b = ast::make(CALLOUT, start, start);
    b.children = self.quoted(false, &last);
    b.end = last;
    b.callout = { kind, TITLES[kind] };
    self.add(b);
}

fn void Parser.quote(&self)
{
    int start = self.at;
    int last = start;
    Block b = ast::make(BLOCKQUOTE, start, start);
    b.children = self.quoted(true, &last);
    b.end = last;
    self.add(b);
}

fn void Parser.footnote(&self, sz colon)
{
    String t = self.peek().trim();
    Block b = ast::make(FOOTNOTE_DEF, self.at, self.at, self.spans(t[colon + 2..].trim()));
    b.label = self.arena().copy(t[2 : colon - 2]);
    self.add(b);
    self.at++;
}

fn void Parser.item(&self, ListKind kind, int indent, int number, String rest)
{
    Block b = ast::make(LIST_ITEM, self.at, self.at, self.spans(rest));
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
    while (true)
    {
        String raw = self.peek();
        String t = raw.trim();
        self.at++;
        bool more = !self.done() && setext(self.peek()) == 0 && !blockStart(self.peek());
        bool slash = more && t.ends_with("\\");
        body.append(slash ? t[:t.len - 1] : t);
        if (!more) break;
        body.append_char(slash || raw.ends_with("  ") ? '\n' : ' ');
    }
    int rank = self.done() ? 0 : setext(self.peek());
    if (rank == 0)
    {
        self.add(ast::make(PARAGRAPH, start, self.at - 1, self.spans(body.str_view())));
        return;
    }
    Block b = ast::make(HEADING, start, self.at, self.spans(body.str_view()));
    b.level = rank;
    self.add(b);
    self.at++;
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
    Entry entry;
    switch
    {
        case t.len == 0: self.single(BLANK);
        case self.standalone(line): self.indented();
        case t.starts_with("```") || t.starts_with("~~~"): self.fence();
        case t.starts_with("<!--"): self.comment();
        case definition(t, &entry): self.drop();
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
    List{Entry} refs;
    refs.init(mem, 8);
    defer refs.free();
    String[] all = split(content, &lines);
    foreach (line : all)
    {
        Entry entry;
        if (definition(line.trim(), &entry)) refs.push({ doc.arena.copy(entry.key), doc.arena.copy(entry.value) });
    }
    doc.refs = keep(&doc.arena, &refs);
    Parser p = { .doc = &doc, .lines = all, .refs = doc.refs };
    p.blocks.init(mem, 64);
    defer p.blocks.free();
    if (all.len > 0 && all[0].trim() == "---") p.frontmatter();
    while (!p.done()) p.block();
    doc.blocks = keep(&doc.arena, &p.blocks);
    return doc;
}

fn int locate(Block[] blocks, int line)
{
    int lo;
    int hi = (int)blocks.len;
    while (lo < hi)
    {
        int mid = (lo + hi) / 2;
        bool before = blocks[mid].start <= line;
        lo = before ? mid + 1 : lo;
        hi = before ? hi : mid;
    }
    return lo - 1;
}

fn void shift(Block[] blocks, int delta)
{
    foreach (&b : blocks)
    {
        b.start += delta;
        b.end += delta;
        shift(b.children, delta);
    }
}

fn bool defines(String[] lines)
{
    foreach (line : lines) if (line.contains("]:")) return true;
    return false;
}

fn bool alike(Block[] a, Block[] b)
{
    if (a.len == 0 || b.len == 0 || a[^1].kind != b[^1].kind) return false;
    BlockKind x = BLANK;
    BlockKind y = BLANK;
    foreach_r (block : a) if (block.kind != BLANK) { x = block.kind; break; }
    foreach_r (block : b) if (block.kind != BLANK) { y = block.kind; break; }
    return x == y;
}

fn bool reparse(Document* doc, List{Block}* blocks, String before, String after, Splice* splice)
{
    List{String} was;
    was.init(mem, 1024);
    defer was.free();
    List{String} now;
    now.init(mem, 1024);
    defer now.free();
    String[] old = split(before, &was);
    String[] fresh = split(after, &now);
    int limit = (int)min(old.len, fresh.len);
    int first;
    while (first < limit && old[first] == fresh[first]) first++;
    int same;
    while (same < limit - first && old[old.len - 1 - same] == fresh[fresh.len - 1 - same]) same++;
    if (defines(old[first : old.len - same - first]) || defines(fresh[first : fresh.len - same - first])) return false;
    Block[] seen = blocks.array_view();
    if (seen.len == 0) return false;
    int restart = max(locate(seen, first - 1) - 1, 0);
    if (restart == 0 && fresh.len > 0 && fresh[0].trim() == "---") return false;
    int delta = (int)fresh.len - (int)old.len;
    int changed = (int)fresh.len - same;
    Parser p = { .doc = doc, .lines = fresh, .refs = doc.refs, .at = restart == 0 ? 0 : seen[restart].start };
    p.blocks.init(mem, seen.len + 64);
    p.blocks.push_all(seen[:restart]);
    int resume = (int)seen.len;
    while (!p.done())
    {
        p.block();
        if (p.at < changed) continue;
        int k = locate(seen, p.at - delta);
        if (k < restart || seen[k].start != p.at - delta || !alike(p.blocks.array_view(), seen[:k])) continue;
        resume = k;
        break;
    }
    *splice = { restart, resume - restart, (int)p.blocks.len() - restart, delta };
    shift(seen[resume..], delta);
    p.blocks.push_all(seen[resume..]);
    blocks.free();
    *blocks = p.blocks;
    doc.blocks = blocks.array_view();
    return true;
}
