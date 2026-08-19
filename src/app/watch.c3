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

fn void FrameBuffer.append_char(FrameBuffer* fb, char c)
{
    if (fb.len < fb.cap - 1)
    {
        fb.buf[fb.len++] = c;
    }
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

struct TocItem {
    int level;
    String title;
    int src_line;
    int visual_line;
}

struct TocList {
    TocItem[64] items;
    usz count;
}

fn void extract_toc(ast::Document* doc, layout::VisualDocument* vdoc, TocList* toc)
{
    toc.count = 0;
    int total_lines = vdoc.get_total_lines();
    for (usz i = 0; i < doc.blocks.len && toc.count < 64; i++)
    {
        ast::Block* b = &doc.blocks[i];
        if (b.kind == ast::BlockKind.HEADING)
        {
            // Build plain title
            char[256] tbuf;
            int tp = 0;
            for (usz s = 0; s < b.heading.spans.len; s++)
            {
                String sp_txt = b.heading.spans[s].text;
                for (usz c = 0; c < (usz)sp_txt.len && tp < 250; c++)
                {
                    tbuf[tp++] = sp_txt[c];
                }
            }
            tbuf[tp] = 0;
            String title_str = vdoc.arena.dup_string((String)tbuf[:tp]);

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
            toc.items[toc.count++] = item;
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

fn void append_with_search_highlight(FrameBuffer* fb, String line, String query, bool is_cur_match_line)
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
                    fb.append_str("\x1b[48;2;166;226;46m\x1b[38;2;0;0;0m\x1b[1m");
                }
                else
                {
                    fb.append_str("\x1b[48;2;253;151;31m\x1b[38;2;0;0;0m\x1b[1m");
                }

                for (usz k = 0; k < qlen; k++)
                {
                    fb.append_char(line[p++]);
                }
                fb.append_str("\x1b[0m");
                continue;
            }
        }

        fb.append_char(line[p++]);
    }
}

fn void append_horizontal_slice(FrameBuffer* fb, String line, int scroll_left, int max_w)
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

