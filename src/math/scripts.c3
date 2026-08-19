module math;

import std::core::mem;
import ast;
import buffer;

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

fn String try_unicode_superscript(ast::Arena* arena, String s)
{
    if (s.len == 0) return "";
    buffer::ByteBuffer mb;
    mb.init((usz)(s.len * 4 + 8));
    defer mb.free();

    for (usz i = 0; i < (usz)s.len; i++)
    {
        char* sup = get_superscript_char(s[i]);
        if (sup == null) return "";
        mb.append_zstr(sup);
    }
    return mb.to_arena_string(arena);
}

fn String try_unicode_subscript(ast::Arena* arena, String s)
{
    if (s.len == 0) return "";
    buffer::ByteBuffer mb;
    mb.init((usz)(s.len * 4 + 8));
    defer mb.free();

    for (usz i = 0; i < (usz)s.len; i++)
    {
        char* sub = get_subscript_char(s[i]);
        if (sub == null) return "";
        mb.append_zstr(sub);
    }
    return mb.to_arena_string(arena);
}
