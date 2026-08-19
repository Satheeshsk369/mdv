module logic;

struct MathBox {
    int width;
    int height;
    int baseline;
    String[] rows;
}

struct CLatexBox {
    char** rows;
    int width;
    int height;
    int baseline;
}

enum MathAtomKind {
    ORD,    // Ordinary symbol or variable (x, 2, \alpha)
    OP,     // Big operator or named function (\sum, \sin, \lim)
    BIN,    // Binary operator (+, -, \times, \cdot, \pm)
    REL,    // Relation (=, \le, \ge, \neq, \approx, \to)
    OPEN,   // Open delimiter ((, [, {, \langle)
    CLOSE,  // Close delimiter (), ], }, \rangle)
    PUNCT,  // Punctuation (,, ;, :)
    INNER   // Fractions, radicals, boxes
}

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
        case 'A': return "";
        case 'B': return "";
        case 'C': return "ℂ";
        case 'D': return "";
        case 'E': return "";
        case 'F': return "";
        case 'G': return "";
        case 'H': return "ℍ";
        case 'I': return "";
        case 'J': return "";
        case 'K': return "";
        case 'L': return "";
        case 'M': return "";
        case 'N': return "ℕ";
        case 'O': return "";
        case 'P': return "ℙ";
        case 'Q': return "ℚ";
        case 'R': return "ℝ";
        case 'S': return "";
        case 'T': return "";
        case 'U': return "";
        case 'V': return "";
        case 'W': return "";
        case 'X': return "";
        case 'Y': return "";
        case 'Z': return "ℤ";
        case '0': return "";
        case '1': return "";
        default: return null;
    }
}

fn char* get_mathcal_char(char c)
{
    switch (c)
    {
        case 'A': return "";
        case 'B': return "ℬ";
        case 'C': return "";
        case 'D': return "";
        case 'E': return "ℰ";
        case 'F': return "ℱ";
        case 'G': return "";
        case 'H': return "ℋ";
        case 'I': return "ℐ";
        case 'J': return "";
        case 'K': return "";
        case 'L': return "ℒ";
        case 'M': return "ℳ";
        case 'N': return "";
        case 'O': return "";
        case 'P': return "";
        case 'Q': return "";
        case 'R': return "ℛ";
        case 'S': return "";
        case 'T': return "";
        case 'U': return "";
        case 'V': return "";
        case 'W': return "";
        case 'X': return "";
        case 'Y': return "";
        case 'Z': return "";
        default: return null;
    }
}

fn char* get_mathfrak_char(char c)
{
    switch (c)
    {
        case 'A': return "";
        case 'B': return "";
        case 'C': return "ℭ";
        case 'D': return "";
        case 'E': return "";
        case 'F': return "";
        case 'G': return "";
        case 'H': return "ℌ";
        case 'I': return "ℑ";
        case 'J': return "";
        case 'K': return "";
        case 'L': return "";
        case 'M': return "";
        case 'N': return "";
        case 'O': return "";
        case 'P': return "";
        case 'Q': return "";
        case 'R': return "ℜ";
        case 'S': return "";
        case 'T': return "";
        case 'U': return "";
        case 'V': return "";
        case 'W': return "";
        case 'X': return "";
        case 'Y': return "";
        case 'Z': return "ℨ";
        case 'a': return "";
        case 'b': return "";
        case 'c': return "";
        case 'd': return "";
        case 'e': return "";
        case 'f': return "";
        case 'g': return "";
        case 'h': return "";
        case 'i': return "";
        case 'j': return "";
        case 'k': return "";
        case 'l': return "";
        case 'm': return "";
        case 'n': return "";
        case 'o': return "";
        case 'p': return "";
        case 'q': return "";
        case 'r': return "";
        case 's': return "";
        case 't': return "";
        case 'u': return "";
        case 'v': return "";
        case 'w': return "";
        case 'x': return "";
        case 'y': return "";
        case 'z': return "";
        default: return null;
    }
}

