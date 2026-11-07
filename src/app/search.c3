module app;

fn void View.find(&self)
{
    self.mode = NORMAL;
    self.matches.clear();
    self.match = 0;
    String q = self.query.str_view();
    if (q.len == 0) return;
    for (int i = 0; i < self.total(); i++)
    {
        if (self.lines.lines[i].text.contains(q)) self.matches.push(i);
    }
    if (self.matches.len() > 0)
    {
        self.center(self.matches[0], self.rows / 3);
    }
    else
    {
        self.say("No matches found");
    }
}

fn void View.step(&self, int delta)
{
    if (self.matches.len() == 0) return;
    int n = (int)self.matches.len();
    self.match = (self.match + delta + n) % n;
    self.cursor = self.matches[self.match];
    self.center(self.cursor, self.rows / 3);
}

fn void View.goto(&self)
{
    self.mode = NORMAL;
    int line = self.jump.str_view().to_int() ?? 0;
    self.jump.clear();
    if (line <= 0) return;
    self.cursor = self.lines.find(line - 1);
    self.center(self.cursor, self.rows / 3);
    @pool()
    {
        self.say(string::tformat("✔ Jumped to Line %d", line));
    };
}
