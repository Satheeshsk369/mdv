module layout;

import std::core::mem;
import ast;

struct VisualLine {
    String text;
    int src_line;
    int display_width;
}

struct VisualDocument {
    VisualLine[] lines;
    ast::Arena arena;
}

fn void VisualDocument.init(VisualDocument* doc)
{
    doc.lines = {};
    doc.arena.init(65536);
}

fn int VisualDocument.get_total_lines(VisualDocument* doc)
{
    return (int)doc.lines.len;
}

fn int VisualDocument.find_visual_line(VisualDocument* doc, int src_target)
{
    if (src_target < 0) return 0;
    int total = (int)doc.lines.len;
    for (int i = 0; i < total; i++)
    {
        if (doc.lines[i].src_line >= src_target)
        {
            return i;
        }
    }
    if (total > 0) return total - 1;
    return 0;
}

fn void VisualDocument.free(VisualDocument* doc)
{
    doc.arena.free();
    doc.lines = {};
}
