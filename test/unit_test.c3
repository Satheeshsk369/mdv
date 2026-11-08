module unit_test;

import std::core::test;
import std::core::mem;
import std::io;
import std::collections::list;
import ast;
import text;
import parser;
import tex;
import render;
import ansi;

fn void testUnicodeDisplayWidth() @test
{
    test::eq(text::width("hello world"), 11);
    test::eq(text::width(""), 0);

    test::eq(text::width("\x1b[31;1mhello\x1b[0m"), 5);
    test::eq(text::width("\x1b[48;2;255;0;0m\x1b[38;2;0;255;0mC3 Lang\x1b[0m"), 7);

    test::eq(text::width("ℝ"), 1);
    test::eq(text::width("𝔸"), 1);
    test::eq(text::width("𝒜"), 1);
    test::eq(text::width("𝔤"), 1);
    test::eq(text::width("λ"), 1);
    test::eq(text::width("∫"), 1);

    test::eq(text::width("🖼"), 2);
    test::eq(text::width("💡"), 2);

    test::eq(text::width("中文测试"), 8);
}

fn void testByteBuffer() @test
{
    DString b;
    b.init(mem, 16);
    defer b.free();

    b.append("Hello ");
    b.append_string("World");
    b.append_char('!');
    b.spaces(2);
    b.repeat("=", 3);
    b.append_char(' ');
    b.appendf("%d", 42);

    test::eq(b.str_view(), "Hello World!  === 42");
    test::eq((int)b.len(), 20);

    b.clear();
    test::eq((int)b.len(), 0);
    test::eq(b.str_view(), "");
}

fn void testInlineMathVsCurrency() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    String mathInput = "Formula is $a^2 + b^2 = c^2$ today.";
    Span[] spans = parser::spans(&arena, mathInput);
    test::eq((int)spans.len, 3);
    test::eq((int)spans[1].kind, (int)SpanKind.MATH_INLINE);

    String currencyInput = "Costs $5 and shipping is $10.";
    Span[] currSpans = parser::spans(&arena, currencyInput);
    test::eq((int)currSpans.len, 1);
    test::eq((int)currSpans[0].kind, (int)SpanKind.TEXT);
}

fn void testIntraWordUnderscore() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    String codeIdent = "Check my_variable_name and another_variable_here.";
    Span[] spans = parser::spans(&arena, codeIdent);
    test::eq((int)spans.len, 1);
    test::eq((int)spans[0].kind, (int)SpanKind.TEXT);

    String italicText = "This is _italic text_ here.";
    Span[] itSpans = parser::spans(&arena, italicText);
    test::eq((int)itSpans.len, 3);
    test::eq((int)itSpans[1].kind, (int)SpanKind.ITALIC);
}

fn void testLinkParentheses() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();

    String linkInput = "Read [Wikipedia](https://en.wikipedia.org/wiki/Function_(mathematics)) for details.";
    Span[] spans = parser::spans(&arena, linkInput);
    test::eq((int)spans.len, 3);
    test::eq((int)spans[1].kind, (int)SpanKind.LINK);
    test::eq(spans[1].text, "Wikipedia");
    test::eq(spans[1].url, "https://en.wikipedia.org/wiki/Function_(mathematics)");
}

fn void testMultilineParagraphReflow() @test
{
    String md = "Line one of paragraph.\nLine two of paragraph.\nLine three of paragraph.\n\nSecond paragraph here.";
    Document doc = parser::parse(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[0].kind, (int)BlockKind.PARAGRAPH);
    test::eq((int)doc.blocks[1].kind, (int)BlockKind.BLANK);
    test::eq((int)doc.blocks[2].kind, (int)BlockKind.PARAGRAPH);

    test::eq(doc.blocks[0].spans[0].text, "Line one of paragraph. Line two of paragraph. Line three of paragraph.");
    test::eq(doc.blocks[2].spans[0].text, "Second paragraph here.");
}

