# mdv

A standalone, high-performance Markdown, AST query, and 2D LaTeX math terminal viewer written in **C3**. Designed for fast visual previewing in terminal workflows, multiplexers, and scriptable Unix CLI pipelines.

---

## Features

- **Blazing Fast Native C3:** Instant parsing, Truecolor ANSI formatting, and AST querying with zero external runtime dependencies.
- **Interactive Step-by-Step Story & Presentation Mode (`--play` / `-P`):**
  - Splits documents into focused cards/slides by heading (`#` / `##`) or thematic breaks (`---`).
  - Zero-scroll cognitive viewport locking 1 concept to the screen at a time.
  - Seamlessly toggle between normal document viewer and presentation mode on `p` / `P`.
  - Advance with `Space` / `→`, step back with `Backspace` / `←`, jump with `1`..`9`, live hot-reload on `r`.
- **Vim-Style CRUD Mutation Grammar:**
  - Full support for `[Verb] + [Noun]` operations (`-y` yank, `-d` delete, `-c` change body, `-a` append, `-i` insert, `--rename` title, `-w` save in-place).
- **Fuzzy & Number-Insensitive Heading Matching:**
  - Matches sections effortlessly (`-H "Background"`, `-c s:Background`, `#background`) regardless of numbering like `## 1. Background` or `### 2.3 System Architecture`.
- **Preserves Headings & Document Integrity on Mutations:**
  - Changing a section (`-c #slug`) replaces the inner body while preserving the heading and document hierarchy.
  - Slices lines directly from the original source buffer to guarantee 100% byte-accurate preservation of comments, frontmatter, whitespace, and horizontal rules (`---`).
- **Section Word Count & Structure Linter:**
  - `--word-count` / `--wc`: Section-by-section word count breakdown (essential for grant proposals, essays, and reports with word limits).
  - `--lint`: Validates heading hierarchy jumps, empty sections, and untyped code fences.
- **AST-Aware Querying & Section Anchoring:**
  - Slices heading sections and nested subtrees by slug (`mdv doc.md#installation`) or flag (`-H "Quick Start"`).
  - Extracts code blocks by language/index (`--code python:1 --raw | python3`), tables (`--table 1 --csv`), and math blocks (`--math 1`).
  - Document outline generation (`--toc`) and structural metrics (`--count`).
- **2D Multi-line LaTeX Math Engine:**
  - Multi-line fractions (`\frac{a}{b}`, `\cfrac`) with dynamic horizontal division bars (`───`).
  - 5-row Summations ($\Sigma$), Products ($\Pi$), and Scalable Integrals (`⌠ │ ⌡`) with upper and lower limits.
  - Multi-equation alignment derivations (`\begin{align*}`, `\begin{aligned}`, `\begin{gather*}`).
  - Elevated exponents and powers ($e^x$, $x^n$, $(x+y)^n$) in display math mode.
  - Roots and radicals (`\sqrt[n]{x}`) with overline vinculum (`┌───`).
  - Directional limits (`\lim_{x \to 0}`) with subscripts stacked underneath.
  - Matrices, determinants, and piecewise cases (`pmatrix`, `bmatrix`, `vmatrix`, `\begin{cases}`).
  - Boxed formulas (`\boxed{...}`), horizontal braces (`\overbrace`, `\underbrace`), multi-character vectors (`\overrightarrow{AB}`), and cancellations (`\cancel{x}`).
  - Greek letters, calculus operators, logic, set theory, blackboard bold ($\mathbb{R}$), and calligraphic ($\mathcal{L}$) scripts.
  - Compact single-line Unicode math for inline `$ ... $` equations.
- **Built-in Syntax Highlighter:**
  - Automatic keyword, type, string, comment, number, and function token highlighting inside code blocks for C, C3, Python, Rust, Go, Zig, JavaScript, TypeScript, Bash, JSON, YAML, TOML, SQL, HTML, and CSS.
- **Live File-Watching with Terminal Velocity Acceleration:**
  - Smooth accelerated keyboard & mouse scrolling that ramps up velocity during rapid/held navigation.
  - Half-page jumping (`u` / `d`), outline modal (`Tab` / `t`), document search (`/`), and editor jumping (`e`).
