#!/usr/bin/env python3
"""Compose Jo standing/pressing on accurate T9 Zhuyin keyboard."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
from rembg import remove

SIZE = 1024
OUT = Path("docs/icon-previews/app-icon-jo-on-zhuyin-keyboard-v4.png")
ART = Path("/opt/cursor/artifacts/assets/app-icon-jo-on-zhuyin-keyboard-v4.png")
JO_ALONE = Path("/opt/cursor/artifacts/assets/jo-letters-alone.png")
ORIG = Path("T9Bopomofo/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
FALLBACK = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"

ROWS = [
    ["ˉ", "ㄅㄉㄚ", "ㄍㄐㄞ", "ㄓㄗㄢㄦ", "⌫"],
    ["ˊ", "ㄆㄊㄛ", "ㄎㄑㄟ", "ㄔㄘㄣㄧ", "123"],
    ["ˇ", "ㄇㄋㄜ", "ㄏㄒㄠㄡ", "ㄕㄙㄤㄨ", "。"],
    ["ˋ", "ㄈㄌㄝ", "空格", "ㄖㄥㄩ", "↵"],
]


def get_font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.truetype(FALLBACK, size)


def round_rect(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_radials(canvas: Image.Image) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = cy = SIZE // 2
    for i in range(80):
        ang = (i / 80) * math.tau
        x2 = cx + int(math.cos(ang) * SIZE * 0.85)
        y2 = cy + int(math.sin(ang) * SIZE * 0.85)
        w = 11 if i % 4 == 0 else (7 if i % 2 == 0 else 3)
        d.line((cx, cy, x2, y2), fill=(15, 15, 15, 255), width=w)
    # soft white wash in center
    wash = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    for r in range(460, 0, -6):
        a = int(245 * (1 - r / 460) ** 1.35)
        wd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, a))
    canvas.alpha_composite(layer)
    canvas.alpha_composite(wash)


def draw_keyboard(canvas: Image.Image) -> tuple[int, int, int, int]:
    dlayer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(dlayer)

    margin_x = 56
    top, bottom = 580, 980
    kb = (margin_x, top, SIZE - margin_x, bottom)

    # Drop shadow for whole keyboard (platform)
    round_rect(d, (kb[0] + 10, kb[1] + 16, kb[2] + 10, kb[3] + 16), 30, (0, 0, 0, 140))
    round_rect(d, kb, 28, (236, 236, 236, 255), outline=(8, 8, 8), width=9)
    round_rect(
        d,
        (kb[0] + 12, kb[1] + 12, kb[2] - 12, kb[3] - 12),
        18,
        (210, 210, 210, 255),
        outline=(35, 35, 35),
        width=3,
    )

    cols, rows_n = 5, 4
    gap = 9
    inner = (kb[0] + 22, kb[1] + 22, kb[2] - 22, kb[3] - 22)
    usable_w = inner[2] - inner[0] - gap * (cols - 1)
    usable_h = inner[3] - inner[1] - gap * (rows_n - 1)
    side = usable_w * 0.155
    mid = usable_w * 0.230
    widths = [side, mid, mid, mid, side]
    widths = [w * (usable_w / sum(widths)) for w in widths]
    row_h = usable_h / rows_n

    # Top middle keys pressed by Jo
    pressed = {(0, 1), (0, 2), (0, 3)}

    for r, row in enumerate(ROWS):
        x = float(inner[0])
        y = float(inner[1] + r * (row_h + gap))
        for c, label in enumerate(row):
            w = widths[c]
            box = [int(x), int(y), int(x + w), int(y + row_h)]
            is_func = c in (0, 4) or label in ("空格",)
            if (r, c) in pressed:
                # sunk / crushed
                box = [box[0], box[1] + 10, box[2], box[3] + 6]
                round_rect(d, tuple(box), 9, (150, 150, 150, 255), outline=(5, 5, 5), width=4)
                # stress cracks
                cx = (box[0] + box[2]) / 2
                cy = box[1] + 4
                for ang in (-50, -20, 15, 45):
                    rad = math.radians(ang)
                    d.line(
                        (cx, cy, cx + math.cos(rad) * 36, cy + math.sin(rad) * 22),
                        fill=(0, 0, 0, 230),
                        width=3,
                    )
            else:
                round_rect(
                    d,
                    (box[0] + 3, box[1] + 5, box[2] + 3, box[3] + 5),
                    9,
                    (20, 20, 20, 150),
                )
                fill = (200, 200, 200, 255) if is_func else (252, 252, 252, 255)
                round_rect(d, tuple(box), 9, fill, outline=(8, 8, 8), width=4)

            if len(label) >= 4:
                fs = 21
            elif len(label) == 3 and label != "123":
                fs = 25
            elif label in ("空格", "123"):
                fs = 23
            else:
                fs = 32
            f = get_font(fs)
            if len(label) >= 4:
                l1, l2 = label[:2], label[2:]
                b1 = d.textbbox((0, 0), l1, font=f)
                b2 = d.textbbox((0, 0), l2, font=f)
                th = (b1[3] - b1[1]) + (b2[3] - b2[1]) + 2
                ty = box[1] + (box[3] - box[1] - th) / 2
                d.text((box[0] + (box[2] - box[0] - (b1[2] - b1[0])) / 2, ty), l1, fill=(5, 5, 5), font=f)
                d.text(
                    (box[0] + (box[2] - box[0] - (b2[2] - b2[0])) / 2, ty + (b1[3] - b1[1]) + 2),
                    l2,
                    fill=(5, 5, 5),
                    font=f,
                )
            else:
                b = d.textbbox((0, 0), label, font=f)
                tw, th = b[2] - b[0], b[3] - b[1]
                d.text(
                    (box[0] + (box[2] - box[0] - tw) / 2, box[1] + (box[3] - box[1] - th) / 2 - 2),
                    label,
                    fill=(5, 5, 5),
                    font=f,
                )
            x += w + gap

    canvas.alpha_composite(dlayer)
    return kb


def prepare_jo() -> Image.Image:
    # Prefer dedicated Jo art with background removed
    src = Image.open(JO_ALONE).convert("RGBA")
    cut = remove(src)
    bbox = cut.getbbox()
    if bbox:
        cut = cut.crop(bbox)
    # Soft-edge cleanup: remove near-white fringe
    px = cut.load()
    w, h = cut.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and r > 245 and g > 245 and b > 245:
                px[x, y] = (r, g, b, 0)
    bbox = cut.getbbox()
    if bbox:
        cut = cut.crop(bbox)

    # Scale — Jo should be substantial but leave room for keyboard platform
    target_w = 680
    ratio = target_w / cut.width
    cut = cut.resize((target_w, max(1, int(cut.height * ratio))), Image.Resampling.LANCZOS)
    return cut


def sparkles(canvas: Image.Image) -> None:
    d = ImageDraw.Draw(canvas, "RGBA")

    def star(x, y, r):
        pts = []
        for i in range(8):
            ang = math.pi / 2 + i * math.pi / 4
            rad = r if i % 2 == 0 else r * 0.32
            pts.append((x + rad * math.cos(ang), y + rad * math.sin(ang)))
        d.polygon(pts, fill=(8, 8, 8, 255))

    star(130, 160, 26)
    star(900, 190, 20)
    star(170, 480, 14)
    for x, y, r in [(70, 300, 6), (960, 360, 8), (100, 740, 5), (930, 700, 7)]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=(0, 0, 0, 230))


def main() -> None:
    canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    draw_radials(canvas)
    kb = draw_keyboard(canvas)

    jo = prepare_jo()
    jo_x = (SIZE - jo.width) // 2
    # Plant Jo ON the keyboard: overlap deep into top key row
    jo_y = kb[1] - jo.height + 145

    # Contact shadow on keys (under Jo)
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        (jo_x + 70, kb[1] + 8, jo_x + jo.width - 70, kb[1] + 110),
        fill=(0, 0, 0, 150),
    )
    # impact burst at feet
    cx = SIZE // 2
    cy = kb[1] + 35
    for ang in range(0, 360, 18):
        rad = math.radians(ang)
        sd.line(
            (cx, cy, cx + math.cos(rad) * 70, cy + math.sin(rad) * 28),
            fill=(0, 0, 0, 200),
            width=3,
        )
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    canvas.alpha_composite(shadow)

    # Jo ON TOP of keyboard (standing / pressing)
    canvas.alpha_composite(jo, (jo_x, jo_y))
    sparkles(canvas)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    rgb = canvas.convert("RGB")
    rgb.save(OUT, "PNG")
    rgb.save(ART, "PNG")
    print(f"wrote {OUT}")
    print(f"jo size={jo.size} pos=({jo_x},{jo_y}) kb_top={kb[1]}")


if __name__ == "__main__":
    main()
