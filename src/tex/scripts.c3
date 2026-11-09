module tex;

import std::core::mem;
import ast;
import text;

struct Script
{
    String from;
    String[] to;
}

const Script SUPER = {
    "0123456789+-=()abcdefghijklmnoprstuvwxyzABDEGHIJKLMNOPRTUVW/",
    { "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁺", "⁻", "⁼", "⁽", "⁾",
      "ᵃ", "ᵇ", "ᶜ", "ᵈ", "ᵉ", "ᶠ", "ᵍ", "ʰ", "ⁱ", "ʲ", "ᵏ", "ˡ", "ᵐ", "ⁿ", "ᵒ", "ᵖ", "ʳ", "ˢ", "ᵗ", "ᵘ", "ᵛ", "ʷ", "ˣ", "ʸ", "ᶻ",
      "ᴬ", "ᴮ", "ᴰ", "ᴱ", "ᴳ", "ᴴ", "ᴵ", "ᴶ", "ᴷ", "ᴸ", "ᴹ", "ᴺ", "ᴼ", "ᴾ", "ᴿ", "ᵀ", "ᵁ", "ⱽ", "ᵂ", "ᐟ" }
};

const Script SUB = {
    "0123456789+-=()aehijklmnoprstuvx",
    { "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉", "₊", "₋", "₌", "₍", "₎",
      "ₐ", "ₑ", "ₕ", "ᵢ", "ⱼ", "ₖ", "ₗ", "ₘ", "ₙ", "ₒ", "ₚ", "ᵣ", "ₛ", "ₜ", "ᵤ", "ᵥ", "ₓ" }
};

fn String Script.map(&self, char c)
{
    if (try i = self.from.index_of_char(c)) return self.to[i];
    return "";
}

fn bool Script.fits(&self, String s)
{
    foreach (c : s) if (!self.from.contains_char(c)) return false;
    return s.len > 0;
}

fn String Script.apply(&self, ast::Arena* arena, String s)
{
    if (s.len == 0) return "";
    DString mb;
    mb.init(mem, s.len * 4 + 8);
    defer mb.free();
    foreach (c : s)
    {
        String glyph = self.map(c);
        if (glyph.len == 0) return "";
        mb.append(glyph);
    }
    return mb.keep(arena);
}
