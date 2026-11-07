# mdv

A terminal Markdown viewer written in C3. It renders Markdown with colour, Unicode tables, callouts, syntax-highlighted code and 2D LaTeX math, and reloads the view when the file changes on disk.

## Build

```bash
make          # build build/mdv
make test     # unit tests
make check    # golden render and TUI snapshots (needs tmux)
make golden   # rewrite the golden snapshots after an intended change
make install  # copy to ~/.local/bin/mdv
```

## Usage

```bash
mdv                     # pick a Markdown file in this folder
mdv notes.md            # live view, reloads on save
mdv notes.md:42         # open at line 42
mdv notes.md -s         # print rendered text and exit
cat notes.md | mdv      # render stdin
```

| Option | Effect |
| :--- | :--- |
| `-s` | Print to stdout |
| `-p` | Plain text, no colour (implies `-s`) |
| `-nw` | No wrapping |
| `-W <cols>` | Wrap width |
| `-h` / `-v` | Help / version |

## Keys

| Key | Action |
| :--- | :--- |
| `j` `k` `↓` `↑` | Scroll; speeds up while held |
| `d` `u` `Space` `Ctrl+D` `Ctrl+U` | Half page |
| `g` `G` | Top / bottom |
| `h` `l` `←` `→` | Horizontal scroll in no-wrap mode |
| `w` | Toggle wrap |
| `:` | Go to source line |
| `/` `n` `N` `Esc` | Search, next, previous, clear |
| `Tab` `t` | Outline |
| `o` | File tree |
| `e` | Open `$EDITOR` at the current line |
| `y` | Copy the document (OSC 52) |
| `?` | Help |
| `q` | Quit |

## Rendering

- Headings, bold, italic, strikethrough, inline code, links, images and footnotes.
- Tables with column alignment and wrapping cells.
- Callouts: `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!IMPORTANT]`, `[!CAUTION]`.
- YAML frontmatter as a header card.
- Code highlighting for C, C3, Python, Rust, Go, Zig, JavaScript, TypeScript, Bash, JSON, YAML, TOML, SQL, HTML and CSS.
- Display math in 2D: fractions, roots, sums, products, integrals, limits, matrices, cases, aligned equations, braces, arrows, `\boxed`, `\cancel`, `\mathbb`, `\mathcal`, `\mathfrak`. Inline math becomes single-line Unicode.

## Layout

| Folder | Module | Role |
| :--- | :--- | :--- |
| `src/app` | `main`, `app` | CLI; live view split into `view` (state), `keys` (key tables, dispatch), `draw`, `search`, `outline`, `tree` |
| `src/ast` | `ast` | Document blocks and spans, arena |
| `src/parser` | `parser` | `Parser.block` dispatches to one method per block kind; `Inline` scans spans |
| `src/render` | `render`, `ansi` | `Renderer` turns blocks into a `Page` of lines; one `wrap` for paragraphs and table cells |
| `src/tex` | `tex` | LaTeX to 2D boxes (`column`/`beside` combinators) and to inline Unicode (`Flat`) |
| `src/sys` | `terminal`, `text` | Raw terminal, keys, display width |
