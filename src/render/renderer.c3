module render;

import std::io;
import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import layout;
import math;
import strutils;
import buffer;

struct RenderConfig {
    int width;
    bool plain;
    bool no_wrap;
}

struct CalloutTheme {
    String icon;
    String label;
    char* color;
}

const CalloutTheme[5] CALLOUT_THEMES = {
    { "ℹ", "NOTE", (char*)ansi::FG_CYAN },
    { "💡", "TIP", (char*)ansi::FG_GREEN },
    { "⚠", "WARNING", (char*)ansi::FG_ORANGE },
    { "📌", "IMPORTANT", (char*)ansi::FG_PURPLE },
    { "⛔", "CAUTION", (char*)ansi::FG_PINK }
};

struct DocRenderContext {
    layout::VisualDocument* vdoc;
    ast::Arena* arena;
    RenderConfig config;
    List{layout::VisualLine} list;
}

fn void render_span(buffer::ByteBuffer* b, ast::Span span, bool plain)
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

        case ast::SpanKind.FOOTNOTE_REF:
            if (!plain)
            {
                b.append_zstr((char*)ansi::FG_CYAN);
                b.append_zstr((char*)ansi::BOLD);
            }
            b.append_char('[');
            b.append_slice(span.text);
            b.append_char(']');
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

        case ast::SpanKind.IMAGE:
            if (!plain)
            {
                b.append_zstr((char*)ansi::FG_CYAN);
                b.append_zstr((char*)ansi::ITALIC);
            }
            b.append_zstr("🖼  [Image: ");
            b.append_slice(span.text);
            b.append_zstr("]");
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

fn void render_spans(buffer::ByteBuffer* b, ast::Span[] spans, bool plain)
{
    for (usz i = 0; i < spans.len; i++)
    {
        render_span(b, spans[i], plain);
    }
}

