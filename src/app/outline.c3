module app;

import std::core::mem;
import ast;

struct Heading
{
    int level;
    String title;
    int src;
    int line;
}

fn void View.index(&self)
{
    self.outline.clear();
    foreach (i, &b : self.doc.blocks)
    {
        if (b.kind != BlockKind.HEADING) continue;
        DString title;
        title.init(mem, 128);
        defer title.free();
        foreach (span : b.spans) title.append(span.text);
        self.outline.push({ b.level, title.keep(&self.lines.arena), b.start, self.lines.anchors[i] });
    }
}
