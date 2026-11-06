module app;

import std::io;
import std::math;
import std::collections::list;
import std::encoding::base64;
import ast;
import parser;
import render;
import ansi;
import terminal;
import text;

enum Mode
{
    NORMAL,
    HELP,
    SEARCH,
    JUMP,
    OUTLINE,
    FILES
}

enum Act
{
    NONE,
    QUIT,
    CLEAR,
    DOWN,
    UP,
    WHEELDOWN,
    WHEELUP,
    LEFT,
    RIGHT,
    WRAP,
    HALFDOWN,
    HALFUP,
    TOP,
    BOTTOM,
    HELP,
    OUTLINE,
    FILES,
    SEARCH,
    NEXT,
    PREV,
    JUMP,
    EDIT,
    COPY,
    CLOSE,
    OPEN,
    ALL,
    TOGGLE
}

struct Bind
{
    int key;
    Act act;
}

const Bind[] MOTION = {
    { 'j', DOWN }, { terminal::DOWN, DOWN },
    { 'k', UP }, { terminal::UP, UP },
    { terminal::WHEELDOWN, WHEELDOWN }, { terminal::WHEELUP, WHEELUP },
    { terminal::PAGEDOWN, HALFDOWN }, { ' ', HALFDOWN }, { terminal::HALFDOWN, HALFDOWN }, { 'd', HALFDOWN }, { 'D', HALFDOWN },
    { terminal::PAGEUP, HALFUP }, { terminal::SHIFTSPACE, HALFUP }, { terminal::HALFUP, HALFUP }, { 'b', HALFUP }, { 'B', HALFUP }, { 'u', HALFUP }, { 'U', HALFUP },
    { 'g', TOP }, { terminal::HOME, TOP },
    { 'G', BOTTOM }, { terminal::END, BOTTOM },
};

const Bind[] DOCUMENT = {
    { 'q', QUIT }, { 'Q', QUIT },
    { terminal::ESC, CLEAR },
    { terminal::LEFT, LEFT }, { 'h', LEFT }, { 'H', LEFT },
    { terminal::RIGHT, RIGHT }, { 'l', RIGHT }, { 'L', RIGHT },
    { 'w', WRAP }, { 'W', WRAP },
    { '?', HELP }, { 31, HELP },
    { terminal::TAB, OUTLINE }, { 't', OUTLINE }, { 'T', OUTLINE },
    { 'o', FILES }, { 'O', FILES },
    { '/', SEARCH },
    { 'n', NEXT },
    { 'N', PREV },
    { ':', JUMP },
    { 'e', EDIT }, { 'E', EDIT },
    { 'y', COPY }, { 'Y', COPY },
};

const Bind[] CONTENTS = {
    { terminal::ESC, CLOSE }, { terminal::TAB, CLOSE }, { 't', CLOSE }, { 'T', CLOSE }, { 'q', CLOSE },
    { terminal::LEFT, CLOSE }, { 'h', CLOSE }, { 'H', CLOSE },
    { terminal::ENTER, OPEN }, { terminal::RIGHT, OPEN }, { 'l', OPEN }, { 'L', OPEN },
};

const Bind[] BROWSER = {
    { terminal::ESC, CLOSE }, { 'o', CLOSE }, { 'O', CLOSE }, { 'q', CLOSE },
    { 'j', DOWN }, { terminal::DOWN, DOWN },
    { 'k', UP }, { terminal::UP, UP },
    { 'g', TOP }, { terminal::HOME, TOP },
    { 'G', BOTTOM }, { terminal::END, BOTTOM },
    { 'a', ALL }, { 'A', ALL },
    { terminal::LEFT, LEFT }, { 'h', LEFT }, { 'H', LEFT },
    { terminal::RIGHT, RIGHT }, { 'l', RIGHT }, { 'L', RIGHT },
    { ' ', TOGGLE },
    { terminal::ENTER, OPEN },
};

const Bind[] MODAL = {
    { terminal::ESC, CLOSE }, { 'q', CLOSE }, { 'Q', CLOSE }, { '?', CLOSE }, { 31, CLOSE },
    { terminal::ENTER, CLOSE }, { terminal::TAB, CLOSE }, { terminal::LEFT, CLOSE }, { 'h', CLOSE }, { 'H', CLOSE },
};

