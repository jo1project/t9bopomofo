#!/usr/bin/env python3
"""Render App Store screenshots (iPhone 6.9", 1320x2868) of the T9 Zhuyin keyboard.

Keyboard geometry and colors mirror the Swift UI (KeyboardChrome, ZhuyinKeyboardView,
CandidateBarView, KeyCalloutView), drawn in points and scaled by S. Candidate lists come from
the Python reference engine (Tests/test_engine_ref.py), not made up.

Usage: python Scripts/render_asc_screenshots.py   (Windows fonts; see FONTS)
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Tests"))
from test_engine_ref import encode_reading, load_all, n_best  # noqa: E402

W, H = 1320, 2868  # iPhone 6.9" App Store size
S = 3.0  # px per pt
OUT = ROOT / "docs" / "app-store-screenshots"
ICON = ROOT / "T9Bopomofo/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
FONTS = {
    "regular": "C:/Windows/Fonts/msjh.ttc",
    "bold": "C:/Windows/Fonts/msjhbd.ttc",
    "symbol": "C:/Windows/Fonts/seguisym.ttf",
}
SYMBOLS = set("⌫▼▲↓✦‹›⌄")

BRAND = (74, 64, 207)  # app icon indigo
ORANGE = (255, 149, 0)  # UIColor.systemOrange
BLUE = (0, 122, 255)  # UIColor.systemBlue
KB_BG = (199, 199, 199)  # white 0.78


def P(v: float) -> int:
    return int(round(v * S))


_fonts: dict = {}


def font(size_pt: float, kind: str = "regular") -> ImageFont.FreeTypeFont:
    key = (kind, size_pt)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONTS[kind], P(size_pt))
    return _fonts[key]


def runs(text: str, size: float, bold: bool):
    """Split text into (chunk, font) runs; a few symbols aren't in JhengHei."""
    out = []
    for ch in text:
        f = font(size, "symbol") if ch in SYMBOLS else font(size, "bold" if bold else "regular")
        if out and out[-1][1] is f:
            out[-1][0] += ch
        else:
            out.append([ch, f])
    return out


def text_w(text: str, size: float, bold: bool = False) -> float:
    return sum(f.getlength(c) for c, f in runs(text, size, bold)) / S


TONES = "ˉˊˇˋ˙"


def draw_text(d, x: float, y: float, text: str, size: float, fill, bold=False, anchor="l"):
    """x, y in pt; y is the vertical center. anchor: l / m (center) / r."""
    if text and not text.strip(TONES):
        return draw_tone(d, x, y, text, size * 1.5, fill)  # JhengHei's tone glyphs are tiny vs SF
    rs = runs(text, size, bold)
    w = text_w(text, size, bold)
    x0 = {"l": x, "m": x - w / 2, "r": x - w}[anchor]
    px = P(x0)
    for chunk, f in rs:
        d.text((px, P(y)), chunk, fill=fill, font=f, anchor="lm")
        px += f.getlength(chunk)


def draw_tone(d, x, y, text, size, fill):
    """Tone marks sit at the top of their em box, so center on the rendered ink instead."""
    f = font(size, "bold")
    mask = Image.new("L", (P(size) * 3, P(size) * 3))
    ImageDraw.Draw(mask).text((P(size), P(size) * 2), text, font=f, fill=255, anchor="ls")
    x0, y0, x1, y1 = mask.getbbox()
    d.text((P(x) - (x0 + x1) / 2 + P(size), P(y) - (y0 + y1) / 2 + P(size) * 2), text, font=f, fill=fill, anchor="ls")


def rrect(d, box, r, fill=None, outline=None, width=0):
    d.rounded_rectangle([P(v) for v in box], radius=P(r), fill=fill, outline=outline, width=P(width) if width else 0)


def blend(c, bg, a):
    return tuple(int(bg[i] * (1 - a) + c[i] * a) for i in range(3))


