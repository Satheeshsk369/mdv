# mdview

A standalone, high-performance Markdown and LaTeX math terminal viewer written in **C3**. Designed for fast live previewing with **Ghostty**, **Helix**, **tmux**, and CLI workflows.

---

## Features

- **Blazing Fast Native C3:** Instant parsing and Truecolor ANSI formatting with zero external runtime dependencies.
- **LaTeX Math Support:** Converts LaTeX math expressions (`$ \alpha + \beta^2 $` and `$$ ... $$`) directly to readable Unicode glyphs via `unicodeit`.
- **Default High-Performance Pager (`less -R -S`):**
  - **No word-wrapping stutter:** Lines are clean and smooth without wrapping across rows.
  - **Full Truecolor Colors:** Monokai palette (Pink headings, Gold math, Cyan code, Green checkboxes).
  - **Full Navigation & Search:** Mouse wheel, arrow keys, `/` search, `j`/`k`, `d`/`u`, `g`/`G`, `q` to quit.
- **Line Synchronization (`mdview file.md [line_number]`):**
  - Automatically translates source line numbers to rendered lines and opens the pager directly at that position.
- **Table Engine:** Auto-sizes columns, handles alignments (`:---`, `:---:`, `---:`), renders Unicode box borders (`┌─┬─┐`), and word-wraps text.
- **Modern Callouts & Admonitions:** GitHub / Obsidian style `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`.
- **Interactive Checklist & Lists:** Formatted task lists (`- [x]` -> `✔`, `- [ ]` -> `☐`) and hierarchical bullets (`•`, `◦`, `▪`).

---

## Build & Install

```bash
cd /home/satheesh/Jarvis/tools/mdview
c3c run install
```

---

## Usage

```bash
# Open file in fast Truecolor pager (less -R -S)
mdview README.md

# Open synchronized to a specific line number
mdview README.md 45
mdview README.md:45
mdview README.md +45

# Print directly to stdout (bypasses pager)
mdview --stdout README.md

# Output plain Unicode text without ANSI escape codes
mdview --plain README.md

# Read from stdin
curl -s https://raw.githubusercontent.com/.../README.md | mdview
```

---

## Helix Integration

In `~/.config/helix/config.toml`:

```toml
[keys.normal.space]
p = [":write", ":sh mdview %{buffer_name} %{cursor_line}"]
```
