module terminal;

import std::io;
import strutils;

struct WinSize {
    ushort ws_row;
    ushort ws_col;
    ushort ws_xpixel;
    ushort ws_ypixel;
}

struct Stat {
    ulong  st_dev;
    ulong  st_ino;
    ulong  st_nlink;
    uint   st_mode;
    uint   st_uid;
    uint   st_gid;
    uint   __pad0;
    ulong  st_rdev;
    long   st_size;
    long   st_blksize;
    long   st_blocks;
    long   st_atime;
    ulong  st_atime_nsec;
    long   st_mtime;
    ulong  st_mtime_nsec;
    long   st_ctime;
    ulong  st_ctime_nsec;
    long[3] __glibc_reserved;
}

struct FileState {
    ulong inode;
    long size;
    long mtime;
    ulong mtime_nsec;
}

struct Termios {
    uint c_iflag;
    uint c_oflag;
    uint c_cflag;
    uint c_lflag;
    char c_line;
    char[32] c_cc;
    uint c_ispeed;
    uint c_ospeed;
}

extern fn int ioctl(int fd, ulong request, ...);
extern fn int isatty(int fd);
extern fn char* getenv(char* name);
extern fn int stat(char* path, Stat* buf);
extern fn int usleep(uint usec);
extern fn int tcgetattr(int fd, Termios* termios_p);
extern fn int tcsetattr(int fd, int optional_actions, Termios* termios_p);
extern fn int read(int fd, void* buf, ulong count);
extern fn int write(int fd, void* buf, ulong count);
extern fn int system(char* command);
extern fn char* getcwd(char* buf, ulong size);
extern fn int chdir(char* path);

struct Dirent {
    ulong d_ino;
    long d_off;
    ushort d_reclen;
    char d_type;
    char[256] d_name;
}

extern fn void* opendir(char* name);
extern fn Dirent* readdir(void* dirp);
extern fn int closedir(void* dirp);

struct TreeNode {
    char[128] path;
    char[64] name;
    int depth;
    bool is_dir;
    bool is_expanded;
    bool is_current;
    bool is_last;
}

struct FileTree {
    TreeNode[128] nodes;
    usz count;
}

fn bool dir_has_markdown(char* dir_path, int depth_limit)
{
    if (depth_limit <= 0) return false;
    void* d = opendir(dir_path);
    if (d == null) return false;

    Dirent* ent = null;
    bool found = false;
    while ((ent = readdir(d)) != null)
    {
        char* name = &ent.d_name[0];
        if (name[0] == '.') continue;
        if (strutils::str_ends_with(name, ".md") || strutils::str_ends_with(name, ".markdown"))
        {
            found = true;
            break;
        }
        if (ent.d_type == 4)
        {
            if (strutils::str_eq(name, "build") || strutils::str_eq(name, "node_modules") || strutils::str_eq(name, "target") || strutils::str_eq(name, ".git") || strutils::str_eq(name, "dist") || strutils::str_eq(name, ".cache"))
            {
                continue;
            }
            char[128] sub_path;
            strutils::copy_str(&sub_path[0], dir_path, 128);
            strutils::append_str(&sub_path[0], "/", 128);
            strutils::append_str(&sub_path[0], name, 128);
            if (dir_has_markdown(&sub_path[0], depth_limit - 1))
            {
                found = true;
                break;
            }
        }
    }
    closedir(d);
    return found;
}