bitstruct MathCmdFlags : uint {
    bool opt_arg       : 0; // Accepts optional [...] argument (e.g. \sqrt, \xrightarrow, \tag)
    bool big_op        : 1; // Operator with 2D limits (e.g. \sum, \prod, \bigcup)
    bool integral      : 2; // Integral operator (\int, \iint, \oint)
    bool fraction      : 3; // Fraction / binomial 2-group stacked layout
    bool box           : 4; // Single-group frame or decorator (\boxed, \underline, \cancel)
    bool limit         : 5; // Named limit operator (\lim, \max, \min)
    bool spacing       : 6; // Spacing command (\quad, \qquad)
    uint arity         : 8..11; // Number of required {} group arguments (0, 1, 2)
}

enum MathCommand {
    TAG,
    XRIGHTARROW,
    XLEFTARROW,
    XLEFTRIGHTARROW,
    UNDERLINE,
    OVERRIGHTARROW,
    OVERLEFTARROW,
    CANCEL,
    BCANCEL,
    XCANCEL,
    COLOR,
    TEXTCOLOR,
    MATHCOLOR,
    FRAC,
    DFRAC,
    TFRAC,
    CFRAC,
    BOXED,
    BINOM,
    DBINOM,
    TBINOM,
    OVERSET,
    STACKREL,
    UNDERSET,
    OVERBRACE,
    UNDERBRACE,
    SUBSTACK,
    SQRT,
    SUM,
    PROD,
    COPROD,
    BIG_UNION,
    BIG_INTERSECTION,
    BIG_PLUS,
    BIG_TIMES,
    BIG_DOT,
    BIG_SQ_CUP,
    BIG_VEE,
    BIG_WEDGE,
    INT,
    IINT,
    IIINT,
    OINT,
    OIINT,
    OIIINT,
    LIM,
    LIMINF,
    LIMSUP,
    MAX,
    MIN,
    SUP,
    INF,
    ARGMAX,
    ARGMIN,
    PMOD,
    POD,
    BMOD,
    LEFT,
    BEGIN,
    TEXT,
    QUAD,
    QQUAD
}

struct CommandDef {
    String name;
    MathCommand cmd;
    MathCmdFlags flags;
}

