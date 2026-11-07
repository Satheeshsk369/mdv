module tex;

struct MathBox {
    int width;
    int height;
    int baseline;
    String[] rows;
}

enum MathAtomKind {
    ORD,
    OP,
    BIN,
    REL,
    OPEN,
    CLOSE,
    PUNCT,
    INNER
}

struct Alphabet
{
    Char32 upper;
    Char32 lower;
    Char32 digits;
    String holes;
    Char32[] fills;
}

const Alphabet DOUBLE = { 0x1D538, 0, 0x1D7D8, "CHNPQRZ", { 0x2102, 0x210D, 0x2115, 0x2119, 0x211A, 0x211D, 0x2124 } };
const Alphabet SCRIPT = { 0x1D49C, 0, 0, "BEFHILMR", { 0x212C, 0x2130, 0x2131, 0x210B, 0x2110, 0x2112, 0x2133, 0x211B } };
const Alphabet FRAKTUR = { 0x1D504, 0x1D51E, 0, "CHIRZ", { 0x212D, 0x210C, 0x2111, 0x211C, 0x2128 } };

struct Font
{
    String name;
    Alphabet alphabet;
}

const Font[] FONTS = {
    { "mathbb", DOUBLE },
    { "mathcal", SCRIPT },
    { "mathscr", SCRIPT },
    { "mathfrak", FRAKTUR },
    { "frak", FRAKTUR },
    { "mathbf", {} },
    { "boldsymbol", {} },
    { "bm", {} },
    { "mathrm", {} },
    { "mathit", {} },
    { "mathsf", {} },
    { "mathtt", {} },
};

fn bool font(String name, Alphabet* out)
{
    foreach (f : FONTS)
    {
        if (f.name != name) continue;
        *out = f.alphabet;
        return true;
    }
    return false;
}

fn Char32 Alphabet.map(&self, char c)
{
    if (self.upper == 0) return 0;
    if (try i = self.holes.index_of_char(c)) return self.fills[i];
    if (c >= 'A' && c <= 'Z') return self.upper + c - 'A';
    if (c >= 'a' && c <= 'z' && self.lower) return self.lower + c - 'a';
    if (c >= '0' && c <= '9' && self.digits) return self.digits + c - '0';
    return 0;
}

bitstruct MathCmdFlags : uint {
    bool optArg       : 0;
    bool bigOp        : 1;
    bool integral      : 2;
    bool fraction      : 3;
    bool box           : 4;
    bool limit         : 5;
    bool spacing       : 6;
    uint arity         : 8..11;
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
    OPERATORNAME,
    QUAD,
    QQUAD,
    PHANTOM
}

struct CommandDef {
    String name;
    MathCommand cmd;
    MathCmdFlags flags;
}

const CommandDef[] COMMANDS = {
    { "tag", MathCommand.TAG, { .optArg, .arity = 1 } },
    { "xrightarrow", MathCommand.XRIGHTARROW, { .optArg, .arity = 1 } },
    { "xleftarrow", MathCommand.XLEFTARROW, { .optArg, .arity = 1 } },
    { "xleftrightarrow", MathCommand.XLEFTRIGHTARROW, { .optArg, .arity = 1 } },
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
    { "sqrt", MathCommand.SQRT, { .optArg, .arity = 1 } },
    { "sum", MathCommand.SUM, { .bigOp } },
    { "prod", MathCommand.PROD, { .bigOp } },
    { "coprod", MathCommand.COPROD, { .bigOp } },
    { "bigcup", MathCommand.BIG_UNION, { .bigOp } },
    { "bigcap", MathCommand.BIG_INTERSECTION, { .bigOp } },
    { "bigoplus", MathCommand.BIG_PLUS, { .bigOp } },
    { "bigotimes", MathCommand.BIG_TIMES, { .bigOp } },
    { "bigodot", MathCommand.BIG_DOT, { .bigOp } },
    { "bigsqcup", MathCommand.BIG_SQ_CUP, { .bigOp } },
    { "bigvee", MathCommand.BIG_VEE, { .bigOp } },
    { "bigwedge", MathCommand.BIG_WEDGE, { .bigOp } },
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
    { "textbf", MathCommand.TEXT, { .arity = 1 } },
    { "textit", MathCommand.TEXT, { .arity = 1 } },
    { "textrm", MathCommand.TEXT, { .arity = 1 } },
    { "textsf", MathCommand.TEXT, { .arity = 1 } },
    { "texttt", MathCommand.TEXT, { .arity = 1 } },
    { "textnormal", MathCommand.TEXT, { .arity = 1 } },
    { "mbox", MathCommand.TEXT, { .arity = 1 } },
    { "phantom", MathCommand.PHANTOM, { .arity = 1 } },
    { "hphantom", MathCommand.PHANTOM, { .arity = 1 } },
    { "operatorname", MathCommand.OPERATORNAME, { .arity = 1 } },
    { "quad", MathCommand.QUAD, { .spacing } },
    { "qquad", MathCommand.QQUAD, { .spacing } }
};

