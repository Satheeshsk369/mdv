module ansi;

import buffer;
import logic;

enum Theme {
    DARK,
    LIGHT
}

Theme current_theme = Theme.DARK;
bool plain_mode = false;

fn void set_plain(bool plain)
{
    plain_mode = plain;
}

const char* RESET       = "\x1b[0m";
const char* BOLD        = "\x1b[1m";
const char* DIM         = "\x1b[2m";
const char* ITALIC      = "\x1b[3m";
const char* UNDERLINE   = "\x1b[4m";
const char* STRIKE      = "\x1b[9m";

// Dynamic Palette
char* fg_h1       = "\x1b[38;2;249;38;114m\x1b[1m";   // Magenta / Pink
char* fg_h2       = "\x1b[38;2;166;226;46m\x1b[1m";   // Lime Green
char* fg_h3       = "\x1b[38;2;253;151;31m\x1b[1m";   // Warm Orange
char* fg_h4       = "\x1b[38;2;230;219;116m\x1b[1m";  // Yellow
char* fg_h5       = "\x1b[38;2;174;129;255m\x1b[1m";  // Purple
char* fg_h6       = "\x1b[38;2;102;217;239m\x1b[1m";  // Cyan

char* fg_cyan     = "\x1b[38;2;102;217;239m";
char* fg_green    = "\x1b[38;2;166;226;46m";
char* fg_orange   = "\x1b[38;2;253;151;31m";
char* fg_pink     = "\x1b[38;2;249;38;114m";
char* fg_yellow   = "\x1b[38;2;230;219;116m";
char* fg_purple   = "\x1b[38;2;174;129;255m";
char* fg_muted    = "\x1b[38;2;117;113;94m";
char* fg_text     = "\x1b[38;2;248;248;242m";
char* fg_math     = "\x1b[38;2;255;216;102m\x1b[1m";  // Bright gold

char* bg_code     = "\x1b[48;2;39;40;34m";
char* bg_callout  = "\x1b[48;2;30;32;36m";

char* code_inline = "\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m";

// UI Theme Elements
char* ui_top_badge   = "\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m";
char* ui_top_path    = "\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m";
char* ui_top_div     = "\x1b[38;2;117;113;94m";
char* ui_border      = "\x1b[38;2;117;113;94m";
char* ui_title       = "\x1b[38;2;253;151;31m\x1b[1m";
char* ui_accent      = "\x1b[38;2;102;217;239m\x1b[1m";
char* ui_active_bg   = "\x1b[48;2;49;50;68m\x1b[38;2;166;226;46m\x1b[1m";
char* ui_active_tree = "\x1b[48;2;49;50;68m\x1b[38;2;248;248;242m\x1b[1m";
char* ui_status_bg   = "\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m";
char* ui_cursor_bar  = "\x1b[38;2;102;217;239m\x1b[1m";
char* ui_tilde       = "\x1b[38;2;60;60;50m";

// ── Monoid Style Combinators ───────────────────────────────────────────────

struct Style {
    bool is_bold;
    bool is_dim;
    bool is_italic;
    bool is_underline;
    bool is_strike;
    char* fg_color;
    char* bg_color;
}

fn Style style_empty()
{
    Style s;
    return s;
}

// Monoid append: (Style × Style) -> Style
fn Style Style.combine(Style self, Style other)
{
    Style res;
    res.is_bold = self.is_bold || other.is_bold;
    res.is_dim = self.is_dim || other.is_dim;
    res.is_italic = self.is_italic || other.is_italic;
    res.is_underline = self.is_underline || other.is_underline;
    res.is_strike = self.is_strike || other.is_strike;
    res.fg_color = other.fg_color != null ? other.fg_color : self.fg_color;
    res.bg_color = other.bg_color != null ? other.bg_color : self.bg_color;
    return res;
}

fn Style Style.bold(Style self) { self.is_bold = true; return self; }
fn Style Style.dim(Style self) { self.is_dim = true; return self; }
fn Style Style.italic(Style self) { self.is_italic = true; return self; }
fn Style Style.underline(Style self) { self.is_underline = true; return self; }
fn Style Style.strike(Style self) { self.is_strike = true; return self; }
fn Style Style.fg(Style self, char* color) { self.fg_color = color; return self; }
fn Style Style.bg(Style self, char* color) { self.bg_color = color; return self; }

fn Style Style.red(Style self) { self.fg_color = fg_pink; return self; }
fn Style Style.pink(Style self) { self.fg_color = fg_pink; return self; }
fn Style Style.green(Style self) { self.fg_color = fg_green; return self; }
fn Style Style.yellow(Style self) { self.fg_color = fg_yellow; return self; }
fn Style Style.orange(Style self) { self.fg_color = fg_orange; return self; }
fn Style Style.cyan(Style self) { self.fg_color = fg_cyan; return self; }
fn Style Style.purple(Style self) { self.fg_color = fg_purple; return self; }
fn Style Style.muted(Style self) { self.fg_color = fg_muted; return self; }
fn Style Style.text_color(Style self) { self.fg_color = fg_text; return self; }
fn Style Style.math(Style self) { self.fg_color = fg_math; self.is_bold = true; return self; }

