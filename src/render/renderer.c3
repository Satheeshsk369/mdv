module render;

import std::io;
import std::core::mem;
import ast;
import ansi;
import layout;
import strutils;

struct RenderConfig {
    int width;
    bool plain;
}

struct VisualLineList {
    layout::VisualLine[] items;
    usz count;
    usz capacity;
}

fn void VisualLineList.init(VisualLineList* l, usz initial_cap = 128)
{
    l.items = mem::alloc_array(layout::VisualLine, (sz)initial_cap);
    l.count = 0;
    l.capacity = initial_cap;
}

fn void VisualLineList.push(VisualLineList* l, layout::VisualLine line)
{
    if (l.count >= l.capacity)
    {
        usz new_cap = l.capacity * 2;
        layout::VisualLine[] new_items = mem::alloc_array(layout::VisualLine, (sz)new_cap);
        for (usz i = 0; i < l.count; i++)
        {
            new_items[i] = l.items[i];
        }
        mem::free(l.items);
        l.items = new_items;
        l.capacity = new_cap;
    }
    l.items[l.count++] = line;
}

fn layout::VisualLine[] VisualLineList.to_arena_slice(VisualLineList* l, ast::Arena* arena)
{
    if (l.count == 0) return {};
    layout::VisualLine* buf = (layout::VisualLine*)arena.alloc(l.count * layout::VisualLine::size);
    for (usz i = 0; i < l.count; i++)
    {
        buf[i] = l.items[i];
    }
    return buf[:l.count];
}

fn void VisualLineList.free(VisualLineList* l)
{
    if (l.items.ptr != null)
    {
        mem::free(l.items);
        l.items = {};
        l.count = 0;
        l.capacity = 0;
    }
}

struct LineBuilder {
    char[] buf;
    usz len;
    usz cap;
}

fn void LineBuilder.init(LineBuilder* b, usz initial_cap = 4096)
{
    b.buf = mem::alloc_array(char, (sz)initial_cap);
    b.len = 0;
    b.cap = initial_cap;
}

fn void LineBuilder.append_char(LineBuilder* b, char c)
{
    if (b.len >= b.cap - 1)
    {
        usz new_cap = b.cap * 2;
        char[] new_buf = mem::alloc_array(char, (sz)new_cap);
        for (usz i = 0; i < b.len; i++)
        {
            new_buf[i] = b.buf[i];
        }
        mem::free(b.buf);
        b.buf = new_buf;
        b.cap = new_cap;
    }
    b.buf[b.len++] = c;
}

fn void LineBuilder.append_zstr(LineBuilder* b, char* s)
{
    if (s == null) return;
    usz sl = 0;
    while (s[sl] != 0)
    {
        b.append_char(s[sl++]);
    }
}

fn void LineBuilder.append_slice(LineBuilder* b, String s)
{
    for (usz i = 0; i < (usz)s.len; i++)
    {
        b.append_char(s[i]);
    }
}

fn void LineBuilder.append_spaces(LineBuilder* b, int count)
{
    for (int i = 0; i < count; i++)
    {
        b.append_char(' ');
    }
}

fn void LineBuilder.append_repeat(LineBuilder* b, char* ch, int count)
{
    for (int i = 0; i < count; i++)
    {
        b.append_zstr(ch);
    }
}

fn String LineBuilder.to_string(LineBuilder* b)
{
    return (String)b.buf[:b.len];
}

fn void LineBuilder.reset(LineBuilder* b)
{
    b.len = 0;
}

fn void LineBuilder.free(LineBuilder* b)
{
    if (b.buf.ptr != null)
    {
        mem::free(b.buf);
        b.buf = {};
        b.len = 0;
        b.cap = 0;
    }
}

struct DocRenderContext {
    layout::VisualDocument* vdoc;
    ast::Arena* arena;
    RenderConfig config;
    VisualLineList list;
}

