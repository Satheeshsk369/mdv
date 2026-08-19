module math;

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

fn bool lookup_environment(String name, MathEnvironment* out_env)
{
    if (name == "matrix") { *out_env = MathEnvironment.MATRIX; return true; }
    if (name == "pmatrix") { *out_env = MathEnvironment.PMATRIX; return true; }
    if (name == "bmatrix") { *out_env = MathEnvironment.BMATRIX; return true; }
    if (name == "vmatrix") { *out_env = MathEnvironment.VMATRIX; return true; }
    if (name == "Vmatrix") { *out_env = MathEnvironment.VM_MATRIX; return true; }
    if (name == "Bmatrix") { *out_env = MathEnvironment.B_MATRIX; return true; }
    if (name == "smallmatrix") { *out_env = MathEnvironment.SMALLMATRIX; return true; }
    if (name == "cases") { *out_env = MathEnvironment.CASES; return true; }
    if (name == "dcases") { *out_env = MathEnvironment.DCASES; return true; }
    if (name == "rcases") { *out_env = MathEnvironment.RCASES; return true; }
    if (name == "align" || name == "align*") { *out_env = MathEnvironment.ALIGN; return true; }
    if (name == "aligned") { *out_env = MathEnvironment.ALIGNED; return true; }
    if (name == "split") { *out_env = MathEnvironment.SPLIT; return true; }
    if (name == "gather" || name == "gather*") { *out_env = MathEnvironment.GATHER; return true; }
    if (name == "gathered") { *out_env = MathEnvironment.GATHERED; return true; }
    if (name == "flalign" || name == "flalign*") { *out_env = MathEnvironment.FLALIGN; return true; }
    if (name == "eqnarray") { *out_env = MathEnvironment.EQNARRAY; return true; }
    if (name == "array") { *out_env = MathEnvironment.ARRAY; return true; }
    return false;
}