const CommandDef[] COMMANDS = {
    { "tag", MathCommand.TAG, { .opt_arg, .arity = 1 } },
    { "xrightarrow", MathCommand.XRIGHTARROW, { .opt_arg, .arity = 1 } },
    { "xleftarrow", MathCommand.XLEFTARROW, { .opt_arg, .arity = 1 } },
    { "xleftrightarrow", MathCommand.XLEFTRIGHTARROW, { .opt_arg, .arity = 1 } },
    { "underline", MathCommand.UNDERLINE, { .box, .arity = 1 } },
    { "overrightarrow", MathCommand.OVERRIGHTARROW, { .box, .arity = 1 } },
    { "overleftarrow", MathCommand.OVERLEFTARROW, { .box, .arity = 1 } },
    { "cancel", MathCommand.CANCEL, { .box, .arity = 1 } },
    { "bcancel", MathCommand.BCANCEL, { .box, .arity = 1 } },
    { "xcancel", MathCommand.XCANCEL, { .box, .arity = 1 } },
    { "color", MathCommand.COLOR, { .arity = 2 } },
    { "textcolor", MathCommand.TEXTCOLOR, { .arity = 2 } },
    { "mathcolor", MathCommand.MATHCOLOR, { .arity = 2 } },
    { "frac", MathCommand.FRAC, { .fraction, .arity = 2 } },
    { "dfrac", MathCommand.DFRAC, { .fraction, .arity = 2 } },
    { "tfrac", MathCommand.TFRAC, { .fraction, .arity = 2 } },
    { "cfrac", MathCommand.CFRAC, { .fraction, .arity = 2 } },
    { "boxed", MathCommand.BOXED, { .box, .arity = 1 } },
    { "binom", MathCommand.BINOM, { .fraction, .arity = 2 } },
    { "dbinom", MathCommand.DBINOM, { .fraction, .arity = 2 } },
    { "tbinom", MathCommand.TBINOM, { .fraction, .arity = 2 } },
    { "overset", MathCommand.OVERSET, { .arity = 2 } },
    { "stackrel", MathCommand.STACKREL, { .arity = 2 } },
    { "underset", MathCommand.UNDERSET, { .arity = 2 } },
    { "overbrace", MathCommand.OVERBRACE, { .arity = 1 } },
    { "underbrace", MathCommand.UNDERBRACE, { .arity = 1 } },
    { "substack", MathCommand.SUBSTACK, { .arity = 1 } },
    { "sqrt", MathCommand.SQRT, { .opt_arg, .arity = 1 } },
    { "sum", MathCommand.SUM, { .big_op } },
    { "prod", MathCommand.PROD, { .big_op } },
    { "coprod", MathCommand.COPROD, { .big_op } },
    { "bigcup", MathCommand.BIG_UNION, { .big_op } },
    { "bigcap", MathCommand.BIG_INTERSECTION, { .big_op } },
    { "bigoplus", MathCommand.BIG_PLUS, { .big_op } },
    { "bigotimes", MathCommand.BIG_TIMES, { .big_op } },
    { "bigodot", MathCommand.BIG_DOT, { .big_op } },
    { "bigsqcup", MathCommand.BIG_SQ_CUP, { .big_op } },
    { "bigvee", MathCommand.BIG_VEE, { .big_op } },
    { "bigwedge", MathCommand.BIG_WEDGE, { .big_op } },
    { "int", MathCommand.INT, { .integral } },
    { "iint", MathCommand.IINT, { .integral } },
    { "iiint", MathCommand.IIINT, { .integral } },
    { "oint", MathCommand.OINT, { .integral } },
    { "oiint", MathCommand.OIINT, { .integral } },
    { "oiiint", MathCommand.OIIINT, { .integral } },
    { "lim", MathCommand.LIM, { .limit } },
    { "liminf", MathCommand.LIMINF, { .limit } },
    { "limsup", MathCommand.LIMSUP, { .limit } },
    { "max", MathCommand.MAX, { .limit } },
    { "min", MathCommand.MIN, { .limit } },
    { "sup", MathCommand.SUP, { .limit } },
    { "inf", MathCommand.INF, { .limit } },
    { "argmax", MathCommand.ARGMAX, { .limit } },
    { "argmin", MathCommand.ARGMIN, { .limit } },
    { "pmod", MathCommand.PMOD, { .arity = 1 } },
    { "pod", MathCommand.POD, { .arity = 1 } },
    { "bmod", MathCommand.BMOD, { .arity = 0 } },
    { "left", MathCommand.LEFT, { .arity = 1 } },
    { "begin", MathCommand.BEGIN, { .arity = 1 } },
    { "text", MathCommand.TEXT, { .arity = 1 } },
    { "quad", MathCommand.QUAD, { .spacing } },
    { "qquad", MathCommand.QQUAD, { .spacing } }
};

fn bool lookup_command(String name, MathCommand* out_cmd, MathCmdFlags* out_flags = null)
{
    for (usz i = 0; i < COMMANDS.len; i++)
    {
        if (name == COMMANDS[i].name)
        {
            *out_cmd = COMMANDS[i].cmd;
            if (out_flags != null)
            {
                *out_flags = COMMANDS[i].flags;
            }
            return true;
        }
    }
    return false;
}

bitstruct MathEnvFlags : uint {
    bool matrix      : 0; // Standard matrix grid
    bool cases       : 1; // Piecewise cases block
    bool align       : 2; // Multi-line derivation aligned at &
    bool gather      : 3; // Centered multi-line formulas
    bool array       : 4; // Generic array grid
    uint col_gap     : 5..7; // Inter-column horizontal gap spaces
    char align_mode  : 8..15; // 'C' (center), 'L' (left), 'A' (alternating math)
    char delim_left  : 16..23; // Left delimiter: '(', '[', '{', '|', 'V', or 0
    char delim_right : 24..31; // Right delimiter: ')', ']', '}', '|', 'V', or 0
}

enum MathEnvironment {
    MATRIX,
    PMATRIX,
    BMATRIX,
    VMATRIX,
    VM_MATRIX,
    B_MATRIX,
    SMALLMATRIX,
    CASES,
    DCASES,
    RCASES,
    ALIGN,
    ALIGNED,
    SPLIT,
    GATHER,
    GATHERED,
    FLALIGN,
    EQNARRAY,
    ARRAY
}

