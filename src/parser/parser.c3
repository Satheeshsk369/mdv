module parser;

import std::core::mem;
import ast;
import strutils;

struct BlockList {
    Block[] items;
    usz count;
    usz capacity;
}

fn void BlockList.init(BlockList* list, usz initial_cap = 64)
{
    list.items = mem::alloc_array(Block, (sz)initial_cap);
    list.count = 0;
    list.capacity = initial_cap;
}

fn void BlockList.push(BlockList* list, Block block)
{
    if (list.count >= list.capacity)
    {
        usz new_cap = list.capacity * 2;
        Block[] new_items = mem::alloc_array(Block, (sz)new_cap);
        for (usz i = 0; i < list.count; i++)
        {
            new_items[i] = list.items[i];
        }
        mem::free(list.items);
        list.items = new_items;
        list.capacity = new_cap;
    }
    list.items[list.count++] = block;
}

fn Block[] BlockList.to_arena_slice(BlockList* list, ast::Arena* arena)
{
    if (list.count == 0) return {};
    Block* buf = (Block*)arena.alloc(list.count * Block::size);
    for (usz i = 0; i < list.count; i++)
    {
        buf[i] = list.items[i];
    }
    return buf[:list.count];
}

fn void BlockList.free(BlockList* list)
{
    if (list.items.ptr != null)
    {
        mem::free(list.items);
        list.items = {};
        list.count = 0;
        list.capacity = 0;
    }
}

struct LineList {
    String[] items;
    usz count;
    usz capacity;
}

fn void LineList.init(LineList* list, usz initial_cap = 64)
{
    list.items = mem::alloc_array(String, (sz)initial_cap);
    list.count = 0;
    list.capacity = initial_cap;
}

fn void LineList.push(LineList* list, String line)
{
    if (list.count >= list.capacity)
    {
        usz new_cap = list.capacity * 2;
        String[] new_items = mem::alloc_array(String, (sz)new_cap);
        for (usz i = 0; i < list.count; i++)
        {
            new_items[i] = list.items[i];
        }
        mem::free(list.items);
        list.items = new_items;
        list.capacity = new_cap;
    }
    list.items[list.count++] = line;
}

fn String[] LineList.to_arena_slice(LineList* list, ast::Arena* arena)
{
    if (list.count == 0) return {};
    String* buf = (String*)arena.alloc(list.count * String::size);
    for (usz i = 0; i < list.count; i++)
    {
        buf[i] = list.items[i];
    }
    return buf[:list.count];
}

fn void LineList.free(LineList* list)
{
    if (list.items.ptr != null)
    {
        mem::free(list.items);
        list.items = {};
        list.count = 0;
        list.capacity = 0;
    }
}

fn bool is_thematic_break(String line)
{
    String trimmed = strutils::string_trim(line);
    if (trimmed.len < 3) return false;

    usz dashes = 0;
    usz stars = 0;
    usz underscores = 0;

    for (usz i = 0; i < (usz)trimmed.len; i++)
    {
        char c = trimmed[i];
        if (c == '-')
        {
            dashes++;
        }
        else if (c == '*')
        {
            stars++;
        }
        else if (c == '_')
        {
            underscores++;
        }
        else if (c != ' ' && c != '\t')
        {
            return false;
        }
    }

    return dashes >= 3 || stars >= 3 || underscores >= 3;
}

fn bool is_table_sep_row(String line)
{
    String trimmed = strutils::string_trim(line);
    if (trimmed.len < 3) return false;
    bool has_dash = false;

    for (usz i = 0; i < (usz)trimmed.len; i++)
    {
        char c = trimmed[i];
        if (c == '-')
        {
            has_dash = true;
        }
        else if (c != '|' && c != ':' && c != ' ' && c != '\t')
        {
            return false;
        }
    }
    return has_dash;
}

