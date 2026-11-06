module logic;

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
    int level;          // 1 - 6
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
    int indent_level;
    int order_number;
    Span[] spans;
}

struct TableBlock {
    int col_count;
    Alignment[] alignments;
    Span[][] headers;
    Span[][][] rows;
}

struct MathBlock {
    String latex;
}

struct Block {
    BlockKind kind;
    int src_line_start;
    int src_line_end;
    union
    {
        FrontmatterBlock frontmatter;
        HeadingBlock heading;
        ParagraphBlock paragraph;
        CodeBlock code;
        BlockquoteBlock blockquote;
        CalloutBlock callout;
        ListItemBlock list_item;
        TableBlock table;
        MathBlock math_block;
        FootnoteDefBlock footnote_def;
        ImageBlock image_block;
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
    int src_line;
    int display_width;
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

fn int VisualDocument.get_total_lines(VisualDocument* doc)
{
    return (int)doc.lines.len;
}

fn int VisualDocument.find_visual_line(VisualDocument* doc, int src_target)
{
    if (src_target < 0) return 0;
    int total = (int)doc.lines.len;
    for (int i = 0; i < total; i++)
    {
        if (doc.lines[i].src_line >= src_target)
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
    bool no_wrap;
}