fn void testOrderedListsAndTasks() @test
{
    String md = "1. First step\n2. Second step\n3. Third step\n- [x] Done item\n- [ ] Todo item";
    Document doc = parser::parse(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 5);

    test::eq((int)doc.blocks[0].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[0].item.kind, (int)ListKind.ORDERED);
    test::eq(doc.blocks[0].item.number, 1);

    test::eq((int)doc.blocks[1].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[1].item.kind, (int)ListKind.ORDERED);
    test::eq(doc.blocks[1].item.number, 2);

    test::eq((int)doc.blocks[3].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[3].item.kind, (int)ListKind.TASK_CHECKED);

    test::eq((int)doc.blocks[4].kind, (int)BlockKind.LIST_ITEM);
    test::eq((int)doc.blocks[4].item.kind, (int)ListKind.TASK_UNCHECKED);
}

fn void testMultilineCallout() @test
{
    String md = "> [!NOTE]\n> This is the first line of the note.\n> And this is the second line of the note.\n> And the third line.\n\nNext text.";
    Document doc = parser::parse(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[0].kind, (int)BlockKind.CALLOUT);
    test::eq((int)doc.blocks[0].callout.kind, (int)CalloutKind.NOTE);
    test::eq(doc.blocks[0].callout.title, "NOTE");

    Block[] inner = doc.blocks[0].children;
    test::eq((int)inner.len, 1);
    test::eq((int)inner[0].kind, (int)BlockKind.PARAGRAPH);
    test::eq(inner[0].start, 1);
    test::eq(inner[0].end, 3);
    test::eq(inner[0].spans[0].text, "This is the first line of the note. And this is the second line of the note. And the third line.");
}

fn void testQuoteHoldsBlocks() @test
{
    Document doc = parser::parse("> a\n> > b\n> - c");
    defer doc.free();
    Block[] inner = doc.blocks[0].children;
    test::eq((int)inner.len, 3);
    test::eq((int)inner[1].children[0].kind, (int)BlockKind.PARAGRAPH);
    test::eq((int)inner[2].kind, (int)BlockKind.LIST_ITEM);
    test::eq(inner[2].start, 2);
}

fn void testCommonMarkInline() @test
{
    Document doc = parser::parse("\\*a\\* <https://x.io> [t][R] &#169; \\(x^2\\)  \nnext\n\n[r]: http://y\n");
    defer doc.free();
    Span[] s = doc.blocks[0].spans;
    test::eq(s[0].text, "*a");
    test::eq(s[1].text, "* ");
    test::eq(s[2].url, "https://x.io");
    test::eq(s[4].url, "http://y");
    test::eq(s[5].text, " © ");
    test::eq(s[6].text, "x²");
    test::eq(s[7].text, "\nnext");
}

fn void testCapitalSuperscript() @test
{
    Document doc = parser::parse("$A^T P^{RW}$");
    defer doc.free();
    test::eq(doc.blocks[0].spans[0].text, "Aᵀ Pᴿᵂ");
}

fn void testSetextAndFences() @test
{
    Document doc = parser::parse("Title\n===\n\n```math\nx^2\n```\n\n\\[ y \\]\n\npara\n\n    code");
    defer doc.free();
    test::eq((int)doc.blocks[0].kind, (int)BlockKind.HEADING);
    test::eq(doc.blocks[0].level, 1);
    test::eq((int)doc.blocks[2].kind, (int)BlockKind.MATH_BLOCK);
    test::eq(doc.blocks[2].latex, "x^2");
    test::eq(doc.blocks[4].latex, "y");
    test::eq((int)doc.blocks[8].kind, (int)BlockKind.CODE_BLOCK);
}

fn void testFootnoteDefLabel() @test
{
    String md = "Here is a note[^ref].\n\n[^ref]: This is the custom footnote explanation.";
    Document doc = parser::parse(md);
    defer doc.free();

    test::eq((int)doc.blocks.len, 3);
    test::eq((int)doc.blocks[2].kind, (int)BlockKind.FOOTNOTE_DEF);
    test::eq(doc.blocks[2].label, "ref");
    test::eq(doc.blocks[2].spans[0].text, "This is the custom footnote explanation.");
}

fn void testLatex2dFractionsAndMatrices() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox frac = tex::latex(&arena, "\\frac{x + 1}{y - 1}");
    test::eq(frac.height, 3);
    test::eq(frac.baseline, 1);
    test::eq(frac.rows[1], "───────");

    MathBox mat = tex::latex(&arena, "\\begin{pmatrix} 1 & 0 \\\\ 0 & 1 \\end{pmatrix}");
    test::eq(mat.height, 2);
    test::eq(mat.rows[0], "⎛ 1  0 ⎞");
    test::eq(mat.rows[1], "⎝ 0  1 ⎠");
}

