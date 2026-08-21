module unit_test;

import std::core::test;
import std::core::mem;
import std::collections::list;
import logic;
import strutils;
import buffer;
import parser;
import math;
import render;

fn void test_unicode_display_width() @test
{
    // ASCII
    test::eq(strutils::string_display_width("hello world"), 11);
    test::eq(strutils::string_display_width(""), 0);

    // ANSI escape codes should not contribute to width
    test::eq(strutils::string_display_width("\x1b[31;1mhello\x1b[0m"), 5);
    test::eq(strutils::string_display_width("\x1b[48;2;255;0;0m\x1b[38;2;0;255;0mC3 Lang\x1b[0m"), 7);

    // Plane 1 Mathematical Alphanumeric Symbols must have width 1
    test::eq(strutils::string_display_width("ℝ"), 1); // U+211D
    test::eq(strutils::string_display_width("𝔸"), 1); // U+1D538 (Plane 1)
    test::eq(strutils::string_display_width("𝒜"), 1); // U+1D49C (Plane 1)
    test::eq(strutils::string_display_width("𝔤"), 1); // U+1D524 (Fraktur Plane 1)
    test::eq(strutils::string_display_width("λ"), 1); // Greek
    test::eq(strutils::string_display_width("∫"), 1); // Integral

    // Emojis (Width 2)
    test::eq(strutils::string_display_width("🖼"), 2);
    test::eq(strutils::string_display_width("💡"), 2);

    // CJK Ideographs (Width 2 per char)
    test::eq(strutils::string_display_width("中文测试"), 8);
}

fn void test_html_entity_decoding() @test
{
    char[64] out_buf;
    strutils::decode_html_entities("&copy; 2025 &mdash; &infin; &plusmn; &check;", &out_buf[0], 64);
    String res = (String)(&out_buf[0])[:strutils::str_len(&out_buf[0])];
    test::eq(res, "© 2025 — ∞ ± ✔");
}

fn void test_byte_buffer() @test
{
    buffer::ByteBuffer b;
    b.init(16);
    defer b.free();

    b.append_zstr("Hello ");
    b.append_slice("World");
    b.append_char('!');
    b.append_spaces(2);
    b.append_repeat("=", 3);
    b.append_char(' ');
    b.append_int(42);

    test::eq(b.to_string(), "Hello World!  === 42");
    test::eq((int)b.len, 20);

    b.reset();
    test::eq((int)b.len, 0);
    test::eq(b.to_string(), "");
}

fn void test_inline_math_vs_currency() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    // Real math formula
    String math_input = "Formula is $a^2 + b^2 = c^2$ today.";
    Span[] spans = parser::parse_inline(&arena, math_input);
    test::eq((int)spans.len, 3);
    test::eq((int)spans[1].kind, (int)SpanKind.MATH_INLINE);

    // Currency values ($5 and $10) should NOT be parsed as math
    String currency_input = "Costs $5 and shipping is $10.";
    Span[] curr_spans = parser::parse_inline(&arena, currency_input);
    test::eq((int)curr_spans.len, 1);
    test::eq((int)curr_spans[0].kind, (int)SpanKind.TEXT);
}

fn void test_intra_word_underscore() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    // Variable with underscores should NOT become italics
    String code_ident = "Check my_variable_name and another_variable_here.";
    Span[] spans = parser::parse_inline(&arena, code_ident);
    test::eq((int)spans.len, 1);
    test::eq((int)spans[0].kind, (int)SpanKind.TEXT);

    // Actual italics with leading/trailing word boundaries
    String italic_text = "This is _italic text_ here.";
    Span[] it_spans = parser::parse_inline(&arena, italic_text);
    test::eq((int)it_spans.len, 3);
    test::eq((int)it_spans[1].kind, (int)SpanKind.ITALIC);
}

fn void test_link_parentheses() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    String link_input = "Read [Wikipedia](https://en.wikipedia.org/wiki/Function_(mathematics)) for details.";
    Span[] spans = parser::parse_inline(&arena, link_input);
    test::eq((int)spans.len, 3);
    test::eq((int)spans[1].kind, (int)SpanKind.LINK);
    test::eq(spans[1].text, "Wikipedia");
    test::eq(spans[1].url, "https://en.wikipedia.org/wiki/Function_(mathematics)");
}

fn void test_multiline_paragraph_reflow() @test
{
    String md = "Line one of paragraph.\nLine two of paragraph.\nLine three of paragraph.\n\nSecond paragraph here.";
    Document doc = parser::parse_document(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[0].kind, (int)BlockKind.PARAGRAPH);
    test::eq((int)doc.blocks[1].kind, (int)BlockKind.BLANK);
    test::eq((int)doc.blocks[2].kind, (int)BlockKind.PARAGRAPH);

    test::eq(doc.blocks[0].paragraph.spans[0].text, "Line one of paragraph. Line two of paragraph. Line three of paragraph.");
    test::eq(doc.blocks[2].paragraph.spans[0].text, "Second paragraph here.");
}

