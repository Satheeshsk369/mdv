module render;

import std::core::mem;
import ansi;
import text;
import logic;

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

fn void highlight_code_line(DString* b, String line, String lang, bool plain)
{
    if (plain || line.len == 0)
    {
        b.append_string(line);
        return;
    }

    String trimmed = line.trim();

    // Fast check for whole-line comment
    bool is_hash_comment_lang = lang == "python" || lang == "py" || lang == "bash" || lang == "sh" || lang == "yaml" || lang == "yml" || lang == "toml" || lang == "r";
    if ((is_hash_comment_lang && trimmed.starts_with("#")) || trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with("* ") || trimmed.starts_with("<!--"))
    {
        b.append(ansi::MUTED);
        b.append(ansi::ITALIC);
        b.append_string(line);
        b.append(ansi::RESET);
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
            b.append(ansi::MUTED);
            b.append(ansi::ITALIC);
            b.append_string(line[i..]);
            b.append(ansi::RESET);
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
            b.append(ansi::YELLOW);
            b.append_string(line[s_start : i - s_start]);
            b.append(ansi::RESET);
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
            b.append(ansi::PURPLE);
            b.append_string(line[n_start : i - n_start]);
            b.append(ansi::RESET);
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
                b.append(ansi::PINK);
                b.append(ansi::BOLD);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (is_type_or_literal_token(id))
            {
                b.append(ansi::CYAN);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (i < len && line[i] == '(') // Function call
            {
                b.append(ansi::GREEN);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (id.len > 0 && (id[0] == '@' || id[0] == '$'))
            {
                b.append(ansi::ORANGE);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else
            {
                b.append(ansi::TEXT);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            continue;
        }

        // 5. Punctuation & Operators
        if (c == '=' || c == '+' || c == '-' || c == '*' || c == '/' || c == '<' || c == '>' || c == '!' || c == '&' || c == '|' || c == '^' || c == '~')
        {
            b.append(ansi::PINK);
            b.append_char(c);
            b.append(ansi::RESET);
            i++;
            continue;
        }

        // 6. Other characters (spaces, braces, brackets, commas, semicolons)
        b.append_char(c);
        i++;
    }
}