def shadowed_key(im, box, r, fill):
    d = ImageDraw.Draw(im)
    rrect(d, (box[0], box[1] + 1.5, box[2], box[3] + 1.5), r, fill=(160, 160, 160))
    rrect(d, box, r, fill=fill)


# MARK: - Candidates from the reference engine

_entries = None


def candidates(reading: str, marks, limit=40) -> list[str]:
    global _entries
    if _entries is None:
        best = {}
        for e in load_all():
            k = (e[0], e[1])
            if k not in best or e[3] > best[k][3]:
                best[k] = e
        _entries = list(best.values())
    digits = encode_reading(reading)
    out = n_best(digits, _entries, marks, limit=4)
    spans = []
    for n in range(len(digits) - 1, 0, -1):
        hits = sorted((e for e in _entries if e[2] == digits[:n]), key=lambda e: -e[3])
        spans.append([e[0] for e in hits[:12]])
    for i in range(12):  # round-robin long -> short, like T9SortFilter
        for s in spans:
            if i < len(s) and s[i] not in out:
                out.append(s[i])
    return out[:limit]


def preedit(reading: str) -> str:
    labels = {"1": "ㄅㄉㄚ", "2": "ㄍㄐㄞ", "3": "ㄓㄗㄢㄦ", "4": "ㄆㄊㄛ", "5": "ㄎㄑㄟ", "6": "ㄔㄘㄣㄧ",
              "7": "ㄇㄋㄜ", "8": "ㄏㄒㄠㄡ", "9": "ㄕㄙㄤㄨ", "0": "ㄈㄌㄝ", "v": "ㄖㄥㄩ"}
    return "·".join(labels[c] for c in encode_reading(reading))


# MARK: - Phone chrome

def status_bar(d, dark=False):
    fg = (255, 255, 255) if dark else (0, 0, 0)
    draw_text(d, 52, 30, "9:41", 17, fg, bold=True, anchor="m")
    rrect(d, (157, 11, 283, 48), 19, fill=(0, 0, 0))  # dynamic island
    # battery
    rrect(d, (386, 23, 412, 36), 4, outline=fg, width=1.2)
    rrect(d, (388.5, 25.5, 409.5, 33.5), 2, fill=fg)
    for i, h in enumerate((4, 6, 8, 10)):  # signal
        d.rectangle([P(346 + i * 5), P(35 - h), P(349 + i * 5), P(35)], fill=fg)


# MARK: - Keyboard (mirrors KeyboardViewController / ZhuyinKeyboardView)

ROWS = [
    [("tone", "˙"), ("z", "ㄅㄉㄚ"), ("z", "ㄍㄐㄞ"), ("z", "ㄓㄗㄢㄦ"), ("func", "⌫")],
    [("tone", "ˊ"), ("z", "ㄆㄊㄛ"), ("z", "ㄎㄑㄟ"), ("z", "ㄔㄘㄣㄧ"), ("func", "123")],
    [("tone", "ˇ"), ("z", "ㄇㄋㄜ"), ("z", "ㄏㄒㄠㄡ"), ("z", "ㄕㄙㄤㄨ"), ("func", "。")],
    [("tone", "ˋ"), ("z", "ㄈㄌㄝ"), ("space", "空格/EN"), ("z", "ㄖㄥㄩ"), ("action", "換行")],
]
TONE_FILL = blend(ORANGE, KB_BG, 0.16)
TONE_TEXT = (158, 71, 0)