fn void test_ordered_lists_and_tasks() @test
{
    String md = "1. First step\n2. Second step\n3. Third step\n- [x] Done item\n- [ ] Todo item";
    Document doc = parser::parse_document(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 5);

    test::eq((int)doc.blocks[0].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[0].list_item.kind, (int)ListKind.ORDERED);
    test::eq(doc.blocks[0].list_item.order_number, 1);

    test::eq((int)doc.blocks[1].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[1].list_item.kind, (int)ListKind.ORDERED);
    test::eq(doc.blocks[1].list_item.order_number, 2);

    test::eq((int)doc.blocks[3].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[3].list_item.kind, (int)ListKind.TASK_CHECKED);

    test::eq((int)doc.blocks[4].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[4].list_item.kind, (int)ListKind.TASK_UNCHECKED);
}

fn void test_multiline_callout() @test
{
    String md = "> [!NOTE]\n> This is the first line of the note.\n> And this is the second line of the note.\n> And the third line.\n\nNext text.";
    Document doc = parser::parse_document(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[0].kind, (int)BlockKind.CALLOUT);
    test::eq((int)doc.blocks[0].callout.kind, (int)CalloutKind.NOTE);
    test::eq(doc.blocks[0].callout.title, "NOTE");

    test::eq((int)doc.blocks[0].callout.spans.len, 1);
    test::eq(doc.blocks[0].callout.spans[0].text, "This is the first line of the note. And this is the second line of the note. And the third line.");
}

fn void test_footnote_def_label() @test
{
    String md = "Here is a note[^ref].\n\n[^ref]: This is the custom footnote explanation.";
    Document doc = parser::parse_document(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[2].kind, (int)BlockKind.FOOTNOTE_DEF);
    test::eq(doc.blocks[2].footnote_def.label, "ref");
    test::eq(doc.blocks[2].footnote_def.spans[0].text, "This is the custom footnote explanation.");
}

fn void test_latex_2d_fractions_and_matrices() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    // Fraction
    MathBox frac = math::render_latex_to_box(&arena, "\\frac{x + 1}{y - 1}");
    test::eq(frac.height, 3);
    test::eq(frac.baseline, 1);
    test::eq(frac.rows[1], "───────");

    // 2x2 Matrix
    MathBox mat = math::render_latex_to_box(&arena, "\\begin{pmatrix} 1 & 0 \\\\ 0 & 1 \\end{pmatrix}");
    test::eq(mat.height, 2);
    test::eq(mat.rows[0], "⎛ 1  0 ⎞");
    test::eq(mat.rows[1], "⎝ 0  1 ⎠");
}

fn void test_bracket_expressions() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    // Functional bracket expression like action in physics: S[q] = \int L dt
    MathBox act = math::render_latex_to_box(&arena, "S[q] = \\int L(q, \\dot{q}, t) dt");
    test::gt(act.width, 10);
    test::gt(act.height, 0);

    // Matrix index or interval: f(x) \in [a, b]
    MathBox iv = math::render_latex_to_box(&arena, "x \\in [0, 1]");
    test::gt(iv.width, 5);
}

fn void test_extensible_arrows() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox arrow = math::render_latex_to_box(&arena, "A \\xrightarrow[\\text{below}]{\\text{above}} B");
    test::eq(arrow.height, 3);
    test::eq(arrow.baseline, 1);
}

fn void test_fraktur_and_gothic() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox fk = math::render_latex_to_box(&arena, "\\mathfrak{g} \\in \\mathfrak{sl}(2, \\mathbb{C})");
    test::gt(fk.width, 0);
}

fn void test_big_operators_and_limits() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox union_box = math::render_latex_to_box(&arena, "\\bigcup_{i=1}^n A_i");
    test::eq(union_box.height, 5); // 1 (sup) + 3 (glyph) + 1 (sub)
}

fn void test_primes_and_derivatives() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox p1 = math::render_latex_to_box(&arena, "f'''(x)");
    test::gt(p1.width, 0);
}

fn void test_command_bitstruct_flags() @test
{
    MathCommand cmd;
    MathCmdFlags flags;

    // Check fraction traits
    bool found_frac = logic::lookup_command("frac", &cmd, &flags);
    test::eq(found_frac, true);
    test::eq((int)cmd, (int)MathCommand.FRAC);
    test::eq(flags.fraction, true);
    assert(flags.arity == 2);
    test::eq(flags.opt_arg, false);

    // Check sqrt traits (optional root index degree)
    bool found_sqrt = logic::lookup_command("sqrt", &cmd, &flags);
    test::eq(found_sqrt, true);
    test::eq((int)cmd, (int)MathCommand.SQRT);
    test::eq(flags.opt_arg, true);
    assert(flags.arity == 1);

    // Check summation traits
    bool found_sum = logic::lookup_command("sum", &cmd, &flags);
    test::eq(found_sum, true);
    test::eq(flags.big_op, true);
}