fn void scan_tree_recursive(
    char* dir_path,
    int depth,
    int max_depth,
    char* current_file,
    FileTree* tree
)
{
    if (tree.count >= 120 || depth > max_depth) return;

    void* d = opendir(dir_path);
    if (d == null) return;

    Dirent[64] dir_entries;
    int dir_count = 0;
    Dirent[64] file_entries;
    int file_count = 0;

    Dirent* ent = null;
    while ((ent = readdir(d)) != null)
    {
        char* name = &ent.d_name[0];
        if (name[0] == '.') continue;

        if (ent.d_type == 4)
        {
            if (strutils::str_eq(name, "build") || strutils::str_eq(name, "node_modules") || strutils::str_eq(name, "target") || strutils::str_eq(name, ".git") || strutils::str_eq(name, "dist") || strutils::str_eq(name, ".cache"))
            {
                continue;
            }
            char[128] sub_path;
            if (strutils::str_eq(dir_path, "."))
            {
                strutils::copy_str(&sub_path[0], name, 128);
            }
            else
            {
                strutils::copy_str(&sub_path[0], dir_path, 128);
                strutils::append_str(&sub_path[0], "/", 128);
                strutils::append_str(&sub_path[0], name, 128);
            }
            if (dir_has_markdown(&sub_path[0], 4) && dir_count < 60)
            {
                dir_entries[dir_count++] = *ent;
            }
        }
        else if ((strutils::str_ends_with(name, ".md") || strutils::str_ends_with(name, ".markdown")) && file_count < 60)
        {
            file_entries[file_count++] = *ent;
        }
    }
    closedir(d);

    int total_entries = dir_count + file_count;
    int cur_entry = 0;

    // List files at current depth
    for (int i = 0; i < file_count && tree.count < 120; i++)
    {
        cur_entry++;
        char* name = &file_entries[i].d_name[0];
        char[128] rel_path;
        if (strutils::str_eq(dir_path, "."))
        {
            strutils::copy_str(&rel_path[0], name, 128);
        }
        else
        {
            strutils::copy_str(&rel_path[0], dir_path, 128);
            strutils::append_str(&rel_path[0], "/", 128);
            strutils::append_str(&rel_path[0], name, 128);
        }

        TreeNode* node = &tree.nodes[tree.count++];
        strutils::copy_str(&node.path[0], &rel_path[0], 128);
        strutils::copy_str(&node.name[0], name, 64);
        node.depth = depth;
        node.is_dir = false;
        node.is_expanded = false;
        node.is_last = (cur_entry == total_entries);
        node.is_current = (current_file != null && (strutils::str_eq(&rel_path[0], current_file) || strutils::str_eq(name, current_file)));
    }

    // List directories at current depth
    for (int i = 0; i < dir_count && tree.count < 120; i++)
    {
        cur_entry++;
        char* name = &dir_entries[i].d_name[0];
        char[128] rel_path;
        if (strutils::str_eq(dir_path, "."))
        {
            strutils::copy_str(&rel_path[0], name, 128);
        }
        else
        {
            strutils::copy_str(&rel_path[0], dir_path, 128);
            strutils::append_str(&rel_path[0], "/", 128);
            strutils::append_str(&rel_path[0], name, 128);
        }

        TreeNode* node = &tree.nodes[tree.count++];
        strutils::copy_str(&node.path[0], &rel_path[0], 128);
        strutils::copy_str(&node.name[0], name, 64);
        node.depth = depth;
        node.is_dir = true;
        node.is_expanded = (depth < 3); // Auto-expand up to 3 levels by default
        node.is_last = (cur_entry == total_entries);
        node.is_current = false;

        scan_tree_recursive(&rel_path[0], depth + 1, max_depth, current_file, tree);
    }
}

fn void scan_file_tree(char* current_file, FileTree* out_tree)
{
    out_tree.count = 0;

    // Parent directory entry
    TreeNode* parent_node = &out_tree.nodes[out_tree.count++];
    strutils::copy_str(&parent_node.path[0], "..", 128);
    strutils::copy_str(&parent_node.name[0], "..", 64);
    parent_node.depth = 0;
    parent_node.is_dir = true;
    parent_node.is_expanded = false;
    parent_node.is_last = false;
    parent_node.is_current = false;

    scan_tree_recursive(".", 0, 5, current_file, out_tree);
}

Termios orig_termios;
bool raw_mode_active = false;

