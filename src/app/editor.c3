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

struct Change
{
    usz at;
    String removed;
    String inserted;
    usz before;
    usz after;
    bool join;
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
    LINE,
    SWAP,
    WITH
}

const String[] LABELS = { "", "Find: ", "Line: ", "Replace: ", "With: " };

$assert(LABELS.len == Prompt::len);

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
    bool warned;
    bool fresh;
    bool wrap;
    bool preview;
    bool pasting;
    bool marked;
    usz mark;
    Prompt prompt;
    ulong edited;
    DString input;
    DString needle;
    DString clip;
    int clean;
    List{Change} history;
    List{Change} future;
    List{usz} hits;
    List{usz} starts;
    List{usz} begins;
    bool indexed;
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

fn void Editor.index(&self)
{
    if (self.indexed) return;
    self.begins.clear();
    self.begins.push(0);
    foreach (usz i, c : self.str()) if (c == '\n') self.begins.push(i + 1);
    self.indexed = true;
}

fn int Editor.line(&self, usz at)
{
    self.index();
    int low;
    int high = (int)self.begins.len() - 1;
    while (low < high)
    {
        int mid = (low + high + 1) / 2;
        if (self.begins[mid] <= at)
        {
            low = mid;
        }
        else
        {
            high = mid - 1;
        }
    }
    return low;
}

fn int Editor.count(&self)
{
    self.index();
    return (int)self.begins.len();
}