struct EnvironmentDef {
    String name;
    MathEnvironment env;
    MathEnvFlags flags;
}

const EnvironmentDef[] ENVIRONMENTS = {
    { "matrix",      MathEnvironment.MATRIX,      { .matrix, .col_gap = 2, .align_mode = 'C' } },
    { "pmatrix",     MathEnvironment.PMATRIX,     { .matrix, .col_gap = 2, .align_mode = 'C', .delim_left = '(', .delim_right = ')' } },
    { "bmatrix",     MathEnvironment.BMATRIX,     { .matrix, .col_gap = 2, .align_mode = 'C', .delim_left = '[', .delim_right = ']' } },
    { "vmatrix",     MathEnvironment.VMATRIX,     { .matrix, .col_gap = 2, .align_mode = 'C', .delim_left = '|', .delim_right = '|' } },
    { "Vmatrix",     MathEnvironment.VM_MATRIX,   { .matrix, .col_gap = 2, .align_mode = 'C', .delim_left = 'V', .delim_right = 'V' } },
    { "Bmatrix",     MathEnvironment.B_MATRIX,    { .matrix, .col_gap = 2, .align_mode = 'C', .delim_left = '{', .delim_right = '}' } },
    { "smallmatrix", MathEnvironment.SMALLMATRIX, { .matrix, .col_gap = 2, .align_mode = 'C' } },
    { "cases",       MathEnvironment.CASES,       { .cases,  .col_gap = 3, .align_mode = 'L', .delim_left = '{' } },
    { "dcases",      MathEnvironment.DCASES,      { .cases,  .col_gap = 3, .align_mode = 'L', .delim_left = '{' } },
    { "rcases",      MathEnvironment.RCASES,      { .cases,  .col_gap = 3, .align_mode = 'L', .delim_right = '}' } },
    { "align",       MathEnvironment.ALIGN,       { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "align*",      MathEnvironment.ALIGN,       { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "aligned",     MathEnvironment.ALIGNED,     { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "split",       MathEnvironment.SPLIT,       { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "flalign",     MathEnvironment.FLALIGN,     { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "flalign*",    MathEnvironment.FLALIGN,     { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "eqnarray",    MathEnvironment.EQNARRAY,    { .align,  .col_gap = 0, .align_mode = 'A' } },
    { "gather",      MathEnvironment.GATHER,      { .gather, .col_gap = 0, .align_mode = 'C' } },
    { "gather*",     MathEnvironment.GATHER,      { .gather, .col_gap = 0, .align_mode = 'C' } },
    { "gathered",    MathEnvironment.GATHERED,    { .gather, .col_gap = 0, .align_mode = 'C' } },
    { "array",       MathEnvironment.ARRAY,       { .array,  .col_gap = 0, .align_mode = 'A' } }
};

fn bool lookup_environment(String name, MathEnvironment* out_env, MathEnvFlags* out_flags = null)
{
    for (usz i = 0; i < ENVIRONMENTS.len; i++)
    {
        if (name == ENVIRONMENTS[i].name)
        {
            *out_env = ENVIRONMENTS[i].env;
            if (out_flags != null)
            {
                *out_flags = ENVIRONMENTS[i].flags;
            }
            return true;
        }
    }
    return false;
}

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

struct SymbolEntry {
    String name;
    String glyph;
    MathAtomKind kind;
}

const SymbolEntry[] SYMBOLS = {
    // ── Greek Lowercase ──────────────────────────────────────────────────────
    { "alpha", "α", MathAtomKind.ORD },
    { "beta", "β", MathAtomKind.ORD },
    { "gamma", "γ", MathAtomKind.ORD },
    { "delta", "δ", MathAtomKind.ORD },
    { "epsilon", "ϵ", MathAtomKind.ORD },
    { "varepsilon", "ε", MathAtomKind.ORD },
    { "zeta", "ζ", MathAtomKind.ORD },
    { "eta", "η", MathAtomKind.ORD },
    { "theta", "θ", MathAtomKind.ORD },
    { "vartheta", "ϑ", MathAtomKind.ORD },
    { "iota", "ι", MathAtomKind.ORD },
    { "kappa", "κ", MathAtomKind.ORD },
    { "varkappa", "ϰ", MathAtomKind.ORD },
    { "lambda", "λ", MathAtomKind.ORD },
    { "mu", "μ", MathAtomKind.ORD },
    { "nu", "ν", MathAtomKind.ORD },
    { "xi", "ξ", MathAtomKind.ORD },
    { "omicron", "ο", MathAtomKind.ORD },
    { "pi", "π", MathAtomKind.ORD },
    { "varpi", "ϖ", MathAtomKind.ORD },
    { "rho", "ρ", MathAtomKind.ORD },
    { "varrho", "ϱ", MathAtomKind.ORD },
    { "sigma", "σ", MathAtomKind.ORD },
    { "varsigma", "ς", MathAtomKind.ORD },
    { "tau", "τ", MathAtomKind.ORD },
    { "upsilon", "υ", MathAtomKind.ORD },
    { "phi", "ϕ", MathAtomKind.ORD },
    { "varphi", "φ", MathAtomKind.ORD },
    { "chi", "χ", MathAtomKind.ORD },
    { "psi", "ψ", MathAtomKind.ORD },
    { "omega", "ω", MathAtomKind.ORD },
    { "digamma", "ϝ", MathAtomKind.ORD },

    // ── Greek Uppercase ──────────────────────────────────────────────────────
    { "Alpha", "Α", MathAtomKind.ORD },
    { "Beta", "Β", MathAtomKind.ORD },
    { "Gamma", "Γ", MathAtomKind.ORD },
    { "Delta", "Δ", MathAtomKind.ORD },
    { "Epsilon", "Ε", MathAtomKind.ORD },
    { "Zeta", "Ζ", MathAtomKind.ORD },
    { "Eta", "Η", MathAtomKind.ORD },
    { "Theta", "Θ", MathAtomKind.ORD },
    { "Iota", "Ι", MathAtomKind.ORD },
    { "Kappa", "Κ", MathAtomKind.ORD },
    { "Lambda", "Λ", MathAtomKind.ORD },
    { "Mu", "Μ", MathAtomKind.ORD },
    { "Nu", "Ν", MathAtomKind.ORD },
    { "Xi", "Ξ", MathAtomKind.ORD },
    { "Omicron", "Ο", MathAtomKind.ORD },
    { "Pi", "Π", MathAtomKind.ORD },
    { "Rho", "Ρ", MathAtomKind.ORD },
    { "Sigma", "Σ", MathAtomKind.ORD },
    { "Tau", "Τ", MathAtomKind.ORD },
    { "Upsilon", "Υ", MathAtomKind.ORD },
    { "Phi", "Φ", MathAtomKind.ORD },
    { "Chi", "Χ", MathAtomKind.ORD },
    { "Psi", "Ψ", MathAtomKind.ORD },
    { "Omega", "Ω", MathAtomKind.ORD },
    { "Digamma", "Ϝ", MathAtomKind.ORD },

    // ── Standard Number Sets & Systems (AMS blackboard shortcuts) ───────────
    { "N", "ℕ", MathAtomKind.ORD },
    { "Z", "ℤ", MathAtomKind.ORD },
    { "Q", "ℚ", MathAtomKind.ORD },
    { "R", "ℝ", MathAtomKind.ORD },
    { "C", "ℂ", MathAtomKind.ORD },
    { "H", "ℍ", MathAtomKind.ORD },
    { "O", "", MathAtomKind.ORD },

    // ── Hebrew / Set Cardinalities ───────────────────────────────────────────
    { "aleph", "ℵ", MathAtomKind.ORD },
    { "beth", "ℶ", MathAtomKind.ORD },
    { "gimel", "ℷ", MathAtomKind.ORD },
    { "daleth", "ℸ", MathAtomKind.ORD },

    // ── Calculus & Differential Symbols ──────────────────────────────────────
    { "partial", "∂", MathAtomKind.ORD },
    { "nabla", "∇", MathAtomKind.ORD },
    { "infty", "∞", MathAtomKind.ORD },
    { "prime", "′", MathAtomKind.ORD },
    { "dprime", "″", MathAtomKind.ORD },
    { "trprime", "‴", MathAtomKind.ORD },
    { "qprime", "⁗", MathAtomKind.ORD },

    // ── Standard Binary Operators ────────────────────────────────────────────
    { "pm", "±", MathAtomKind.BIN },
    { "mp", "∓", MathAtomKind.BIN },
    { "times", "×", MathAtomKind.BIN },
    { "cdot", "⋅", MathAtomKind.BIN },
    { "div", "÷", MathAtomKind.BIN },
    { "ast", "*", MathAtomKind.BIN },
    { "star", "⋆", MathAtomKind.BIN },
    { "circ", "∘", MathAtomKind.BIN },
    { "bullet", "∙", MathAtomKind.BIN },
    { "oplus", "⊕", MathAtomKind.BIN },
    { "ominus", "⊖", MathAtomKind.BIN },
    { "otimes", "⊗", MathAtomKind.BIN },
    { "oslash", "⊘", MathAtomKind.BIN },
    { "odot", "⊙", MathAtomKind.BIN },
    { "bigcirc", "◯", MathAtomKind.BIN },
    { "dagger", "†", MathAtomKind.BIN },
    { "ddagger", "‡", MathAtomKind.BIN },
    { "amalg", "⨿", MathAtomKind.BIN },
    { "setminus", "∖", MathAtomKind.BIN },
    { "cap", "∩", MathAtomKind.BIN },
    { "cup", "∪", MathAtomKind.BIN },
    { "uplus", "⊎", MathAtomKind.BIN },
    { "sqcap", "⊓", MathAtomKind.BIN },
    { "sqcup", "⊔", MathAtomKind.BIN },
    { "wedge", "∧", MathAtomKind.BIN },
    { "vee", "∨", MathAtomKind.BIN },
    { "land", "∧", MathAtomKind.BIN },
    { "lor", "∨", MathAtomKind.BIN },
    { "wr", "≀", MathAtomKind.BIN },

    // ── Relational Operators ─────────────────────────────────────────────────
    { "le", "≤", MathAtomKind.REL },
    { "leq", "≤", MathAtomKind.REL },
    { "leqslant", "⩽", MathAtomKind.REL },
    { "ge", "≥", MathAtomKind.REL },
    { "geq", "≥", MathAtomKind.REL },
    { "geqslant", "⩾", MathAtomKind.REL },
    { "ne", "≠", MathAtomKind.REL },
    { "neq", "≠", MathAtomKind.REL },
    { "approx", "≈", MathAtomKind.REL },
    { "sim", "∼", MathAtomKind.REL },
    { "simeq", "≃", MathAtomKind.REL },
    { "cong", "≅", MathAtomKind.REL },
    { "equiv", "≡", MathAtomKind.REL },
    { "propto", "∝", MathAtomKind.REL },
    { "ll", "≪", MathAtomKind.REL },
    { "lll", "⋘", MathAtomKind.REL },
    { "gg", "≫", MathAtomKind.REL },
    { "ggg", "⋙", MathAtomKind.REL },
    { "subset", "⊂", MathAtomKind.REL },
    { "supset", "⊃", MathAtomKind.REL },
    { "subseteq", "⊆", MathAtomKind.REL },
    { "supseteq", "⊇", MathAtomKind.REL },
    { "nsubseteq", "⊈", MathAtomKind.REL },
    { "nsupseteq", "⊉", MathAtomKind.REL },
    { "subsetneq", "⊊", MathAtomKind.REL },
    { "supsetneq", "⊋", MathAtomKind.REL },
    { "sqsubset", "⊏", MathAtomKind.REL },
    { "sqsupset", "⊐", MathAtomKind.REL },
    { "sqsubseteq", "⊑", MathAtomKind.REL },
    { "sqsupseteq", "⊒", MathAtomKind.REL },
    { "in", "∈", MathAtomKind.REL },
    { "notin", "∉", MathAtomKind.REL },
    { "ni", "∋", MathAtomKind.REL },
    { "owns", "∋", MathAtomKind.REL },
    { "prec", "≺", MathAtomKind.REL },
    { "succ", "≻", MathAtomKind.REL },
    { "preceq", "≼", MathAtomKind.REL },
    { "succeq", "≽", MathAtomKind.REL },
    { "perp", "⊥", MathAtomKind.REL },
    { "mid", "∣", MathAtomKind.REL },
    { "parallel", "∥", MathAtomKind.REL },
    { "nshortmid", "∤", MathAtomKind.REL },
    { "nshortparallel", "∦", MathAtomKind.REL },
    { "vdash", "⊢", MathAtomKind.REL },
    { "dashv", "⊣", MathAtomKind.REL },
    { "vDash", "⊨", MathAtomKind.REL },
    { "Vdash", "⊩", MathAtomKind.REL },
    { "VDash", "⊫", MathAtomKind.REL },
    { "nvdash", "⊬", MathAtomKind.REL },
    { "nvDash", "⊭", MathAtomKind.REL },
    { "nVdash", "⊮", MathAtomKind.REL },
    { "nVDash", "⊯", MathAtomKind.REL },
    { "models", "⊨", MathAtomKind.REL },
    { "bowtie", "⋈", MathAtomKind.REL },
    { "smile", "⌣", MathAtomKind.REL },
    { "frown", "⌢", MathAtomKind.REL },
    { "asymp", "≍", MathAtomKind.REL },
    { "doteq", "≐", MathAtomKind.REL },
    { "nleq", "≰", MathAtomKind.REL },
    { "ngeq", "≱", MathAtomKind.REL },
    { "nsim", "≁", MathAtomKind.REL },
    { "ncong", "≇", MathAtomKind.REL },

    // ── Arrows ───────────────────────────────────────────────────────────────
    { "to", "→", MathAtomKind.REL },
    { "rightarrow", "→", MathAtomKind.REL },
    { "leftarrow", "←", MathAtomKind.REL },
    { "leftrightarrow", "↔", MathAtomKind.REL },
    { "Rightarrow", "⇒", MathAtomKind.REL },
    { "Leftarrow", "⇐", MathAtomKind.REL },
    { "Leftrightarrow", "⇔", MathAtomKind.REL },
    { "iff", "⟺", MathAtomKind.REL },
    { "implies", "⟹", MathAtomKind.REL },
    { "mapsto", "↦", MathAtomKind.REL },
    { "longleftarrow", "⟵", MathAtomKind.REL },
    { "longrightarrow", "⟶", MathAtomKind.REL },
    { "longleftrightarrow", "⟷", MathAtomKind.REL },
    { "Longleftarrow", "⟸", MathAtomKind.REL },
    { "Longrightarrow", "⟹", MathAtomKind.REL },
    { "Longleftrightarrow", "⟺", MathAtomKind.REL },
    { "uparrow", "↑", MathAtomKind.REL },
    { "downarrow", "↓", MathAtomKind.REL },
    { "updownarrow", "↕", MathAtomKind.REL },
    { "Uparrow", "⇑", MathAtomKind.REL },
    { "Downarrow", "⇓", MathAtomKind.REL },
    { "Updownarrow", "⇕", MathAtomKind.REL },
    { "nearrow", "↗", MathAtomKind.REL },
    { "searrow", "↘", MathAtomKind.REL },
    { "nwarrow", "↖", MathAtomKind.REL },
    { "swarrow", "↙", MathAtomKind.REL },
    { "leftharpoonup", "↼", MathAtomKind.REL },
    { "leftharpoondown", "↽", MathAtomKind.REL },
    { "rightharpoonup", "⇀", MathAtomKind.REL },
    { "rightharpoondown", "⇁", MathAtomKind.REL },
    { "rightleftharpoons", "⇌", MathAtomKind.REL },
    { "leftrightharpoons", "⇋", MathAtomKind.REL },

    // ── Logic, Sets & Quantifiers ────────────────────────────────────────────
    { "forall", "∀", MathAtomKind.ORD },
    { "exists", "∃", MathAtomKind.ORD },
    { "nexists", "∄", MathAtomKind.ORD },
    { "neg", "¬", MathAtomKind.ORD },
    { "lnot", "¬", MathAtomKind.ORD },
    { "top", "⊤", MathAtomKind.ORD },
    { "bot", "⊥", MathAtomKind.ORD },
    { "emptyset", "∅", MathAtomKind.ORD },
    { "varnothing", "∅", MathAtomKind.ORD },

    // ── Miscellaneous Symbols & Geometry ─────────────────────────────────────
    { "angle", "∠", MathAtomKind.ORD },
    { "measuredangle", "∡", MathAtomKind.ORD },
    { "sphericalangle", "∢", MathAtomKind.ORD },
    { "triangle", "△", MathAtomKind.ORD },
    { "triangledown", "▽", MathAtomKind.ORD },
    { "triangleleft", "◁", MathAtomKind.BIN },
    { "triangleright", "▷", MathAtomKind.BIN },
    { "ntriangleleft", "⋪", MathAtomKind.REL },
    { "ntriangleright", "⋫", MathAtomKind.REL },
    { "diamond", "◇", MathAtomKind.BIN },
    { "square", "□", MathAtomKind.ORD },
    { "Box", "□", MathAtomKind.ORD },
    { "Diamond", "◇", MathAtomKind.ORD },
    { "hbar", "ℏ", MathAtomKind.ORD },
    { "hslash", "ℏ", MathAtomKind.ORD },
    { "ell", "ℓ", MathAtomKind.ORD },
    { "wp", "℘", MathAtomKind.ORD },
    { "Re", "ℜ", MathAtomKind.ORD },
    { "Im", "ℑ", MathAtomKind.ORD },
    { "mho", "℧", MathAtomKind.ORD },
    { "eth", "ð", MathAtomKind.ORD },
    { "flat", "♭", MathAtomKind.ORD },
    { "natural", "♮", MathAtomKind.ORD },
    { "sharp", "♯", MathAtomKind.ORD },
    { "clubsuit", "♣", MathAtomKind.ORD },
    { "diamondsuit", "♢", MathAtomKind.ORD },
    { "heartsuit", "♡", MathAtomKind.ORD },
    { "spadesuit", "♠", MathAtomKind.ORD },
    { "ulcorner", "⌜", MathAtomKind.OPEN },
    { "urcorner", "⌝", MathAtomKind.CLOSE },
    { "llcorner", "⌞", MathAtomKind.OPEN },
    { "lrcorner", "⌟", MathAtomKind.CLOSE },

    // ── Delimiters & Brackets ────────────────────────────────────────────────
    { "langle", "⟨", MathAtomKind.OPEN },
    { "rangle", "⟩", MathAtomKind.CLOSE },
    { "lfloor", "⌊", MathAtomKind.OPEN },
    { "rfloor", "⌋", MathAtomKind.CLOSE },
    { "lceil", "⌈", MathAtomKind.OPEN },
    { "rceil", "⌉", MathAtomKind.CLOSE },
    { "backslash", "\\", MathAtomKind.ORD },
    { "vert", "|", MathAtomKind.ORD },
    { "Vert", "‖", MathAtomKind.ORD },

    // ── Ellipses ─────────────────────────────────────────────────────────────
    { "dots", "…", MathAtomKind.PUNCT },
    { "cdots", "⋯", MathAtomKind.PUNCT },
    { "ldots", "…", MathAtomKind.PUNCT },
    { "vdots", "⋮", MathAtomKind.PUNCT },
    { "ddots", "⋱", MathAtomKind.PUNCT },
    { "iddots", "⋰", MathAtomKind.PUNCT }
};

fn bool lookup_symbol(String name, String* out_glyph, MathAtomKind* out_kind = null)
{
    for (usz i = 0; i < SYMBOLS.len; i++)
    {
        if (name == SYMBOLS[i].name)
        {
            *out_glyph = SYMBOLS[i].glyph;
            if (out_kind != null) *out_kind = SYMBOLS[i].kind;
            return true;
        }
    }
    return false;
}
