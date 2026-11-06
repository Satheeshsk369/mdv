module parser;

import std::core::mem;
import std::collections::list;
import ast;
import text;

fn bool thematic(String line)
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

fn bool separator(String line)
{
    String trimmed = line.trim();
    if (trimmed.len < 3) return false;
    bool hasDash = false;

    for (usz i = 0; i < (usz)trimmed.len; i++)
    {
        char c = trimmed[i];
        if (c == '-')
        {
            hasDash = true;
        }
        else if (c != '|' && c != ':' && c != ' ' && c != '\t')
        {
            return false;
        }
    }
    return hasDash;
}

fn bool ordered(String line, usz indent, int* outNum, usz* outPrefixLen)
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
        *outNum = num;
        *outPrefixLen = p + 2;
        return true;
    }
    return false;
}

fn bool headingPrefix(String s)
{
    if (s.len < 2 || s[0] != '#') return false;
    usz h = 0;
    while (h < (usz)s.len && s[h] == '#') h++;
    return h >= 1 && h <= 6 && h < (usz)s.len && (s[h] == ' ' || s[h] == '\t');
}

fn bool blockStart(String line)
{
    String trimmed = line.trim();
    if (trimmed.len == 0) return true;
    if (thematic(line)) return true;
    if (headingPrefix(trimmed)) return true;
    if (trimmed.starts_with("```") || trimmed.starts_with("~~~")) return true;
    if (trimmed.starts_with("$$") || trimmed.starts_with("\\begin{")) return true;
    if (trimmed.starts_with(">")) return true;

    if (trimmed.starts_with("[^"))
    {
        usz colPos = 2;
        while (colPos + 1 < (usz)trimmed.len && !(trimmed[colPos] == ']' && trimmed[colPos + 1] == ':')) colPos++;
        if (colPos + 1 < (usz)trimmed.len) return true;
    }

    usz indent = 0;
    while (indent < (usz)line.len && line[indent] == ' ') indent++;
    if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ') return true;

    int ordNum = 0;
    usz ordLen = 0;
    if (ordered(line, indent, &ordNum, &ordLen)) return true;

    return false;
}

fn Block[] keepBlocks(ast::Arena* arena, List{Block}* l)
{
    if (l.size == 0) return {};
    Block* buf = (Block*)arena.alloc((usz)l.size * Block::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn String[] keepStrings(ast::Arena* arena, List{String}* l)
{
    if (l.size == 0) return {};
    String* buf = (String*)arena.alloc((usz)l.size * String::size);
    for (sz i = 0; i < l.size; i++)
    {
        buf[i] = l.entries[i];
    }
    return buf[:(usz)l.size];
}

fn Span[][] cells(ast::Arena* arena, String line, usz* outColCount)
{
    String trimmed = line.trim();
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    List{Span[]} cellList;
    cellList.init(mem, 8);
    defer cellList.free();

    while (i < len)
    {
        usz start = i;
        while (i < len && trimmed[i] != '|') i++;
        usz end = i;

        String rawCell = trimmed[start : end - start].trim();
        Span[] parsed = parser::spans(arena, rawCell);
        cellList.push(parsed);

        if (i < len && trimmed[i] == '|') i++;
    }

    *outColCount = (usz)cellList.size;
    if (cellList.size == 0) return {};

    Span[]* buf = (Span[]*)arena.alloc((usz)cellList.size * Span[]::size);
    for (sz c = 0; c < cellList.size; c++)
    {
        buf[c] = cellList.entries[c];
    }
    return buf[:(usz)cellList.size];
}

fn Alignment[] alignments(ast::Arena* arena, String sepLine, usz expectedCols)
{
    String trimmed = sepLine.trim();
    usz len = (usz)trimmed.len;
    usz i = 0;
    if (i < len && trimmed[i] == '|') i++;

    List{Alignment} alignList;
    alignList.init(mem, 8);
    defer alignList.free();

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
                alignList.push(Alignment.CENTER);
            }
            else if (right)
            {
                alignList.push(Alignment.RIGHT);
            }
            else
            {
                alignList.push(Alignment.LEFT);
            }
        }

        if (i < len && trimmed[i] == '|') i++;
    }

    while ((usz)alignList.size < expectedCols)
    {
        alignList.push(Alignment.LEFT);
    }

    if (alignList.size == 0) return {};

    Alignment* buf = (Alignment*)arena.alloc((usz)alignList.size * Alignment::size);
    for (sz c = 0; c < alignList.size; c++)
    {
        buf[c] = alignList.entries[c];
    }
    return buf[:(usz)alignList.size];
}