fn int get_width()
{
    WinSize ws;
    // Try Linux TIOCGWINSZ (0x5413) and macOS / BSD TIOCGWINSZ (0x40087468)
    if ((ioctl(1, 0x5413, &ws) == 0 || ioctl(1, 0x40087468, &ws) == 0) && ws.ws_col > 0)
    {
        return (int)ws.ws_col;
    }
    char* env_col = getenv("COLUMNS");
    if (env_col != null && env_col[0] != 0)
    {
        int val = 0;
        int i = 0;
        while (env_col[i] >= '0' && env_col[i] <= '9')
        {
            val = val * 10 + (int)(env_col[i] - '0');
            i++;
        }
        if (val > 0) return val;
    }
    return 80;
}

fn int get_height()
{
    WinSize ws;
    if ((ioctl(1, 0x5413, &ws) == 0 || ioctl(1, 0x40087468, &ws) == 0) && ws.ws_row > 0)
    {
        return (int)ws.ws_row;
    }
    char* env_row = getenv("LINES");
    if (env_row != null && env_row[0] != 0)
    {
        int val = 0;
        int i = 0;
        while (env_row[i] >= '0' && env_row[i] <= '9')
        {
            val = val * 10 + (int)(env_row[i] - '0');
            i++;
        }
        if (val > 0) return val;
    }
    return 24;
}

fn bool is_tty()
{
    return isatty(1) != 0;
}

fn void write_direct(char* s)
{
    if (s == null) return;
    int len = strutils::str_len(s);
    if (len > 0)
    {
        write(1, (void*)s, (ulong)len);
    }
}

fn void enter_alt_screen()
{
    // Enable alternate screen + disable autowrap (\x1b[?7l) + mouse tracking + clear + hide cursor
    write_direct("\x1b[?1049h\x1b[?7l\x1b[?1000h\x1b[?1002h\x1b[?1006h\x1b[2J\x1b[3J\x1b[H\x1b[?25l");
}

fn void leave_alt_screen()
{
    // Disable mouse tracking + enable autowrap (\x1b[?7h) + leave alternate screen + show cursor
    write_direct("\x1b[?7h\x1b[?1006l\x1b[?1002l\x1b[?1000l\x1b[?1049l\x1b[?25h\x1b[0m");
}

fn void clear_screen()
{
    write_direct("\x1b[2J\x1b[3J\x1b[H");
}

fn void hide_cursor()
{
    write_direct("\x1b[?25l");
}

fn void show_cursor()
{
    write_direct("\x1b[?25h");
}

fn void open_editor_at_line(char* filename, int src_line)
{
    if (filename == null || filename[0] == 0) return;

    disable_raw_mode();
    leave_alt_screen();

    char* editor = getenv("EDITOR");
    if (editor == null || editor[0] == 0)
    {
        editor = getenv("VISUAL");
    }
    if (editor == null || editor[0] == 0)
    {
        editor = "nano";
    }

    char[1024] cmd_buf;
    strutils::copy_str(&cmd_buf[0], editor, 1024);
    strutils::append_str(&cmd_buf[0], " +", 1024);

    char[16] line_str;
    strutils::int_to_str(src_line, &line_str[0], 16);
    strutils::append_str(&cmd_buf[0], &line_str[0], 1024);

    strutils::append_str(&cmd_buf[0], " \"", 1024);
    strutils::append_str(&cmd_buf[0], filename, 1024);
    strutils::append_str(&cmd_buf[0], "\"", 1024);

    system(&cmd_buf[0]);

    enable_raw_mode();
    enter_alt_screen();
}

fn void sleep_ms(uint ms)
{
    usleep(ms * 1000);
}

fn bool get_file_state(char* path, FileState* state)
{
    Stat st;
    if (stat(path, &st) == 0)
    {
        state.inode = st.st_ino;
        state.size = st.st_size;
        state.mtime = st.st_mtime;
        state.mtime_nsec = st.st_mtime_nsec;
        return true;
    }
    return false;
}

fn bool file_has_changed(FileState* prev, FileState* curr)
{
    if (prev.inode != curr.inode) return true;
    if (prev.size != curr.size) return true;
    if (prev.mtime != curr.mtime) return true;
    if (prev.mtime_nsec != curr.mtime_nsec) return true;
    return false;
}