fn bool command(String name, MathCommand* outCmd, MathCmdFlags* outFlags = null)
{
    for (usz i = 0; i < COMMANDS.len; i++)
    {
        if (name == COMMANDS[i].name)
        {
            *outCmd = COMMANDS[i].cmd;
            if (outFlags != null)
            {
                *outFlags = COMMANDS[i].flags;
            }
            return true;
        }
    }
    return false;
}

bitstruct MathEnvFlags : uint {
    bool argument    : 0;
    uint colGap     : 5..7;
    char alignMode  : 8..15;
    char delimLeft  : 16..23;
    char delimRight : 24..31;
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
    { "matrix",      MathEnvironment.MATRIX,      { .colGap = 2, .alignMode = 'C' } },
    { "pmatrix",     MathEnvironment.PMATRIX,     { .colGap = 2, .alignMode = 'C', .delimLeft = '(', .delimRight = ')' } },
    { "bmatrix",     MathEnvironment.BMATRIX,     { .colGap = 2, .alignMode = 'C', .delimLeft = '[', .delimRight = ']' } },
    { "vmatrix",     MathEnvironment.VMATRIX,     { .colGap = 2, .alignMode = 'C', .delimLeft = '|', .delimRight = '|' } },
    { "Vmatrix",     MathEnvironment.VM_MATRIX,   { .colGap = 2, .alignMode = 'C', .delimLeft = 'V', .delimRight = 'V' } },
    { "Bmatrix",     MathEnvironment.B_MATRIX,    { .colGap = 2, .alignMode = 'C', .delimLeft = '{', .delimRight = '}' } },
    { "smallmatrix", MathEnvironment.SMALLMATRIX, { .colGap = 2, .alignMode = 'C' } },
    { "cases",       MathEnvironment.CASES,       { .colGap = 3, .alignMode = 'L', .delimLeft = '{' } },
    { "dcases",      MathEnvironment.DCASES,      { .colGap = 3, .alignMode = 'L', .delimLeft = '{' } },
    { "rcases",      MathEnvironment.RCASES,      { .colGap = 3, .alignMode = 'L', .delimRight = '}' } },
    { "align",       MathEnvironment.ALIGN,       { .colGap = 0, .alignMode = 'A' } },
    { "align*",      MathEnvironment.ALIGN,       { .colGap = 0, .alignMode = 'A' } },
    { "aligned",     MathEnvironment.ALIGNED,     { .colGap = 0, .alignMode = 'A' } },
    { "split",       MathEnvironment.SPLIT,       { .colGap = 0, .alignMode = 'A' } },
    { "flalign",     MathEnvironment.FLALIGN,     { .colGap = 0, .alignMode = 'A' } },
    { "flalign*",    MathEnvironment.FLALIGN,     { .colGap = 0, .alignMode = 'A' } },
    { "eqnarray",    MathEnvironment.EQNARRAY,    { .colGap = 0, .alignMode = 'A' } },
    { "gather",      MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } },
    { "gather*",     MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } },
    { "gathered",    MathEnvironment.GATHERED,    { .colGap = 0, .alignMode = 'C' } },
    { "array",       MathEnvironment.ARRAY,       { .argument, .colGap = 2, .alignMode = 'C' } },
    { "alignat",     MathEnvironment.ALIGN,       { .argument, .colGap = 0, .alignMode = 'A' } },
    { "alignat*",    MathEnvironment.ALIGN,       { .argument, .colGap = 0, .alignMode = 'A' } },
    { "alignedat",   MathEnvironment.ALIGNED,     { .argument, .colGap = 0, .alignMode = 'A' } },
    { "multline",    MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } },
    { "multline*",   MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } },
    { "equation",    MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } },
    { "equation*",   MathEnvironment.GATHER,      { .colGap = 0, .alignMode = 'C' } }
};

