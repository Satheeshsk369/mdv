module app;

import std::io;
import std::core::mem;
import ast;
import parser;
import render;
import layout;
import ansi;
import terminal;
import strutils;

extern fn int write(int fd, void* buf, ulong count);

struct FrameBuffer {
    char[] buf;
    usz len;
    usz cap;
}

fn void FrameBuffer.init(FrameBuffer* fb, usz initial_cap = 262144)
{
    fb.buf = mem::alloc_array(char, (sz)initial_cap);
    fb.len = 0;
    fb.cap = initial_cap;
}

fn void FrameBuffer.append_str(FrameBuffer* fb, char* s)
{
    if (s == null) return;
    usz sl = 0;
    while (s[sl] != 0 && fb.len < fb.cap - 1)
    {
        fb.buf[fb.len++] = s[sl++];
    }
}

fn void FrameBuffer.append_slice(FrameBuffer* fb, String s)
{
    for (usz i = 0; i < (usz)s.len && fb.len < fb.cap - 1; i++)
    {
        fb.buf[fb.len++] = s[i];
    }
}

fn void FrameBuffer.append_int(FrameBuffer* fb, int val)
{
    char[32] tmp;
    if (val == 0) { fb.append_str("0"); return; }
    if (val < 0) { fb.append_str("-"); val = -val; }
    int p = 0;
    while (val > 0)
    {
        tmp[p++] = (char)('0' + (val % 10));
        val /= 10;
    }
    for (int i = p - 1; i >= 0; i--)
    {
        char[2] ch; ch[0] = tmp[i]; ch[1] = 0;
        fb.append_str(&ch[0]);
    }
}

fn void FrameBuffer.flush(FrameBuffer* fb)
{
    if (fb.len > 0)
    {
        write(1, (void*)fb.buf.ptr, (ulong)fb.len);
        fb.len = 0;
    }
}

fn void FrameBuffer.free(FrameBuffer* fb)
{
    if (fb.buf.ptr != null)
    {
        mem::free(fb.buf);
        fb.buf = {};
        fb.len = 0;
        fb.cap = 0;
    }
}

