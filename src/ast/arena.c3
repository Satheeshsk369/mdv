module ast;

import std::core::mem;

struct ArenaBlock {
    ArenaBlock* next;
    usz capacity;
    usz used;
    char* data;
}

struct Arena {
    ArenaBlock* head;
    usz default_block_size;
}

fn void Arena.init(Arena* a, usz block_size = 65536)
{
    a.head = null;
    a.default_block_size = block_size;
}

fn void* Arena.alloc(Arena* a, usz bytes, usz align = 8)
{
    if (bytes == 0) return null;
    usz aligned_bytes = (bytes + (align - 1)) & ~(align - 1);

    if (a.head != null)
    {
        usz cur_offset = (a.head.used + (align - 1)) & ~(align - 1);
        if (cur_offset + aligned_bytes <= a.head.capacity)
        {
            void* ptr = (void*)(a.head.data + cur_offset);
            a.head.used = cur_offset + aligned_bytes;
            return ptr;
        }
    }

    usz block_capacity = a.default_block_size;
    if (block_capacity == 0) block_capacity = 65536;
    if (aligned_bytes + 256 > block_capacity)
    {
        block_capacity = aligned_bytes + 256;
    }

    usz total_alloc = ArenaBlock::size + block_capacity;
    char[] raw = mem::alloc_array(char, (sz)total_alloc);
    ArenaBlock* new_block = (ArenaBlock*)raw.ptr;
    new_block.next = a.head;
    new_block.capacity = block_capacity;
    new_block.used = aligned_bytes;
    new_block.data = (char*)(raw.ptr + ArenaBlock::size);
    a.head = new_block;

    return (void*)new_block.data;
}

fn String Arena.dup_string(Arena* a, String src)
{
    if (src.len == 0) return "";
    char* buf = (char*)a.alloc((usz)(src.len + 1), 1);
    for (sz i = 0; i < (sz)src.len; i++)
    {
        buf[i] = src[i];
    }
    buf[src.len] = 0;
    return (String)buf[:src.len];
}

fn String Arena.dup_zstring(Arena* a, char* src)
{
    if (src == null || src[0] == 0) return "";
    usz len = 0;
    while (src[len] != 0) len++;
    char* buf = (char*)a.alloc(len + 1, 1);
    for (sz i = 0; i < (sz)len; i++)
    {
        buf[i] = src[i];
    }
    buf[len] = 0;
    return (String)buf[:len];
}

fn void Arena.free(Arena* a)
{
    ArenaBlock* curr = a.head;
    while (curr != null)
    {
        ArenaBlock* next = curr.next;
        char* raw_ptr = (char*)curr;
        mem::free(raw_ptr);
        curr = next;
    }
    a.head = null;
}
