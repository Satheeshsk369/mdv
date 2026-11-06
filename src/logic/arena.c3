module logic;

import std::core::mem;

struct ArenaBlock
{
    ArenaBlock* next;
    usz capacity;
    usz used;
    char* data;
}

struct Arena
{
    ArenaBlock* head;
    usz size;
}

fn void Arena.init(&self, usz size = 65536)
{
    self.head = null;
    self.size = size;
}

fn void* Arena.alloc(&self, usz bytes, usz align = 8)
{
    if (bytes == 0) return null;
    usz need = (bytes + align - 1) & ~(align - 1);
    if (self.head)
    {
        usz at = (self.head.used + align - 1) & ~(align - 1);
        if (at + need <= self.head.capacity)
        {
            self.head.used = at + need;
            return self.head.data + at;
        }
    }
    usz capacity = max(self.size, need + 256);
    char[] raw = mem::alloc_array(char, ArenaBlock::size + capacity);
    ArenaBlock* block = (ArenaBlock*)raw.ptr;
    *block = { self.head, capacity, need, raw.ptr + ArenaBlock::size };
    self.head = block;
    return block.data;
}

fn String Arena.dup_string(&self, String s)
{
    if (s.len == 0) return "";
    char* buf = self.alloc(s.len + 1, 1);
    buf[:s.len] = s[..];
    buf[s.len] = 0;
    return (String)buf[:s.len];
}

fn void Arena.free(&self)
{
    for (ArenaBlock* block = self.head; block;)
    {
        ArenaBlock* next = block.next;
        mem::free(block);
        block = next;
    }
    self.head = null;
}

fn String DString.to_arena_string(&self, Arena* arena)
{
    if (self.len() == 0) return "";
    return arena.dup_string(self.str_view());
}
