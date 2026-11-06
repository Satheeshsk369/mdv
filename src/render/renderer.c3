module render;

import std::io;
import std::core::mem;
import std::collections::list;
import ast;
import ansi;
import tex;
import std::math;
import text;

struct DocRenderContext {
    VisualDocument* vdoc;
    ast::Arena* arena;
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

const String[] BULLETS = { "• ", "◦ ", "▪ " };

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

fn void renderSpan(DString* b, Span span, bool plain)
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
        renderSpans(b, span.children, plain);
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

fn void renderSpans(DString* b, Span[] spans, bool plain)
{
    foreach (span : spans) renderSpan(b, span, plain);
}

fn void emit(void* ctxPtr, String text, int srcLine)
{
    DocRenderContext* ctx = (DocRenderContext*)ctxPtr;
    VisualLine vl;
    vl.text = ctx.arena.copy(text);
    vl.srcLine = srcLine;
    vl.displayWidth = text::width(text);
    ctx.list.push(vl);
}

fn void wrap(
    void* emitCtx,
    EmitLineFn emitFn,
    Span[] spans,
    int srcLine,
    int maxW,
    String prefixStr,
    String firstPrefixStr,
    bool plain,
    bool noWrap
)
{
    if (spans.len == 0)
    {
        if (firstPrefixStr.len > 0)
        {
            emitFn(emitCtx, firstPrefixStr, srcLine);
        }
        return;
    }

    if (noWrap || maxW <= 20)
    {
        DString lb;
        lb.init(mem, 4096);
        defer lb.free();
        if (firstPrefixStr.len > 0) lb.append_string(firstPrefixStr);
        renderSpans(&lb, spans, plain);
        emitFn(emitCtx, lb.str_view(), srcLine);
        return;
    }

    DString curLine;
    curLine.init(mem, 4096);
    defer curLine.free();

    int curW = 0;
    if (firstPrefixStr.len > 0)
    {
        curLine.append_string(firstPrefixStr);
        curW = text::width(firstPrefixStr);
    }

    int contPrefixW = 0;
    if (prefixStr.len > 0)
    {
        contPrefixW = text::width(prefixStr);
    }

    for (usz sIdx = 0; sIdx < spans.len; sIdx++)
    {
        Span sp = spans[sIdx];

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

            usz wStart = p;
            while (p < tlen && txt[p] != ' ' && txt[p] != '\t' && txt[p] != '\n')
            {
                p++;
            }
            String word = txt[wStart : p - wStart];
            int wordW = text::width(word);

            if (curW + 1 + wordW > maxW && curW > (prefixStr.len > 0 ? contPrefixW : 0))
            {
                emitFn(emitCtx, curLine.str_view(), srcLine);
                curLine.clear();
                if (prefixStr.len > 0)
                {
                    curLine.append_string(prefixStr);
                    curW = contPrefixW;
                }
                else
                {
                    curW = 0;
                }
            }
            else if (curW > (prefixStr.len > 0 ? contPrefixW : (firstPrefixStr.len > 0 ? contPrefixW : 0)))
            {
                curLine.append_char(' ');
                curW++;
            }

            curLine.append(style);
            curLine.append(word);
            if (style.len) curLine.append(ansi::RESET);
            curW += wordW;
        }

        if (sp.kind == SpanKind.LINK && sp.url.len > 0)
        {
            int urlW = text::width(sp.url) + 3;
            if (curW + urlW > maxW && curW > contPrefixW)
            {
                emitFn(emitCtx, curLine.str_view(), srcLine);
                curLine.clear();
                if (prefixStr.len > 0)
                {
                    curLine.append_string(prefixStr);
                    curW = contPrefixW;
                }
                else
                {
                    curW = 0;
                }
            }
            else
            {
                curLine.append_char(' ');
                curW++;
            }
            if (!plain) curLine.append(ansi::MUTED);
            curLine.append_char('(');
            curLine.append_string(sp.url);
            curLine.append_char(')');
            if (!plain) curLine.append(ansi::RESET);
            curW += urlW;
        }
    }

