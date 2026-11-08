#!/usr/bin/env python3
import os, re, shutil, subprocess, tempfile, unicodedata
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cols, rows, size, cell, line, pad, bar = 100, 30, 15, 9, 19, 14, 40
background, foreground = (0x1B, 0x1B, 0x1B), (0xF8, 0xF8, 0xF2)

typed = r"$$ \sigma^2 = \frac{1}{n} \sum_{i=1}^{n} (x_i - \mu)^2 $$"
saved = "!printf '\\nThe noise covariance $P_k = A P_{k-1} A^T + Q$ grows until a measurement arrives.\\n' >> demo.md"
story = [("", 1800, "Enter", "open the file")] + [("Down", 160, "↓", "scroll")] * 8 + [
    ("PageDown", 900, "PgDn", "half page down"), ("PageDown", 900, "PgDn", "half page down"), ("Home", 700, "Home", "back to the top"),
    ("Tab", 1200, "Tab", "outline"), ("Down", 500, "↓", "pick a heading"), ("Down", 500, "↓", "pick a heading"), ("Enter", 1200, "Enter", "jump to it"),
    ("h", 1400, "h", "highlight the block"), ("h", 400, "h", "highlight off"),
    ("c", 1000, "c", "theme picker"), ("Down", 700, "↓", "live preview"), ("Down", 700, "↓", "live preview"),
    ("Down", 700, "↓", "live preview"), ("Down", 700, "↓", "live preview"), ("Up", 700, "↑", "live preview"),
    ("Up", 900, "↑", "live preview"), ("Enter", 1300, "Enter", "keep Kanagawa"),
    (saved, 2600, "Ctrl+S", "saved in another editor: mdv reloads and marks the change"),
    ("e", 1300, "e", "edit with live preview"), ("C-End", 600, "Ctrl+End", "end of file"),
    ("Enter", 250, "Enter", "new line"), ("Enter", 250, "Enter", "new line")] + \
    [(c if c != " " else "Space", 70, "type", "the preview follows every key") for c in typed[:-1]] + \
    [(typed[-1], 1500, "type", "the preview follows every key"),
     ("C-s", 1300, "Ctrl+S", "save"), ("Escape", 4500, "Esc", "back to the viewer, with the new equation")]


def frames():
    work = tempfile.mkdtemp()
    os.makedirs(os.path.join(work, "config"))
    try:
        for n in range(len(story)):
            shutil.copy(os.path.join(root, "assets/demo.md"), os.path.join(work, "demo.md"))
            keys = "\n".join(s[0] for s in story[1:n + 1])
            env = dict(os.environ, MDV_SIZE=f"{cols}x{rows}", MDV_KEYS=keys, XDG_CONFIG_HOME=os.path.join(work, "config"), EDITOR="true")
            yield subprocess.run([os.path.join(root, "build/mdv"), "demo.md"], cwd=work, env=env, capture_output=True, timeout=20).stdout.decode()
    finally:
        shutil.rmtree(work)


fonts = {}


def font(char, bold, italic):
    style = ("Bold " if bold else "") + ("Italic" if italic else "Regular" if not bold else "")
    query = f"JetBrainsMono Nerd Font Mono:style={style.strip()}"
    if char.isascii() or all(covers(query, c) for c in char):
        return load(query)
    return load(f"monospace:charset={' '.join(f'{ord(c):x}' for c in char)}")


def load(query):
    if query not in fonts:
        path = subprocess.run(["fc-match", "-f", "%{file}", query], capture_output=True, text=True).stdout
        fonts[query] = (ImageFont.truetype(path, size), TTFont(path, lazy=True).getBestCmap())
    return fonts[query][0]


def covers(query, char):
    load(query)
    return ord(char) in fonts[query][1]


def sgr(state, codes):
    codes = [int(c or 0) for c in codes.split(";")] if codes else [0]
    i = 0
    while i < len(codes):
        c = codes[i]
        if c == 0: state.update(fg=None, bg=None, bold=False, italic=False, under=False, strike=False)
        elif c == 1: state["bold"] = True
        elif c == 3: state["italic"] = True
        elif c == 4: state["under"] = True
        elif c == 9: state["strike"] = True
        elif c == 22: state["bold"] = False
        elif c == 23: state["italic"] = False
        elif c == 24: state["under"] = False
        elif c == 29: state["strike"] = False
        elif c == 39: state["fg"] = None
        elif c == 49: state["bg"] = None
        elif c in (38, 48) and i + 4 < len(codes) and codes[i + 1] == 2:
            state["fg" if c == 38 else "bg"] = tuple(codes[i + 2:i + 5])
            i += 4
        i += 1


