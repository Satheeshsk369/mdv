module render;

import std::core::mem;
import ansi;
import strutils;
import logic;
import buffer;

fn bool is_keyword_token(String s)
{
    if (strutils::string_eq(s, "fn") || strutils::string_eq(s, "def") || strutils::string_eq(s, "return") || strutils::string_eq(s, "struct") || strutils::string_eq(s, "class") || strutils::string_eq(s, "import") || strutils::string_eq(s, "export") || strutils::string_eq(s, "module") || strutils::string_eq(s, "if") || strutils::string_eq(s, "else") || strutils::string_eq(s, "while") || strutils::string_eq(s, "for") || strutils::string_eq(s, "in") || strutils::string_eq(s, "switch") || strutils::string_eq(s, "case") || strutils::string_eq(s, "break") || strutils::string_eq(s, "continue") || strutils::string_eq(s, "const") || strutils::string_eq(s, "let") || strutils::string_eq(s, "var") || strutils::string_eq(s, "mut") || strutils::string_eq(s, "async") || strutils::string_eq(s, "await") || strutils::string_eq(s, "pub") || strutils::string_eq(s, "type") || strutils::string_eq(s, "interface") || strutils::string_eq(s, "package") || strutils::string_eq(s, "func") || strutils::string_eq(s, "defer") || strutils::string_eq(s, "enum") || strutils::string_eq(s, "union") || strutils::string_eq(s, "typedef") || strutils::string_eq(s, "static") || strutils::string_eq(s, "extern") || strutils::string_eq(s, "inline") || strutils::string_eq(s, "trait") || strutils::string_eq(s, "impl") || strutils::string_eq(s, "match") || strutils::string_eq(s, "where") || strutils::string_eq(s, "use") || strutils::string_eq(s, "crate") || strutils::string_eq(s, "lambda") || strutils::string_eq(s, "yield") || strutils::string_eq(s, "try") || strutils::string_eq(s, "catch") || strutils::string_eq(s, "finally") || strutils::string_eq(s, "raise") || strutils::string_eq(s, "with") || strutils::string_eq(s, "as") || strutils::string_eq(s, "pass") || strutils::string_eq(s, "from") || strutils::string_eq(s, "echo") || strutils::string_eq(s, "local")) return true;
    if (strutils::string_eq(s, "SELECT") || strutils::string_eq(s, "FROM") || strutils::string_eq(s, "WHERE") || strutils::string_eq(s, "INSERT") || strutils::string_eq(s, "UPDATE") || strutils::string_eq(s, "DELETE") || strutils::string_eq(s, "CREATE") || strutils::string_eq(s, "TABLE") || strutils::string_eq(s, "JOIN") || strutils::string_eq(s, "GROUP") || strutils::string_eq(s, "BY") || strutils::string_eq(s, "ORDER")) return true;
    return false;
}

fn bool is_type_or_literal_token(String s)
{
    if (strutils::string_eq(s, "int") || strutils::string_eq(s, "uint") || strutils::string_eq(s, "String") || strutils::string_eq(s, "bool") || strutils::string_eq(s, "float") || strutils::string_eq(s, "double") || strutils::string_eq(s, "void") || strutils::string_eq(s, "char") || strutils::string_eq(s, "i8") || strutils::string_eq(s, "i16") || strutils::string_eq(s, "i32") || strutils::string_eq(s, "i64") || strutils::string_eq(s, "u8") || strutils::string_eq(s, "u16") || strutils::string_eq(s, "u32") || strutils::string_eq(s, "u64") || strutils::string_eq(s, "usz") || strutils::string_eq(s, "sz") || strutils::string_eq(s, "Vec") || strutils::string_eq(s, "Option") || strutils::string_eq(s, "Result") || strutils::string_eq(s, "None") || strutils::string_eq(s, "Some") || strutils::string_eq(s, "true") || strutils::string_eq(s, "false") || strutils::string_eq(s, "null") || strutils::string_eq(s, "nil") || strutils::string_eq(s, "self") || strutils::string_eq(s, "this") || strutils::string_eq(s, "NULL") || strutils::string_eq(s, "TRUE") || strutils::string_eq(s, "FALSE")) return true;
    return false;
}

