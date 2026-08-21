module render;

import std::io;
import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import math;
import strutils;
import buffer;

struct DocRenderContext {
    VisualDocument* vdoc;
    logic::Arena* arena;
    RenderConfig config;
    List{VisualLine} list;
}

fn void render_span(buffer::ByteBuffer* b, Span span, bool plain)
{
    switch (span.kind)
    {
        case SpanKind.TEXT:
            b.append_slice(span.text);

        case SpanKind.BOLD:
            if (!plain) b.append_zstr(ansi::BOLD);
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
            if (!plain) b.append_zstr(ansi::RESET);

        case SpanKind.ITALIC:
            if (!plain) b.append_zstr(ansi::ITALIC);
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
            if (!plain) b.append_zstr(ansi::RESET);

        case SpanKind.STRIKETHROUGH:
            if (!plain)
            {
                b.append_zstr(ansi::STRIKE);
                b.append_zstr(ansi::fg_muted);
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
            if (!plain) b.append_zstr(ansi::RESET);

        case SpanKind.CODE_INLINE:
            if (!plain) b.append_zstr(ansi::code_inline);
            if (!plain) b.append_char(' ');
            b.append_slice(span.text);
            if (!plain) b.append_char(' ');
            if (!plain) b.append_zstr(ansi::RESET);

        case SpanKind.MATH_INLINE:
        case SpanKind.MATH_DISPLAY:
            b.append_slice(span.text);

        case SpanKind.FOOTNOTE_REF:
            if (!plain)
            {
                b.append_zstr(ansi::fg_cyan);
                b.append_zstr(ansi::BOLD);
            }
            b.append_char('[');
            b.append_slice(span.text);
            b.append_char(']');
            if (!plain) b.append_zstr(ansi::RESET);

        case SpanKind.LINK:
            if (!plain && span.url.len > 0)
            {
                b.append_zstr("\x1b]8;;");
                b.append_slice(span.url);
                b.append_zstr("\x1b\\");
            }
            if (!plain)
            {
                b.append_zstr(ansi::fg_cyan);
                b.append_zstr(ansi::UNDERLINE);
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
            if (!plain) b.append_zstr(ansi::RESET);
            if (!plain && span.url.len > 0)
            {
                b.append_zstr("\x1b]8;;\x1b\\");
            }

            if (span.url.len > 0)
            {
                b.append_char(' ');
                if (!plain) b.append_zstr(ansi::fg_muted);
                b.append_char('(');
                b.append_slice(span.url);
                b.append_char(')');
                if (!plain) b.append_zstr(ansi::RESET);
            }

        case SpanKind.IMAGE:
            b.append_zstr("🖼  ");
            if (!plain)
            {
                b.append_zstr(ansi::fg_cyan);
                b.append_zstr(ansi::BOLD);
            }
            b.append_char('[');
            b.append_slice(span.text);
            b.append_char(']');
            if (!plain) b.append_zstr(ansi::RESET);

            if (span.url.len > 0)
            {
                b.append_char(' ');
                if (!plain) b.append_zstr(ansi::fg_muted);
                b.append_char('(');
                b.append_slice(span.url);
                b.append_char(')');
                if (!plain) b.append_zstr(ansi::RESET);
            }
    }
}

fn void render_spans(buffer::ByteBuffer* b, Span[] spans, bool plain)
{
    for (usz i = 0; i < spans.len; i++)
    {
        render_span(b, spans[i], plain);
    }
}

fn void emit_table_line_cb(void* ctx_ptr, String text, int src_line)
{
    DocRenderContext* ctx = (DocRenderContext*)ctx_ptr;
    VisualLine vl;
    vl.text = ctx.arena.dup_string(text);
    vl.src_line = src_line;
    vl.display_width = strutils::string_display_width(text);
    ctx.list.push(vl);
}

fn void render_wrapped_spans(
    void* emit_ctx,
    EmitLineFn emit_fn,
    Span[] spans,
    int src_line,
    int max_w,
    String prefix_str,
    String first_prefix_str,
    bool plain,
    bool no_wrap
)
{
    if (spans.len == 0)
    {
        if (first_prefix_str.len > 0)
        {
            emit_fn(emit_ctx, first_prefix_str, src_line);
        }
        return;
    }

    if (no_wrap || max_w <= 20)
    {
        buffer::ByteBuffer lb;
        lb.init(4096);
        defer lb.free();
        if (first_prefix_str.len > 0) lb.append_slice(first_prefix_str);
        render_spans(&lb, spans, plain);
        emit_fn(emit_ctx, lb.to_string(), src_line);
        return;
    }

    buffer::ByteBuffer cur_line;
    cur_line.init(4096);
    defer cur_line.free();

    int cur_w = 0;
    if (first_prefix_str.len > 0)
    {
        cur_line.append_slice(first_prefix_str);
        cur_w = strutils::string_display_width(first_prefix_str);
    }

    int cont_prefix_w = 0;
    if (prefix_str.len > 0)
    {
        cont_prefix_w = strutils::string_display_width(prefix_str);
    }

    for (usz s_idx = 0; s_idx < spans.len; s_idx++)
    {
        Span sp = spans[s_idx];

        char* style_start = "";
        char* style_end = "";
        if (!plain)
        {
            switch (sp.kind)
            {
                case SpanKind.BOLD: style_start = ansi::BOLD; style_end = ansi::RESET;
                case SpanKind.ITALIC: style_start = ansi::ITALIC; style_end = ansi::RESET;
                case SpanKind.STRIKETHROUGH: style_start = ansi::STRIKE; style_end = ansi::RESET;
                case SpanKind.CODE_INLINE: style_start = ansi::code_inline; style_end = ansi::RESET;
                case SpanKind.MATH_INLINE: style_start = ""; style_end = "";
                case SpanKind.FOOTNOTE_REF: style_start = ansi::fg_cyan; style_end = ansi::RESET;
                case SpanKind.LINK: style_start = ansi::fg_cyan; style_end = ansi::RESET;
                default: style_start = ""; style_end = "";
            }
        }

        String txt = sp.text;
        usz p = 0;
        usz tlen = (usz)txt.len;

        while (p < tlen)
        {
            while (p < tlen && (txt[p] == ' ' || txt[p] == '\t'))
            {
                p++;
            }
            if (p >= tlen) break;

            usz w_start = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n')
            {
                p++;
            }
            String word = txt[w_start : p - w_start];
            int word_w = strutils::string_display_width(word);

            if (cur_w + 1 + word_w > max_w && cur_w > (prefix_str.len > 0 ? cont_prefix_w : 0))
            {
                emit_fn(emit_ctx, cur_line.to_string(), src_line);
                cur_line.reset();
                if (prefix_str.len > 0)
                {
                    cur_line.append_slice(prefix_str);
                    cur_w = cont_prefix_w;
                }
                else
                {
                    cur_w = 0;
                }
            }
            else if (cur_w > (prefix_str.len > 0 ? cont_prefix_w : (first_prefix_str.len > 0 ? cont_prefix_w : 0)))
            {
                cur_line.append_char(' ');
                cur_w++;
            }

            if (style_start[0] != 0) cur_line.append_zstr(style_start);
            cur_line.append_slice(word);
            if (style_end[0] != 0) cur_line.append_zstr(style_end);
            cur_w += word_w;
        }

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int url_w = strutils::string_display_width(sp.url) + 3;
            if (cur_w + url_w > max_w && cur_w > cont_prefix_w)
            {
                emit_fn(emit_ctx, cur_line.to_string(), src_line);
                cur_line.reset();
                if (prefix_str.len > 0)
                {
                    cur_line.append_slice(prefix_str);
                    cur_w = cont_prefix_w;
                }
                else
                {
                    cur_w = 0;
                }
            }
            else
            {
                cur_line.append_char(' ');
                cur_w++;
            }
            if (!plain) cur_line.append_zstr(ansi::fg_muted);
            cur_line.append_char('(');
            cur_line.append_slice(sp.url);
            cur_line.append_char(')');
            if (!plain) cur_line.append_zstr(ansi::RESET);
            cur_w += url_w;
        }
    }

    if (cur_line.len > 0)
    {
        emit_fn(emit_ctx, cur_line.to_string(), src_line);
    }
}

fn VisualDocument render_document(Document* doc, RenderConfig config)
{
    VisualDocument vdoc;
    vdoc.init();

    DocRenderContext ctx;
    ctx.vdoc = &vdoc;
    ctx.arena = &vdoc.arena;
    ctx.config = config;
    ctx.list.init(mem, 256);

    buffer::ByteBuffer lb;
    lb.init(4096);
    defer lb.free();

    bool plain = config.plain;
    int width = config.width;
    if (width < 20) width = 80;

    for (usz b_idx = 0; b_idx < doc.blocks.len; b_idx++)
    {
        Block* b = &doc.blocks[b_idx];

        switch (b.kind)
        {
            case BlockKind.FRONTMATTER:
                int max_klen = 0;
                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    int klen = (int)b.frontmatter.entries[e].key.len;
                    if (klen > max_klen && klen <= 20) max_klen = klen;
                }
                if (max_klen < 5) max_klen = 5;

                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    FrontmatterEntry entry = b.frontmatter.entries[e];
                    int key_len = (int)entry.key.len;
                    int pad_spaces = max_klen - key_len;
                    if (pad_spaces < 0) pad_spaces = 0;

                    lb.reset();
                    if (!plain)
                    {
                        lb.append_zstr(ansi::fg_cyan);
                        lb.append_zstr(ansi::BOLD);
                    }
                    lb.append_slice(entry.key);
                    if (!plain) lb.append_zstr(ansi::RESET);
                    lb.append_zstr(":");
                    for (int s = 0; s < pad_spaces + 1; s++) lb.append_char(' ');

                    if (!plain) lb.append_zstr(ansi::fg_text);
                    lb.append_slice(entry.value);
                    if (!plain) lb.append_zstr(ansi::RESET);
                    emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start + 1 + (int)e);
                }

                // Divider line below metadata
                lb.reset();
                if (!plain) lb.append_zstr(ansi::fg_muted);
                int mbar_len = width > 20 ? width - 4 : 76;
                lb.append_repeat("─", mbar_len);
                if (!plain) lb.append_zstr(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_end);

            case BlockKind.FOOTNOTE_DEF:
                buffer::ByteBuffer fn_pfx;
                fn_pfx.init(64);
                defer fn_pfx.free();

                fn_pfx.append_zstr("  [");
                fn_pfx.append_slice(b.footnote_def.label);
                fn_pfx.append_zstr("] ");

                int fn_w = strutils::string_display_width(fn_pfx.to_string());
                buffer::ByteBuffer fn_cont;
                fn_cont.init(64);
                defer fn_cont.free();
                fn_cont.append_spaces(fn_w);

                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.footnote_def.spans, b.src_line_start, width - 4, fn_cont.to_string(), fn_pfx.to_string(), plain, config.no_wrap);

            case BlockKind.BLANK:
                emit_table_line_cb((void*)&ctx, "", b.src_line_start);

            case BlockKind.THEMATIC_BREAK:
                lb.reset();
                if (!plain) lb.append_zstr(ansi::fg_muted);
                int bar_len = width > 20 ? width - 4 : 76;
                lb.append_repeat("─", bar_len);
                if (!plain) lb.append_zstr(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start);

            case BlockKind.HEADING:
                if (b_idx > 0)
                {
                    emit_table_line_cb((void*)&ctx, "", b.src_line_start > 0 ? b.src_line_start - 1 : 0);
                }

                lb.reset();
                if (!plain)
                {
                    switch (b.heading.level)
                    {
                        case 1: lb.append_zstr(ansi::fg_h1);
                        case 2: lb.append_zstr(ansi::fg_h2);
                        case 3: lb.append_zstr(ansi::fg_h3);
                        case 4: lb.append_zstr(ansi::fg_h4);
                        case 5: lb.append_zstr(ansi::fg_h5);
                        default: lb.append_zstr(ansi::fg_h6);
                    }
                }
                else
                {
                    for (int k = 0; k < b.heading.level; k++) lb.append_char('#');
                    lb.append_char(' ');
                }

                render_spans(&lb, b.heading.spans, plain);
                if (!plain) lb.append_zstr(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start);

            case BlockKind.CODE_BLOCK:
                // Code block lines with exact indentation (zero leading padding for easy copy-paste)
                for (usz l = 0; l < b.code.lines.len; l++)
                {
                    lb.reset();
                    highlight_code_line(&lb, b.code.lines[l], b.code.language, plain);
                    emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start + (int)l);
                }

            case BlockKind.CALLOUT:
                // Title line
                lb.reset();
                if (!plain)
                {
                    logic::CalloutTheme theme = logic::get_callout_theme(b.callout.kind);
                    lb.append_zstr(theme.color);
                    lb.append_zstr(ansi::BOLD);
                    lb.append_zstr("│ ");
                    lb.append_slice(theme.icon);
                    lb.append_spaces(1);
                    lb.append_slice(theme.label);
                    lb.append_zstr(ansi::RESET);
                }
                else
                {
                    lb.append_zstr("| [!");
                    lb.append_slice(b.callout.title);
                    lb.append_zstr("]");
                }
                emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start);

                if (b.callout.spans.len > 0)
                {
                    render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.callout.spans, b.src_line_end, width - 6, "│ ", "│ ", plain, config.no_wrap);
                }

            case BlockKind.BLOCKQUOTE:
                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.blockquote.spans, b.src_line_start, width - 6, "│ ", "│ ", plain, config.no_wrap);

            case BlockKind.LIST_ITEM:
                buffer::ByteBuffer pfx_indent;
                pfx_indent.init(32);
                defer pfx_indent.free();
                pfx_indent.append_spaces(b.list_item.indent_level);

                buffer::ByteBuffer first_full;
                first_full.init(64);
                defer first_full.free();
                first_full.append_slice(pfx_indent.to_string());

                buffer::ByteBuffer cont_full;
                cont_full.init(64);
                defer cont_full.free();
                cont_full.append_slice(pfx_indent.to_string());

                switch (b.list_item.kind)
                {
                    case ListKind.TASK_UNCHECKED:
                        first_full.append_zstr("☐  ");
                        cont_full.append_zstr("   ");

                    case ListKind.TASK_CHECKED:
                        first_full.append_zstr("✔  ");
                        cont_full.append_zstr("   ");

                    case ListKind.ORDERED:
                        first_full.append_int(b.list_item.order_number);
                        first_full.append_zstr(". ");
                        int ord_w = strutils::string_display_width(first_full.to_string()) - b.list_item.indent_level;
                        cont_full.append_spaces(ord_w);

                    case ListKind.BULLET:
                        char* b_glyph = "• ";
                        if (b.list_item.indent_level >= 4)
                        {
                            b_glyph = "▪ ";
                        }
                        else if (b.list_item.indent_level >= 2)
                        {
                            b_glyph = "◦ ";
                        }
                        first_full.append_zstr(b_glyph);
                        cont_full.append_spaces(strutils::string_display_width((String)b_glyph[:strutils::str_len(b_glyph)]));

                    default:
                        first_full.append_zstr("• ");
                        cont_full.append_zstr("  ");
                }

                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.list_item.spans, b.src_line_start, width - 4, cont_full.to_string(), first_full.to_string(), plain, config.no_wrap);

            case BlockKind.TABLE:
                render_table(&b.table, b.src_line_start, width, plain, (void*)&ctx, &emit_table_line_cb);

            case BlockKind.MATH_BLOCK:
                MathBox mbox = math::render_latex_to_box(ctx.arena, b.math_block.latex);
                int pad_left = 4;

                emit_table_line_cb((void*)&ctx, "", b.src_line_start);

                for (int r = 0; r < mbox.height; r++)
                {
                    lb.reset();
                    lb.append_spaces(pad_left);
                    lb.append_slice(mbox.rows[r]);
                    emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start);
                }

                emit_table_line_cb((void*)&ctx, "", b.src_line_end);

            case BlockKind.IMAGE_BLOCK:
                lb.reset();
                lb.append_zstr("🖼  ");
                if (b.image_block.alt.len > 0)
                {
                    if (!plain)
                    {
                        lb.append_zstr(ansi::fg_cyan);
                        lb.append_zstr(ansi::BOLD);
                    }
                    lb.append_char('[');
                    lb.append_slice(b.image_block.alt);
                    lb.append_char(']');
                    if (!plain) lb.append_zstr(ansi::RESET);
                    lb.append_char(' ');
                }
                if (!plain) lb.append_zstr(ansi::fg_muted);
                lb.append_char('(');
                lb.append_slice(b.image_block.url);
                lb.append_char(')');
                if (!plain) lb.append_zstr(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.to_string(), b.src_line_start);

            case BlockKind.PARAGRAPH:
                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.paragraph.spans, b.src_line_start, width - 2, "", "", plain, config.no_wrap);
        }
    }

    if (ctx.list.size > 0)
    {
        VisualLine* v_buf = (VisualLine*)vdoc.arena.alloc((usz)ctx.list.size * VisualLine::size);
        for (sz i = 0; i < ctx.list.size; i++)
        {
            v_buf[i] = ctx.list.entries[i];
        }
        vdoc.lines = v_buf[:(usz)ctx.list.size];
    }
    else
    {
        vdoc.lines = {};
    }

    ctx.list.free();
    return vdoc;
}

fn void render_to_stdout(Document* doc, RenderConfig config)
{
    VisualDocument vdoc = render_document(doc, config);
    defer vdoc.free();

    for (usz i = 0; i < vdoc.lines.len; i++)
    {
        io::printn(vdoc.lines[i].text);
    }
}
