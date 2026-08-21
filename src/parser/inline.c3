module parser;

import std::core::mem;
import std::collections::list;
import logic;
import math;
import strutils;
import buffer;

fn bool is_alnum(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
}

fn Span[] list_to_arena_spans(logic::Arena* arena, List{Span}* l)
{
    if (l.size == 0) return {};
    Span* buf = (Span*)arena.alloc((usz)l.size * Span::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn void push_text_span(List{Span}* l, logic::Arena* arena, String text)
{
    if (text.len == 0) return;

    buffer::ByteBuffer decoded;
    decoded.init((usz)(text.len + 32));
    defer decoded.free();

    usz i = 0;
    usz len = (usz)text.len;

    while (i < len)
    {
        if (text[i] == '&')
        {
            String symbol;
            usz skip = 0;
            if (strutils::match_html_entity(text[i..], &symbol, &skip))
            {
                decoded.append_slice(symbol);
                i += skip;
                continue;
            }
        }

        decoded.append_char(text[i++]);
    }

    String final_str = decoded.to_arena_string(arena);
    Span span = {};
    span.kind = SpanKind.TEXT;
    span.text = final_str;
    span.url = "";
    span.children = {};
    l.push(span);
}

fn Span[] parse_inline(logic::Arena* arena, String src)
{
    if (src.len == 0) return {};

    List{Span} l;
    l.init(mem, 16);
    defer l.free();

    usz i = 0;
    usz text_start = 0;
    usz len = (usz)src.len;

    while (i < len)
    {
        // 1. Footnote Reference: [^label]
        if (src[i] == '[' && i + 1 < len && src[i + 1] == '^')
        {
            usz fn_end = i + 2;
            bool found_fn = false;
            while (fn_end < len && src[fn_end] != ' ' && src[fn_end] != '\t' && src[fn_end] != '\n')
            {
                if (src[fn_end] == ']')
                {
                    found_fn = true;
                    break;
                }
                fn_end++;
            }

            if (found_fn)
            {
                if (i > text_start)
                {
                    push_text_span(&l, arena, src[text_start : i - text_start]);
                }
                String label = src[i + 2 : fn_end - (i + 2)];
                Span span = {};
                span.kind = SpanKind.FOOTNOTE_REF;
                span.text = arena.dup_string(label);
                span.url = "";
                span.children = {};
                l.push(span);

                i = fn_end + 1;
                text_start = i;
                continue;
            }
        }

        // 2. Images: ![alt](url)
        if (src[i] == '!' && i + 1 < len && src[i + 1] == '[')
        {
            usz alt_start = i + 2;
            usz alt_end = alt_start;
            bool found_alt = false;
            while (alt_end < len)
            {
                if (src[alt_end] == ']')
                {
                    found_alt = true;
                    break;
                }
                alt_end++;
            }

            if (found_alt && alt_end + 1 < len && src[alt_end + 1] == '(')
            {
                usz url_start = alt_end + 2;
                usz url_end = url_start;
                int p_depth = 1;
                bool found_url = false;

                while (url_end < len && p_depth > 0)
                {
                    if (src[url_end] == '(')
                    {
                        p_depth++;
                    }
                    else if (src[url_end] == ')')
                    {
                        p_depth--;
                        if (p_depth == 0)
                        {
                            found_url = true;
                            break;
                        }
                    }
                    url_end++;
                }

                if (found_url)
                {
                    if (i > text_start)
                    {
                        push_text_span(&l, arena, src[text_start : i - text_start]);
                    }
                    String alt_text = src[alt_start : alt_end - alt_start];
                    String url_text = src[url_start : url_end - url_start];

                    Span span = {};
                    span.kind = SpanKind.IMAGE;
                    span.text = arena.dup_string(alt_text);
                    span.url = arena.dup_string(url_text);
                    span.children = {};
                    l.push(span);

                    i = url_end + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        // 3. Links: [label](url)
        if (src[i] == '[')
        {
            usz label_start = i + 1;
            usz label_end = label_start;
            bool found_label = false;
            while (label_end < len)
            {
                if (src[label_end] == ']')
                {
                    found_label = true;
                    break;
                }
                label_end++;
            }

            if (found_label && label_end + 1 < len && src[label_end + 1] == '(')
            {
                usz url_start = label_end + 2;
                usz url_end = url_start;
                int p_depth = 1;
                bool found_url = false;

                while (url_end < len && p_depth > 0)
                {
                    if (src[url_end] == '(')
                    {
                        p_depth++;
                    }
                    else if (src[url_end] == ')')
                    {
                        p_depth--;
                        if (p_depth == 0)
                        {
                            found_url = true;
                            break;
                        }
                    }
                    url_end++;
                }

                if (found_url)
                {
                    if (i > text_start)
                    {
                        push_text_span(&l, arena, src[text_start : i - text_start]);
                    }
                    String label = src[label_start : label_end - label_start];
                    String url = src[url_start : url_end - url_start];

                    Span span = {};
                    span.kind = SpanKind.LINK;
                    span.text = arena.dup_string(label);
                    span.url = arena.dup_string(url);
                    span.children = parse_inline(arena, label);
                    l.push(span);

                    i = url_end + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        // 4. Math: $...$ or $$...$$
        if (src[i] == '$')
        {
            bool is_double = (i + 1 < len && src[i + 1] == '$');
            usz m_start = is_double ? i + 2 : i + 1;

            if (m_start < len && src[m_start] != ' ' && src[m_start] != '\t' && src[m_start] != '\r' && src[m_start] != '\n')
            {
                usz m_end = m_start;
                bool found = false;

                while (m_end < len)
                {
                    if (src[m_end] == '$' && src[m_end - 1] != ' ' && src[m_end - 1] != '\t' && src[m_end - 1] != '\\')
                    {
                        if (is_double)
                        {
                            if (m_end + 1 < len && src[m_end + 1] == '$')
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
                    m_end++;
                }

                if (found)
                {
                    if (i > text_start)
                    {
                        push_text_span(&l, arena, src[text_start : i - text_start]);
                    }
                    String raw_math = src[m_start : m_end - m_start];
                    String transformed = math::transform_math(arena, raw_math);

                    Span span = {};
                    span.kind = is_double ? SpanKind.MATH_DISPLAY : SpanKind.MATH_INLINE;
                    span.text = transformed;
                    span.url = "";
                    span.children = {};
                    l.push(span);

                    i = is_double ? m_end + 2 : m_end + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        // 5. Inline Code: `...`
        if (src[i] == '`')
        {
            usz c_end = i + 1;
            bool found = false;
            while (c_end < len)
            {
                if (src[c_end] == '`')
                {
                    found = true;
                    break;
                }
                c_end++;
            }

            if (found)
            {
                if (i > text_start)
                {
                    push_text_span(&l, arena, src[text_start : i - text_start]);
                }
                String code_text = src[i + 1 : c_end - (i + 1)];
                Span span = {};
                span.kind = SpanKind.CODE_INLINE;
                span.text = arena.dup_string(code_text);
                span.url = "";
                span.children = {};
                l.push(span);

                i = c_end + 1;
                text_start = i;
                continue;
            }
        }

        // 6. Bold: **...** or __...__
        if (i + 1 < len && ((src[i] == '*' && src[i + 1] == '*') || (src[i] == '_' && src[i + 1] == '_')))
        {
            char marker = src[i];
            bool valid_start = true;
            if (marker == '_' && i > 0 && is_alnum(src[i - 1]))
            {
                valid_start = false;
            }

            if (valid_start)
            {
                usz b_end = i + 2;
                bool found = false;
                while (b_end + 1 < len)
                {
                    if (src[b_end] == marker && src[b_end + 1] == marker)
                    {
                        if (marker == '_' && b_end + 2 < len && is_alnum(src[b_end + 2]))
                        {
                            b_end++;
                            continue;
                        }
                        found = true;
                        break;
                    }
                    b_end++;
                }

                if (found)
                {
                    if (i > text_start)
                    {
                        push_text_span(&l, arena, src[text_start : i - text_start]);
                    }
                    String inner = src[i + 2 : b_end - (i + 2)];
                    Span span = {};
                    span.kind = SpanKind.BOLD;
                    span.text = arena.dup_string(inner);
                    span.url = "";
                    span.children = parse_inline(arena, inner);
                    l.push(span);

                    i = b_end + 2;
                    text_start = i;
                    continue;
                }
            }
        }

        // 7. Strikethrough: ~~...~~
        if (src[i] == '~' && i + 1 < len && src[i + 1] == '~')
        {
            usz s_end = i + 2;
            bool found = false;
            while (s_end + 1 < len)
            {
                if (src[s_end] == '~' && src[s_end + 1] == '~')
                {
                    found = true;
                    break;
                }
                s_end++;
            }

            if (found)
            {
                if (i > text_start)
                {
                    push_text_span(&l, arena, src[text_start : i - text_start]);
                }
                String inner = src[i + 2 : s_end - (i + 2)];
                Span span = {};
                span.kind = SpanKind.STRIKETHROUGH;
                span.text = arena.dup_string(inner);
                span.url = "";
                span.children = parse_inline(arena, inner);
                l.push(span);

                i = s_end + 2;
                text_start = i;
                continue;
            }
        }

        // 8. Italic: *...* or _..._
        if ((src[i] == '*' || src[i] == '_') && i + 1 < len && src[i + 1] != ' ' && src[i + 1] != '\t')
        {
            char marker = src[i];
            bool valid_start = true;
            if (marker == '_' && i > 0 && is_alnum(src[i - 1]))
            {
                valid_start = false;
            }

            if (valid_start)
            {
                usz it_end = i + 1;
                bool found = false;
                while (it_end < len)
                {
                    if (src[it_end] == marker && (it_end + 1 >= len || src[it_end + 1] != marker))
                    {
                        if (marker == '_' && it_end + 1 < len && is_alnum(src[it_end + 1]))
                        {
                            it_end++;
                            continue;
                        }
                        if (src[it_end - 1] != ' ' && src[it_end - 1] != '\t')
                        {
                            found = true;
                            break;
                        }
                    }
                    it_end++;
                }

                if (found)
                {
                    if (i > text_start)
                    {
                        push_text_span(&l, arena, src[text_start : i - text_start]);
                    }
                    String inner = src[i + 1 : it_end - (i + 1)];
                    Span span = {};
                    span.kind = SpanKind.ITALIC;
                    span.text = arena.dup_string(inner);
                    span.url = "";
                    span.children = parse_inline(arena, inner);
                    l.push(span);

                    i = it_end + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        i++;
    }

    if (i > text_start)
    {
        push_text_span(&l, arena, src[text_start : i - text_start]);
    }

    return list_to_arena_spans(arena, &l);
}
