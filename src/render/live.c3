module render;

import std::core::mem;
import std::collections::list;
import ast;
import parser;

struct Live
{
    Document doc;
    Page page;
    List{Block} blocks;
    List{Line} rows;
    List{int} anchors;
    DString source;
    int width;
    usz budget;
    bool ready;
}

fn void Live.init(&self)
{
    self.blocks.init(mem, 256);
    self.rows.init(mem, 1024);
    self.anchors.init(mem, 256);
    self.source.init(mem, 4096);
}

fn void Live.free(&self)
{
    self.doc.free();
    self.page.free();
    self.blocks.free();
    self.rows.free();
    self.anchors.free();
    self.source.free();
}

fn void Live.update(&self, String text, int width)
{
    Splice s;
    bool quick = self.ready && width == self.width && self.doc.arena.bytes() + self.page.arena.bytes() < self.budget;
    if (quick && parser::reparse(&self.doc, &self.blocks, self.source.str_view(), text, &s))
    {
        self.splice(s);
    }
    else
    {
        self.rebuild(text, width);
    }
    self.source.clear();
    self.source.append(text);
    self.width = width;
    self.ready = true;
}

fn void Live.rebuild(&self, String text, int width)
{
    self.doc.free();
    self.doc = parser::parse(text);
    self.blocks.clear();
    self.blocks.push_all(self.doc.blocks);
    self.doc.blocks = self.blocks.array_view();
    self.page.free();
    self.page = layout(&self.doc, { .width = width });
    self.rows.clear();
    self.rows.push_all(self.page.lines);
    self.anchors.clear();
    self.anchors.push_all(self.page.anchors);
    self.anchors.push((int)self.rows.len());
    self.point();
    self.budget = 2 * (self.doc.arena.bytes() + self.page.arena.bytes()) + (1 << 20);
}

fn void Live.point(&self)
{
    self.page.lines = self.rows.array_view();
    self.page.anchors = self.anchors.array_view()[: self.anchors.len() - 1];
}

fn int edge(Line[] lines, int block)
{
    int lo;
    int hi = (int)lines.len;
    while (lo < hi)
    {
        int mid = (lo + hi) / 2;
        bool before = lines[mid].block < block;
        lo = before ? mid + 1 : lo;
        hi = before ? hi : mid;
    }
    return lo;
}

fn void Live.splice(&self, Splice s)
{
    Line[] old = self.rows.array_view();
    int[] marks = self.anchors.array_view();
    int cut = edge(old, s.first);
    int resume = edge(old, s.first + s.removed);
    Renderer r = { .page = &self.page, .config = { .width = self.width }, .width = self.width < 20 ? 80 : self.width };
    r.lines.init(mem, old.len + 256);
    r.pieces.init(mem, 16);
    r.buf.init(mem, 4096);
    defer r.pieces.free();
    defer r.buf.free();
    List{int} anchors;
    anchors.init(mem, self.doc.blocks.len + 1);
    r.lines.push_all(old[:cut]);
    anchors.push_all(marks[:s.first]);
    for (int i = s.first; i < s.first + s.added; i++)
    {
        r.block = i;
        anchors.push((int)r.lines.len());
        self.page.anchors = anchors.array_view();
        r.render(&self.doc.blocks[i]);
    }
    int moved = (int)r.lines.len() - resume;
    foreach (line : old[resume..])
    {
        r.lines.push({ line.text, line.src + s.delta, line.block + s.added - s.removed });
    }
    foreach (mark : marks[s.first + s.removed..]) anchors.push(mark + moved);
    self.rows.free();
    self.rows = r.lines;
    self.anchors.free();
    self.anchors = anchors;
    self.point();
}
