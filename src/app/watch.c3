module app;

import std::io;
import std::core::mem;
import std::collections::list;
import ast;
import parser;
import render;
import layout;
import ansi;
import terminal;
import strutils;
import buffer;

extern fn int write(int fd, void* buf, ulong count);

fn void flush_fb(buffer::ByteBuffer* fb)
{
    if (fb.len > 0)
    {
        write(1, (void*)fb.buf.ptr, (ulong)fb.len);
        fb.len = 0;
    }
}

struct TocItem {
    int level;
    String title;
    int src_line;
    int visual_line;
}

fn void extract_toc(ast::Document* doc, layout::VisualDocument* vdoc, List{TocItem}* toc)
{
    toc.clear();
    int total_lines = vdoc.get_total_lines();
    for (usz i = 0; i < doc.blocks.len; i++)
    {
        ast::Block* b = &doc.blocks[i];
        if (b.kind == ast::BlockKind.HEADING)
        {
            // Build plain title
            buffer::ByteBuffer tbuf;
            tbuf.init(128);
            defer tbuf.free();

            for (usz s = 0; s < b.heading.spans.len; s++)
            {
                tbuf.append_slice(b.heading.spans[s].text);
            }
            String title_str = tbuf.to_arena_string(&vdoc.arena);

            // Find exact visual line containing this heading
            int start_hint = vdoc.find_visual_line(b.src_line_start);
            int exact_vline = start_hint;

            // Search around start_hint for the line containing the title
            bool found = false;
            int search_start = start_hint > 5 ? start_hint - 5 : 0;
            int search_end = start_hint + 25 < total_lines ? start_hint + 25 : total_lines;

            for (int v = search_start; v < search_end; v++)
            {
                if (strutils::string_contains(vdoc.lines[v].text, title_str))
                {
                    exact_vline = v;
                    found = true;
                    break;
                }
            }

            if (!found)
            {
                while (exact_vline < total_lines && vdoc.lines[exact_vline].text.len == 0)
                {
                    exact_vline++;
                }
            }

            TocItem item;
            item.level = b.heading.level;
            item.title = title_str;
            item.src_line = b.src_line_start;
            item.visual_line = exact_vline;
            toc.push(item);
        }
    }
}

fn void copy_to_clipboard_osc52(char* text, int len)
{
    if (text == null || len <= 0) return;
    char[64] b64 = {
        'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
        'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
        'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
        'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
    };

    int out_cap = ((len + 2) / 3) * 4 + 64;
    char[] out = mem::alloc_array(char, (sz)out_cap);
    defer mem::free(out);

    int op = 0;
    out[op++] = '\x1b'; out[op++] = ']'; out[op++] = '5'; out[op++] = '2';
    out[op++] = ';'; out[op++] = 'c'; out[op++] = ';';

    int i = 0;
    while (i < len)
    {
        uint b0 = (uint)text[i] & 0xFFu;
        i++;
        uint b1 = 0u;
        if (i < len)
        {
            b1 = (uint)text[i] & 0xFFu;
            i++;
        }
        uint b2 = 0u;
        if (i < len)
        {
            b2 = (uint)text[i] & 0xFFu;
            i++;
        }

        uint triple = (b0 << 16) | (b1 << 8) | b2;

        out[op++] = b64[(triple >> 18) & 0x3F];
        out[op++] = b64[(triple >> 12) & 0x3F];
        out[op++] = (i > len + 1) ? '=' : b64[(triple >> 6) & 0x3F];
        out[op++] = (i > len) ? '=' : b64[triple & 0x3F];
    }

    out[op++] = '\x1b'; out[op++] = '\\';
    write(1, (void*)out.ptr, (ulong)op);
}

fn bool char_eq_ignore_case(char a, char b)
{
    if (a >= 'A' && a <= 'Z') a = (char)(a + ('a' - 'A'));
    if (b >= 'A' && b <= 'Z') b = (char)(b + ('a' - 'A'));
    return a == b;
}

struct ScrollVelocity {
    int key_streak;
    int wheel_streak;
    int last_dir;
    int streak_ticks;
}

fn int get_accelerated_step(ScrollVelocity* v, int dir, bool is_wheel)
{
    if (v.last_dir != dir || v.streak_ticks > 8)
    {
        v.key_streak = 0;
        v.wheel_streak = 0;
    }
    v.last_dir = dir;
    v.streak_ticks = 0;

    if (is_wheel)
    {
        v.wheel_streak++;
        if (v.wheel_streak > 12) return 12;
        if (v.wheel_streak > 6) return 8;
        if (v.wheel_streak > 2) return 5;
        return 3;
    }
    else
    {
        v.key_streak++;
        if (v.key_streak > 20) return 5;
        if (v.key_streak > 10) return 3;
        if (v.key_streak > 4) return 2;
        return 1;
    }
}

fn void append_with_search_highlight(buffer::ByteBuffer* fb, String line, String query, bool is_cur_match_line)
{
    if (query.len == 0)
    {
        fb.append_slice(line);
        return;
    }

    usz p = 0;
    usz len = (usz)line.len;
    usz qlen = (usz)query.len;

    while (p < len)
    {
        // Skip and preserve ANSI escape codes
        if (line[p] == '\x1b')
        {
            fb.append_char(line[p++]);
            while (p < len && line[p] != 'm' && line[p] != 'K' && line[p] != 'H')
            {
                fb.append_char(line[p++]);
            }
            if (p < len) fb.append_char(line[p++]);
            continue;
        }

        // Check if query matches starting at p
        if (p + qlen <= len)
        {
            bool match = true;
            for (usz k = 0; k < qlen; k++)
            {
                if (!char_eq_ignore_case(line[p + k], query[k]))
                {
                    match = false;
                    break;
                }
            }

            if (match)
            {
                // Active match = bright lime green background, other matches = warm orange background
                if (is_cur_match_line)
                {
                    fb.append_zstr("\x1b[48;2;166;226;46m\x1b[38;2;0;0;0m\x1b[1m");
                }
                else
                {
                    fb.append_zstr("\x1b[48;2;253;151;31m\x1b[38;2;0;0;0m\x1b[1m");
                }

                for (usz k = 0; k < qlen; k++)
                {
                    fb.append_char(line[p++]);
                }
                fb.append_zstr("\x1b[0m");
                continue;
            }
        }

        fb.append_char(line[p++]);
    }
}

