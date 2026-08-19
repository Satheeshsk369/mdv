/**
 * latexmath.h - Standalone 2D LaTeX Math Layout & Rendering Engine
 *
 * Provides high-performance 2D multi-line ASCII/Unicode rendering for LaTeX formulas.
 */

#ifndef LATEXMATH_H
#define LATEXMATH_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char** rows;      /* Array of null-terminated UTF-8 string rows */
    int width;        /* Maximum horizontal character width */
    int height;       /* Number of rendered rows */
    int baseline;     /* Primary baseline row index (0-indexed) */
} CLatexBox;

/**
 * Render a LaTeX equation into a 2D multi-line ASCII/Unicode grid.
 *
 * @param latex_src  Null-terminated LaTeX math expression (e.g. "\\frac{a}{b} + \\sqrt{x}")
 * @return CLatexBox Struct containing the rendered rows, dimensions, and baseline.
 */
CLatexBox latexmath_render_2d(const char* latex_src);

/**
 * Free memory allocated by latexmath_render_2d.
 */
void latexmath_free_2d(CLatexBox* box);

/**
 * Transform an inline LaTeX formula into a compact 1D Unicode string.
 *
 * @param latex_src  Null-terminated inline LaTeX expression (e.g. "x^2 + y^2 = r^2")
 * @return Heap-allocated null-terminated UTF-8 string. Must be freed with latexmath_free_string.
 */
char* latexmath_render_inline(const char* latex_src);

/**
 * Free a string allocated by latexmath_render_inline.
 */
void latexmath_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif /* LATEXMATH_H */
