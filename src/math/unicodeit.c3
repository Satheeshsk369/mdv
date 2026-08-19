module math;

import std::core::mem;
import ast;
import strutils;
import buffer;

struct SymbolEntry {
    String name;
    String glyph;
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

    // ── Hebrew & Special Letters ─────────────────────────────────────────────
    { "aleph", "ℵ" },
    { "beth", "ℶ" },
    { "gimel", "ℷ" },
    { "daleth", "ℸ" },
    { "hbar", "ℏ" },
    { "ell", "ℓ" },
    { "wp", "℘" },
    { "Re", "ℜ" },
    { "Im", "ℑ" },
    { "partial", "∂" },
    { "nabla", "∇" },
    { "infty", "∞" },
    { "prime", "′" },
    { "backprime", "‵" },

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
    { "circledast", "⊛" },
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
    { "diff", "d" },

    // ── Relations & Comparisons ──────────────────────────────────────────────
    { "leq", "≤" },
    { "le", "≤" },
    { "geq", "≥" },
    { "ge", "≥" },
    { "neq", "≠" },
    { "ne", "≠" },
    { "approx", "≈" },
    { "approxeq", "≊" },
    { "equiv", "≡" },
    { "sim", "∼" },
    { "nsim", "≁" },
    { "simeq", "≃" },
    { "cong", "≅" },
    { "ncong", "≇" },
    { "asymp", "≍" },
    { "doteq", "≐" },
    { "propto", "∝" },
    { "ll", "≪" },
    { "gg", "≫" },
    { "prec", "≺" },
    { "succ", "≻" },
    { "preceq", "≼" },
    { "succeq", "≽" },
    { "nleq", "≰" },
    { "ngeq", "≱" },
    { "nless", "≮" },
    { "ngtr", "≯" },
    { "subset", "⊂" },
    { "supset", "⊃" },
    { "subseteq", "⊆" },
    { "supseteq", "⊇" },
    { "subsetneq", "⊊" },
    { "supsetneq", "⊋" },
    { "sqsubset", "⊏" },
    { "sqsupset", "⊐" },
    { "sqsubseteq", "⊑" },
    { "sqsupseteq", "⊒" },
    { "in", "∈" },
    { "notin", "∉" },
    { "ni", "∋" },
    { "owns", "∋" },
    { "models", "⊨" },
    { "vdash", "⊢" },
    { "dashv", "⊣" },
    { "perp", "⊥" },
    { "mid", "∣" },
    { "nmid", "∤" },
    { "parallel", "∥" },
    { "nparallel", "∦" },

    // ── Sets, Logic & Geometry ───────────────────────────────────────────────
    { "forall", "∀" },
    { "exists", "∃" },
    { "nexists", "∄" },
    { "neg", "¬" },
    { "lnot", "¬" },
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
    { "smallsetminus", "∖" },
    { "emptyset", "∅" },
    { "varnothing", "∅" },
    { "therefore", "∴" },
    { "because", "∵" },
    { "angle", "∠" },
    { "measuredangle", "∡" },
    { "sphericalangle", "∢" },

    // ── Big Operators ────────────────────────────────────────────────────────
    { "int", "∫" },
    { "iint", "∬" },
    { "iiint", "∭" },
    { "oint", "∮" },
    { "sum", "∑" },
    { "prod", "∏" },
    { "coprod", "∐" },
    { "bigcup", "⋃" },
    { "bigcap", "⋂" },
    { "bigoplus", "⨁" },
    { "bigotimes", "⨂" },
    { "bigsqcup", "⨆" },
    { "bigvee", "⋁" },
    { "bigwedge", "⋀" },

    // ── Trigonometric & Hyperbolic ───────────────────────────────────────────
    { "sin", "sin" },
    { "cos", "cos" },
    { "tan", "tan" },
    { "cot", "cot" },
    { "sec", "sec" },
    { "csc", "csc" },
    { "arcsin", "arcsin" },
    { "arccos", "arccos" },
    { "arctan", "arctan" },
    { "arccot", "arccot" },
    { "arcsec", "arcsec" },
    { "arccsc", "arccsc" },
    { "asin", "asin" },
    { "acos", "acos" },
    { "atan", "atan" },
    { "acot", "acot" },
    { "asec", "asec" },
    { "acsc", "acsc" },
    { "sinh", "sinh" },
    { "cosh", "cosh" },
    { "tanh", "tanh" },
    { "coth", "coth" },
    { "sech", "sech" },
    { "csch", "csch" },
    { "arsinh", "arsinh" },
    { "arcosh", "arcosh" },
    { "artanh", "artanh" },
    { "arcoth", "arcoth" },
    { "asinh", "asinh" },
    { "acosh", "acosh" },
    { "atanh", "atanh" },

