module app;

import std::math;
import ast;
import ansi;
import terminal;
import text;

const String[] GUIDE = {
    "\e[38;2;102;217;239m\e[1mVertical Navigation:\e[0m",
    "  \e[38;2;230;219;116m↓ / ↑\e[0m                 Scroll down / up (accelerated)",
    "  \e[38;2;230;219;116mPgDn / PgUp\e[0m           Half-page scroll down / up",
    "  \e[38;2;230;219;116mHome / End\e[0m            Jump to Top / Bottom",
    "  \e[38;2;230;219;116m: <line>\e[0m              Goto line number (e.g. :42)",
    "",
    "\e[38;2;102;217;239m\e[1mHorizontal & Layout:\e[0m",
    "  \e[38;2;230;219;116mw\e[0m                     Toggle Wrap / No-Wrap mode",
    "  \e[38;2;230;219;116m← / →\e[0m                 Horizontal scroll (accelerated)",
    "",
    "\e[38;2;102;217;239m\e[1mFeatures & Actions:\e[0m",
    "  \e[38;2;166;226;46mSpace\e[0m                 Options menu",
    "  \e[38;2;166;226;46mTab / t\e[0m               Toggle Document Outline (Table of Contents)",
    "  \e[38;2;166;226;46mh\e[0m                     Highlight the current block",
    "  \e[38;2;166;226;46mo\e[0m                     Switch Document (Markdown File Tree)",
    "  \e[38;2;166;226;46m/\e[0m                     In-document search (n next, N prev)",
    "  \e[38;2;166;226;46me\e[0m                     Edit with live preview (Ctrl+O lists editor commands)",
    "  \e[38;2;166;226;46mE\e[0m                     Open $EDITOR at current line",
    "  \e[38;2;166;226;46my\e[0m                     Copy document to clipboard (OSC 52)",
    "  \e[38;2;166;226;46m?\e[0m                     Show / hide this help screen",
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
            fb.append(ansi::ACTIVE);
            fb.append("▶ ");
        }
        fb.append(active ? ansi::BOLD : ansi::TEXT);
        fb.append(items[i].label);
        fb.append(ansi::RESET);
        fb.spaces(max(20 - (int)items[i].label.len, 1));
        fb.append(ansi::MUTED);
        fb.append(items[i].key);
        fb.append(ansi::RESET);
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}

fn void tint(DString* fb, String line)
{
    fb.append(ansi::FOCUS);
    while (line.len > 0)
    {
        sz at = line.index_of(ansi::RESET) ?? line.len;
        fb.append(line[:at]);
        if (at == line.len) break;
        fb.append(ansi::RESET);
        fb.append(ansi::FOCUS);
        line = line[at + ansi::RESET.len..];
    }
}

struct Row
{
    String text;
    usz base;
    int number;
    bool current;
    bool first;
    bool heading;
}

