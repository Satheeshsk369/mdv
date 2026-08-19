module parser;

import std::core::mem;
import ast;
import math;
import strutils;

struct SpanList {
    Span[] items;
    usz count;
    usz capacity;
}

fn void SpanList.init(SpanList* list, usz initial_cap = 16)
{
    list.items = mem::alloc_array(Span, (sz)initial_cap);
    list.count = 0;
    list.capacity = initial_cap;
}

fn void SpanList.push(SpanList* list, Span span)
{
    if (list.count >= list.capacity)
    {
        usz new_cap = list.capacity * 2;
        Span[] new_items = mem::alloc_array(Span, (sz)new_cap);
        for (usz i = 0; i < list.count; i++)
        {
            new_items[i] = list.items[i];
        }
        mem::free(list.items);
        list.items = new_items;
        list.capacity = new_cap;
    }
    list.items[list.count++] = span;
}

fn Span[] SpanList.to_arena_slice(SpanList* list, ast::Arena* arena)
{
    if (list.count == 0) return {};
    Span* buf = (Span*)arena.alloc(list.count * Span::size);
    for (usz i = 0; i < list.count; i++)
    {
        buf[i] = list.items[i];
    }
    return buf[:list.count];
}

fn void SpanList.free(SpanList* list)
{
    if (list.items.ptr != null)
    {
        mem::free(list.items);
        list.items = {};
        list.count = 0;
        list.capacity = 0;
    }
}

fn void push_text_span(SpanList* list, ast::Arena* arena, String text)
{
    if (text.len > 0)
    {
        Span span;
        span.kind = ast::SpanKind.TEXT;
        span.text = arena.dup_string(text);
        span.url = "";
        span.children = {};
        list.push(span);
    }
}

fn Span[] parse_inline(ast::Arena* arena, String src)
{
    if (src.len == 0) return {};

    SpanList list;
    list.init(16);
    defer list.free();

    usz i = 0;
    usz text_start = 0;

    while (i < (usz)src.len)
    {
        // 1. Math: $...$ or $$...$$
        if (src[i] == '$')
        {
            bool is_double = (i + 1 < (usz)src.len && src[i + 1] == '$');
            usz m_start = is_double ? i + 2 : i + 1;
            usz m_end = m_start;
            bool found = false;

            while (m_end < (usz)src.len)
            {
                if (src[m_end] == '$')
                {
                    if (is_double)
                    {
                        if (m_end + 1 < (usz)src.len && src[m_end + 1] == '$')
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
                    push_text_span(&list, arena, src[text_start:i]);
                }
                String raw_math = src[m_start:m_end];
                String transformed = math::transform_math(arena, raw_math);

                Span span;
                span.kind = is_double ? ast::SpanKind.MATH_DISPLAY : ast::SpanKind.MATH_INLINE;
                span.text = transformed;
                span.url = "";
                span.children = {};
                list.push(span);

                i = is_double ? m_end + 2 : m_end + 1;
                text_start = i;
                continue;
            }
        }

        // 2. Inline Code: `...`
        if (src[i] == '`')
        {
            usz c_end = i + 1;
            bool found = false;
            while (c_end < (usz)src.len)
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
                    push_text_span(&list, arena, src[text_start:i]);
                }
                String code_text = src[i + 1:c_end];
                Span span;
                span.kind = ast::SpanKind.CODE_INLINE;
                span.text = arena.dup_string(code_text);
                span.url = "";
                span.children = {};
                list.push(span);

                i = c_end + 1;
                text_start = i;
                continue;
            }
        }

        // 3. Bold: **...** or __...__
        if ((src[i] == '*' && i + 1 < (usz)src.len && src[i + 1] == '*') || (src[i] == '_' && i + 1 < (usz)src.len && src[i + 1] == '_'))
        {
            char marker = src[i];
            usz b_end = i + 2;
            bool found = false;
            while (b_end + 1 < (usz)src.len)
            {
                if (src[b_end] == marker && src[b_end + 1] == marker)
                {
                    found = true;
                    break;
                }
                b_end++;
            }

            if (found)
            {
                if (i > text_start)
                {
                    push_text_span(&list, arena, src[text_start:i]);
                }
                String inner = src[i + 2:b_end];
                Span span;
                span.kind = ast::SpanKind.BOLD;
                span.text = arena.dup_string(inner);
                span.url = "";
                span.children = parse_inline(arena, inner);
                list.push(span);

                i = b_end + 2;
                text_start = i;
                continue;
            }
        }

        // 4. Strikethrough: ~~...~~
        if (src[i] == '~' && i + 1 < (usz)src.len && src[i + 1] == '~')
        {
            usz s_end = i + 2;
            bool found = false;
            while (s_end + 1 < (usz)src.len)
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
                    push_text_span(&list, arena, src[text_start:i]);
                }
                String inner = src[i + 2:s_end];
                Span span;
                span.kind = ast::SpanKind.STRIKETHROUGH;
                span.text = arena.dup_string(inner);
                span.url = "";
                span.children = parse_inline(arena, inner);
                list.push(span);

                i = s_end + 2;
                text_start = i;
                continue;
            }
        }

        // 5. Italic: *...* or _..._
        if ((src[i] == '*' || src[i] == '_') && i + 1 < (usz)src.len && src[i + 1] != ' ')
        {
            char marker = src[i];
            usz it_end = i + 1;
            bool found = false;
            while (it_end < (usz)src.len)
            {
                if (src[it_end] == marker && (it_end + 1 >= (usz)src.len || src[it_end + 1] != marker))
                {
                    found = true;
                    break;
                }
                it_end++;
            }

            if (found)
            {
                if (i > text_start)
                {
                    push_text_span(&list, arena, src[text_start:i]);
                }
                String inner = src[i + 1:it_end];
                Span span;
                span.kind = ast::SpanKind.ITALIC;
                span.text = arena.dup_string(inner);
                span.url = "";
                span.children = parse_inline(arena, inner);
                list.push(span);

                i = it_end + 1;
                text_start = i;
                continue;
            }
        }

        // 6. Links: [label](url)
        if (src[i] == '[')
        {
            usz label_end = i + 1;
            bool found_label = false;
            while (label_end < (usz)src.len)
            {
                if (src[label_end] == ']')
                {
                    found_label = true;
                    break;
                }
                label_end++;
            }

            if (found_label && label_end + 1 < (usz)src.len && src[label_end + 1] == '(')
            {
                usz url_start = label_end + 2;
                usz url_end = url_start;
                bool found_url = false;
                while (url_end < (usz)src.len)
                {
                    if (src[url_end] == ')')
                    {
                        found_url = true;
                        break;
                    }
                    url_end++;
                }

                if (found_url)
                {
                    if (i > text_start)
                    {
                        push_text_span(&list, arena, src[text_start:i]);
                    }
                    String label = src[i + 1:label_end];
                    String url = src[url_start:url_end];

                    Span span;
                    span.kind = ast::SpanKind.LINK;
                    span.text = arena.dup_string(label);
                    span.url = arena.dup_string(url);
                    span.children = parse_inline(arena, label);
                    list.push(span);

                    i = url_end + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        i++;
    }

    if (i > text_start)
    {
        push_text_span(&list, arena, src[text_start:i]);
    }

    return list.to_arena_slice(arena);
}
