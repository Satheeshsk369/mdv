module render;

import std::io;
import std::core::mem;
import std::collections::list;
import logic;
import ansi;
import math;
import std::math;
import text;

struct DocRenderContext {
    VisualDocument* vdoc;
    logic::Arena* arena;
    RenderConfig config;
    List{VisualLine} list;
}

struct Theme
{
    String icon;
    String label;
    String color;
}

const String[] STYLES = { "", ansi::BOLD, ansi::ITALIC, ansi::STRIKE, ansi::INLINE, "", "", ansi::CYAN, ansi::CYAN, "" };

const Theme[] THEMES = {
    { "ℹ", "NOTE", ansi::CYAN },
    { "💡", "TIP", ansi::GREEN },
    { "⚠", "WARNING", ansi::ORANGE },
    { "🔔", "IMPORTANT", ansi::PURPLE },
    { "⛔", "CAUTION", ansi::PINK },
};

struct Look
{
    String prefix;
    String open;
    String left;
    String right;
    String close;
    bool nested;
    bool url;
}

const Look[] LOOKS = {
    { "", "", "", "", "", false, false },
    { "", ansi::BOLD, "", "", ansi::RESET, true, false },
    { "", ansi::ITALIC, "", "", ansi::RESET, true, false },
    { "", ansi::STRIKE +++ ansi::MUTED, "", "", ansi::RESET, true, false },
    { "", ansi::INLINE +++ " ", "", "", " " +++ ansi::RESET, false, false },
    { "", "", "", "", "", false, false },
    { "", "", "", "", "", false, false },
    { "", ansi::CYAN +++ ansi::UNDERLINE, "", "", ansi::RESET, true, true },
    { "", ansi::CYAN +++ ansi::BOLD, "[", "]", ansi::RESET, false, false },
    { "🖼  ", ansi::CYAN +++ ansi::BOLD, "[", "]", ansi::RESET, false, true },
};

fn void render_span(DString* b, Span span, bool plain)
{
    Look look = LOOKS[span.kind];
    bool link = !plain && span.kind == SpanKind.LINK && span.url.len > 0;
    b.append(look.prefix);
    if (link)
    {
        b.append("\e]8;;");
        b.append(span.url);
        b.append("\e\\");
    }
    if (!plain) b.append(look.open);
    b.append(look.left);
    if (look.nested && span.children.len > 0)
    {
        render_spans(b, span.children, plain);
    }
    else
    {
        b.append(span.text);
    }
    b.append(look.right);
    if (!plain) b.append(look.close);
    if (link) b.append("\e]8;;\e\\");
    if (!look.url || span.url.len == 0) return;
    b.append_char(' ');
    if (!plain) b.append(ansi::MUTED);
    b.append_char('(');
    b.append(span.url);
    b.append_char(')');
    if (!plain) b.append(ansi::RESET);
}

fn void render_spans(DString* b, Span[] spans, bool plain)
{
    foreach (span : spans) render_span(b, span, plain);
}