fn usz Editor.offset(&self, int line)
{
    self.index();
    return line < self.begins.len() ? self.begins[line] : (usz)self.text.len();
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

fn void forget(List{Change}* list)
{
    foreach (change : *list)
    {
        free(change.removed);
        free(change.inserted);
    }
    list.clear();
}

fn bool Editor.dirty(&self) => (int)self.history.len() != self.clean;

fn void Editor.apply(&self, usz at, usz remove, String add)
{
    self.indexed = false;
    if (remove > 0) self.text.delete((sz)at, (sz)remove);
    if (add.len == 0) return;
    if (at >= (usz)self.text.len())
    {
        self.text.append(add);
    }
    else
    {
        self.text.insert_chars_at((sz)at, add);
    }
}

fn void Editor.record(&self, usz at, String removed, String inserted, usz after)
{
    ulong now = terminal::now();
    int count = (int)self.history.len();
    bool join = count > 0 && count != self.clean && now - self.edited <= 1000;
    if (self.clean > count) self.clean = -1;
    forget(&self.future);
    self.history.push({ at, removed.copy(mem), inserted.copy(mem), self.at, after, join });
    self.edited = now;
    self.warned = false;
    self.fresh = true;
}

fn void Editor.insert(&self, String s)
{
    self.record(self.at, "", s, self.at + s.len);
    self.apply(self.at, 0, s);
    self.at += s.len;
}

fn void Editor.erase(&self, usz from, usz to)
{
    if (to <= from) return;
    self.record(from, self.str()[from : to - from], "", from);
    self.apply(from, to - from, "");
    self.at = from;
}

fn void Editor.undo(&self)
{
    while (try change = self.history.pop())
    {
        self.apply(change.at, change.inserted.len, change.removed);
        self.at = change.before;
        self.future.push(change);
        if (!change.join) break;
    }
    self.settle();
}

fn void Editor.redo(&self)
{
    for (bool first = true; self.future.len() > 0; first = false)
    {
        Change change = self.future[self.future.len() - 1];
        if (!first && !change.join) break;
        self.future.pop()!!;
        self.apply(change.at, change.removed.len, change.inserted);
        self.at = change.after;
        self.history.push(change);
    }
    self.settle();
}

fn void Editor.settle(&self)
{
    self.marked = false;
    self.edited = 0;
    self.fresh = true;
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
    String line = s[indent : self.end(from) - indent];
    usz marker;
    int number = -1;
    foreach (bullet : BULLETS)
    {
        if (!line.starts_with(bullet)) continue;
        marker = bullet.len;
        break;
    }
    if (marker == 0)
    {
        usz d;
        while (d < line.len && line[d].is_digit()) d++;
        if (d > 0 && d + 1 < line.len && (line[d] == '.' || line[d] == ')') && line[d + 1] == ' ')
        {
            marker = d + 2;
            number = line[:d].to_int() ?? 0;
        }
    }
    if (marker > 0 && self.at >= indent + marker)
    {
        if (line.len == marker)
        {
            self.erase(indent, indent + marker);
            return;
        }
        @pool()
        {
            String next = number >= 0 ? string::tformat("%d%c ", number + 1, line[marker - 2]) : line.starts_with("- [") || line.starts_with("* [") ? string::tformat("%c [ ] ", line[0]) : line[:marker];
            self.insert(string::tformat("\n%s%s", s[from : indent - from], next));
        };
        return;
    }
    @pool()
    {
        self.insert(string::tformat("\n%s", s[from : indent - from]));
    };
}

const String OPENERS = "([{`\"";
const String CLOSERS = ")]}`\"";
const String WRAPPERS = "*_~$";

fn bool Editor.paired(&self)
{
    String s = self.str();
    if (self.at == 0 || self.at >= s.len) return false;
    sz k = OPENERS.index_of_char(s[self.at - 1]) ?? -1;
    return k >= 0 && s[self.at] == CLOSERS[k];
}

fn bool Editor.pair(&self, char c)
{
    String s = self.str();
    sz open = OPENERS.index_of_char(c) ?? -1;
    if (self.selected() && (open >= 0 || WRAPPERS.contains_char(c)))
    {
        char close = open >= 0 ? CLOSERS[open] : c;
        usz low = self.low();
        usz high = self.high();
        @pool()
        {
            self.splice(low, high, string::tformat("%c%s%c", c, s[low : high - low], close));
        };
        self.select(low + 1, high + 1);
        return true;
    }
    if (self.selected()) return false;
    char next = self.at < s.len ? s[self.at] : '\n';
    char prior = self.at > 0 ? s[self.at - 1] : '\n';
    if (CLOSERS.contains_char(c) && next == c)
    {
        self.at++;
        return true;
    }
    if (open < 0) return false;
    bool quote = c == '"' || c == '`';
    if (quote && (prior.is_alnum() || prior == c)) return false;
    if (next != '\n' && next != ' ' && !CLOSERS.contains_char(next)) return false;
    @pool()
    {
        self.insert(string::tformat("%c%c", c, CLOSERS[open]));
    };
    self.at--;
    return true;
}

fn bool word(char c) => c.is_alnum() || c == '_' || c >= 0x80;

fn usz Editor.wordLeft(&self, usz at)
{
    String s = self.str();
    while (at > 0 && !word(s[at - 1])) at--;
    while (at > 0 && word(s[at - 1])) at--;
    return at;
}

fn usz Editor.wordRight(&self, usz at)
{
    String s = self.str();
    while (at < s.len && !word(s[at])) at++;
    while (at < s.len && word(s[at])) at++;
    return at;
}

fn usz Editor.home(&self, usz at)
{
    String s = self.str();
    usz from = self.start(at);
    usz first = from;
    while (first < s.len && (s[first] == ' ' || s[first] == '\t')) first++;
    return at == first ? from : first;
}

fn bool Editor.selected(&self) => self.marked && self.mark != self.at;

fn usz Editor.low(&self) => self.selected() ? min(self.mark, self.at) : self.at;

fn usz Editor.high(&self) => self.selected() ? max(self.mark, self.at) : self.at;

fn usz Editor.first(&self) => self.start(self.low());

fn usz Editor.last(&self)
{
    usz high = self.high();
    if (self.selected() && high > self.low() && self.str()[high - 1] == '\n') high--;
    return self.end(high);
}

fn bool Editor.remove(&self)
{
    if (!self.selected())
    {
        self.marked = false;
        return false;
    }
    usz low = self.low();
    usz high = self.high();
    self.marked = false;
    self.erase(low, high);
    return true;
}

fn void Editor.select(&self, usz from, usz to)
{
    self.mark = from;
    self.at = to;
    self.marked = true;
}

fn void Editor.splice(&self, usz from, usz to, String with)
{
    self.erase(from, to);
    self.at = from;
    self.insert(with);
}

const String[] BULLETS = { "- [ ] ", "- [x] ", "* [ ] ", "* [x] ", "- ", "* ", "+ ", "> " };

fn void Editor.copy(&self)
{
    self.clip.clear();
    if (self.selected())
    {
        self.clip.append(self.str()[self.low() : self.high() - self.low()]);
    }
    else
    {
        usz from = self.start(self.at);
        self.clip.append(self.str()[from : self.end(from) - from]);
        self.clip.append_char('\n');
    }
    terminal::copy(self.clip.str_view());
}

fn void Editor.kill(&self)
{
    usz from = self.first();
    usz to = self.last();
    self.marked = false;
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
    if (!self.remove() && clip.ends_with("\n")) self.at = self.start(self.at);
    @pool()
    {
        self.insert(clip.tcopy());
    };
}

fn void Editor.duplicate(&self)
{
    usz from = self.first();
    usz to = self.last();
    usz shift = to - from + 1;
    @pool()
    {
        String block = self.str()[from : to - from].tcopy();
        usz at = self.at;
        usz mark = self.mark;
        self.at = to;
        self.insert("\n");
        self.insert(block);
        self.at = at + shift;
        self.mark = mark + shift;
    };
}

fn void Editor.shift(&self, int direction)
{
    usz from = self.first();
    usz to = self.last();
    String s = self.str();
    if (direction < 0 && from == 0) return;
    if (direction > 0 && to >= s.len) return;
    @pool()
    {
        String block = s[from : to - from].tcopy();
        if (direction < 0)
        {
            usz above = self.start(from - 1);
            String prior = s[above : from - 1 - above].tcopy();
            usz move = from - above;
            usz at = self.at - move;
            usz mark = self.mark - move;
            self.splice(above, to, string::tformat("%s\n%s", block, prior));
            self.at = at;
            self.mark = mark;
        }
        else
        {
            usz below = self.end(to + 1);
            String next = s[to + 1 : below - to - 1].tcopy();
            usz move = next.len + 1;
            usz at = self.at + move;
            usz mark = self.mark + move;
            self.splice(from, below, string::tformat("%s\n%s", next, block));
            self.at = at;
            self.mark = mark;
        }
    };
}

fn void Editor.indent(&self, bool outward)
{
    usz from = self.first();
    usz to = self.last();
    bool selected = self.selected();
    usz column = self.at - self.start(self.at);
    DString block;
    block.init(mem, (sz)(to - from) + 64);
    defer block.free();
    int removed;
    @pool()
    {
        foreach (line : self.str()[from : to - from].tsplit("\n"))
        {
            if (block.len() > 0) block.append_char('\n');
            if (!outward)
            {
                block.append("    ");
                block.append(line);
                continue;
            }
            usz cut;
            while (cut < 4 && cut < line.len && line[cut] == ' ') cut++;
            if (cut == 0 && line.len > 0 && line[0] == '\t') cut = 1;
            if (removed == 0) removed = (int)cut;
            block.append(line[cut..]);
        }
    };
    self.splice(from, to, block.str_view());
    if (selected)
    {
        self.select(from, from + (usz)block.len());
        return;
    }
    self.at = from + (outward ? column - min(column, (usz)removed) : column + 4);
    self.marked = false;
}

fn bool Editor.find(&self)
{
    String s = self.str();
    String n = self.needle.str_view();
    if (n.len == 0 || n.len > s.len) return false;
    usz total = s.len - n.len + 1;
    for (usz k = 1; k <= total; k++)
    {
        usz p = (self.low() + k) % total;
        if (!text::same(s[p : n.len], n)) continue;
        self.select(p, p + n.len);
        return true;
    }
    return false;
}

fn int Editor.replace(&self, String with)
{
    String s = self.str();
    String n = self.needle.str_view();
    if (n.len == 0) return 0;
    DString out;
    out.init(mem, (sz)s.len + 64);
    defer out.free();
    int count;
    for (usz p = 0; p < s.len;)
    {
        if (p + n.len <= s.len && text::same(s[p : n.len], n))
        {
            out.append(with);
            p += n.len;
            count++;
            continue;
        }
        out.append_char(s[p++]);
    }
    if (count == 0) return 0;
    usz at = min(self.at, (usz)out.len());
    self.marked = false;
    self.splice(0, s.len, out.str_view());
    self.at = at;
    return count;
}

fn void Editor.open(&self, String content, int line)
{
    self.text.clear();
    self.text.append(content);
    self.indexed = false;
    forget(&self.history);
    forget(&self.future);
    self.at = self.offset(max(line, 0));
    self.top = 0;
    self.skip = 0;
    self.left = 0;
    self.goal = -1;
    self.clean = 0;
    self.warned = false;
    self.pasting = false;
    self.marked = false;
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
    self.hits.init(mem, 16);
    self.starts.init(mem, 16);
    self.begins.init(mem, 1024);
    self.wrap = true;
    self.preview = true;
}

fn void Editor.free(&self)
{
    forget(&self.history);
    forget(&self.future);
    self.history.free();
    self.future.free();
    self.hits.free();
    self.starts.free();
    self.begins.free();
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
    terminal::mouse(true);
}

fn void View.write(&self)
{
    Editor* e = &self.editor;
    if (!terminal::store(self.name(), e.str()))
    {
        self.say("✘ Save failed");
        return;
    }
    self.replace(e.str().copy(mem));
    self.stamp = terminal::stamp(self.name());
    e.clean = (int)e.history.len();
    e.warned = false;
    self.say("✔ Saved");
}

fn void View.close(&self)
{
    terminal::mouse(false);
    self.mode = NORMAL;
    self.cursor = self.lines.find(self.editor.line(self.editor.at));
    self.center(self.cursor, self.rows / 3);
}

fn void View.point(&self, int key)
{
    Editor* e = &self.editor;
    int base = key & terminal::KEY;
    int r = terminal::pointerRow - 3;
    int x = terminal::pointerColumn - 1;
    if (base == terminal::RELEASE || r < 0 || r >= self.rows) return;
    bool split = self.split();
    int editRows = self.paneRows();
    if (split ? x >= self.editWidth() : r >= editRows)
    {
        int p = e.view + (split ? r : r - editRows - 1);
        if (base != terminal::CLICK || !e.preview || p < e.view || p >= e.page.count()) return;
        e.marked = false;
        e.at = e.offset(e.page.lines[p].src);
        return;
    }
    int count = e.count();
    int line = e.top;
    int row = e.skip;
    for (int k = 0; k < r && line < count; k++)
    {
        if (++row < e.height(line)) continue;
        line++;
        row = 0;
    }
    if (line >= count)
    {
        line = count - 1;
        row = e.height(line) - 1;
    }
    int column = max(x - 5, 0);
    if (!e.wrap && line == e.line(e.at)) column += e.left;
    usz at = e.place(line, row, column);
    if (base == terminal::DRAG || (key & terminal::SHIFT) != 0)
    {
        if (!e.marked) e.select(e.at, e.at);
        e.at = at;
        return;
    }
    e.select(at, at);
}

fn void View.ask(&self, Prompt prompt, String initial)
{
    Editor* e = &self.editor;
    e.prompt = prompt;
    e.input.clear();
    e.input.append(initial);
}

fn bool View.quit(&self)
{
    Editor* e = &self.editor;
    if (!e.dirty() || e.warned) return true;
    e.warned = true;
    self.say("Unsaved changes: Ctrl+S to save, Ctrl+Q again to quit");
    return false;
}

fn void View.command(&self, Act act)
{
    Editor* e = &self.editor;
    switch (act)
    {
        case CLOSE:
            if (e.selected())
            {
                e.marked = false;
                return;
            }
            if (e.needle.len() > 0)
            {
                e.needle.clear();
                return;
            }
            if (e.dirty() && !e.warned)
            {
                e.warned = true;
                self.say("Unsaved changes: Ctrl+S to save, Esc again to discard");
                return;
            }
            self.close();
        case MENU: self.menu(EDITS, EDITOR);
        case SAVE: self.write();
        case UNDO: e.undo();
        case REDO: e.redo();
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
            self.say(e.selected() ? "✔ Copied selection" : "✔ Copied line");
            e.copy();
        case CUT:
            self.say(e.selected() ? "✔ Cut selection" : "✔ Cut line");
            e.copy();
            if (!e.remove()) e.kill();
        case ALL: e.select(0, (usz)e.text.len());
        case RAISE: e.shift(-1);
        case LOWER: e.shift(1);
        case INDENT: e.indent(false);
        case OUTDENT: e.indent(true);
        case PASTE: e.paste();
        case KILL: e.kill();
        case DUPLICATE: e.duplicate();
        case SEARCH: self.ask(FIND, e.needle.str_view());
        case NEXT: if (!e.find()) self.say("Not found");
        case JUMP: self.ask(LINE, "");
        case REPLACE: self.ask(SWAP, e.needle.str_view());
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
            if (prompt == WITH)
            {
                @pool()
                {
                    self.say(string::tformat("✔ Replaced %d", e.replace(e.input.str_view())));
                };
                return;
            }
            e.needle.clear();
            e.needle.append(e.input.str_view());
            if (prompt == SWAP)
            {
                self.ask(WITH, "");
                return;
            }
            if (!e.find()) self.say("Not found");
        default:
            self.input(&e.input, 120, key, e.prompt == LINE);
    }
}

fn bool View.type(&self, int key)
{
    Editor* e = &self.editor;
    if (e.prompt != NONE)
    {
        self.answer(key);
        return false;
    }
    Act act = e.pasting ? NONE : lookup(EDITING, key);
    if (act == QUIT) return self.quit();
    if (act != NONE)
    {
        self.command(act);
        return false;
    }
    int page = max(self.paneRows() - 2, 1);
    int base = key & terminal::KEY;
    bool shift = (key & terminal::SHIFT) != 0;
    bool ctrl = (key & terminal::CTRL) != 0;
    bool vertical = base == terminal::UP || base == terminal::DOWN || base == terminal::PAGEUP || base == terminal::PAGEDOWN || base == terminal::WHEELUP || base == terminal::WHEELDOWN;
    bool motion = vertical || base == terminal::LEFT || base == terminal::RIGHT || base == terminal::HOME || base == terminal::END;
    if (!vertical || ctrl) e.goal = -1;
    if (base == terminal::CLICK || base == terminal::DRAG || base == terminal::RELEASE)
    {
        self.point(key);
        return false;
    }
    if (motion && base != terminal::WHEELUP && base != terminal::WHEELDOWN)
    {
        if (shift && !e.marked) e.select(e.at, e.at);
        if (!shift)
        {
            bool collapse = e.selected() && !ctrl && (base == terminal::LEFT || base == terminal::RIGHT);
            usz edge = base == terminal::LEFT ? e.low() : e.high();
            e.marked = false;
            if (collapse)
            {
                e.at = edge;
                return false;
            }
        }
    }
    switch (base)
    {
        case terminal::PASTE:
            e.remove();
            e.pasting = true;
        case terminal::PASTED: e.pasting = false;
        case terminal::LEFT: e.at = ctrl ? e.wordLeft(e.at) : e.backward(e.at);
        case terminal::RIGHT: e.at = ctrl ? e.wordRight(e.at) : e.forward(e.at);
        case terminal::UP: e.vertical(-1);
        case terminal::DOWN: e.vertical(1);
        case terminal::PAGEUP: e.vertical(-page);
        case terminal::PAGEDOWN: e.vertical(page);
        case terminal::WHEELUP: e.vertical(-3);
        case terminal::WHEELDOWN: e.vertical(3);
        case terminal::HOME: e.at = ctrl ? 0 : e.home(e.at);
        case terminal::END: e.at = ctrl ? (usz)e.text.len() : e.end(e.at);
        case terminal::ENTER:
            e.remove();
            e.newline();
        case terminal::TAB:
            if (e.pasting)
            {
                e.insert("\t");
            }
            else if (e.selected())
            {
                e.indent(false);
            }
            else
            {
                e.insert("    ");
            }
        case terminal::BACKSPACE:
            if (e.remove()) return false;
            if (!ctrl && e.paired())
            {
                e.erase(e.at - 1, e.at + 1);
                return false;
            }
            e.erase(ctrl ? e.wordLeft(e.at) : e.backward(e.at), e.at);
        case terminal::DELETE:
            if (!e.remove()) e.erase(e.at, ctrl ? e.wordRight(e.at) : e.forward(e.at));
        default:
            if (key < 32 || key > 255 || key == 127) return false;
            char c = (char)key;
            if (!e.pasting && e.pair(c)) return false;
            e.remove();
            e.insert((String)(&c)[:1]);
    }
    return false;
}
