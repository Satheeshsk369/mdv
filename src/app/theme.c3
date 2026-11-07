module app;

import std::io;
import std::io::path;
import std::math;
import std::core::mem;
import ansi;
import terminal;
import text;

fn String settings()
{
    String config = terminal::variable("XDG_CONFIG_HOME") ?? "";
    if (config.len > 0) return string::tformat("%s/mdv/theme", config);
    String home = terminal::variable("HOME") ?? terminal::variable("USERPROFILE") ?? ".";
    return string::tformat("%s/.config/mdv/theme", home);
}

fn int scheme(String name)
{
    for (int i = 0; i < ansi::themes(); i++) if (ansi::title(i) == name) return i;
    return 0;
}

fn void View.paint(&self, int index)
{
    self.theme = index;
    ansi::use(ansi::palette(index));
    @pool()
    {
        terminal::out(ansi::backdrop());
    };
    self.layout();
    self.editor.fresh = true;
}

fn void View.restore(&self)
{
    @pool()
    {
        String? saved = (String)io::file::load(tmem, settings());
        if (catch saved) return;
        int index = scheme(saved.trim());
        if (index != 0) self.paint(index);
    };
}

fn void View.remember(&self)
{
    @pool()
    {
        String file = settings();
        (void)path::mkdir(file[:file.rindex_of_char('/') ?? 0], true);
        if (!terminal::store(file, ansi::title(self.theme))) self.say("✘ Could not save theme");
    };
}

fn void View.palette(&self)
{
    self.original = self.theme;
    self.mode = THEME;
}

fn void View.preview(&self, Act act)
{
    switch (act)
    {
        case CLOSE:
            if (self.theme != self.original) self.paint(self.original);
            self.mode = NORMAL;
        case OPEN:
            self.mode = NORMAL;
            self.remember();
            @pool()
            {
                self.say(string::tformat("✔ Theme: %s", ansi::title(self.theme)));
            };
        default:
            int next = self.move(self.theme, ansi::themes(), act);
            if (next != self.theme) self.paint(next);
    }
}

fn void View.drawThemes(&self, DString* fb)
{
    @pool()
    {
        self.title(fb, string::tformat("Theme: %s (%d/%d)  Enter keep · Esc revert", ansi::title(self.theme), self.theme + 1, ansi::themes()));
    };
    rule(fb, self.width);
    int list = 26;
    self.themeTop = follow(self.themeTop, self.theme, ansi::themes(), self.rows);
    for (int r = 0; r < self.rows; r++)
    {
        int i = self.themeTop + r;
        int used = 0;
        if (i < ansi::themes())
        {
            bool active = i == self.theme;
            fb.append(active ? ansi::style(ACTIVE) : ansi::style(TEXT));
            fb.append(active ? " ▶ " : "   ");
            used = 3 + text::clip(fb, ansi::title(i), 0, list - 4);
            fb.append(ansi::RESET);
        }
        fb.spaces(list - used);
        fb.append(ansi::style(BORDER));
        fb.append("│");
        fb.append(ansi::RESET);
        int line = self.top + r;
        if (line < self.total())
        {
            fb.append_char(' ');
            text::clip(fb, self.lines.lines[line].text, 0, self.width - list - 2);
        }
        fb.append("\e[K");
        if (r < self.rows - 1) fb.append_char('\n');
    }
}