- **Column & Word Wrapping by Default:**
  - Paragraphs, callouts, blockquotes, and lists wrap cleanly at word boundaries to fit the terminal width (or custom `-W <cols>`).
  - Optional `-nw` / `--no-wrap` flag with horizontal scrolling (`←` / `→` or `h` / `l`).
- **YAML Frontmatter Cards:**
  - Metadata headers (`title:`, `author:`, `date:`, `version:`) automatically format into clean header cards.
- **Unicode Box Tables & Callouts:**
  - Auto-column sizing with alignment markers (`:---:`) and GitHub/Obsidian callouts (`[!NOTE]`, `[!TIP]`, `[!WARNING]`, `[!IMPORTANT]`, `[!CAUTION]`).

---

## Installation

```bash
c3c run install
```
This compiles the native executable and installs the `mdv` binary globally to `~/.local/bin/mdv` (with a symlink from `mdview`).

---

## Interactive Step-by-Step Presentation / Story Mode (`--play` / `-P`)

Turn any Markdown file into an interactive slide deck or progressive mental model tutorial:

```bash
mdv lecture.md --play
mdv document.md -P
```

* **Step Splitting:** Auto-splits document into focused slides strictly by `#` (Heading 1) or horizontal dividing rules (`---`). Subheadings (`##`, `###`) stay inside the slide and scroll smoothly (`j`/`k`, `d`/`u`, mouse wheel).
* **Zero Scroll Clutter:** Each step is framed cleanly on screen without distractions.
* **Seamless Mode Switching:** Press `p` / `P` at any time while browsing in normal viewer mode to enter presentation mode at your current reading position, or press `p` to return to normal continuous scroll.

### Presentation Controls
| Key | Action |
| :--- | :--- |
| `Space` / `→` / `l` / `Enter` / `n` | Advance to the **Next Step** |
| `Backspace` / `←` / `h` / `p` / `N` | Go back to the **Previous Step** |
| `1` .. `9` | Jump directly to step 1 through 9 |
| `g` / `G` | Jump to **First / Last Step** |
| `j` / `k` / `↓` / `↑` | Scroll within taller step cards |
| `p` / `P` | Toggle between **Presentation Mode** and **Normal Viewer** |
| `r` | Live re-parse and reload from disk |
| `w` | Toggle Wrap / No-Wrap mode |
| `q` / `Esc` | Cleanly exit presentation mode |

---

## Vim-Style AST Query & Mutation Grammar

`mdv` provides a concise `[Verb] + [Noun / Target]` grammar for AST-level querying, deletion, replacement, and insertion:

### 1. Verbs (Actions)
| Flag | Action | Description |
| :--- | :--- | :--- |
| **`-y, --yank`** | Yank / Query | Extract and render target block or section (**Default**). |
| **`-d, --delete`** | Delete | Remove the target block or entire section cleanly from AST. |
| **`-c, --change`** | Change Body | Replace the body of a section (preserving heading title) with new text from arg or stdin. |
| **`-a, --append`** | Append | Insert new content at the bottom of the target section. |
| **`-i, --insert`** | Insert / Prepend | Insert new content at the top of the section (immediately under heading). |
| **`--rename`** | Rename Title | Rename the section heading title while preserving body. |
| **`-w, --write, --in-place`** | Save to Disk | Save modifications back to file on disk atomically (default: stdout). |

### 2. Nouns (Target Specifiers)
| Specifier | Target Type | Example |
| :--- | :--- | :--- |
| **`#slug`** or **`s:<title>`** | Heading Section + Children | `#installation`, `s:"Quick Start"`, `s:Background` |
| **`c:<lang>[:idx]`** | Code Block (language + index) | `c:python:1`, `c:bash` |
| **`t:<idx>`** | Table (by 1-based index) | `t:1` |
| **`m:<idx>`** | 2D Math Block (by index) | `m:1` |
| **`k:<kind>`** | Callout by kind | `k:warning`, `k:note` |

