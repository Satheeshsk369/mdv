module math;

import std::core::mem;
import ast;
import strutils;

struct SymbolEntry {
    char* name;
    char* glyph;
}

const SymbolEntry[] SYMBOLS = {
    // ── Greek Lowercase ──────────────────────────────────────────────────────
    { "alpha", "α" },
    { "beta", "β" },
    { "gamma", "γ" },
    { "delta", "δ" },
    { "epsilon", "ϵ" },
    { "varepsilon", "ε" },
    { "zeta", "ζ" },
    { "eta", "η" },
    { "theta", "θ" },
    { "vartheta", "ϑ" },
    { "iota", "ι" },
    { "kappa", "κ" },
    { "varkappa", "ϰ" },
    { "lambda", "λ" },
    { "mu", "μ" },
    { "nu", "ν" },
    { "xi", "ξ" },
    { "omicron", "ο" },
    { "pi", "π" },
    { "varpi", "ϖ" },
    { "rho", "ρ" },
    { "varrho", "ϱ" },
    { "sigma", "σ" },
    { "varsigma", "ς" },
    { "tau", "τ" },
    { "upsilon", "υ" },
    { "phi", "ϕ" },
    { "varphi", "φ" },
    { "chi", "χ" },
    { "psi", "ψ" },
    { "omega", "ω" },

    // ── Greek Uppercase ──────────────────────────────────────────────────────
    { "Gamma", "Γ" },
    { "Delta", "Δ" },
    { "Theta", "Θ" },
    { "Lambda", "Λ" },
    { "Xi", "Ξ" },
    { "Pi", "Π" },
    { "Sigma", "Σ" },
    { "Upsilon", "Υ" },
    { "Phi", "Φ" },
    { "Psi", "Ψ" },
    { "Omega", "Ω" },

    // ── Operators & Arithmetic ───────────────────────────────────────────────
    { "pm", "±" },
    { "mp", "∓" },
    { "times", "×" },
    { "cdot", "⋅" },
    { "div", "÷" },
    { "ast", "*" },
    { "star", "⋆" },
    { "circ", "∘" },
    { "bullet", "•" },
    { "oplus", "⊕" },
    { "ominus", "⊖" },
    { "otimes", "⊗" },
    { "oslash", "⊘" },
    { "odot", "⊙" },
    { "circledcirc", "⊚" },
    { "circleddash", "⊝" },
    { "boxplus", "⊞" },
    { "boxminus", "⊟" },
    { "boxtimes", "⊠" },
    { "boxdot", "⊡" },
    { "dagger", "†" },
    { "ddagger", "‡" },
    { "amalg", "⨿" },
    { "wr", "≀" },

    // ── Relations & Comparisons ──────────────────────────────────────────────
    { "leq", "≤" },
    { "le", "≤" },
    { "geq", "≥" },
    { "ge", "≥" },
    { "neq", "≠" },
    { "ne", "≠" },
    { "approx", "≈" },
    { "equiv", "≡" },
    { "sim", "∼" },
    { "simeq", "≃" },
    { "cong", "≅" },
    { "asymp", "≍" },
    { "doteq", "≐" },
    { "propto", "∝" },
    { "ll", "≪" },
    { "gg", "≫" },
    { "prec", "≺" },
    { "succ", "≻" },
    { "preceq", "≼" },
    { "succeq", "≽" },
    { "subset", "⊂" },
    { "supset", "⊃" },
    { "subseteq", "⊆" },
    { "supseteq", "⊇" },
    { "sqsubset", "⊏" },
    { "sqsupset", "⊐" },
    { "sqsubseteq", "⊑" },
    { "sqsupseteq", "⊒" },
    { "in", "∈" },
    { "notin", "∉" },
    { "ni", "∋" },
    { "models", "⊨" },
    { "vdash", "⊢" },
    { "dashv", "⊣" },
    { "perp", "⊥" },
    { "mid", "∣" },
    { "parallel", "∥" },

    // ── Sets, Logic & Calculus ───────────────────────────────────────────────
    { "forall", "∀" },
    { "exists", "∃" },
    { "nexists", "∄" },
    { "neg", "¬" },
    { "land", "∧" },
    { "lor", "∨" },
    { "wedge", "∧" },
    { "vee", "∨" },
    { "top", "⊤" },
    { "bot", "⊥" },
    { "cap", "∩" },
    { "cup", "∪" },
    { "uplus", "⊎" },
    { "sqcap", "⊓" },
    { "sqcup", "⊔" },
    { "setminus", "∖" },
    { "emptyset", "∅" },
    { "varnothing", "∅" },
    { "int", "∫" },
    { "iint", "∬" },
    { "iiint", "∭" },
    { "oint", "∮" },
    { "sum", "∑" },
    { "prod", "∏" },
    { "coprod", "∐" },
    { "nabla", "∇" },
    { "partial", "∂" },
    { "infty", "∞" },
    { "hbar", "ℏ" },
    { "ell", "ℓ" },
    { "Re", "ℜ" },
    { "Im", "ℑ" },
    { "wp", "℘" },
    { "aleph", "ℵ" },
    { "beth", "ℶ" },
    { "angle", "∠" },
    { "measuredangle", "∡" },
    { "sphericalangle", "∢" },
    { "prime", "′" },
    { "backprime", "‵" },

    // ── Standard Functions ───────────────────────────────────────────────────
    { "lim", "lim" },
    { "sin", "sin" },
    { "cos", "cos" },
    { "tan", "tan" },
    { "cot", "cot" },
    { "sec", "sec" },
    { "csc", "csc" },
    { "arcsin", "arcsin" },
    { "arccos", "arccos" },
    { "arctan", "arctan" },
    { "sinh", "sinh" },
    { "cosh", "cosh" },
    { "tanh", "tanh" },
    { "coth", "coth" },
    { "ln", "ln" },
    { "log", "log" },
    { "exp", "exp" },
    { "det", "det" },
    { "dim", "dim" },
    { "gcd", "gcd" },
    { "hom", "hom" },
    { "ker", "ker" },
    { "deg", "deg" },
    { "arg", "arg" },
    { "max", "max" },
    { "min", "min" },
    { "sup", "sup" },
    { "inf", "inf" },

    // ── Arrows ───────────────────────────────────────────────────────────────
    { "to", "→" },
    { "rightarrow", "→" },
    { "leftarrow", "←" },
    { "uparrow", "↑" },
    { "downarrow", "↓" },
    { "leftrightarrow", "↔" },
    { "updownarrow", "↕" },
    { "Rightarrow", "⇒" },
    { "Leftarrow", "⇐" },
    { "Leftrightarrow", "⇔" },
    { "Uparrow", "⇑" },
    { "Downarrow", "⇓" },
    { "Updownarrow", "⇕" },
    { "implies", "⇒" },
    { "iff", "⇔" },
    { "mapsto", "↦" },
    { "hookrightarrow", "↪" },
    { "hookleftarrow", "↩" },
    { "nearrow", "↗" },
    { "searrow", "↘" },
    { "nwarrow", "↖" },
    { "swarrow", "↙" },
    { "rightharpoonup", "⇀" },
    { "rightharpoondown", "⇁" },
    { "leftharpoonup", "↼" },
    { "leftharpoondown", "↽" },
    { "rightleftharpoons", "⇌" },
    { "leftrightharpoons", "⇋" },

    // ── Ellipses ─────────────────────────────────────────────────────────────
    { "dots", "…" },
    { "ldots", "…" },
    { "cdots", "⋯" },
    { "ddots", "⋱" },
    { "vdots", "⋮" }
};

