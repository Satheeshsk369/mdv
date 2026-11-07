module terminal @feat(WASM);

fn void out(String s)
{
}

fn bool tty() => false;

fn bool piped() => false;

fn void edit(String path, int line)
{
}

fn ulong now() => fake;

fn Stamp stamp(String file) => {};

fn void shell(String command)
{
}

fn bool store(String name, String text) => false;

fn int[2] size() => fixed;

fn void rawMode()
{
}

fn void cooked()
{
}

fn bool wait(int ms) => false;

fn void fill()
{
}