fn void render_span(LineBuilder* b, ast::Span span, bool plain)
{
    switch (span.kind)
    {
        case ast::SpanKind.TEXT:
            b.append_slice(span.text);

        case ast::SpanKind.BOLD:
            if (!plain) b.append_zstr((char*)ansi::BOLD);
            if (span.children.len > 0)
            {
                for (usz i = 0; i < span.children.len; i++)
                {
                    render_span(b, span.children[i], plain);
                }
            }
            else
            {
                b.append_slice(span.text);
            }
            if (!plain) b.append_zstr((char*)ansi::RESET);

        case ast::SpanKind.ITALIC:
            if (!plain) b.append_zstr((char*)ansi::ITALIC);
            if (span.children.len > 0)
            {
                for (usz i = 0; i < span.children.len; i++)
                {
                    render_span(b, span.children[i], plain);
                }
            }
            else
            {
                b.append_slice(span.text);
            }
            if (!plain) b.append_zstr((char*)ansi::RESET);

        case ast::SpanKind.STRIKETHROUGH:
            if (!plain)
            {
                b.append_zstr((char*)ansi::STRIKE);
                b.append_zstr((char*)ansi::FG_MUTED);
            }
            if (span.children.len > 0)
            {
                for (usz i = 0; i < span.children.len; i++)
                {
                    render_span(b, span.children[i], plain);
                }
            }
            else
            {
                b.append_slice(span.text);
            }
            if (!plain) b.append_zstr((char*)ansi::RESET);

        case ast::SpanKind.CODE_INLINE:
            if (!plain) b.append_zstr((char*)ansi::CODE_INLINE);
            if (!plain) b.append_char(' ');
            b.append_slice(span.text);
            if (!plain) b.append_char(' ');
            if (!plain) b.append_zstr((char*)ansi::RESET);

        case ast::SpanKind.MATH_INLINE:
        case ast::SpanKind.MATH_DISPLAY:
            if (!plain) b.append_zstr((char*)ansi::FG_MATH);
            b.append_slice(span.text);
            if (!plain) b.append_zstr((char*)ansi::RESET);

        case ast::SpanKind.LINK:
            if (!plain)
            {
                b.append_zstr((char*)ansi::FG_CYAN);
                b.append_zstr((char*)ansi::UNDERLINE);
            }
            if (span.children.len > 0)
            {
                for (usz i = 0; i < span.children.len; i++)
                {
                    render_span(b, span.children[i], plain);
                }
            }
            else
            {
                b.append_slice(span.text);
            }
            if (!plain) b.append_zstr((char*)ansi::RESET);

            if (span.url.len > 0)
            {
                b.append_char(' ');
                if (!plain) b.append_zstr((char*)ansi::FG_MUTED);
                b.append_char('(');
                b.append_slice(span.url);
                b.append_char(')');
                if (!plain) b.append_zstr((char*)ansi::RESET);
            }
    }
}

fn void render_spans(LineBuilder* b, ast::Span[] spans, bool plain)
{
    for (usz i = 0; i < spans.len; i++)
    {
        render_span(b, spans[i], plain);
    }
}

fn void emit_table_line_cb(void* ctx_ptr, String text, int src_line)
{
    DocRenderContext* ctx = (DocRenderContext*)ctx_ptr;
    layout::VisualLine vl;
    vl.text = ctx.arena.dup_string(text);
    vl.src_line = src_line;
    vl.display_width = strutils::string_display_width(text);
    ctx.list.push(vl);
}

fn void emit_rendered_line(DocRenderContext* ctx, LineBuilder* lb, int src_line)
{
    String s = lb.to_string();
    layout::VisualLine vl;
    vl.text = ctx.arena.dup_string(s);
    vl.src_line = src_line;
    vl.display_width = strutils::string_display_width(s);
    ctx.list.push(vl);
    lb.reset();
}