const String[] GUIDE = {
    "\e[38;2;102;217;239m\e[1mVertical Navigation:\e[0m",
    "  \e[38;2;230;219;116mj / ↓\e[0m                 Scroll down (accelerated)",
    "  \e[38;2;230;219;116mk / ↑\e[0m                 Scroll up (accelerated)",
    "  \e[38;2;230;219;116md / Ctrl+D / Space\e[0m    Half-page scroll down",
    "  \e[38;2;230;219;116mu / Ctrl+U / Shift+Sp\e[0m Half-page scroll up",
    "  \e[38;2;230;219;116mg / G\e[0m                 Jump to Top / Bottom",
    "  \e[38;2;230;219;116m: <line>\e[0m              Goto line number (e.g. :42)",
    "",
    "\e[38;2;102;217;239m\e[1mHorizontal & Layout:\e[0m",
    "  \e[38;2;230;219;116mw\e[0m                     Toggle Wrap / No-Wrap mode",
    "  \e[38;2;230;219;116mh / l / ← / →\e[0m         Horizontal scroll (accelerated)",
    "",
    "\e[38;2;102;217;239m\e[1mFeatures & Actions:\e[0m",
    "  \e[38;2;166;226;46mTab / t\e[0m               Toggle Document Outline (Table of Contents)",
    "  \e[38;2;166;226;46mo\e[0m                     Switch Document (Markdown File Tree)",
    "  \e[38;2;166;226;46m/\e[0m                     In-document search (n next, N prev)",
    "  \e[38;2;166;226;46me\e[0m                     Open $EDITOR at current line",
    "  \e[38;2;166;226;46my\e[0m                     Copy document to clipboard (OSC 52)",
    "  \e[38;2;166;226;46m?\e[0m                     Show / hide this help screen",
};

fn Act lookup(Bind[] table, int key)
{
    foreach (b : table) if (b.key == key) return b.act;
    return NONE;
}

struct Velocity
{
    ulong time;
    int dir;
    int speed;
}

fn int Velocity.next(&self, int dir, int max, ulong window)
{
    ulong now = terminal::now();
    if (self.dir == dir && now - self.time <= window)
    {
        if (self.speed < max) self.speed++;
    }
    else
    {
        self.speed = 1;
        self.dir = dir;
    }
    self.time = now;
    return self.speed;
}

struct Heading
{
    int level;
    String title;
    int src;
    int line;
}

struct View
{
    Mode mode;
    char[256] path;
    String content;
    Document doc;
    VisualDocument lines;
    RenderConfig config;
    terminal::Stamp stamp;
    int width;
    int height;
    int rows;
    int top;
    int left;
    int cursor;
    int changed;
    List{Heading} outline;
    int heading;
    Tree tree;
    char[128] query;
    int queryLen;
    char[32] jump;
    int jumpLen;
    List{int} matches;
    int match;
    char[128] status;
    int ticks;
    Velocity velocity;
    DString frame;
}

fn String View.name(&self) => ((ZString)&self.path).str_view();

fn int View.total(&self) => (int)self.lines.lines.len;

fn int View.last(&self) => self.total() > 0 ? self.total() - 1 : 0;

fn void View.say(&self, String message)
{
    sz n = min(message.len, (sz)127);
    self.status[:n] = message[:n];
    self.status[n] = 0;
    self.ticks = 40;
}

fn void View.index(&self)
{
    self.outline.clear();
    int total = self.total();
    foreach (&b : self.doc.blocks)
    {
        if (b.kind != BlockKind.HEADING) continue;
        DString title;
        title.init(mem, 128);
        defer title.free();
        foreach (span : b.heading.spans) title.append(span.text);
        String text = title.keep(&self.lines.arena);
        int hint = self.lines.visual(b.srcLineStart);
        int line = hint;
        bool found;
        for (int v = max(hint - 5, 0); v < min(hint + 25, total); v++)
        {
            if (self.lines.lines[v].text.contains(text))
            {
                line = v;
                found = true;
                break;
            }
        }
        if (!found) while (line < total && self.lines.lines[line].text.len == 0) line++;
        self.outline.push({ b.heading.level, text, b.srcLineStart, line });
    }
}

fn void View.layout(&self)
{
    self.lines.free();
    self.lines = render::layout(&self.doc, self.config);
    self.index();
}

