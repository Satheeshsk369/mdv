module ast;

enum SpanKind {
    TEXT,
    BOLD,
    ITALIC,
    STRIKETHROUGH,
    CODE_INLINE,
    MATH_INLINE,
    MATH_DISPLAY,
    LINK,
    FOOTNOTE_REF,
    IMAGE
}

struct Span {
    SpanKind kind;
    String text;
    String url;
    Span[] children;
}

enum BlockKind {
    FRONTMATTER,
    HEADING,
    PARAGRAPH,
    CODE_BLOCK,
    BLOCKQUOTE,
    CALLOUT,
    LIST_ITEM,
    TABLE,
    THEMATIC_BREAK,
    MATH_BLOCK,
    FOOTNOTE_DEF,
    IMAGE_BLOCK,
    BLANK
}

struct ImageBlock {
    String alt;
    String url;
}

struct FrontmatterEntry {
    String key;
    String value;
}

struct FrontmatterBlock {
    FrontmatterEntry[] entries;
}

struct FootnoteDefBlock {
    String label;
    Span[] spans;
}

enum CalloutKind {
    NOTE,
    TIP,
    WARNING,
    IMPORTANT,
    CAUTION
}

enum ListKind {
    BULLET,
    ORDERED,
    TASK_UNCHECKED,
    TASK_CHECKED
}

enum Alignment {
    LEFT,
    CENTER,
    RIGHT
}

struct HeadingBlock {
    int level;
    Span[] spans;
}

struct ParagraphBlock {
    Span[] spans;
}

struct CodeBlock {
    String language;
    String[] lines;
}

struct BlockquoteBlock {
    Span[] spans;
}

struct CalloutBlock {
    CalloutKind kind;
    String title;
    Span[] spans;
}

struct ListItemBlock {
    ListKind kind;
    int indentLevel;
    int orderNumber;
    Span[] spans;
}

struct TableBlock {
    int colCount;
    Alignment[] alignments;
    Span[][] headers;
    Span[][][] rows;
}

struct MathBlock {
    String latex;
}

struct Block {
    BlockKind kind;
    int srcLineStart;
    int srcLineEnd;
    union
    {
        FrontmatterBlock frontmatter;
        HeadingBlock heading;
        ParagraphBlock paragraph;
        CodeBlock code;
        BlockquoteBlock blockquote;
        CalloutBlock callout;
        ListItemBlock listItem;
        TableBlock table;
        MathBlock mathBlock;
        FootnoteDefBlock footnoteDef;
        ImageBlock imageBlock;
    }
}

struct Document {
    Block[] blocks;
    Arena arena;
}

fn void Document.init(Document* doc)
{
    doc.blocks = {};
    doc.arena.init(65536);
}

fn void Document.free(Document* doc)
{
    doc.arena.free();
    doc.blocks = {};
}

struct VisualLine {
    String text;
    int srcLine;
    int displayWidth;
}

struct VisualDocument {
    VisualLine[] lines;
    Arena arena;
}

fn void VisualDocument.init(VisualDocument* doc)
{
    doc.lines = {};
    doc.arena.init(65536);
}

fn int VisualDocument.count(VisualDocument* doc)
{
    return (int)doc.lines.len;
}

fn int VisualDocument.visual(VisualDocument* doc, int srcTarget)
{
    if (srcTarget < 0) return 0;
    int total = (int)doc.lines.len;
    for (int i = 0; i < total; i++)
    {
        if (doc.lines[i].srcLine >= srcTarget)
        {
            return i;
        }
    }
    if (total > 0) return total - 1;
    return 0;
}

fn void VisualDocument.free(VisualDocument* doc)
{
    doc.arena.free();
    doc.lines = {};
}

struct RenderConfig {
    int width;
    bool plain;
    bool noWrap;
}
