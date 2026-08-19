# C3 Markdown & LaTeX Engine Showcase

Welcome to **mdview**! This document tests and demonstrates the full suite of in-editor Markdown and LaTeX rendering capabilities.

---

## 1. Typography & Formatting

- **Bold tex** with `**bold**` or `__bold__`
- *Italic text* with `*italic*` or `_italic_`
- ~~Strikethrough~~ with `~~strike~~`
- Inline code like `fn int main()` with ` `code` `
- Hyperlinks: [C3 Language Portal](https://c3-lang.org) and [Helix Editor](https://helix-editor.com)

---

## 2. LaTeX Math Formulas

### Inline Math
- The famous Pythagorean identity: $a^2 + b^2 = c^2$
- Euler's identity: $e^{i\pi} + 1 = 0$
- Greek letters and roots: $\alpha + \beta^2 = \sqrt{\gamma} \cdot \theta$
- Limits & Calculus: $\lim_{x \to 0} \frac{\sin(x)}{x} = 1$ and $\frac{d}{dx}(e^x) = e^x$

$$ e^x = \sum_{n=0}^{\infty} \frac{x^n}{n!} $$

$$ \int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi} $$

$$ x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} $$

$$ \lim_{x \to 0} \frac{\sin(x)}{x} = 1 $$

$$ (x + y)^n = \sum_{k=0}^n \binom{n}{k} x^{n-k} y^k $$

$$ \mathcal{F}\{f(t)\} = \int_{-\infty}^{\infty} f(t) e^{-i \omega t} dt $$

$$ x = \frac{1}{1 + \frac{1}{1 + \frac{1}{x}}} $$

$$ \det(A) = \begin{vmatrix} a & b \\ c & d \end{vmatrix} = ad - bc $$

$$ \operatorname{sgn}(x) = \begin{cases} 1 & \text{if } x > 0 \\ 0 & \text{if } x = 0 \\ -1 & \text{if } x < 0 \end{cases} $$

$$ A = \begin{pmatrix} 1 & 0 & 0 \\ 0 & 1 & 0 \\ 0 & 0 & 1 \end{pmatrix} $$

$$ f(x) = \begin{cases} \frac{x^2 - 1}{x - 1} & \text{if } x \neq 1 \\ 2 & \text{if } x = 1 \end{cases} $$

### Complex Equations
- Gaussian integral: $\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$
- Summation formula: $\sum_{i=1}^n i = \frac{n(n+1)}{2}$
- Quadratic equation: $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$
- Vectors & Matrix multiplication: $A \in \mathbb{R}^{m \times n}$ and $x \in \mathbb{R}^n$

---

## 3. Interactive Task Lists & Bullets

- [x] High-performance C3 native parsing engine
- [x] Inline LaTeX math to Unicode transformation
- [x] Automatic box-drawing tables with column alignment
- [ ] Direct Tree-sitter AST queries
- [ ] Export to formatted terminal scrollback

### Nested Lists
* Systems Programming
  * Low overhead & zero runtime cost
  * C ABI interop with `@export` and `extern`
* Editor Integration
  * Helix (`<Space> + p` split preview)
  * Ghostty terminal split & watch mode

---

## 4. Modern Callouts & Admonitions

> [!NOTE]
> This note callout provides helpful contextual info without interrupting your reading flow.

> [!TIP]
> Press `<Space> + p` in Helix to preview your document in a side-by-side vertical split!

> [!WARNING]
> Keep your LaTeX brackets `{}` balanced so expressions transform cleanly.

> [!IMPORTANT]
> The original source file remains 100% untouched while previewing.

> [!CAUTION]
> Avoid mixing raw HTML tags with Markdown tables to ensure clean alignment.

---

## 5. Source Code Blocks

```c3
module demo;
import std::io;

fn int main(String[] args)
{
    io::printn("Hello from the native C3 Markdown engine!");
    return 0;
}
```

```python
def fibonacci(n: int) -> list[int]:
    """Generate Fibonacci series up to n terms."""
    a, b = 0, 1
    result = []
    for _ in range(n):
        result.append(a)
        a, b = b, a + b
    return result
```

---

## 6. Table Layouts & Alignment

| Component | Technology | Math Expression | Status |
| :--- | :--- | :---: | ---: |
| Math Engine | `unicodeit.c3` | $\int_0^1 x^2 dx = \frac{1}{3}$ | ✔ Ready |
| Table Renderer | `table.c3` | $O(N \times M)$ | ✔ Active |
| Terminal Output | ANSI / Unicode | $\nabla \cdot \vec{E} = \frac{\rho}{\epsilon_0}$ | ✔ Supported |
| Editor Hook | Helix / Ghostty | $\lambda \to \infty$ | ✔ Integrated |

---

*Compiled and rendered at native speed with C3 & mdview.*
