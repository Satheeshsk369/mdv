module math;

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