fn void emit_rendered_line(DocRenderContext* ctx, buffer::ByteBuffer* lb, int src_line)
{
    String s = lb.to_string();
    layout::VisualLine vl;
    vl.text = ctx.arena.dup_string(s);
    vl.src_line = src_line;
    vl.display_width = strutils::string_display_width(s);
    ctx.list.push(vl);
    lb.reset();
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

fn void render_wrapped_spans(
    DocRenderContext* ctx,
    ast::Span[] spans,
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
        buffer::ByteBuffer lb;
        lb.init(512);
        defer lb.free();
        if (first_prefix_str.len > 0) lb.append_slice(first_prefix_str);
        emit_rendered_line(ctx, &lb, src_line);
        return;
    }

    if (no_wrap || max_w <= 20)
    {
        buffer::ByteBuffer lb;
        lb.init(4096);
        defer lb.free();
        if (first_prefix_str.len > 0) lb.append_slice(first_prefix_str);
        render_spans(&lb, spans, plain);
        emit_rendered_line(ctx, &lb, src_line);
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
        ast::Span sp = spans[s_idx];

        char* style_start = "";
        char* style_end = "";
        if (!plain)
        {
            switch (sp.kind)
            {
                case ast::SpanKind.BOLD: style_start = (char*)ansi::BOLD; style_end = (char*)ansi::RESET;
                case ast::SpanKind.ITALIC: style_start = (char*)ansi::ITALIC; style_end = (char*)ansi::RESET;
                case ast::SpanKind.STRIKETHROUGH: style_start = (char*)ansi::STRIKE; style_end = (char*)ansi::RESET;
                case ast::SpanKind.CODE_INLINE: style_start = (char*)ansi::CODE_INLINE; style_end = (char*)ansi::RESET;
                case ast::SpanKind.MATH_INLINE: style_start = (char*)ansi::FG_MATH; style_end = (char*)ansi::RESET;
                case ast::SpanKind.FOOTNOTE_REF: style_start = (char*)ansi::FG_CYAN; style_end = (char*)ansi::RESET;
                case ast::SpanKind.LINK: style_start = (char*)ansi::FG_CYAN; style_end = (char*)ansi::RESET;
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
                emit_rendered_line(ctx, &cur_line, src_line);
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

        if (sp.kind == ast::SpanKind.LINK && sp.url.len > 0)
        {
            int url_w = strutils::string_display_width(sp.url) + 3;
            if (cur_w + url_w > max_w && cur_w > cont_prefix_w)
            {
                emit_rendered_line(ctx, &cur_line, src_line);
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
            if (!plain) cur_line.append_zstr((char*)ansi::FG_MUTED);
            cur_line.append_char('(');
            cur_line.append_slice(sp.url);
            cur_line.append_char(')');
            if (!plain) cur_line.append_zstr((char*)ansi::RESET);
            cur_w += url_w;
        }
    }

    if (cur_line.len > 0)
    {
        emit_rendered_line(ctx, &cur_line, src_line);
    }
}

fn layout::VisualDocument render_document(ast::Document* doc, RenderConfig config)
{
    layout::VisualDocument vdoc;
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
        ast::Block* b = &doc.blocks[b_idx];

        switch (b.kind)
        {
            case ast::BlockKind.FRONTMATTER:
                // Top border ╭── Document Info ──────────────────────────╮
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("╭── ");
                if (!plain)
                {
                    lb.append_zstr((char*)ansi::FG_CYAN);
                    lb.append_zstr((char*)ansi::BOLD);
                }
                lb.append_zstr("Document Metadata");
                if (!plain)
                {
                    lb.append_zstr((char*)ansi::RESET);
                    lb.append_zstr((char*)ansi::FG_MUTED);
                }
                lb.append_char(' ');
                int used_w = 4 + 17 + 1;
                int cbar_len = width - 4 - used_w;
                if (cbar_len < 4) cbar_len = 4;
                lb.append_repeat("─", cbar_len);
                lb.append_zstr("╮");
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Find max key length for clean alignment
                int max_klen = 0;
                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    int klen = (int)b.frontmatter.entries[e].key.len;
                    if (klen > max_klen && klen <= 20) max_klen = klen;
                }
                if (max_klen < 5) max_klen = 5;

                // Frontmatter entries with word wrapping
                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    ast::FrontmatterEntry entry = b.frontmatter.entries[e];
                    int key_len = (int)entry.key.len;
                    int pad_spaces = max_klen - key_len;
                    if (pad_spaces < 0) pad_spaces = 0;

                    // Build first line
                    lb.reset();
                    if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                    lb.append_zstr("│ ");
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::FG_YELLOW);
                        lb.append_zstr((char*)ansi::BOLD);
                    }
                    lb.append_slice(entry.key);
                    if (!plain) lb.append_zstr((char*)ansi::RESET);
                    lb.append_zstr(":");
                    for (int s = 0; s < pad_spaces + 1; s++) lb.append_char(' ');

                    int pfx_w = 2 + max_klen + 2; // "│ " + key (padded) + ": "
                    int cur_w = pfx_w;
                    int max_w = width - 4;
                    if (max_w < pfx_w + 10) max_w = pfx_w + 10;

                    String val = entry.value;
                    usz p = 0;
                    usz vlen = (usz)val.len;

                    if (config.no_wrap)
                    {
                        if (!plain) lb.append_zstr((char*)ansi::FG_TEXT);
                        lb.append_slice(val);
                        if (!plain) lb.append_zstr((char*)ansi::RESET);
                        emit_rendered_line(&ctx, &lb, b.src_line_start + 1 + (int)e);
                    }
                    else
                    {
                        while (p < vlen)
                        {
                            while (p < vlen && (val[p] == ' ' || val[p] == '\t')) p++;
                            if (p >= vlen) break;

                            usz w_start = p;
                            while (p < vlen && val[p] != ' ' && val[p] != '\t' && val[p] != '\n') p++;
                            String word = val[w_start : p - w_start];
                            int word_w = strutils::string_display_width(word);

                            if (cur_w + 1 + word_w > max_w && cur_w > pfx_w)
                            {
                                emit_rendered_line(&ctx, &lb, b.src_line_start + 1 + (int)e);
                                lb.reset();
                                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                                lb.append_zstr("│ ");
                                if (!plain) lb.append_zstr((char*)ansi::RESET);
                                for (int s = 0; s < max_klen + 2; s++) lb.append_char(' ');
                                cur_w = pfx_w;
                            }
                            else if (cur_w > pfx_w)
                            {
                                lb.append_char(' ');
                                cur_w++;
                            }

                            if (!plain) lb.append_zstr((char*)ansi::FG_TEXT);
                            lb.append_slice(word);
                            if (!plain) lb.append_zstr((char*)ansi::RESET);
                            cur_w += word_w;
                        }

                        emit_rendered_line(&ctx, &lb, b.src_line_start + 1 + (int)e);
                    }
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

            case ast::BlockKind.FOOTNOTE_DEF:
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

                render_wrapped_spans(&ctx, b.footnote_def.spans, b.src_line_start, width - 4, fn_cont.to_string(), fn_pfx.to_string(), plain, config.no_wrap);

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
                if (b_idx > 0)
                {
                    lb.reset();
                    emit_rendered_line(&ctx, &lb, b.src_line_start > 0 ? b.src_line_start - 1 : 0);
                }

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
                    if (!plain) lb.append_zstr((char*)ansi::RESET);
                    highlight_code_line(&lb, b.code.lines[l], b.code.language, plain);
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
                    CalloutTheme theme = CALLOUT_THEMES[(int)b.callout.kind];
                    lb.append_zstr(theme.color);
                    lb.append_zstr((char*)ansi::BOLD);
                    lb.append_zstr("│ ");
                    lb.append_slice(theme.icon);
                    lb.append_spaces(1);
                    lb.append_slice(theme.label);
                    lb.append_zstr((char*)ansi::RESET);
                }
                else
                {
                    lb.append_zstr("| [!");
                    lb.append_slice(b.callout.title);
                    lb.append_zstr("]");
                }
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Body lines
                if (b.callout.spans.len > 0)
                {
                    render_wrapped_spans(&ctx, b.callout.spans, b.src_line_end, width - 6, "│ ", "│ ", plain, config.no_wrap);
                }

            case ast::BlockKind.BLOCKQUOTE:
                render_wrapped_spans(&ctx, b.blockquote.spans, b.src_line_start, width - 6, "│ ", "│ ", plain, config.no_wrap);

            case ast::BlockKind.LIST_ITEM:
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
                    case ast::ListKind.TASK_UNCHECKED:
                        first_full.append_zstr("☐  ");
                        cont_full.append_zstr("   ");

                    case ast::ListKind.TASK_CHECKED:
                        first_full.append_zstr("✔  ");
                        cont_full.append_zstr("   ");

                    case ast::ListKind.ORDERED:
                        first_full.append_int(b.list_item.order_number);
                        first_full.append_zstr(". ");
                        int ord_w = strutils::string_display_width(first_full.to_string()) - b.list_item.indent_level;
                        cont_full.append_spaces(ord_w);

                    case ast::ListKind.BULLET:
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

                render_wrapped_spans(&ctx, b.list_item.spans, b.src_line_start, width - 4, cont_full.to_string(), first_full.to_string(), plain, config.no_wrap);

            case ast::BlockKind.TABLE:
                layout::render_table(&b.table, b.src_line_start, width, plain, (void*)&ctx, &emit_table_line_cb);

            case ast::BlockKind.MATH_BLOCK:
                math::MathBox mbox = math::render_latex_to_box(ctx.arena, b.math_block.latex);
                int pad_left = 4;

                lb.reset();
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                for (int r = 0; r < mbox.height; r++)
                {
                    lb.reset();
                    lb.append_spaces(pad_left);
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::FG_MATH);
                    }
                    lb.append_slice(mbox.rows[r]);
                    if (!plain)
                    {
                        lb.append_zstr((char*)ansi::RESET);
                    }
                    emit_rendered_line(&ctx, &lb, b.src_line_start);
                }

                lb.reset();
                emit_rendered_line(&ctx, &lb, b.src_line_end);

            case ast::BlockKind.IMAGE_BLOCK:
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("╭── ");
                if (!plain)
                {
                    lb.append_zstr((char*)ansi::FG_CYAN);
                    lb.append_zstr((char*)ansi::BOLD);
                }
                lb.append_zstr("Image");
                if (b.image_block.alt.len > 0)
                {
                    lb.append_zstr(": ");
                    lb.append_slice(b.image_block.alt);
                }
                if (!plain)
                {
                    lb.append_zstr((char*)ansi::RESET);
                    lb.append_zstr((char*)ansi::FG_MUTED);
                }
                lb.append_char(' ');
                int used_w = 4 + 6 + (b.image_block.alt.len > 0 ? (int)b.image_block.alt.len + 2 : 0) + 1;
                int cbar_len = width - 4 - used_w;
                if (cbar_len < 4) cbar_len = 4;
                lb.append_repeat("─", cbar_len);
                lb.append_zstr("╮");
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Body
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("│ ");
                if (!plain) lb.append_zstr((char*)ansi::FG_CYAN);
                lb.append_zstr("🖼  ");
                lb.append_slice(b.image_block.url);
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_start);

                // Bottom border
                if (!plain) lb.append_zstr((char*)ansi::FG_MUTED);
                lb.append_zstr("╰");
                int bbar_len = width - 6;
                if (bbar_len < 8) bbar_len = 8;
                lb.append_repeat("─", bbar_len);
                lb.append_zstr("╯");
                if (!plain) lb.append_zstr((char*)ansi::RESET);
                emit_rendered_line(&ctx, &lb, b.src_line_end);

            case ast::BlockKind.PARAGRAPH:
                render_wrapped_spans(&ctx, b.paragraph.spans, b.src_line_start, width - 2, "", "", plain, config.no_wrap);
        }
    }

    if (ctx.list.size > 0)
    {
        layout::VisualLine* v_buf = (layout::VisualLine*)vdoc.arena.alloc((usz)ctx.list.size * layout::VisualLine::size);
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

fn void render_to_stdout(ast::Document* doc, RenderConfig config)
{
    layout::VisualDocument vdoc = render_document(doc, config);
    defer vdoc.free();

    for (usz i = 0; i < vdoc.lines.len; i++)
    {
        io::printn(vdoc.lines[i].text);
    }
}
