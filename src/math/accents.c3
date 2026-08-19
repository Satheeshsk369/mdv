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

struct AccentDef {
    String name;
    MathAccent accent;
    String combining;
    bool overline;
    bool underline;
}

const AccentDef[] ACCENTS = {
    { "vec",       MathAccent.VEC,       "⃗", false, false },
    { "hat",       MathAccent.HAT,       "̂", false, false },
    { "bar",       MathAccent.BAR,       "̄", false, false },
    { "dot",       MathAccent.DOT,       "̇", false, false },
    { "ddot",      MathAccent.DDOT,      "̈", false, false },
    { "dddot",     MathAccent.DDDOT,     "⃛", false, false },
    { "ddddot",    MathAccent.DDDDOT,    "⃜", false, false },
    { "tilde",     MathAccent.TILDE,     "̃", false, false },
    { "acute",     MathAccent.ACUTE,     "́", false, false },
    { "grave",     MathAccent.GRAVE,     "̀", false, false },
    { "overline",  MathAccent.OVERLINE,  "̄", true,  false },
    { "underline", MathAccent.UNDERLINE, "̄", false, true }
};

fn bool lookup_accent(String name, MathAccent* out_accent, String* out_combining = null, bool* out_overline = null, bool* out_underline = null)
{
    for (usz i = 0; i < ACCENTS.len; i++)
    {
        if (name == ACCENTS[i].name)
        {
            *out_accent = ACCENTS[i].accent;
            if (out_combining != null) *out_combining = ACCENTS[i].combining;
            if (out_overline != null) *out_overline = ACCENTS[i].overline;
            if (out_underline != null) *out_underline = ACCENTS[i].underline;
            return true;
        }
    }
    return false;
}

fn char* get_accent_combining(MathAccent accent)
{
    for (usz i = 0; i < ACCENTS.len; i++)
    {
        if (ACCENTS[i].accent == accent)
        {
            return ACCENTS[i].combining.ptr;
        }
    }
    return "̄";
}