fn void draw_viewport(FrameBuffer* fb, layout::VisualDocument* vdoc, int scroll_top, int view_height, char* filename, int changed_src_line, int term_width)
{
    fb.len = 0;

    // Move cursor to top-left (1,1)
    fb.append_str("\x1b[H");

    // Header Banner
    int total = vdoc.get_total_lines();
    int end_idx = scroll_top + view_height;
    if (end_idx > total) end_idx = total;
    int pct = total > 0 ? ((scroll_top + 1) * 100) / total : 100;
    if (pct > 100) pct = 100;

    fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
    fb.append_str(filename);
    fb.append_str(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m ");

    if (changed_src_line >= 0)
    {
        fb.append_str("\x1b[38;2;166;226;46m\x1b[1m⚡ Sync L");
        fb.append_int(changed_src_line + 1);
        fb.append_str("\x1b[0m \x1b[38;2;117;113;94m│\x1b[0m ");
    }

    fb.append_str("\x1b[38;2;117;113;94mLines ");
    fb.append_int(scroll_top + 1);
    fb.append_str("-");
    fb.append_int(end_idx);
    fb.append_str(" of ");
    fb.append_int(total);
    fb.append_str(" (");
    fb.append_int(pct);
    fb.append_str("%)\x1b[0m\x1b[K\n");

    // Separator line
    fb.append_str("\x1b[38;2;117;113;94m");
    for (int k = 0; k < term_width - 2 && k < 120; k++) fb.append_str("─");
    fb.append_str("\x1b[0m\x1b[K\n");

    // Visual document lines
    for (int i = scroll_top; i < scroll_top + view_height; i++)
    {
        if (i < total)
        {
            fb.append_slice(vdoc.lines[i].text);
            fb.append_str("\x1b[K\n");
        }
        else
        {
            fb.append_str("\x1b[38;2;60;60;50m~\x1b[0m\x1b[K\n");
        }
    }

    fb.flush();
}

fn void run_watch(char* filename, int initial_line)
{
    terminal::enable_raw_mode();
    terminal::enter_alt_screen();
    defer {
        terminal::leave_alt_screen();
        terminal::disable_raw_mode();
    }

    int width = terminal::get_width();
    int height = terminal::get_height();
    int view_height = height - 2;
    if (view_height < 2) view_height = 2;

    terminal::FileState prev_state;
    char* prev_content = null;
    int scroll_top = 0;
    int last_changed_line = initial_line > 0 ? initial_line - 1 : -1;

    FrameBuffer fb;
    fb.init(262144);
    defer fb.free();

    char* content = strutils::load_file_string(filename);
    if (content == null)
    {
        io::printfn("Error: Could not open file '%s'", (ZString)filename);
        terminal::sleep_ms(1500);
        return;
    }

    render::RenderConfig config;
    config.width = width;
    config.plain = ansi::plain_mode;

    String content_str = (String)content[:strutils::str_len(content)];
    ast::Document doc = parser::parse_document(content_str);
    layout::VisualDocument vdoc = render::render_document(&doc, config);

    int total_lines = vdoc.get_total_lines();
    int max_scroll = total_lines - view_height;
    if (max_scroll < 0) max_scroll = 0;

    if (initial_line > 0)
    {
        int v_line = vdoc.find_visual_line(initial_line - 1);
        int context_offset = view_height / 3;
        if (context_offset < 5) context_offset = 5;
        scroll_top = v_line - context_offset;
        if (scroll_top < 0) scroll_top = 0;
        if (scroll_top > max_scroll) scroll_top = max_scroll;
    }

    draw_viewport(&fb, &vdoc, scroll_top, view_height, filename, last_changed_line, width);
    prev_content = content;
    terminal::get_file_state(filename, &prev_state);

    int idle_tick = 0;

    while (true)
    {
        bool need_redraw = false;
        total_lines = vdoc.get_total_lines();
        max_scroll = total_lines - view_height;
        if (max_scroll < 0) max_scroll = 0;

        // Process all available keypresses
        while (true)
        {
            int key = terminal::poll_key();
            if (key == 0) break;

            if (key == 'q' || key == 0x1b || key == 0x03)
            {
                if (prev_content != null) mem::free(prev_content);
                doc.free();
                vdoc.free();
                return;
            }
            else if (key == 'j' || key == 1000) // Down
            {
                if (scroll_top < max_scroll) { scroll_top++; need_redraw = true; }
            }
            else if (key == 'k' || key == 1001) // Up
            {
                if (scroll_top > 0) { scroll_top--; need_redraw = true; }
            }
            else if (key == 'd' || key == 1004) // Half page down
            {
                scroll_top += view_height / 2;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == 'u' || key == 1005) // Half page up
            {
                scroll_top -= view_height / 2;
                if (scroll_top < 0) scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 1002) // Full page down (Space / PgDn / Ctrl+F)
            {
                scroll_top += view_height - 2;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == 1003) // Full page up (PgUp / Ctrl+B)
            {
                scroll_top -= view_height - 2;
                if (scroll_top < 0) scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 'g') // Top
            {
                scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 'G') // Bottom
            {
                scroll_top = max_scroll;
                need_redraw = true;
            }
        }

        // Check for file updates every ~25ms
        idle_tick++;
        if (idle_tick >= 2)
        {
            idle_tick = 0;
            terminal::FileState curr_state;
            bool state_ok = terminal::get_file_state(filename, &curr_state);
            int cur_width = terminal::get_width();
            int cur_height = terminal::get_height();

            if ((state_ok && terminal::file_has_changed(&prev_state, &curr_state)) || cur_width != width || cur_height != height)
            {
                prev_state = curr_state;
                width = cur_width;
                height = cur_height;
                view_height = height - 2;
                if (view_height < 2) view_height = 2;

                char* new_content = strutils::load_file_string(filename);
                if (new_content != null)
                {
                    int diff_line = strutils::find_first_diff_line(prev_content, new_content);
                    if (diff_line >= 0)
                    {
                        last_changed_line = diff_line;
                    }

                    // Free old AST & VisualDoc
                    doc.free();
                    vdoc.free();

                    config.width = width;
                    config.plain = ansi::plain_mode;

                    String new_str = (String)new_content[:strutils::str_len(new_content)];
                    doc = parser::parse_document(new_str);
                    vdoc = render::render_document(&doc, config);

                    total_lines = vdoc.get_total_lines();
                    max_scroll = total_lines - view_height;
                    if (max_scroll < 0) max_scroll = 0;

                    // Line sync
                    if (diff_line >= 0)
                    {
                        int v_line = vdoc.find_visual_line(diff_line);
                        int context_offset = view_height / 3;
                        if (context_offset < 5) context_offset = 5;
                        scroll_top = v_line - context_offset;
                        if (scroll_top < 0) scroll_top = 0;
                        if (scroll_top > max_scroll) scroll_top = max_scroll;
                    }

                    if (prev_content != null) mem::free(prev_content);
                    prev_content = new_content;
                    need_redraw = true;
                }
            }
        }

        if (need_redraw)
        {
            draw_viewport(&fb, &vdoc, scroll_top, view_height, filename, last_changed_line, width);
        }

        terminal::sleep_ms(12);
    }
}