fn void emit_table_line_cb(void* ctx_ptr, String text, int src_line)
{
    DocRenderContext* ctx = (DocRenderContext*)ctx_ptr;
    VisualLine vl;
    vl.text = ctx.arena.dup_string(text);
    vl.src_line = src_line;
    vl.display_width = text::width(text);
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
        DString lb;
        lb.init(mem, 4096);
        defer lb.free();
        if (first_prefix_str.len > 0) lb.append_string(first_prefix_str);
        render_spans(&lb, spans, plain);
        emit_fn(emit_ctx, lb.str_view(), src_line);
        return;
    }

    DString cur_line;
    cur_line.init(mem, 4096);
    defer cur_line.free();

    int cur_w = 0;
    if (first_prefix_str.len > 0)
    {
        cur_line.append_string(first_prefix_str);
        cur_w = text::width(first_prefix_str);
    }

    int cont_prefix_w = 0;
    if (prefix_str.len > 0)
    {
        cont_prefix_w = text::width(prefix_str);
    }

    for (usz s_idx = 0; s_idx < spans.len; s_idx++)
    {
        Span sp = spans[s_idx];

        String style = plain ? "" : STYLES[sp.kind];

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
            int word_w = text::width(word);

            if (cur_w + 1 + word_w > max_w && cur_w > (prefix_str.len > 0 ? cont_prefix_w : 0))
            {
                emit_fn(emit_ctx, cur_line.str_view(), src_line);
                cur_line.clear();
                if (prefix_str.len > 0)
                {
                    cur_line.append_string(prefix_str);
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

            cur_line.append(style);
            cur_line.append(word);
            if (style.len) cur_line.append(ansi::RESET);
            cur_w += word_w;
        }

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int url_w = text::width(sp.url) + 3;
            if (cur_w + url_w > max_w && cur_w > cont_prefix_w)
            {
                emit_fn(emit_ctx, cur_line.str_view(), src_line);
                cur_line.clear();
                if (prefix_str.len > 0)
                {
                    cur_line.append_string(prefix_str);
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
            if (!plain) cur_line.append(ansi::MUTED);
            cur_line.append_char('(');
            cur_line.append_string(sp.url);
            cur_line.append_char(')');
            if (!plain) cur_line.append(ansi::RESET);
            cur_w += url_w;
        }
    }

    if (cur_line.len() > 0)
    {
        emit_fn(emit_ctx, cur_line.str_view(), src_line);
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

    DString lb;
    lb.init(mem, 4096);
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

                    lb.clear();
                    if (!plain)
                    {
                        lb.append(ansi::CYAN);
                        lb.append(ansi::BOLD);
                    }
                    lb.append_string(entry.key);
                    if (!plain) lb.append(ansi::RESET);
                    lb.append(":");
                    for (int s = 0; s < pad_spaces + 1; s++) lb.append_char(' ');

                    if (!plain) lb.append(ansi::TEXT);
                    lb.append_string(entry.value);
                    if (!plain) lb.append(ansi::RESET);
                    emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start + 1 + (int)e);
                }

                // Divider line below metadata
                lb.clear();
                if (!plain) lb.append(ansi::MUTED);
                int mbar_len = width > 20 ? width - 4 : 76;
                lb.repeat("─", mbar_len);
                if (!plain) lb.append(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_end);

            case BlockKind.FOOTNOTE_DEF:
                DString fn_pfx;
                fn_pfx.init(mem, 64);
                defer fn_pfx.free();

                fn_pfx.append("  [");
                fn_pfx.append_string(b.footnote_def.label);
                fn_pfx.append("] ");

                int fn_w = text::width(fn_pfx.str_view());
                DString fn_cont;
                fn_cont.init(mem, 64);
                defer fn_cont.free();
                fn_cont.spaces(fn_w);

                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.footnote_def.spans, b.src_line_start, width - 4, fn_cont.str_view(), fn_pfx.str_view(), plain, config.no_wrap);

            case BlockKind.BLANK:
                emit_table_line_cb((void*)&ctx, "", b.src_line_start);

            case BlockKind.THEMATIC_BREAK:
                lb.clear();
                if (!plain) lb.append(ansi::MUTED);
                int bar_len = width > 20 ? width - 4 : 76;
                lb.repeat("─", bar_len);
                if (!plain) lb.append(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start);

            case BlockKind.HEADING:
                if (b_idx > 0)
                {
                    emit_table_line_cb((void*)&ctx, "", b.src_line_start > 0 ? b.src_line_start - 1 : 0);
                }

                lb.clear();
                if (!plain)
                {
                    lb.append(ansi::HEADINGS[std::math::clamp(b.heading.level, 1, 6) - 1]);
                }
                else
                {
                    for (int k = 0; k < b.heading.level; k++) lb.append_char('#');
                    lb.append_char(' ');
                }

                render_spans(&lb, b.heading.spans, plain);
                if (!plain) lb.append(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start);

            case BlockKind.CODE_BLOCK:
                // Code block lines with exact indentation (zero leading padding for easy copy-paste)
                for (usz l = 0; l < b.code.lines.len; l++)
                {
                    lb.clear();
                    highlight_code_line(&lb, b.code.lines[l], b.code.language, plain);
                    emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start + (int)l);
                }

            case BlockKind.CALLOUT:
                // Title line
                lb.clear();
                if (!plain)
                {
                    Theme theme = THEMES[b.callout.kind];
                    lb.append(theme.color);
                    lb.append(ansi::BOLD);
                    lb.append("│ ");
                    lb.append_string(theme.icon);
                    lb.spaces(1);
                    lb.append_string(theme.label);
                    lb.append(ansi::RESET);
                }
                else
                {
                    lb.append("| [!");
                    lb.append_string(b.callout.title);
                    lb.append("]");
                }
                emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start);

                if (b.callout.spans.len > 0)
                {
                    render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.callout.spans, b.src_line_end, width - 6, "│ ", "│ ", plain, config.no_wrap);
                }

            case BlockKind.BLOCKQUOTE:
                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.blockquote.spans, b.src_line_start, width - 6, "│ ", "│ ", plain, config.no_wrap);

            case BlockKind.LIST_ITEM:
                DString pfx_indent;
                pfx_indent.init(mem, 32);
                defer pfx_indent.free();
                pfx_indent.spaces(b.list_item.indent_level);

                DString first_full;
                first_full.init(mem, 64);
                defer first_full.free();
                first_full.append_string(pfx_indent.str_view());

                DString cont_full;
                cont_full.init(mem, 64);
                defer cont_full.free();
                cont_full.append_string(pfx_indent.str_view());

                switch (b.list_item.kind)
                {
                    case ListKind.TASK_UNCHECKED:
                        first_full.append("☐  ");
                        cont_full.append("   ");

                    case ListKind.TASK_CHECKED:
                        first_full.append("✔  ");
                        cont_full.append("   ");

                    case ListKind.ORDERED:
                        first_full.appendf("%d", b.list_item.order_number);
                        first_full.append(". ");
                        int ord_w = text::width(first_full.str_view()) - b.list_item.indent_level;
                        cont_full.spaces(ord_w);

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
                        first_full.zstr(b_glyph);
                        cont_full.spaces(text::width(((ZString)b_glyph).str_view()));

                    default:
                        first_full.append("• ");
                        cont_full.append("  ");
                }

                render_wrapped_spans((void*)&ctx, &emit_table_line_cb, b.list_item.spans, b.src_line_start, width - 4, cont_full.str_view(), first_full.str_view(), plain, config.no_wrap);

            case BlockKind.TABLE:
                render_table(&b.table, b.src_line_start, width, plain, (void*)&ctx, &emit_table_line_cb);

            case BlockKind.MATH_BLOCK:
                MathBox mbox = math::render_latex_to_box(ctx.arena, b.math_block.latex);
                int pad_left = 4;

                emit_table_line_cb((void*)&ctx, "", b.src_line_start);

                for (int r = 0; r < mbox.height; r++)
                {
                    lb.clear();
                    lb.spaces(pad_left);
                    lb.append_string(mbox.rows[r]);
                    emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start);
                }

                emit_table_line_cb((void*)&ctx, "", b.src_line_end);

            case BlockKind.IMAGE_BLOCK:
                lb.clear();
                lb.append("🖼  ");
                if (b.image_block.alt.len > 0)
                {
                    if (!plain)
                    {
                        lb.append(ansi::CYAN);
                        lb.append(ansi::BOLD);
                    }
                    lb.append_char('[');
                    lb.append_string(b.image_block.alt);
                    lb.append_char(']');
                    if (!plain) lb.append(ansi::RESET);
                    lb.append_char(' ');
                }
                if (!plain) lb.append(ansi::MUTED);
                lb.append_char('(');
                lb.append_string(b.image_block.url);
                lb.append_char(')');
                if (!plain) lb.append(ansi::RESET);
                emit_table_line_cb((void*)&ctx, lb.str_view(), b.src_line_start);

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
