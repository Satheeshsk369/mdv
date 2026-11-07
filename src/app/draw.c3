module app;

import std::math;
import ast;
import ansi;
import terminal;
import text;

struct Guide
{
    Role role;
    String key;
    String text;
}

const Guide[] GUIDE = {
    { CURSOR, "Vertical Navigation:", "" },
    { YELLOW, "  ↓ / ↑", "                 Scroll down / up (accelerated)" },
    { YELLOW, "  PgDn / PgUp", "           Half-page scroll down / up" },
    { YELLOW, "  Home / End", "            Jump to Top / Bottom" },
    { YELLOW, "  : <line>", "              Goto line number (e.g. :42)" },
    { NONE, "", "" },
    { CURSOR, "Horizontal & Layout:", "" },
    { YELLOW, "  w", "                     Toggle Wrap / No-Wrap mode" },
    { YELLOW, "  ← / →", "                 Horizontal scroll (accelerated)" },
    { NONE, "", "" },
    { CURSOR, "Features & Actions:", "" },
    { GREEN, "  Space", "                 Options menu" },
    { GREEN, "  Tab / t", "               Toggle Document Outline (Table of Contents)" },
    { GREEN, "  h", "                     Highlight the current block" },
    { GREEN, "  c", "                     Colour theme with live preview" },
    { GREEN, "  o", "                     Switch Document (Markdown File Tree)" },
    { GREEN, "  /", "                     In-document search (n next, N prev)" },
    { GREEN, "  e", "                     Edit with live preview (Ctrl+O lists editor commands)" },
    { GREEN, "  E", "                     Open $EDITOR at current line" },
    { GREEN, "  y", "                     Copy document to clipboard (OSC 52)" },
    { GREEN, "  ?", "                     Show / hide this help screen" },
};

fn int follow(int top, int cursor, int count, int rows)
{
    int off = rows > 6 ? 2 : 0;
    if (cursor - off < top) top = cursor - off;
    if (cursor + off >= top + rows) top = cursor + off - rows + 1;
    return math::clamp(top, 0, max(count - rows, 0));
}

fn void View.badge(&self, DString* fb)
{
    fb.append(ansi::style(BADGE));
    fb.append(" mdv ");
    fb.append(ansi::RESET);
    fb.append(ansi::style(PATH));
    fb.append(" ");
    fb.append(self.name());
    fb.append(" ");
    fb.append(ansi::RESET);
    fb.append(ansi::style(BORDER));
    fb.append("│");
    fb.append(ansi::RESET);
    fb.append(" ");
}

fn void View.title(&self, DString* fb, String title)
{
    self.badge(fb);
    fb.append(ansi::style(TITLE));
    fb.append(title);
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
}

fn void rule(DString* fb, int width)
{
    fb.append(ansi::style(BORDER));
    fb.repeat("─", max(width - 2, 10));
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
}

