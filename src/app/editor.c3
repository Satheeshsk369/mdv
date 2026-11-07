module app;

import std::io;
import std::math;
import std::core::mem;
import std::collections::list;
import ast;
import parser;
import render;
import terminal;
import text;

struct Snapshot
{
    String text;
    usz at;
}

struct Spot
{
    int line;
    int row;
    int column;
}

enum Prompt
{
    NONE,
    FIND,
    LINE
}

struct Editor
{
    DString text;
    usz at;
    int top;
    int skip;
    int width;
    int left;
    int goal;
    int view;
    bool dirty;
    bool warned;
    bool fresh;
    bool wrap;
    bool preview;
    bool pasting;
    Prompt prompt;
    ulong edited;
    DString input;
    DString needle;
    DString clip;
    List{Snapshot} history;
    List{Snapshot} future;
    List{usz} starts;
    Document doc;
    render::Page page;
}

fn int columns(String s)
{
    int tabs;
    foreach (c : s) if (c == '\t') tabs++;
    return text::width(s) + 4 * tabs;
}

fn void fold(String line, int width, List{usz}* starts)
{
    starts.clear();
    starts.push(0);
    usz row;
    usz space;
    int column;
    usz i;
    while (i < line.len)
    {
        usz next = i + 1;
        while (next < line.len && (line[next] & 0xC0) == 0x80) next++;
        int w = line[i] == '\t' ? 4 : text::width(line[i : next - i]);
        if (column + w > width && i > row)
        {
            row = space > row ? space : i;
            starts.push(row);
            space = 0;
            column = columns(line[row : i - row]);
            continue;
        }
        column += w;
        if (line[i] == ' ') space = next;
        i = next;
    }
}

fn String Editor.str(&self) => self.text.str_view();

fn String Editor.slice(&self, int line)
{
    usz from = self.offset(line);
    return self.str()[from : self.end(from) - from];
}

fn int Editor.span(&self) => self.wrap ? self.width : 1 << 28;

fn int Editor.height(&self, int line)
{
    fold(self.slice(line), self.span(), &self.starts);
    return (int)self.starts.len();
}

fn Spot Editor.spot(&self)
{
    int line = self.line(self.at);
    usz from = self.start(self.at);
    fold(self.str()[from : self.end(from) - from], self.span(), &self.starts);
    usz offset = self.at - from;
    int row;
    while (row + 1 < (int)self.starts.len() && self.starts[(usz)row + 1] <= offset) row++;
    usz first = from + self.starts[row];
    return { line, row, columns(self.str()[first : self.at - first]) };
}

fn usz Editor.start(&self, usz at)
{
    String s = self.str();
    while (at > 0 && s[at - 1] != '\n') at--;
    return at;
}

fn usz Editor.end(&self, usz at)
{
    String s = self.str();
    while (at < s.len && s[at] != '\n') at++;
    return at;
}

fn usz Editor.forward(&self, usz at)
{
    String s = self.str();
    if (at >= s.len) return at;
    for (at++; at < s.len && (s[at] & 0xC0) == 0x80; at++);
    return at;
}

fn usz Editor.backward(&self, usz at)
{
    String s = self.str();
    if (at == 0) return 0;
    for (at--; at > 0 && (s[at] & 0xC0) == 0x80; at--);
    return at;
}

fn int Editor.line(&self, usz at)
{
    int n;
    foreach (c : self.str()[:at]) if (c == '\n') n++;
    return n;
}

fn int Editor.count(&self) => self.line((usz)self.text.len()) + 1;

fn usz Editor.offset(&self, int line)
{
    String s = self.str();
    usz at;
    for (int n = 0; n < line && at < s.len; at++) if (s[at] == '\n') n++;
    return at;
}

fn int Editor.column(&self)
{
    usz from = self.start(self.at);
    return columns(self.str()[from : self.at - from]);
}