fn void draw_viewport(FrameBuffer* fb, layout::VisualDocument* vdoc, int scroll_top, int scroll_left, int view_height, char* filename, int changed_src_line, int term_width, char* status_msg, bool search_active, char* search_query, int match_count, int cur_match_idx, int cur_match_line, bool show_toc, TocList* toc, int toc_cursor, bool show_help, bool no_wrap)
{
    fb.len = 0;

    // Disable line wrap and move cursor to top-left (1,1)
    fb.append_str("\x1b[?7l\x1b[H");

    // ── Help Modal View ───────────────────────────────────────────────
    if (show_help)
    {
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
        fb.append_str(filename);
        fb.append_str(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m \x1b[38;2;253;151;31m\x1b[1mKeyboard Controls & Keybindings\x1b[0m\x1b[K\n");

        // Separator line
        fb.append_str("\x1b[38;2;117;113;94m");
        for (int k = 0; k < term_width - 2 && k < 120; k++) fb.append_str("─");
        fb.append_str("\x1b[0m\x1b[K\n");

        char*[18] help_rows = {
            "\x1b[38;2;102;217;239m\x1b[1mVertical Navigation:\x1b[0m",
            "  \x1b[38;2;230;219;116mj / ↓\x1b[0m                 Scroll down 1 line",
            "  \x1b[38;2;230;219;116mk / ↑\x1b[0m                 Scroll up 1 line",
            "  \x1b[38;2;230;219;116md / Ctrl+D\x1b[0m            Half page down",
            "  \x1b[38;2;230;219;116mu / Ctrl+U\x1b[0m            Half page up",
            "  \x1b[38;2;230;219;116mSpace / Ctrl+F\x1b[0m        Full page down",
            "  \x1b[38;2;230;219;116mCtrl+B\x1b[0m                Full page up",
            "  \x1b[38;2;230;219;116mg / G\x1b[0m                 Jump to Top / Bottom",
            "",
            "\x1b[38;2;102;217;239m\x1b[1mHorizontal & Layout:\x1b[0m",
            "  \x1b[38;2;230;219;116mw\x1b[0m                     Toggle Wrap / No-Wrap mode",
            "  \x1b[38;2;230;219;116mh / l / ← / →\x1b[0m         Horizontal scroll in no-wrap mode",
            "",
            "\x1b[38;2;102;217;239m\x1b[1mFeatures & Actions:\x1b[0m",
            "  \x1b[38;2;166;226;46mTab / t\x1b[0m               Document Outline (Table of Contents)",
            "  \x1b[38;2;166;226;46m/\x1b[0m                     In-document search (n next, N prev)",
            "  \x1b[38;2;166;226;46my\x1b[0m                     Copy document to clipboard (OSC 52)",
            "  \x1b[38;2;166;226;46m?\x1b[0m                     Show / hide this help screen"
        };

        for (int r = 0; r < view_height; r++)
        {
            if (r < 18)
            {
                fb.append_str("  ");
                fb.append_str(help_rows[r]);
            }
            else
            {
                fb.append_str("\x1b[38;2;60;60;50m~\x1b[0m");
            }
            fb.append_str("\x1b[K\n");
        }

        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m Help \x1b[0m\x1b[38;2;117;113;94m [Press ?, Esc, or q to return to document]\x1b[0m\x1b[K");
        fb.flush();
        return;
    }

    // ── Table of Contents (Outline) View ──────────────────────────────
    if (show_toc)
    {
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m mdview \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m ");
        fb.append_str(filename);
        fb.append_str(" \x1b[0m\x1b[38;2;117;113;94m│\x1b[0m \x1b[38;2;166;226;46m\x1b[1mDocument Outline (Table of Contents)\x1b[0m\x1b[K\n");

        // Separator line
        fb.append_str("\x1b[38;2;117;113;94m");
        for (int k = 0; k < term_width - 2 && k < 120; k++) fb.append_str("─");
        fb.append_str("\x1b[0m\x1b[K\n");

        int toc_total = (toc != null) ? (int)toc.count : 0;

        for (int r = 0; r < view_height; r++)
        {
            if (r < toc_total)
            {
                TocItem item = toc.items[r];
                bool is_cur = (r == toc_cursor);

                if (is_cur)
                {
                    fb.append_str("  \x1b[48;2;49;50;68m\x1b[38;2;166;226;46m\x1b[1m▶ ");
                }
                else
                {
                    fb.append_str("    ");
                }

                // Indent by level
                for (int lv = 1; lv < item.level && lv < 5; lv++) fb.append_str("   ");

                if (is_cur)
                {
                    fb.append_str("\x1b[38;2;248;248;242m\x1b[1m");
                }
                else
                {
                    switch (item.level)
                    {
                        case 1: fb.append_str("\x1b[38;2;249;38;114m\x1b[1m");
                        case 2: fb.append_str("\x1b[38;2;166;226;46m\x1b[1m");
                        case 3: fb.append_str("\x1b[38;2;253;151;31m\x1b[1m");
                        case 4: fb.append_str("\x1b[38;2;230;219;116m\x1b[1m");
                        default: fb.append_str("\x1b[38;2;102;217;239m\x1b[1m");
                    }
                }

                fb.append_slice(item.title);
                fb.append_str("\x1b[0m");

                fb.append_str(" \x1b[38;2;117;113;94m(Line ");
                fb.append_int(item.src_line + 1);
                fb.append_str(")\x1b[0m");
            }
            else
            {
                fb.append_str("\x1b[38;2;60;60;50m~\x1b[0m");
            }
            fb.append_str("\x1b[K\n");
        }

        // Bottom status line
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m Outline \x1b[0m\x1b[38;2;117;113;94m [j/k: Navigate | Enter: Jump to section | Tab/Esc/q: Return to Document]\x1b[0m\x1b[K");
        fb.flush();
        return;
    }

    // ── Normal Document View ──────────────────────────────────────────
    int total = vdoc.get_total_lines();
    int end_idx = scroll_top + view_height;
    if (end_idx > total) end_idx = total;

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
    fb.append_str("\x1b[0m\x1b[K\n");

    // Separator line
    fb.append_str("\x1b[38;2;117;113;94m");
    for (int k = 0; k < term_width - 2 && k < 120; k++) fb.append_str("─");
    fb.append_str("\x1b[0m\x1b[K\n");

    // Visual document lines
    String q_str = (search_query != null) ? (String)search_query[:strutils::str_len(search_query)] : "";

    for (int i = scroll_top; i < scroll_top + view_height; i++)
    {
        if (i < total)
        {
            bool is_cur_line = (i == cur_match_line);
            if (q_str.len > 0 && (search_active || match_count > 0))
            {
                append_with_search_highlight(fb, vdoc.lines[i].text, q_str, is_cur_line);
            }
            else
            {
                append_horizontal_slice(fb, vdoc.lines[i].text, scroll_left, term_width);
            }
            fb.append_str("\x1b[K\n");
        }
        else
        {
            fb.append_str("\x1b[38;2;60;60;50m~\x1b[0m\x1b[K\n");
        }
    }

    // Bottom Status / Search Bar
    if (search_active)
    {
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;253;151;31m\x1b[1m / \x1b[0m\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m ");
        fb.append_str(search_query);
        fb.append_str(" \x1b[0m\x1b[38;2;117;113;94m (Enter: Search, Esc: Cancel)\x1b[0m\x1b[K");
    }
    else if (match_count > 0)
    {
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m Match ");
        fb.append_int(cur_match_idx + 1);
        fb.append_str(" of ");
        fb.append_int(match_count);
        fb.append_str(" \x1b[0m\x1b[38;2;117;113;94m (n: Next, N: Prev, Esc: Clear)\x1b[0m\x1b[K");
    }
    else if (status_msg != null && status_msg[0] != 0)
    {
        fb.append_str("\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m ");
        fb.append_str(status_msg);
        fb.append_str(" \x1b[0m\x1b[K");
    }
    else if (no_wrap)
    {
        fb.append_str("\x1b[38;2;117;113;94m[? help | w wrap | ←/→ scroll | / search | Tab outline | q quit]\x1b[0m\x1b[K");
    }
    else
    {
        fb.append_str("\x1b[38;2;117;113;94m[? help | w no-wrap | / search | Tab outline | y copy | q quit]\x1b[0m\x1b[K");
    }

    fb.flush();
}

fn void run_watch(char* filename, int initial_line, bool initial_no_wrap = false)
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
    config.no_wrap = no_wrap;

    String content_str = (String)content[:strutils::str_len(content)];
    ast::Document doc = parser::parse_document(content_str);
    layout::VisualDocument vdoc = render::render_document(&doc, config);

    TocList toc;
    extract_toc(&doc, &vdoc, &toc);

    int total_lines = vdoc.get_total_lines();
    int max_scroll = total_lines > 0 ? total_lines - 1 : 0;

    if (initial_line > 0)
    {
        int v_line = vdoc.find_visual_line(initial_line - 1);
        int context_offset = view_height / 3;
        if (context_offset < 5) context_offset = 5;
        scroll_top = v_line - context_offset;
        if (scroll_top < 0) scroll_top = 0;
        if (scroll_top > max_scroll) scroll_top = max_scroll;
    }

    // TUI state
    bool show_toc = false;
    int toc_cursor = 0;
    bool show_help = false;

    bool search_mode = false;
    char[128] search_buf;
    int search_len = 0;
    search_buf[0] = 0;

    int[128] match_lines;
    int match_count = 0;
    int cur_match_idx = 0;

    char[128] status_msg_buf;
    status_msg_buf[0] = 0;
    int status_ticks = 0;

    int cur_match_line = (match_count > 0 && cur_match_idx < match_count) ? match_lines[cur_match_idx] : -1;
    draw_viewport(&fb, &vdoc, scroll_top, scroll_left, view_height, filename, last_changed_line, width, &status_msg_buf[0], search_mode, &search_buf[0], match_count, cur_match_idx, cur_match_line, show_toc, &toc, toc_cursor, show_help, no_wrap);
    prev_content = content;
    terminal::get_file_state(filename, &prev_state);

    int idle_tick = 0;

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
                    match_count = 0;
                    cur_match_idx = 0;

                    if (search_len > 0)
                    {
                        String query = (String)search_buf[:search_len];
                        for (int i = 0; i < total_lines && match_count < 128; i++)
                        {
                            if (strutils::string_contains(vdoc.lines[i].text, query))
                            {
                                match_lines[match_count++] = i;
                            }
                        }
                        if (match_count > 0)
                        {
                            scroll_top = match_lines[0] - view_height / 3;
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
                    if (toc_cursor + 1 < (int)toc.count) { toc_cursor++; need_redraw = true; }
                }
                else if (key == 'k' || key == 1001) // Up
                {
                    if (toc_cursor > 0) { toc_cursor--; need_redraw = true; }
                }
                else if (key == 10) // Enter -> Jump to heading
                {
                    if (toc_cursor < (int)toc.count)
                    {
                        scroll_top = toc.items[toc_cursor].visual_line;
                        if (scroll_top > max_scroll) scroll_top = max_scroll;
                        if (scroll_top < 0) scroll_top = 0;
                    }
                    show_toc = false;
                    need_redraw = true;
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
                if (match_count > 0 || search_len > 0)
                {
                    match_count = 0;
                    cur_match_idx = 0;
                    search_len = 0;
                    search_buf[0] = 0;
                    status_msg_buf[0] = 0;
                    need_redraw = true;
                }
            }
            else if (key == 'j' || key == 1000) // Down
            {
                if (scroll_top < max_scroll) { scroll_top++; need_redraw = true; }
            }
            else if (key == 'k' || key == 1001) // Up
            {
                if (scroll_top > 0) { scroll_top--; need_redraw = true; }
            }
            else if (key == 1012) // Mouse Wheel Up
            {
                scroll_top -= 3;
                if (scroll_top < 0) scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 1013) // Mouse Wheel Down
            {
                scroll_top += 3;
                if (scroll_top > max_scroll) scroll_top = max_scroll;
                need_redraw = true;
            }
            else if (key == 1006 || key == 'h' || key == 'H') // Left arrow
            {
                if (scroll_left > 0)
                {
                    scroll_left -= 4;
                    if (scroll_left < 0) scroll_left = 0;
                    need_redraw = true;
                }
            }
            else if (key == 1007 || key == 'l' || key == 'L') // Right arrow
            {
                scroll_left += 4;
                need_redraw = true;
            }
            else if (key == 'w' || key == 'W') // Toggle wrap / no-wrap
            {
                no_wrap = !no_wrap;
                scroll_left = 0;
                doc.free();
                vdoc.free();
                config.no_wrap = no_wrap;
                doc = parser::parse_document(content_str);
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
            else if (key == 1002 || key == ' ') // Full page down (Space / PgDn / Ctrl+F)
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
            else if (key == 'g' || key == 1008) // Top
            {
                scroll_top = 0;
                need_redraw = true;
            }
            else if (key == 'G' || key == 1009) // Bottom
            {
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
            else if (key == '/') // Search
            {
                search_mode = true;
                search_len = 0;
                search_buf[0] = 0;
                need_redraw = true;
            }
            else if (key == 'n') // Next search match
            {
                if (match_count > 0)
                {
                    cur_match_idx = (cur_match_idx + 1) % match_count;
                    scroll_top = match_lines[cur_match_idx] - view_height / 3;
                    if (scroll_top < 0) scroll_top = 0;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                    need_redraw = true;
                }
            }
            else if (key == 'N') // Prev search match
            {
                if (match_count > 0)
                {
                    cur_match_idx = (cur_match_idx - 1 + match_count) % match_count;
                    scroll_top = match_lines[cur_match_idx] - view_height / 3;
                    if (scroll_top < 0) scroll_top = 0;
                    if (scroll_top > max_scroll) scroll_top = max_scroll;
                    need_redraw = true;
                }
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
                view_height = height - 3;
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
        }

        if (need_redraw)
        {
            int active_line = (match_count > 0 && cur_match_idx < match_count) ? match_lines[cur_match_idx] : -1;
            draw_viewport(&fb, &vdoc, scroll_top, scroll_left, view_height, filename, last_changed_line, width, &status_msg_buf[0], search_mode, &search_buf[0], match_count, cur_match_idx, active_line, show_toc, &toc, toc_cursor, show_help, no_wrap);
        }

        terminal::sleep_ms(12);
    }
}