fn String? load(String path) => (String)io::file::load(mem, path);

fn int changed(String a, String b)
{
    for (int line = 0; ; line++)
    {
        if (a.len == 0 || b.len == 0) return a.len == b.len ? -1 : line;
        if (next(&a) != next(&b)) return line;
    }
}

fn String next(String* s)
{
    sz n = s.index_of_char('\n') ?? s.len;
    String line = (*s)[:n];
    *s = n < s.len ? (*s)[n + 1..] : "";
    return line.ends_with("\r") ? line[:line.len - 1] : line;
}

fn void View.replace(&self, String fresh)
{
    free(self.content);
    self.content = fresh;
    self.doc.free();
    self.doc = parser::parse(fresh);
    self.layout();
}

fn void View.center(&self, int line, int above)
{
    self.top = math::clamp(line - above, 0, self.last());
}

fn int View.source(&self)
{
    if (self.cursor < 0 || self.cursor >= self.total()) return -1;
    return self.lines.lines[self.cursor].srcLine;
}

fn void View.copy(&self)
{
    @pool()
    {
        String encoded = base64::tencode(self.content);
        terminal::out(string::tformat("\e]52;c;%s\e\\", encoded));
    };
    self.say("✔ Copied document to clipboard (OSC 52)");
}

fn void View.find(&self)
{
    self.mode = NORMAL;
    self.matches.clear();
    self.match = 0;
    if (self.queryLen == 0) return;
    String q = (String)self.query[:self.queryLen];
    for (int i = 0; i < self.total(); i++)
    {
        if (self.lines.lines[i].text.contains(q)) self.matches.push(i);
    }
    if (self.matches.len() > 0)
    {
        self.center(self.matches[0], self.rows / 3);
    }
    else
    {
        self.say("No matches found");
    }
}

fn void View.step(&self, int delta)
{
    if (self.matches.len() == 0) return;
    int n = (int)self.matches.len();
    self.match = (self.match + delta + n) % n;
    self.cursor = self.matches[self.match];
    self.center(self.cursor, self.rows / 3);
}

fn void View.goto(&self)
{
    self.mode = NORMAL;
    int line = ((String)self.jump[:self.jumpLen]).to_int() ?? 0;
    self.jumpLen = 0;
    self.jump[0] = 0;
    if (line <= 0) return;
    self.cursor = self.lines.visual(line - 1);
    self.center(self.cursor, self.rows / 3);
    @pool()
    {
        self.say(string::tformat("✔ Jumped to Line %d", line));
    };
}

fn void View.edit(&self)
{
    int src = self.source();
    int line = src >= 0 ? src + 1 : 1;
    terminal::edit(self.name(), line);
    if (try fresh = load(self.name()))
    {
        self.replace(fresh);
        self.cursor = self.lines.visual(line - 1);
        self.center(self.cursor, self.rows / 3);
        self.stamp = terminal::stamp((ZString)&self.path);
    }
    self.say("✔ Resumed from Editor");
}

fn void View.open(&self)
{
    Node* node = self.tree.selected();
    if (node == null) return;
    if (node.dir)
    {
        terminal::chdir(&node.path[0]);
        self.tree.scan(self.name());
        self.tree.cursor = 0;
        return;
    }
    self.mode = NORMAL;
    String? fresh = load(((ZString)&node.path).str_view());
    if (catch fresh) return;
    self.path[..] = 0;
    sz n = min(((ZString)&node.path).str_view().len, (sz)255);
    self.path[:n] = node.path[:n];
    self.replace(fresh);
    self.top = 0;
    self.cursor = 0;
    self.stamp = terminal::stamp((ZString)&self.path);
    @pool()
    {
        self.say(string::tformat("✔ Switched to %s", self.name()));
    };
}

fn void View.files(&self)
{
    self.tree.scan(self.name());
    self.tree.focus();
    self.mode = FILES;
}

fn void View.input(&self, char[] buffer, int* len, int limit, int key, bool digits)
{
    if (key == terminal::BACKSPACE)
    {
        if (*len > 0) buffer[--*len] = 0;
        return;
    }
    bool ok = digits ? key >= '0' && key <= '9' : key >= 32 && key < 127;
    if (!ok || *len >= limit) return;
    buffer[(*len)++] = (char)key;
    buffer[*len] = 0;
}