fn usz Editor.place(&self, int line, int row, int goal)
{
    String s = self.str();
    usz base = self.offset(line);
    int rows = self.height(line);
    usz from = base + self.starts[row];
    usz end = row + 1 < rows ? self.backward(base + self.starts[(usz)row + 1]) : self.end(base);
    usz at = from;
    while (at < end)
    {
        usz next = self.forward(at);
        if (columns(s[from : next - from]) > goal) break;
        at = next;
    }
    return at;
}

fn void Editor.vertical(&self, int steps)
{
    Spot spot = self.spot();
    if (self.goal < 0) self.goal = spot.column;
    int line = spot.line;
    int row = spot.row;
    int last = self.count() - 1;
    for (; steps > 0; steps--)
    {
        if (row + 1 < self.height(line))
        {
            row++;
        }
        else if (line < last)
        {
            line++;
            row = 0;
        }
    }
    for (; steps < 0; steps++)
    {
        if (row > 0)
        {
            row--;
        }
        else if (line > 0)
        {
            line--;
            row = self.height(line) - 1;
        }
    }
    self.at = self.place(line, row, self.goal);
}

fn void Editor.scroll(&self, int rows)
{
    Spot spot = self.spot();
    if (spot.line < self.top || (spot.line == self.top && spot.row < self.skip))
    {
        self.top = spot.line;
        self.skip = spot.row;
        return;
    }
    int distance = spot.row - self.skip;
    for (int line = self.top; line < spot.line; line++) distance += self.height(line);
    int margin = rows > 6 ? 2 : 0;
    while (distance > rows - 1 - margin && distance > 0)
    {
        self.skip++;
        distance--;
        if (self.skip >= self.height(self.top))
        {
            self.top++;
            self.skip = 0;
        }
    }
}

fn void forget(List{Snapshot}* list)
{
    foreach (snapshot : *list) free(snapshot.text);
    list.clear();
}

fn void Editor.keep(&self, List{Snapshot}* list)
{
    if (list.len() >= 100)
    {
        free((*list)[0].text);
        list.remove_at(0);
    }
    list.push({ self.str().copy(mem), self.at });
}

fn void Editor.restore(&self, List{Snapshot}* from, List{Snapshot}* to)
{
    if (try snapshot = from.pop())
    {
        self.keep(to);
        self.text.clear();
        self.text.append(snapshot.text);
        self.at = min(snapshot.at, (usz)self.text.len());
        free(snapshot.text);
        self.edited = 0;
        self.dirty = true;
        self.fresh = true;
    }
}

fn void Editor.remember(&self)
{
    ulong now = terminal::now();
    if (now - self.edited > 1000) self.keep(&self.history);
    forget(&self.future);
    self.edited = now;
    self.dirty = true;
    self.warned = false;
    self.fresh = true;
}

fn void Editor.insert(&self, String s)
{
    self.remember();
    if (self.at >= (usz)self.text.len())
    {
        self.text.append(s);
    }
    else
    {
        self.text.insert_chars_at((sz)self.at, s);
    }
    self.at += s.len;
}

fn void Editor.erase(&self, usz from, usz to)
{
    if (to <= from) return;
    self.remember();
    self.text.delete((sz)from, (sz)(to - from));
    self.at = from;
}

fn void Editor.newline(&self)
{
    if (self.pasting)
    {
        self.insert("\n");
        return;
    }
    usz from = self.start(self.at);
    String s = self.str();
    usz indent = from;
    while (indent < self.at && (s[indent] == ' ' || s[indent] == '\t')) indent++;
    @pool()
    {
        self.insert(string::tformat("\n%s", s[from : indent - from]));
    };
}

fn void Editor.copy(&self)
{
    usz from = self.start(self.at);
    self.clip.clear();
    self.clip.append(self.str()[from : self.end(from) - from]);
    self.clip.append_char('\n');
    terminal::copy(self.clip.str_view());
}

