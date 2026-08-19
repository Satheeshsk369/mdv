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
            String sub = in_str[i..];
            char* repl = null;
            usz skip = 0;

            if (string_starts_with(sub, "&copy;")) { repl = "©"; skip = 6; }
            else if (string_starts_with(sub, "&trade;")) { repl = "™"; skip = 7; }
            else if (string_starts_with(sub, "&reg;")) { repl = "®"; skip = 5; }
            else if (string_starts_with(sub, "&mdash;")) { repl = "—"; skip = 7; }
            else if (string_starts_with(sub, "&ndash;")) { repl = "–"; skip = 7; }
            else if (string_starts_with(sub, "&hellip;")) { repl = "…"; skip = 8; }
            else if (string_starts_with(sub, "&amp;")) { repl = "&"; skip = 5; }
            else if (string_starts_with(sub, "&lt;")) { repl = "<"; skip = 4; }
            else if (string_starts_with(sub, "&gt;")) { repl = ">"; skip = 4; }
            else if (string_starts_with(sub, "&quot;")) { repl = "\""; skip = 6; }
            else if (string_starts_with(sub, "&apos;")) { repl = "'"; skip = 6; }
            else if (string_starts_with(sub, "&plusmn;")) { repl = "±"; skip = 8; }
            else if (string_starts_with(sub, "&times;")) { repl = "×"; skip = 7; }
            else if (string_starts_with(sub, "&divide;")) { repl = "÷"; skip = 8; }
            else if (string_starts_with(sub, "&deg;")) { repl = "°"; skip = 5; }
            else if (string_starts_with(sub, "&infin;")) { repl = "∞"; skip = 7; }
            else if (string_starts_with(sub, "&ne;")) { repl = "≠"; skip = 4; }
            else if (string_starts_with(sub, "&le;")) { repl = "≤"; skip = 4; }
            else if (string_starts_with(sub, "&ge;")) { repl = "≥"; skip = 4; }
            else if (string_starts_with(sub, "&euro;")) { repl = "€"; skip = 6; }
            else if (string_starts_with(sub, "&pound;")) { repl = "£"; skip = 7; }
            else if (string_starts_with(sub, "&yen;")) { repl = "¥"; skip = 5; }
            else if (string_starts_with(sub, "&check;")) { repl = "✔"; skip = 7; }
            else if (string_starts_with(sub, "&cross;")) { repl = "✗"; skip = 7; }
            else if (string_starts_with(sub, "&bull;")) { repl = "•"; skip = 6; }

            if (repl != null)
            {
                int r = 0;
                while (repl[r] != 0 && out_p < max_len - 1)
                {
                    out_buf[out_p++] = repl[r++];
                }
                i += skip;
                continue;
            }
        }

        out_buf[out_p++] = in_str[i++];
    }
    out_buf[out_p] = 0;
}