fn layout::VisualDocument render_document(ast::Document* doc, RenderConfig config)
{
    layout::VisualDocument vdoc;
    vdoc.init();

    DocRenderContext ctx;
    ctx.vdoc = &vdoc;
    ctx.arena = &vdoc.arena;
    ctx.config = config;
    ctx.list.init(256);

    LineBuilder lb;
    lb.init(4096);
    defer lb.free();

    bool plain = config.plain;
    int width = config.width;
    if (width < 20) width = 80;

    for (usz b_idx = 0; b_idx < doc.blocks.len; b_idx++)
    {
        ast::Block* b = &doc.blocks[b_idx];

        switch (b.kind)
        {
            case ast::BlockKind.BLANK:
                emit_rendered_line(&ctx, &lb, b.src_line_start);

            case ast::BlockKind.THEMATIC_BREAK:
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                int bar_len = width - 4;
                if (bar_len < 10) bar_len = 10;
                lb.append_repeat("─", bar_len);
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

            case ast::BlockKind.HEADING:
                lb.reset();
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                if (!plain)
                {
                    switch (b.heading.level)
                    {
                        case 1: lb.append_zstr((char*)ansi::FG_H1); lb.append_zstr("█ ");
                        case 2: lb.append_zstr((char*)ansi::FG_H2); lb.append_zstr("▊ ");
                        case 3: lb.append_zstr((char*)ansi::FG_H3); lb.append_zstr("▋ ");
                        case 4: lb.append_zstr((char*)ansi::FG_H4); lb.append_zstr("▌ ");
                        case 5: lb.append_zstr((char*)ansi::FG_H5); lb.append_zstr("▍ ");
                        default: lb.append_zstr((char*)ansi::FG_H6); lb.append_zstr("▎ ");
                    }
                }
                else
                {
                    for (int k = 0; k < b.heading.level; k++) lb.append_char('#');
                    lb.append_char(' ');
                }

                render_spans(&lb, b.heading.spans, plain);
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

            case ast::BlockKind.CODE_BLOCK:
                // Top border ╭── lang ───────────────────╮
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("╭── ");
                if (b.code.language.len > 0)
                {
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::FG_CYAN);
                        lb.append_zstr((char*)ansi::BOLD);
                    }
                    lb.append_slice(b.code.language);
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::RESET);
                        lb.append_zstr((char*)ansi::FG_MUTED);
                    }
                    lb.append_char(' ');
                }
                int used_w = 4 + (b.code.language.len > 0 ? (int)b.code.language.len + 1 : 0) + 1;
                int cbar_len = width - 4 - used_w;
                if (cbar_len < 4) cbar_len = 4;
                lb.append_repeat("─", cbar_len);
                lb.append_zstr("╮");
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Code block lines
                for (usz l = 0; l < b.code.lines.len; l++)
                {
                    if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                    lb.append_zstr("│ ");
                    if (!plain) lb.append_zstr((char*)ansi::FG_TEXT);
                    lb.append_slice(b.code.lines[l]);
                    if (!plain) lb.append_zstr((char*)ansi::RESET);
                    emit_rendered_line(&ctx, &lb, b.src_line_start + 1 + (int)l);
                }

                // Bottom border ╰────────────────────────╯
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("╰");
                int bbar_len = width - 6;
                if (bbar_len < 8) bbar_len = 8;
                lb.append_repeat("─", bbar_len);
                lb.append_zstr("╯");
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_end);

            case ast::BlockKind.CALLOUT:
                // Title line
                if (!plain)
                {
                    switch (b.callout.kind)
                    {
                        case ast::CalloutKind.NOTE:
                            lb.append_zstr((char*)ansi::FG_CYAN);
                            lb.append_zstr((char*)ansi::BOLD);
                            lb.append_zstr("│ ℹ  NOTE");
                        case ast::CalloutKind.TIP:
                            lb.append_zstr((char*)ansi::FG_GREEN);
                            lb.append_zstr((char*)ansi::BOLD);
                            lb.append_zstr("│ 💡 TIP");
                        case ast::CalloutKind.WARNING:
                            lb.append_zstr((char*)ansi::FG_ORANGE);
                            lb.append_zstr((char*)ansi::BOLD);
                            lb.append_zstr("│ ⚠  WARNING");
                        case ast::CalloutKind.IMPORTANT:
                            lb.append_zstr((char*)ansi::FG_PURPLE);
                            lb.append_zstr((char*)ansi::BOLD);
                            lb.append_zstr("│ 📌 IMPORTANT");
                        case ast::CalloutKind.CAUTION:
                            lb.append_zstr((char*)ansi::FG_PINK);
                            lb.append_zstr((char*)ansi::BOLD);
                            lb.append_zstr("│ ⛔ CAUTION");
                    }
                    lb.append_zstr((char*)ansi::RESET);
                }
                else
                {
                    lb.append_zstr("| [!");
                    lb.append_slice(b.callout.title);
                    lb.append_zstr("]");
                }
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Body line
                if (b.callout.spans.len > 0)
                {
                    if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                    lb.append_zstr("│ ");
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::RESET);
                        lb.append_zstr((char*)ansi::ITALIC);
                    }
                    render_spans(&lb, b.callout.spans, plain);
                    if (!plain) lb.append_zstr((char*)ansi::RESET);
                    emit_rendered_line(&ctx, &lb, b.src_line_end);
                }

            case ast::BlockKind.BLOCKQUOTE:
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("│ ");
                if (!plain)
                {
                    lb.append_zstr((char*)ansi::RESET);
                    lb.append_zstr((char*)ansi::ITALIC);
                }
                render_spans(&lb, b.blockquote.spans, plain);
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

            case ast::BlockKind.LIST_ITEM:
                lb.append_spaces(b.list_item.indent_level);
                switch (b.list_item.kind)
                {
                    case ast::ListKind.TASK_UNCHECKED:
                        if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                        lb.append_zstr("☐  ");
                        if (!plain) lb.append_zstr((char*)ansi::RESET);
                    case ast::ListKind.TASK_CHECKED:
                        if (!plain)
                        {
                            lb.append_zstr((char*)ansi::FG_GREEN);
                            lb.append_zstr((char*)ansi::BOLD);
                        }
                        lb.append_zstr("✔  ");
                        if (!plain) lb.append_zstr((char*)ansi::RESET);
                    case ast::ListKind.BULLET:
                        if (!plain) lb.append_zstr((char*)ansi::FG_YELLOW);
                        if (b.list_item.indent_level >= 4)
                        {
                            lb.append_zstr("▪ ");
                        }
                        else if (b.list_item.indent_level >= 2)
                        {
                            lb.append_zstr("◦ ");
                        }
                        else
                        {
                            lb.append_zstr("• ");
                        }
                        if (!plain) lb.append_zstr((char*)ansi::RESET);
                    default:
                        lb.append_zstr("• ");
                }
                render_spans(&lb, b.list_item.spans, plain);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

            case ast::BlockKind.TABLE:
                layout::render_table(&b.table, b.src_line_start, width, plain, (void*)&ctx, &emit_table_line_cb);

            case ast::BlockKind.PARAGRAPH:
                render_spans(&lb, b.paragraph.spans, plain);
                emit_rendered_line(&ctx, &lb, b.src_line_start);
        }
    }

    vdoc.lines = ctx.list.to_arena_slice(&vdoc.arena);
    ctx.list.free();
    return vdoc;
}

fn void render_to_stdout(ast::Document* doc, RenderConfig config)
{
    layout::VisualDocument vdoc = render_document(doc, config);
    defer vdoc.free();

    for (usz i = 0; i < vdoc.lines.len; i++)
    {
        io::printn(vdoc.lines[i].text);
    }
}
