module math;

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

fn bool lookup_command(String name, MathCommand* out_cmd)
{
    if (name == "tag") { *out_cmd = MathCommand.TAG; return true; }
    if (name == "xrightarrow") { *out_cmd = MathCommand.XRIGHTARROW; return true; }
    if (name == "xleftarrow") { *out_cmd = MathCommand.XLEFTARROW; return true; }
    if (name == "xleftrightarrow") { *out_cmd = MathCommand.XLEFTRIGHTARROW; return true; }
    if (name == "underline") { *out_cmd = MathCommand.UNDERLINE; return true; }
    if (name == "overrightarrow") { *out_cmd = MathCommand.OVERRIGHTARROW; return true; }
    if (name == "overleftarrow") { *out_cmd = MathCommand.OVERLEFTARROW; return true; }
    if (name == "cancel") { *out_cmd = MathCommand.CANCEL; return true; }
    if (name == "bcancel") { *out_cmd = MathCommand.BCANCEL; return true; }
    if (name == "xcancel") { *out_cmd = MathCommand.XCANCEL; return true; }
    if (name == "color") { *out_cmd = MathCommand.COLOR; return true; }
    if (name == "textcolor") { *out_cmd = MathCommand.TEXTCOLOR; return true; }
    if (name == "mathcolor") { *out_cmd = MathCommand.MATHCOLOR; return true; }
    if (name == "frac") { *out_cmd = MathCommand.FRAC; return true; }
    if (name == "dfrac") { *out_cmd = MathCommand.DFRAC; return true; }
    if (name == "tfrac") { *out_cmd = MathCommand.TFRAC; return true; }
    if (name == "cfrac") { *out_cmd = MathCommand.CFRAC; return true; }
    if (name == "boxed") { *out_cmd = MathCommand.BOXED; return true; }
    if (name == "binom") { *out_cmd = MathCommand.BINOM; return true; }
    if (name == "dbinom") { *out_cmd = MathCommand.DBINOM; return true; }
    if (name == "tbinom") { *out_cmd = MathCommand.TBINOM; return true; }
    if (name == "overset") { *out_cmd = MathCommand.OVERSET; return true; }
    if (name == "stackrel") { *out_cmd = MathCommand.STACKREL; return true; }
    if (name == "underset") { *out_cmd = MathCommand.UNDERSET; return true; }
    if (name == "overbrace") { *out_cmd = MathCommand.OVERBRACE; return true; }
    if (name == "underbrace") { *out_cmd = MathCommand.UNDERBRACE; return true; }
    if (name == "substack") { *out_cmd = MathCommand.SUBSTACK; return true; }
    if (name == "sqrt") { *out_cmd = MathCommand.SQRT; return true; }
    if (name == "sum") { *out_cmd = MathCommand.SUM; return true; }
    if (name == "prod") { *out_cmd = MathCommand.PROD; return true; }
    if (name == "coprod") { *out_cmd = MathCommand.COPROD; return true; }
    if (name == "bigcup") { *out_cmd = MathCommand.BIG_UNION; return true; }
    if (name == "bigcap") { *out_cmd = MathCommand.BIG_INTERSECTION; return true; }
    if (name == "bigoplus") { *out_cmd = MathCommand.BIG_PLUS; return true; }
    if (name == "bigotimes") { *out_cmd = MathCommand.BIG_TIMES; return true; }
    if (name == "bigodot") { *out_cmd = MathCommand.BIG_DOT; return true; }
    if (name == "bigsqcup") { *out_cmd = MathCommand.BIG_SQ_CUP; return true; }
    if (name == "bigvee") { *out_cmd = MathCommand.BIG_VEE; return true; }
    if (name == "bigwedge") { *out_cmd = MathCommand.BIG_WEDGE; return true; }
    if (name == "int") { *out_cmd = MathCommand.INT; return true; }
    if (name == "iint") { *out_cmd = MathCommand.IINT; return true; }
    if (name == "iiint") { *out_cmd = MathCommand.IIINT; return true; }
    if (name == "oint") { *out_cmd = MathCommand.OINT; return true; }
    if (name == "oiint") { *out_cmd = MathCommand.OIINT; return true; }
    if (name == "oiiint") { *out_cmd = MathCommand.OIIINT; return true; }
    if (name == "lim") { *out_cmd = MathCommand.LIM; return true; }
    if (name == "liminf") { *out_cmd = MathCommand.LIMINF; return true; }
    if (name == "limsup") { *out_cmd = MathCommand.LIMSUP; return true; }
    if (name == "max") { *out_cmd = MathCommand.MAX; return true; }
    if (name == "min") { *out_cmd = MathCommand.MIN; return true; }
    if (name == "sup") { *out_cmd = MathCommand.SUP; return true; }
    if (name == "inf") { *out_cmd = MathCommand.INF; return true; }
    if (name == "argmax") { *out_cmd = MathCommand.ARGMAX; return true; }
    if (name == "argmin") { *out_cmd = MathCommand.ARGMIN; return true; }
    if (name == "pmod") { *out_cmd = MathCommand.PMOD; return true; }
    if (name == "pod") { *out_cmd = MathCommand.POD; return true; }
    if (name == "bmod") { *out_cmd = MathCommand.BMOD; return true; }
    if (name == "left") { *out_cmd = MathCommand.LEFT; return true; }
    if (name == "begin") { *out_cmd = MathCommand.BEGIN; return true; }
    if (name == "text") { *out_cmd = MathCommand.TEXT; return true; }
    if (name == "quad") { *out_cmd = MathCommand.QUAD; return true; }
    if (name == "qquad") { *out_cmd = MathCommand.QQUAD; return true; }
    return false;
}
