module strutils;

import std::io;
import std::core::mem;

fn int str_len(char* str)
{
    if (str == null) return 0;
    int len = 0;
    while (str[len] != 0) len++;
    return len;
}

fn void copy_str(char* dest, char* src, int max_len)
{
    if (dest == null || max_len <= 0) return;
    if (src == null) { dest[0] = 0; return; }
    int i = 0;
    while (src[i] != 0 && i < max_len - 1)
    {
        dest[i] = src[i];
        i++;
    }
    dest[i] = 0;
}

fn void append_str(char* dest, char* src, int max_len)
{
    if (dest == null || src == null || max_len <= 0) return;
    int d = str_len(dest);
    int s = 0;
    while (src[s] != 0 && d < max_len - 1)
    {
        dest[d++] = src[s++];
    }
    dest[d] = 0;
}

fn void int_to_str(int val, char* out_buf, int max_len)
{
    if (out_buf == null || max_len < 2) return;
    if (val == 0)
    {
        out_buf[0] = '0';
        out_buf[1] = 0;
        return;
    }

    char[32] temp;
    int t_pos = 0;
    int n = val;
    bool neg = false;
    if (n < 0)
    {
        neg = true;
        n = -n;
    }

    while (n > 0 && t_pos < 30)
    {
        temp[t_pos++] = (char)('0' + (n % 10));
        n /= 10;
    }

    int o_pos = 0;
    if (neg && o_pos < max_len - 1)
    {
        out_buf[o_pos++] = '-';
    }

    while (t_pos > 0 && o_pos < max_len - 1)
    {
        t_pos--;
        out_buf[o_pos++] = temp[t_pos];
    }
    out_buf[o_pos] = 0;
}

fn bool str_starts_with(char* str, char* prefix)
{
    if (str == null || prefix == null) return false;
    int i = 0;
    while (prefix[i] != 0)
    {
        if (str[i] != prefix[i]) return false;
        i++;
    }
    return true;
}

fn bool str_ends_with(char* str, char* suffix)
{
    if (str == null || suffix == null) return false;
    int slen = str_len(str);
    int suflen = str_len(suffix);
    if (suflen > slen) return false;
    int p = slen - suflen;
    int k = 0;
    while (k < suflen)
    {
        if (str[p + k] != suffix[k]) return false;
        k++;
    }
    return true;
}

fn bool str_eq(char* a, char* b)
{
    if (a == null || b == null) return a == b;
    int i = 0;
    while (a[i] != 0 && b[i] != 0)
    {
        if (a[i] != b[i]) return false;
        i++;
    }
    return a[i] == 0 && b[i] == 0;
}

fn bool string_eq(String a, String b)
{
    if (a.len != b.len) return false;
    for (sz i = 0; i < (sz)a.len; i++)
    {
        if (a[i] != b[i]) return false;
    }
    return true;
}

fn bool string_starts_with(String str, String prefix)
{
    if (str.len < prefix.len) return false;
    for (sz i = 0; i < (sz)prefix.len; i++)
    {
        if (str[i] != prefix[i]) return false;
    }
    return true;
}

fn bool string_ends_with(String str, String suffix)
{
    if (str.len < suffix.len) return false;
    sz offset = (sz)(str.len - suffix.len);
    for (sz i = 0; i < (sz)suffix.len; i++)
    {
        if (str[offset + i] != suffix[i]) return false;
    }
    return true;
}

fn String string_trim(String src)
{
    if (src.len == 0) return src;
    sz start = 0;
    while (start < (sz)src.len && (src[start] == ' ' || src[start] == '\t' || src[start] == '\r' || src[start] == '\n'))
    {
        start++;
    }
    sz end = (sz)src.len;
    while (end > start && (src[end - 1] == ' ' || src[end - 1] == '\t' || src[end - 1] == '\r' || src[end - 1] == '\n'))
    {
        end--;
    }
    return src[start : end - start];
}