fn Span[][] parse_table_row_cells(ast::Arena* arena, String line, usz* out_col_count)
{
    String trimmed = strutils::string_trim(line);
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    const usz MAX_TEMP_COLS = 64;
    Span[][MAX_TEMP_COLS] temp_cols;
    usz col_count = 0;

    while (i < len && col_count < MAX_TEMP_COLS)
    {
        usz start = i;
        while (i < len && trimmed[i] != '|') i++;
        usz end = i;

        String raw_cell = strutils::string_trim(trimmed[start:end]);
        Span[] parsed = parser::parse_inline(arena, raw_cell);
        temp_cols[col_count++] = parsed;

        if (i < len && trimmed[i] == '|') i++;
    }

    *out_col_count = col_count;
    if (col_count > 0)
    {
        Span[]* slice_buf = (Span[]*)arena.alloc(col_count * Span[]::size);
        for (usz c = 0; c < col_count; c++)
        {
            slice_buf[c] = temp_cols[c];
        }
        return slice_buf[:col_count];
    }
    return {};
}

fn ast::Alignment[] parse_table_alignments(ast::Arena* arena, String sep_line, usz expected_cols)
{
    String trimmed = strutils::string_trim(sep_line);
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    const usz MAX_TEMP_COLS = 64;
    ast::Alignment[MAX_TEMP_COLS] temp_align;
    usz count = 0;

    while (i < len && count < MAX_TEMP_COLS)
    {
        usz start = i;
        while (i < len && trimmed[i] != '|') i++;
        usz end = i;

        String spec = strutils::string_trim(trimmed[start:end]);
        if (spec.len > 0)
        {
            bool left = (spec[0] == ':');
            bool right = (spec[spec.len - 1] == ':');
            if (left && right)
            {
                temp_align[count++] = ast::Alignment.CENTER;
            }
            else if (right)
            {
                temp_align[count++] = ast::Alignment.RIGHT;
            }
            else
            {
                temp_align[count++] = ast::Alignment.LEFT;
            }
        }

        if (i < len && trimmed[i] == '|') i++;
    }

    usz final_count = (count > expected_cols) ? count : expected_cols;
    if (final_count == 0) final_count = 1;

    ast::Alignment* buf = (ast::Alignment*)arena.alloc(final_count * ast::Alignment::size);
    for (usz c = 0; c < final_count; c++)
    {
        buf[c] = (c < count) ? temp_align[c] : ast::Alignment.LEFT;
    }
    return buf[:final_count];
}

