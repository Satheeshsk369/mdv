module parser;

import std::core::mem;
import std::collections::list;
import ast;
import tex;
import text;

struct HtmlEntityDef {
    String entity;
    String symbol;
}

const HtmlEntityDef[] HTML_ENTITIES = {
    { "&copy;", "©" },
    { "&trade;", "™" },
    { "&reg;", "®" },
    { "&mdash;", "—" },
    { "&ndash;", "–" },
    { "&hellip;", "…" },
    { "&amp;", "&" },
    { "&lt;", "<" },
    { "&gt;", ">" },
    { "&quot;", "\"" },
    { "&apos;", "'" },
    { "&plusmn;", "±" },
    { "&times;", "×" },
    { "&divide;", "÷" },
    { "&deg;", "°" },
    { "&infin;", "∞" },
    { "&ne;", "≠" },
    { "&le;", "≤" },
    { "&ge;", "≥" },
    { "&euro;", "€" },
    { "&pound;", "£" },
    { "&yen;", "¥" },
    { "&check;", "✔" },
    { "&cross;", "✗" },
    { "&bull;", "•" }
};

fn bool entity(String s, String* outSymbol, usz* outSkip)
{
    for (usz k = 0; k < HTML_ENTITIES.len; k++)
    {
        if (s.starts_with(HTML_ENTITIES[k].entity))
        {
            *outSymbol = HTML_ENTITIES[k].symbol;
            *outSkip = (usz)HTML_ENTITIES[k].entity.len;
            return true;
        }
    }
    return false;
}

fn bool alnum(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
}

