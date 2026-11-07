module app;

import std::io;
import std::math;
import std::collections::list;
import ast;
import parser;
import render;
import ansi;
import terminal;
import text;

struct View
{
    Mode mode;
    DString path;
    String content;
    Document doc;
    render::Page lines;
    render::Config config;
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
    int headingTop;
    int choice;
    int choiceTop;
    int theme;
    int themeTop;
    int original;
    bool focus;
    Item[] items;
    Mode back;
    Editor editor;
    Tree tree;
    DString query;
    DString jump;
    List{int} matches;
    int match;
    DString status;
    int ticks;
    Velocity velocity;
    DString frame;
}

fn String View.name(&self) => self.path.str_view();

fn int View.total(&self) => (int)self.lines.lines.len;

fn int View.last(&self) => self.total() > 0 ? self.total() - 1 : 0;

fn void View.say(&self, String message)
{
    self.status.clear();
    self.status.append(message);
    self.ticks = 40;
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
    return self.lines.lines[self.cursor].src;
}

fn void View.copy(&self)
{
    terminal::copy(self.content);
    self.say("✔ Copied document to clipboard (OSC 52)");
}

fn void View.external(&self)
{
    int src = self.source();
    int line = src >= 0 ? src + 1 : 1;
    terminal::edit(self.name(), line);
    if (try fresh = load(self.name()))
    {
        self.replace(fresh);
        self.cursor = self.lines.find(line - 1);
        self.center(self.cursor, self.rows / 3);
        self.stamp = terminal::stamp(self.path.zstr_view());
    }
    self.say("✔ Resumed from Editor");
}

fn void View.open(&self)
{
    Node* node = self.tree.selected();
    if (node == null) return;
    if (node.dir)
    {
        terminal::chdir((ZString)node.path.ptr);
        self.tree.scan(self.name());
        self.tree.cursor = 0;
        return;
    }
    self.mode = NORMAL;
    String? fresh = load(node.path);
    if (catch fresh) return;
    self.path.clear();
    self.path.append(node.path);
    self.replace(fresh);
    self.top = 0;
    self.cursor = 0;
    self.stamp = terminal::stamp(self.path.zstr_view());
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
    self.editor.width = max(self.editWidth() - 5, 1);
    self.editor.fresh = true;
    self.draw();
}

fn void View.watch(&self)
{
    terminal::Stamp now = terminal::stamp(self.path.zstr_view());
    if (now.inode == 0 || now.same(self.stamp)) return;
    self.stamp = now;
    String? fresh = load(self.name());
    if (catch fresh) return;
    int diff = changed(self.content, fresh);
    if (diff >= 0) self.changed = diff;
    self.config.width = self.width;
    self.replace(fresh);
    if (diff >= 0) self.center(self.lines.find(diff), max(self.rows / 3, 5));
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
    self.tree.names.free();
    self.path.free();
    self.query.free();
    self.jump.free();
    self.status.free();
    self.editor.free();
}

fn bool run(String file, int line, bool noWrap, bool picker)
{
    View view;
    view.path.init(mem, 256);
    view.path.append(file);
    view.query.init(mem, 128);
    view.jump.init(mem, 32);
    view.status.init(mem, 128);
    view.editor.init();
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
        view.cursor = view.lines.find(line - 1);
        view.center(view.cursor, max(view.rows / 3, 5));
    }
    terminal::rawMode();
    terminal::enter();
    defer
    {
        if (view.theme != 0) terminal::out("\e]111\e\\\e]110\e\\");
        terminal::leave();
        terminal::cooked();
    }
    view.restore();
    if (picker) view.files();
    view.draw();
    view.stamp = terminal::stamp(view.path.zstr_view());
    while (true)
    {
        bool dirty;
        if (view.ticks > 0 && --view.ticks == 0)
        {
            view.status.clear();
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
