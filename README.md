# mdview

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
  - `?`: Toggle in-viewer interactive keybindings help screen.
  - `Esc`: Dismiss search highlights or close modal dialogs (does not quit).
  - `y`: Instant document copying to system clipboard via ANSI OSC 52 sequences.
  - `q` / `Ctrl+C`: Exit viewer.
- **Customizable Color Themes:**
  - Selectable Truecolor palettes: `monokai` (Default), `catppuccin`, `nord`, `tokyonight`, `dracula`, `gruvbox`.

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

# Select a color theme
mdview -t catppuccin document.md
mdview --theme nord document.md

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
