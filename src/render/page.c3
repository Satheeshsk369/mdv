module render;

import ast;

struct Config
{
    int width;
    bool plain;
    bool noWrap;
}

struct Line
{
    String text;
    int src;
    int block;
}

struct Page
{
    Line[] lines;
    int[] anchors;
    ast::Arena arena;
}

fn int Page.count(&self) => (int)self.lines.len;

fn int Page.find(&self, int src)
{
    if (src < 0) return 0;
    foreach (i, line : self.lines) if (line.src >= src) return (int)i;
    return max(self.count() - 1, 0);
}

fn void Page.free(&self)
{
    self.arena.free();
    *self = {};
}