fn void testBracketExpressions() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox act = tex::latex(&arena, "S[q] = \\int L(q, \\dot{q}, t) dt");
    test::gt(act.width, 10);
    test::gt(act.height, 0);

    MathBox iv = tex::latex(&arena, "x \\in [0, 1]");
    test::gt(iv.width, 5);
}

fn void testExtensibleArrows() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox arrow = tex::latex(&arena, "A \\xrightarrow[\\text{below}]{\\text{above}} B");
    test::eq(arrow.height, 3);
    test::eq(arrow.baseline, 1);
}

fn void testFrakturAndGothic() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox fk = tex::latex(&arena, "\\mathfrak{g} \\in \\mathfrak{sl}(2, \\mathbb{C})");
    test::gt(fk.width, 0);
}

fn void testBigOperatorsAndLimits() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox unionBox = tex::latex(&arena, "\\bigcup_{i=1}^n A_i");
    test::eq(unionBox.height, 3);
}

fn void testPrimesAndDerivatives() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox p1 = tex::latex(&arena, "f'''(x)");
    test::gt(p1.width, 0);
}

fn void testCommandBitstructFlags() @test
{
    MathCommand cmd;
    MathCmdFlags flags;

    bool foundFrac = tex::command("frac", &cmd, &flags);
    test::eq(foundFrac, true);
    test::eq((int)cmd, (int)MathCommand.FRAC);
    test::eq(flags.fraction, true);
    assert(flags.arity == 2);
    test::eq(flags.optArg, false);

    bool foundSqrt = tex::command("sqrt", &cmd, &flags);
    test::eq(foundSqrt, true);
    test::eq((int)cmd, (int)MathCommand.SQRT);
    test::eq(flags.optArg, true);
    assert(flags.arity == 1);

    bool foundSum = tex::command("sum", &cmd, &flags);
    test::eq(foundSum, true);
    test::eq(flags.bigOp, true);
}

fn void testDirectMathRendering() @test
{
    Arena arena;
    arena.init(16384);
    defer arena.free();

    MathBox box = tex::latex(&arena, "\\frac{a + 1}{b - 1}");
    test::eq(box.height, 3);
    test::eq(box.baseline, 1);
    test::gt(box.width, 0);

    String inlineStr = tex::unicode(&arena, "x^2 + y^2 = r^2");
    test::gt(inlineStr.len, 0);
}

fn void testModuloCongruence() @test
{
    Arena arena;
    arena.init(8192);
    defer arena.free();

    MathBox pmod = tex::latex(&arena, "a \\equiv b \\pmod{m}");
    test::gt(pmod.width, 0);
}

fn void testOeisSymbolsSuite() @test
{
    Arena arena;
    arena.init(16384);
    defer arena.free();

    String t1 = tex::unicode(&arena, "\\leqslant \\geqslant \\nleq \\ngeq \\lll \\ggg \\prec \\succ \\preceq \\succeq \\bowtie \\smile \\frown \\ulcorner \\urcorner \\llcorner \\lrcorner \\eth \\digamma");
    test::gt(text::width(t1), 0);

    String t2 = tex::unicode(&arena, "\\nshortmid \\nshortparallel \\nvdash \\nvDash \\nVdash \\nVDash \\ntriangleleft \\ntriangleright \\nsubseteq \\subsetneq \\supsetneq");
    test::gt(text::width(t2), 0);

    String t3 = tex::unicode(&arena, "\\N \\Z \\Q \\R \\C \\H \\O");
    test::gt(text::width(t3), 0);

    String t4 = tex::unicode(&arena, "\\Alpha \\Beta \\Gamma \\Delta \\Digamma \\alpha \\beta \\gamma \\delta \\digamma");
    test::gt(text::width(t4), 0);
}

fn void testLogicArenaBlocks() @test
{
    ast::Arena arena;
    arena.init(64);
    defer arena.free();
    String small = arena.copy("persistent_state");
    String large = arena.copy("a string longer than the sixty four byte block so it spills into a new block");
    test::eq(small, "persistent_state");
    test::eq(large, "a string longer than the sixty four byte block so it spills into a new block");
}