fn void View.normal(&self, Act act)
{
    int half = max(self.rows / 2, 3);
    int off = self.rows > 6 ? 2 : 0;
    switch (act)
    {
        case DOWN:
            self.cursor = min(self.cursor + self.velocity.next(1, 8, 180), self.last());
            if (self.cursor + off >= self.top + self.rows) self.top = min(self.cursor + off - self.rows + 1, self.last());
        case UP:
            self.cursor = max(self.cursor - self.velocity.next(-1, 8, 180), 0);
            if (self.cursor - off < self.top) self.top = max(self.cursor - off, 0);
        case WHEELUP:
            int step = 3 * self.velocity.next(-3, 6, 120);
            self.top = max(self.top - step, 0);
            self.cursor = math::clamp(max(self.cursor - step, 0), self.top, self.top + self.rows - 1);
        case WHEELDOWN:
            int step = 3 * self.velocity.next(3, 6, 120);
            self.top = min(self.top + step, self.last());
            self.cursor = math::clamp(min(self.cursor + step, self.last()), self.top, self.top + self.rows - 1);
        case LEFT:
            self.left = max(self.left - 4 * self.velocity.next(-2, 6, 180), 0);
        case RIGHT:
            self.left += 4 * self.velocity.next(2, 6, 180);
        case WRAP:
            self.config.noWrap = !self.config.noWrap;
            self.left = 0;
            self.layout();
            self.say(self.config.noWrap ? "No-Wrap Mode (← / → to scroll)" : "Wrap Mode Active");
        case HALFDOWN:
            self.cursor = min(self.cursor + half, self.last());
            self.top = min(self.top + half, self.last());
        case HALFUP:
            self.cursor = max(self.cursor - half, 0);
            self.top = max(self.top - half, 0);
        case TOP:
            self.cursor = 0;
            self.top = 0;
        case BOTTOM:
            self.cursor = self.last();
            self.top = self.last();
        case HELP:
            self.mode = HELP;
        case OUTLINE:
            self.mode = OUTLINE;
            if (self.outline.len() == 0) break;
            self.heading = 0;
            foreach (i, h : self.outline)
            {
                if (h.line > self.cursor) break;
                self.heading = (int)i;
            }
        case FILES:
            self.files();
        case SEARCH:
            self.mode = SEARCH;
            self.queryLen = 0;
            self.query[0] = 0;
        case NEXT:
            self.step(1);
        case PREV:
            self.step(-1);
        case JUMP:
            self.mode = JUMP;
            self.jumpLen = 0;
            self.jump[0] = 0;
        case EDIT:
            self.edit();
        case COPY:
            self.copy();
        case CLEAR:
            self.matches.clear();
            self.match = 0;
            self.queryLen = 0;
            self.query[0] = 0;
            self.status[0] = 0;
        default:
    }
}

fn void View.headings(&self, Act act)
{
    int last = max((int)self.outline.len() - 1, 0);
    int half = max(self.rows / 2, 1);
    switch (act)
    {
        case CLOSE:
            self.mode = NORMAL;
        case DOWN:
            self.heading = min(self.heading + self.velocity.next(1, 8, 180), last);
        case UP:
            self.heading = max(self.heading - self.velocity.next(-1, 8, 180), 0);
        case WHEELDOWN:
            self.heading = min(self.heading + 3 * self.velocity.next(3, 6, 120), last);
        case WHEELUP:
            self.heading = max(self.heading - 3 * self.velocity.next(-3, 6, 120), 0);
        case HALFDOWN:
            self.heading = min(self.heading + half, last);
        case HALFUP:
            self.heading = max(self.heading - half, 0);
        case TOP:
            self.heading = 0;
        case BOTTOM:
            self.heading = last;
        case OPEN:
            if (self.heading < self.outline.len())
            {
                self.cursor = self.outline[self.heading].line;
                self.top = math::clamp(self.cursor, 0, self.last());
            }
            self.mode = NORMAL;
        default:
    }
}

fn void View.browse(&self, Act act)
{
    switch (act)
    {
        case CLOSE:
            self.mode = NORMAL;
        case DOWN:
            if (self.tree.cursor + 1 < self.tree.visible) self.tree.cursor++;
        case UP:
            if (self.tree.cursor > 0) self.tree.cursor--;
        case TOP:
            self.tree.cursor = 0;
        case BOTTOM:
            self.tree.cursor = max(self.tree.visible - 1, 0);
        case ALL:
            self.tree.toggleAll();
        case LEFT:
            self.tree.left();
        case RIGHT:
            self.tree.right();
        case TOGGLE:
            self.tree.toggle();
        case OPEN:
            self.open();
        default:
    }
}