fn int codepoint_display_width(uint cp)
{
    // Control characters & null
    if (cp < 0x20 || (cp >= 0x7F && cp < 0xA0)) return 0;
    // Standard ASCII
    if (cp < 0x7F) return 1;

    // Combining diacritical marks & non-spacing marks (width 0)
    if ((cp >= 0x0300 && cp <= 0x036F) ||
        (cp >= 0x0483 && cp <= 0x0489) ||
        (cp >= 0x0591 && cp <= 0x05BD) ||
        (cp == 0x05BF) || (cp >= 0x05C1 && cp <= 0x05C2) || (cp >= 0x05C4 && cp <= 0x05C5) || (cp == 0x05C7) ||
        (cp >= 0x0610 && cp <= 0x061A) || (cp >= 0x064B && cp <= 0x065F) || (cp == 0x0670) ||
        (cp == 0x0711) || (cp >= 0x0730 && cp <= 0x074A) ||
        (cp >= 0x1AB0 && cp <= 0x1AFF) ||
        (cp >= 0x1DC0 && cp <= 0x1DFF) ||
        (cp >= 0x20D0 && cp <= 0x20FF) ||
        (cp >= 0xFE20 && cp <= 0xFE2F) ||
        (cp >= 0xFE00 && cp <= 0xFE0F) || // Variation selectors
        (cp >= 0x200B && cp <= 0x200F) || // ZWSP, ZWNJ, ZWJ, LRM, RLM
        (cp >= 0x202A && cp <= 0x202E) || // BiDi controls
        (cp >= 0x2060 && cp <= 0x206F) || // Invisible formatting
        (cp == 0xFEFF))                    // Byte order mark
    {
        return 0;
    }

    // Mathematical Alphanumeric Symbols in Plane 1 (Double-struck, Script, Fraktur, Bold math letters)
    if (cp >= 0x1D400 && cp <= 0x1D7FF) return 1;

    // Wide Emojis, Symbols, and CJK Ideographs (width 2)
    if ((cp >= 0x1100 && cp <= 0x115F) ||
        (cp >= 0x2E80 && cp <= 0xA4CF && cp != 0x303F) ||
        (cp >= 0xAC00 && cp <= 0xD7A3) ||
        (cp >= 0xF900 && cp <= 0xFAFF) ||
        (cp >= 0xFE10 && cp <= 0xFE19) ||
        (cp >= 0xFE30 && cp <= 0xFE6F) ||
        (cp >= 0xFF01 && cp <= 0xFF60) ||
        (cp >= 0xFFE0 && cp <= 0xFFE6) ||
        (cp >= 0x1F000 && cp <= 0x1FAFF) ||
        (cp >= 0x20000 && cp <= 0x3FFFF))
    {
        return 2;
    }

    return 1;
}

fn int utf8_display_width(char* s)
{
    if (s == null) return 0;
    int i = 0;
    int width = 0;
    while (s[i] != 0)
    {
        // Skip ANSI escape sequence
        if (s[i] == 0x1b && s[i+1] == '[')
        {
            i += 2;
            while (s[i] != 0 && !((s[i] >= 'a' && s[i] <= 'z') || (s[i] >= 'A' && s[i] <= 'Z')))
            {
                i++;
            }
            if (s[i] != 0) i++;
            continue;
        }

        uint c = (uint)s[i];
        if (c < 0x80)
        {
            width += codepoint_display_width(c);
            i++;
        }
        else if ((c & 0xe0) == 0xc0)
        {
            uint cp = (c & 0x1f) << 6;
            if (s[i+1] != 0) cp |= ((uint)s[i+1] & 0x3f);
            width += codepoint_display_width(cp);
            i += (s[i+1] != 0) ? 2 : 1;
        }
        else if ((c & 0xf0) == 0xe0)
        {
            uint cp = (c & 0x0f) << 12;
            if (s[i+1] != 0) cp |= ((uint)s[i+1] & 0x3f) << 6;
            if (s[i+1] != 0 && s[i+2] != 0) cp |= ((uint)s[i+2] & 0x3f);
            width += codepoint_display_width(cp);
            i += (s[i+1] != 0 && s[i+2] != 0) ? 3 : (s[i+1] != 0 ? 2 : 1);
        }
        else if ((c & 0xf8) == 0xf0)
        {
            uint cp = (c & 0x07) << 18;
            if (s[i+1] != 0) cp |= ((uint)s[i+1] & 0x3f) << 12;
            if (s[i+1] != 0 && s[i+2] != 0) cp |= ((uint)s[i+2] & 0x3f) << 6;
            if (s[i+1] != 0 && s[i+2] != 0 && s[i+3] != 0) cp |= ((uint)s[i+3] & 0x3f);
            width += codepoint_display_width(cp);
            int step = 1;
            if (s[i+1] != 0) step++;
            if (step == 2 && s[i+2] != 0) step++;
            if (step == 3 && s[i+3] != 0) step++;
            i += step;
        }
        else
        {
            i++;
        }
    }
    return width;
}