fn void append_horizontal_slice(buffer::ByteBuffer* fb, String line, int scroll_left, int max_w)
{
    if (scroll_left <= 0)
    {
        fb.append_slice(line);
        return;
    }

    usz p = 0;
    usz len = (usz)line.len;
    int cur_col = 0;
    int emitted_cols = 0;

    while (p < len)
    {
        // Always emit ANSI escape sequences
        if (line[p] == '\x1b')
        {
            fb.append_char(line[p++]);
            while (p < len && line[p] != 'm' && line[p] != 'K' && line[p] != 'H')
            {
                fb.append_char(line[p++]);
            }
            if (p < len) fb.append_char(line[p++]);
            continue;
        }

        // Measure UTF-8 character length & width
        char c = line[p];
        usz char_bytes = 1;
        if ((c & 0xE0) == 0xC0)
        {
            char_bytes = 2;
        }
        else if ((c & 0xF0) == 0xE0)
        {
            char_bytes = 3;
        }
        else if ((c & 0xF8) == 0xF0)
        {
            char_bytes = 4;
        }

        if (p + char_bytes > len) char_bytes = len - p;

        if (cur_col >= scroll_left && (max_w <= 0 || emitted_cols < max_w))
        {
            for (usz k = 0; k < char_bytes; k++)
            {
                fb.append_char(line[p + k]);
            }
            emitted_cols++;
        }

        p += char_bytes;
        cur_col++;
    }
}

