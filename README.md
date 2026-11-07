# mdv

A terminal Markdown viewer written in C3. It renders Markdown with colour, Unicode tables, callouts, syntax-highlighted code and 2D LaTeX math, and reloads the view when the file changes on disk.

## Build

```bash
make          # build build/mdv
make test     # unit tests
make check    # golden render and TUI snapshots
make golden   # rewrite the golden snapshots after an intended change
make install  # copy to ~/.local/bin/mdv
```

Runs on Linux, macOS, FreeBSD, OpenBSD, NetBSD and Windows (Windows Terminal or any console with VT support).

`make check` drives the live view without a terminal: `MDV_KEYS` holds one key per line (tmux names such as `Down`, `C-s`, `S-Right`, raw escape sequences, `resize:70x20`, or `!command`), `MDV_SIZE` sets the screen (default `100x30`), and mdv prints the final frame. Keys arrive 300 ms apart on a simulated clock.

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
| `↓` `↑` | Scroll; speeds up while held |
| `PgDn` `PgUp` | Half page |
| `Home` `End` | Top / bottom |
| `←` `→` | Horizontal scroll in no-wrap mode |
| `w` | Toggle wrap |
| `:` | Go to source line |
| `/` `n` `N` `Esc` | Search, next, previous, clear |
| `Space` | Options menu: pick any action below with `↓` `↑` `Enter`, or press its key |
| `h` | Highlight the block under the cursor |
| `c` | Colour theme: move through the list to preview live, `Enter` keeps it (saved to `~/.config/mdv/theme`), `Esc` reverts |
| `Tab` `t` | Outline |
| `o` | File tree |
| `e` | Edit in mdv: source and live preview side by side (wide) or stacked (narrow); opens at the highlighted block |
| `E` | Open `$EDITOR` at the current line |
| `y` | Copy the document (OSC 52) |
| `?` | Help |
| `q` `Ctrl+C` | Quit |

## Editor

`e` opens the file in mdv's editor with a live preview: side by side on wide screens, stacked on narrow ones. Editing is modeless: type to insert, arrows move by screen row, `PgUp` `PgDn` page, `Home` goes to the first non-blank then column 1, `End` to line end. `Enter` keeps indentation and continues list items (`-`, `*`, `+`, `1.`, `- [ ]`, `>`); `Enter` on an empty item ends the list. `Ctrl+O` opens the editor options menu, which lists every command:

| Key | Action |
| :--- | :--- |
| `Ctrl+S` | Save |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Ctrl+F` / `Ctrl+N` | Find / find next; every match is tinted, `Esc` clears |
| `Ctrl+E` | Replace all (asks for the text, then the replacement) |
| Mouse | Click places the cursor, drag or `Shift`+click selects, click in the preview jumps to that source line, wheel scrolls |
| `Ctrl+G` | Go to line |
| `Shift+arrows` `Shift+Home/End` | Select |
| `Ctrl+A` | Select all |
| `Ctrl+←` `Ctrl+→` | Move by word; `Ctrl+Backspace` `Ctrl+Delete` delete a word |
| `Ctrl+Home` `Ctrl+End` | Start / end of file |
| `Ctrl+C` `Ctrl+X` `Ctrl+V` | Copy, cut, paste the selection, or the line when nothing is selected |
| `Ctrl+K` / `Ctrl+D` | Delete / duplicate the lines |
| `Alt+↑` `Alt+↓` | Move the lines up / down |
| `Tab` / `Shift+Tab` | Indent / outdent the selected lines |
| `(` `[` `{` `` ` `` `"` | Insert the pair; typing the closer steps over it, `Backspace` removes both. With a selection these and `*` `_` `~` `$` wrap it |
| `Ctrl+H` | Highlight the block in source and preview |
| `Ctrl+W` | Toggle wrap |
| `Ctrl+R` | Toggle the preview |
| `Esc` | Close; twice to discard unsaved changes |

## Rendering

- CommonMark blocks: ATX and setext headings, paragraphs with hard breaks, fenced and indented code, nested block quotes holding any block, lists, thematic breaks.
- Inline: bold, italic, strikethrough, code, links, reference links, autolinks, images, footnotes, backslash escapes, named and numeric entities. Common HTML tags are hidden, `<br>` breaks the line, comments are dropped.
- Tables with column alignment and wrapping cells.
- Callouts: `[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!IMPORTANT]`, `[!CAUTION]`.
- YAML frontmatter as a header card.
- Code highlighting for C, C3, Python, Rust, Go, Zig, JavaScript, TypeScript, Bash, JSON, YAML, TOML, SQL, HTML and CSS.
- Math delimiters: `$…$`, `\(…\)` inline; `$$…$$`, `\[…\]`, ```` ```math ```` and bare `\begin{…}` for display.
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