fn bool environment(String name, MathEnvironment* outEnv, MathEnvFlags* outFlags = null)
{
    for (usz i = 0; i < ENVIRONMENTS.len; i++)
    {
        if (name == ENVIRONMENTS[i].name)
        {
            *outEnv = ENVIRONMENTS[i].env;
            if (outFlags != null)
            {
                *outFlags = ENVIRONMENTS[i].flags;
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
    CHECK,
    BREVE,
    RING,
    ARROWS,
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
    { "widehat",   MathAccent.HAT,       "̂", false, false },
    { "widetilde", MathAccent.TILDE,     "̃", false, false },
    { "check",     MathAccent.CHECK,     "̌", false, false },
    { "breve",     MathAccent.BREVE,     "̆", false, false },
    { "mathring",  MathAccent.RING,      "̊", false, false },
    { "overleftrightarrow", MathAccent.ARROWS, "⃡", false, false },
    { "overline",  MathAccent.OVERLINE,  "̄", true,  false },
    { "underline", MathAccent.UNDERLINE, "\u0332", false, true }
};

fn bool accent(String name, MathAccent* outAccent, String* outCombining = null, bool* outOverline = null, bool* outUnderline = null)
{
    for (usz i = 0; i < ACCENTS.len; i++)
    {
        if (name == ACCENTS[i].name)
        {
            *outAccent = ACCENTS[i].accent;
            if (outCombining != null) *outCombining = ACCENTS[i].combining;
            if (outOverline != null) *outOverline = ACCENTS[i].overline;
            if (outUnderline != null) *outUnderline = ACCENTS[i].underline;
            return true;
        }
    }
    return false;
}


struct SymbolEntry {
    String name;
    String glyph;
    MathAtomKind kind;
}

const SymbolEntry[] SYMBOLS = {
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

    { "N", "ℕ", MathAtomKind.ORD },
    { "Z", "ℤ", MathAtomKind.ORD },
    { "Q", "ℚ", MathAtomKind.ORD },
    { "R", "ℝ", MathAtomKind.ORD },
    { "C", "ℂ", MathAtomKind.ORD },
    { "H", "ℍ", MathAtomKind.ORD },
    { "O", "", MathAtomKind.ORD },

    { "aleph", "ℵ", MathAtomKind.ORD },
    { "beth", "ℶ", MathAtomKind.ORD },
    { "gimel", "ℷ", MathAtomKind.ORD },
    { "daleth", "ℸ", MathAtomKind.ORD },

    { "int", "∫", MathAtomKind.ORD },
    { "iint", "∬", MathAtomKind.ORD },
    { "iiint", "∭", MathAtomKind.ORD },
    { "oint", "∮", MathAtomKind.ORD },
    { "sum", "∑", MathAtomKind.ORD },
    { "prod", "∏", MathAtomKind.ORD },
    { "coprod", "∐", MathAtomKind.ORD },
    { "sqrt", "√", MathAtomKind.ORD },
    { "partial", "∂", MathAtomKind.ORD },
    { "nabla", "∇", MathAtomKind.ORD },
    { "infty", "∞", MathAtomKind.ORD },
    { "prime", "′", MathAtomKind.ORD },
    { "dprime", "″", MathAtomKind.ORD },
    { "trprime", "‴", MathAtomKind.ORD },
    { "qprime", "⁗", MathAtomKind.ORD },

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

    { "forall", "∀", MathAtomKind.ORD },
    { "exists", "∃", MathAtomKind.ORD },
    { "nexists", "∄", MathAtomKind.ORD },
    { "neg", "¬", MathAtomKind.ORD },
    { "lnot", "¬", MathAtomKind.ORD },
    { "top", "⊤", MathAtomKind.ORD },
    { "bot", "⊥", MathAtomKind.ORD },
    { "emptyset", "∅", MathAtomKind.ORD },
    { "varnothing", "∅", MathAtomKind.ORD },

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

    { "langle", "⟨", MathAtomKind.OPEN },
    { "rangle", "⟩", MathAtomKind.CLOSE },
    { "lfloor", "⌊", MathAtomKind.OPEN },
    { "rfloor", "⌋", MathAtomKind.CLOSE },
    { "lceil", "⌈", MathAtomKind.OPEN },
    { "rceil", "⌉", MathAtomKind.CLOSE },
    { "backslash", "\\", MathAtomKind.ORD },
    { "vert", "|", MathAtomKind.ORD },
    { "Vert", "‖", MathAtomKind.ORD },

    { "dots", "…", MathAtomKind.PUNCT },
    { "cdots", "⋯", MathAtomKind.PUNCT },
    { "ldots", "…", MathAtomKind.PUNCT },
    { "vdots", "⋮", MathAtomKind.PUNCT },
    { "ddots", "⋱", MathAtomKind.PUNCT },
    { "iddots", "⋰", MathAtomKind.PUNCT },
    { "dotsc", "…", MathAtomKind.PUNCT },
    { "dotsb", "⋯", MathAtomKind.PUNCT },
    { "colon", ":", MathAtomKind.PUNCT },
    { "cdotp", "·", MathAtomKind.PUNCT },

    { "lvert", "|", MathAtomKind.OPEN },
    { "rvert", "|", MathAtomKind.CLOSE },
    { "lVert", "‖", MathAtomKind.OPEN },
    { "rVert", "‖", MathAtomKind.CLOSE },
    { "lbrace", "{", MathAtomKind.OPEN },
    { "rbrace", "}", MathAtomKind.CLOSE },
    { "lbrack", "[", MathAtomKind.OPEN },
    { "rbrack", "]", MathAtomKind.CLOSE },

    { "therefore", "∴", MathAtomKind.REL },
    { "because", "∵", MathAtomKind.REL },
    { "gets", "←", MathAtomKind.REL },
    { "impliedby", "⟸", MathAtomKind.REL },
    { "longmapsto", "⟼", MathAtomKind.REL },
    { "hookleftarrow", "↩", MathAtomKind.REL },
    { "hookrightarrow", "↪", MathAtomKind.REL },
    { "leadsto", "⇝", MathAtomKind.REL },
    { "nmid", "∤", MathAtomKind.REL },
    { "approxeq", "≊", MathAtomKind.REL },
    { "lesssim", "≲", MathAtomKind.REL },
    { "gtrsim", "≳", MathAtomKind.REL },
    { "nless", "≮", MathAtomKind.REL },
    { "ngtr", "≯", MathAtomKind.REL },
    { "coloneqq", "≔", MathAtomKind.REL },
    { "eqqcolon", "≕", MathAtomKind.REL },
    { "trianglelefteq", "⊴", MathAtomKind.REL },
    { "trianglerighteq", "⊵", MathAtomKind.REL },
    { "varpropto", "∝", MathAtomKind.REL },
    { "between", "≬", MathAtomKind.REL },
    { "pitchfork", "⋔", MathAtomKind.REL },

    { "lhd", "⊲", MathAtomKind.BIN },
    { "rhd", "⊳", MathAtomKind.BIN },
    { "unlhd", "⊴", MathAtomKind.BIN },
    { "unrhd", "⊵", MathAtomKind.BIN },
    { "bigtriangleup", "△", MathAtomKind.BIN },
    { "bigtriangledown", "▽", MathAtomKind.BIN },
    { "boxplus", "⊞", MathAtomKind.BIN },
    { "boxminus", "⊟", MathAtomKind.BIN },
    { "boxtimes", "⊠", MathAtomKind.BIN },
    { "boxdot", "⊡", MathAtomKind.BIN },
    { "ltimes", "⋉", MathAtomKind.BIN },
    { "rtimes", "⋊", MathAtomKind.BIN },
    { "curlyvee", "⋎", MathAtomKind.BIN },
    { "curlywedge", "⋏", MathAtomKind.BIN },
    { "intercal", "⊺", MathAtomKind.BIN },
    { "barwedge", "⊼", MathAtomKind.BIN },
    { "veebar", "⊻", MathAtomKind.BIN },
    { "dotplus", "∔", MathAtomKind.BIN },
    { "divideontimes", "⋇", MathAtomKind.BIN },
    { "centerdot", "·", MathAtomKind.BIN },
    { "circledast", "⊛", MathAtomKind.BIN },
    { "circledcirc", "⊚", MathAtomKind.BIN },

    { "imath", "ı", MathAtomKind.ORD },
    { "jmath", "ȷ", MathAtomKind.ORD },
    { "backprime", "‵", MathAtomKind.ORD },
    { "surd", "√", MathAtomKind.ORD },
    { "blacksquare", "■", MathAtomKind.ORD },
    { "checkmark", "✓", MathAtomKind.ORD },
    { "degree", "°", MathAtomKind.ORD },
    { "circledR", "®", MathAtomKind.ORD },
    { "copyright", "©", MathAtomKind.ORD },
    { "pounds", "£", MathAtomKind.ORD },
    { "yen", "¥", MathAtomKind.ORD },
    { "euro", "€", MathAtomKind.ORD },
    { "dag", "†", MathAtomKind.ORD },
    { "ddag", "‡", MathAtomKind.ORD },
    { "S", "§", MathAtomKind.ORD },
    { "P", "¶", MathAtomKind.ORD },
    { "blacktriangle", "▲", MathAtomKind.ORD },
    { "vartriangle", "△", MathAtomKind.ORD },
    { "complement", "∁", MathAtomKind.ORD },
    { "Finv", "Ⅎ", MathAtomKind.ORD },
    { "Game", "⅁", MathAtomKind.ORD },
    { "lozenge", "◊", MathAtomKind.ORD },
    { "blacklozenge", "⧫", MathAtomKind.ORD },
    { "bigstar", "★", MathAtomKind.ORD }
};

struct Skip
{
    String name;
    bool argument;
}

const Skip[] SKIPS = {
    { "big", false }, { "Big", false }, { "bigg", false }, { "Bigg", false },
    { "bigl", false }, { "bigr", false }, { "Bigl", false }, { "Bigr", false },
    { "biggl", false }, { "biggr", false }, { "Biggl", false }, { "Biggr", false },
    { "middle", false }, { "limits", false }, { "nolimits", false }, { "nonumber", false }, { "notag", false },
    { "displaystyle", false }, { "textstyle", false }, { "scriptstyle", false }, { "scriptscriptstyle", false },
    { "hline", false }, { "label", true }, { "vphantom", true },
};

fn bool skip(String name, bool* argument)
{
    foreach (k : SKIPS)
    {
        if (k.name != name) continue;
        *argument = k.argument;
        return true;
    }
    return false;
}

const SymbolEntry[] NEGATIONS = {
    { "=", "≠", MathAtomKind.REL }, { "<", "≮", MathAtomKind.REL }, { ">", "≯", MathAtomKind.REL },
    { "in", "∉", MathAtomKind.REL }, { "ni", "∌", MathAtomKind.REL }, { "subset", "⊄", MathAtomKind.REL },
    { "supset", "⊅", MathAtomKind.REL }, { "subseteq", "⊈", MathAtomKind.REL }, { "supseteq", "⊉", MathAtomKind.REL },
    { "equiv", "≢", MathAtomKind.REL }, { "sim", "≁", MathAtomKind.REL }, { "simeq", "≄", MathAtomKind.REL },
    { "approx", "≉", MathAtomKind.REL }, { "cong", "≇", MathAtomKind.REL }, { "le", "≰", MathAtomKind.REL },
    { "leq", "≰", MathAtomKind.REL }, { "ge", "≱", MathAtomKind.REL }, { "geq", "≱", MathAtomKind.REL },
    { "mid", "∤", MathAtomKind.REL }, { "parallel", "∦", MathAtomKind.REL }, { "exists", "∄", MathAtomKind.ORD },
};

fn String negate(String key)
{
    foreach (n : NEGATIONS) if (n.name == key) return n.glyph;
    return "";
}

fn bool symbol(String name, String* outGlyph, MathAtomKind* outKind = null)
{
    for (usz i = 0; i < SYMBOLS.len; i++)
    {
        if (name == SYMBOLS[i].name)
        {
            *outGlyph = SYMBOLS[i].glyph;
            if (outKind != null) *outKind = SYMBOLS[i].kind;
            return true;
        }
    }
    return false;
}