fn int string_display_width(String s)
{
    if (s.len == 0) return 0;
    sz i = 0;
    int width = 0;
    while (i < (sz)s.len)
    {
        // Skip ANSI escape sequence
        if (s[i] == 0x1b && i + 1 < (sz)s.len && s[i+1] == '[')
        {
            i += 2;
            while (i < (sz)s.len && !((s[i] >= 'a' && s[i] <= 'z') || (s[i] >= 'A' && s[i] <= 'Z')))
            {
                i++;
            }
            if (i < (sz)s.len) i++;
            continue;
        }

        uint c = (uint)s[i];
        if (c < 0x80)
        {
            width += codepoint_display_width(c);
            i++;
        }
        else if ((c & 0xe0) == 0xc0)
        {
            uint cp = (c & 0x1f) << 6;
            if (i + 1 < (sz)s.len) cp |= ((uint)s[i+1] & 0x3f);
            width += codepoint_display_width(cp);
            i += (i + 1 < (sz)s.len) ? 2 : 1;
        }
        else if ((c & 0xf0) == 0xe0)
        {
            uint cp = (c & 0x0f) << 12;
            if (i + 1 < (sz)s.len) cp |= ((uint)s[i+1] & 0x3f) << 6;
            if (i + 2 < (sz)s.len) cp |= ((uint)s[i+2] & 0x3f);
            width += codepoint_display_width(cp);
            i += (i + 2 < (sz)s.len) ? 3 : ((i + 1 < (sz)s.len) ? 2 : 1);
        }
        else if ((c & 0xf8) == 0xf0)
        {
            uint cp = (c & 0x07) << 18;
            if (i + 1 < (sz)s.len) cp |= ((uint)s[i+1] & 0x3f) << 12;
            if (i + 2 < (sz)s.len) cp |= ((uint)s[i+2] & 0x3f) << 6;
            if (i + 3 < (sz)s.len) cp |= ((uint)s[i+3] & 0x3f);
            width += codepoint_display_width(cp);
            sz step = 1;
            if (i + 1 < (sz)s.len) step++;
            if (step == 2 && i + 2 < (sz)s.len) step++;
            if (step == 3 && i + 3 < (sz)s.len) step++;
            i += step;
        }
        else
        {
            i++;
        }
    }
    return width;
}

