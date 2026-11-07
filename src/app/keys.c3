module app;

import std::math;
import terminal;

enum Mode
{
    NORMAL,
    HELP,
    SEARCH,
    JUMP,
    OUTLINE,
    FILES
}

enum Act
{
    NONE,
    QUIT,
    CLEAR,
    DOWN,
    UP,
    WHEELDOWN,
    WHEELUP,
    LEFT,
    RIGHT,
    WRAP,
    HALFDOWN,
    HALFUP,
    TOP,
    BOTTOM,
    HELP,
    OUTLINE,
    FILES,
    SEARCH,
    NEXT,
    PREV,
    JUMP,
    EDIT,
    COPY,
    CLOSE,
    OPEN,
    ALL,
    TOGGLE
}

struct Bind
{
    int key;
    Act act;
}

const Bind[] MOTION = {
    { 'j', DOWN }, { terminal::DOWN, DOWN },
    { 'k', UP }, { terminal::UP, UP },
    { terminal::WHEELDOWN, WHEELDOWN }, { terminal::WHEELUP, WHEELUP },
    { terminal::PAGEDOWN, HALFDOWN }, { ' ', HALFDOWN }, { terminal::HALFDOWN, HALFDOWN }, { 'd', HALFDOWN }, { 'D', HALFDOWN },
    { terminal::PAGEUP, HALFUP }, { terminal::SHIFTSPACE, HALFUP }, { terminal::HALFUP, HALFUP }, { 'b', HALFUP }, { 'B', HALFUP }, { 'u', HALFUP }, { 'U', HALFUP },
    { 'g', TOP }, { terminal::HOME, TOP },
    { 'G', BOTTOM }, { terminal::END, BOTTOM },
};

const Bind[] DOCUMENT = {
    { 'q', QUIT }, { 'Q', QUIT },
    { terminal::ESC, CLEAR },
    { terminal::LEFT, LEFT }, { 'h', LEFT }, { 'H', LEFT },
    { terminal::RIGHT, RIGHT }, { 'l', RIGHT }, { 'L', RIGHT },
    { 'w', WRAP }, { 'W', WRAP },
    { '?', HELP }, { 31, HELP },
    { terminal::TAB, OUTLINE }, { 't', OUTLINE }, { 'T', OUTLINE },
    { 'o', FILES }, { 'O', FILES },
    { '/', SEARCH },
    { 'n', NEXT },
    { 'N', PREV },
    { ':', JUMP },
    { 'e', EDIT }, { 'E', EDIT },
    { 'y', COPY }, { 'Y', COPY },
};

const Bind[] CONTENTS = {
    { 'q', QUIT }, { 'Q', QUIT },
    { terminal::ESC, CLOSE }, { terminal::TAB, CLOSE }, { 't', CLOSE }, { 'T', CLOSE },
    { terminal::LEFT, CLOSE }, { 'h', CLOSE }, { 'H', CLOSE },
    { terminal::ENTER, OPEN }, { terminal::RIGHT, OPEN }, { 'l', OPEN }, { 'L', OPEN },
};

const Bind[] BROWSER = {
    { terminal::ESC, CLOSE }, { 'o', CLOSE }, { 'O', CLOSE }, { 'q', CLOSE },
    { 'j', DOWN }, { terminal::DOWN, DOWN },
    { 'k', UP }, { terminal::UP, UP },
    { 'g', TOP }, { terminal::HOME, TOP },
    { 'G', BOTTOM }, { terminal::END, BOTTOM },
    { 'a', ALL }, { 'A', ALL },
    { terminal::LEFT, LEFT }, { 'h', LEFT }, { 'H', LEFT },
    { terminal::RIGHT, RIGHT }, { 'l', RIGHT }, { 'L', RIGHT },
    { ' ', TOGGLE },
    { terminal::ENTER, OPEN },
};

const Bind[] MODAL = {
    { terminal::ESC, CLOSE }, { 'q', CLOSE }, { 'Q', CLOSE }, { '?', CLOSE }, { 31, CLOSE },
    { terminal::ENTER, CLOSE }, { terminal::TAB, CLOSE }, { terminal::LEFT, CLOSE }, { 'h', CLOSE }, { 'H', CLOSE },
};

const ulong HELD = 60;

fn Act lookup(Bind[] table, int key)
{
    foreach (b : table) if (b.key == key) return b.act;
    return NONE;
}

struct Velocity
{
    ulong time;
    int dir;
    int speed;
}

fn int Velocity.next(&self, int dir, int max, ulong window)
{
    ulong now = terminal::now();
    if (self.dir == dir && now - self.time <= window)
    {
        if (self.speed < max) self.speed++;
    }
    else
    {
        self.speed = 1;
        self.dir = dir;
    }
    self.time = now;
    return self.speed;
}

fn void View.input(&self, DString* buffer, int limit, int key, bool digits)
{
    if (key == terminal::BACKSPACE)
    {
        if (buffer.len() > 0) buffer.chop(buffer.len() - 1);
        return;
    }
    bool ok = digits ? key >= '0' && key <= '9' : key >= 32 && key < 127;
    if (ok && buffer.len() < limit) buffer.append_char((char)key);
}

