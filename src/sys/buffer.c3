module buffer;

import std::core::mem;
import strutils;

struct ByteBuffer
{
    char[] buf;
    usz len;
    usz cap;
}

fn void ByteBuffer.init(ByteBuffer* b, usz initial_cap = 512)
{
    usz cap = initial_cap < 64 ? 64 : initial_cap;
    b.buf = mem::alloc_array(char, (sz)cap);
    b.len = 0;
    b.cap = cap;
    b.buf[0] = 0;
}

fn void ByteBuffer.ensure_space(ByteBuffer* b, usz needed)
{
    if (b.len + needed + 1 >= b.cap)
    {
        usz new_cap = b.cap * 2;
        if (new_cap < b.len + needed + 64) new_cap = b.len + needed + 64;
        char[] new_buf = mem::alloc_array(char, (sz)new_cap);
        for (usz i = 0; i < b.len; i++)
        {
            new_buf[i] = b.buf[i];
        }
        if (b.buf.ptr != null) mem::free(b.buf);
        b.buf = new_buf;
        b.cap = new_cap;
    }
}

fn void ByteBuffer.append_char(ByteBuffer* b, char c)
{
    b.ensure_space(1);
    b.buf[b.len++] = c;
    b.buf[b.len] = 0;
}

fn void ByteBuffer.append_zstr(ByteBuffer* b, char* s)
{
    if (s == null) return;
    usz sl = 0;
    while (s[sl] != 0) sl++;
    b.ensure_space(sl);
    for (usz i = 0; i < sl; i++)
    {
        b.buf[b.len++] = s[i];
    }
    b.buf[b.len] = 0;
}

fn void ByteBuffer.append_slice(ByteBuffer* b, String s)
{
    if (s.len == 0) return;
    b.ensure_space((usz)s.len);
    for (usz i = 0; i < (usz)s.len; i++)
    {
        b.buf[b.len++] = s[i];
    }
    b.buf[b.len] = 0;
}

fn void ByteBuffer.append_spaces(ByteBuffer* b, int count)
{
    if (count <= 0) return;
    b.ensure_space((usz)count);
    for (int i = 0; i < count; i++)
    {
        b.buf[b.len++] = ' ';
    }
    b.buf[b.len] = 0;
}

fn void ByteBuffer.append_repeat(ByteBuffer* b, char* s, int count)
{
    if (s == null || count <= 0) return;
    usz sl = 0;
    while (s[sl] != 0) sl++;
    b.ensure_space(sl * (usz)count);
    for (int i = 0; i < count; i++)
    {
        for (usz j = 0; j < sl; j++)
        {
            b.buf[b.len++] = s[j];
        }
    }
    b.buf[b.len] = 0;
}

fn void ByteBuffer.append_int(ByteBuffer* b, int val)
{
    char[32] tmp;
    strutils::int_to_str(val, &tmp[0], 32);
    b.append_zstr(&tmp[0]);
}

fn String ByteBuffer.to_string(ByteBuffer* b)
{
    if (b.len == 0) return "";
    return (String)b.buf[:b.len];
}

fn void ByteBuffer.reset(ByteBuffer* b)
{
    b.len = 0;
    if (b.buf.ptr != null && b.cap > 0) b.buf[0] = 0;
}

fn void ByteBuffer.free(ByteBuffer* b)
{
    if (b.buf.ptr != null)
    {
        mem::free(b.buf);
        b.buf = {};
    }
    b.len = 0;
    b.cap = 0;
}