def draw(text, key, note):
    back, fore = background, foreground
    for kind, value in re.findall(r"\x1b\](1[01]);#([0-9a-fA-F]{6})", text):
        color = tuple(bytes.fromhex(value))
        if kind == "11": back = color
        else: fore = color
    image = Image.new("RGB", (cols * cell + 2 * pad, rows * line + 2 * pad + bar), back)
    pen = ImageDraw.Draw(image)
    caption(pen, key, note)
    state = dict(fg=None, bg=None, bold=False, italic=False, under=False, strike=False)
    row = col = 0
    cursor = None
    glyphs = []
    for token in re.findall(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\n|[^\x1b\n]", text):
        if token == "\n":
            row, col = row + 1, 0
        elif token.startswith("\x1b["):
            body, final = token[2:-1], token[-1]
            if final == "m": sgr(state, body)
            elif final == "H" and not body.startswith("?"):
                parts = body.split(";") if body else ["1", "1"]
                row, col = int(parts[0]) - 1, int(parts[1]) - 1
            elif token == "\x1b[?25h": cursor = (row, col)
            elif token == "\x1b[?25l": cursor = None
            elif final == "K":
                x = pad + col * cell
                pen.rectangle([x, pad + row * line, pad + cols * cell, pad + (row + 1) * line - 1], fill=state["bg"] or back)
        elif not token.startswith("\x1b"):
            if unicodedata.combining(token) and glyphs:
                glyphs[-1] = glyphs[-1][:2] + (glyphs[-1][2] + token,) + glyphs[-1][3:]
                continue
            width = 2 if unicodedata.east_asian_width(token) in "WF" else 1
            x = pad + col * cell
            if state["bg"]: pen.rectangle([x, pad + row * line, x + width * cell - 1, pad + (row + 1) * line - 1], fill=state["bg"])
            col += width
            y = pad + row * line
            color = state["fg"] or fore
            glyphs.append((x, y, token, color, dict(state)))
    for x, y, token, color, look in glyphs:
        if token != " ":
            face = font(token, look["bold"], look["italic"])
            wide = face.getlength(token) / cell
            if wide > 1.15 and len(token) == 1: face = face.font_variant(size=int(size / wide))
            pen.text((x, y + 14), token, font=face, fill=color, anchor="ls")
        if look["under"]: pen.line([x, y + line - 3, x + cell, y + line - 3], fill=color)
        if look["strike"]: pen.line([x, y + line // 2, x + cell, y + line // 2], fill=color)
    if cursor:
        x, y = pad + cursor[1] * cell, pad + cursor[0] * line
        pen.rectangle([x, y + 1, x + 1, y + line - 2], fill=(0x66, 0xD9, 0xEF))
    return image


def caption(pen, key, note):
    top = rows * line + 2 * pad
    pen.line([pad, top, pad + cols * cell, top], fill=(0x3C, 0x3C, 0x32))
    if not key: return
    bold = load("JetBrainsMono Nerd Font Mono:style=Bold")
    width = int(bold.getlength(key)) + 20
    pen.rounded_rectangle([pad, top + 8, pad + width, top + bar - 6], radius=5, fill=(0x27, 0x28, 0x22), outline=(0x66, 0xD9, 0xEF))
    pen.text((pad + 10, top + bar // 2 + 1), key, font=bold, fill=(0xF8, 0xF8, 0xF2), anchor="lm")
    pen.text((pad + width + 12, top + bar // 2 + 1), note, font=load("JetBrainsMono Nerd Font Mono:style=Regular"), fill=(0x75, 0x71, 0x5E), anchor="lm")


command = "mdv demo.md"
prompt = [(f"\x1b[H\x1b[38;2;166;226;46m>\x1b[0m {command[:i]}\x1b[1;{i + 3}H\x1b[?25h", 900 if i in (0, len(command)) else 90, "type" if i else "", "")
    for i in range(len(command) + 1)]
images = [draw(f, k, n) for f, _, k, n in prompt] + [draw(f, k, n) for f, (_, _, k, n) in zip(frames(), story)]
images[0].save(os.path.join(root, "assets/demo.gif"), save_all=True, append_images=images[1:],
    duration=[d for _, d, _, _ in prompt + story], loop=0, optimize=True)
print(f"assets/demo.gif: {len(images)} frames, {os.path.getsize(os.path.join(root, 'assets/demo.gif'))} bytes")
