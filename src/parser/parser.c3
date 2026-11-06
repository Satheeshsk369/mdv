module parser;

import std::core::mem;
import std::collections::list;
import logic;
import text;

fn bool is_thematic_break(String line)
{
    String trimmed = line.trim();
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
    String trimmed = line.trim();
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

fn bool is_ordered_list(String line, usz indent, int* out_num, usz* out_prefix_len)
{
    usz p = indent;
    usz len = (usz)line.len;
    if (p >= len || line[p] < '0' || line[p] > '9') return false;

    int num = 0;
    while (p < len && line[p] >= '0' && line[p] <= '9')
    {
        num = num * 10 + (int)(line[p] - '0');
        p++;
    }

    if (p < len && (line[p] == '.' || line[p] == ')') && p + 1 < len && (line[p + 1] == ' ' || line[p + 1] == '\t'))
    {
        *out_num = num;
        *out_prefix_len = p + 2;
        return true;
    }
    return false;
}

fn bool is_heading_prefix(String s)
{
    if (s.len < 2 || s[0] != '#') return false;
    usz h = 0;
    while (h < (usz)s.len && s[h] == '#') h++;
    return h >= 1 && h <= 6 && h < (usz)s.len && (s[h] == ' ' || s[h] == '\t');
}

fn bool is_block_start(String line)
{
    String trimmed = line.trim();
    if (trimmed.len == 0) return true;
    if (is_thematic_break(line)) return true;
    if (is_heading_prefix(trimmed)) return true;
    if (trimmed.starts_with("```") || trimmed.starts_with("~~~")) return true;
    if (trimmed.starts_with("$$") || trimmed.starts_with("\\begin{")) return true;
    if (trimmed.starts_with(">")) return true;

    if (trimmed.starts_with("[^"))
    {
        usz col_pos = 2;
        while (col_pos + 1 < (usz)trimmed.len && !(trimmed[col_pos] == ']' && trimmed[col_pos + 1] == ':')) col_pos++;
        if (col_pos + 1 < (usz)trimmed.len) return true;
    }

    usz indent = 0;
    while (indent < (usz)line.len && line[indent] == ' ') indent++;
    if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ') return true;

    int ord_num = 0;
    usz ord_len = 0;
    if (is_ordered_list(line, indent, &ord_num, &ord_len)) return true;

    return false;
}

fn Block[] list_to_arena_blocks(logic::Arena* arena, List{Block}* l)
{
    if (l.size == 0) return {};
    Block* buf = (Block*)arena.alloc((usz)l.size * Block::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn String[] list_to_arena_strings(logic::Arena* arena, List{String}* l)
{
    if (l.size == 0) return {};
    String* buf = (String*)arena.alloc((usz)l.size * String::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn Span[][] parse_table_row_cells(logic::Arena* arena, String line, usz* out_col_count)
{
    String trimmed = line.trim();
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    List{Span[]} cell_list;
    cell_list.init(mem, 8);
    defer cell_list.free();

    while (i < len)
    {
        usz start = i;
        while (i < len && trimmed[i] != '|') i++;
        usz end = i;

        String raw_cell = trimmed[start : end - start].trim();
        Span[] parsed = parser::parse_inline(arena, raw_cell);
        cell_list.push(parsed);

        if (i < len && trimmed[i] == '|') i++;
    }

    *out_col_count = (usz)cell_list.size;
    if (cell_list.size == 0) return {};

    Span[]* buf = (Span[]*)arena.alloc((usz)cell_list.size * Span[]::size);
    for (sz c = 0; c < cell_list.size; c++)
    {
        buf[c] = cell_list.entries[c];
    }
    return buf[:(usz)cell_list.size];
}

fn Alignment[] parse_table_alignments(logic::Arena* arena, String sep_line, usz expected_cols)
{
    String trimmed = sep_line.trim();
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    List{Alignment} align_list;
    align_list.init(mem, 8);
    defer align_list.free();

    while (i < len)
    {
        usz start = i;
        while (i < len && trimmed[i] != '|') i++;
        usz end = i;

        String spec = trimmed[start : end - start].trim();
        if (spec.len > 0)
        {
            bool left = (spec[0] == ':');
            bool right = (spec[spec.len - 1] == ':');
            if (left && right)
            {
                align_list.push(Alignment.CENTER);
            }
            else if (right)
            {
                align_list.push(Alignment.RIGHT);
            }
            else
            {
                align_list.push(Alignment.LEFT);
            }
        }

        if (i < len && trimmed[i] == '|') i++;
    }

    while ((usz)align_list.size < expected_cols)
    {
        align_list.push(Alignment.LEFT);
    }

    if (align_list.size == 0) return {};

    Alignment* buf = (Alignment*)arena.alloc((usz)align_list.size * Alignment::size);
    for (sz c = 0; c < align_list.size; c++)
    {
        buf[c] = align_list.entries[c];
    }
    return buf[:(usz)align_list.size];
}

fn Document parse_document(String content)
{
    Document doc;
    doc.init();

    if (content.len == 0) return doc;

    List{String} raw_lines;
    raw_lines.init(mem, 128);
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

        raw_lines.push(content[line_start : line_end - line_start]);
        if (cursor < total_len && content[cursor] == '\n') cursor++;
    }

    List{Block} block_list;
    block_list.init(mem, 64);
    defer block_list.free();

    usz line_idx = 0;
    usz line_count = (usz)raw_lines.size;

    while (line_idx < line_count)
    {
        String line = raw_lines.entries[line_idx];
        String trimmed = line.trim();
        int src_start = (int)line_idx;

        // 0. YAML Frontmatter (at start of document)
        if (line_idx == 0 && trimmed == "---")
        {
            usz fm_start = line_idx;
            line_idx++;

            List{FrontmatterEntry} entries;
            entries.init(mem, 16);
            defer entries.free();

            while (line_idx < line_count)
            {
                String cur = raw_lines.entries[line_idx];
                String cur_t = cur.trim();
                if (cur_t == "---" || cur_t == "...")
                {
                    break;
                }

                // Find ':'
                usz c_pos = 0;
                while (c_pos < (usz)cur_t.len && cur_t[c_pos] != ':') c_pos++;

                if (c_pos < (usz)cur_t.len)
                {
                    String k = cur_t[0:c_pos].trim();
                    String v = cur_t[c_pos + 1..].trim();
                    // Strip optional quotes
                    if (v.len >= 2 && ((v[0] == '"' && v[v.len - 1] == '"') || (v[0] == '\'' && v[v.len - 1] == '\'')))
                    {
                        v = v[1 : (usz)v.len - 2];
                    }
                    FrontmatterEntry entry;
                    entry.key = doc.arena.dup_string(k);
                    entry.value = doc.arena.dup_string(v);
                    entries.push(entry);
                }
                line_idx++;
            }

            if (entries.size > 0)
            {
                FrontmatterEntry* e_buf = (FrontmatterEntry*)doc.arena.alloc((usz)entries.size * FrontmatterEntry::size);
                for (sz e = 0; e < entries.size; e++) e_buf[e] = entries.entries[e];

                Block b;
                b.kind = BlockKind.FRONTMATTER;
                b.src_line_start = (int)fm_start;
                b.src_line_end = (int)line_idx;
                b.frontmatter.entries = e_buf[:(usz)entries.size];
                block_list.push(b);
            }

            line_idx++;
            continue;
        }

        // 1. Blank Line
        if (trimmed.len == 0)
        {
            Block b;
            b.kind = BlockKind.BLANK;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 2. Fenced Code Block: ```... or ~~~...
        if (trimmed.starts_with("```") || trimmed.starts_with("~~~"))
        {
            char fence_char = trimmed[0];
            usz fence_len = 0;
            while (fence_len < (usz)trimmed.len && trimmed[fence_len] == fence_char)
            {
                fence_len++;
            }

            String lang = trimmed[fence_len..].trim();

            List{String} code_lines;
            code_lines.init(mem, 16);
            defer code_lines.free();

            line_idx++;
            while (line_idx < line_count)
            {
                String cur_line = raw_lines.entries[line_idx];
                String cur_trimmed = cur_line.trim();

                bool is_closing_fence = false;
                if ((usz)cur_trimmed.len >= fence_len && cur_trimmed[0] == fence_char)
                {
                    usz close_len = 0;
                    while (close_len < (usz)cur_trimmed.len && cur_trimmed[close_len] == fence_char)
                    {
                        close_len++;
                    }
                    if (close_len >= fence_len)
                    {
                        String rest = cur_trimmed[close_len..].trim();
                        if (rest.len == 0)
                        {
                            is_closing_fence = true;
                        }
                    }
                }

                if (is_closing_fence)
                {
                    break;
                }

                code_lines.push(doc.arena.dup_string(cur_line));
                line_idx++;
            }

            Block b;
            b.kind = BlockKind.CODE_BLOCK;
            b.src_line_start = src_start;
            b.src_line_end = (int)line_idx;
            b.code.language = doc.arena.dup_string(lang);
            b.code.lines = list_to_arena_strings(&doc.arena, &code_lines);
            block_list.push(b);

            line_idx++;
            continue;
        }

        // 3. Display Math Block ($$ ... $$ or \begin{equation} ... \end{equation})
        if (trimmed.starts_with("$$") || trimmed.starts_with("\\begin{equation}") || trimmed.starts_with("\\begin{align}") || trimmed.starts_with("\\begin{gather}") || trimmed.starts_with("\\begin{aligned}"))
        {
            if (trimmed.starts_with("$$") && trimmed.len >= 4 && trimmed.ends_with("$$") && trimmed.len > 4)
            {
                String math_content = (trimmed[2 : (usz)trimmed.len - 4]).trim();
                Block b;
                b.kind = BlockKind.MATH_BLOCK;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.math_block.latex = doc.arena.dup_string(math_content);
                block_list.push(b);
                line_idx++;
                continue;
            }

            bool is_dollar = trimmed.starts_with("$$");
            String end_marker = is_dollar ? "$$" : "\\end{";

            List{String} math_lines;
            math_lines.init(mem, 16);
            defer math_lines.free();

            if (is_dollar && trimmed.len > 2)
            {
                math_lines.push(trimmed[2..]);
            }
            else if (!is_dollar)
            {
                math_lines.push(line);
            }

            line_idx++;
            while (line_idx < line_count)
            {
                String cur_line = raw_lines.entries[line_idx];
                String cur_trimmed = cur_line.trim();

                if (is_dollar)
                {
                    if (cur_trimmed.ends_with("$$") || cur_trimmed.starts_with("$$"))
                    {
                        if (cur_trimmed.len > 2 && !cur_trimmed.starts_with("$$"))
                        {
                            math_lines.push(cur_trimmed[0 : (usz)cur_trimmed.len - 2]);
                        }
                        break;
                    }
                }
                else
                {
                    if (cur_trimmed.starts_with(end_marker))
                    {
                        math_lines.push(cur_line);
                        break;
                    }
                }

                math_lines.push(cur_line);
                line_idx++;
            }

            DString mb;
            mb.init(mem, 512);
            defer mb.free();

            for (sz m = 0; m < math_lines.size; m++)
            {
                if (m > 0) mb.append_char(' ');
                mb.append_string(math_lines.entries[m]);
            }

            Block b;
            b.kind = BlockKind.MATH_BLOCK;
            b.src_line_start = src_start;
            b.src_line_end = (int)line_idx;
            b.math_block.latex = mb.to_arena_string(&doc.arena);
            block_list.push(b);

            line_idx++;
            continue;
        }

        // 4. Table: starts with | and next row is separator
        if (trimmed.starts_with("|") && line_idx + 1 < line_count && is_table_sep_row(raw_lines.entries[line_idx + 1]))
        {
            usz header_cols = 0;
            Span[][] header_row = parse_table_row_cells(&doc.arena, line, &header_cols);

            String sep_line = raw_lines.entries[line_idx + 1];
            Alignment[] alignments = parse_table_alignments(&doc.arena, sep_line, header_cols);

            List{Span[][]} body_rows;
            body_rows.init(mem, 32);
            defer body_rows.free();

            line_idx += 2;

            while (line_idx < line_count)
            {
                String row_line = raw_lines.entries[line_idx];
                String row_trimmed = row_line.trim();
                if (!row_trimmed.starts_with("|") || row_trimmed.len == 0)
                {
                    break;
                }

                usz rcols = 0;
                Span[][] cell_row = parse_table_row_cells(&doc.arena, row_line, &rcols);
                body_rows.push(cell_row);
                line_idx++;
            }

            Span[][]* rows_buf = (Span[][]*)doc.arena.alloc((usz)body_rows.size * Span[][]::size);
            for (sz r = 0; r < body_rows.size; r++)
            {
                rows_buf[r] = body_rows.entries[r];
            }

            Block b;
            b.kind = BlockKind.TABLE;
            b.src_line_start = src_start;
            b.src_line_end = (int)(line_idx - 1);
            b.table.col_count = (int)header_cols;
            b.table.alignments = alignments;
            b.table.headers = header_row;
            b.table.rows = rows_buf[:(usz)body_rows.size];
            block_list.push(b);
            continue;
        }

        // 5. Thematic Break / Horizontal Rule (---, ***, ___)
        if (is_thematic_break(line))
        {
            Block b;
            b.kind = BlockKind.THEMATIC_BREAK;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 6. Headings: # through ######
        if (trimmed.starts_with("# ") || trimmed.starts_with("## ") || trimmed.starts_with("### ") || trimmed.starts_with("#### ") || trimmed.starts_with("##### ") || trimmed.starts_with("###### "))
        {
            int level = 0;
            while ((usz)level < (usz)trimmed.len && trimmed[level] == '#') level++;
            usz text_offset = (usz)(level + 1);
            String heading_text = trimmed[text_offset..].trim();

            Block b;
            b.kind = BlockKind.HEADING;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.heading.level = level;
            b.heading.spans = parser::parse_inline(&doc.arena, heading_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 7. Callouts / Admonitions: > [!NOTE], > [!TIP], > [!WARNING], > [!IMPORTANT], > [!CAUTION] (full multiline support)
        if (trimmed.starts_with("> [!"))
        {
            CalloutKind kind = CalloutKind.NOTE;
            String callout_title = "NOTE";

            if (trimmed.starts_with("> [!NOTE]") || trimmed.starts_with("> [!INFO]"))
            {
                kind = CalloutKind.NOTE;
                callout_title = "NOTE";
            }
            else if (trimmed.starts_with("> [!TIP]") || trimmed.starts_with("> [!SUCCESS]"))
            {
                kind = CalloutKind.TIP;
                callout_title = "TIP";
            }
            else if (trimmed.starts_with("> [!WARNING]"))
            {
                kind = CalloutKind.WARNING;
                callout_title = "WARNING";
            }
            else if (trimmed.starts_with("> [!IMPORTANT]"))
            {
                kind = CalloutKind.IMPORTANT;
                callout_title = "IMPORTANT";
            }
            else if (trimmed.starts_with("> [!DANGER]") || trimmed.starts_with("> [!CAUTION]") || trimmed.starts_with("> [!ERROR]"))
            {
                kind = CalloutKind.CAUTION;
                callout_title = "CAUTION";
            }

            DString callout_body;
            callout_body.init(mem, 512);
            defer callout_body.free();

            line_idx++;
            int last_callout_line = src_start;

            while (line_idx < line_count)
            {
                String q_raw = raw_lines.entries[line_idx];
                String q_trim = q_raw.trim();
                if (!q_trim.starts_with(">"))
                {
                    break;
                }

                String q_text = q_trim[1..];
                if (q_text.len > 0 && q_text[0] == ' ') q_text = q_text[1..];

                if (callout_body.len() > 0) callout_body.append_char(' ');
                callout_body.append_string(q_text);

                last_callout_line = (int)line_idx;
                line_idx++;
            }

            Block b;
            b.kind = BlockKind.CALLOUT;
            b.src_line_start = src_start;
            b.src_line_end = last_callout_line;
            b.callout.kind = kind;
            b.callout.title = doc.arena.dup_string(callout_title);
            b.callout.spans = parser::parse_inline(&doc.arena, callout_body.str_view());
            block_list.push(b);
            continue;
        }

        // 8. Footnote Definitions: [^label]: ...
        if (trimmed.starts_with("[^"))
        {
            usz col_pos = 2;
            while (col_pos + 1 < (usz)trimmed.len && !(trimmed[col_pos] == ']' && trimmed[col_pos + 1] == ':'))
            {
                col_pos++;
            }

            if (col_pos + 1 < (usz)trimmed.len)
            {
                String fn_label = trimmed[2 : col_pos - 2];
                String fn_body = trimmed[col_pos + 2..].trim();

                Block b;
                b.kind = BlockKind.FOOTNOTE_DEF;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.footnote_def.label = doc.arena.dup_string(fn_label);
                b.footnote_def.spans = parser::parse_inline(&doc.arena, fn_body);
                block_list.push(b);
                line_idx++;
                continue;
            }
        }

        // 9. Blockquote: > ... (multiline support)
        if (trimmed.starts_with("> ") || trimmed == ">")
        {
            DString quote_body;
            quote_body.init(mem, 512);
            defer quote_body.free();

            int last_q_line = src_start;

            while (line_idx < line_count)
            {
                String q_raw = raw_lines.entries[line_idx];
                String q_trim = q_raw.trim();
                if (!q_trim.starts_with(">") || q_trim.starts_with("> [!"))
                {
                    break;
                }

                String q_text = q_trim[1..];
                if (q_text.len > 0 && q_text[0] == ' ') q_text = q_text[1..];

                if (quote_body.len() > 0) quote_body.append_char(' ');
                quote_body.append_string(q_text);

                last_q_line = (int)line_idx;
                line_idx++;
            }

            Block b;
            b.kind = BlockKind.BLOCKQUOTE;
            b.src_line_start = src_start;
            b.src_line_end = last_q_line;
            b.blockquote.spans = parser::parse_inline(&doc.arena, quote_body.str_view());
            block_list.push(b);
            continue;
        }

        // 10. Task lists / Checkboxes (- [ ] or - [x])
        usz indent = 0;
        while (indent < (usz)line.len && line[indent] == ' ') indent++;

        if (indent + 5 < (usz)line.len)
        {
            String sub = line[indent..];
            if (sub.starts_with("- [ ] ") || sub.starts_with("* [ ] "))
            {
                String task_text = sub[6..];
                Block b;
                b.kind = BlockKind.LIST_ITEM;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.list_item.kind = ListKind.TASK_UNCHECKED;
                b.list_item.indent_level = (int)indent;
                b.list_item.order_number = 0;
                b.list_item.spans = parser::parse_inline(&doc.arena, task_text);
                block_list.push(b);
                line_idx++;
                continue;
            }
            if (sub.starts_with("- [x] ") || sub.starts_with("- [X] ") || sub.starts_with("* [x] ") || sub.starts_with("* [X] "))
            {
                String task_text = sub[6..];
                Block b;
                b.kind = BlockKind.LIST_ITEM;
                b.src_line_start = src_start;
                b.src_line_end = src_start;
                b.list_item.kind = ListKind.TASK_CHECKED;
                b.list_item.indent_level = (int)indent;
                b.list_item.order_number = 0;
                b.list_item.spans = parser::parse_inline(&doc.arena, task_text);
                block_list.push(b);
                line_idx++;
                continue;
            }
        }

        // 11. Bullet Lists (* , - , + )
        if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ')
        {
            String item_text = line[indent + 2..];
            Block b;
            b.kind = BlockKind.LIST_ITEM;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.list_item.kind = ListKind.BULLET;
            b.list_item.indent_level = (int)indent;
            b.list_item.order_number = 0;
            b.list_item.spans = parser::parse_inline(&doc.arena, item_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 12. Ordered Lists (1. , 2. , 1) etc.)
        int ord_num = 0;
        usz ord_prefix_len = 0;
        if (is_ordered_list(line, indent, &ord_num, &ord_prefix_len))
        {
            String item_text = line[ord_prefix_len..];
            Block b;
            b.kind = BlockKind.LIST_ITEM;
            b.src_line_start = src_start;
            b.src_line_end = src_start;
            b.list_item.kind = ListKind.ORDERED;
            b.list_item.indent_level = (int)indent;
            b.list_item.order_number = ord_num;
            b.list_item.spans = parser::parse_inline(&doc.arena, item_text);
            block_list.push(b);
            line_idx++;
            continue;
        }

        // 13. Paragraph: group consecutive regular lines into a unified reflowable paragraph
        DString para_buf;
        para_buf.init(mem, 512);
        defer para_buf.free();

        int last_para_line = src_start;

        while (line_idx < line_count)
        {
            String cur_line = raw_lines.entries[line_idx];
            if (is_block_start(cur_line))
            {
                break;
            }

            String cur_t = cur_line.trim();
            if (cur_t.len == 0) break;

            if (para_buf.len() > 0)
            {
                para_buf.append_char(' ');
            }
            para_buf.append_string(cur_t);

            last_para_line = (int)line_idx;
            line_idx++;
        }

        Block b;
        b.kind = BlockKind.PARAGRAPH;
        b.src_line_start = src_start;
        b.src_line_end = last_para_line;
        b.paragraph.spans = parser::parse_inline(&doc.arena, para_buf.str_view());
        block_list.push(b);
    }

    doc.blocks = list_to_arena_blocks(&doc.arena, &block_list);
    return doc;
}