fn void Editor.kill(&self)
{
    usz from = self.start(self.at);
    usz to = self.end(from);
    if (to < (usz)self.text.len())
    {
        to++;
    }
    else if (from > 0)
    {
        from--;
    }
    self.erase(from, to);
    self.at = self.start(self.at);
}

fn void Editor.paste(&self)
{
    String clip = self.clip.str_view();
    if (clip.len == 0) return;
    if (clip.ends_with("\n")) self.at = self.start(self.at);
    self.insert(clip);
}

fn void Editor.duplicate(&self)
{
    usz from = self.start(self.at);
    usz to = self.end(from);
    usz column = self.at - from;
    @pool()
    {
        String line = self.str()[from : to - from].tcopy();
        self.at = to;
        self.insert("\n");
        self.insert(line);
    };
    self.at = to + 1 + column;
}

fn bool Editor.find(&self)
{
    String s = self.str();
    String n = self.needle.str_view();
    if (n.len == 0 || n.len > s.len) return false;
    usz total = s.len - n.len + 1;
    for (usz k = 1; k <= total; k++)
    {
        usz p = (self.at + k) % total;
        if (!text::same(s[p : n.len], n)) continue;
        self.at = p;
        return true;
    }
    return false;
}

fn void Editor.open(&self, String content, int line)
{
    self.text.clear();
    self.text.append(content);
    forget(&self.history);
    forget(&self.future);
    self.at = self.offset(max(line, 0));
    self.top = 0;
    self.skip = 0;
    self.left = 0;
    self.goal = -1;
    self.dirty = false;
    self.warned = false;
    self.pasting = false;
    self.prompt = NONE;
    self.edited = 0;
    self.fresh = true;
}

fn void Editor.refresh(&self, int width)
{
    self.doc.free();
    self.doc = parser::parse(self.str());
    self.page.free();
    self.page = render::layout(&self.doc, { .width = width });
    self.fresh = false;
}

fn void Editor.init(&self)
{
    self.text.init(mem, 4096);
    self.input.init(mem, 64);
    self.needle.init(mem, 64);
    self.clip.init(mem, 256);
    self.history.init(mem, 16);
    self.future.init(mem, 16);
    self.starts.init(mem, 16);
    self.wrap = true;
    self.preview = true;
}

fn void Editor.free(&self)
{
    forget(&self.history);
    forget(&self.future);
    self.history.free();
    self.future.free();
    self.starts.free();
    self.text.free();
    self.input.free();
    self.needle.free();
    self.clip.free();
    self.doc.free();
    self.page.free();
}

fn bool View.wide(&self) => self.width >= 100;

fn bool View.split(&self) => self.editor.preview && self.wide();

fn int View.paneRows(&self) => !self.editor.preview || self.wide() ? self.rows : self.rows / 2;

fn int View.previewWidth(&self) => self.wide() ? self.width - self.width / 2 - 2 : self.width - 1;

fn int View.editWidth(&self) => self.split() ? self.width / 2 : self.width;

fn void View.edit(&self)
{
    int src = self.source();
    if (self.focus && self.total() > 0) src = self.doc.blocks[self.lines.lines[self.cursor].block].start;
    self.editor.open(self.content, src);
    self.editor.width = max(self.editWidth() - 5, 1);
    self.mode = EDITOR;
}

fn void View.write(&self)
{
    Editor* e = &self.editor;
    if (catch io::file::save(self.name(), e.str()))
    {
        self.say("✘ Save failed");
        return;
    }
    self.replace(e.str().copy(mem));
    self.stamp = terminal::stamp(self.path.zstr_view());
    e.dirty = false;
    e.warned = false;
    self.say("✔ Saved");
}

fn void View.close(&self)
{
    self.mode = NORMAL;
    self.cursor = self.lines.find(self.editor.line(self.editor.at));
    self.center(self.cursor, self.rows / 3);
}