    if (curLine.len() > 0)
    {
        emitFn(emitCtx, curLine.str_view(), srcLine);
    }
}

fn VisualDocument layout(Document* doc, RenderConfig config)
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

    for (usz bIdx = 0; bIdx < doc.blocks.len; bIdx++)
    {
        Block* b = &doc.blocks[bIdx];

        switch (b.kind)
        {
            case BlockKind.FRONTMATTER:
                int maxKlen = 0;
                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    int klen = (int)b.frontmatter.entries[e].key.len;
                    if (klen > maxKlen && klen <= 20) maxKlen = klen;
                }
                if (maxKlen < 5) maxKlen = 5;

                for (usz e = 0; e < b.frontmatter.entries.len; e++)
                {
                    FrontmatterEntry entry = b.frontmatter.entries[e];
                    int keyLen = (int)entry.key.len;
                    int padSpaces = maxKlen - keyLen;
                    if (padSpaces < 0) padSpaces = 0;

                    lb.clear();
                    if (!plain)
                    {
                        lb.append(ansi::CYAN);
                        lb.append(ansi::BOLD);
                    }
                    lb.append_string(entry.key);
                    if (!plain) lb.append(ansi::RESET);
                    lb.append(":");
                    for (int s = 0; s < padSpaces + 1; s++) lb.append_char(' ');

                    if (!plain) lb.append(ansi::TEXT);
                    lb.append_string(entry.value);
                    if (!plain) lb.append(ansi::RESET);
                    emit((void*)&ctx, lb.str_view(), b.srcLineStart + 1 + (int)e);
                }

                lb.clear();
                if (!plain) lb.append(ansi::MUTED);
                int mbarLen = width > 20 ? width - 4 : 76;
                lb.repeat("─", mbarLen);
                if (!plain) lb.append(ansi::RESET);
                emit((void*)&ctx, lb.str_view(), b.srcLineEnd);

            case BlockKind.FOOTNOTE_DEF:
                DString fnPfx;
                fnPfx.init(mem, 64);
                defer fnPfx.free();

                fnPfx.append("  [");
                fnPfx.append_string(b.footnoteDef.label);
                fnPfx.append("] ");

                int fnW = text::width(fnPfx.str_view());
                DString fnCont;
                fnCont.init(mem, 64);
                defer fnCont.free();
                fnCont.spaces(fnW);

                wrap((void*)&ctx, &emit, b.footnoteDef.spans, b.srcLineStart, width - 4, fnCont.str_view(), fnPfx.str_view(), plain, config.noWrap);

            case BlockKind.BLANK:
                emit((void*)&ctx, "", b.srcLineStart);

            case BlockKind.THEMATIC_BREAK:
                lb.clear();
                if (!plain) lb.append(ansi::MUTED);
                int barLen = width > 20 ? width - 4 : 76;
                lb.repeat("─", barLen);
                if (!plain) lb.append(ansi::RESET);
                emit((void*)&ctx, lb.str_view(), b.srcLineStart);

            case BlockKind.HEADING:
                if (bIdx > 0)
                {
                    emit((void*)&ctx, "", b.srcLineStart > 0 ? b.srcLineStart - 1 : 0);
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

                renderSpans(&lb, b.heading.spans, plain);
                if (!plain) lb.append(ansi::RESET);
                emit((void*)&ctx, lb.str_view(), b.srcLineStart);

            case BlockKind.CODE_BLOCK:
                for (usz l = 0; l < b.code.lines.len; l++)
                {
                    lb.clear();
                    highlight(&lb, b.code.lines[l], b.code.language, plain);
                    emit((void*)&ctx, lb.str_view(), b.srcLineStart + (int)l);
                }

            case BlockKind.CALLOUT:
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
                emit((void*)&ctx, lb.str_view(), b.srcLineStart);

                if (b.callout.spans.len > 0)
                {
                    wrap((void*)&ctx, &emit, b.callout.spans, b.srcLineEnd, width - 6, "│ ", "│ ", plain, config.noWrap);
                }

            case BlockKind.BLOCKQUOTE:
                wrap((void*)&ctx, &emit, b.blockquote.spans, b.srcLineStart, width - 6, "│ ", "│ ", plain, config.noWrap);

            case BlockKind.LIST_ITEM:
                DString pfxIndent;
                pfxIndent.init(mem, 32);
                defer pfxIndent.free();
                pfxIndent.spaces(b.listItem.indentLevel);

                DString firstFull;
                firstFull.init(mem, 64);
                defer firstFull.free();
                firstFull.append_string(pfxIndent.str_view());

                DString contFull;
                contFull.init(mem, 64);
                defer contFull.free();
                contFull.append_string(pfxIndent.str_view());

                switch (b.listItem.kind)
                {
                    case ListKind.TASK_UNCHECKED:
                        firstFull.append("☐  ");
                        contFull.append("   ");

                    case ListKind.TASK_CHECKED:
                        firstFull.append("✔  ");
                        contFull.append("   ");

                    case ListKind.ORDERED:
                        firstFull.appendf("%d", b.listItem.orderNumber);
                        firstFull.append(". ");
                        int ordW = text::width(firstFull.str_view()) - b.listItem.indentLevel;
                        contFull.spaces(ordW);

                    case ListKind.BULLET:
                        String bullet = BULLETS[min(b.listItem.indentLevel / 2, 2)];
                        firstFull.append(bullet);
                        contFull.spaces(text::width(bullet));

                    default:
                        firstFull.append("• ");
                        contFull.append("  ");
                }

                wrap((void*)&ctx, &emit, b.listItem.spans, b.srcLineStart, width - 4, contFull.str_view(), firstFull.str_view(), plain, config.noWrap);

            case BlockKind.TABLE:
                table(&b.table, b.srcLineStart, width, plain, (void*)&ctx, &emit);

            case BlockKind.MATH_BLOCK:
                MathBox mbox = tex::latex(ctx.arena, b.mathBlock.latex);
                int padLeft = 4;

                emit((void*)&ctx, "", b.srcLineStart);

                for (int r = 0; r < mbox.height; r++)
                {
                    lb.clear();
                    lb.spaces(padLeft);
                    lb.append_string(mbox.rows[r]);
                    emit((void*)&ctx, lb.str_view(), b.srcLineStart);
                }

                emit((void*)&ctx, "", b.srcLineEnd);

            case BlockKind.IMAGE_BLOCK:
                lb.clear();
                lb.append("🖼  ");
                if (b.imageBlock.alt.len > 0)
                {
                    if (!plain)
                    {
                        lb.append(ansi::CYAN);
                        lb.append(ansi::BOLD);
                    }
                    lb.append_char('[');
                    lb.append_string(b.imageBlock.alt);
                    lb.append_char(']');
                    if (!plain) lb.append(ansi::RESET);
                    lb.append_char(' ');
                }
                if (!plain) lb.append(ansi::MUTED);
                lb.append_char('(');
                lb.append_string(b.imageBlock.url);
                lb.append_char(')');
                if (!plain) lb.append(ansi::RESET);
                emit((void*)&ctx, lb.str_view(), b.srcLineStart);

            case BlockKind.PARAGRAPH:
                wrap((void*)&ctx, &emit, b.paragraph.spans, b.srcLineStart, width - 2, "", "", plain, config.noWrap);
        }
    }

    if (ctx.list.size > 0)
    {
        VisualLine* vBuf = (VisualLine*)vdoc.arena.alloc((usz)ctx.list.size * VisualLine::size);
        for (sz i = 0; i < ctx.list.size; i++)
        {
            vBuf[i] = ctx.list.entries[i];
        }
        vdoc.lines = vBuf[:(usz)ctx.list.size];
    }
    else
    {
        vdoc.lines = {};
    }

    ctx.list.free();
    return vdoc;
}

fn void print(Document* doc, RenderConfig config)
{
    VisualDocument vdoc = layout(doc, config);
    defer vdoc.free();

    for (usz i = 0; i < vdoc.lines.len; i++)
    {
        io::printn(vdoc.lines[i].text);
    }
}