def candidate_bar(im, top: float, items: list[str], pre: str = "", llm: set[str] = frozenset(), expanded=False):
    d = ImageDraw.Draw(im)
    x0, x1, h = 4, 436, 40
    cy = top + h / 2
    x = x0
    if pre:
        # Chip truncates from the head (CandidateBarView.preeditLabel.lineBreakMode).
        while text_w(pre, 12) > 72:
            pre = pre[1:]
        if pre != preedit_full[0]:
            pre = "…" + pre[1:]
        cw = text_w(pre, 12) + 16
        rrect(d, (x, cy - 14, x + cw, cy + 14), 8, fill=(173, 173, 173))
        draw_text(d, x + cw / 2, cy, pre, 12, (31, 31, 31), anchor="m")
        x += cw + 6
        d.rectangle([P(x), P(cy - 11), P(x + 1), P(cy + 11)], fill=(169, 169, 169))
        x += 7
    # ▼ / ↓ buttons
    draw_text(d, x1 - 2 - 34 - 2 - 17, cy, "▲" if expanded else "▼", 14, (85, 85, 85), bold=True, anchor="m")
    draw_text(d, x1 - 2 - 17, cy, "↓", 18, (85, 85, 85), bold=True, anchor="m")
    limit = x1 - 2 - 34 - 2 - 34
    for i, t in enumerate(items):
        is_llm = t in llm
        label = f"✦ {t}" if is_llm else t
        size = 18 if is_llm else 20
        w = text_w(label, size, bold=is_llm or i == 0) + 28
        if x + w > limit:
            break
        box = (x, cy - 17, x + w, cy + 17)
        if is_llm:
            shadowed_key(im, box, 16, (209, 232, 255))
            rrect(d, box, 16, outline=(115, 173, 235), width=1)
            draw_text(d, x + w / 2, cy, label, size, (31, 89, 140), bold=True, anchor="m")
        else:
            shadowed_key(im, box, 16, (255, 255, 255))
            rrect(d, box, 16, outline=ORANGE if i == 0 else (235, 235, 235), width=1.5 if i == 0 else 1)
            draw_text(d, x + w / 2, cy, label, size, (0, 0, 0), bold=i == 0, anchor="m")
        x += w + 10


preedit_full = [""]


def keyboard(im, *, items, pre_reading="", composing=False, llm=frozenset(), highlight=None, expanded_items=None):
    """Draws the keyboard + system globe strip at the bottom; returns key boxes (pt)."""
    d = ImageDraw.Draw(im)
    height = 360 if expanded_items else 268
    bottom = 956 - 34
    top = bottom - height
    d.rectangle([0, P(top), W, H], fill=KB_BG)
    # System strip under third-party keyboards (globe + mic).
    d.ellipse([P(22), P(bottom + 4), P(44), P(bottom + 26)], outline=(70, 70, 70), width=P(1.6))
    d.line([P(33), P(bottom + 4), P(33), P(bottom + 26)], fill=(70, 70, 70), width=P(1.2))
    d.line([P(22), P(bottom + 15), P(44), P(bottom + 15)], fill=(70, 70, 70), width=P(1.2))
    rrect(d, (147, 949, 293, 954), 3, fill=(20, 20, 20))  # home indicator

    preedit_full[0] = preedit(pre_reading) if pre_reading else ""
    candidate_bar(im, top + 2, items, preedit_full[0], llm, expanded=bool(expanded_items))
    if expanded_items:
        candidate_panel(im, (4, top + 44, 436, bottom - 4), expanded_items)
        return {}

    # ZhuyinKeyboardView.layoutKeys
    kx, ky, kw, kh = 3 + 2, top + 44 + 2, 434 - 4, height - 46 - 2 - 4
    usable = kw - 4 * 3 - 8
    side, mid = usable * 0.155, usable * 0.230
    scale = usable / (side * 2 + mid * 3)
    widths = [w * scale for w in (side, mid, mid, mid, side)]
    gaps = [4, 4, 4, 8]
    row_h = (kh - 4 * 3) / 4
    sep_x = kx + sum(widths[:4]) + sum(gaps[:3]) + 8 * 0.45
    boxes = {}
    for r, row in enumerate(ROWS):
        x = kx
        y = ky + r * (row_h + 4)
        for c, (kind, label) in enumerate(row):
            box = (x, y, x + widths[c], y + row_h)
            boxes[(r, c)] = box
            fill, color, size = (255, 255, 255), (0, 0, 0), 24
            if kind == "z":
                size = 20 if len(label) >= 4 else 22
            elif kind == "tone":
                fill, color, size = TONE_FILL, TONE_TEXT, 26
            elif kind == "func":
                fill, size = (153, 153, 153), 16
            elif kind == "action":
                fill, color, size = ORANGE, (255, 255, 255), 15
            elif kind == "space":
                label, size = ("ˉ", 24) if composing else (label, 14)
            if highlight and (r, c) in highlight:
                fill = (214, 228, 255)
            shadowed_key(im, box, 7, fill)
            if label == "⌫":
                size = 22
            draw_text(d, (box[0] + box[2]) / 2, (box[1] + box[3]) / 2, label, size, color, bold=True, anchor="m")
            x += widths[c] + (gaps[c] if c < 4 else 0)
    d.rectangle([P(sep_x - 1), P(ky + 2), P(sep_x + 1), P(ky + kh - 2)], fill=(115, 115, 115))
    return boxes