fn void View.ask(&self, Prompt prompt, String initial)
{
    Editor* e = &self.editor;
    e.prompt = prompt;
    e.input.clear();
    e.input.append(initial);
}

fn void View.command(&self, Act act)
{
    Editor* e = &self.editor;
    switch (act)
    {
        case CLOSE:
            if (e.dirty && !e.warned)
            {
                e.warned = true;
                self.say("Unsaved changes: Ctrl+S to save, Esc again to discard");
                return;
            }
            self.close();
        case MENU: self.menu(EDITS, EDITOR);
        case SAVE: self.write();
        case UNDO: e.restore(&e.history, &e.future);
        case REDO: e.restore(&e.future, &e.history);
        case MARK: self.focus = !self.focus;
        case WRAP:
            e.wrap = !e.wrap;
            e.left = 0;
            self.say(e.wrap ? "Wrap on" : "Wrap off");
        case PREVIEW:
            e.preview = !e.preview;
            e.width = max(self.editWidth() - 5, 1);
            self.say(e.preview ? "Preview on" : "Preview off");
        case COPY:
            e.copy();
            self.say("✔ Copied line");
        case CUT:
            e.copy();
            e.kill();
            self.say("✔ Cut line");
        case PASTE: e.paste();
        case KILL: e.kill();
        case DUPLICATE: e.duplicate();
        case SEARCH: self.ask(FIND, e.needle.str_view());
        case NEXT: if (!e.find()) self.say("Not found");
        case JUMP: self.ask(LINE, "");
        default:
    }
}

fn void View.answer(&self, int key)
{
    Editor* e = &self.editor;
    switch (key)
    {
        case terminal::ESC:
            e.prompt = NONE;
        case terminal::ENTER:
            Prompt prompt = e.prompt;
            e.prompt = NONE;
            if (prompt == LINE)
            {
                int line = e.input.str_view().to_int() ?? 1;
                e.at = e.offset(math::clamp(line, 1, e.count()) - 1);
                return;
            }
            e.needle.clear();
            e.needle.append(e.input.str_view());
            if (!e.find()) self.say("Not found");
        default:
            self.input(&e.input, 120, key, e.prompt == LINE);
    }
}

fn void View.type(&self, int key)
{
    Editor* e = &self.editor;
    if (e.prompt != NONE)
    {
        self.answer(key);
        return;
    }
    Act act = e.pasting ? NONE : lookup(EDITING, key);
    if (act != NONE)
    {
        self.command(act);
        return;
    }
    int page = max(self.paneRows() - 2, 1);
    bool vertical = key == terminal::UP || key == terminal::DOWN || key == terminal::PAGEUP || key == terminal::PAGEDOWN || key == terminal::WHEELUP || key == terminal::WHEELDOWN;
    if (!vertical) e.goal = -1;
    switch (key)
    {
        case terminal::PASTE: e.pasting = true;
        case terminal::PASTED: e.pasting = false;
        case terminal::LEFT: e.at = e.backward(e.at);
        case terminal::RIGHT: e.at = e.forward(e.at);
        case terminal::UP: e.vertical(-1);
        case terminal::DOWN: e.vertical(1);
        case terminal::PAGEUP: e.vertical(-page);
        case terminal::PAGEDOWN: e.vertical(page);
        case terminal::WHEELUP: e.vertical(-3);
        case terminal::WHEELDOWN: e.vertical(3);
        case terminal::HOME: e.at = e.start(e.at);
        case terminal::END: e.at = e.end(e.at);
        case terminal::ENTER: e.newline();
        case terminal::TAB: e.insert(e.pasting ? "\t" : "    ");
        case terminal::BACKSPACE: e.erase(e.backward(e.at), e.at);
        case terminal::DELETE: e.erase(e.at, e.forward(e.at));
        default:
            if (key < 32 || key > 255 || key == 127) return;
            char c = (char)key;
            e.insert((String)(&c)[:1]);
    }
}
