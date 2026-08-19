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
    return src[start:end];
}

fn int utf8_display_width(char* s)
{
    if (s == null) return 0;
    int i = 0;
    int width = 0;
    while (s[i] != 0)
    {
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
            if (c >= 0x20 && c != 0x7F) width++;
            i++;
        }
        else if ((c & 0xe0) == 0xc0)
        {
            i += (s[i+1] != 0) ? 2 : 1;
            width++;
        }
        else if ((c & 0xf0) == 0xe0)
        {
            uint cp = ((c & 0x0f) << 12);
            if (s[i+1] != 0) cp |= ((uint)s[i+1] & 0x3f) << 6;
            if (s[i+1] != 0 && s[i+2] != 0) cp |= ((uint)s[i+2] & 0x3f);

            if ((cp >= 0x2E80 && cp <= 0xA4CF) || (cp >= 0xAC00 && cp <= 0xD7A3) || (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFE30 && cp <= 0xFE6F) || (cp >= 0xFF01 && cp <= 0xFF60))
            {
                width += 2;
            }
            else
            {
                width++;
            }
            i += (s[i+1] != 0 && s[i+2] != 0) ? 3 : (s[i+1] != 0 ? 2 : 1);
        }
        else if ((c & 0xf8) == 0xf0)
        {
            width += 2;
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
            if (c >= 0x20 && c != 0x7F) width++;
            i++;
        }
        else if ((c & 0xe0) == 0xc0)
        {
            i += (i + 1 < (sz)s.len) ? 2 : 1;
            width++;
        }
        else if ((c & 0xf0) == 0xe0)
        {
            uint cp = ((c & 0x0f) << 12);
            if (i + 1 < (sz)s.len) cp |= ((uint)s[i+1] & 0x3f) << 6;
            if (i + 2 < (sz)s.len) cp |= ((uint)s[i+2] & 0x3f);

            if ((cp >= 0x2E80 && cp <= 0xA4CF) || (cp >= 0xAC00 && cp <= 0xD7A3) || (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFE30 && cp <= 0xFE6F) || (cp >= 0xFF01 && cp <= 0xFF60))
            {
                width += 2;
            }
            else
            {
                width++;
            }
            i += (i + 2 < (sz)s.len) ? 3 : ((i + 1 < (sz)s.len) ? 2 : 1);
        }
        else if ((c & 0xf8) == 0xf0)
        {
            width += 2;
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
    if (s[0] == '+') i = 1;
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