def candidate_panel(im, box, items):
    """CandidatePanelView.packRows: wrapping rows, min cell = 1/6 of the width."""
    d = ImageDraw.Draw(im)
    rrect(d, box, 10, fill=(230, 230, 230))
    width = box[2] - box[0] - 16
    avail = width - 6
    min_cell = (avail - 6 * 5) // 6
    x, y = box[0] + 8, box[1] + 8
    used = -6
    for i, t in enumerate(items):
        w = min(avail, max(min_cell, text_w(t, 20, i == 0) + 28))
        if used + 6 + w > avail:
            y += 44 + 8
            used = -6
        if y + 44 > box[3] - 8:
            break
        cx = box[0] + 8 + used + 6
        cell = (cx, y, cx + w, y + 44)
        shadowed_key(im, cell, 8, (255, 255, 255))
        rrect(d, cell, 8, outline=ORANGE if i == 0 else (235, 235, 235), width=1.5 if i == 0 else 1)
        draw_text(d, cx + w / 2, y + 22, t, 20, (0, 0, 0), bold=i == 0, anchor="m")
        used += 6 + w


def callout(im, key_box, items, selected):
    """KeyCalloutView: 48pt per item, 56pt tall, 8pt above the key, selected = systemBlue."""
    d = ImageDraw.Draw(im)
    w = len(items) * 48 + 8
    x = max(6, min((key_box[0] + key_box[2]) / 2 - w / 2, 440 - w - 6))
    y = key_box[1] - 56 - 8
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([P(x), P(y + 2), P(x + w), P(y + 58)], radius=P(10), fill=(0, 0, 0, 90))
    im.paste(Image.alpha_composite(im.convert("RGBA"), sh.filter(ImageFilter.GaussianBlur(P(5)))).convert("RGB"))
    d = ImageDraw.Draw(im)
    rrect(d, (x, y, x + w, y + 56), 10, fill=(247, 247, 247), outline=(200, 200, 204), width=0.5)
    for i, t in enumerate(items):
        ix = x + 4 + i * 48
        if i == selected:
            rrect(d, (ix + 2, y + 6, ix + 46, y + 50), 8, fill=BLUE)
        draw_text(d, ix + 24, y + 28, t, 26, (255, 255, 255) if i == selected else (0, 0, 0), bold=True, anchor="m")
    # finger
    fx, fy = (key_box[0] + key_box[2]) / 2 + 10, (key_box[1] + key_box[3]) / 2 + 8
    ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([P(fx - 22), P(fy - 22), P(fx + 22), P(fy + 22)], fill=(40, 40, 40, 70))
    im.paste(Image.alpha_composite(im.convert("RGBA"), ring).convert("RGB"))


# MARK: - Host app screens

