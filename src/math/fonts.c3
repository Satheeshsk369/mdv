module math;

enum MathFontStyle {
    MATHBB,
    MATHCAL,
    MATHFRAK,
    MATHBF,
    MATHRM,
    MATHIT,
    MATHSF,
    MATHTT,
    BOLDSYMBOL
}

bitstruct MathFontFlags : char {
    bool blackboard : 0;
    bool script     : 1;
    bool fraktur    : 2;
    bool bold       : 3;
    bool roman      : 4;
}

struct FontDef {
    String name;
    MathFontStyle style;
    MathFontFlags flags;
}

const FontDef[] FONTS = {
    { "mathbb",     MathFontStyle.MATHBB,     { .blackboard } },
    { "mathcal",    MathFontStyle.MATHCAL,    { .script } },
    { "mathscr",    MathFontStyle.MATHCAL,    { .script } },
    { "mathfrak",   MathFontStyle.MATHFRAK,   { .fraktur } },
    { "frak",       MathFontStyle.MATHFRAK,   { .fraktur } },
    { "mathbf",     MathFontStyle.MATHBF,     { .bold } },
    { "boldsymbol", MathFontStyle.BOLDSYMBOL, { .bold } },
    { "bm",         MathFontStyle.BOLDSYMBOL, { .bold } },
    { "mathrm",     MathFontStyle.MATHRM,     { .roman } },
    { "mathit",     MathFontStyle.MATHIT,     {} },
    { "mathsf",     MathFontStyle.MATHSF,     {} },
    { "mathtt",     MathFontStyle.MATHTT,     {} }
};

fn bool lookup_font_style(String name, MathFontStyle* out_style, MathFontFlags* out_flags = null)
{
    for (usz i = 0; i < FONTS.len; i++)
    {
        if (name == FONTS[i].name)
        {
            *out_style = FONTS[i].style;
            if (out_flags != null) *out_flags = FONTS[i].flags;
            return true;
        }
    }
    return false;
}

fn char* get_mathbb_char(char c)
{
    switch (c)
    {
        case 'A': return "𝔸";
        case 'B': return "𝔹";
        case 'C': return "ℂ";
        case 'D': return "𝔻";
        case 'E': return "𝔼";
        case 'F': return "𝔽";
        case 'G': return "𝔾";
        case 'H': return "ℍ";
        case 'I': return "𝕀";
        case 'J': return "𝕁";
        case 'K': return "𝕂";
        case 'L': return "𝕃";
        case 'M': return "𝕄";
        case 'N': return "ℕ";
        case 'O': return "𝕆";
        case 'P': return "ℙ";
        case 'Q': return "ℚ";
        case 'R': return "ℝ";
        case 'S': return "𝕊";
        case 'T': return "𝕋";
        case 'U': return "𝕌";
        case 'V': return "𝕍";
        case 'W': return "𝕎";
        case 'X': return "𝕏";
        case 'Y': return "𝕐";
        case 'Z': return "ℤ";
        case '0': return "𝟘";
        case '1': return "𝟙";
        default: return null;
    }
}

fn char* get_mathcal_char(char c)
{
    switch (c)
    {
        case 'A': return "𝒜";
        case 'B': return "ℬ";
        case 'C': return "𝒞";
        case 'D': return "𝒟";
        case 'E': return "ℰ";
        case 'F': return "ℱ";
        case 'G': return "𝒢";
        case 'H': return "ℋ";
        case 'I': return "ℐ";
        case 'J': return "𝒥";
        case 'K': return "𝒦";
        case 'L': return "ℒ";
        case 'M': return "ℳ";
        case 'N': return "𝒩";
        case 'O': return "𝒪";
        case 'P': return "𝒫";
        case 'Q': return "𝒬";
        case 'R': return "ℛ";
        case 'S': return "𝒮";
        case 'T': return "𝒯";
        case 'U': return "𝒰";
        case 'V': return "𝒱";
        case 'W': return "𝒲";
        case 'X': return "𝒳";
        case 'Y': return "𝒴";
        case 'Z': return "𝒵";
        default: return null;
    }
}

fn char* get_mathfrak_char(char c)
{
    switch (c)
    {
        case 'A': return "𝔄";
        case 'B': return "𝔅";
        case 'C': return "ℭ";
        case 'D': return "𝔇";
        case 'E': return "𝔈";
        case 'F': return "𝔉";
        case 'G': return "𝔊";
        case 'H': return "ℌ";
        case 'I': return "ℑ";
        case 'J': return "𝔍";
        case 'K': return "𝔎";
        case 'L': return "𝔏";
        case 'M': return "𝔐";
        case 'N': return "𝔑";
        case 'O': return "𝔒";
        case 'P': return "𝔓";
        case 'Q': return "𝔔";
        case 'R': return "ℜ";
        case 'S': return "𝔖";
        case 'T': return "𝔗";
        case 'U': return "𝔘";
        case 'V': return "𝔙";
        case 'W': return "𝔚";
        case 'X': return "𝔛";
        case 'Y': return "𝔜";
        case 'Z': return "ℨ";
        case 'a': return "𝔞";
        case 'b': return "𝔟";
        case 'c': return "𝔠";
        case 'd': return "𝔡";
        case 'e': return "𝔢";
        case 'f': return "𝔣";
        case 'g': return "𝔤";
        case 'h': return "𝔥";
        case 'i': return "𝔦";
        case 'j': return "𝔧";
        case 'k': return "𝔨";
        case 'l': return "𝔩";
        case 'm': return "𝔪";
        case 'n': return "𝔫";
        case 'o': return "𝔬";
        case 'p': return "𝔭";
        case 'q': return "𝔮";
        case 'r': return "𝔯";
        case 's': return "𝔰";
        case 't': return "𝔱";
        case 'u': return "𝔲";
        case 'v': return "𝔳";
        case 'w': return "𝔴";
        case 'x': return "𝔵";
        case 'y': return "𝔶";
        case 'z': return "𝔷";
        default: return null;
    }
}