fn bool View.key(&self, int key)
{
    switch (self.mode)
    {
        case SEARCH:
            switch (key)
            {
                case terminal::ESC: self.mode = NORMAL;
                case terminal::ENTER: self.find();
                default: self.input(&self.query, &self.queryLen, 120, key, false);
            }
        case JUMP:
            switch (key)
            {
                case terminal::ESC:
                    self.mode = NORMAL;
                    self.jumpLen = 0;
                    self.jump[0] = 0;
                case terminal::ENTER: self.goto();
                default: self.input(&self.jump, &self.jumpLen, 20, key, true);
            }
        case HELP:
            if (lookup(MODAL, key) == CLOSE) self.mode = NORMAL;
        case FILES:
            self.browse(lookup(BROWSER, key));
        case OUTLINE:
            Act act = lookup(CONTENTS, key);
            self.headings(act != NONE ? act : lookup(MOTION, key));
        case NORMAL:
            Act act = lookup(DOCUMENT, key);
            if (act == QUIT) return true;
            self.normal(act != NONE ? act : lookup(MOTION, key));
    }
    return false;
}

fn void View.badge(&self, DString* fb)
{
    fb.append(ansi::BADGE);
    fb.append(" mdv ");
    fb.append(ansi::RESET);
    fb.append(ansi::PATH);
    fb.append(" ");
    fb.append(self.name());
    fb.append(" ");
    fb.append(ansi::RESET);
    fb.append(ansi::DIVIDER);
    fb.append("│");
    fb.append(ansi::RESET);
    fb.append(" ");
}

fn void View.title(&self, DString* fb, String title)
{
    self.badge(fb);
    fb.append(ansi::TITLE);
    fb.append(title);
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
}

fn void rule(DString* fb, int width)
{
    fb.append(ansi::BORDER);
    fb.repeat("─", max(width - 2, 10));
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
}

fn void tilde(DString* fb, int r, int rows)
{
    fb.append(ansi::TILDE);
    fb.append("~");
    fb.append(ansi::RESET);
    fb.append("\e[K");
    if (r < rows - 1) fb.append_char('\n');
}