struct MathBuffer {
    char[] buf;
    usz len;
    usz cap;
}

fn void MathBuffer.init(MathBuffer* b, usz initial_cap)
{
    b.buf = mem::alloc_array(char, (sz)initial_cap);
    b.len = 0;
    b.cap = initial_cap;
}

fn void MathBuffer.append_char(MathBuffer* b, char c)
{
    if (b.len < b.cap - 1)
    {
        b.buf[b.len++] = c;
    }
}

fn void MathBuffer.append_str(MathBuffer* b, char* s)
{
    if (s == null) return;
    usz sl = 0;
    while (s[sl] != 0 && b.len < b.cap - 1)
    {
        b.buf[b.len++] = s[sl++];
    }
}

fn void MathBuffer.append_slice(MathBuffer* b, String s)
{
    for (usz i = 0; i < (usz)s.len && b.len < b.cap - 1; i++)
    {
        b.buf[b.len++] = s[i];
    }
}

fn void MathBuffer.free(MathBuffer* b)
{
    if (b.buf.ptr != null)
    {
        mem::free(b.buf);
        b.buf = {};
        b.len = 0;
        b.cap = 0;
    }
}

fn char* get_superscript_char(char c)
{
    switch (c)
    {
        case '0': return "⁰";
        case '1': return "¹";
        case '2': return "²";
        case '3': return "³";
        case '4': return "⁴";
        case '5': return "⁵";
        case '6': return "⁶";
        case '7': return "⁷";
        case '8': return "⁸";
        case '9': return "⁹";
        case '+': return "⁺";
        case '-': return "⁻";
        case '=': return "⁼";
        case '(': return "⁽";
        case ')': return "⁾";
        case 'a': return "ᵃ";
        case 'b': return "ᵇ";
        case 'c': return "ᶜ";
        case 'd': return "ᵈ";
        case 'e': return "ᵉ";
        case 'f': return "ᶠ";
        case 'g': return "ᵍ";
        case 'h': return "ʰ";
        case 'i': return "ⁱ";
        case 'j': return "ʲ";
        case 'k': return "ᵏ";
        case 'l': return "ˡ";
        case 'm': return "ᵐ";
        case 'n': return "ⁿ";
        case 'o': return "ᵒ";
        case 'p': return "ᵖ";
        case 'r': return "ʳ";
        case 's': return "ˢ";
        case 't': return "ᵗ";
        case 'u': return "ᵘ";
        case 'v': return "ᵛ";
        case 'w': return "ʷ";
        case 'x': return "ˣ";
        case 'y': return "ʸ";
        case 'z': return "ᶻ";
        default: return null;
    }
}

