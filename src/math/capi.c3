module math;

import std::core::mem;
import ast;
import strutils;

/**
 * C-ABI struct representing a 2D rendered LaTeX equation.
 */
struct CLatexBox {
    char** rows;
    int width;
    int height;
    int baseline;
}

/**
 * Render a LaTeX equation into a 2D multi-line ASCII/Unicode grid.
 * Returns a CLatexBox containing an array of null-terminated row strings.
 */
fn CLatexBox latexmath_render_2d(char* latex_zstr) @export("latexmath_render_2d")
{
    CLatexBox result;
    result.rows = null;
    result.width = 0;
    result.height = 0;
    result.baseline = 0;

    if (latex_zstr == null) return result;

    String latex_str = (String)latex_zstr[:(usz)strutils::str_len(latex_zstr)];

    ast::Arena arena;
    arena.init(16384);
    defer arena.free();

    MathBox box = render_latex_to_box(&arena, latex_str);

    result.width = box.width;
    result.height = box.height;
    result.baseline = box.baseline;

    if (box.height > 0)
    {
        result.rows = (char**)mem::alloc_array(char*, (usz)box.height);
        for (int r = 0; r < box.height; r++)
        {
            String row = box.rows[(usz)r];
            char* zrow = (char*)mem::alloc_array(char, (usz)row.len + 1);
            mem::copy(zrow, row.ptr, (usz)row.len);
            zrow[row.len] = 0;
            result.rows[(usz)r] = zrow;
        }
    }

    return result;
}

/**
 * Free memory allocated by latexmath_render_2d.
 */
fn void latexmath_free_2d(CLatexBox* box) @export("latexmath_free_2d")
{
    if (box == null || box.rows == null) return;
    for (int r = 0; r < box.height; r++)
    {
        if (box.rows[(usz)r] != null)
        {
            mem::free(box.rows[(usz)r]);
        }
    }
    mem::free(box.rows);
    box.rows = null;
    box.height = 0;
    box.width = 0;
}

/**
 * Transform an inline LaTeX formula into a compact 1D Unicode string.
 * Returns a heap-allocated null-terminated string that must be freed with latexmath_free_string.
 */
fn char* latexmath_render_inline(char* latex_zstr) @export("latexmath_render_inline")
{
    if (latex_zstr == null) return null;

    String latex_str = (String)latex_zstr[:(usz)strutils::str_len(latex_zstr)];

    ast::Arena arena;
    arena.init(8192);
    defer arena.free();

    String res = transform_math(&arena, latex_str);
    char* out_str = (char*)mem::alloc_array(char, (usz)res.len + 1);
    mem::copy(out_str, res.ptr, (usz)res.len);
    out_str[res.len] = 0;

    return out_str;
}

/**
 * Free string allocated by latexmath_render_inline.
 */
fn void latexmath_free_string(char* str) @export("latexmath_free_string")
{
    if (str != null)
    {
        mem::free(str);
    }
}
