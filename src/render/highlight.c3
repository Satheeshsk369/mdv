module render;

import std::core::mem;
import ansi;
import text;
import ast;

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

fn bool keyword(String s)
{
    for (usz i = 0; i < KEYWORDS.len; i++)
    {
        if (s == KEYWORDS[i]) return true;
    }
    return false;
}

fn bool literal(String s)
{
    for (usz i = 0; i < TYPES_AND_LITERALS.len; i++)
    {
        if (s == TYPES_AND_LITERALS[i]) return true;
    }
    return false;
}

fn void highlight(DString* b, String line, String lang, bool plain)
{
    if (plain || line.len == 0)
    {
        b.append_string(line);
        return;
    }

    String trimmed = line.trim();

    bool isHashCommentLang = lang == "python" || lang == "py" || lang == "bash" || lang == "sh" || lang == "yaml" || lang == "yml" || lang == "toml" || lang == "r";
    if ((isHashCommentLang && trimmed.starts_with("#")) || trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with("* ") || trimmed.starts_with("<!--"))
    {
        b.append(ansi::style(MUTED));
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

        if ((c == '/' && i + 1 < len && line[i + 1] == '/') || (isHashCommentLang && c == '#'))
        {
            b.append(ansi::style(MUTED));
            b.append(ansi::ITALIC);
            b.append_string(line[i..]);
            b.append(ansi::RESET);
            break;
        }

        if (c == '"' || c == '\'' || c == '`')
        {
            char quote = c;
            usz sStart = i;
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
            b.append(ansi::style(YELLOW));
            b.append_string(line[sStart : i - sStart]);
            b.append(ansi::RESET);
            continue;
        }

        if (c >= '0' && c <= '9')
        {
            usz nStart = i;
            while (i < len && ((line[i] >= '0' && line[i] <= '9') || (line[i] >= 'a' && line[i] <= 'f') || (line[i] >= 'A' && line[i] <= 'F') || line[i] == 'x' || line[i] == 'b' || line[i] == '.' || line[i] == '_'))
            {
                i++;
            }
            b.append(ansi::style(PURPLE));
            b.append_string(line[nStart : i - nStart]);
            b.append(ansi::RESET);
            continue;
        }

        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c == '@' || c == '$')
        {
            usz idStart = i;
            while (i < len && ((line[i] >= 'a' && line[i] <= 'z') || (line[i] >= 'A' && line[i] <= 'Z') || (line[i] >= '0' && line[i] <= '9') || line[i] == '_' || line[i] == '$' || line[i] == '@'))
            {
                i++;
            }
            String id = line[idStart : i - idStart];

            if (keyword(id))
            {
                b.append(ansi::style(PINK));
                b.append(ansi::BOLD);
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (literal(id))
            {
                b.append(ansi::style(CYAN));
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (i < len && line[i] == '(')
            {
                b.append(ansi::style(GREEN));
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else if (id.len > 0 && (id[0] == '@' || id[0] == '$'))
            {
                b.append(ansi::style(ORANGE));
                b.append_string(id);
                b.append(ansi::RESET);
            }
            else
            {
                b.append(ansi::style(TEXT));
                b.append_string(id);
                b.append(ansi::RESET);
            }
            continue;
        }

        if (c == '=' || c == '+' || c == '-' || c == '*' || c == '/' || c == '<' || c == '>' || c == '!' || c == '&' || c == '|' || c == '^' || c == '~')
        {
            b.append(ansi::style(PINK));
            b.append_char(c);
            b.append(ansi::RESET);
            i++;
            continue;
        }

        b.append_char(c);
        i++;
    }
}
