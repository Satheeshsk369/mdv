# mdview

A standalone, high-performance Markdown and 2D LaTeX math terminal viewer written in **C3**. Designed for fast visual previewing in terminal workflows, terminal multiplexers, and CLI pipelines.

---

## Features

- **Blazing Fast Native C3:** Instant parsing and Truecolor ANSI formatting with zero external runtime dependencies.
- **2D Multi-line LaTeX Math Engine:**
  - Multi-line fractions (`\frac{a}{b}`) and nested continued fractions with dynamic horizontal division bars (`───`).
  - 5-row Summations ($\Sigma$), Products ($\Pi$), and Scalable Integrals (`⌠ │ ⌡`) with upper and lower limits.
  - Elevated exponents and powers ($e^x$, $x^n$, $(x+y)^n$) in display math mode.
  - Roots and radicals (`\sqrt[n]{x}`) with overline vinculum (`┌───`).
  - Directional limits (`\lim_{x \to 0}`) with subscripts stacked underneath.
  - Matrices, determinants, and piecewise cases (`pmatrix`, `bmatrix`, `vmatrix`, `\begin{cases}`).
  - Full support for Greek letters, calculus operators, logic, set theory, blackboard bold ($\mathbb{R}$), and calligraphic ($\mathcal{L}$) scripts.
  - Compact single-line Unicode math for inline `$ ... $` equations.
- **Live File-Watching with Instant Line Sync:**
  - Automatically detects file edits on disk, re-renders in milliseconds, and smoothly scrolls to keep the changed lines centered in view.
- **Default High-Performance Viewer & Pager:**
  - **Clean Formatting:** Text and tables are laid out cleanly without row-wrapping stutter.
  - **Full Truecolor Colors:** Monokai palette (Pink headings, Gold math, Cyan code, Green checkboxes).
  - **Full Navigation:** Mouse wheel, arrow keys, `j`/`k`, `d`/`u` (half page), `Space`/`Ctrl+F` (full page), `g`/`G` (top/bottom), `q` to quit.
- **Line Synchronization (`mdview file.md [line_number]`):**
  - Automatically translates source line numbers to rendered lines and opens directly at that position.
- **Table Engine:** Auto-sizes columns, handles alignments (`:---`, `:---:`, `---:`), and renders Unicode box borders (`┌─┬─┐`).
- **Modern Callouts & Admonitions:** GitHub / Obsidian style `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`.
- **Interactive Checklists & Lists:** Formatted task lists (`- [x]` -> `✔`, `- [ ]` -> `☐`) and hierarchical bullets (`•`, `◦`, `▪`).

---

## Installation

```bash
c3c run install
```
This compiles the native executable and installs the `mdview` binary globally to `~/.local/bin/mdview`.

---

## Global Usage

```bash
# Open file in live watch mode with auto line sync and Truecolor rendering (Default)
mdview document.md

# Open synchronized to a specific line number
mdview document.md 45
mdview document.md:45
mdview document.md +45

# Print rendered output directly to stdout (useful for AI visual output & scripts)
mdview --stdout document.md
mdview -s document.md

# Output plain Unicode text without ANSI escape codes
mdview --plain document.md
mdview -P document.md

# Open in one-shot less pager (less -R -S)
mdview --pager document.md
mdview -p document.md

# Stream and render from stdin
curl -s https://raw.githubusercontent.com/.../README.md | mdview
cat document.md | mdview
```