// ── Functional Fluent Text API ─────────────────────────────────────────────

struct Styled {
    String slice;
    char* zstr;
    Style item_style;
}

fn Styled text(String s)
{
    Styled st;
    st.slice = s;
    return st;
}

fn Styled text_z(char* s)
{
    Styled st;
    st.zstr = s;
    return st;
}

fn Styled Styled.bold(Styled self) { self.item_style.is_bold = true; return self; }
fn Styled Styled.dim(Styled self) { self.item_style.is_dim = true; return self; }
fn Styled Styled.italic(Styled self) { self.item_style.is_italic = true; return self; }
fn Styled Styled.underline(Styled self) { self.item_style.is_underline = true; return self; }
fn Styled Styled.strike(Styled self) { self.item_style.is_strike = true; return self; }

fn Styled Styled.fg(Styled self, char* color) { self.item_style.fg_color = color; return self; }
fn Styled Styled.bg(Styled self, char* color) { self.item_style.bg_color = color; return self; }

fn Styled Styled.red(Styled self) { self.item_style.fg_color = fg_pink; return self; }
fn Styled Styled.pink(Styled self) { self.item_style.fg_color = fg_pink; return self; }
fn Styled Styled.green(Styled self) { self.item_style.fg_color = fg_green; return self; }
fn Styled Styled.yellow(Styled self) { self.item_style.fg_color = fg_yellow; return self; }
fn Styled Styled.orange(Styled self) { self.item_style.fg_color = fg_orange; return self; }
fn Styled Styled.cyan(Styled self) { self.item_style.fg_color = fg_cyan; return self; }
fn Styled Styled.purple(Styled self) { self.item_style.fg_color = fg_purple; return self; }
fn Styled Styled.muted(Styled self) { self.item_style.fg_color = fg_muted; return self; }
fn Styled Styled.text_color(Styled self) { self.item_style.fg_color = fg_text; return self; }
fn Styled Styled.math(Styled self) { self.item_style.fg_color = fg_math; self.item_style.is_bold = true; return self; }

fn Styled Styled.h1(Styled self) { self.item_style.fg_color = fg_h1; self.item_style.is_bold = true; return self; }
fn Styled Styled.h2(Styled self) { self.item_style.fg_color = fg_h2; self.item_style.is_bold = true; return self; }
fn Styled Styled.h3(Styled self) { self.item_style.fg_color = fg_h3; self.item_style.is_bold = true; return self; }
fn Styled Styled.h4(Styled self) { self.item_style.fg_color = fg_h4; self.item_style.is_bold = true; return self; }
fn Styled Styled.h5(Styled self) { self.item_style.fg_color = fg_h5; self.item_style.is_bold = true; return self; }
fn Styled Styled.h6(Styled self) { self.item_style.fg_color = fg_h6; self.item_style.is_bold = true; return self; }

fn Styled Styled.with_style(Styled self, Style st)
{
    self.item_style = self.item_style.combine(st);
    return self;
}

fn void Styled.render(Styled* self, buffer::ByteBuffer* out, bool plain = false)
{
    if (plain || plain_mode)
    {
        if (self.zstr != null)
        {
            out.append_zstr(self.zstr);
        }
        else if (self.slice.len > 0)
        {
            out.append_slice(self.slice);
        }
        return;
    }

    bool has_style = self.item_style.is_bold || self.item_style.is_dim || self.item_style.is_italic || 
                     self.item_style.is_underline || self.item_style.is_strike || 
                     self.item_style.fg_color != null || self.item_style.bg_color != null;

    if (has_style)
    {
        if (self.item_style.bg_color != null) out.append_zstr(self.item_style.bg_color);
        if (self.item_style.fg_color != null) out.append_zstr(self.item_style.fg_color);
        if (self.item_style.is_bold) out.append_zstr(BOLD);
        if (self.item_style.is_dim) out.append_zstr(DIM);
        if (self.item_style.is_italic) out.append_zstr(ITALIC);
        if (self.item_style.is_underline) out.append_zstr(UNDERLINE);
        if (self.item_style.is_strike) out.append_zstr(STRIKE);
    }

    if (self.zstr != null)
    {
        out.append_zstr(self.zstr);
    }
    else if (self.slice.len > 0)
    {
        out.append_slice(self.slice);
    }

    if (has_style)
    {
        out.append_zstr(RESET);
    }
}

// ── Theme Setter & Switcher ───────────────────────────────────────────────

