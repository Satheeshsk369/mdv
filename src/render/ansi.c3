module ansi;

import std::core::mem;

const String RESET = "\e[0m";
const String BOLD = "\e[1m";
const String ITALIC = "\e[3m";
const String UNDERLINE = "\e[4m";
const String STRIKE = "\e[9m";

enum Role
{
    H1,
    H2,
    H3,
    H4,
    H5,
    H6,
    NONE,
    STRONG,
    EMPHASIS,
    STRIKEOUT,
    TEXT,
    MUTED,
    FAINT,
    CYAN,
    GREEN,
    ORANGE,
    PINK,
    YELLOW,
    PURPLE,
    INLINE,
    CODE,
    STRUCK,
    LINK,
    NOTE,
    BADGE,
    PATH,
    BORDER,
    TITLE,
    ACTIVE,
    SELECTED,
    STATUS,
    CURSOR,
    FOCUS,
    SELECTION,
    MATCH,
    FOUND,
    CURRENT
}

struct Palette
{
    String name;
    uint text;
    uint muted;
    uint faint;
    uint red;
    uint green;
    uint orange;
    uint yellow;
    uint purple;
    uint cyan;
    uint panel;
    uint deep;
    uint row;
    uint focus;
    uint selection;
    uint match;
    uint ink;
    uint background;
}

struct Scheme
{
    String name;
    uint bg;
    uint fg;
    uint comment;
    uint red;
    uint orange;
    uint yellow;
    uint green;
    uint cyan;
    uint blue;
    uint purple;
}

const Palette MDV = {
    "mdv", 0xF8F8F2, 0x75715E, 0x3C3C32, 0xF92672, 0xA6E22E, 0xFD971F, 0xE6DB74, 0xAE81FF, 0x66D9EF,
    0x272822, 0x1E2024, 0x313244, 0x3E3D32, 0x44475A, 0x5E481C, 0x000000, 0,
};

