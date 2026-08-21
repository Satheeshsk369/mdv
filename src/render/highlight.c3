module render;

import std::core::mem;
import ansi;
import strutils;
import logic;
import buffer;

const String[] KEYWORDS = {
    "fn", "def", "return", "struct", "class", "import", "export", "module",
    "if", "else", "while", "for", "in", "switch", "case", "break", "continue",
    "const", "let", "var", "mut", "async", "await", "pub", "type", "interface",
    "package", "func", "defer", "enum", "union", "typedef", "static", "extern",
    "inline", "trait", "impl", "match", "where", "use", "crate", "lambda",
    "yield", "try", "catch", "finally", "raise", "with", "as", "pass", "from",
    "echo", "local",
    "SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "CREATE", "TABLE",
    "JOIN", "GROUP", "BY", "ORDER"
};

const String[] TYPES_AND_LITERALS = {
    "int", "uint", "String", "bool", "float", "double", "void", "char",
    "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "usz", "sz",
    "Vec", "Option", "Result", "None", "Some", "true", "false", "null", "nil",
    "self", "this", "NULL", "TRUE", "FALSE"
};

fn bool is_keyword_token(String s)
{
    for (usz i = 0; i < KEYWORDS.len; i++)
    {
        if (s == KEYWORDS[i]) return true;
    }
    return false;
}

fn bool is_type_or_literal_token(String s)
{
    for (usz i = 0; i < TYPES_AND_LITERALS.len; i++)
    {
        if (s == TYPES_AND_LITERALS[i]) return true;
    }
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
        b.append_zstr(ansi::fg_muted);
        b.append_zstr(ansi::ITALIC);
        b.append_slice(line);
        b.append_zstr(ansi::RESET);
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
            b.append_zstr(ansi::fg_muted);
            b.append_zstr(ansi::ITALIC);
            b.append_slice(line[i..]);
            b.append_zstr(ansi::RESET);
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
            b.append_zstr(ansi::fg_yellow);
            b.append_slice(line[s_start : i - s_start]);
            b.append_zstr(ansi::RESET);
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
            b.append_zstr(ansi::fg_purple);
            b.append_slice(line[n_start : i - n_start]);
            b.append_zstr(ansi::RESET);
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
                b.append_zstr(ansi::fg_pink);
                b.append_zstr(ansi::BOLD);
                b.append_slice(id);
                b.append_zstr(ansi::RESET);
            }
            else if (is_type_or_literal_token(id))
            {
                b.append_zstr(ansi::fg_cyan);
                b.append_slice(id);
                b.append_zstr(ansi::RESET);
            }
            else if (i < len && line[i] == '(') // Function call
            {
                b.append_zstr(ansi::fg_green);
                b.append_slice(id);
                b.append_zstr(ansi::RESET);
            }
            else if (id.len > 0 && (id[0] == '@' || id[0] == '$'))
            {
                b.append_zstr(ansi::fg_orange);
                b.append_slice(id);
                b.append_zstr(ansi::RESET);
            }
            else
            {
                b.append_zstr(ansi::fg_text);
                b.append_slice(id);
                b.append_zstr(ansi::RESET);
            }
            continue;
        }

        // 5. Punctuation & Operators
        if (c == '=' || c == '+' || c == '-' || c == '*' || c == '/' || c == '<' || c == '>' || c == '!' || c == '&' || c == '|' || c == '^' || c == '~')
        {
            b.append_zstr(ansi::fg_pink);
            b.append_char(c);
            b.append_zstr(ansi::RESET);
            i++;
            continue;
        }

        // 6. Other characters (spaces, braces, brackets, commas, semicolons)
        b.append_char(c);
        i++;
    }
}