### 3. Pipeline Examples
```bash
# Delete a section in-place
mdv document.md -d s:"Deprecated API" -w

# Replace 1st Python code block with new script from stdin
cat new_script.py | mdv document.md -c c:python:1 -w

# Replace body of section "1. Background" while keeping the heading line
echo "New background research summary." | mdv proposal.md -c s:Background -w

# Rename a section title
mdv proposal.md --rename s:Background "1. Executive Summary" -w

# Append a new step to the installation section
echo "3. Run 'mdv' to start" | mdv document.md -a #installation -w

# Insert changelog entry at the top of section
echo "- v0.3.0 released" | mdv CHANGELOG.md -i #v0-3-0 -w

# Yank 1st python code block in raw format directly into python
mdv document.md -y c:python:1 --raw | python3

# Yank 1st table directly as CSV
mdv document.md -y t:1 --csv
```

---

## AST-Aware Query, Slicing & Quality Checks

### Section & Slug Anchors (Fuzzy & Number-Insensitive)
```bash
# Slices by heading name or slug regardless of leading numbers
mdv document.md -H "Background"
mdv document.md#2-latex-math-formulas
mdv document.md -H "Quick Start"
```

### Word Count & Structure Linter
```bash
# Print section-by-section word count breakdown
mdv proposal.md --wc
mdv proposal.md --word-count

# Run document quality linter (heading hierarchy, empty sections, untyped code)
mdv document.md --lint
```

### Typed Block Extraction
```bash
# Extract all bash code blocks
mdv document.md --code bash

# Extract the 1st Python code block in raw format
mdv document.md --code python:1 --raw | python3

# Extract the 1st table as CSV
mdv report.md --table 1 --csv > table.csv

# Extract the 1st LaTeX display equation
mdv paper.md --math 1
```

### Document Structure & Outline
```bash
# Print structured heading outline with slug anchors and line numbers
mdv document.md --toc

# Print document block counts and structure statistics
mdv document.md --count

# Filter only blocks matching a keyword or pattern
mdv document.md --grep "Euler"
```

---

## Interactive Viewer Keybindings

When running `mdv file.md` interactively, the viewer features sub-millisecond redraws and velocity-accelerated scrolling:

| Key | Action |
| :--- | :--- |
| `p` / `P` | **Toggle Presentation / Story Mode (`--play`)** |
| `j` / `↓` | Scroll down (accelerates with rapid key repeat up to terminal velocity) |
| `k` / `↑` | Scroll up (accelerates with rapid key repeat up to terminal velocity) |
| `d` / `Ctrl+D` / `Space` | Half-page scroll down |
| `u` / `Ctrl+U` / `Shift+Space` | Half-page scroll up |
| `h` / `l` / `←` / `→` | Horizontal scroll (accelerated) for wide tables & code blocks |
| `g` / `G` | Jump directly to Top / Bottom of document |
| `: <line>` | Goto line number (e.g. `:42`) |
| `Tab` / `t` | Toggle Document Outline (Table of Contents) modal |
| `o` | Open Markdown File Tree switcher |
| `/` | Live in-document search (`n` next match, `N` previous match, `Esc` clear) |
| `e` | Open current line in `$EDITOR` (resumes watch on exit) |
| `y` | Copy full document to clipboard via OSC 52 |
| `w` | Toggle Wrap / No-Wrap mode |
| `?` | Toggle Help & Keybinding cheat-sheet |
| `q` | Quit viewer |

---

## Global CLI Usage

```bash
# Open file in live watch mode with auto line sync (Default)
mdv document.md
mdv document.md:45

# Open file directly in step-by-step presentation mode
mdv document.md --play
mdv document.md -P

# Print rendered Markdown directly to stdout and exit immediately
mdv -s document.md
mdv --stdout document.md

# Custom rendering width & disable line wrapping
mdv -W 80 -s document.md
mdv -nw -s document.md

# Output plain text without ANSI escape codes
mdv -p document.md
mdv --plain document.md

# Stream and render from stdin
curl -s https://raw.githubusercontent.com/.../README.md | mdv
cat document.md | mdv -s
```
