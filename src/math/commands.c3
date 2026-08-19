module math;

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
    { "overbrace", MathCommand.OVERBRACE, { .opt_arg, .arity = 1 } },
    { "underbrace", MathCommand.UNDERBRACE, { .opt_arg, .arity = 1 } },
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
    { "left", MathCommand.LEFT, { .arity = 0 } },
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
