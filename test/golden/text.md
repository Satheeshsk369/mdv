---
title: "Golden text fixture"
author: mdv
date: 2026-11-07
---

# Heading one

## Heading two

### Heading three

#### Heading four

##### Heading five

###### Heading six

A paragraph with **bold**, *italic*, ***both***, ~~struck~~, `code`, a [link](https://example.com), an ![image](pic.png), a footnote[^1], &copy; &mdash; &infin; entities, snake_case_words and a very long sentence that keeps going so that wrapping at forty columns has to break it into several lines.

[^1]: The footnote body with *emphasis*.

1. First
2. Second with a longer line that needs to wrap around the edge of a narrow terminal
   1. Nested ordered
10. Tenth

- Bullet
  - Nested bullet
    - Deeper bullet
      - Deepest bullet
- [ ] Open task
- [x] Done task

> A quote that spans
> two source lines.

> [!TIP] Custom title
> Callout body with **bold**.

| Left | Center | Right |
| :--- | :----: | ----: |
| a | [link](https://example.org/a/very/long/path) | 1 |
| a much longer cell that should wrap inside the table | b | 22 |

***

```c
int main(void) { return 0; } // comment
```

```python
def f(x):  # comment
    return "s" + str(1.5)
```

```
plain fence
```

    indented line