fn void testBlockStartLinesBecomeParagraphs() @test
{
    foreach (String input : { ">foo", "\\begin{cases} a \\end{cases}" })
    {
        Document doc = parser::parse(input);
        defer doc.free();
        test::eq(doc.blocks.len, 1);
        test::eq(doc.blocks[0].kind, BlockKind.PARAGRAPH);
    }
}

fn void testCompactScriptsAndSpacing() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    MathBox frac = tex::latex(&arena, "\\frac{\\hbar^2 k^2}{2m L^2}");
    test::eq(frac.height, 3);
    test::eq(frac.rows[0].trim(), "ℏ² k²");
    test::eq(frac.rows[2].trim(), "2m L²");
}

fn void testNoSpaceBeforePunctuation() @test
{
    Document doc = parser::parse("Welcome to **mdv**! See $x^2$.");
    defer doc.free();
    render::Page page = render::layout(&doc, { .width = 80, .plain = true });
    defer page.free();
    test::eq(page.lines[0].text, "Welcome to mdv! See x².");
}

fn void testHeadingAfterTab() @test
{
    Document doc = parser::parse("#\tTitle");
    defer doc.free();
    test::eq(doc.blocks[0].kind, BlockKind.HEADING);
    test::eq(doc.blocks[0].level, 1);
}

fn void testScriptsRaiseTogether() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    MathBox mixed = tex::latex(&arena, "e^x x^{n - 1}");
    test::eq(mixed.height, 2);
    MathBox simple = tex::latex(&arena, "e^x x^2");
    test::eq(simple.height, 1);
}

fn void testVerticalRootKeepsRadicandAligned() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    MathBox root = tex::latex(&arena, "\\sqrt[3]{\\frac{a+b}{c}}");
    test::eq(root.height, 4);
    test::eq(root.rows[0], "  ┌───────");
    test::eq(root.rows[2], "3 │───────");
    test::eq(root.rows[3].starts_with(" ╲│"), true);
}

fn void testFlatRootOnOneRow() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    MathBox root = tex::latex(&arena, "\\sqrt{b^2 - 4ac} + \\sqrt[3]{x}");
    test::eq(root.height, 1);
    test::eq(root.rows[0], "√(b² - 4ac) + ³√x");
}

fn void testBigOperatorsTakeThreeRows() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    MathBox sum = tex::latex(&arena, "\\sum_{n=0}^{\\infty} a");
    test::eq(sum.height, 3);
    test::eq(sum.rows[1].contains("∑"), true);
    MathBox integral = tex::latex(&arena, "\\oint_C f");
    test::eq(integral.height, 2);
    test::eq(integral.rows[0].contains("∮"), true);
}

fn void testInlineLimitsBracketWhenNeeded() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    test::eq(tex::unicode(&arena, "\\sum_{i=1}^n i"), "∑ᵢ₌₁..ₙ i");
    test::eq(tex::unicode(&arena, "\\int_{-\\infty}^{\\infty} e^{-x^2} dx"), "∫(-∞..∞) e^(-x²) dx");
    test::eq(tex::unicode(&arena, "\\lim_{x \\to 0} f"), "lim(x→0) f");
}

fn void testLatexCoverage() @test
{
    ast::Arena arena;
    arena.init(16384);
    defer arena.free();
    test::eq(tex::unicode(&arena, "\\not\\in \\binom{n}{k} \\big( x \\big)"), "∉ C(n,k) ( x )");
    test::eq(tex::unicode(&arena, "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"), "(a b; c d)");
    MathBox sum = tex::latex(&arena, "\\sum\\limits_{i}^{n} \\lvert x \\rvert \\therefore");
    test::eq(sum.height, 3);
    test::eq(sum.rows[1], " ∑ |x| ∴ ");
    MathBox over = tex::latex(&arena, "{a \\over b}");
    test::eq(over.height, 3);
}

const String[] PIECES = {
    "\n", "\n\n", "```", "```math\n", "$$", "# ", "> ", "- ", "1. ", "- [ ] ", "| a | b |\n| --- | --- |\n", "===", "---",
    "    ", "x", " ", "\\", "[^1]: n", "> [!NOTE]\n", "<!--", "-->", "*", "[x]: http://a", "\\begin{aligned}", "\\end{aligned}",
};

