module ansi;

const String RESET = "\e[0m";
const String BOLD = "\e[1m";
const String DIM = "\e[2m";
const String ITALIC = "\e[3m";
const String UNDERLINE = "\e[4m";
const String STRIKE = "\e[9m";

const String H1 = "\e[38;2;249;38;114m\e[1m";
const String H2 = "\e[38;2;166;226;46m\e[1m";
const String H3 = "\e[38;2;253;151;31m\e[1m";
const String H4 = "\e[38;2;230;219;116m\e[1m";
const String H5 = "\e[38;2;174;129;255m\e[1m";
const String H6 = "\e[38;2;102;217;239m\e[1m";

const String CYAN = "\e[38;2;102;217;239m";
const String GREEN = "\e[38;2;166;226;46m";
const String ORANGE = "\e[38;2;253;151;31m";
const String PINK = "\e[38;2;249;38;114m";
const String YELLOW = "\e[38;2;230;219;116m";
const String PURPLE = "\e[38;2;174;129;255m";
const String MUTED = "\e[38;2;117;113;94m";
const String TEXT = "\e[38;2;248;248;242m";
const String MATH = "\e[38;2;255;216;102m\e[1m";

const String CODE = "\e[48;2;39;40;34m";
const String CALLOUT = "\e[48;2;30;32;36m";
const String INLINE = "\e[48;2;39;40;34m\e[38;2;102;217;239m";

const String BADGE = "\e[48;2;39;40;34m\e[38;2;102;217;239m\e[1m";
const String PATH = "\e[48;2;30;32;36m\e[38;2;248;248;242m\e[1m";
const String DIVIDER = "\e[38;2;117;113;94m";
const String BORDER = "\e[38;2;117;113;94m";
const String TITLE = "\e[38;2;253;151;31m\e[1m";
const String ACTIVE = "\e[48;2;49;50;68m\e[38;2;166;226;46m\e[1m";
const String SELECTED = "\e[48;2;49;50;68m\e[38;2;248;248;242m\e[1m";
const String STATUS = "\e[48;2;39;40;34m\e[38;2;166;226;46m\e[1m";
const String CURSOR = "\e[38;2;102;217;239m\e[1m";
const String TILDE = "\e[38;2;60;60;50m";

const String[] HEADINGS = { H1, H2, H3, H4, H5, H6 };

struct Named
{
    String name;
    String code;
}

const Named[] NAMES = {
    { "red", PINK }, { "pink", PINK }, { "green", GREEN }, { "orange", ORANGE }, { "yellow", YELLOW },
    { "purple", PURPLE }, { "magenta", PURPLE }, { "gray", MUTED }, { "grey", MUTED },
};

fn String named(String name)
{
    foreach (n : NAMES) if (n.name == name) return n.code;
    return CYAN;
}
