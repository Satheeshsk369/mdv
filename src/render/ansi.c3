module ansi;

bool plain_mode = false;

fn void set_plain(bool plain)
{
    plain_mode = plain;
}

const ZString RESET       = "\x1b[0m";
const ZString BOLD        = "\x1b[1m";
const ZString DIM         = "\x1b[2m";
const ZString ITALIC      = "\x1b[3m";
const ZString UNDERLINE   = "\x1b[4m";
const ZString STRIKE      = "\x1b[9m";

// High-Fidelity Monokai Palette
const ZString FG_H1       = "\x1b[38;2;249;38;114m\x1b[1m";   // Magenta / Pink
const ZString FG_H2       = "\x1b[38;2;166;226;46m\x1b[1m";   // Lime Green
const ZString FG_H3       = "\x1b[38;2;253;151;31m\x1b[1m";   // Warm Orange
const ZString FG_H4       = "\x1b[38;2;230;219;116m\x1b[1m";  // Yellow
const ZString FG_H5       = "\x1b[38;2;174;129;255m\x1b[1m";  // Purple
const ZString FG_H6       = "\x1b[38;2;102;217;239m\x1b[1m";  // Cyan

const ZString FG_CYAN     = "\x1b[38;2;102;217;239m";
const ZString FG_GREEN    = "\x1b[38;2;166;226;46m";
const ZString FG_ORANGE   = "\x1b[38;2;253;151;31m";
const ZString FG_PINK     = "\x1b[38;2;249;38;114m";
const ZString FG_YELLOW   = "\x1b[38;2;230;219;116m";
const ZString FG_PURPLE   = "\x1b[38;2;174;129;255m";
const ZString FG_MUTED    = "\x1b[38;2;117;113;94m";
const ZString FG_TEXT     = "\x1b[38;2;248;248;242m";
const ZString FG_MATH     = "\x1b[38;2;255;216;102m\x1b[1m";  // Bright gold

const ZString BG_CODE     = "\x1b[48;2;39;40;34m";
const ZString BG_CALLOUT  = "\x1b[48;2;30;32;36m";

const ZString CODE_INLINE = "\x1b[48;2;39;40;34m\x1b[38;2;102;217;239m";