fn usz boundary(String s, usz at)
{
    while (at < s.len && (s[at] & 0xC0) == 0x80) at++;
    return at;
}

fn void testIncrementalMatchesFull() @test
{
    String[] files = { "test/golden/sample.md", "test/golden/markdown.md", "test/golden/math.md", "test/golden/latex.md", "test/golden/text.md", "README.md" };
    uint seed = 7;
    foreach (name : files)
    {
        String base = (String)io::file::load(mem, name)!!;
        defer free(base);
        DString text;
        text.init(mem, base.len + 1024);
        defer text.free();
        text.append(base);
        render::Live live;
        live.init();
        defer live.free();
        live.update(text.str_view(), 80);
        for (int step = 0; step < 100; step++)
        {
            seed = seed * 1103515245 + 12345;
            String now = text.str_view();
            usz at = boundary(now, (usz)(seed >> 8) % (usz)(now.len + 1));
            DString next;
            next.init(mem, now.len + 64);
            defer next.free();
            next.append(now[:at]);
            if ((seed >> 4) % 3 == 0)
            {
                usz end = boundary(now, min((usz)now.len, at + 1 + (usz)((seed >> 12) % 24)));
                next.append(now[end..]);
            }
            else
            {
                next.append(PIECES[(usz)(seed >> 16) % (usz)PIECES.len]);
                next.append(now[at..]);
            }
            text.clear();
            text.append(next.str_view());
            live.update(text.str_view(), 80);
            Document doc = parser::parse(text.str_view());
            defer doc.free();
            render::Page page = render::layout(&doc, { .width = 80 });
            defer page.free();
            test::eq(live.doc.blocks.len, doc.blocks.len);
            foreach (i, b : doc.blocks)
            {
                test::eq(live.doc.blocks[i].kind, b.kind);
                test::eq(live.doc.blocks[i].start, b.start);
                test::eq(live.doc.blocks[i].end, b.end);
            }
            test::eq(live.page.lines.len, page.lines.len);
            test::eq(live.page.anchors.len, page.anchors.len);
            foreach (i, a : page.anchors) test::eq(live.page.anchors[i], a);
            foreach (i, line : page.lines)
            {
                test::eq(live.page.lines[i].text, line.text);
                test::eq(live.page.lines[i].src, line.src);
                test::eq(live.page.lines[i].block, line.block);
            }
        }
    }
}

fn void testEnvironmentSkipsStrayBrace() @test
{
    ast::Arena arena;
    arena.init();
    defer arena.free();
    MathBox box = tex::latex(&arena, "\\begin{aligned} a } b \\end{aligned}");
    test::eq(box.height, 1);
}

fn void testPaddedInlineMath() @test
{
    Arena arena;
    arena.init(4096);
    defer arena.free();
    Span[] padded = parser::spans(&arena, "a $ 2_3 $ b $$ x^2 $$ c $ y $");
    test::eq(padded[1].text, "2₃");
    test::eq((int)padded[3].kind, (int)SpanKind.MATH_DISPLAY);
    test::eq(padded[5].text, "y");
    Span[] money = parser::spans(&arena, "costs $ 5 and $ 10 total");
    test::eq((int)money.len, 1);
}

fn void testSymbolSheet() @test
{
    ast::Arena arena;
    arena.init();
    defer arena.free();
    test::eq(tex::latex(&arena, "\\left\\{ x \\right\\} \\left\\| y \\right\\| \\left\\lfloor z \\right\\rfloor").rows[0], "{ x } ‖ y ‖ ⌊ z ⌋");
    test::eq(tex::latex(&arena, "a \\mbox{~and~} b").rows[0], "a  and  b");
    test::eq(tex::latex(&arena, "\\sin\\theta").rows[0], "sin θ");
    test::eq(tex::latex(&arena, "\\deg p = 90^\\circ").rows[0], "deg p = 90°");
    test::eq(tex::unicode(&arena, "45^{\\circ} f \\circ g"), "45° f ∘ g");
    test::eq(tex::unicode(&arena, "\\mathbf{v} \\mathbb{R^n} \\Bumpeq \\twoheadrightarrow \\biguplus \\Vec{a}"), "𝐯 ℝⁿ ≎ ↠ ⨄ a⃗");
}
