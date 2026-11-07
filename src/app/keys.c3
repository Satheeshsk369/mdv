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
    FILES,
    MENU
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
    TOGGLE,
    MENU,
    MARK
}

struct Bind
{
    int key;
    Act act;
}

const Bind[] MOTION = {
    { terminal::DOWN, DOWN }, { terminal::UP, UP },
    { terminal::WHEELDOWN, WHEELDOWN }, { terminal::WHEELUP, WHEELUP },
    { terminal::PAGEDOWN, HALFDOWN }, { terminal::PAGEUP, HALFUP },
    { terminal::HOME, TOP }, { terminal::END, BOTTOM },
};

const Bind[] DOCUMENT = {
    { 'q', QUIT }, { 'Q', QUIT },
    { terminal::ESC, CLEAR },
    { terminal::LEFT, LEFT }, { terminal::RIGHT, RIGHT },
    { ' ', MENU },
    { 'h', MARK }, { 'H', MARK },
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
    { terminal::LEFT, CLOSE },
    { terminal::ENTER, OPEN }, { terminal::RIGHT, OPEN },
};

const Bind[] CHOICES = {
    { 'q', QUIT }, { 'Q', QUIT },
    { terminal::ESC, CLOSE }, { ' ', CLOSE }, { terminal::LEFT, CLOSE },
    { terminal::ENTER, OPEN }, { terminal::RIGHT, OPEN },
};

struct Item
{
    String key;
    String label;
    Act act;
}

const Item[] ITEMS = {
    { "Tab", "Outline", OUTLINE },
    { "o", "Files", FILES },
    { "/", "Search", SEARCH },
    { ":", "Go to line", JUMP },
    { "h", "Highlight block", MARK },
    { "w", "Toggle wrap", WRAP },
    { "e", "Edit in $EDITOR", EDIT },
    { "y", "Copy document", COPY },
    { "?", "Help", HELP },
    { "q", "Quit", QUIT },
};

const Bind[] BROWSER = {
    { terminal::ESC, CLOSE }, { 'o', CLOSE }, { 'O', CLOSE }, { 'q', CLOSE },
    { terminal::DOWN, DOWN }, { terminal::UP, UP },
    { terminal::HOME, TOP }, { terminal::END, BOTTOM },
    { 'a', ALL }, { 'A', ALL },
    { terminal::LEFT, LEFT }, { terminal::RIGHT, RIGHT },
    { ' ', TOGGLE },
    { terminal::ENTER, OPEN },
};

const Bind[] MODAL = {
    { terminal::ESC, CLOSE }, { 'q', CLOSE }, { 'Q', CLOSE }, { '?', CLOSE }, { 31, CLOSE },
    { terminal::ENTER, CLOSE }, { terminal::TAB, CLOSE }, { terminal::LEFT, CLOSE },
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

fn int View.move(&self, int at, int count, Act act)
{
    int last = max(count - 1, 0);
    int half = max(self.rows / 2, 1);
    switch (act)
    {
        case DOWN: return min(at + self.velocity.next(1, 8, HELD), last);
        case UP: return max(at - self.velocity.next(-1, 8, HELD), 0);
        case WHEELDOWN: return min(at + 3 * self.velocity.next(3, 6, 120), last);
        case WHEELUP: return max(at - 3 * self.velocity.next(-3, 6, 120), 0);
        case HALFDOWN: return min(at + half, last);
        case HALFUP: return max(at - half, 0);
        case TOP: return 0;
        case BOTTOM: return last;
        default: return at;
    }
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
        case MENU:
            self.mode = MENU;
            self.choice = 0;
        case MARK:
            self.focus = !self.focus;
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
            self.focus = false;
        default:
    }
}

fn void View.headings(&self, Act act)
{
    switch (act)
    {
        case CLOSE:
            self.mode = NORMAL;
        case OPEN:
            if (self.heading < self.outline.len())
            {
                self.cursor = self.outline[self.heading].line;
                self.top = math::clamp(self.cursor, 0, self.last());
            }
            self.mode = NORMAL;
        default:
            self.heading = self.move(self.heading, (int)self.outline.len(), act);
    }
}

fn bool View.choose(&self, int key)
{
    Act act = lookup(CHOICES, key);
    switch (act)
    {
        case QUIT: return true;
        case CLOSE: self.mode = NORMAL;
        case OPEN:
            self.mode = NORMAL;
            Act chosen = ITEMS[self.choice].act;
            if (chosen == QUIT) return true;
            self.normal(chosen);
        default:
            Act motion = lookup(MOTION, key);
            if (motion != NONE)
            {
                self.choice = self.move(self.choice, ITEMS.len, motion);
                return false;
            }
            Act direct = lookup(DOCUMENT, key);
            if (direct == NONE) return false;
            self.mode = NORMAL;
            if (direct == QUIT) return true;
            self.normal(direct);
    }
    return false;
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
        case MENU:
            return self.choose(key);
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