fn void enable_raw_mode()
{
    if (raw_mode_active || isatty(0) == 0) return;
    if (tcgetattr(0, &orig_termios) == 0)
    {
        Termios raw = orig_termios;
        raw.c_lflag &= ~0x000Au; // disable ECHO (0x08) and ICANON (0x02)
        raw.c_cc[6] = 0; // VMIN = 0
        raw.c_cc[5] = 0; // VTIME = 0
        tcsetattr(0, 0, &raw);
        raw_mode_active = true;
        hide_cursor();
    }
}

fn void disable_raw_mode()
{
    if (!raw_mode_active) return;
    tcsetattr(0, 0, &orig_termios);
    raw_mode_active = false;
    show_cursor();
}

fn int poll_key()
{
    char[64] buf;
    int n = read(0, (void*)&buf[0], 64);
    if (n <= 0) return 0;

    if (buf[0] == 0x1b)
    {
        if (n == 1) return 27; // Single Esc key

        // SGR Mouse mode: \x1b[<button;col;row(M|m)
        if (n >= 6 && buf[1] == '[' && buf[2] == '<')
        {
            int btn = 0;
            int p = 3;
            while (p < n && buf[p] >= '0' && buf[p] <= '9')
            {
                btn = btn * 10 + (int)(buf[p] - '0');
                p++;
            }
            if (btn == 64) return 1012; // Mouse Wheel Up
            if (btn == 65) return 1013; // Mouse Wheel Down
            return 0; // Ignore clicks/drags for view scrolling
        }

        // X10 Mouse mode: \x1b[M(btn)(x)(y)
        if (n >= 6 && buf[1] == '[' && buf[2] == 'M')
        {
            int btn = ((int)buf[3] & 0xFF) - 32;
            if (btn == 64) return 1012; // Wheel Up
            if (btn == 65) return 1013; // Wheel Down
            return 0;
        }

        // Application Cursor Keys: \x1bO...
        if (n >= 3 && buf[1] == 'O')
        {
            if (buf[2] == 'A') return 1001; // Up
            if (buf[2] == 'B') return 1000; // Down
            if (buf[2] == 'C') return 1007; // Right
            if (buf[2] == 'D') return 1006; // Left
            if (buf[2] == 'H') return 1008; // Home
            if (buf[2] == 'F') return 1009; // End
            return 0;
        }

        // ANSI Cursor Keys: \x1b[...
        if (n >= 3 && buf[1] == '[')
        {
            if (buf[2] == 'A') return 1001; // Up
            if (buf[2] == 'B') return 1000; // Down
            if (buf[2] == 'C') return 1007; // Right
            if (buf[2] == 'D') return 1006; // Left
            if (buf[2] == '5' && n >= 4 && buf[3] == '~') return 1003; // PgUp
            if (buf[2] == '6' && n >= 4 && buf[3] == '~') return 1002; // PgDn
            if (buf[2] == 'H') return 1008; // Home
            if (buf[2] == 'F') return 1009; // End
            if (buf[2] == '1' && n >= 4 && buf[3] == '~') return 1008; // Home
            if (buf[2] == '4' && n >= 4 && buf[3] == '~') return 1009; // End
            if (buf[2] == '7' && n >= 4 && buf[3] == '~') return 1008; // Home
            if (buf[2] == '8' && n >= 4 && buf[3] == '~') return 1009; // End
        }
        return 27;
    }

    if (buf[0] == 0x03) return 'q'; // Ctrl+C
    if (buf[0] == 0x04) return 1004; // Ctrl+D (half page down)
    if (buf[0] == 0x15) return 1005; // Ctrl+U (half page up)
    if (buf[0] == 0x06) return 1002; // Ctrl+F (page down)
    if (buf[0] == 0x02) return 1003; // Ctrl+B (page up)
    if (buf[0] == 0x09) return 9;    // Tab
    if (buf[0] == '\r' || buf[0] == '\n') return 10; // Enter
    if (buf[0] == 0x7f || buf[0] == 0x08) return 127; // Backspace
    return (int)buf[0] & 0xFF;
}
