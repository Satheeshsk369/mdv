# mdv

A standalone, high-performance Markdown and 2D LaTeX math terminal viewer written in **C3**. Designed for fast visual previewing in terminal workflows, multiplexers, and CLI pipelines.

---

## Features

- **Blazing Fast Native C3:** Instant parsing and Truecolor ANSI formatting with zero external runtime dependencies.
- **Built-in Syntax Highlighter:**
  - Automatic keyword, type, string, comment, number, and function token highlighting inside code blocks for C, C3, Python, Rust, Go, Zig, JavaScript, TypeScript, Bash, JSON, YAML, TOML, SQL, HTML, and CSS.
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
- **Column & Word Wrapping by Default:**
  - Paragraphs, callouts, blockquotes, and lists wrap cleanly at word boundaries to fit the terminal width.
  - Optional `-nw` / `--no-wrap` flag with horizontal scrolling (`←` / `→` or `h` / `l`).
- **YAML Frontmatter Cards:**
  - Metadata headers (`title:`, `author:`, `date:`, `version:`) automatically format into clean header cards.
- **Footnotes & References:**
  - Inline references (`[^1]`) and definition blocks (`[^1]: ...`).
- **HTML Entity Decoding:**
  - Decodes `&copy;`, `&trade;`, `&mdash;`, `&ndash;`, `&plusmn;`, `&times;`, `&divide;`, `&infin;`, `&le;`, `&ge;`, `&euro;`, `&pound;`, `&check;`, `&bull;`.
- **Live File-Watching with Instant Line Sync & SGR Mouse Scrolling:**
  - Seamless mouse wheel and keyboard scrolling without screen artifacts.
  - Automatically detects file edits on disk, re-renders in milliseconds, and smoothly scrolls to keep changed lines in view.
- **Interactive TUI Controls in Watch Mode:**
  - `Tab` / `t`: Interactive Document Outline (TOC popup) with instant heading jumping.
  - `/`: In-document interactive search with `n` (next) and `N` (previous) match navigation.
  - `w`: Toggle between Wrap mode and No-Wrap mode.
  - `h` / `l` / `←` / `→`: Horizontal scroll in no-wrap mode.
  - `?`: Toggle in-viewer interactive keybindings help screen.
  - `Esc`: Dismiss search highlights or close modal dialogs (does not quit).
  - `y`: Instant document copying to system clipboard via ANSI OSC 52 sequences.
  - `q` / `Ctrl+C`: Exit viewer.

---

## Installation

```bash
c3c run install
```
This compiles the native executable and installs the `mdv` binary globally to `~/.local/bin/mdv` (with a symlink from `mdview`).

---

## Global Usage

```bash
# Open file in live watch mode with auto line sync & native mouse selection (Default)
mdv document.md

# Open synchronized to a specific line number
mdv document.md 45
mdv document.md:45
mdv document.md +45

# Print rendered Markdown directly to stdout and exit immediately
mdv -s document.md
mdv --stdout document.md

# Disable line wrapping
mdv -nw document.md

# Output plain text without ANSI escape codes
mdv -p document.md
mdv --plain document.md

# Stream and render from stdin
curl -s https://raw.githubusercontent.com/.../README.md | mdv
cat document.md | mdv
```