fn char* get_subscript_char(char c)
{
    switch (c)
    {
        case '0': return "₀";
        case '1': return "₁";
        case '2': return "₂";
        case '3': return "₃";
        case '4': return "₄";
        case '5': return "₅";
        case '6': return "₆";
        case '7': return "₇";
        case '8': return "₈";
        case '9': return "₉";
        case '+': return "₊";
        case '-': return "₋";
        case '=': return "₌";
        case '(': return "₍";
        case ')': return "₎";
        case 'a': return "ₐ";
        case 'e': return "ₑ";
        case 'h': return "ₕ";
        case 'i': return "ᵢ";
        case 'j': return "ⱼ";
        case 'k': return "ₖ";
        case 'l': return "ₗ";
        case 'm': return "ₘ";
        case 'n': return "ₙ";
        case 'o': return "ₒ";
        case 'p': return "ₚ";
        case 'r': return "ᵣ";
        case 's': return "ₛ";
        case 't': return "ₜ";
        case 'u': return "ᵤ";
        case 'v': return "ᵥ";
        case 'x': return "ₓ";
        default: return null;
    }
}

fn char* get_mathbb_char(char c)
{
    switch (c)
    {
        case 'R': return "ℝ";
        case 'C': return "ℂ";
        case 'N': return "ℕ";
        case 'Z': return "ℤ";
        case 'Q': return "ℚ";
        case 'P': return "ℙ";
        case 'E': return "𝔼";
        case 'H': return "ℍ";
        case 'F': return "𝔽";
        case 'K': return "𝕂";
        case 'A': return "𝔸";
        case 'B': return "𝔹";
        case 'D': return "𝔻";
        case 'G': return "𝔾";
        case 'I': return "𝕀";
        case 'J': return "𝕁";
        case 'L': return "𝕃";
        case 'M': return "𝕄";
        case 'O': return "𝕆";
        case 'S': return "𝕊";
        case 'T': return "𝕋";
        case 'U': return "𝕌";
        case 'V': return "𝕍";
        case 'W': return "𝕎";
        case 'X': return "𝕏";
        case 'Y': return "𝕐";
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

fn String transform_math(ast::Arena* arena, String input)
{
    if (input.len == 0) return "";

    usz max_out = (usz)input.len * 4 + 256;
    MathBuffer mb;
    mb.init(max_out);
    defer mb.free();

    usz i = 0;

    while (i < (usz)input.len)
    {
        char c = input[i];

        // ── 1. LaTeX Math Backslash Commands & Spaces ────────────────────────
        if (c == '\\')
        {
            // Mathematical spacing & escaped symbols
            if (i + 1 < (usz)input.len)
            {
                char next_c = input[i + 1];
                if (next_c == '{' || next_c == '}')
                {
                    mb.append_char(next_c);
                    i += 2;
                    continue;
                }
                if (next_c == ',') // Thin space (U+2009)
                {
                    mb.append_str(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ':') // Medium math space (U+205F)
                {
                    mb.append_str(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ';') // Thick space (U+2005)
                {
                    mb.append_str(" ");
                    i += 2;
                    continue;
                }
                if (next_c == '!') // Negative thin space
                {
                    i += 2;
                    continue;
                }
                if (next_c == ' ') // Escaped space
                {
                    mb.append_char(' ');
                    i += 2;
                    continue;
                }
                if (next_c == '%')
                {
                    mb.append_char('%');
                    i += 2;
                    continue;
                }
                if (next_c == '$')
                {
                    mb.append_char('$');
                    i += 2;
                    continue;
                }
            }

            // Command name scanner
            usz cmd_start = i + 1;
            usz cmd_end = cmd_start;
            while (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z')))
            {
                cmd_end++;
            }

            String cmd = input[cmd_start:cmd_end];

            // ── Quad Spacing: \quad, \qquad ──────────────────────────────────
            if (strutils::string_eq(cmd, "quad"))
            {
                mb.append_str(" ");
                i = cmd_end;
                continue;
            }
            if (strutils::string_eq(cmd, "qquad"))
            {
                mb.append_str("  ");
                i = cmd_end;
                continue;
            }

            // ── Text / Style Wrappers: \text{...}, \mathrm{...}, etc. ─────────
            if (strutils::string_eq(cmd, "text") || strutils::string_eq(cmd, "mathbf") || strutils::string_eq(cmd, "mathrm") || strutils::string_eq(cmd, "mathit") || strutils::string_eq(cmd, "mathsf") || strutils::string_eq(cmd, "operatorname") || strutils::string_eq(cmd, "hspace") || strutils::string_eq(cmd, "vspace"))
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        if (!strutils::string_eq(cmd, "hspace") && !strutils::string_eq(cmd, "vspace"))
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                }
                continue;
            }

            // ── Blackboard Bold: \mathbb{R} ───────────────────────────────────
            if (strutils::string_eq(cmd, "mathbb"))
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        char* bb = get_mathbb_char(input[i]);
                        if (bb != null)
                        {
                            mb.append_str(bb);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                    continue;
                }
            }

            // ── Calligraphic / Script: \mathcal{L} ─────────────────────────────
            if (strutils::string_eq(cmd, "mathcal") || strutils::string_eq(cmd, "mathscr"))
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        char* cal = get_mathcal_char(input[i]);
                        if (cal != null)
                        {
                            mb.append_str(cal);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                    continue;
                }
            }

            // ── Accents: \vec, \hat, \bar, \overline, \dot, \ddot, \tilde ────
            if (strutils::string_eq(cmd, "vec") || strutils::string_eq(cmd, "hat") || strutils::string_eq(cmd, "bar") || strutils::string_eq(cmd, "overline") || strutils::string_eq(cmd, "dot") || strutils::string_eq(cmd, "ddot") || strutils::string_eq(cmd, "tilde") || strutils::string_eq(cmd, "acute") || strutils::string_eq(cmd, "grave"))
            {
                char* combining = "⃗";
                if (strutils::string_eq(cmd, "hat"))
                {
                    combining = "̂";
                }
                else if (strutils::string_eq(cmd, "bar") || strutils::string_eq(cmd, "overline"))
                {
                    combining = "̄";
                }
                else if (strutils::string_eq(cmd, "dot"))
                {
                    combining = "̇";
                }
                else if (strutils::string_eq(cmd, "ddot"))
                {
                    combining = "̈";
                }
                else if (strutils::string_eq(cmd, "tilde"))
                {
                    combining = "̃";
                }
                else if (strutils::string_eq(cmd, "acute"))
                {
                    combining = "́";
                }
                else if (strutils::string_eq(cmd, "grave"))
                {
                    combining = "̀";
                }

                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz arg_start = i;
                    while (i < (usz)input.len && input[i] != '}') i++;
                    String arg_content = input[arg_start:i];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_arg = transform_math(arena, arg_content);
                    mb.append_slice(t_arg);
                    mb.append_str(combining);
                }
                else if (i < (usz)input.len)
                {
                    mb.append_char(input[i++]);
                    mb.append_str(combining);
                }
                continue;
            }

            // ── Fractions: \frac{num}{den} ───────────────────────────────────
            if (strutils::string_eq(cmd, "frac") || strutils::string_eq(cmd, "dfrac") || strutils::string_eq(cmd, "tfrac"))
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz n_start = i;
                    int depth = 1;
                    while (i < (usz)input.len && depth > 0)
                    {
                        if (input[i] == '{')
                        {
                            depth++;
                        }
                        else if (input[i] == '}')
                        {
                            depth--;
                        }
                        if (depth > 0) i++;
                    }
                    String num = input[n_start:i];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    while (i < (usz)input.len && input[i] == ' ') i++;
                    if (i < (usz)input.len && input[i] == '{')
                    {
                        i++;
                        usz d_start = i;
                        depth = 1;
                        while (i < (usz)input.len && depth > 0)
                        {
                            if (input[i] == '{')
                            {
                                depth++;
                            }
                            else if (input[i] == '}')
                            {
                                depth--;
                            }
                            if (depth > 0) i++;
                        }
                        String den = input[d_start:i];
                        if (i < (usz)input.len && input[i] == '}') i++;

                        String t_num = transform_math(arena, num);
                        String t_den = transform_math(arena, den);

                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "2")) { mb.append_str("½"); continue; }
                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "3")) { mb.append_str("⅓"); continue; }
                        if (strutils::string_eq(t_num, "2") && strutils::string_eq(t_den, "3")) { mb.append_str("⅔"); continue; }
                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "4")) { mb.append_str("¼"); continue; }
                        if (strutils::string_eq(t_num, "3") && strutils::string_eq(t_den, "4")) { mb.append_str("¾"); continue; }
                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "5")) { mb.append_str("⅕"); continue; }
                        if (strutils::string_eq(t_num, "2") && strutils::string_eq(t_den, "5")) { mb.append_str("⅖"); continue; }
                        if (strutils::string_eq(t_num, "3") && strutils::string_eq(t_den, "5")) { mb.append_str("⅗"); continue; }
                        if (strutils::string_eq(t_num, "4") && strutils::string_eq(t_den, "5")) { mb.append_str("⅘"); continue; }
                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "6")) { mb.append_str("⅙"); continue; }
                        if (strutils::string_eq(t_num, "5") && strutils::string_eq(t_den, "6")) { mb.append_str("⅚"); continue; }
                        if (strutils::string_eq(t_num, "1") && strutils::string_eq(t_den, "8")) { mb.append_str("⅛"); continue; }
                        if (strutils::string_eq(t_num, "3") && strutils::string_eq(t_den, "8")) { mb.append_str("⅜"); continue; }
                        if (strutils::string_eq(t_num, "5") && strutils::string_eq(t_den, "8")) { mb.append_str("⅝"); continue; }
                        if (strutils::string_eq(t_num, "7") && strutils::string_eq(t_den, "8")) { mb.append_str("⅞"); continue; }

                        bool complex_num = (t_num.len > 1 && (t_num[0] != '(' || t_num[t_num.len - 1] != ')'));
                        bool complex_den = (t_den.len > 1 && (t_den[0] != '(' || t_den[t_den.len - 1] != ')'));

                        if (complex_num) mb.append_char('(');
                        mb.append_slice(t_num);
                        if (complex_num) mb.append_char(')');

                        mb.append_str(" / ");

                        if (complex_den) mb.append_char('(');
                        mb.append_slice(t_den);
                        if (complex_den) mb.append_char(')');
                        continue;
                    }
                }
            }

            // ── Roots: \sqrt[n]{...} or \sqrt{...} ───────────────────────────
            if (strutils::string_eq(cmd, "sqrt"))
            {
                i = cmd_end;
                while (i < (usz)input.len && input[i] == ' ') i++;

                // Optional degree: [n]
                if (i < (usz)input.len && input[i] == '[')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != ']')
                    {
                        char* deg = get_superscript_char(input[i]);
                        if (deg != null)
                        {
                            mb.append_str(deg);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == ']') i++;
                }

                mb.append_str("√");

                while (i < (usz)input.len && input[i] == ' ') i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    usz rad_start = i;
                    int depth = 1;
                    while (i < (usz)input.len && depth > 0)
                    {
                        if (input[i] == '{')
                        {
                            depth++;
                        }
                        else if (input[i] == '}')
                        {
                            depth--;
                        }
                        if (depth > 0) i++;
                    }
                    String rad = input[rad_start:i];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_rad = transform_math(arena, rad);
                    if (t_rad.len > 1 && (t_rad[0] != '(' || t_rad[t_rad.len - 1] != ')'))
                    {
                        mb.append_char('(');
                        mb.append_slice(t_rad);
                        mb.append_char(')');
                    }
                    else
                    {
                        mb.append_slice(t_rad);
                    }
                }
                continue;
            }

            // ── Symbol Table Lookup ──────────────────────────────────────────
            bool found_sym = false;
            for (usz s = 0; s < SYMBOLS.len; s++)
            {
                if (strutils::str_eq((char*)cmd.ptr, SYMBOLS[s].name) && (usz)strutils::str_len(SYMBOLS[s].name) == cmd.len)
                {
                    mb.append_str(SYMBOLS[s].glyph);
                    found_sym = true;
                    i = cmd_end;
                    break;
                }
            }
            if (found_sym) continue;

            // If unknown command, emit clean command name
            mb.append_slice(cmd);
            i = cmd_end;
            continue;
        }

        // ── 2. Superscripts: ^2, ^{n+1}, etc. ────────────────────────────────
        if (c == '^')
        {
            i++;
            if (i < (usz)input.len && input[i] == '{')
            {
                i++;
                while (i < (usz)input.len && input[i] != '}')
                {
                    if (input[i] == '\\')
                    {
                        // Parse command inside superscript
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start:s_end];
                        if (strutils::string_eq(scmd, "alpha"))
                        {
                            mb.append_str("ᵅ");
                        }
                        else if (strutils::string_eq(scmd, "beta"))
                        {
                            mb.append_str("ᵝ");
                        }
                        else if (strutils::string_eq(scmd, "gamma"))
                        {
                            mb.append_str("ᵞ");
                        }
                        else if (strutils::string_eq(scmd, "delta"))
                        {
                            mb.append_str("ᵟ");
                        }
                        else if (strutils::string_eq(scmd, "epsilon"))
                        {
                            mb.append_str("ᵋ");
                        }
                        else if (strutils::string_eq(scmd, "theta"))
                        {
                            mb.append_str("ᶿ");
                        }
                        else if (strutils::string_eq(scmd, "phi"))
                        {
                            mb.append_str("ᵠ");
                        }
                        else if (strutils::string_eq(scmd, "chi"))
                        {
                            mb.append_str("ᵡ");
                        }
                        else if (strutils::string_eq(scmd, "infty"))
                        {
                            mb.append_str("᪲");
                        }
                        else
                        {
                            mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sup = get_superscript_char(input[i]);
                    if (sup != null)
                    {
                        mb.append_str(sup);
                    }
                    else
                    {
                        mb.append_char(input[i]);
                    }
                    i++;
                }
                if (i < (usz)input.len && input[i] == '}') i++;
                continue;
            }
            else if (i < (usz)input.len)
            {
                char* sup = get_superscript_char(input[i]);
                if (sup != null)
                {
                    mb.append_str(sup);
                    i++;
                    continue;
                }
                else
                {
                    mb.append_char('^');
                    mb.append_char(input[i++]);
                    continue;
                }
            }
            mb.append_char('^');
            continue;
        }

        // ── 3. Subscripts: _i, _{10}, etc. ───────────────────────────────────
        if (c == '_')
        {
            i++;
            if (i < (usz)input.len && input[i] == '{')
            {
                i++;
                while (i < (usz)input.len && input[i] != '}')
                {
                    if (input[i] == '\\')
                    {
                        // Parse command inside subscript
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start:s_end];
                        if (strutils::string_eq(scmd, "beta"))
                        {
                            mb.append_str("ᵦ");
                        }
                        else if (strutils::string_eq(scmd, "gamma"))
                        {
                            mb.append_str("ᵧ");
                        }
                        else if (strutils::string_eq(scmd, "rho"))
                        {
                            mb.append_str("ᵨ");
                        }
                        else if (strutils::string_eq(scmd, "phi"))
                        {
                            mb.append_str("ᵩ");
                        }
                        else if (strutils::string_eq(scmd, "chi"))
                        {
                            mb.append_str("ᵪ");
                        }
                        else
                        {
                            mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sub = get_subscript_char(input[i]);
                    if (sub != null)
                    {
                        mb.append_str(sub);
                    }
                    else
                    {
                        mb.append_char(input[i]);
                    }
                    i++;
                }
                if (i < (usz)input.len && input[i] == '}') i++;
                continue;
            }
            else if (i < (usz)input.len)
            {
                char* sub = get_subscript_char(input[i]);
                if (sub != null)
                {
                    mb.append_str(sub);
                    i++;
                    continue;
                }
                else
                {
                    mb.append_char('_');
                    mb.append_char(input[i++]);
                    continue;
                }
            }
            mb.append_char('_');
            continue;
        }

        // ── Normal Characters ────────────────────────────────────────────────
        mb.append_char(c);
        i++;
    }

    String result_slice = (String)mb.buf[:mb.len];
    return arena.dup_string(result_slice);
}
