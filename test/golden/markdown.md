Setext H1
=========

Setext H2
---------

line one  
hard break two\
hard break three

Escapes: \*not em\* \_x\_ \# \`tick\`

snake_case_word and 2*3*4

Ref [link][r] and [r] and <https://auto.link> and www.bare.com

[r]: https://example.com "Title"

<b>html</b> <br> <kbd>Ctrl</kbd> &copy; &#169; &#x1F600;

> outer
> > nested quote
> - list in quote

1. one
2. two
   - nested
     1. deep
   ```c
   int x;
   ```
3. three

5. starts at five
6. six

    indented code block

- [x] done
- [ ] todo

Term
: definition

| a \| pipe | `b|c` | $x^2$ |
|---|---|---|
| 1 | 2 | 3 |

Inline \(a+b\) and $$c$$ inline and $5 and $6 money.

\[
x = \frac{1}{2}
\]

```math
E = mc^2
```

![alt](img.png)

Text with footnote[^1].

[^1]: The note.

## Heading {#custom-id}

***

<details><summary>Sum</summary>
hidden
</details>

<!-- comment -->


para before

    indented code
    second line

> [!TIP]
> - tip list
> - second
>
> ```c
> int y;
> ```

Inline cases $\begin{cases} 1 & x > 0 \\ 0 & \text{else} \end{cases}$ and $\binom{n}{k}$, $\xrightarrow{f}$, $\cancel{x}$.