fn void set_theme(Theme t)
{
    current_theme = t;
    if (t == Theme.LIGHT)
    {
        // Light Palette (Modern Crisp Editorial)
        fg_h1       = "\x1b[38;2;30;58;138m\x1b[1m";   // Deep Royal Blue
        fg_h2       = "\x1b[38;2;15;118;110m\x1b[1m";  // Deep Emerald Teal
        fg_h3       = "\x1b[38;2;194;65;12m\x1b[1m";   // Warm Rust Orange
        fg_h4       = "\x1b[38;2;161;98;7m\x1b[1m";    // Dark Golden Amber
        fg_h5       = "\x1b[38;2;126;34;206m\x1b[1m";  // Royal Violet
        fg_h6       = "\x1b[38;2;3;105;161m\x1b[1m";   // Steel Sky Blue

        fg_cyan     = "\x1b[38;2;2;132;199m";           // Sky Blue
        fg_green    = "\x1b[38;2;22;163;74m";           // Forest Green
        fg_orange   = "\x1b[38;2;234;88;12m";           // Burnt Orange
        fg_pink     = "\x1b[38;2;225;29;72m";           // Crimson Pink
        fg_yellow   = "\x1b[38;2;202;138;4m";           // Amber Yellow
        fg_purple   = "\x1b[38;2;124;58;237m";          // Purple
        fg_muted    = "\x1b[38;2;100;116;139m";         // Slate Muted
        fg_text     = "\x1b[38;2;15;23;42m";            // Deep Slate Text
        fg_math     = "\x1b[38;2;180;83;9m\x1b[1m";     // Deep Amber Gold

        bg_code     = "\x1b[48;2;241;245;249m";
        bg_callout  = "\x1b[48;2;248;250;252m";

        code_inline = "\x1b[48;2;226;232;240m\x1b[38;2;15;23;42m";

        ui_top_badge   = "\x1b[48;2;226;232;240m\x1b[38;2;2;132;199m\x1b[1m";
        ui_top_path    = "\x1b[48;2;241;245;249m\x1b[38;2;15;23;42m\x1b[1m";
        ui_top_div     = "\x1b[38;2;203;213;225m";
        ui_border      = "\x1b[38;2;203;213;225m";
        ui_title       = "\x1b[38;2;194;65;12m\x1b[1m";
        ui_accent      = "\x1b[38;2;2;132;199m\x1b[1m";
        ui_active_bg   = "\x1b[48;2;226;232;240m\x1b[38;2;15;23;42m\x1b[1m";
        ui_active_tree = "\x1b[48;2;226;232;240m\x1b[38;2;15;23;42m\x1b[1m";
        ui_status_bg   = "\x1b[48;2;226;232;240m\x1b[38;2;15;118;110m\x1b[1m";
        ui_cursor_bar  = "\x1b[38;2;2;132;199m\x1b[1m";
        ui_tilde       = "\x1b[38;2;203;213;225m";
    }
    else
    {
        // Dark Palette (Monokai Pro / Tokyo Night)
        fg_h1       = "\x1b[38;2;249;38;114m\x1b[1m";   // Magenta / Pink
        fg_h2       = "\x1b[38;2;166;226;46m\x1b[1m";   // Lime Green
        fg_h3       = "\x1b[38;2;253;151;31m\x1b[1m";   // Warm Orange
        fg_h4       = "\x1b[38;2;230;219;116m\x1b[1m";  // Yellow
        fg_h5       = "\x1b[38;2;174;129;255m\x1b[1m";  // Purple
        fg_h6       = "\x1b[38;2;102;217;239m\x1b[1m";  // Cyan

        fg_cyan     = "\x1b[38;2;102;217;239m";
        fg_green    = "\x1b[38;2;166;226;46m";
        fg_orange   = "\x1b[38;2;253;151;31m";
        fg_pink     = "\x1b[38;2;249;38;114m";
        fg_yellow   = "\x1b[38;2;230;219;116m";
        fg_purple   = "\x1b[38;2;174;129;255m";
        fg_muted    = "\x1b[38;2;117;113;94m";
        fg_text     = "\x1b[38;2;248;248;242m";
        fg_math     = "\x1b[38;2;255;216;102m\x1b[1m";  // Bright gold

        bg_code     = "\x1b[48;2;39;40;34m";
        bg_callout  = "\x1b[48;2;30;32;36m";

        code_inline = "\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m";

        ui_top_badge   = "\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m\x1b[1m";
        ui_top_path    = "\x1b[48;2;30;32;36m\x1b[38;2;248;248;242m\x1b[1m";
        ui_top_div     = "\x1b[38;2;117;113;94m";
        ui_border      = "\x1b[38;2;117;113;94m";
        ui_title       = "\x1b[38;2;253;151;31m\x1b[1m";
        ui_accent      = "\x1b[38;2;102;217;239m\x1b[1m";
        ui_active_bg   = "\x1b[48;2;49;50;68m\x1b[38;2;166;226;46m\x1b[1m";
        ui_active_tree = "\x1b[48;2;49;50;68m\x1b[38;2;248;248;242m\x1b[1m";
        ui_status_bg   = "\x1b[48;2;39;40;34m\x1b[38;2;166;226;46m\x1b[1m";
        ui_cursor_bar  = "\x1b[38;2;102;217;239m\x1b[1m";
        ui_tilde       = "\x1b[38;2;60;60;50m";
    }
}

fn void toggle_theme()
{
    if (current_theme == Theme.DARK)
    {
        set_theme(Theme.LIGHT);
    }
    else
    {
        set_theme(Theme.DARK);
    }
}