const Scheme[] SCHEMES = {
    { "Everforest", 0x2D353B, 0xD3C6AA, 0x859289, 0xE67E80, 0xE69875, 0xDBBC7F, 0xA7C080, 0x83C092, 0x7FBBB3, 0xD699B6 },
    { "Kanagawa", 0x1F1F28, 0xDCD7BA, 0x727169, 0xE46876, 0xFFA066, 0xE6C384, 0x98BB6C, 0x7AA89F, 0x7E9CD8, 0x957FB8 },
    { "Melange", 0x292522, 0xECE1D7, 0x867462, 0xD47766, 0xE49B5D, 0xEBC06D, 0x85B695, 0x89B3B6, 0xA3A9CE, 0xCF9BC2 },
    { "Sonokai", 0x2C2E34, 0xE2E2E3, 0x7F8490, 0xFC5D7C, 0xF39660, 0xE7C664, 0x9ED072, 0x76CCE0, 0x76CCE0, 0xB39DF3 },
    { "Rosé Pine Moon", 0x232136, 0xE0DEF4, 0x6E6A86, 0xEB6F92, 0xEA9A97, 0xF6C177, 0x9CCFD8, 0x9CCFD8, 0x3E8FB0, 0xC4A7E7 },
    { "Gruvbox Material", 0x282828, 0xD4BE98, 0x928374, 0xEA6962, 0xE78A4E, 0xD8A657, 0xA9B665, 0x89B482, 0x7DAEA3, 0xD3869B },
    { "Moonfly", 0x080808, 0xBDBDBD, 0x808080, 0xFF5D5D, 0xDE935F, 0xE3C78A, 0x8CC85F, 0x79DAC8, 0x80A0FF, 0xCF87E8 },
    { "Nightfox", 0x192330, 0xCDCECF, 0x738091, 0xC94F6D, 0xF4A261, 0xDBC074, 0x81B29A, 0x63CDCF, 0x719CD6, 0x9D79D6 },
    { "Oxocarbon", 0x161616, 0xF2F4F8, 0x6F6F6F, 0xEE5396, 0xFF7EB6, 0x82CFFF, 0x42BE65, 0x3DDBD9, 0x33B1FF, 0xBE95FF },
    { "Bamboo", 0x252623, 0xF1E9D2, 0x838781, 0xE75A7C, 0xFF9966, 0xDBB651, 0x8FB573, 0x70C2BE, 0x57A5E5, 0xAAAAFF },
    { "Kanagawa Dragon", 0x181616, 0xC5C9C5, 0x737C73, 0xC4746E, 0xB6927B, 0xC4B28A, 0x87A987, 0x8EA4A2, 0x8BA4B0, 0xA292A3 },
    { "Poimandres", 0x1B1E28, 0xA6ACCD, 0x767C9D, 0xD0679D, 0xF087BD, 0xFFFAC2, 0x5DE4C7, 0x89DDFF, 0xADD7FF, 0xFCC5E9 },
    { "Embark", 0x1E1C31, 0xCBE3E7, 0x585273, 0xF48FB1, 0xF2B482, 0xFFE6B3, 0xA1EFD3, 0x87DFEB, 0x91DDFF, 0xD4BFFF },
    { "Iceberg", 0x161821, 0xC6C8D1, 0x6B7089, 0xE27878, 0xE2A478, 0xE2C08A, 0xB4BE82, 0x89B8C2, 0x84A0C6, 0xA093C7 },
    { "Moonlight", 0x222436, 0xC8D3F5, 0x7A88CF, 0xFF757F, 0xFF966C, 0xFFC777, 0xC3E88D, 0x86E1FC, 0x82AAFF, 0xC099FF },
    { "Horizon", 0x1C1E26, 0xD5D8DA, 0x6C6F93, 0xE95678, 0xFAB795, 0xFAC29A, 0x29D398, 0x59E1E3, 0x26BBD9, 0xEE64AC },
    { "Spaceduck", 0x0F111B, 0xECF0C1, 0x686F9A, 0xE33400, 0xE39400, 0xF2CE00, 0x5CCC96, 0x00A3CC, 0x7A5CCC, 0xB3A1E6 },
    { "Mariana", 0x303841, 0xD8DEE9, 0xA6ACB9, 0xEC5F66, 0xF9AE58, 0xFAC761, 0x99C794, 0x5FB4B4, 0x6699CC, 0xC695C6 },
    { "Tomorrow Night Eighties", 0x2D2D2D, 0xCCCCCC, 0x999999, 0xF2777A, 0xF99157, 0xFFCC66, 0x99CC99, 0x66CCCC, 0x6699CC, 0xCC99CC },
    { "Zenburn", 0x3F3F3F, 0xDCDCCC, 0x7F9F7F, 0xCC9393, 0xDFAF8F, 0xF0DFAF, 0x7F9F7F, 0x93E0E3, 0x8CD0D3, 0xDC8CC3 },
    { "Apprentice", 0x262626, 0xBCBCBC, 0x6C6C6C, 0xAF5F5F, 0xFF8700, 0xD7AF5F, 0x87AF87, 0x5F8787, 0x5F87AF, 0x8787AF },
    { "Snazzy", 0x282A36, 0xEFF0EB, 0x97979B, 0xFF5C57, 0xFF9F43, 0xF3F99D, 0x5AF78E, 0x9AEDFE, 0x57C7FF, 0xFF6AC1 },
    { "Monokai Pro", 0x2D2A2E, 0xFCFCFA, 0x727072, 0xFF6188, 0xFC9867, 0xFFD866, 0xA9DC76, 0x78DCE8, 0x78DCE8, 0xAB9DF2 },
    { "Catppuccin Mocha", 0x1E1E2E, 0xCDD6F4, 0x6C7086, 0xF38BA8, 0xFAB387, 0xF9E2AF, 0xA6E3A1, 0x94E2D5, 0x89B4FA, 0xCBA6F7 },
    { "Tokyo Night", 0x1A1B26, 0xC0CAF5, 0x565F89, 0xF7768E, 0xFF9E64, 0xE0AF68, 0x9ECE6A, 0x7DCFFF, 0x7AA2F7, 0xBB9AF7 },
    { "Rosé Pine", 0x191724, 0xE0DEF4, 0x6E6A86, 0xEB6F92, 0xEBBCBA, 0xF6C177, 0x9CCFD8, 0x9CCFD8, 0x31748F, 0xC4A7E7 },
    { "Dracula", 0x282A36, 0xF8F8F2, 0x6272A4, 0xFF5555, 0xFFB86C, 0xF1FA8C, 0x50FA7B, 0x8BE9FD, 0x8BE9FD, 0xBD93F9 },
    { "One Dark", 0x282C34, 0xABB2BF, 0x5C6370, 0xE06C75, 0xD19A66, 0xE5C07B, 0x98C379, 0x56B6C2, 0x61AFEF, 0xC678DD },
    { "Doom One", 0x282C34, 0xBBC2CF, 0x5B6268, 0xFF6C6B, 0xDA8548, 0xECBE7B, 0x98BE65, 0x46D9FF, 0x51AFEF, 0xC678DD },
    { "Nord", 0x2E3440, 0xD8DEE9, 0x616E88, 0xBF616A, 0xD08770, 0xEBCB8B, 0xA3BE8C, 0x8FBCBB, 0x81A1C1, 0xB48EAD },
    { "Gruvbox", 0x282828, 0xEBDBB2, 0x928374, 0xFB4934, 0xFE8019, 0xFABD2F, 0xB8BB26, 0x8EC07C, 0x83A598, 0xD3869B },
    { "Solarized Dark", 0x002B36, 0x839496, 0x586E75, 0xDC322F, 0xCB4B16, 0xB58900, 0x859900, 0x2AA198, 0x268BD2, 0x6C71C4 },
    { "GitHub Dark", 0x0D1117, 0xE6EDF3, 0x8B949E, 0xFF7B72, 0xFFA657, 0xE3B341, 0x7EE787, 0xA5D6FF, 0x79C0FF, 0xD2A8FF },
    { "Ayu Mirage", 0x1F2430, 0xCBCCC6, 0x5C6773, 0xF28779, 0xFFA759, 0xFFD580, 0xBAE67E, 0x95E6CB, 0x73D0FF, 0xD4BFFF },
    { "Night Owl", 0x011627, 0xD6DEEB, 0x637777, 0xEF5350, 0xF78C6C, 0xFFCB8B, 0xADDB67, 0x7FDBCA, 0x82AAFF, 0xC792EA },
    { "Material Palenight", 0x292D3E, 0xA6ACCD, 0x676E95, 0xF07178, 0xF78C6C, 0xFFCB6B, 0xC3E88D, 0x89DDFF, 0x82AAFF, 0xC792EA },
    { "Synthwave '84", 0x262335, 0xFFFFFF, 0x848BBD, 0xFE4450, 0xF97E72, 0xFEDE5D, 0x72F1B8, 0x36F9F6, 0x2EE2FA, 0xFF7EDB },
    { "Base16 Ocean", 0x2B303B, 0xC0C5CE, 0x65737E, 0xBF616A, 0xD08770, 0xEBCB8B, 0xA3BE8C, 0x96B5B4, 0x8FA1B3, 0xB48EAD },
};