def messages(d, title, bubbles, field_text):
    d.rectangle([0, 0, W, P(100)], fill=(247, 247, 247))
    draw_text(d, 18, 72, "‹", 34, BLUE)
    d.ellipse([P(200), P(52), P(240), P(92)], fill=(170, 170, 178))
    draw_text(d, 220, 72, title[0], 18, (255, 255, 255), bold=True, anchor="m")
    y = 130
    for mine, text in bubbles:
        w = text_w(text, 17) + 28
        box = (440 - 14 - w, y, 440 - 14, y + 40) if mine else (14, y, 14 + w, y + 40)
        rrect(d, box, 20, fill=BLUE if mine else (233, 233, 235))
        draw_text(d, box[0] + 14, y + 20, text, 17, (255, 255, 255) if mine else (0, 0, 0))
        y += 50
    # input bar above keyboard
    fy = 956 - 34 - 268 - 52
    d.rectangle([0, P(fy), W, P(fy + 52)], fill=(255, 255, 255))
    d.ellipse([P(10), P(fy + 10), P(42), P(fy + 42)], fill=(233, 233, 235))
    draw_text(d, 26, fy + 25, "+", 22, (120, 120, 128), anchor="m")
    rrect(d, (52, fy + 8, 428, fy + 44), 18, fill=(255, 255, 255), outline=(200, 200, 204), width=1)
    draw_text(d, 66, fy + 26, field_text, 17, (0, 0, 0))
    cx = 66 + text_w(field_text, 17) + 1
    d.rectangle([P(cx), P(fy + 15), P(cx + 2), P(fy + 37)], fill=BLUE)


def notes(d, title, lines, kb_height=268):
    draw_text(d, 18, 72, "‹ 備忘錄", 17, ORANGE)
    draw_text(d, 20, 122, title, 28, (0, 0, 0), bold=True)
    y = 168
    for line in lines:
        draw_text(d, 20, y, line, 18, (0, 0, 0))
        y += 30
    return y


# MARK: - Marketing frame

def framed(screen: Image.Image, title: str, sub: str) -> Image.Image:
    status_bar(ImageDraw.Draw(screen))  # last, so host-app headers don't cover it
    bg = Image.new("RGB", (W, H), BRAND)
    d = ImageDraw.Draw(bg)
    # soft circles like the icon
    d.ellipse([W - 520, -380, W + 300, 440], fill=(92, 82, 222))
    d.ellipse([-360, H - 520, 420, H + 260], fill=(64, 55, 186))
    y = 150
    for line in title.split("\n"):
        f = font(29, "bold")
        d.text((W // 2, y), line, fill=(255, 255, 255), font=f, anchor="mm")
        y += 120
    d.text((W // 2, y + 10), sub, fill=(214, 210, 255), font=font(15), anchor="mm")

    scale = 0.78
    sw, sh = int(W * scale), int(H * scale)
    top = 480
    left = (W - sw) // 2
    bezel = 26
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left - bezel, top - bezel + 30, left + sw + bezel, top + sh + bezel + 30], radius=150, fill=(0, 0, 0, 110))
    bg = Image.alpha_composite(bg.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(40))).convert("RGB")
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle([left - bezel, top - bezel, left + sw + bezel, top + sh + bezel], radius=150, fill=(22, 22, 26))
    content = screen.resize((sw, sh), Image.Resampling.LANCZOS)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], radius=124, fill=255)
    bg.paste(content, (left, top), mask)
    return bg


def screen() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (W, H), (255, 255, 255))
    return im, ImageDraw.Draw(im)


# MARK: - Screenshots

def shot_long_phrase():
    im, d = screen()
    messages(d, "小安", [(False, "晚上要不要一起去看電影？"), (False, "九點那場還有位子")], "讓我")
    reading = "ㄒㄧㄤˇ ㄧ ㄒㄧㄚˋ"
    keyboard(im, items=candidates(reading, [(3, "x"), (4, "q"), (7, "y")]), pre_reading=reading, composing=True)
    return framed(im, "九宮格注音\n長句一次打到位", "打 ㄒㄧㄤˇ ㄧ ㄒㄧㄚˋ，直接選到「想一下」")