fn void View.drawHelp(&self, DString* fb)
{
    self.title(fb, "Keyboard Controls & Keybindings");
    rule(fb, self.width);
    for (int r = 0; r < self.rows; r++)
    {
        if (r >= GUIDE.len)
        {
            tilde(fb, r, self.rows);
            continue;
        }
        fb.append("  ");
        fb.append(GUIDE[r]);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void View.drawOutline(&self, DString* fb)
{
    self.title(fb, "Document Outline (Table of Contents)");
    rule(fb, self.width);
    int off = self.rows > 6 ? 2 : 0;
    int offset = self.heading + off >= self.rows ? self.heading + off - self.rows + 1 : 0;
    offset = math::clamp(offset, 0, max(self.heading, 0));
    for (int r = 0; r < self.rows; r++)
    {
        int i = offset + r;
        if (i >= self.outline.len())
        {
            tilde(fb, r, self.rows);
            continue;
        }
        Heading h = self.outline[i];
        bool active = i == self.heading;
        fb.append(active ? "  " : "    ");
        if (active)
        {
            fb.append(ansi::ACTIVE);
            fb.append("▶ ");
        }
        for (int lv = 1; lv < h.level && lv < 5; lv++) fb.append("   ");
        fb.append(active ? ansi::BOLD : ansi::HEADINGS[min(h.level, 5) - 1]);
        fb.append(h.title);
        fb.append(ansi::RESET);
        fb.append(" ");
        fb.append(ansi::MUTED);
        fb.appendf("(Line %d)", h.src + 1);
        fb.append(ansi::RESET);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void View.drawFiles(&self, DString* fb)
{
    char[256] buf;
    ZString cwd = (ZString)terminal::getcwd(&buf[0], 256);
    self.badge(fb);
    fb.append(ansi::GREEN);
    fb.append(ansi::BOLD);
    fb.append("Tree: ");
    fb.append(ansi::RESET);
    fb.append(ansi::TEXT);
    fb.append(cwd ? cwd.str_view() : ".");
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
    rule(fb, self.width);
    self.tree.draw(fb, self.rows);
}

fn char lower(char c) => c >= 'A' && c <= 'Z' ? c + 32 : c;

fn bool same(String a, String b)
{
    foreach (i, c : a) if (lower(c) != lower(b[i])) return false;
    return true;
}

fn void escape(DString* fb, String line, usz* p)
{
    fb.append_char(line[(*p)++]);
    while (*p < line.len && line[*p] != 'm' && line[*p] != 'K' && line[*p] != 'H') fb.append_char(line[(*p)++]);
    if (*p < line.len) fb.append_char(line[(*p)++]);
}

fn void highlight(DString* fb, String line, String query, bool current)
{
    usz p = 0;
    while (p < line.len)
    {
        if (line[p] == '\e')
        {
            escape(fb, line, &p);
            continue;
        }
        if (p + query.len <= line.len && same(line[p:query.len], query))
        {
            fb.append(current ? "\e[48;2;166;226;46m\e[38;2;0;0;0m\e[1m" : "\e[48;2;253;151;31m\e[38;2;0;0;0m\e[1m");
            fb.append(line[p:query.len]);
            fb.append("\e[0m");
            p += query.len;
            continue;
        }
        fb.append_char(line[p++]);
    }
}

fn void slice(DString* fb, String line, int left, int width)
{
    if (left <= 0)
    {
        fb.append(line);
        return;
    }
    usz p = 0;
    int column;
    int emitted;
    while (p < line.len)
    {
        if (line[p] == '\e')
        {
            escape(fb, line, &p);
            continue;
        }
        char c = line[p];
        usz bytes = (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 1;
        bytes = min(bytes, line.len - p);
        if (column >= left && (width <= 0 || emitted < width))
        {
            fb.append(line[p:bytes]);
            emitted++;
        }
        p += bytes;
        column++;
    }
}

fn void View.drawDocument(&self, DString* fb)
{
    int total = self.total();
    int src = self.source();
    int pct = total > 0 ? (self.cursor + 1) * 100 / total : 0;
    DString head;
    head.init(mem, 256);
    defer head.free();
    self.badge(&head);
    if (self.changed >= 0)
    {
        head.append(ansi::GREEN);
        head.append(ansi::BOLD);
        head.appendf("⚡ Sync L%d", self.changed + 1);
        head.append(ansi::RESET);
        head.append(" ");
        head.append(ansi::DIVIDER);
        head.append("│");
        head.append(ansi::RESET);
        head.append(" ");
    }
    head.append(ansi::GREEN);
    head.append(ansi::BOLD);
    head.appendf("Ln %d", src >= 0 ? src + 1 : 1);
    head.append(ansi::RESET);
    head.append(" ");
    head.append(ansi::MUTED);
    head.appendf("(%d/%d · %d%%)", self.cursor + 1, total, pct);
    head.append(ansi::RESET);
    fb.append(head.str_view());
    String hint = "[? Help │ Tab TOC │ q Quit]";
    int pad = self.width - text::width(head.str_view()) - text::width(hint) - 1;
    if (pad > 0)
    {
        fb.spaces(pad);
        fb.append(ansi::MUTED);
        fb.append(hint);
        fb.append(ansi::RESET);
    }
    fb.append("\e[K\n");
    rule(fb, self.width);
    String query = (String)self.query[:self.queryLen];
    int current = self.matches.len() > 0 && self.match < self.matches.len() ? self.matches[self.match] : -1;
    for (int i = self.top; i < self.top + self.rows; i++)
    {
        if (i < total)
        {
            if (i == self.cursor)
            {
                fb.append(ansi::CURSOR);
                fb.append("▌");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append_char(' ');
            }
            if (query.len > 0 && (self.mode == SEARCH || self.matches.len() > 0))
            {
                highlight(fb, self.lines.lines[i].text, query, i == current);
            }
            else
            {
                slice(fb, self.lines.lines[i].text, self.left, self.width - 1);
            }
            fb.append("\e[K");
        }
        else
        {
            fb.append(" ");
            fb.append(ansi::TILDE);
            fb.append("~");
            fb.append(ansi::RESET);
            fb.append("\e[K");
        }
        if (i < self.top + self.rows - 1) fb.append_char('\n');
    }
    self.drawStatus(fb);
}

fn void View.drawStatus(&self, DString* fb)
{
    String label;
    String text;
    String help;
    switch
    {
        case self.mode == JUMP:
            label = " : ";
            text = (String)self.jump[:self.jumpLen];
            help = " (Enter: Goto line, Esc: Cancel)";
        case self.mode == SEARCH:
            label = " / ";
            text = (String)self.query[:self.queryLen];
            help = " (Enter: Search, Esc: Cancel)";
        case self.matches.len() > 0:
            fb.append(ansi::STATUS);
            fb.appendf(" Match %d of %d ", self.match + 1, self.matches.len());
            fb.append(ansi::RESET);
            fb.append(ansi::MUTED);
            fb.append(" (n: Next, N: Prev, Esc: Clear)");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        case self.status[0] != 0:
            fb.append(ansi::STATUS);
            fb.append(" ");
            fb.append(((ZString)&self.status).str_view());
            fb.append(" ");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        default:
            return;
    }
    fb.append(ansi::STATUS);
    fb.append(label);
    fb.append(ansi::RESET);
    fb.append(ansi::PATH);
    fb.append(" ");
    fb.append(text);
    fb.append(" ");
    fb.append(ansi::RESET);
    fb.append(ansi::MUTED);
    fb.append(help);
    fb.append(ansi::RESET);
    fb.append("\e[K");
}

fn void View.draw(&self)
{
    DString* fb = &self.frame;
    fb.clear();
    fb.append("\e[?7l\e[H");
    switch (self.mode)
    {
        case HELP: self.drawHelp(fb);
        case OUTLINE: self.drawOutline(fb);
        case FILES: self.drawFiles(fb);
        default: self.drawDocument(fb);
    }
    terminal::out(fb.str_view());
}

fn void View.resize(&self)
{
    int width = terminal::width();
    int height = terminal::height();
    if (width == self.width && height == self.height) return;
    self.width = width;
    self.height = height;
    self.rows = max(height - 2, 2);
    self.config.width = width;
    self.layout();
    self.top = min(self.top, self.last());
    self.draw();
}

fn void View.watch(&self)
{
    terminal::Stamp now = terminal::stamp((ZString)&self.path);
    if (now.inode == 0 || now.same(self.stamp)) return;
    self.stamp = now;
    String? fresh = load(self.name());
    if (catch fresh) return;
    int diff = changed(self.content, fresh);
    if (diff >= 0) self.changed = diff;
    self.config.width = self.width;
    self.replace(fresh);
    if (diff >= 0) self.center(self.lines.visual(diff), max(self.rows / 3, 5));
    self.draw();
}

fn void View.free(&self)
{
    free(self.content);
    self.doc.free();
    self.lines.free();
    self.outline.free();
    self.matches.free();
    self.frame.free();
}

fn bool run(String file, int line, bool noWrap, bool picker)
{
    View view;
    view.path[:min(file.len, 255)] = file[:min(file.len, 255)];
    String? content = load(file);
    if (catch content) return false;
    view.width = terminal::width();
    view.height = terminal::height();
    view.rows = max(view.height - 2, 2);
    view.config = { .width = view.width, .noWrap = noWrap };
    view.changed = line > 0 ? line - 1 : -1;
    view.frame.init(mem, 262144);
    view.outline.init(mem, 32);
    view.matches.init(mem, 32);
    view.replace(content);
    defer view.free();
    if (line > 0)
    {
        view.cursor = view.lines.visual(line - 1);
        view.center(view.cursor, max(view.rows / 3, 5));
    }
    terminal::rawMode();
    terminal::enter();
    defer
    {
        terminal::leave();
        terminal::cooked();
    }
    if (picker) view.files();
    view.draw();
    view.stamp = terminal::stamp((ZString)&view.path);
    while (true)
    {
        bool dirty;
        if (view.ticks > 0 && --view.ticks == 0)
        {
            view.status[0] = 0;
            dirty = true;
        }
        for (int key = terminal::key(); key != 0; key = terminal::key())
        {
            if (view.key(key)) return true;
            dirty = true;
        }
        if (dirty) view.draw();
        view.resize();
        view.watch();
        terminal::wait(30);
    }
}