fn int themes() => SCHEMES.len + 1;

fn String title(int index) => index == 0 ? MDV.name : SCHEMES[index - 1].name;

fn uint channel(uint c, int shift) => (c >> shift) & 0xFF;

fn uint mix(uint a, uint b, float t)
{
    uint c;
    for (int shift = 0; shift <= 16; shift += 8)
    {
        float x = (float)channel(a, shift);
        float y = (float)channel(b, shift);
        c |= (uint)(x + (y - x) * t + 0.5f) << shift;
    }
    return c;
}

fn float luma(uint c) => (0.2126f * channel(c, 16) + 0.7152f * channel(c, 8) + 0.0722f * channel(c, 0)) / 255.0f;

fn uint lift(uint c, float floor)
{
    float l = luma(c);
    return l >= floor ? c : mix(c, 0xFFFFFF, (floor - l) / (1.0f - l));
}

fn Palette derive(Scheme s)
{
    return {
        .name = s.name,
        .text = lift(s.fg, 0.82f),
        .muted = lift(s.comment, 0.42f),
        .faint = mix(s.bg, s.comment, 0.45f),
        .red = lift(s.red, 0.45f),
        .green = lift(s.green, 0.6f),
        .orange = lift(s.orange, 0.55f),
        .yellow = lift(s.yellow, 0.68f),
        .purple = lift(s.purple, 0.5f),
        .cyan = lift(s.cyan, 0.62f),
        .panel = mix(s.bg, s.fg, 0.07f),
        .deep = mix(s.bg, 0, 0.3f),
        .row = mix(s.bg, s.blue, 0.22f),
        .focus = mix(s.bg, s.yellow, 0.13f),
        .selection = mix(s.bg, s.blue, 0.32f),
        .match = mix(s.bg, s.orange, 0.38f),
        .ink = mix(s.bg, 0, 0.4f),
        .background = s.bg,
    };
}

