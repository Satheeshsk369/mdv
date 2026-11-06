module text;

struct Range
{
    uint lo;
    uint hi;
}

const Range[] ZERO = {
    { 0x0300, 0x036F }, { 0x0483, 0x0489 }, { 0x0591, 0x05BD }, { 0x05BF, 0x05BF },
    { 0x05C1, 0x05C2 }, { 0x05C4, 0x05C5 }, { 0x05C7, 0x05C7 }, { 0x0610, 0x061A },
    { 0x064B, 0x065F }, { 0x0670, 0x0670 }, { 0x0711, 0x0711 }, { 0x0730, 0x074A },
    { 0x1AB0, 0x1AFF }, { 0x1DC0, 0x1DFF }, { 0x200B, 0x200F }, { 0x202A, 0x202E },
    { 0x2060, 0x206F }, { 0x20D0, 0x20FF }, { 0xFE00, 0xFE0F }, { 0xFE20, 0xFE2F },
    { 0xFEFF, 0xFEFF },
};

const Range[] WIDE = {
    { 0x1100, 0x115F }, { 0x2E80, 0x303E }, { 0x3040, 0xA4CF }, { 0xAC00, 0xD7A3 },
    { 0xF900, 0xFAFF }, { 0xFE10, 0xFE19 }, { 0xFE30, 0xFE6F }, { 0xFF01, 0xFF60 },
    { 0xFFE0, 0xFFE6 }, { 0x1F000, 0x1FAFF }, { 0x20000, 0x3FFFF },
};

fn bool within(Range[] ranges, uint cp)
{
    foreach (r : ranges) if (cp >= r.lo && cp <= r.hi) return true;
    return false;
}

fn int cells(uint cp)
{
    if (cp < 0x20 || (cp >= 0x7F && cp < 0xA0)) return 0;
    if (cp < 0x7F) return 1;
    if (within(ZERO, cp)) return 0;
    return within(WIDE, cp) ? 2 : 1;
}

fn int width(String s)
{
    int total;
    sz i;
    while (i < s.len)
    {
        char c = s[i];
        if (c == 0x1b && i + 1 < s.len && s[i + 1] == '[')
        {
            i += 2;
            while (i < s.len && !s[i].is_alpha()) i++;
            if (i < s.len) i++;
            continue;
        }
        sz n = c < 0x80 ? 1 : (c & 0xE0) == 0xC0 ? 2 : (c & 0xF0) == 0xE0 ? 3 : (c & 0xF8) == 0xF0 ? 4 : 0;
        if (n == 0)
        {
            i++;
            continue;
        }
        uint cp = n == 1 ? c : c & (0xFF >> (n + 1));
        for (sz k = 1; k < n; k++) cp = cp << 6 | (i + k < s.len ? s[i + k] & 0x3F : 0);
        total += cells(cp);
        i += min(n, s.len - i);
    }
    return total;
}

fn void DString.repeat(&self, String s, int count)
{
    if (count > 0) self.append_string_repeat(s, count);
}

fn void DString.spaces(&self, int count)
{
    if (count > 0) self.append_char_repeat(' ', count);
}