fn void draw_viewport(
    buffer::ByteBuffer* fb,
    layout::VisualDocument* vdoc,
    int scroll_top,
    int scroll_left,
    int view_height,
    char* filename,
    int changed_src_line,
    int term_width,
    char* status_msg,
    bool search_active,
    char* search_query,
    int match_count,
    int cur_match_idx,
    int cur_match_line,
    bool show_toc,
    List{TocItem}* toc,
    int toc_cursor,
    bool show_help,
    bool no_wrap,
    bool goto_active = false,
    char* goto_query = null,
    int cursor_line = 0,
    bool show_files = false,
    terminal::FileTree* tree = null,
    int file_cursor = 0
)
{
    fb.reset();

    // Disable line wrap and move cursor to top-left (1,1)
    fb.append_zstr("\x1b[?7l\x1b[H");

    // ── Help Modal View ───────────────────────────────────────────────
    if (show_help)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
        fb.append_zstr(filename);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m \x1b[38;2;253;151;31m\x1b[1mKeyboard Controls & Keybindings\x1b[0m\x1b[K\n");

        // Separator line
        fb.append_zstr("\x1b[38;2;117;113;94m");
        int bar_w = term_width - 2;
        if (bar_w < 10) bar_w = 10;
        fb.append_repeat("─", bar_w);
        fb.append_zstr("\x1b[0m\x1b[K\n");

        char*[20] help_rows = {
            "\x1b[38;2;102;217;239m\x1b[1mVertical Navigation:\x1b[0m",
            "  \x1b[38;2;230;219;116mj / ↓\x1b[0m                 Scroll down (with acceleration)",
            "  \x1b[38;2;230;219;116mk / ↑\x1b[0m                 Scroll up (with acceleration)",
            "  \x1b[38;2;230;219;116md / Ctrl+D\x1b[0m            Half page down",
            "  \x1b[38;2;230;219;116mu / Ctrl+U\x1b[0m            Half page up",
            "  \x1b[38;2;230;219;116mSpace / Ctrl+F\x1b[0m        Full page down",
            "  \x1b[38;2;230;219;116mg / G\x1b[0m                 Jump to Top / Bottom",
            "  \x1b[38;2;230;219;116m: <line>\x1b[0m              Goto line number (e.g. :42)",
            "",
            "\x1b[38;2;102;217;239m\x1b[1mHorizontal & Layout:\x1b[0m",
            "  \x1b[38;2;230;219;116mw\x1b[0m                     Toggle Wrap / No-Wrap mode",
            "  \x1b[38;2;230;219;116mh / l / ← / →\x1b[0m         Horizontal scroll in no-wrap mode",
            "",
            "\x1b[38;2;102;217;239m\x1b[1mFeatures & Actions:\x1b[0m",
            "  \x1b[38;2;166;226;46mTab / t\x1b[0m               Document Outline (Table of Contents)",
            "  \x1b[38;2;166;226;46mo\x1b[0m                     Switch Document (Markdown File Tree)",
            "  \x1b[38;2;166;226;46m/\x1b[0m                     In-document search (n next, N prev)",
            "  \x1b[38;2;166;226;46me\x1b[0m                     Open $EDITOR at current line",
            "  \x1b[38;2;166;226;46my\x1b[0m                     Copy document to clipboard (OSC 52)",
            "  \x1b[38;2;166;226;46m?\x1b[0m                     Show / hide this help screen"
        };

        for (int r = 0; r < view_height; r++)
        {
            if (r < 20)
            {
                fb.append_zstr("  ");
                fb.append_zstr(help_rows[r]);
            }
            else
            {
                fb.append_zstr("\x1b[38;2;60;60;50m~\x1b[0m");
            }
            fb.append_zstr("\x1b[K\n");
        }

        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m Help \x1b[0m\x1b[38;2;117;113;94m [Esc / ? / q: Close]\x1b[0m\x1b[K");
        flush_fb(fb);
        return;
    }

    // ── Table of Contents (Outline) View ──────────────────────────────
    if (show_toc)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
        fb.append_zstr(filename);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m \x1b[38;2;166;226;46m\x1b[1mDocument Outline (Table of Contents)\x1b[0m\x1b[K\n");

        // Separator line
        fb.append_zstr("\x1b[38;2;117;113;94m");
        int bar_w = term_width - 2;
        if (bar_w < 10) bar_w = 10;
        fb.append_repeat("─", bar_w);
        fb.append_zstr("\x1b[0m\x1b[K\n");

        int toc_total = (toc != null) ? (int)toc.size : 0;

        for (int r = 0; r < view_height; r++)
        {
            if (r < toc_total)
            {
                TocItem item = toc.entries[r];
                bool is_cur = (r == toc_cursor);

                if (is_cur)
                {
                    fb.append_zstr("  \x1b[48;2;49;50;68m\x1b[38;2;166;226;46m\x1b[1m▶ ");
                }
                else
                {
                    fb.append_zstr("    ");
                }

                // Indent by level
                for (int lv = 1; lv < item.level && lv < 5; lv++) fb.append_zstr("   ");

                if (is_cur)
                {
                    fb.append_zstr("\x1b[38;2;248;248;242m\x1b[1m");
                }
                else
                {
                    switch (item.level)
                    {
                        case 1: fb.append_zstr("\x1b[38;2;249;38;114m\x1b[1m");
                        case 2: fb.append_zstr("\x1b[38;2;166;226;46m\x1b[1m");
                        case 3: fb.append_zstr("\x1b[38;2;253;151;31m\x1b[1m");
                        case 4: fb.append_zstr("\x1b[38;2;230;219;116m\x1b[1m");
                        default: fb.append_zstr("\x1b[38;2;102;217;239m\x1b[1m");
                    }
                }

                fb.append_slice(item.title);
                fb.append_zstr("\x1b[0m");

                fb.append_zstr(" \x1b[38;2;117;113;94m(Line ");
                fb.append_int(item.src_line + 1);
                fb.append_zstr(")\x1b[0m");
            }
            else
            {
                fb.append_zstr("\x1b[38;2;60;60;50m~\x1b[0m");
            }
            fb.append_zstr("\x1b[K\n");
        }

        // Bottom status line
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m Outline \x1b[0m\x1b[38;2;117;113;94m [Enter: Jump │ Esc: Close]\x1b[0m\x1b[K");
        flush_fb(fb);
        return;
    }

    // ── File Tree View ───────────────────────────────────────────────
    if (show_files && tree != null)
    {
        char[256] cwd_buf;
        char* cwd = terminal::getcwd(&cwd_buf[0], 256);
        if (cwd == null) cwd = ".";

        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
        fb.append_zstr(filename);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m \x1b[38;2;166;226;46m\x1b[1mTree: \x1b[0m\x1b[38;2;248;248;242m");
        fb.append_zstr(cwd);
        fb.append_zstr("\x1b[0m\x1b[K\n");

        // Separator line
        fb.append_zstr("\x1b[38;2;117;113;94m");
        int bar_w = term_width - 2;
        if (bar_w < 10) bar_w = 10;
        fb.append_repeat("─", bar_w);
        fb.append_zstr("\x1b[0m\x1b[K\n");

        // Compute visible nodes
        int[128] vis_idx;
        int vis_count = 0;

        int[16] collapse_depth;
        int collapse_count = 0;

        for (usz i = 0; i < tree.count; i++)
        {
            terminal::TreeNode* node = &tree.nodes[i];
            while (collapse_count > 0 && collapse_depth[collapse_count - 1] >= node.depth)
            {
                collapse_count--;
            }

            if (collapse_count == 0 && vis_count < 128)
            {
                vis_idx[vis_count++] = (int)i;
            }

            if (node.is_dir && !node.is_expanded && collapse_count < 15)
            {
                collapse_depth[collapse_count++] = node.depth;
            }
        }

        int f_offset = 0;
        if (file_cursor >= view_height)
        {
            f_offset = file_cursor - view_height + 1;
        }

        for (int r = 0; r < view_height; r++)
        {
            int v_idx = f_offset + r;
            if (v_idx < vis_count)
            {
                int node_idx = vis_idx[v_idx];
                terminal::TreeNode* item = &tree.nodes[node_idx];
                bool is_cur = (v_idx == file_cursor);

                if (is_cur)
                {
                    fb.append_zstr("  \x1b[48;2;49;50;68m\x1b[38;2;166;226;46m\x1b[1m▶ ");
                }
                else
                {
                    fb.append_zstr("    ");
                }

                if (strutils::str_eq(&item.name[0], ".."))
                {
                    if (is_cur)
                    {
                        fb.append_zstr("\x1b[48;2;49;50;68m\x1b[38;2;253;151;31m\x1b[1m📁 ../ \x1b[38;2;248;248;242m(Parent Directory)\x1b[0m");
                    }
                    else
                    {
                        fb.append_zstr("\x1b[38;2;253;151;31m\x1b[1m📁 ../ \x1b[0m\x1b[38;2;117;113;94m(Parent Directory)\x1b[0m");
                    }
                }
                else
                {
                    // Indentation
                    for (int d = 0; d < item.depth && d < 6; d++)
                    {
                        fb.append_zstr("\x1b[38;2;117;113;94m│   \x1b[0m");
                    }

                    if (item.is_dir)
                    {
                        if (item.is_expanded)
                        {
                            fb.append_zstr("\x1b[38;2;253;151;31m\x1b[1m▾ \x1b[0m");
                        }
                        else
                        {
                            fb.append_zstr("\x1b[38;2;253;151;31m\x1b[1m▸ \x1b[0m");
                        }

                        if (is_cur)
                        {
                            fb.append_zstr("\x1b[48;2;49;50;68m\x1b[38;2;102;217;239m\x1b[1m");
                        }
                        else
                        {
                            fb.append_zstr("\x1b[38;2;102;217;239m\x1b[1m");
                        }
                        fb.append_zstr(&item.name[0]);
                        fb.append_zstr("/\x1b[0m");
                    }
                    else
                    {
                        if (item.is_last)
                        {
                            fb.append_zstr("\x1b[38;2;117;113;94m└── \x1b[0m");
                        }
                        else
                        {
                            fb.append_zstr("\x1b[38;2;117;113;94m├── \x1b[0m");
                        }

                        if (is_cur)
                        {
                            fb.append_zstr("\x1b[48;2;49;50;68m\x1b[38;2;248;248;242m\x1b[1m");
                        }
                        else
                        {
                            fb.append_zstr("\x1b[38;2;248;248;242m");
                        }
                        fb.append_zstr(&item.name[0]);
                        fb.append_zstr("\x1b[0m");

                        if (item.is_current)
                        {
                            fb.append_zstr(" \x1b[38;2;166;226;46m[Active]\x1b[0m");
                        }
                    }
                }
            }
            else
            {
                fb.append_zstr("\x1b[38;2;60;60;50m~\x1b[0m");
            }
            fb.append_zstr("\x1b[K\n");
        }

        // Bottom status line
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m Tree \x1b[0m\x1b[38;2;117;113;94m [Enter: CD/Open │ a: Toggle all │ ←/→: Fold │ Esc: Close]\x1b[0m\x1b[K");
        flush_fb(fb);
        return;
    }

    // ── Normal Document View ──────────────────────────────────────────
    int total = vdoc.get_total_lines();
    int end_idx = scroll_top + view_height;
    if (end_idx > total) end_idx = total;

    int cur_src = (cursor_line >= 0 && cursor_line < total && vdoc.lines[cursor_line].src_line >= 0) ? vdoc.lines[cursor_line].src_line + 1 : 1;
    int pct = total > 0 ? ((cursor_line + 1) * 100) / total : 0;

    fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
    fb.append_zstr(filename);
    fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m ");

    if (changed_src_line >= 0)
    {
        fb.append_zstr("\x1b[38;2;166;226;46m\x1b[1m⚡ Sync L");
        fb.append_int(changed_src_line + 1);
        fb.append_zstr("\x1b[0m \x1b[38;2;117;113;94m│\x1b[0m ");
    }

    fb.append_zstr("\x1b[38;2;166;226;46m\x1b[1mLn ");
    fb.append_int(cur_src);
    fb.append_zstr("\x1b[0m \x1b[38;2;117;113;94m(");
    fb.append_int(cursor_line + 1);
    fb.append_zstr("/");
    fb.append_int(total);
    fb.append_zstr(" · ");
    fb.append_int(pct);
    fb.append_zstr("%)\x1b[0m\x1b[K\n");

    // Separator line
    fb.append_zstr("\x1b[38;2;117;113;94m");
    int bar_w = term_width - 2;
    if (bar_w < 10) bar_w = 10;
    fb.append_repeat("─", bar_w);
    fb.append_zstr("\x1b[0m\x1b[K\n");

    // Visual document lines
    String q_str = (search_query != null) ? (String)search_query[:strutils::str_len(search_query)] : "";

    for (int i = scroll_top; i < scroll_top + view_height; i++)
    {
        if (i < total)
        {
            bool is_cursor = (i == cursor_line);
            bool is_cur_line = (i == cur_match_line);

            if (is_cursor)
            {
                fb.append_zstr("\x1b[38;2;102;217;239m\x1b[1m▌\x1b[0m");
            }
            else
            {
                fb.append_zstr(" ");
            }

            if (q_str.len > 0 && (search_active || match_count > 0))
            {
                append_with_search_highlight(fb, vdoc.lines[i].text, q_str, is_cur_line);
            }
            else
            {
                append_horizontal_slice(fb, vdoc.lines[i].text, scroll_left, term_width - 1);
            }
            fb.append_zstr("\x1b[K\n");
        }
        else
        {
            fb.append_zstr(" \x1b[38;2;60;60;50m~\x1b[0m\x1b[K\n");
        }
    }

    // Bottom Status / Search Bar
    if (goto_active)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;253;151;31m\x1b[1m : \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m ");
        if (goto_query != null) fb.append_zstr(goto_query);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m (Enter: Goto line, Esc: Cancel)\x1b[0m\x1b[K");
    }
    else if (search_active)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;253;151;31m\x1b[1m / \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m ");
        fb.append_zstr(search_query);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m (Enter: Search, Esc: Cancel)\x1b[0m\x1b[K");
    }
    else if (match_count > 0)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m Match ");
        fb.append_int(cur_match_idx + 1);
        fb.append_zstr(" of ");
        fb.append_int(match_count);
        fb.append_zstr(" \x1b[0m\x1b[38;2;117;113;94m (n: Next, N: Prev, Esc: Clear)\x1b[0m\x1b[K");
    }
    else if (status_msg != null && status_msg[0] != 0)
    {
        fb.append_zstr("\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m ");
        fb.append_zstr(status_msg);
        fb.append_zstr(" \x1b[0m\x1b[K");
    }
    else
    {
        fb.append_zstr("\x1b[38;2;117;113;94m[? Help │ \x1b[38;2;166;226;46me Edit\x1b[38;2;117;113;94m │ q Quit]\x1b[0m\x1b[K");
    }

    flush_fb(fb);
}

fn void run_watch(char* filename, int initial_line, bool initial_no_wrap = false, bool initial_file_picker = false)
{
    terminal::enable_raw_mode();
    terminal::enter_alt_screen();
    defer {
        terminal::leave_alt_screen();
        terminal::disable_raw_mode();
    }

    int width = terminal::get_width();
    int height = terminal::get_height();
    int view_height = height - 3;
    if (view_height < 2) view_height = 2;

    bool no_wrap = initial_no_wrap;
    int scroll_left = 0;

    terminal::FileState prev_state;
    char* prev_content = null;
    int scroll_top = 0;
    int cursor_line = 0;
    int last_changed_line = initial_line > 0 ? initial_line - 1 : -1;

    buffer::ByteBuffer fb;
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
    config.no_wrap = no_wrap;

    String content_str = (String)content[:strutils::str_len(content)];
    ast::Document doc = parser::parse_document(content_str);
    layout::VisualDocument vdoc = render::render_document(&doc, config);

    List{TocItem} toc;
    toc.init(mem, 32);
    defer toc.free();
    extract_toc(&doc, &vdoc, &toc);

    int total_lines = vdoc.get_total_lines();
    int max_scroll = total_lines > 0 ? total_lines - 1 : 0;

    if (initial_line > 0)
    {
        int v_line = vdoc.find_visual_line(initial_line - 1);
        cursor_line = v_line;
        int context_offset = view_height / 3;
        if (context_offset < 5) context_offset = 5;
        scroll_top = v_line - context_offset;
        if (scroll_top < 0) scroll_top = 0;
        if (scroll_top > max_scroll) scroll_top = max_scroll;
    }

    // TUI state
    ScrollVelocity velocity = {};
    bool show_toc = false;
    int toc_cursor = 0;
    bool show_help = false;

    bool show_files = initial_file_picker;
    terminal::FileTree file_tree;
    int file_cursor = 0;
    char[256] cur_filename;
    strutils::copy_str(&cur_filename[0], filename, 256);

    if (initial_file_picker)
    {
        terminal::scan_file_tree(&cur_filename[0], &file_tree);
        int[16] collapse_depth;
        int collapse_count = 0;
        int v_count = 0;
        for (usz f = 0; f < file_tree.count; f++)
        {
            terminal::TreeNode* node = &file_tree.nodes[f];
            while (collapse_count > 0 && collapse_depth[collapse_count - 1] >= node.depth) collapse_count--;
            if (collapse_count == 0)
            {
                if (node.is_current) { file_cursor = v_count; break; }
                v_count++;
            }
            if (node.is_dir && !node.is_expanded && collapse_count < 15) collapse_depth[collapse_count++] = node.depth;
        }
    }

    bool search_mode = false;
    char[128] search_buf;
    int search_len = 0;
    search_buf[0] = 0;

    bool goto_mode = false;
    char[32] goto_buf;
    int goto_len = 0;
    goto_buf[0] = 0;

    List{int} match_lines;
    match_lines.init(mem, 32);
    defer match_lines.free();

    int cur_match_idx = 0;

    char[128] status_msg_buf;
    status_msg_buf[0] = 0;
    int status_ticks = 0;

    int cur_match_line = (match_lines.size > 0 && cur_match_idx < (int)match_lines.size) ? match_lines.entries[cur_match_idx] : -1;
    draw_viewport(&fb, &vdoc, scroll_top, scroll_left, view_height, &cur_filename[0], last_changed_line, width, &status_msg_buf[0], search_mode, &search_buf[0], (int)match_lines.size, cur_match_idx, cur_match_line, show_toc, &toc, toc_cursor, show_help, no_wrap, goto_mode, &goto_buf[0], cursor_line, show_files, &file_tree, file_cursor);
    prev_content = content;
    terminal::get_file_state(filename, &prev_state);

    while (true)
    {
        bool need_redraw = false;
        total_lines = vdoc.get_total_lines();
        max_scroll = total_lines > 0 ? total_lines - 1 : 0;

        if (status_ticks > 0)
        {
            status_ticks--;
            if (status_ticks == 0)
            {
                status_msg_buf[0] = 0;
                need_redraw = true;
            }
        }
        velocity.streak_ticks++;

        // Process keypresses
        while (true)
        {
            int key = terminal::poll_key();
            if (key == 0) break;

            // ── Help Modal Mode ──────────────────────────────────────────
            if (show_help)
            {
                if (key == 27 || key == 'q' || key == 'Q' || key == '?' || key == 31 || key == 0x1F || key == 10 || key == 9)
                {
                    show_help = false;
                    need_redraw = true;
                }
                continue;
            }

            // ── Search Input Mode ─────────────────────────────────────────
            if (search_mode)
            {
                if (key == 27) // Esc
                {
                    search_mode = false;
                    need_redraw = true;
                }
                else if (key == 10) // Enter -> Execute search
                {
                    search_mode = false;
                    match_lines.clear();
                    cur_match_idx = 0;

                    if (search_len > 0)
                    {
                        String query = (String)search_buf[:search_len];
                        for (int i = 0; i < total_lines; i++)
                        {
                            if (strutils::string_contains(vdoc.lines[i].text, query))
                            {
                                match_lines.push(i);
                            }
                        }
                        if (match_lines.size > 0)
                        {
                            scroll_top = match_lines.entries[0] - view_height / 3;
                            if (scroll_top < 0) scroll_top = 0;
                            if (scroll_top > max_scroll) scroll_top = max_scroll;
                        }
                        else
                        {
                            strutils::copy_str(&status_msg_buf[0], "No matches found", 128);
                            status_ticks = 40;
                        }
                    }
                    need_redraw = true;
                }
                else if (key == 127) // Backspace
                {
                    if (search_len > 0)
                    {
                        search_len--;
                        search_buf[search_len] = 0;
                        need_redraw = true;
                    }
                }
                else if (key >= 32 && key < 127 && search_len < 120)
                {
                    search_buf[search_len++] = (char)key;
                    search_buf[search_len] = 0;
                    need_redraw = true;
                }
                continue;
            }

            // ── Goto Line Mode ───────────────────────────────────────────
            if (goto_mode)
            {
                if (key == 27) // Esc
                {
                    goto_mode = false;
                    goto_len = 0;
                    goto_buf[0] = 0;
                    need_redraw = true;
                }
                else if (key == 10 || key == 13) // Enter -> Jump to line
                {
                    goto_mode = false;
                    int target_line = strutils::parse_int(&goto_buf[0]);
                    goto_len = 0;
                    goto_buf[0] = 0;
                    if (target_line > 0)
                    {
                        int v_line = vdoc.find_visual_line(target_line - 1);
                        cursor_line = v_line;
                        scroll_top = v_line - view_height / 3;
                        if (scroll_top > max_scroll) scroll_top = max_scroll;
                        if (scroll_top < 0) scroll_top = 0;

                        char[64] msg;
                        strutils::copy_str(&msg[0], "✔ Jumped to Line ", 64);
                        char[16] num_str;
                        strutils::int_to_str(target_line, &num_str[0], 16);
                        strutils::append_str(&msg[0], &num_str[0], 64);
                        strutils::copy_str(&status_msg_buf[0], &msg[0], 128);
                        status_ticks = 40;
                    }
                    need_redraw = true;
                }
                else if (key == 127 || key == 0x08) // Backspace
                {
                    if (goto_len > 0)
                    {
                        goto_len--;
                        goto_buf[goto_len] = 0;
                        need_redraw = true;
                    }
                }
                else if (key >= '0' && key <= '9' && goto_len < 20)
                {
                    goto_buf[goto_len++] = (char)key;
                    goto_buf[goto_len] = 0;
                    need_redraw = true;
                }
                continue;
            }

            // ── TOC Modal Mode ────────────────────────────────────────────
            if (show_toc)
            {
                if (key == 27 || key == 9 || key == 't' || key == 'T' || key == 'q')
                {
                    show_toc = false;
                    need_redraw = true;
                }
                else if (key == 'j' || key == 1000) // Down
                {
                    if (toc_cursor + 1 < (int)toc.size) { toc_cursor++; need_redraw = true; }
                }
                else if (key == 'k' || key == 1001) // Up
                {
                    if (toc_cursor > 0) { toc_cursor--; need_redraw = true; }
                }
                else if (key == 'g' || key == 1008) // Top
                {
                    toc_cursor = 0;
                    need_redraw = true;
                }
                else if (key == 'G' || key == 1009) // Bottom
                {
                    toc_cursor = (int)toc.size > 0 ? (int)toc.size - 1 : 0;
                    need_redraw = true;
                }
                else if (key == 10) // Enter -> Jump to heading
                {
                    if (toc_cursor < (int)toc.size)
                    {
                        cursor_line = toc.entries[toc_cursor].visual_line;
                        scroll_top = cursor_line;
                        if (scroll_top > max_scroll) scroll_top = max_scroll;
                        if (scroll_top < 0) scroll_top = 0;
                    }
                    show_toc = false;
                    need_redraw = true;
                }
                continue;
            }

            // ── File Tree Mode ────────────────────────────────────────────
            if (show_files)
            {
                int[128] vis_idx;
                int vis_count = 0;

                int[16] collapse_depth;
                int collapse_count = 0;

                for (usz i = 0; i < file_tree.count; i++)
                {
                    terminal::TreeNode* node = &file_tree.nodes[i];
                    while (collapse_count > 0 && collapse_depth[collapse_count - 1] >= node.depth)
                    {
                        collapse_count--;
                    }

                    if (collapse_count == 0 && vis_count < 128)
                    {
                        vis_idx[vis_count++] = (int)i;
                    }

                    if (node.is_dir && !node.is_expanded && collapse_count < 15)
                    {
                        collapse_depth[collapse_count++] = node.depth;
                    }
                }

                if (key == 27 || key == 'o' || key == 'O' || key == 'q')
                {
                    show_files = false;
                    need_redraw = true;
                }
                else if (key == 'j' || key == 1000) // Down
                {
                    if (file_cursor + 1 < vis_count) { file_cursor++; need_redraw = true; }
                }
                else if (key == 'k' || key == 1001) // Up
                {
                    if (file_cursor > 0) { file_cursor--; need_redraw = true; }
                }
                else if (key == 'g' || key == 1008) // Top of tree
                {
                    file_cursor = 0;
                    need_redraw = true;
                }
                else if (key == 'G' || key == 1009) // Bottom of tree
                {
                    file_cursor = vis_count > 0 ? vis_count - 1 : 0;
                    need_redraw = true;
                }
                else if (key == 'a' || key == 'A') // Toggle all folders
                {
                    bool any_expanded = false;
                    for (usz i = 0; i < file_tree.count; i++)
                    {
                        if (file_tree.nodes[i].is_dir && file_tree.nodes[i].is_expanded)
                        {
                            any_expanded = true;
                            break;
                        }
                    }

                    bool target_state = !any_expanded;
                    for (usz i = 0; i < file_tree.count; i++)
                    {
                        if (file_tree.nodes[i].is_dir && !strutils::str_eq(&file_tree.nodes[i].name[0], ".."))
                        {
                            file_tree.nodes[i].is_expanded = target_state;
                        }
                    }
                    need_redraw = true;
                }
                else if (key == 1006 || key == 'h' || key == 'H') // Left arrow -> Collapse or jump to parent
                {
                    if (file_cursor < vis_count)
                    {
                        int node_idx = vis_idx[file_cursor];
                        terminal::TreeNode* sel = &file_tree.nodes[node_idx];
                        if (sel.is_dir && sel.is_expanded)
                        {
                            sel.is_expanded = false;
                        }
                        else if (sel.depth > 0)
                        {
                            for (int p = file_cursor - 1; p >= 0; p--)
                            {
                                int p_idx = vis_idx[p];
                                if (file_tree.nodes[p_idx].is_dir && file_tree.nodes[p_idx].depth < sel.depth)
                                {
                                    file_cursor = p;
                                    break;
                                }
                            }
                        }
                        need_redraw = true;
                    }
                }
                else if (key == 1007 || key == 'l' || key == 'L') // Right arrow -> Expand or step into child
                {
                    if (file_cursor < vis_count)
                    {
                        int node_idx = vis_idx[file_cursor];
                        terminal::TreeNode* sel = &file_tree.nodes[node_idx];
                        if (sel.is_dir)
                        {
                            if (!sel.is_expanded)
                            {
                                sel.is_expanded = true;
                            }
                            else if (file_cursor + 1 < vis_count)
                            {
                                file_cursor++;
                            }
                            need_redraw = true;
                        }
                    }
                }
                else if (key == ' ') // Space -> Toggle expand/collapse
                {
                    if (file_cursor < vis_count)
                    {
                        int node_idx = vis_idx[file_cursor];
                        terminal::TreeNode* sel = &file_tree.nodes[node_idx];
                        if (sel.is_dir)
                        {
                            sel.is_expanded = !sel.is_expanded;
                            need_redraw = true;
                        }
                    }
                }
                else if (key == 10 || key == 13) // Enter -> Open file or CD into folder
                {
                    if (file_cursor < vis_count)
                    {
                        int node_idx = vis_idx[file_cursor];
                        terminal::TreeNode* sel = &file_tree.nodes[node_idx];
                        if (sel.is_dir)
                        {
                            terminal::chdir(&sel.path[0]);
                            terminal::scan_file_tree(&cur_filename[0], &file_tree);
                            file_cursor = 0;
                            need_redraw = true;
                        }
                        else
                        {
                            char* new_path = &sel.path[0];
                            char* new_c = strutils::load_file_string(new_path);
                            if (new_c != null)
                            {
                                if (prev_content != null) mem::free(prev_content);
                                prev_content = new_c;
                                strutils::copy_str(&cur_filename[0], new_path, 256);
                                filename = &cur_filename[0];
                                doc.free();
                                vdoc.free();
                                content_str = (String)new_c[:strutils::str_len(new_c)];
                                doc = parser::parse_document(content_str);
                                vdoc = render::render_document(&doc, config);
                                extract_toc(&doc, &vdoc, &toc);
                                total_lines = vdoc.get_total_lines();
                                max_scroll = total_lines > 0 ? total_lines - 1 : 0;
                                scroll_top = 0;
                                cursor_line = 0;
                                terminal::get_file_state(filename, &prev_state);

                                char[128] sw_msg;
                                strutils::copy_str(&sw_msg[0], "✔ Switched to ", 128);
                                strutils::append_str(&sw_msg[0], filename, 128);
                                strutils::copy_str(&status_msg_buf[0], &sw_msg[0], 128);
                                status_ticks = 40;
                            }
                            show_files = false;
                            need_redraw = true;
                        }
                    }
                }
                continue;
            }

            // ── Normal Navigation Mode ────────────────────────────────────
            if (key == 'q' || key == 'Q' || key == 0x03)
            {
                if (prev_content != null) mem::free(prev_content);
                doc.free();
                vdoc.free();
                return;
            }
            else if (key == 27) // Esc in normal mode: clear search highlights without quitting
            {
                if (match_lines.size > 0 || search_len > 0)
                {
                    match_lines.clear();
                    cur_match_idx = 0;
                    search_len = 0;
                    search_buf[0] = 0;
                    status_msg_buf[0] = 0;
                    need_redraw = true;
                }
            }
            else if (key == 'j' || key == 1000) // Down (with acceleration)
            {
                int step = get_accelerated_step(&velocity, 1, false);
                cursor_line += step;
                if (cursor_line >= total_lines) cursor_line = total_lines > 0 ? total_lines - 1 : 0;
                int scrolloff = view_height > 6 ? 2 : 0;
                if (cursor_line + scrolloff >= scroll_top + view_height)
                {
                    scroll_top = cursor_line + scrolloff - view_height + 1;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                }
                need_redraw = true;
            }
            else if (key == 'k' || key == 1001) // Up (with acceleration)
            {
                int step = get_accelerated_step(&velocity, -1, false);
                cursor_line -= step;
                if (cursor_line < 0) cursor_line = 0;
                int scrolloff = view_height > 6 ? 2 : 0;
                if (cursor_line - scrolloff < scroll_top)
                {
                    scroll_top = cursor_line - scrolloff;
                    if (scroll_top < 0) scroll_top = 0;
                }
                need_redraw = true;
            }
            else if (key == 1012) // Mouse Wheel Up (with acceleration)
            {
                int step = get_accelerated_step(&velocity, -1, true);
                scroll_top -= step;
                if (scroll_top < 0) scroll_top = 0;
                cursor_line -= step;
                if (cursor_line < 0) cursor_line = 0;
                if (cursor_line < scroll_top) cursor_line = scroll_top;
                if (cursor_line >= scroll_top + view_height) cursor_line = scroll_top + view_height - 1;
                need_redraw = true;
            }
            else if (key == 1013) // Mouse Wheel Down (with acceleration)
            {
                int step = get_accelerated_step(&velocity, 1, true);
                scroll_top += step;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                cursor_line += step;
                if (cursor_line >= total_lines) cursor_line = total_lines > 0 ? total_lines - 1 : 0;
                if (cursor_line < scroll_top) cursor_line = scroll_top;
                if (cursor_line >= scroll_top + view_height) cursor_line = scroll_top + view_height - 1;
                need_redraw = true;
            }
            else if (key == 1006 || key == 'h' || key == 'H') // Left arrow
            {
                if (no_wrap && scroll_left > 0)
                {
                    scroll_left -= 4;
                    if (scroll_left < 0) scroll_left = 0;
                    need_redraw = true;
                }
            }
            else if (key == 1007 || key == 'l' || key == 'L') // Right arrow
            {
                if (no_wrap)
                {
                    scroll_left += 4;
                    need_redraw = true;
                }
            }
            else if (key == 'w' || key == 'W') // Toggle wrap / no-wrap
            {
                no_wrap = !no_wrap;
                scroll_left = 0;
                vdoc.free();
                config.no_wrap = no_wrap;
                vdoc = render::render_document(&doc, config);
                extract_toc(&doc, &vdoc, &toc);
                total_lines = vdoc.get_total_lines();
                max_scroll = total_lines > 0 ? total_lines - 1 : 0;
                strutils::copy_str(&status_msg_buf[0], no_wrap ? "No-Wrap Mode (← / → to scroll)" : "Wrap Mode Active", 128);
                status_ticks = 40;
                need_redraw = true;
            }
            else if (key == 'd' || key == 1004) // Half page down
            {
                cursor_line += view_height / 2;
                if (cursor_line >= total_lines) cursor_line = total_lines > 0 ? total_lines - 1 : 0;
                scroll_top += view_height / 2;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == 'u' || key == 1005) // Half page up
            {
                cursor_line -= view_height / 2;
                if (cursor_line < 0) cursor_line = 0;
                scroll_top -= view_height / 2;
                if (scroll_top < 0) scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 1002 || key == ' ') // Full page down (Space / PgDn / Ctrl+F)
            {
                cursor_line += view_height - 2;
                if (cursor_line >= total_lines) cursor_line = total_lines > 0 ? total_lines - 1 : 0;
                scroll_top += view_height - 2;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == 1003) // Full page up (PgUp / Ctrl+B)
            {
                cursor_line -= view_height - 2;
                if (cursor_line < 0) cursor_line = 0;
                scroll_top -= view_height - 2;
                if (scroll_top < 0) scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 'g' || key == 1008) // Top
            {
                cursor_line = 0;
                scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 'G' || key == 1009) // Bottom
            {
                cursor_line = total_lines > 0 ? total_lines - 1 : 0;
                scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == '?' || key == 31 || key == 0x1F) // ? / Ctrl+? -> Help
            {
                show_help = true;
                need_redraw = true;
            }
            else if (key == 9 || key == 't' || key == 'T') // Tab / 't' -> Open TOC outline
            {
                show_toc = true;
                need_redraw = true;
            }
            else if (key == 'o' || key == 'O') // 'o' -> Open File Tree Switcher
            {
                terminal::scan_file_tree(&cur_filename[0], &file_tree);
                file_cursor = 0;
                int[16] collapse_depth;
                int collapse_count = 0;
                int v_count = 0;
                for (usz f = 0; f < file_tree.count; f++)
                {
                    terminal::TreeNode* node = &file_tree.nodes[f];
                    while (collapse_count > 0 && collapse_depth[collapse_count - 1] >= node.depth) collapse_count--;
                    if (collapse_count == 0)
                    {
                        if (node.is_current) { file_cursor = v_count; break; }
                        v_count++;
                    }
                    if (node.is_dir && !node.is_expanded && collapse_count < 15) collapse_depth[collapse_count++] = node.depth;
                }
                show_files = true;
                need_redraw = true;
            }
            else if (key == '/') // Search
            {
                search_mode = true;
                search_len = 0;
                search_buf[0] = 0;
                need_redraw = true;
            }
            else if (key == 'n') // Next search match
            {
                if (match_lines.size > 0)
                {
                    cur_match_idx = (cur_match_idx + 1) % (int)match_lines.size;
                    cursor_line = match_lines.entries[cur_match_idx];
                    scroll_top = cursor_line - view_height / 3;
                    if (scroll_top < 0) scroll_top = 0;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                    need_redraw = true;
                }
            }
            else if (key == 'N') // Prev search match
            {
                if (match_lines.size > 0)
                {
                    cur_match_idx = (cur_match_idx - 1 + (int)match_lines.size) % (int)match_lines.size;
                    cursor_line = match_lines.entries[cur_match_idx];
                    scroll_top = cursor_line - view_height / 3;
                    if (scroll_top < 0) scroll_top = 0;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                    need_redraw = true;
                }
            }
            else if (key == ':') // Goto line
            {
                goto_mode = true;
                goto_len = 0;
                goto_buf[0] = 0;
                need_redraw = true;
            }
            else if (key == 'e' || key == 'E') // Open editor at current line
            {
                int cur_src = (cursor_line >= 0 && cursor_line < (int)vdoc.lines.len && vdoc.lines[cursor_line].src_line >= 0) ? vdoc.lines[cursor_line].src_line + 1 : 1;
                terminal::open_editor_at_line(filename, cur_src);

                char* new_c = strutils::load_file_string(filename);
                if (new_c != null)
                {
                    if (prev_content != null) mem::free(prev_content);
                    prev_content = new_c;
                    doc.free();
                    vdoc.free();
                    content_str = (String)new_c[:strutils::str_len(new_c)];
                    doc = parser::parse_document(content_str);
                    vdoc = render::render_document(&doc, config);
                    extract_toc(&doc, &vdoc, &toc);
                    total_lines = vdoc.get_total_lines();
                    max_scroll = total_lines > 0 ? total_lines - 1 : 0;
                    cursor_line = vdoc.find_visual_line(cur_src - 1);
                    scroll_top = cursor_line - view_height / 3;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                    if (scroll_top < 0) scroll_top = 0;
                    terminal::get_file_state(filename, &prev_state);
                }

                strutils::copy_str(&status_msg_buf[0], "✔ Resumed from Editor", 128);
                status_ticks = 40;
                need_redraw = true;
            }
            else if (key == 'y' || key == 'Y') // Copy document to clipboard
            {
                if (prev_content != null)
                {
                    copy_to_clipboard_osc52(prev_content, strutils::str_len(prev_content));
                    strutils::copy_str(&status_msg_buf[0], "✔ Copied document to clipboard (OSC 52)", 128);
                    status_ticks = 40;
                    need_redraw = true;
                }
            }
        }

        // Check for window resize
        int cur_width = terminal::get_width();
        int cur_height = terminal::get_height();
        if (cur_width != width || cur_height != height)
        {
            width = cur_width;
            height = cur_height;
            view_height = height - 3;
            if (view_height < 2) view_height = 2;

            config.width = width;
            vdoc.free();
            vdoc = render::render_document(&doc, config);
            extract_toc(&doc, &vdoc, &toc);
            total_lines = vdoc.get_total_lines();
            max_scroll = total_lines > 0 ? total_lines - 1 : 0;
            if (scroll_top > max_scroll) scroll_top = max_scroll;
            need_redraw = true;
        }

        // Check for file updates on disk
        terminal::FileState curr_state;
        bool state_ok = terminal::get_file_state(filename, &curr_state);

        if (state_ok && terminal::file_has_changed(&prev_state, &curr_state))
        {
            prev_state = curr_state;

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
                extract_toc(&doc, &vdoc, &toc);

                total_lines = vdoc.get_total_lines();
                max_scroll = total_lines > 0 ? total_lines - 1 : 0;

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

        if (need_redraw)
        {
            int active_line = (match_lines.size > 0 && cur_match_idx < (int)match_lines.size) ? match_lines.entries[cur_match_idx] : -1;
            draw_viewport(&fb, &vdoc, scroll_top, scroll_left, view_height, &cur_filename[0], last_changed_line, width, &status_msg_buf[0], search_mode, &search_buf[0], (int)match_lines.size, cur_match_idx, active_line, show_toc, &toc, toc_cursor, show_help, no_wrap, goto_mode, &goto_buf[0], cursor_line, show_files, &file_tree, file_cursor);
        }

        // Wait up to 30ms for keyboard/terminal input event; if timeout, loop checks file state
        terminal::wait_for_input(30);
    }
}