fn Span[] keepSpans(ast::Arena* arena, List{Span}* l)
{
    if (l.size == 0) return {};
    Span* buf = (Span*)arena.alloc((usz)l.size * Span::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn void pushText(List{Span}* l, ast::Arena* arena, String text)
{
    if (text.len == 0) return;

    DString decoded;
    decoded.init(mem, (usz)(text.len + 32));
    defer decoded.free();

    usz i = 0;
    usz len = (usz)text.len;

    while (i < len)
    {
        if (text[i] == '&')
        {
            String symbol;
            usz skip = 0;
            if (entity(text[i..], &symbol, &skip))
            {
                decoded.append_string(symbol);
                i += skip;
                continue;
            }
        }

        decoded.append_char(text[i++]);
    }

    String finalStr = decoded.keep(arena);
    Span span = {};
    span.kind = SpanKind.TEXT;
    span.text = finalStr;
    span.url = "";
    span.children = {};
    l.push(span);
}

fn Span[] spans(ast::Arena* arena, String src)
{
    if (src.len == 0) return {};

    List{Span} l;
    l.init(mem, 16);
    defer l.free();

    usz i = 0;
    usz textStart = 0;
    usz len = (usz)src.len;

    while (i < len)
    {
        if (src[i] == '[' && i + 1 < len && src[i + 1] == '^')
        {
            usz fnEnd = i + 2;
            bool foundFn = false;
            while (fnEnd < len && src[fnEnd] != ' ' && src[fnEnd] != '\t' && src[fnEnd] != '\n')
            {
                if (src[fnEnd] == ']')
                {
                    foundFn = true;
                    break;
                }
                fnEnd++;
            }

            if (foundFn)
            {
                if (i > textStart)
                {
                    pushText(&l, arena, src[textStart : i - textStart]);
                }
                String label = src[i + 2 : fnEnd - (i + 2)];
                Span span = {};
                span.kind = SpanKind.FOOTNOTE_REF;
                span.text = arena.copy(label);
                span.url = "";
                span.children = {};
                l.push(span);

                i = fnEnd + 1;
                textStart = i;
                continue;
            }
        }

        if (src[i] == '!' && i + 1 < len && src[i + 1] == '[')
        {
            usz altStart = i + 2;
            usz altEnd = altStart;
            bool foundAlt = false;
            while (altEnd < len)
            {
                if (src[altEnd] == ']')
                {
                    foundAlt = true;
                    break;
                }
                altEnd++;
            }

            if (foundAlt && altEnd + 1 < len && src[altEnd + 1] == '(')
            {
                usz urlStart = altEnd + 2;
                usz urlEnd = urlStart;
                int pDepth = 1;
                bool foundUrl = false;

                while (urlEnd < len && pDepth > 0)
                {
                    if (src[urlEnd] == '(')
                    {
                        pDepth++;
                    }
                    else if (src[urlEnd] == ')')
                    {
                        pDepth--;
                        if (pDepth == 0)
                        {
                            foundUrl = true;
                            break;
                        }
                    }
                    urlEnd++;
                }

                if (foundUrl)
                {
                    if (i > textStart)
                    {
                        pushText(&l, arena, src[textStart : i - textStart]);
                    }
                    String altText = src[altStart : altEnd - altStart];
                    String urlText = src[urlStart : urlEnd - urlStart];

                    Span span = {};
                    span.kind = SpanKind.IMAGE;
                    span.text = arena.copy(altText);
                    span.url = arena.copy(urlText);
                    span.children = {};
                    l.push(span);

                    i = urlEnd + 1;
                    textStart = i;
                    continue;
                }
            }
        }

        if (src[i] == '[')
        {
            usz labelStart = i + 1;
            usz labelEnd = labelStart;
            bool foundLabel = false;
            while (labelEnd < len)
            {
                if (src[labelEnd] == ']')
                {
                    foundLabel = true;
                    break;
                }
                labelEnd++;
            }

            if (foundLabel && labelEnd + 1 < len && src[labelEnd + 1] == '(')
            {
                usz urlStart = labelEnd + 2;
                usz urlEnd = urlStart;
                int pDepth = 1;
                bool foundUrl = false;

                while (urlEnd < len && pDepth > 0)
                {
                    if (src[urlEnd] == '(')
                    {
                        pDepth++;
                    }
                    else if (src[urlEnd] == ')')
                    {
                        pDepth--;
                        if (pDepth == 0)
                        {
                            foundUrl = true;
                            break;
                        }
                    }
                    urlEnd++;
                }

                if (foundUrl)
                {
                    if (i > textStart)
                    {
                        pushText(&l, arena, src[textStart : i - textStart]);
                    }
                    String label = src[labelStart : labelEnd - labelStart];
                    String url = src[urlStart : urlEnd - urlStart];

                    Span span = {};
                    span.kind = SpanKind.LINK;
                    span.text = arena.copy(label);
                    span.url = arena.copy(url);
                    span.children = spans(arena, label);
                    l.push(span);

                    i = urlEnd + 1;
                    textStart = i;
                    continue;
                }
            }
        }

        if (src[i] == '$')
        {
            bool isDouble = (i + 1 < len && src[i + 1] == '$');
            usz mStart = isDouble ? i + 2 : i + 1;

            if (mStart < len && src[mStart] != ' ' && src[mStart] != '\t' && src[mStart] != '\r' && src[mStart] != '\n')
            {
                usz mEnd = mStart;
                bool found = false;

                while (mEnd < len)
                {
                    if (src[mEnd] == '$' && src[mEnd - 1] != ' ' && src[mEnd - 1] != '\t' && src[mEnd - 1] != '\\')
                    {
                        if (isDouble)
                        {
                            if (mEnd + 1 < len && src[mEnd + 1] == '$')
                            {
                                found = true;
                                break;
                            }
                        }
                        else
                        {
                            found = true;
                            break;
                        }
                    }
                    mEnd++;
                }

                if (found)
                {
                    if (i > textStart)
                    {
                        pushText(&l, arena, src[textStart : i - textStart]);
                    }
                    String rawMath = src[mStart : mEnd - mStart];
                    String transformed = tex::unicode(arena, rawMath);

                    Span span = {};
                    span.kind = isDouble ? SpanKind.MATH_DISPLAY : SpanKind.MATH_INLINE;
                    span.text = transformed;
                    span.url = "";
                    span.children = {};
                    l.push(span);

                    i = isDouble ? mEnd + 2 : mEnd + 1;
                    textStart = i;
                    continue;
                }
            }
        }

        if (src[i] == '`')
        {
            usz cEnd = i + 1;
            bool found = false;
            while (cEnd < len)
            {
                if (src[cEnd] == '`')
                {
                    found = true;
                    break;
                }
                cEnd++;
            }

            if (found)
            {
                if (i > textStart)
                {
                    pushText(&l, arena, src[textStart : i - textStart]);
                }
                String codeText = src[i + 1 : cEnd - (i + 1)];
                Span span = {};
                span.kind = SpanKind.CODE_INLINE;
                span.text = arena.copy(codeText);
                span.url = "";
                span.children = {};
                l.push(span);

                i = cEnd + 1;
                textStart = i;
                continue;
            }
        }

        if (i + 1 < len && ((src[i] == '*' && src[i + 1] == '*') || (src[i] == '_' && src[i + 1] == '_')))
        {
            char marker = src[i];
            bool validStart = true;
            if (marker == '_' && i > 0 && alnum(src[i - 1]))
            {
                validStart = false;
            }

            if (validStart)
            {
                usz bEnd = i + 2;
                bool found = false;
                while (bEnd + 1 < len)
                {
                    if (src[bEnd] == marker && src[bEnd + 1] == marker)
                    {
                        if (marker == '_' && bEnd + 2 < len && alnum(src[bEnd + 2]))
                        {
                            bEnd++;
                            continue;
                        }
                        found = true;
                        break;
                    }
                    bEnd++;
                }

                if (found)
                {
                    if (i > textStart)
                    {
                        pushText(&l, arena, src[textStart : i - textStart]);
                    }
                    String inner = src[i + 2 : bEnd - (i + 2)];
                    Span span = {};
                    span.kind = SpanKind.BOLD;
                    span.text = arena.copy(inner);
                    span.url = "";
                    span.children = spans(arena, inner);
                    l.push(span);

                    i = bEnd + 2;
                    textStart = i;
                    continue;
                }
            }
        }

        if (src[i] == '~' && i + 1 < len && src[i + 1] == '~')
        {
            usz sEnd = i + 2;
            bool found = false;
            while (sEnd + 1 < len)
            {
                if (src[sEnd] == '~' && src[sEnd + 1] == '~')
                {
                    found = true;
                    break;
                }
                sEnd++;
            }

            if (found)
            {
                if (i > textStart)
                {
                    pushText(&l, arena, src[textStart : i - textStart]);
                }
                String inner = src[i + 2 : sEnd - (i + 2)];
                Span span = {};
                span.kind = SpanKind.STRIKETHROUGH;
                span.text = arena.copy(inner);
                span.url = "";
                span.children = spans(arena, inner);
                l.push(span);

                i = sEnd + 2;
                textStart = i;
                continue;
            }
        }

        if ((src[i] == '*' || src[i] == '_') && i + 1 < len && src[i + 1] != ' ' && src[i + 1] != '\t')
        {
            char marker = src[i];
            bool validStart = true;
            if (marker == '_' && i > 0 && alnum(src[i - 1]))
            {
                validStart = false;
            }

            if (validStart)
            {
                usz itEnd = i + 1;
                bool found = false;
                while (itEnd < len)
                {
                    if (src[itEnd] == marker && (itEnd + 1 >= len || src[itEnd + 1] != marker))
                    {
                        if (marker == '_' && itEnd + 1 < len && alnum(src[itEnd + 1]))
                        {
                            itEnd++;
                            continue;
                        }
                        if (src[itEnd - 1] != ' ' && src[itEnd - 1] != '\t')
                        {
                            found = true;
                            break;
                        }
                    }
                    itEnd++;
                }

                if (found)
                {
                    if (i > textStart)
                    {
                        pushText(&l, arena, src[textStart : i - textStart]);
                    }
                    String inner = src[i + 1 : itEnd - (i + 1)];
                    Span span = {};
                    span.kind = SpanKind.ITALIC;
                    span.text = arena.copy(inner);
                    span.url = "";
                    span.children = spans(arena, inner);
                    l.push(span);

                    i = itEnd + 1;
                    textStart = i;
                    continue;
                }
            }
        }

        i++;
    }

    if (i > textStart)
    {
        pushText(&l, arena, src[textStart : i - textStart]);
    }

    return keepSpans(arena, &l);
}