fn Document parse_document(String content)
{
    Document doc;
    doc.init();

    if (content.len == 0) return doc;

    LineList raw_lines;
    raw_lines.init(128);
    defer raw_lines.free();

    usz cursor = 0;
    usz total_len = (usz)content.len;

    while (cursor < total_len)
    {
        usz line_start = cursor;
        while (cursor < total_len && content[cursor] != '\n') cursor++;
        usz line_end = cursor;

        if (line_end > line_start && content[line_end - 1] == '\r')
        {
            line_end--;
        }

        raw_lines.push(content[line_start:line_end]);
        if (cursor < total_len && content[cursor] == '\n') cursor++;
    }

    BlockList block_list;
    block_list.init(64);
    defer block_list.free();

    usz line_idx = 0;
    usz line_count = raw_lines.count;

    while (line_idx < line_count)
    {
        String line = raw_lines.items[line_idx];
        String trimmed = strutils::string_trim(line);
        int src_start = (int)line_idx;

        // 1. Blank Line
        if (trimmed.len == 0)
        {
            Block b;
            b.kind = ast::BlockKind.BLANK;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 2. Fenced Code Block: ``` or ~~~
        if (strutils::string_starts_with(trimmed, "```") || strutils::string_starts_with(trimmed, "~~~"))
        {
            String fence = trimmed[0:3];
            String lang = strutils::string_trim(trimmed[3:trimmed.len]);

            LineList code_lines;
            code_lines.init(16);
            defer code_lines.free();

            line_idx++;
            while (line_idx < line_count)
            {
                String cur_line = raw_lines.items[line_idx];
                String cur_trimmed = strutils::string_trim(cur_line);
                if (strutils::string_starts_with(cur_trimmed, fence))
                {
                    break;
                }
                code_lines.push(doc.arena.dup_string(cur_line));
                line_idx++;
            }

            Block b;
            b.kind = ast::BlockKind.CODE_BLOCK;
            b.src_line_start = src_start;
            b.src_line_end = (int)line_idx;
            b.code.language = doc.arena.dup_string(lang);
            b.code.lines = code_lines.to_arena_slice(&doc.arena);
            block_list.push(b);

            line_idx++;
            continue;
        }

        // 3. Table: starts with | or contains |
        if (strutils::string_starts_with(trimmed, "|") && line_idx + 1 < line_count && is_table_sep_row(raw_lines.items[line_idx + 1]))
        {
            usz header_cols = 0;
            Span[][] header_row = parse_table_row_cells(&doc.arena, line, &header_cols);

            String sep_line = raw_lines.items[line_idx + 1];
            ast::Alignment[] alignments = parse_table_alignments(&doc.arena, sep_line, header_cols);

            const usz MAX_TABLE_ROWS = 256;
            Span[][][MAX_TABLE_ROWS] body_rows;
            usz body_row_count = 0;

            line_idx += 2;

            while (line_idx < line_count)
            {
                String row_line = raw_lines.items[line_idx];
                String row_trimmed = strutils::string_trim(row_line);
                if (!strutils::string_starts_with(row_trimmed, "|") || row_trimmed.len == 0)
                {
                    break;
                }

                usz rcols = 0;
                Span[][] cell_row = parse_table_row_cells(&doc.arena, row_line, &rcols);
                if (body_row_count < MAX_TABLE_ROWS)
                {
                    body_rows[body_row_count++] = cell_row;
                }
                line_idx++;
            }

            Span[][]* rows_buf = (Span[][]*)doc.arena.alloc(body_row_count * Span[][]::size);
            for (usz r = 0; r < body_row_count; r++)
            {
                rows_buf[r] = body_rows[r];
            }

            Block b;
            b.kind = ast::BlockKind.TABLE;
            b.src_line_start = src_start;
            b.src_line_end = (int)(line_idx - 1);
            b.table.col_count = (int)header_cols;
            b.table.alignments = alignments;
            b.table.headers = header_row;
            b.table.rows = rows_buf[:body_row_count];
            block_list.push(b);
            continue;
        }

        // 4. Thematic Break / Horizontal Rule (---, ***, ___)
        if (is_thematic_break(line))
        {
            Block b;
            b.kind = ast::BlockKind.THEMATIC_BREAK;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 5. Headings: # through ######
        if (strutils::string_starts_with(trimmed, "# ") || strutils::string_starts_with(trimmed, "## ") || strutils::string_starts_with(trimmed, "### ") || strutils::string_starts_with(trimmed, "#### ") || strutils::string_starts_with(trimmed, "##### ") || strutils::string_starts_with(trimmed, "###### "))
        {
            int level = 0;
            while ((usz)level < (usz)trimmed.len && trimmed[level] == '#') level++;
            usz text_offset = (usz)(level + 1);
            String heading_text = strutils::string_trim(trimmed[text_offset:trimmed.len]);

            Block b;
            b.kind = ast::BlockKind.HEADING;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.heading.level = level;
            b.heading.spans = parser::parse_inline(&doc.arena, heading_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 6. Callouts / Admonitions: > [!NOTE], > [!TIP], > [!WARNING], > [!IMPORTANT], > [!CAUTION]
        if (strutils::string_starts_with(trimmed, "> [!"))
        {
            ast::CalloutKind kind = ast::CalloutKind.NOTE;
            String callout_title = "NOTE";

            if (strutils::string_starts_with(trimmed, "> [!NOTE]") || strutils::string_starts_with(trimmed, "> [!INFO]"))
            {
                kind = ast::CalloutKind.NOTE;
                callout_title = "NOTE";
            }
            else if (strutils::string_starts_with(trimmed, "> [!TIP]") || strutils::string_starts_with(trimmed, "> [!SUCCESS]"))
            {
                kind = ast::CalloutKind.TIP;
                callout_title = "TIP";
            }
            else if (strutils::string_starts_with(trimmed, "> [!WARNING]"))
            {
                kind = ast::CalloutKind.WARNING;
                callout_title = "WARNING";
            }
            else if (strutils::string_starts_with(trimmed, "> [!IMPORTANT]"))
            {
                kind = ast::CalloutKind.IMPORTANT;
                callout_title = "IMPORTANT";
            }
            else if (strutils::string_starts_with(trimmed, "> [!DANGER]") || strutils::string_starts_with(trimmed, "> [!CAUTION]") || strutils::string_starts_with(trimmed, "> [!ERROR]"))
            {
                kind = ast::CalloutKind.CAUTION;
                callout_title = "CAUTION";
            }

            Block b;
            b.kind = ast::BlockKind.CALLOUT;
            b.src_line_start = src_start;
            b.callout.kind = kind;
            b.callout.title = doc.arena.dup_string(callout_title);

            line_idx++;
            if (line_idx < line_count && strutils::string_starts_with(strutils::string_trim(raw_lines.items[line_idx]), ">"))
            {
                String q_line = strutils::string_trim(raw_lines.items[line_idx]);
                String body = (q_line.len > 1 && q_line[1] == ' ') ? q_line[2:q_line.len] : q_line[1:q_line.len];
                b.callout.spans = parser::parse_inline(&doc.arena, body);
                b.src_line_end = (int)line_idx;
                line_idx++;
            }
            else
            {
                b.callout.spans = {};
                b.src_line_end = src_start;
            }

            block_list.push(b);
            continue;
        }

        // 7. Blockquote: > ...
        if (strutils::string_starts_with(trimmed, "> ") || strutils::string_eq(trimmed, ">"))
        {
            String quote_text = (trimmed.len > 2) ? trimmed[2:trimmed.len] : "";
            Block b;
            b.kind = ast::BlockKind.BLOCKQUOTE;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.blockquote.spans = parser::parse_inline(&doc.arena, quote_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 8. Task lists / Checkboxes (- [ ] or - [x])
        usz indent = 0;
        while (indent < (usz)line.len && line[indent] == ' ') indent++;

        if (indent + 5 < (usz)line.len)
        {
            String sub = line[indent:line.len];
            if (strutils::string_starts_with(sub, "- [ ] ") || strutils::string_starts_with(sub, "* [ ] "))
            {
                String task_text = sub[6:sub.len];
                Block b;
                b.kind = ast::BlockKind.LIST_ITEM;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.list_item.kind = ast::ListKind.TASK_UNCHECKED;
                b.list_item.indent_level = (int)indent;
                b.list_item.spans = parser::parse_inline(&doc.arena, task_text);
                block_list.push(b);
                line_idx++;
                continue;
            }
            if (strutils::string_starts_with(sub, "- [x] ") || strutils::string_starts_with(sub, "- [X] ") || strutils::string_starts_with(sub, "* [x] ") || strutils::string_starts_with(sub, "* [X] "))
            {
                String task_text = sub[6:sub.len];
                Block b;
                b.kind = ast::BlockKind.LIST_ITEM;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.list_item.kind = ast::ListKind.TASK_CHECKED;
                b.list_item.indent_level = (int)indent;
                b.list_item.spans = parser::parse_inline(&doc.arena, task_text);
                block_list.push(b);
                line_idx++;
                continue;
            }
        }

        // 9. Bullet / Numbered Lists (* , - , + , 1. )
        if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ')
        {
            String item_text = line[indent + 2:line.len];
            Block b;
            b.kind = ast::BlockKind.LIST_ITEM;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.list_item.kind = ast::ListKind.BULLET;
            b.list_item.indent_level = (int)indent;
            b.list_item.spans = parser::parse_inline(&doc.arena, item_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 10. Paragraph
        Block b;
        b.kind = ast::BlockKind.PARAGRAPH;
        b.src_line_start = src_start;
        b.src_line_end = src_start;
        b.paragraph.spans = parser::parse_inline(&doc.arena, line);
        block_list.push(b);
        line_idx++;
    }

    doc.blocks = block_list.to_arena_slice(&doc.arena);
    return doc;
}