fn void source(DString* fb, Row row, usz low, usz high, int left, int width)
{
    if (row.current) fb.append(ansi::FOCUS);
    fb.append(row.current ? ansi::CURSOR : ansi::MUTED);
    if (row.first)
    {
        fb.appendf("%4d ", row.number);
    }
    else
    {
        fb.append("   ↪ ");
    }
    fb.append(ansi::RESET);
    if (row.current) fb.append(ansi::FOCUS);
    String t = row.text.trim();
    bool fence = t.starts_with("```") || t.starts_with("~~~") || t.starts_with("$$");
    String color = row.heading ? ansi::H2 : fence ? ansi::MUTED : ansi::TEXT;
    fb.append(color);
    DString expanded;
    expanded.init(mem, row.text.len + 64);
    defer expanded.free();
    bool inside;
    foreach (i, c : row.text)
    {
        usz at = row.base + (usz)i;
        bool want = at >= low && at < high;
        if (want != inside)
        {
            expanded.append(want ? ansi::SELECTION : ansi::RESET);
            if (!want && row.current) expanded.append(ansi::FOCUS);
            if (!want) expanded.append(color);
            inside = want;
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
    if (!inside && row.base + row.text.len >= low && row.base + row.text.len < high) expanded.append(ansi::SELECTION);
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
    fb.append(lit ? ansi::FOCUS : "");
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
    head.append(ansi::TITLE);
    head.append("Editing");
    head.append(ansi::RESET);
    if (e.dirty())
    {
        head.append(ansi::ORANGE);
        head.append(" ●");
        head.append(ansi::RESET);
    }
    head.append(ansi::MUTED);
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
    else
    {
        hint.append("[Ctrl+O Options]");
    }
    int pad = self.width - text::width(head.str_view()) - text::width(hint.str_view()) - 1;
    if (pad > 0)
    {
        fb.spaces(pad);
        fb.append(e.prompt != NONE || self.status.len() > 0 ? ansi::STATUS : ansi::MUTED);
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
    usz low = e.selected() ? e.low() : 0;
    usz high = e.selected() ? e.high() : 0;
    for (int r = 0; r < body; r++)
    {
        if (split || r < editRows)
        {
            if (number < count)
            {
                fold(current, e.span(), &e.starts);
                usz from = e.starts[row];
                usz to = row + 1 < rows ? e.starts[(usz)row + 1] : current.len;
                bool lit = number == line || (number >= first && number <= last);
                int left = number == line && !e.wrap ? e.left : 0;
                Row segment = { current[from : to - from], origin + from, number + 1, lit, row == 0, current.starts_with("#") };
                source(fb, segment, low, high, left, textWidth);
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
                fb.append(ansi::TILDE);
                fb.append("   ~");
                fb.append(ansi::RESET);
                fb.spaces(editWidth - 4);
            }
        }
        if (split)
        {
            fb.append(ansi::BORDER);
            fb.append("│");
            fb.append(ansi::RESET);
        }
        if (stacked && r == editRows)
        {
            fb.append(ansi::BORDER);
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
    String hint = "[Space Options]";
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
            if (lit) fb.append(ansi::FOCUS);
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
                text::mark(&line, self.lines.lines[i].text, query, i == current);
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
            text = self.jump.str_view();
            help = " (Enter: Goto line, Esc: Cancel)";
        case self.mode == SEARCH:
            label = " / ";
            text = self.query.str_view();
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
        case self.status.len() > 0:
            fb.append(ansi::STATUS);
            fb.append(" ");
            fb.append(self.status.str_view());
            fb.append(" ");
            fb.append(ansi::RESET);
            fb.append("\e[K");
            return;
        case self.focus && self.total() > 0:
            Block* b = &self.doc.blocks[self.lines.lines[self.cursor].block];
            fb.append(ansi::STATUS);
            fb.appendf(" Block L%d–%d ", b.start + 1, b.end + 1);
            fb.append(ansi::RESET);
            fb.append(ansi::MUTED);
            fb.append(" (h: Unhighlight, Esc: Clear)");
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
    fb.append("\e[?7l\e[?25l\e[H");
    switch (self.mode)
    {
        case HELP: self.drawHelp(fb);
        case OUTLINE: self.drawOutline(fb);
        case FILES: self.drawFiles(fb);
        case MENU: self.drawMenu(fb);
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
            fb.append(ansi::ACTIVE);
            fb.append("▶ ");
        }
        if (name == "..")
        {
            if (active)
            {
                fb.append(ansi::ACTIVE);
                fb.append(ansi::ORANGE);
                fb.append(ansi::BOLD);
                fb.append("📁 ../ (Parent Directory)");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append(ansi::ORANGE);
                fb.append(ansi::BOLD);
                fb.append("📁 ../ ");
                fb.append(ansi::RESET);
                fb.append(ansi::MUTED);
                fb.append("(Parent Directory)");
                fb.append(ansi::RESET);
            }
        }
        else
        {
            for (int d = 0; d < node.depth && d < 6; d++)
            {
                fb.append(ansi::MUTED);
                fb.append("│   ");
                fb.append(ansi::RESET);
            }
            if (node.dir)
            {
                fb.append(ansi::ORANGE);
                fb.append(ansi::BOLD);
                fb.append(node.open ? "▾ " : "▸ ");
                fb.append(ansi::RESET);
                if (active) fb.append(ansi::SELECTED);
                fb.append(ansi::CYAN);
                fb.append(ansi::BOLD);
                fb.append(name);
                fb.append("/");
                fb.append(ansi::RESET);
            }
            else
            {
                fb.append(ansi::MUTED);
                fb.append(node.last ? "└── " : "├── ");
                fb.append(ansi::RESET);
                if (active)
                {
                    fb.append(ansi::SELECTED);
                    fb.append(ansi::BOLD);
                }
                else
                {
                    fb.append(ansi::TEXT);
                }
                fb.append(name);
                fb.append(ansi::RESET);
                if (node.current)
                {
                    fb.append(" ");
                    fb.append(ansi::GREEN);
                    fb.append("[Active]");
                    fb.append(ansi::RESET);
                }
            }
        }
        fb.append("\e[K");
        if (r < rows - 1) fb.append_char('\n');
    }
}