fn Palette palette(int index) => index == 0 ? MDV : derive(SCHEMES[index - 1]);

char[4096] storage;
usz used;
String[Role::len] styles;
Palette current = MDV;

fn String style(Role role) => styles[role];

fn String heading(int level) => styles[(Role)(level - 1)];

fn void set(Role role, String s)
{
    storage[used : s.len] = s[..];
    styles[role] = (String)storage[used : s.len];
    used += s.len;
}

fn String fg(uint c) => string::tformat("\e[38;2;%d;%d;%dm", channel(c, 16), channel(c, 8), channel(c, 0));

fn String bg(uint c) => string::tformat("\e[48;2;%d;%d;%dm", channel(c, 16), channel(c, 8), channel(c, 0));

fn void use(Palette p)
{
    current = p;
    used = 0;
    @pool()
    {
        uint[6] heads = { p.red, p.green, p.orange, p.yellow, p.purple, p.cyan };
        foreach (i, h : heads) set((Role)i, string::tformat("%s%s", fg(h), BOLD));
        set(NONE, "");
        set(STRONG, BOLD);
        set(EMPHASIS, ITALIC);
        set(STRIKEOUT, STRIKE);
        set(TEXT, fg(p.text));
        set(MUTED, fg(p.muted));
        set(FAINT, fg(p.faint));
        set(CYAN, fg(p.cyan));
        set(GREEN, fg(p.green));
        set(ORANGE, fg(p.orange));
        set(PINK, fg(p.red));
        set(YELLOW, fg(p.yellow));
        set(PURPLE, fg(p.purple));
        set(INLINE, string::tformat("%s%s", bg(p.panel), fg(p.cyan)));
        set(CODE, string::tformat("%s%s ", bg(p.panel), fg(p.cyan)));
        set(STRUCK, string::tformat("%s%s", STRIKE, fg(p.muted)));
        set(LINK, string::tformat("%s%s", fg(p.cyan), UNDERLINE));
        set(NOTE, string::tformat("%s%s", fg(p.cyan), BOLD));
        set(BADGE, string::tformat("%s%s%s", bg(p.panel), fg(p.cyan), BOLD));
        set(PATH, string::tformat("%s%s%s", bg(p.deep), fg(p.text), BOLD));
        set(BORDER, fg(p.muted));
        set(TITLE, string::tformat("%s%s", fg(p.orange), BOLD));
        set(ACTIVE, string::tformat("%s%s%s", bg(p.row), fg(p.green), BOLD));
        set(SELECTED, string::tformat("%s%s%s", bg(p.row), fg(p.text), BOLD));
        set(STATUS, string::tformat("%s%s%s", bg(p.panel), fg(p.green), BOLD));
        set(CURSOR, string::tformat("%s%s", fg(p.cyan), BOLD));
        set(FOCUS, bg(p.focus));
        set(SELECTION, bg(p.selection));
        set(MATCH, bg(p.match));
        set(FOUND, string::tformat("%s%s%s", bg(p.orange), fg(p.ink), BOLD));
        set(CURRENT, string::tformat("%s%s%s", bg(p.green), fg(p.ink), BOLD));
    };
}

fn void init() @init => use(MDV);

fn String backdrop()
{
    if (current.background == 0) return "\e]111\e\\\e]110\e\\";
    return string::tformat("\e]11;#%06x\e\\\e]10;#%06x\e\\", current.background, current.text);
}

struct Named
{
    String name;
    Role role;
}

const Named[] NAMES = {
    { "red", PINK }, { "pink", PINK }, { "green", GREEN }, { "orange", ORANGE }, { "yellow", YELLOW },
    { "purple", PURPLE }, { "magenta", PURPLE }, { "gray", MUTED }, { "grey", MUTED },
};

fn String named(String name)
{
    foreach (n : NAMES) if (n.name == name) return styles[n.role];
    return style(CYAN);
}