fn void tilde(DString* fb, int r, int rows)
{
    fb.append(ansi::style(FAINT));
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
        Guide g = GUIDE[r];
        fb.append("  ");
        if (g.key.len > 0)
        {
            int indent;
            while (indent < g.key.len && g.key[indent] == ' ') indent++;
            fb.append(g.key[:indent]);
            fb.append(ansi::style(g.role));
            fb.append(g.key[indent..]);
            fb.append(ansi::RESET);
        }
        fb.append(g.text);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void View.drawOutline(&self, DString* fb)
{
    self.title(fb, "Document Outline (Table of Contents)");
    rule(fb, self.width);
    self.headingTop = follow(self.headingTop, self.heading, (int)self.outline.len(), self.rows);
    int offset = self.headingTop;
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
            fb.append(ansi::style(ACTIVE));
            fb.append("▶ ");
        }
        for (int lv = 1; lv < h.level && lv < 5; lv++) fb.append("   ");
        fb.append(active ? ansi::BOLD : ansi::heading(min(h.level, 5)));
        fb.append(h.title);
        fb.append(ansi::RESET);
        fb.append(" ");
        fb.append(ansi::style(MUTED));
        fb.appendf("(Line %d)", h.src + 1);
        fb.append(ansi::RESET);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void View.drawMenu(&self, DString* fb)
{
    self.title(fb, self.back == EDITOR ? "Editor Options" : "Options");
    rule(fb, self.width);
    Item[] items = self.items;
    self.choiceTop = follow(self.choiceTop, self.choice, (int)items.len, self.rows);
    for (int r = 0; r < self.rows; r++)
    {
        int i = self.choiceTop + r;
        if (i >= items.len)
        {
            tilde(fb, r, self.rows);
            continue;
        }
        bool active = i == self.choice;
        fb.append(active ? "  " : "    ");
        if (active)
        {
            fb.append(ansi::style(ACTIVE));
            fb.append("▶ ");
        }
        fb.append(active ? ansi::BOLD : ansi::style(TEXT));
        fb.append(items[i].label);
        fb.append(ansi::RESET);
        fb.spaces(max(20 - (int)items[i].label.len, 1));
        fb.append(ansi::style(MUTED));
        fb.append(items[i].key);
        fb.append(ansi::RESET);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void tint(DString* fb, String line)
{
    fb.append(ansi::style(FOCUS));
    while (line.len > 0)
    {
        sz at = line.index_of(ansi::RESET) ?? line.len;
        fb.append(line[:at]);
        if (at == line.len) break;
        fb.append(ansi::RESET);
        fb.append(ansi::style(FOCUS));
        line = line[at + ansi::RESET.len..];
    }
}

struct Row
{
    String text;
    usz base;
    int number;
    bool current;
    bool lit;
    bool first;
    bool heading;
}

struct Marks
{
    usz low;
    usz high;
    usz[] hits;
    usz size;
}

fn void source(DString* fb, Row row, Marks marks, int left, int width)
{
    if (row.lit) fb.append(ansi::style(FOCUS));
    fb.append(row.current ? ansi::style(CURSOR) : ansi::style(MUTED));
    if (row.first)
    {
        fb.appendf("%4d ", row.number);
    }
    else
    {
        fb.append("   ↪ ");
    }
    fb.append(ansi::RESET);
    if (row.lit) fb.append(ansi::style(FOCUS));
    String t = row.text.trim();
    bool fence = t.starts_with("```") || t.starts_with("~~~") || t.starts_with("$$");
    String color = row.heading ? ansi::style(H2) : fence ? ansi::style(MUTED) : ansi::style(TEXT);
    fb.append(color);
    DString expanded;
    expanded.init(mem, row.text.len + 64);
    defer expanded.free();
    String state = "";
    usz k;
    foreach (i, c : row.text)
    {
        usz at = row.base + (usz)i;
        while (k < marks.hits.len && marks.hits[k] + marks.size <= at) k++;
        bool hit = k < marks.hits.len && marks.hits[k] <= at;
        String want = at >= marks.low && at < marks.high ? ansi::style(SELECTION) : hit ? ansi::style(MATCH) : "";
        if (want != state)
        {
            expanded.append(want.len > 0 ? want : ansi::RESET);
            if (want.len == 0 && row.lit) expanded.append(ansi::style(FOCUS));
            if (want.len == 0) expanded.append(color);
            state = want;
        }
        if (c == '\t')
        {
            expanded.spaces(4);
        }
        else
        {
            expanded.append_char(c);
        }
    }
    usz end = row.base + row.text.len;
    bool continues = end >= marks.low && end < marks.high;
    if (continues && state != ansi::style(SELECTION)) expanded.append(ansi::style(SELECTION));
    if (!continues && state.len > 0)
    {
        expanded.append(ansi::RESET);
        if (row.lit) expanded.append(ansi::style(FOCUS));
    }
    fb.spaces(width - text::clip(fb, expanded.str_view(), left, width));
    fb.append(ansi::RESET);
}

fn void preview(DString* fb, String line, bool lit, int width)
{
    DString tinted;
    tinted.init(mem, line.len + 64);
    defer tinted.free();
    if (lit)
    {
        tint(&tinted, line);
    }
    else
    {
        tinted.append(line);
    }
    fb.append(lit ? ansi::style(FOCUS) : "");
    fb.append_char(' ');
    fb.spaces(width - 1 - text::clip(fb, tinted.str_view(), 0, width - 1));
    fb.append(ansi::RESET);
}

fn void View.drawEditor(&self, DString* fb)
{
    Editor* e = &self.editor;
    if (e.fresh) e.refresh(self.previewWidth());
    int line = e.line(e.at);
    DString head;
    head.init(mem, 256);
    defer head.free();
    self.badge(&head);
    head.append(ansi::style(TITLE));
    head.append("Editing");
    head.append(ansi::RESET);
    if (e.dirty())
    {
        head.append(ansi::style(ORANGE));
        head.append(" ●");
        head.append(ansi::RESET);
    }
    head.append(ansi::style(MUTED));
    head.appendf("  Ln %d, Col %d", line + 1, e.column() + 1);
    head.append(ansi::RESET);
    fb.append(head.str_view());
    DString hint;
    hint.init(mem, 128);
    defer hint.free();
    if (e.prompt != NONE)
    {
        hint.append(LABELS[e.prompt]);
        hint.append(e.input.str_view());
        hint.append("▏ (Enter │ Esc)");
    }
    else if (self.status.len() > 0)
    {
        hint.append(self.status.str_view());
    }
    else if (self.focus && e.page.count() > 0)
    {
        Block* b = &e.doc.blocks[e.page.lines[e.page.find(line)].block];
        hint.appendf("Block L%d–%d (Ctrl+H)", b.start + 1, b.end + 1);
    }
    else
    {
        hint.append("[Ctrl+O Options]");
    }
    int pad = self.width - text::width(head.str_view()) - text::width(hint.str_view()) - 1;
    if (pad > 0)
    {
        fb.spaces(pad);
        fb.append(e.prompt != NONE || self.status.len() > 0 || self.focus ? ansi::style(STATUS) : ansi::style(MUTED));
        fb.append(hint.str_view());
        fb.append(ansi::RESET);
    }
    fb.append("\e[K\n");
    rule(fb, self.width);
    bool split = self.split();
    bool stacked = e.preview && !split;
    int body = self.rows;
    int editRows = self.paneRows();
    int editWidth = self.editWidth();
    int textWidth = max(editWidth - 5, 1);
    int previewWidth = split ? self.width - editWidth - 1 : self.width;
    int previewRows = split ? body : body - editRows - 1;
    e.width = textWidth;
    e.scroll(editRows);
    Spot spot = e.spot();
    if (!e.wrap)
    {
        if (spot.column < e.left) e.left = spot.column;
        if (spot.column >= e.left + textWidth) e.left = spot.column - textWidth + 1;
    }
    int anchor = e.page.find(line);
    int block = e.page.count() > 0 ? e.page.lines[anchor].block : -1;
    int first = -1;
    int last = -1;
    if (self.focus && block >= 0 && block < e.doc.blocks.len)
    {
        first = e.doc.blocks[block].start;
        last = e.doc.blocks[block].end;
    }
    e.view = math::clamp(anchor - previewRows / 3, 0, max(e.page.count() - previewRows, 0));
    int number = e.top;
    int row = e.skip;
    int count = e.count();
    String current = number < count ? e.slice(number) : "";
    usz origin = e.offset(number);
    int rows = number < count ? e.height(number) : 1;
    String needle = e.needle.str_view();
    e.hits.clear();
    String all = e.str();
    for (usz p = 0; needle.len > 0 && p + needle.len <= all.len; p++)
    {
        if (!text::same(all[p : needle.len], needle)) continue;
        e.hits.push(p);
        p += needle.len - 1;
    }
    Marks marks = { e.selected() ? e.low() : 0, e.selected() ? e.high() : 0, e.hits.array_view(), needle.len };
    for (int r = 0; r < body; r++)
    {
        if (split || r < editRows)
        {
            if (number < count)
            {
                fold(current, e.span(), &e.starts);
                usz from = e.starts[row];
                usz to = row + 1 < rows ? e.starts[(usz)row + 1] : current.len;
                bool lit = number >= first && number <= last;
                int left = number == line && !e.wrap ? e.left : 0;
                Row segment = { current[from : to - from], origin + from, number + 1, number == line, lit, row == 0, current.starts_with("#") };
                source(fb, segment, marks, left, textWidth);
                row++;
                if (row >= rows)
                {
                    number++;
                    row = 0;
                    current = number < count ? e.slice(number) : "";
                    origin = e.offset(number);
                    rows = number < count ? e.height(number) : 1;
                }
            }
            else
            {
                fb.append(ansi::style(FAINT));
                fb.append("   ~");
                fb.append(ansi::RESET);
                fb.spaces(editWidth - 4);
            }
        }
        if (split)
        {
            fb.append(ansi::style(BORDER));
            fb.append("│");
            fb.append(ansi::RESET);
        }
        if (stacked && r == editRows)
        {
            fb.append(ansi::style(BORDER));
            fb.repeat("─", self.width);
            fb.append(ansi::RESET);
        }
        int p = e.view + (split ? r : r - editRows - 1);
        if ((split || (stacked && r > editRows)) && p < e.page.count()) preview(fb, e.page.lines[p].text, self.focus && e.page.lines[p].block == block, previewWidth);
        fb.append("\e[K");
        if (r < body - 1) fb.append_char('\n');
    }
    int distance = spot.row - e.skip;
    for (int l = e.top; l < spot.line; l++) distance += e.height(l);
    fb.appendf("\e[%d;%dH\e[?25h", 3 + distance, 6 + spot.column - (e.wrap ? 0 : e.left));
}

fn void View.drawFiles(&self, DString* fb)
{
    char[256] buf;
    ZString cwd = (ZString)terminal::getcwd(&buf[0], 256);
    self.badge(fb);
    fb.append(ansi::style(GREEN));
    fb.append(ansi::BOLD);
    fb.append("Tree: ");
    fb.append(ansi::RESET);
    fb.append(ansi::style(TEXT));
    fb.append(cwd ? cwd.str_view() : ".");
    fb.append(ansi::RESET);
    fb.append("\e[K\n");
    rule(fb, self.width);
    self.tree.draw(fb, self.rows);
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
        head.append(ansi::style(GREEN));
        head.append(ansi::BOLD);
        head.appendf("⚡ Sync L%d", self.changed + 1);
        head.append(ansi::RESET);
        head.append(" ");
        head.append(ansi::style(BORDER));
        head.append("│");
        head.append(ansi::RESET);
        head.append(" ");
    }
    head.append(ansi::style(GREEN));
    head.append(ansi::BOLD);
    head.appendf("Ln %d", src >= 0 ? src + 1 : 1);
    head.append(ansi::RESET);
    head.append(" ");
    head.append(ansi::style(MUTED));
    head.appendf("(%d/%d · %d%%)", self.cursor + 1, total, pct);
    head.append(ansi::RESET);
    fb.append(head.str_view());
    String hint = "[Space Options]";
    int pad = self.width - text::width(head.str_view()) - text::width(hint) - 1;
    if (pad > 0)
    {
        fb.spaces(pad);
        fb.append(ansi::style(MUTED));
        fb.append(hint);
        fb.append(ansi::RESET);
    }
    fb.append("\e[K\n");
    rule(fb, self.width);
    String query = self.query.str_view();
    int current = self.matches.len() > 0 && self.match < self.matches.len() ? self.matches[self.match] : -1;
    int block = self.focus && total > 0 ? self.lines.lines[self.cursor].block : -1;
    DString line;
    line.init(mem, 1024);
    defer line.free();
    for (int i = self.top; i < self.top + self.rows; i++)
    {
        if (i < total)
        {
            bool lit = self.lines.lines[i].block == block;
            line.clear();
            if (lit) fb.append(ansi::style(FOCUS));
            if (i == self.cursor)
            {
                fb.append(ansi::style(CURSOR));
                fb.append("▌");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append_char(' ');
            }
            if (query.len > 0 && (self.mode == SEARCH || self.matches.len() > 0))
            {
                text::mark(&line, self.lines.lines[i].text, query, ansi::style(i == current ? CURRENT : FOUND));
            }
            else
            {
                text::cut(&line, self.lines.lines[i].text, self.left, self.width - 1);
            }
            if (lit)
            {
                tint(fb, line.str_view());
                fb.append("\e[K");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append(line.str_view());
                fb.append("\e[K");
            }
        }
        else
        {
            fb.append(" ");
            fb.append(ansi::style(FAINT));
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
            text = self.jump.str_view();
            help = " (Enter: Goto line, Esc: Cancel)";
        case self.mode == SEARCH:
            label = " / ";
            text = self.query.str_view();
            help = " (Enter: Search, Esc: Cancel)";
        case self.matches.len() > 0:
            fb.append(ansi::style(STATUS));
            fb.appendf(" Match %d of %d ", self.match + 1, self.matches.len());
            fb.append(ansi::RESET);
            fb.append(ansi::style(MUTED));
            fb.append(" (n: Next, N: Prev, Esc: Clear)");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        case self.status.len() > 0:
            fb.append(ansi::style(STATUS));
            fb.append(" ");
            fb.append(self.status.str_view());
            fb.append(" ");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        case self.focus && self.total() > 0:
            Block* b = &self.doc.blocks[self.lines.lines[self.cursor].block];
            fb.append(ansi::style(STATUS));
            fb.appendf(" Block L%d–%d ", b.start + 1, b.end + 1);
            fb.append(ansi::RESET);
            fb.append(ansi::style(MUTED));
            fb.append(" (h: Unhighlight, Esc: Clear)");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        default:
            return;
    }
    fb.append(ansi::style(STATUS));
    fb.append(label);
    fb.append(ansi::RESET);
    fb.append(ansi::style(PATH));
    fb.append(" ");
    fb.append(text);
    fb.append(" ");
    fb.append(ansi::RESET);
    fb.append(ansi::style(MUTED));
    fb.append(help);
    fb.append(ansi::RESET);
    fb.append("\e[K");
}

fn void View.draw(&self)
{
    DString* fb = &self.frame;
    fb.clear();
    fb.append("\e[?7l\e[?25l\e[H");
    switch (self.mode)
    {
        case HELP: self.drawHelp(fb);
        case OUTLINE: self.drawOutline(fb);
        case FILES: self.drawFiles(fb);
        case MENU: self.drawMenu(fb);
        case THEME: self.drawThemes(fb);
        case EDITOR: self.drawEditor(fb);
        default: self.drawDocument(fb);
    }
    terminal::out(fb.str_view());
}

fn void Tree.draw(&self, DString* fb, int rows)
{
    self.top = follow(self.top, self.cursor, self.visible, rows);
    int offset = self.top;
    for (int r = 0; r < rows; r++)
    {
        int v = offset + r;
        if (v >= self.visible)
        {
            tilde(fb, r, rows);
            continue;
        }
        Node* node = &self.nodes[self.shown[v]];
        bool active = v == self.cursor;
        String name = node.name;
        fb.append(active ? "  " : "    ");
        if (active)
        {
            fb.append(ansi::style(ACTIVE));
            fb.append("▶ ");
        }
        if (name == "..")
        {
            if (active)
            {
                fb.append(ansi::style(ACTIVE));
                fb.append(ansi::style(ORANGE));
                fb.append(ansi::BOLD);
                fb.append("📁 ../ (Parent Directory)");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append(ansi::style(ORANGE));
                fb.append(ansi::BOLD);
                fb.append("📁 ../ ");
                fb.append(ansi::RESET);
                fb.append(ansi::style(MUTED));
                fb.append("(Parent Directory)");
                fb.append(ansi::RESET);
            }
        }
        else
        {
            for (int d = 0; d < node.depth && d < 6; d++)
            {
                fb.append(ansi::style(MUTED));
                fb.append("│   ");
                fb.append(ansi::RESET);
            }
            if (node.dir)
            {
                fb.append(ansi::style(ORANGE));
                fb.append(ansi::BOLD);
                fb.append(node.open ? "▾ " : "▸ ");
                fb.append(ansi::RESET);
                if (active) fb.append(ansi::style(SELECTED));
                fb.append(ansi::style(CYAN));
                fb.append(ansi::BOLD);
                fb.append(name);
                fb.append("/");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append(ansi::style(MUTED));
                fb.append(node.last ? "└── " : "├── ");
                fb.append(ansi::RESET);
                if (active)
                {
                    fb.append(ansi::style(SELECTED));
                    fb.append(ansi::BOLD);
                }
                else
                {
                    fb.append(ansi::style(TEXT));
                }
                fb.append(name);
                fb.append(ansi::RESET);
                if (node.current)
                {
                    fb.append(" ");
                    fb.append(ansi::style(GREEN));
                    fb.append("[Active]");
                    fb.append(ansi::RESET);
                }
            }
        }
        fb.append("\e[K");
        if (r < rows - 1) fb.append_char('\n');
    }
}