fn bool string_contains(String haystack, String needle)
{
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    usz max_i = (usz)(haystack.len - needle.len);
    for (usz i = 0; i <= max_i; i++)
    {
        bool match = true;
        for (usz j = 0; j < (usz)needle.len; j++)
        {
            if (haystack[i + j] != needle[j])
            {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn bool string_contains_case_insensitive(String haystack, String needle)
{
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    usz max_i = (usz)(haystack.len - needle.len);
    for (usz i = 0; i <= max_i; i++)
    {
        bool match = true;
        for (usz j = 0; j < (usz)needle.len; j++)
        {
            char h = haystack[i + j];
            char n = needle[j];
            if (h >= 'A' && h <= 'Z') h = (char)(h + 32);
            if (n >= 'A' && n <= 'Z') n = (char)(n + 32);
            if (h != n)
            {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn int find_first_diff_line(char* old_text, char* new_text)
{
    if (old_text == null || new_text == null) return 0;
    
    int o = 0;
    int n = 0;
    int line_idx = 0;

    while (old_text[o] != 0 && new_text[n] != 0)
    {
        int o_start = o;
        while (old_text[o] != 0 && old_text[o] != '\n') o++;
        int o_len = o - o_start;
        if (old_text[o] == '\n') o++;

        int n_start = n;
        while (new_text[n] != 0 && new_text[n] != '\n') n++;
        int n_len = n - n_start;
        if (new_text[n] == '\n') n++;

        if (o_len > 0 && old_text[o_start + o_len - 1] == '\r') o_len--;
        if (n_len > 0 && new_text[n_start + n_len - 1] == '\r') n_len--;

        if (o_len != n_len) return line_idx;

        for (int k = 0; k < o_len; k++)
        {
            if (old_text[o_start + k] != new_text[n_start + k]) return line_idx;
        }

        line_idx++;
    }

    if (old_text[o] != 0 || new_text[n] != 0)
    {
        return line_idx;
    }

    return -1;
}

fn bool is_numeric(char* s)
{
    if (s == null || s[0] == 0) return false;
    int i = 0;
    if (s[0] == '+') i = 1;
    if (s[i] == 0) return false;
    while (s[i] != 0)
    {
        if (s[i] < '0' || s[i] > '9') return false;
        i++;
    }
    return true;
}

fn int parse_int(char* s)
{
    if (s == null) return 0;
    int i = 0;
    while (s[i] == ' ' || s[i] == '\t' || s[i] == ':') i++;
    if (s[i] == '+') i++;
    int val = 0;
    while (s[i] >= '0' && s[i] <= '9')
    {
        val = val * 10 + (int)(s[i] - '0');
        i++;
    }
    return val;
}

fn char* load_file_string(char* filename)
{
    int flen = str_len(filename);
    String fname_str = (String)filename[:flen];
    char[]? data = io::file::load(tmem, fname_str);
    if (catch err = data)
    {
        return null;
    }

    char* str_ptr = (char*)data.ptr;
    sz len = (sz)data.len;
    char[] buf = mem::alloc_array(char, len + 1);
    for (sz i = 0; i < len; i++) buf[i] = str_ptr[i];
    buf[len] = 0;
    return (char*)buf.ptr;
}

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

fn bool match_html_entity(String s, String* out_symbol, usz* out_skip)
{
    for (usz k = 0; k < HTML_ENTITIES.len; k++)
    {
        if (string_starts_with(s, HTML_ENTITIES[k].entity))
        {
            *out_symbol = HTML_ENTITIES[k].symbol;
            *out_skip = (usz)HTML_ENTITIES[k].entity.len;
            return true;
        }
    }
    return false;
}

fn void slugify(String in_str, char* out_buf, usz max_len)
{
    if (out_buf == null || max_len == 0) return;
    usz out_p = 0;
    usz len = (usz)in_str.len;
    bool last_was_dash = true; // avoid leading dashes

    for (usz i = 0; i < len && out_p < max_len - 1; i++)
    {
        char c = in_str[i];
        if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
        {
            out_buf[out_p++] = c;
            last_was_dash = false;
        }
        else if (c >= 'A' && c <= 'Z')
        {
            out_buf[out_p++] = (char)(c + 32); // lowercase
            last_was_dash = false;
        }
        else if (c == ' ' || c == '-' || c == '_' || c == '.' || c == '/' || c == ':' || c == '&' || c == '(' || c == ')' || c == ',' || c == '\'' || c == '"')
        {
            if (!last_was_dash && out_p < max_len - 1)
            {
                out_buf[out_p++] = '-';
                last_was_dash = true;
            }
        }
    }

    // Strip trailing dash
    while (out_p > 0 && out_buf[out_p - 1] == '-')
    {
        out_p--;
    }
    out_buf[out_p] = 0;
}

fn bool slug_match(String query, String heading_title)
{
    if (query.len == 0) return false;
    
    // Direct case-insensitive substring match
    if (string_contains_case_insensitive(heading_title, query)) return true;

    // Slugified match
    char[256] q_slug;
    char[256] h_slug;
    slugify(query, &q_slug[0], 256);
    slugify(heading_title, &h_slug[0], 256);

    String qs = (String)(&q_slug[0])[:str_len(&q_slug[0])];
    String hs = (String)(&h_slug[0])[:str_len(&h_slug[0])];

    if (qs == hs) return true;
    if (string_contains(hs, qs)) return true;
    return false;
}

fn bool split_file_and_anchor(char* input, char* file_out, char* anchor_out, usz max_len)
{
    if (input == null || max_len == 0) return false;
    file_out[0] = 0;
    anchor_out[0] = 0;

    int hash_pos = -1;
    int len = str_len(input);
    for (int i = 0; i < len; i++)
    {
        if (input[i] == '#')
        {
            hash_pos = i;
            break;
        }
    }

    if (hash_pos >= 0)
    {
        int f_len = hash_pos;
        if ((usz)f_len >= max_len) f_len = (int)max_len - 1;
        for (int i = 0; i < f_len; i++) file_out[i] = input[i];
        file_out[f_len] = 0;

        int a_start = hash_pos + 1;
        int a_len = len - a_start;
        if ((usz)a_len >= max_len) a_len = (int)max_len - 1;
        for (int i = 0; i < a_len; i++) anchor_out[i] = input[a_start + i];
        anchor_out[a_len] = 0;
        return true;
    }

    copy_str(file_out, input, (int)max_len);
    return false;
}

fn void decode_html_entities(String in_str, char* out_buf, int max_len)
{
    if (out_buf == null || max_len <= 0) return;
    int out_p = 0;
    usz i = 0;
    usz len = (usz)in_str.len;

    while (i < len && out_p < max_len - 1)
    {
        if (in_str[i] == '&')
        {
            String symbol;
            usz skip = 0;
            if (match_html_entity(in_str[i..], &symbol, &skip))
            {
                for (sz r = 0; r < (sz)symbol.len && out_p < max_len - 1; r++)
                {
                    out_buf[out_p++] = symbol[r];
                }
                i += skip;
                continue;
            }
        }

        out_buf[out_p++] = in_str[i++];
    }
    out_buf[out_p] = 0;
}

fn void parse_lang_and_index(char* query, char* lang_out, usz max_lang, int* idx_out)
{
    if (lang_out != null && max_lang > 0) lang_out[0] = 0;
    if (idx_out != null) *idx_out = 0;
    if (query == null) return;

    int colon = -1;
    int len = str_len(query);
    for (int i = 0; i < len; i++)
    {
        if (query[i] == ':')
        {
            colon = i;
            break;
        }
    }

    if (colon >= 0)
    {
        if (lang_out != null && max_lang > 0)
        {
            int l_len = colon;
            if ((usz)l_len >= max_lang) l_len = (int)max_lang - 1;
            for (int i = 0; i < l_len; i++) lang_out[i] = query[i];
            lang_out[l_len] = 0;
        }
        if (idx_out != null)
        {
            *idx_out = parse_int(&query[colon + 1]);
        }
    }
    else
    {
        if (is_numeric(query))
        {
            if (idx_out != null) *idx_out = parse_int(query);
        }
        else
        {
            if (lang_out != null && max_lang > 0)
            {
                copy_str(lang_out, query, (int)max_lang);
            }
        }
    }
}
