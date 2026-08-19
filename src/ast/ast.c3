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
