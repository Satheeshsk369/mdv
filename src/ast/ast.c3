module ast;

enum SpanKind
{
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

struct Span
{
    SpanKind kind;
    String text;
    String url;
    Span[] children;
}

enum BlockKind
{
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
    BLANK
}

enum CalloutKind
{
    NOTE,
    TIP,
    WARNING,
    IMPORTANT,
    CAUTION
}

enum ListKind
{
    BULLET,
    ORDERED,
    TASK_UNCHECKED,
    TASK_CHECKED
}

enum Alignment
{
    LEFT,
    CENTER,
    RIGHT
}

struct Entry
{
    String key;
    String value;
}

struct Code
{
    String language;
    String[] lines;
}

struct Callout
{
    CalloutKind kind;
    String title;
}

struct Item
{
    ListKind kind;
    int indent;
    int number;
}

struct Table
{
    int columns;
    Alignment[] aligns;
    Span[][] headers;
    Span[][][] rows;
}

struct Block
{
    BlockKind kind;
    int start;
    int end;
    Span[] spans;
    Block[] children;
    union
    {
        int level;
        String label;
        String latex;
        Entry[] entries;
        Code code;
        Callout callout;
        Item item;
        Table table;
    }
}

fn Block make(BlockKind kind, int start, int end, Span[] spans = {})
{
    return { .kind = kind, .start = start, .end = end, .spans = spans };
}

struct Document
{
    Block[] blocks;
    Arena arena;
}

fn void Document.free(&self)
{
    self.arena.free();
    self.blocks = {};
}