fn void View.normal(&self, Act act)
{
    int half = max(self.rows / 2, 3);
    int off = self.rows > 6 ? 2 : 0;
    switch (act)
    {
        case DOWN:
            self.cursor = min(self.cursor + self.velocity.next(1, 8, HELD), self.last());
            if (self.cursor + off >= self.top + self.rows) self.top = min(self.cursor + off - self.rows + 1, self.last());
        case UP:
            self.cursor = max(self.cursor - self.velocity.next(-1, 8, HELD), 0);
            if (self.cursor - off < self.top) self.top = max(self.cursor - off, 0);
        case WHEELUP:
            int step = 3 * self.velocity.next(-3, 6, 120);
            self.top = max(self.top - step, 0);
            self.cursor = math::clamp(max(self.cursor - step, 0), self.top, self.top + self.rows - 1);
        case WHEELDOWN:
            int step = 3 * self.velocity.next(3, 6, 120);
            self.top = min(self.top + step, self.last());
            self.cursor = math::clamp(min(self.cursor + step, self.last()), self.top, self.top + self.rows - 1);
        case LEFT:
            self.left = max(self.left - 4 * self.velocity.next(-2, 6, HELD), 0);
        case RIGHT:
            self.left += 4 * self.velocity.next(2, 6, HELD);
        case WRAP:
            self.config.noWrap = !self.config.noWrap;
            self.left = 0;
            self.layout();
            self.say(self.config.noWrap ? "No-Wrap Mode (← / → to scroll)" : "Wrap Mode Active");
        case HALFDOWN:
            self.cursor = min(self.cursor + half, self.last());
            self.top = min(self.top + half, self.last());
        case HALFUP:
            self.cursor = max(self.cursor - half, 0);
            self.top = max(self.top - half, 0);
        case TOP:
            self.cursor = 0;
            self.top = 0;
        case BOTTOM:
            self.cursor = self.last();
            self.top = self.last();
        case HELP:
            self.mode = HELP;
        case OUTLINE:
            self.mode = OUTLINE;
            if (self.outline.len() == 0) break;
            self.heading = 0;
            foreach (i, h : self.outline)
            {
                if (h.line > self.cursor) break;
                self.heading = (int)i;
            }
        case FILES:
            self.files();
        case SEARCH:
            self.mode = SEARCH;
            self.query.clear();
        case NEXT:
            self.step(1);
        case PREV:
            self.step(-1);
        case JUMP:
            self.mode = JUMP;
            self.jump.clear();
        case EDIT:
            self.edit();
        case COPY:
            self.copy();
        case CLEAR:
            self.matches.clear();
            self.match = 0;
            self.query.clear();
            self.status.clear();
        default:
    }
}

fn void View.headings(&self, Act act)
{
    int last = max((int)self.outline.len() - 1, 0);
    int half = max(self.rows / 2, 1);
    switch (act)
    {
        case CLOSE:
            self.mode = NORMAL;
        case DOWN:
            self.heading = min(self.heading + self.velocity.next(1, 8, HELD), last);
        case UP:
            self.heading = max(self.heading - self.velocity.next(-1, 8, HELD), 0);
        case WHEELDOWN:
            self.heading = min(self.heading + 3 * self.velocity.next(3, 6, 120), last);
        case WHEELUP:
            self.heading = max(self.heading - 3 * self.velocity.next(-3, 6, 120), 0);
        case HALFDOWN:
            self.heading = min(self.heading + half, last);
        case HALFUP:
            self.heading = max(self.heading - half, 0);
        case TOP:
            self.heading = 0;
        case BOTTOM:
            self.heading = last;
        case OPEN:
            if (self.heading < self.outline.len())
            {
                self.cursor = self.outline[self.heading].line;
                self.top = math::clamp(self.cursor, 0, self.last());
            }
            self.mode = NORMAL;
        default:
    }
}

fn void View.browse(&self, Act act)
{
    switch (act)
    {
        case CLOSE:
            self.mode = NORMAL;
        case DOWN:
            self.tree.cursor = min(self.tree.cursor + self.velocity.next(1, 8, HELD), max(self.tree.visible - 1, 0));
        case UP:
            self.tree.cursor = max(self.tree.cursor - self.velocity.next(-1, 8, HELD), 0);
        case TOP:
            self.tree.cursor = 0;
        case BOTTOM:
            self.tree.cursor = max(self.tree.visible - 1, 0);
        case ALL:
            self.tree.toggleAll();
        case LEFT:
            self.tree.left();
        case RIGHT:
            self.tree.right();
        case TOGGLE:
            self.tree.toggle();
        case OPEN:
            self.open();
        default:
    }
}

fn bool View.key(&self, int key)
{
    switch (self.mode)
    {
        case SEARCH:
            switch (key)
            {
                case terminal::ESC: self.mode = NORMAL;
                case terminal::ENTER: self.find();
                default: self.input(&self.query, 120, key, false);
            }
        case JUMP:
            switch (key)
            {
                case terminal::ESC:
                    self.mode = NORMAL;
                    self.jump.clear();
                case terminal::ENTER: self.goto();
                default: self.input(&self.jump, 20, key, true);
            }
        case HELP:
            if (lookup(MODAL, key) == CLOSE) self.mode = NORMAL;
        case FILES:
            self.browse(lookup(BROWSER, key));
        case OUTLINE:
            Act act = lookup(CONTENTS, key);
            if (act == QUIT) return true;
            self.headings(act != NONE ? act : lookup(MOTION, key));
        case NORMAL:
            Act act = lookup(DOCUMENT, key);
            if (act == QUIT) return true;
            self.normal(act != NONE ? act : lookup(MOTION, key));
    }
    return false;
}
