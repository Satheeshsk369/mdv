module app;

import std::math;
import ansi;
import terminal;
import text;

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
    String query = self.query.str_view();
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
                text::mark(fb, self.lines.lines[i].text, query, i == current);
            }
            else
            {
                text::cut(fb, self.lines.lines[i].text, self.left, self.width - 1);
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