    // ── Exponential, Logarithmic, Analysis ───────────────────────────────────
    { "ln", "ln" },
    { "log", "log" },
    { "lg", "lg" },
    { "lb", "lb" },
    { "exp", "exp" },
    { "lim", "lim" },
    { "liminf", "lim inf" },
    { "limsup", "lim sup" },
    { "injlim", "inj lim" },
    { "projlim", "proj lim" },
    { "max", "max" },
    { "min", "min" },
    { "sup", "sup" },
    { "inf", "inf" },
    { "argmax", "arg max" },
    { "argmin", "arg min" },
    { "arg", "arg" },
    { "deg", "deg" },
    { "det", "det" },
    { "dim", "dim" },
    { "gcd", "gcd" },
    { "lcm", "lcm" },
    { "hom", "hom" },
    { "ker", "ker" },
    { "coker", "coker" },
    { "im", "im" },
    { "image", "image" },
    { "tr", "tr" },
    { "trace", "trace" },
    { "rank", "rank" },
    { "diag", "diag" },
    { "span", "span" },
    { "sgn", "sgn" },
    { "sign", "sign" },
    { "sinc", "sinc" },
    { "erf", "erf" },
    { "erfc", "erfc" },
    { "cov", "cov" },
    { "var", "var" },
    { "corr", "corr" },
    { "grad", "grad" },
    { "curl", "curl" },
    { "rot", "rot" },
    { "Pr", "Pr" },
    { "mod", "mod" },
    { "bmod", "mod" },
    { "pmod", "mod" },

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
    { "longrightarrow", "⟶" },
    { "longleftarrow", "⟵" },
    { "longleftrightarrow", "⟷" },
    { "Longrightarrow", "⟹" },
    { "Longleftarrow", "⟺" },
    { "Longleftrightarrow", "⟺" },
    { "longmapsto", "⟼" },

    // ── Delimiters & Brackets ────────────────────────────────────────────────
    { "langle", "⟨" },
    { "rangle", "⟩" },
    { "lfloor", "⌊" },
    { "rfloor", "⌋" },
    { "lceil", "⌈" },
    { "rceil", "⌉" },
    { "lbrace", "{" },
    { "rbrace", "}" },
    { "vert", "|" },
    { "Vert", "║" },
    { "backslash", "\\" },

    // ── Ellipses & Dots ──────────────────────────────────────────────────────
    { "dots", "…" },
    { "ldots", "…" },
    { "cdots", "⋯" },
    { "ddots", "⋱" },
    { "vdots", "⋮" }
};

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