fn void highlight_code_line(buffer::ByteBuffer* b, String line, String lang, bool plain)
{
    if (plain || line.len == 0)
    {
        b.append_slice(line);
        return;
    }

    String trimmed = strutils::string_trim(line);

    // Fast check for whole-line comment
    bool is_hash_comment_lang = strutils::string_eq(lang, "python") || strutils::string_eq(lang, "py") || strutils::string_eq(lang, "bash") || strutils::string_eq(lang, "sh") || strutils::string_eq(lang, "yaml") || strutils::string_eq(lang, "yml") || strutils::string_eq(lang, "toml") || strutils::string_eq(lang, "r");
    if ((is_hash_comment_lang && strutils::string_starts_with(trimmed, "#")) || strutils::string_starts_with(trimmed, "//") || strutils::string_starts_with(trimmed, "/*") || strutils::string_starts_with(trimmed, "* ") || strutils::string_starts_with(trimmed, "<!--"))
    {
        b.append_zstr((char*)ansi::FG_MUTED);
        b.append_zstr((char*)ansi::ITALIC);
        b.append_slice(line);
        b.append_zstr((char*)ansi::RESET);
        return;
    }

    usz i = 0;
    usz len = (usz)line.len;

    while (i < len)
    {
        char c = line[i];

        // 1. Comments
        if ((c == '/' && i + 1 < len && line[i + 1] == '/') || (is_hash_comment_lang && c == '#'))
        {
            b.append_zstr((char*)ansi::FG_MUTED);
            b.append_zstr((char*)ansi::ITALIC);
            b.append_slice(line[i..]);
            b.append_zstr((char*)ansi::RESET);
            break;
        }

        // 2. String Literals
        if (c == '"' || c == '\'' || c == '`')
        {
            char quote = c;
            usz s_start = i;
            i++;
            while (i < len)
            {
                if (line[i] == '\\' && i + 1 < len)
                {
                    i += 2;
                    continue;
                }
                if (line[i] == quote)
                {
                    i++;
                    break;
                }
                i++;
            }
            b.append_zstr((char*)ansi::FG_YELLOW);
            b.append_slice(line[s_start : i - s_start]);
            b.append_zstr((char*)ansi::RESET);
            continue;
        }

        // 3. Numbers
        if (c >= '0' && c <= '9')
        {
            usz n_start = i;
            while (i < len && ((line[i] >= '0' && line[i] <= '9') || (line[i] >= 'a' && line[i] <= 'f') || (line[i] >= 'A' && line[i] <= 'F') || line[i] == 'x' || line[i] == 'b' || line[i] == '.' || line[i] == '_'))
            {
                i++;
            }
            b.append_zstr((char*)ansi::FG_PURPLE);
            b.append_slice(line[n_start : i - n_start]);
            b.append_zstr((char*)ansi::RESET);
            continue;
        }

        // 4. Identifiers / Keywords / Types
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == '@' || c == '$')
        {
            usz id_start = i;
            while (i < len && ((line[i] >= 'a' && line[i] <= 'z') || (line[i] >= 'A' && line[i] <= 'Z') || (line[i] >= '0' && line[i] <= '9') || line[i] == '_' || line[i] == '$' || line[i] == '@'))
            {
                i++;
            }
            String id = line[id_start : i - id_start];

            if (is_keyword_token(id))
            {
                b.append_zstr((char*)ansi::FG_PINK);
                b.append_zstr((char*)ansi::BOLD);
                b.append_slice(id);
                b.append_zstr((char*)ansi::RESET);
            }
            else if (is_type_or_literal_token(id))
            {
                b.append_zstr((char*)ansi::FG_CYAN);
                b.append_slice(id);
                b.append_zstr((char*)ansi::RESET);
            }
            else if (i < len && line[i] == '(') // Function call
            {
                b.append_zstr((char*)ansi::FG_GREEN);
                b.append_slice(id);
                b.append_zstr((char*)ansi::RESET);
            }
            else if (id.len > 0 && (id[0] == '@' || id[0] == '$'))
            {
                b.append_zstr((char*)ansi::FG_ORANGE);
                b.append_slice(id);
                b.append_zstr((char*)ansi::RESET);
            }
            else
            {
                b.append_zstr((char*)ansi::FG_TEXT);
                b.append_slice(id);
                b.append_zstr((char*)ansi::RESET);
            }
            continue;
        }

        // 5. Punctuation & Operators
        if (c == '=' || c == '+' || c == '-' || c == '*' || c == '/' || c == '<' || c == '>' || c == '!' || c == '&' || c == '|' || c == '^' || c == '~')
        {
            b.append_zstr((char*)ansi::FG_PINK);
            b.append_char(c);
            b.append_zstr((char*)ansi::RESET);
            i++;
            continue;
        }

        // 6. Other characters (spaces, braces, brackets, commas, semicolons)
        b.append_char(c);
        i++;
    }
}