def shot_expanded():
    im, d = screen()
    notes(d, "環島筆記", ["明年想再騎一次單車環島", "認識不一樣的"])
    reading = "ㄊㄞˊ ㄨㄢ"
    items = candidates(reading, [(2, "w")], limit=64)
    keyboard(im, items=items, pre_reading=reading, composing=True, expanded_items=items)
    return framed(im, "候選字一鍵展開\n多字詞完整顯示", "點 ▼ 展開全部候選，詞多長就顯示多長")


def shot_callout():
    im, d = screen()
    notes(d, "購物清單", ["牛奶", "雞蛋", "吐司"])
    boxes = keyboard(im, items=[], composing=False)
    callout(im, boxes[(2, 2)], ["ㄏ", "ㄒ", "ㄠ", "ㄡ"], 1)
    return framed(im, "長按原地左右滑\n精準指定注音", "長按「。」選標點，長按聲調鍵換聲調")


def shot_llm():
    im, d = screen()
    messages(d, "阿哲", [(False, "明天下午三點開會喔"), (False, "記得帶筆電")], "好的，我會準時到")
    llm = ["收到", "謝謝提醒", "到時候見"]
    keyboard(im, items=llm, llm=set(llm))
    return framed(im, "接上自己的 AI\n聯想更聰明", "支援 OpenAI 相容 API，自備 Key 直接連線")


def shot_setup():
    im, d = screen()
    draw_text(d, 20, 112, "啟用說明", 32, (0, 0, 0), bold=True)
    draw_text(d, 20, 165, "Jo一個T9注音", 26, (0, 0, 0), bold=True)
    draw_text(d, 20, 200, "T9 注音鍵盤，九個鍵就能打中文。", 16, (110, 110, 115))
    y = 250
    for n, t in enumerate(["打開「設定 → 一般 → 鍵盤 → 鍵盤」", "新增鍵盤，選擇「Jo一個T9注音」",
                           "點進該鍵盤，開啟「允許完整取用」", "在任意 App 切換到此鍵盤開始使用"], 1):
        d.ellipse([P(20), P(y - 13), P(46), P(y + 13)], fill=(224, 236, 255))
        draw_text(d, 33, y, str(n), 15, BLUE, bold=True, anchor="m")
        draw_text(d, 58, y, t, 16, (0, 0, 0))
        y += 46
    y += 20
    draw_text(d, 20, y, "功能摘要", 18, (0, 0, 0), bold=True)
    for t in ["選詞：libchewing 詞庫 + 自學排序", "長按注音／標點：原地左右滑切換",
              "臨近鍵容錯：按到旁邊的鍵也找得到", "LLM 聯想：自備 API Key", "詞庫備份：匯出 JSON／iCloud"]:
        y += 36
        draw_text(d, 20, y, "•  " + t, 16, (40, 40, 40))
    # tab bar
    d.rectangle([0, P(956 - 84), W, H], fill=(247, 247, 247))
    d.line([0, P(956 - 84), W, P(956 - 84)], fill=(220, 220, 222), width=2)
    for i, t in enumerate(["啟用", "設定", "備份", "LLM"]):
        cx = 55 + i * 110
        d.rounded_rectangle([P(cx - 12), P(956 - 74), P(cx + 12), P(956 - 52)], radius=P(5),
                            outline=BLUE if i == 0 else (150, 150, 155), width=P(1.6))
        draw_text(d, cx, 956 - 38, t, 10, BLUE if i == 0 else (150, 150, 155), anchor="m")
    return framed(im, "三步驟啟用\n不收集任何個人資料", "學習紀錄只存在你的裝置（可選 iCloud 備份）")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    shots = [
        ("01-long-phrase", shot_long_phrase),
        ("02-expanded", shot_expanded),
        ("03-callout", shot_callout),
        ("04-llm", shot_llm),
        ("05-setup", shot_setup),
    ]
    for stem, fn in shots:
        path = OUT / f"{stem}-1320x2868.png"
        fn().save(path, "PNG", optimize=True)
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
