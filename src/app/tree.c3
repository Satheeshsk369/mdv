module app;

import std::io;
import ast;
import terminal;
import text;
import ansi;

struct Dirent
{
    ulong d_ino;
    long d_off;
    ushort d_reclen;
    char d_type;
    char[256] d_name;
}

extern fn void* opendir(ZString name);
extern fn Dirent* readdir(void* dir);
extern fn int closedir(void* dir);

const String[] SKIP = { "build", "node_modules", "target", ".git", "dist", ".cache" };

struct Node
{
    String path;
    String name;
    int depth;
    bool dir;
    bool open;
    bool current;
    bool last;
}

struct Tree
{
    ast::Arena names;
    Node[128] nodes;
    usz count;
    int[128] shown;
    int visible;
    int cursor;
    int top;
}

fn bool markdown(String name)
{
    return name.ends_with(".md") || name.ends_with(".markdown");
}

fn bool skipped(String name)
{
    foreach (s : SKIP) if (name == s) return true;
    return false;
}

fn String join(ast::Arena* arena, String dir, String name)
{
    @pool()
    {
        return arena.copy(dir == "." ? name : string::tformat("%s/%s", dir, name));
    };
}

fn bool hasMarkdown(ZString dir, int depth)
{
    if (depth <= 0) return false;
    void* d = opendir(dir);
    if (d == null) return false;
    defer closedir(d);
    for (Dirent* e = readdir(d); e != null; e = readdir(d))
    {
        String name = ((ZString)&e.d_name).str_view();
        if (name[0] == '.') continue;
        if (markdown(name)) return true;
        if (e.d_type != 4 || skipped(name)) continue;
        bool found;
        @pool()
        {
            found = hasMarkdown(string::tformat("%s/%s", dir, name).zstr_tcopy(), depth - 1);
        };
        if (found) return true;
    }
    return false;
}

fn void Tree.add(&self, String path, String name, int depth, bool dir, bool last, String current)
{
    Node* node = &self.nodes[self.count++];
    node.path = path;
    node.name = self.names.copy(name);
    node.depth = depth;
    node.dir = dir;
    node.open = dir && depth < 3;
    node.last = last;
    node.current = !dir && current.len > 0 && (path == current || name == current);
}

fn void Tree.walk(&self, ZString dir, int depth, String current)
{
    if (self.count >= 120 || depth > 5) return;
    void* d = opendir(dir);
    if (d == null) return;
    Dirent[64] dirs;
    Dirent[64] files;
    int dirCount;
    int fileCount;
    for (Dirent* e = readdir(d); e != null; e = readdir(d))
    {
        String name = ((ZString)&e.d_name).str_view();
        if (name[0] == '.') continue;
        if (e.d_type == 4)
        {
            if (skipped(name)) continue;
            bool found;
            @pool()
            {
                found = hasMarkdown(join(&self.names, dir.str_view(), name).zstr_tcopy(), 4);
            };
            if (found && dirCount < 60) dirs[dirCount++] = *e;
        }
        else if (markdown(name) && fileCount < 60)
        {
            files[fileCount++] = *e;
        }
    }
    closedir(d);
    int total = dirCount + fileCount;
    int index;
    for (int i = 0; i < fileCount && self.count < 120; i++)
    {
        index++;
        String name = ((ZString)&files[i].d_name).str_view();
        self.add(join(&self.names, dir.str_view(), name), name, depth, false, index == total, current);
    }
    for (int i = 0; i < dirCount && self.count < 120; i++)
    {
        index++;
        String name = ((ZString)&dirs[i].d_name).str_view();
        String path = join(&self.names, dir.str_view(), name);
        self.add(path, name, depth, true, index == total, current);
        self.walk((ZString)path.ptr, depth + 1, current);
    }
}

fn void Tree.scan(&self, String current)
{
    self.names.free();
    self.names.init(16384);
    self.count = 0;
    self.top = 0;
    self.nodes[self.count++] = { .path = "..", .name = "..", .dir = true };
    self.walk(".", 0, current);
    self.layout();
}

fn void Tree.layout(&self)
{
    int[16] closed;
    int depth;
    self.visible = 0;
    for (usz i = 0; i < self.count; i++)
    {
        Node* node = &self.nodes[i];
        while (depth > 0 && closed[depth - 1] >= node.depth) depth--;
        if (depth == 0 && self.visible < 128) self.shown[self.visible++] = (int)i;
        if (node.dir && !node.open && depth < 15) closed[depth++] = node.depth;
    }
}

fn void Tree.focus(&self)
{
    self.cursor = 0;
    for (int v = 0; v < self.visible; v++)
    {
        if (self.nodes[self.shown[v]].current)
        {
            self.cursor = v;
            return;
        }
    }
}

fn Node* Tree.selected(&self)
{
    return self.cursor < self.visible ? &self.nodes[self.shown[self.cursor]] : null;
}

fn void Tree.toggleAll(&self)
{
    bool open;
    for (usz i = 0; i < self.count; i++) open = open || (self.nodes[i].dir && self.nodes[i].open);
    for (usz i = 0; i < self.count; i++)
    {
        Node* node = &self.nodes[i];
        if (node.dir && node.name != "..") node.open = !open;
    }
    self.layout();
}

fn void Tree.left(&self)
{
    Node* node = self.selected();
    if (node == null) return;
    if (node.dir && node.open)
    {
        node.open = false;
        self.layout();
        return;
    }
    if (node.depth == 0) return;
    for (int p = self.cursor - 1; p >= 0; p--)
    {
        Node* parent = &self.nodes[self.shown[p]];
        if (parent.dir && parent.depth < node.depth)
        {
            self.cursor = p;
            return;
        }
    }
}

fn bool Tree.right(&self)
{
    Node* node = self.selected();
    if (node == null || !node.dir) return false;
    if (!node.open)
    {
        node.open = true;
        self.layout();
    }
    else if (self.cursor + 1 < self.visible)
    {
        self.cursor++;
    }
    return true;
}

fn bool Tree.toggle(&self)
{
    Node* node = self.selected();
    if (node == null || !node.dir) return false;
    node.open = !node.open;
    self.layout();
    return true;
}
