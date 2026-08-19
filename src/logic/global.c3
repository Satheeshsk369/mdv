module logic;

import std::core::mem;

bitstruct AppFlags : uint {
    bool is_tty          : 0;
    bool plain_mode      : 1;
    bool no_wrap         : 2;
    bool live_watch      : 3;
    bool stdout_mode     : 4;
    bool dark_theme      : 5;
    bool mouse_enabled   : 6;
    bool alt_screen      : 7;
    bool osc52_clipboard : 8;
    bool file_modified   : 9;
    bool exit_requested  : 10;
    bool help_active     : 11;
}

struct GlobalContext {
    AppFlags flags;
    int terminal_width;
    int terminal_height;
    char* target_file;
    int target_line;
    Arena doc_arena;
    Arena scratch_arena;
}

GlobalContext g_ctx;

fn void init_global_context(int width = 80, int height = 24)
{
    g_ctx.flags = {};
    g_ctx.terminal_width = width;
    g_ctx.terminal_height = height;
    g_ctx.target_file = null;
    g_ctx.target_line = 0;
    g_ctx.doc_arena.init(65536);
    g_ctx.scratch_arena.init(32768);
}

fn void free_global_context()
{
    g_ctx.doc_arena.free();
    g_ctx.scratch_arena.free();
    g_ctx.target_file = null;
}

fn void set_app_flag(bool value, AppFlags flag_mask)
{
    if (value)
    {
        g_ctx.flags = (AppFlags)((uint)g_ctx.flags | (uint)flag_mask);
    }
    else
    {
        g_ctx.flags = (AppFlags)((uint)g_ctx.flags & ~(uint)flag_mask);
    }
}

fn bool has_app_flag(AppFlags flag_mask)
{
    return ((uint)g_ctx.flags & (uint)flag_mask) != 0;
}

fn void toggle_app_flag(AppFlags flag_mask)
{
    g_ctx.flags = (AppFlags)((uint)g_ctx.flags ^ (uint)flag_mask);
}