fn Document parse(String content)
{
    Document doc;
    doc.init();

    if (content.len == 0) return doc;

    List{String} rawLines;
    rawLines.init(mem, 128);
    defer rawLines.free();

    usz cursor = 0;
    usz totalLen = (usz)content.len;

    while (cursor < totalLen)
    {
        usz lineStart = cursor;
        while (cursor < totalLen && content[cursor] != '\n') cursor++;
        usz lineEnd = cursor;

        if (lineEnd > lineStart && content[lineEnd - 1] == '\r')
        {
            lineEnd--;
        }

        rawLines.push(content[lineStart : lineEnd - lineStart]);
        if (cursor < totalLen && content[cursor] == '\n') cursor++;
    }

    List{Block} blockList;
    blockList.init(mem, 64);
    defer blockList.free();

    usz lineIdx = 0;
    usz lineCount = (usz)rawLines.size;

    while (lineIdx < lineCount)
    {
        String line = rawLines.entries[lineIdx];
        String trimmed = line.trim();
        int srcStart = (int)lineIdx;

        if (lineIdx == 0 && trimmed == "---")
        {
            usz fmStart = lineIdx;
            lineIdx++;

            List{FrontmatterEntry} entries;
            entries.init(mem, 16);
            defer entries.free();

            while (lineIdx < lineCount)
            {
                String cur = rawLines.entries[lineIdx];
                String curT = cur.trim();
                if (curT == "---" || curT == "...")
                {
                    break;
                }

                usz cPos = 0;
                while (cPos < (usz)curT.len && curT[cPos] != ':') cPos++;

                if (cPos < (usz)curT.len)
                {
                    String k = curT[0:cPos].trim();
                    String v = curT[cPos + 1..].trim();
                    if (v.len >= 2 && ((v[0] == '"' && v[v.len - 1] == '"') || (v[0] == '\'' && v[v.len - 1] == '\'')))
                    {
                        v = v[1 : (usz)v.len - 2];
                    }
                    FrontmatterEntry entry;
                    entry.key = doc.arena.copy(k);
                    entry.value = doc.arena.copy(v);
                    entries.push(entry);
                }
                lineIdx++;
            }

            if (entries.size > 0)
            {
                FrontmatterEntry* eBuf = (FrontmatterEntry*)doc.arena.alloc((usz)entries.size * FrontmatterEntry::size);
                for (sz e = 0; e < entries.size; e++) eBuf[e] = entries.entries[e];

                Block b;
                b.kind = BlockKind.FRONTMATTER;
                b.srcLineStart = (int)fmStart;
                b.srcLineEnd = (int)lineIdx;
                b.frontmatter.entries = eBuf[:(usz)entries.size];
                blockList.push(b);
            }

            lineIdx++;
            continue;
        }

        if (trimmed.len == 0)
        {
            Block b;
            b.kind = BlockKind.BLANK;
            b.srcLineStart = srcStart;
            b.srcLineEnd = srcStart;
            blockList.push(b);
            lineIdx++;
            continue;
        }

        if (trimmed.starts_with("```") || trimmed.starts_with("~~~"))
        {
            char fenceChar = trimmed[0];
            usz fenceLen = 0;
            while (fenceLen < (usz)trimmed.len && trimmed[fenceLen] == fenceChar)
            {
                fenceLen++;
            }

            String lang = trimmed[fenceLen..].trim();

            List{String} codeLines;
            codeLines.init(mem, 16);
            defer codeLines.free();

            lineIdx++;
            while (lineIdx < lineCount)
            {
                String curLine = rawLines.entries[lineIdx];
                String curTrimmed = curLine.trim();

                bool closingFence = false;
                if ((usz)curTrimmed.len >= fenceLen && curTrimmed[0] == fenceChar)
                {
                    usz closeLen = 0;
                    while (closeLen < (usz)curTrimmed.len && curTrimmed[closeLen] == fenceChar)
                    {
                        closeLen++;
                    }
                    if (closeLen >= fenceLen)
                    {
                        String rest = curTrimmed[closeLen..].trim();
                        if (rest.len == 0)
                        {
                            closingFence = true;
                        }
                    }
                }

                if (closingFence)
                {
                    break;
                }

                codeLines.push(doc.arena.copy(curLine));
                lineIdx++;
            }

            Block b;
            b.kind = BlockKind.CODE_BLOCK;
            b.srcLineStart = srcStart;
            b.srcLineEnd = (int)lineIdx;
            b.code.language = doc.arena.copy(lang);
            b.code.lines = keepStrings(&doc.arena, &codeLines);
            blockList.push(b);

            lineIdx++;
            continue;
        }

        if (trimmed.starts_with("$$") || trimmed.starts_with("\\begin{equation}") || trimmed.starts_with("\\begin{align}") || trimmed.starts_with("\\begin{gather}") || trimmed.starts_with("\\begin{aligned}"))
        {
            if (trimmed.starts_with("$$") && trimmed.len >= 4 && trimmed.ends_with("$$") && trimmed.len > 4)
            {
                String mathContent = (trimmed[2 : (usz)trimmed.len - 4]).trim();
                Block b;
                b.kind = BlockKind.MATH_BLOCK;
                b.srcLineStart = srcStart;
                b.srcLineEnd = srcStart;
                b.mathBlock.latex = doc.arena.copy(mathContent);
                blockList.push(b);
                lineIdx++;
                continue;
            }

            bool isDollar = trimmed.starts_with("$$");
            String endMarker = isDollar ? "$$" : "\\end{";

            List{String} mathLines;
            mathLines.init(mem, 16);
            defer mathLines.free();

            if (isDollar && trimmed.len > 2)
            {
                mathLines.push(trimmed[2..]);
            }
            else if (!isDollar)
            {
                mathLines.push(line);
            }

            lineIdx++;
            while (lineIdx < lineCount)
            {
                String curLine = rawLines.entries[lineIdx];
                String curTrimmed = curLine.trim();

                if (isDollar)
                {
                    if (curTrimmed.ends_with("$$") || curTrimmed.starts_with("$$"))
                    {
                        if (curTrimmed.len > 2 && !curTrimmed.starts_with("$$"))
                        {
                            mathLines.push(curTrimmed[0 : (usz)curTrimmed.len - 2]);
                        }
                        break;
                    }
                }
                else
                {
                    if (curTrimmed.starts_with(endMarker))
                    {
                        mathLines.push(curLine);
                        break;
                    }
                }

                mathLines.push(curLine);
                lineIdx++;
            }

            DString mb;
            mb.init(mem, 512);
            defer mb.free();

            for (sz m = 0; m < mathLines.size; m++)
            {
                if (m > 0) mb.append_char(' ');
                mb.append_string(mathLines.entries[m]);
            }

            Block b;
            b.kind = BlockKind.MATH_BLOCK;
            b.srcLineStart = srcStart;
            b.srcLineEnd = (int)lineIdx;
            b.mathBlock.latex = mb.keep(&doc.arena);
            blockList.push(b);

            lineIdx++;
            continue;
        }

        if (trimmed.starts_with("|") && lineIdx + 1 < lineCount && separator(rawLines.entries[lineIdx + 1]))
        {
            usz headerCols = 0;
            Span[][] headerRow = cells(&doc.arena, line, &headerCols);

            String sepLine = rawLines.entries[lineIdx + 1];
            Alignment[] aligns = alignments(&doc.arena, sepLine, headerCols);

            List{Span[][]} bodyRows;
            bodyRows.init(mem, 32);
            defer bodyRows.free();

            lineIdx += 2;

            while (lineIdx < lineCount)
            {
                String rowLine = rawLines.entries[lineIdx];
                String rowTrimmed = rowLine.trim();
                if (!rowTrimmed.starts_with("|") || rowTrimmed.len == 0)
                {
                    break;
                }

                usz rcols = 0;
                Span[][] cellRow = cells(&doc.arena, rowLine, &rcols);
                bodyRows.push(cellRow);
                lineIdx++;
            }

            Span[][]* rowsBuf = (Span[][]*)doc.arena.alloc((usz)bodyRows.size * Span[][]::size);
            for (sz r = 0; r < bodyRows.size; r++)
            {
                rowsBuf[r] = bodyRows.entries[r];
            }

            Block b;
            b.kind = BlockKind.TABLE;
            b.srcLineStart = srcStart;
            b.srcLineEnd = (int)(lineIdx - 1);
            b.table.colCount = (int)headerCols;
            b.table.alignments = aligns;
            b.table.headers = headerRow;
            b.table.rows = rowsBuf[:(usz)bodyRows.size];
            blockList.push(b);
            continue;
        }

        if (thematic(line))
        {
            Block b;
            b.kind = BlockKind.THEMATIC_BREAK;
            b.srcLineStart = srcStart;
            b.srcLineEnd = srcStart;
            blockList.push(b);
            lineIdx++;
            continue;
        }

        if (trimmed.starts_with("# ") || trimmed.starts_with("## ") || trimmed.starts_with("### ") || trimmed.starts_with("#### ") || trimmed.starts_with("##### ") || trimmed.starts_with("###### "))
        {
            int level = 0;
            while ((usz)level < (usz)trimmed.len && trimmed[level] == '#') level++;
            usz textOffset = (usz)(level + 1);
            String headingText = trimmed[textOffset..].trim();

            Block b;
            b.kind = BlockKind.HEADING;
            b.srcLineStart = srcStart;
            b.srcLineEnd = srcStart;
            b.heading.level = level;
            b.heading.spans = parser::spans(&doc.arena, headingText);
            blockList.push(b);
            lineIdx++;
            continue;
        }

        if (trimmed.starts_with("> [!"))
        {
            CalloutKind kind = CalloutKind.NOTE;
            String calloutTitle = "NOTE";

            if (trimmed.starts_with("> [!NOTE]") || trimmed.starts_with("> [!INFO]"))
            {
                kind = CalloutKind.NOTE;
                calloutTitle = "NOTE";
            }
            else if (trimmed.starts_with("> [!TIP]") || trimmed.starts_with("> [!SUCCESS]"))
            {
                kind = CalloutKind.TIP;
                calloutTitle = "TIP";
            }
            else if (trimmed.starts_with("> [!WARNING]"))
            {
                kind = CalloutKind.WARNING;
                calloutTitle = "WARNING";
            }
            else if (trimmed.starts_with("> [!IMPORTANT]"))
            {
                kind = CalloutKind.IMPORTANT;
                calloutTitle = "IMPORTANT";
            }
            else if (trimmed.starts_with("> [!DANGER]") || trimmed.starts_with("> [!CAUTION]") || trimmed.starts_with("> [!ERROR]"))
            {
                kind = CalloutKind.CAUTION;
                calloutTitle = "CAUTION";
            }

            DString calloutBody;
            calloutBody.init(mem, 512);
            defer calloutBody.free();

            lineIdx++;
            int lastCalloutLine = srcStart;

            while (lineIdx < lineCount)
            {
                String qRaw = rawLines.entries[lineIdx];
                String qTrim = qRaw.trim();
                if (!qTrim.starts_with(">"))
                {
                    break;
                }

                String qText = qTrim[1..];
                if (qText.len > 0 && qText[0] == ' ') qText = qText[1..];

                if (calloutBody.len() > 0) calloutBody.append_char(' ');
                calloutBody.append_string(qText);

                lastCalloutLine = (int)lineIdx;
                lineIdx++;
            }

            Block b;
            b.kind = BlockKind.CALLOUT;
            b.srcLineStart = srcStart;
            b.srcLineEnd = lastCalloutLine;
            b.callout.kind = kind;
            b.callout.title = doc.arena.copy(calloutTitle);
            b.callout.spans = parser::spans(&doc.arena, calloutBody.str_view());
            blockList.push(b);
            continue;
        }

        if (trimmed.starts_with("[^"))
        {
            usz colPos = 2;
            while (colPos + 1 < (usz)trimmed.len && !(trimmed[colPos] == ']' && trimmed[colPos + 1] == ':'))
            {
                colPos++;
            }

            if (colPos + 1 < (usz)trimmed.len)
            {
                String fnLabel = trimmed[2 : colPos - 2];
                String fnBody = trimmed[colPos + 2..].trim();

                Block b;
                b.kind = BlockKind.FOOTNOTE_DEF;
                b.srcLineStart = srcStart;
                b.srcLineEnd = srcStart;
                b.footnoteDef.label = doc.arena.copy(fnLabel);
                b.footnoteDef.spans = parser::spans(&doc.arena, fnBody);
                blockList.push(b);
                lineIdx++;
                continue;
            }
        }

        if (trimmed.starts_with("> ") || trimmed == ">")
        {
            DString quoteBody;
            quoteBody.init(mem, 512);
            defer quoteBody.free();

            int lastQLine = srcStart;

            while (lineIdx < lineCount)
            {
                String qRaw = rawLines.entries[lineIdx];
                String qTrim = qRaw.trim();
                if (!qTrim.starts_with(">") || qTrim.starts_with("> [!"))
                {
                    break;
                }

                String qText = qTrim[1..];
                if (qText.len > 0 && qText[0] == ' ') qText = qText[1..];

                if (quoteBody.len() > 0) quoteBody.append_char(' ');
                quoteBody.append_string(qText);

                lastQLine = (int)lineIdx;
                lineIdx++;
            }

            Block b;
            b.kind = BlockKind.BLOCKQUOTE;
            b.srcLineStart = srcStart;
            b.srcLineEnd = lastQLine;
            b.blockquote.spans = parser::spans(&doc.arena, quoteBody.str_view());
            blockList.push(b);
            continue;
        }

        usz indent = 0;
        while (indent < (usz)line.len && line[indent] == ' ') indent++;

        if (indent + 5 < (usz)line.len)
        {
            String sub = line[indent..];
            if (sub.starts_with("- [ ] ") || sub.starts_with("* [ ] "))
            {
                String taskText = sub[6..];
                Block b;
                b.kind = BlockKind.LIST_ITEM;
                b.srcLineStart = srcStart;
                b.srcLineEnd = srcStart;
                b.listItem.kind = ListKind.TASK_UNCHECKED;
                b.listItem.indentLevel = (int)indent;
                b.listItem.orderNumber = 0;
                b.listItem.spans = parser::spans(&doc.arena, taskText);
                blockList.push(b);
                lineIdx++;
                continue;
            }
            if (sub.starts_with("- [x] ") || sub.starts_with("- [X] ") || sub.starts_with("* [x] ") || sub.starts_with("* [X] "))
            {
                String taskText = sub[6..];
                Block b;
                b.kind = BlockKind.LIST_ITEM;
                b.srcLineStart = srcStart;
                b.srcLineEnd = srcStart;
                b.listItem.kind = ListKind.TASK_CHECKED;
                b.listItem.indentLevel = (int)indent;
                b.listItem.orderNumber = 0;
                b.listItem.spans = parser::spans(&doc.arena, taskText);
                blockList.push(b);
                lineIdx++;
                continue;
            }
        }

        if (indent + 1 < (usz)line.len && (line[indent] == '*' || line[indent] == '-' || line[indent] == '+') && line[indent + 1] == ' ')
        {
            String itemText = line[indent + 2..];
            Block b;
            b.kind = BlockKind.LIST_ITEM;
            b.srcLineStart = srcStart;
            b.srcLineEnd = srcStart;
            b.listItem.kind = ListKind.BULLET;
            b.listItem.indentLevel = (int)indent;
            b.listItem.orderNumber = 0;
            b.listItem.spans = parser::spans(&doc.arena, itemText);
            blockList.push(b);
            lineIdx++;
            continue;
        }

        int ordNum = 0;
        usz ordPrefixLen = 0;
        if (ordered(line, indent, &ordNum, &ordPrefixLen))
        {
            String itemText = line[ordPrefixLen..];
            Block b;
            b.kind = BlockKind.LIST_ITEM;
            b.srcLineStart = srcStart;
            b.srcLineEnd = srcStart;
            b.listItem.kind = ListKind.ORDERED;
            b.listItem.indentLevel = (int)indent;
            b.listItem.orderNumber = ordNum;
            b.listItem.spans = parser::spans(&doc.arena, itemText);
            blockList.push(b);
            lineIdx++;
            continue;
        }

        DString paraBuf;
        paraBuf.init(mem, 512);
        defer paraBuf.free();

        int lastParaLine = srcStart;

        while (lineIdx < lineCount)
        {
            String curLine = rawLines.entries[lineIdx];
            if (blockStart(curLine))
            {
                break;
            }

            String curT = curLine.trim();
            if (curT.len == 0) break;

            if (paraBuf.len() > 0)
            {
                paraBuf.append_char(' ');
            }
            paraBuf.append_string(curT);

            lastParaLine = (int)lineIdx;
            lineIdx++;
        }

        Block b;
        b.kind = BlockKind.PARAGRAPH;
        b.srcLineStart = srcStart;
        b.srcLineEnd = lastParaLine;
        b.paragraph.spans = parser::spans(&doc.arena, paraBuf.str_view());
        blockList.push(b);
    }

    doc.blocks = keepBlocks(&doc.arena, &blockList);
    return doc;
}
