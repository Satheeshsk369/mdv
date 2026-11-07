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
    int lo;
    int hi = self.count();
    while (lo < hi)
    {
        int mid = (lo + hi) / 2;
        bool before = self.lines[mid].src < src;
        lo = before ? mid + 1 : lo;
        hi = before ? hi : mid;
    }
    return min(lo, max(self.count() - 1, 0));
}

fn void Page.free(&self)
{
    self.arena.free();
    *self = {};
}