fn void test_capi_exports() @test
{
    // Test 2D export
    CLatexBox box = math::latexmath_render_2d("\\frac{a + 1}{b - 1}");
    test::eq(box.height, 3);
    test::eq(box.baseline, 1);
    test::gt(box.width, 0);
    math::latexmath_free_2d(&box);
    test::eq((void*)box.rows, null);

    // Test 1D inline export
    char* inline_str = math::latexmath_render_inline("x^2 + y^2 = r^2");
    test::gt(strutils::str_len(inline_str), 0);
    math::latexmath_free_string(inline_str);
}

fn void test_modulo_congruence() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox pmod = math::render_latex_to_box(&arena, "a \\equiv b \\pmod{m}");
    test::gt(pmod.width, 0);
}

fn void test_oeis_symbols_suite() @test
{
    Arena arena;
    arena.init(16384);
    defer arena.free();

    // Relations from OEIS wiki
    String t1 = math::transform_math(&arena, "\\leqslant \\geqslant \\nleq \\ngeq \\lll \\ggg \\prec \\succ \\preceq \\succeq \\bowtie \\smile \\frown \\ulcorner \\urcorner \\llcorner \\lrcorner \\eth \\digamma");
    test::gt(strutils::string_display_width(t1), 0);

    // Negated relations
    String t2 = math::transform_math(&arena, "\\nshortmid \\nshortparallel \\nvdash \\nvDash \\nVdash \\nVDash \\ntriangleleft \\ntriangleright \\nsubseteq \\subsetneq \\supsetneq");
    test::gt(strutils::string_display_width(t2), 0);

    // Number sets
    String t3 = math::transform_math(&arena, "\\N \\Z \\Q \\R \\C \\H \\O");
    test::gt(strutils::string_display_width(t3), 0);

    // Greek uppercase & lowercase
    String t4 = math::transform_math(&arena, "\\Alpha \\Beta \\Gamma \\Delta \\Digamma \\alpha \\beta \\gamma \\delta \\digamma");
    test::gt(strutils::string_display_width(t4), 0);
}

fn void test_logic_arena_mark_and_reset() @test
{
    logic::Arena arena;
    arena.init(1024);
    defer arena.free();

    String s1 = arena.dup_string("persistent_state");
    test::eq(s1, "persistent_state");

    logic::ArenaMark mark = arena.mark();

    // Transient allocations inside scratch scope
    {
        logic::LocalScratchScope scope = logic::enter_scratch_scope(&arena);
        String s2 = arena.dup_string("transient_scratch_1");
        String s3 = arena.dup_string("transient_scratch_2");
        test::eq(s2, "transient_scratch_1");
        test::eq(s3, "transient_scratch_2");
        scope.exit();
    }

    // After scratch scope exited, arena head used offset is reset to mark
    test::eq(arena.head.used, mark.used);

    // Persistent string remains valid
    test::eq(s1, "persistent_state");
}

fn void test_logic_bitstruct_flags() @test
{
    logic::init_global_context(120, 40);
    defer logic::free_global_context();

    test::eq(logic::g_ctx.terminal_width, 120);
    test::eq(logic::g_ctx.terminal_height, 40);

    logic::AppFlags flag_plain = { .plain_mode };
    logic::AppFlags flag_watch = { .live_watch };
    logic::AppFlags flag_wrap = { .no_wrap };

    logic::set_app_flag(true, flag_plain);
    logic::set_app_flag(true, flag_watch);
    test::eq(logic::has_app_flag(flag_plain), true);
    test::eq(logic::has_app_flag(flag_watch), true);
    test::eq(logic::has_app_flag(flag_wrap), false);

    logic::toggle_app_flag(flag_wrap);
    test::eq(logic::has_app_flag(flag_wrap), true);

    logic::toggle_app_flag(flag_wrap);
    test::eq(logic::has_app_flag(flag_wrap), false);

    // Local parser bitstructs
    logic::InlineParseFlags in_flags = { .in_bold, .in_math };
    test::eq(in_flags.in_bold, true);
    test::eq(in_flags.in_math, true);
    test::eq(in_flags.in_italic, false);

    logic::MathRenderFlags m_flags = { .display_mode, .is_fraction_num };
    test::eq(m_flags.display_mode, true);
    test::eq(m_flags.is_fraction_num, true);
    test::eq(m_flags.in_subscript, false);
}