fn String transform_math(ast::Arena* arena, String input)
{
    if (input.len == 0) return "";

    buffer::ByteBuffer mb;
    mb.init((usz)input.len * 4 + 256);
    defer mb.free();

    usz i = 0;

    while (i < (usz)input.len)
    {
        char c = input[i];

        // ── 1. LaTeX Math Backslash Commands & Spaces ────────────────────────
        if (c == '\\')
        {
            if (i + 1 < (usz)input.len)
            {
                char next_c = input[i + 1];
                if (next_c == '{' || next_c == '}')
                {
                    mb.append_char(next_c);
                    i += 2;
                    continue;
                }
                if (next_c == ',')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ':')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == ';')
                {
                    mb.append_zstr(" ");
                    i += 2;
                    continue;
                }
                if (next_c == '!')
                {
                    i += 2;
                    continue;
                }
                if (next_c == ' ')
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

            String cmd = input[cmd_start : cmd_end - cmd_start];

            // ── Quad Spacing: \quad, \qquad ──────────────────────────────────
            if (cmd == "quad")
            {
                mb.append_zstr(" ");
                i = cmd_end;
                continue;
            }
            if (cmd == "qquad")
            {
                mb.append_zstr("  ");
                i = cmd_end;
                continue;
            }

            // ── Operatorname / Text / Style Wrappers ─────────────────────────
            if (cmd == "operatorname" || cmd == "text" || cmd == "mathbf" || cmd == "mathrm" || cmd == "mathit" || cmd == "mathsf" || cmd == "hspace" || cmd == "vspace")
            {
                i = cmd_end;
                while (i < (usz)input.len && (input[i] == ' ' || input[i] == '*')) i++;
                if (i < (usz)input.len && input[i] == '{')
                {
                    i++;
                    while (i < (usz)input.len && input[i] != '}')
                    {
                        if (cmd != "hspace" && cmd != "vspace")
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == '}') i++;
                }
                if (cmd == "operatorname") mb.append_char(' ');
                continue;
            }

            // ── Blackboard Bold: \mathbb{R} ───────────────────────────────────
            if (cmd == "mathbb")
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
                            mb.append_zstr(bb);
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
            if (cmd == "mathcal" || cmd == "mathscr")
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
                            mb.append_zstr(cal);
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
            if (cmd == "vec" || cmd == "hat" || cmd == "bar" || cmd == "overline" || cmd == "dot" || cmd == "ddot" || cmd == "tilde" || cmd == "acute" || cmd == "grave")
            {
                char* combining = "⃗";
                if (cmd == "hat")
                {
                    combining = "̂";
                }
                else if (cmd == "bar" || cmd == "overline")
                {
                    combining = "̄";
                }
                else if (cmd == "dot")
                {
                    combining = "̇";
                }
                else if (cmd == "ddot")
                {
                    combining = "̈";
                }
                else if (cmd == "tilde")
                {
                    combining = "̃";
                }
                else if (cmd == "acute")
                {
                    combining = "́";
                }
                else if (cmd == "grave")
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
                    String arg_content = input[arg_start : i - arg_start];
                    if (i < (usz)input.len && input[i] == '}') i++;

                    String t_arg = transform_math(arena, arg_content);
                    mb.append_slice(t_arg);
                    mb.append_zstr(combining);
                }
                else if (i < (usz)input.len)
                {
                    mb.append_char(input[i++]);
                    mb.append_zstr(combining);
                }
                continue;
            }

            // ── Fractions: \frac{num}{den} ───────────────────────────────────
            if (cmd == "frac" || cmd == "dfrac" || cmd == "tfrac")
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
                    String num = input[n_start : i - n_start];
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
                        String den = input[d_start : i - d_start];
                        if (i < (usz)input.len && input[i] == '}') i++;

                        String t_num = transform_math(arena, num);
                        String t_den = transform_math(arena, den);

                        if (t_num == "1" && t_den == "2") { mb.append_zstr("½"); continue; }
                        if (t_num == "1" && t_den == "3") { mb.append_zstr("⅓"); continue; }
                        if (t_num == "2" && t_den == "3") { mb.append_zstr("⅔"); continue; }
                        if (t_num == "1" && t_den == "4") { mb.append_zstr("¼"); continue; }
                        if (t_num == "3" && t_den == "4") { mb.append_zstr("¾"); continue; }
                        if (t_num == "1" && t_den == "5") { mb.append_zstr("⅕"); continue; }
                        if (t_num == "2" && t_den == "5") { mb.append_zstr("⅖"); continue; }
                        if (t_num == "3" && t_den == "5") { mb.append_zstr("⅗"); continue; }
                        if (t_num == "4" && t_den == "5") { mb.append_zstr("⅘"); continue; }
                        if (t_num == "1" && t_den == "6") { mb.append_zstr("⅙"); continue; }
                        if (t_num == "5" && t_den == "6") { mb.append_zstr("⅚"); continue; }
                        if (t_num == "1" && t_den == "8") { mb.append_zstr("⅛"); continue; }
                        if (t_num == "3" && t_den == "8") { mb.append_zstr("⅜"); continue; }
                        if (t_num == "5" && t_den == "8") { mb.append_zstr("⅝"); continue; }
                        if (t_num == "7" && t_den == "8") { mb.append_zstr("⅞"); continue; }

                        bool complex_num = (t_num.len > 1 && (t_num[0] != '(' || t_num[t_num.len - 1] != ')'));
                        bool complex_den = (t_den.len > 1 && (t_den[0] != '(' || t_den[t_den.len - 1] != ')'));

                        if (complex_num) mb.append_char('(');
                        mb.append_slice(t_num);
                        if (complex_num) mb.append_char(')');

                        mb.append_zstr(" / ");

                        if (complex_den) mb.append_char('(');
                        mb.append_slice(t_den);
                        if (complex_den) mb.append_char(')');
                        continue;
                    }
                }
            }

            // ── Roots: \sqrt[n]{...} or \sqrt{...} ───────────────────────────
            if (cmd == "sqrt")
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
                            mb.append_zstr(deg);
                        }
                        else
                        {
                            mb.append_char(input[i]);
                        }
                        i++;
                    }
                    if (i < (usz)input.len && input[i] == ']') i++;
                }

                mb.append_zstr("√");

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
                    String rad = input[rad_start : i - rad_start];
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
                if (cmd == SYMBOLS[s].name)
                {
                    mb.append_slice(SYMBOLS[s].glyph);
                    if (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z') || (input[cmd_end] >= '0' && input[cmd_end] <= '9')))
                    {
                        mb.append_char(' ');
                    }
                    found_sym = true;
                    i = cmd_end;
                    break;
                }
            }
            if (found_sym) continue;

            // If unknown command, emit clean command name with space
            mb.append_slice(cmd);
            if (cmd_end < (usz)input.len && ((input[cmd_end] >= 'a' && input[cmd_end] <= 'z') || (input[cmd_end] >= 'A' && input[cmd_end] <= 'Z') || (input[cmd_end] >= '0' && input[cmd_end] <= '9')))
            {
                mb.append_char(' ');
            }
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
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start : s_end - s_start];
                        if (scmd == "alpha") { mb.append_zstr("ᵅ"); }
                        else if (scmd == "beta") { mb.append_zstr("ᵝ"); }
                        else if (scmd == "gamma") { mb.append_zstr("ᵞ"); }
                        else if (scmd == "delta") { mb.append_zstr("ᵟ"); }
                        else if (scmd == "epsilon") { mb.append_zstr("ᵋ"); }
                        else if (scmd == "theta") { mb.append_zstr("ᶿ"); }
                        else if (scmd == "phi") { mb.append_zstr("ᵠ"); }
                        else if (scmd == "chi") { mb.append_zstr("ᵡ"); }
                        else if (scmd == "infty") { mb.append_zstr("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append_zstr("→"); }
                        else
                        {
                            bool found = false;
                            for (usz s = 0; s < SYMBOLS.len; s++)
                            {
                                if (scmd == SYMBOLS[s].name)
                                {
                                    mb.append_slice(SYMBOLS[s].glyph);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sup = get_superscript_char(input[i]);
                    if (sup != null)
                    {
                        mb.append_zstr(sup);
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
                    mb.append_zstr(sup);
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
                        usz s_start = i + 1;
                        usz s_end = s_start;
                        while (s_end < (usz)input.len && ((input[s_end] >= 'a' && input[s_end] <= 'z') || (input[s_end] >= 'A' && input[s_end] <= 'Z'))) s_end++;
                        String scmd = input[s_start : s_end - s_start];
                        if (scmd == "beta") { mb.append_zstr("ᵦ"); }
                        else if (scmd == "gamma") { mb.append_zstr("ᵧ"); }
                        else if (scmd == "rho") { mb.append_zstr("ᵨ"); }
                        else if (scmd == "phi") { mb.append_zstr("ᵩ"); }
                        else if (scmd == "chi") { mb.append_zstr("ᵪ"); }
                        else if (scmd == "infty") { mb.append_zstr("∞"); }
                        else if (scmd == "to" || scmd == "rightarrow") { mb.append_zstr("→"); }
                        else
                        {
                            bool found = false;
                            for (usz s = 0; s < SYMBOLS.len; s++)
                            {
                                if (scmd == SYMBOLS[s].name)
                                {
                                    mb.append_slice(SYMBOLS[s].glyph);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) mb.append_slice(scmd);
                        }
                        i = s_end;
                        continue;
                    }

                    char* sub = get_subscript_char(input[i]);
                    if (sub != null)
                    {
                        mb.append_zstr(sub);
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
                    mb.append_zstr(sub);
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

    return mb.to_arena_string(arena);
}
