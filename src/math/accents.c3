module math;

enum MathAccent {
    VEC,
    HAT,
    BAR,
    DOT,
    DDOT,
    DDDOT,
    DDDDOT,
    TILDE,
    ACUTE,
    GRAVE,
    OVERLINE,
    UNDERLINE
}

fn bool lookup_accent(String name, MathAccent* out_accent)
{
    if (name == "vec") { *out_accent = MathAccent.VEC; return true; }
    if (name == "hat") { *out_accent = MathAccent.HAT; return true; }
    if (name == "bar") { *out_accent = MathAccent.BAR; return true; }
    if (name == "dot") { *out_accent = MathAccent.DOT; return true; }
    if (name == "ddot") { *out_accent = MathAccent.DDOT; return true; }
    if (name == "dddot") { *out_accent = MathAccent.DDDOT; return true; }
    if (name == "ddddot") { *out_accent = MathAccent.DDDDOT; return true; }
    if (name == "tilde") { *out_accent = MathAccent.TILDE; return true; }
    if (name == "acute") { *out_accent = MathAccent.ACUTE; return true; }
    if (name == "grave") { *out_accent = MathAccent.GRAVE; return true; }
    if (name == "overline") { *out_accent = MathAccent.OVERLINE; return true; }
    if (name == "underline") { *out_accent = MathAccent.UNDERLINE; return true; }
    return false;
}

fn char* get_accent_combining(MathAccent accent)
{
    switch (accent)
    {
        case VEC: return "⃗";
        case HAT: return "̂";
        case BAR:
        case OVERLINE:
        case UNDERLINE: return "̄";
        case DOT: return "̇";
        case DDOT: return "̈";
        case DDDOT: return "⃛";
        case DDDDOT: return "⃜";
        case TILDE: return "̃";
        case ACUTE: return "́";
        case GRAVE: return "̀";
    }
}
