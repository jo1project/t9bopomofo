#!/usr/bin/env python3
"""Render realistic iPhone App Store screenshots with exact T9 Zhuyin layout."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796  # iPhone 6.7"
OUT = Path("docs/app-store-screenshots")
ART = Path("/opt/cursor/artifacts/assets")
ICON = Path("T9Bopomofo/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"
FALLBACK = "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"

# Exact layout from ZhuyinPhoneLayout
ROWS = [
    [("tone", "ˉ"), ("zhuyin", "ㄅㄉㄚ"), ("zhuyin", "ㄍㄐㄞ"), ("zhuyin", "ㄓㄗㄢㄦ"), ("func", "⌫")],
    [("tone", "ˊ"), ("zhuyin", "ㄆㄊㄛ"), ("zhuyin", "ㄎㄑㄟ"), ("zhuyin", "ㄔㄘㄣㄧ"), ("func", "123")],
    [("tone", "ˇ"), ("zhuyin", "ㄇㄋㄜ"), ("zhuyin", "ㄏㄒㄠㄡ"), ("zhuyin", "ㄕㄙㄤㄨ"), ("func", "。")],
    [("tone", "ˋ"), ("zhuyin", "ㄈㄌㄝ"), ("func", "空格/EN"), ("zhuyin", "ㄖㄥㄩ"), ("func", "換行")],
]

SIDE_FRAC, MID_FRAC = 0.155, 0.230


def font(size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.truetype(FALLBACK, size)


def round_rect(draw, box, r, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def draw_status_bar(im: Image.Image, dark: bool = False):
    d = ImageDraw.Draw(im)
    fg = (255, 255, 255) if dark else (0, 0, 0)
    d.text((56, 28), "9:41", fill=fg, font=font(34))
    # Dynamic island
    round_rect(d, (W // 2 - 120, 22, W // 2 + 120, 78), 34, (0, 0, 0))
    # Signal / wifi / battery simplified
    d.ellipse((W - 170, 38, W - 152, 56), outline=fg, width=2)
    d.rectangle((W - 140, 40, W - 90, 58), outline=fg, width=2)
    d.rectangle((W - 90, 46, W - 84, 52), fill=fg)
    d.rectangle((W - 136, 44, W - 100, 54), fill=fg)


def draw_home_indicator(im: Image.Image, y: int | None = None):
    d = ImageDraw.Draw(im)
    y = y or H - 28
    round_rect(d, (W // 2 - 130, y - 5, W // 2 + 130, y + 5), 4, (80, 80, 80))


def draw_app_icon(im: Image.Image, xy: tuple[int, int], size: int = 72):
    if not ICON.exists():
        return
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    # iOS rounded mask
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, size, size), radius=size * 0.22, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(icon, (0, 0))
    out.putalpha(mask)
    im.paste(out, xy, out)


def key_widths(usable: float) -> list[float]:
    widths = [SIDE_FRAC, MID_FRAC, MID_FRAC, MID_FRAC, SIDE_FRAC]
    s = sum(widths)
    return [w / s * usable for w in widths]


def draw_keyboard(
    im: Image.Image,
    top: int,
    bottom: int,
    *,
    highlight: set[tuple[int, int]] | None = None,
    callout: list[str] | None = None,
    callout_anchor_col: int = 4,
    show_candidates: list[str] | None = None,
    llm_candidates: list[str] | None = None,
):
    d = ImageDraw.Draw(im)
    # Keyboard chrome
    kb_bg = (198, 200, 205)
    d.rectangle((0, top, W, bottom), fill=kb_bg)

    # Candidate bar
    cand_h = 78
    d.rectangle((0, top, W, top + cand_h), fill=(236, 236, 238))
    cands = show_candidates or ["你好", "您好", "你號", "你豪", "擬好"]
    x = 20
    for i, text in enumerate(cands):
        is_llm = llm_candidates is not None and text in llm_candidates
        fill = (90, 160, 230) if is_llm else (30, 30, 30)
        prefix = "✦ " if is_llm else ""
        label = prefix + text
        f = font(34)
        bbox = d.textbbox((0, 0), label, font=f)
        tw = bbox[2] - bbox[0]
        d.text((x, top + 20), label, fill=fill, font=f)
        x += tw + 36
        if i < len(cands) - 1:
            d.line((x - 18, top + 18, x - 18, top + cand_h - 18), fill=(190, 190, 195), width=2)

    # Expand chevron
    d.text((W - 50, top + 18), "▼", fill=(90, 90, 95), font=font(28))

    pad_x, gap, side_gap = 10, 10, 14
    area_top = top + cand_h + 10
    area_bottom = bottom - 36
    usable_w = W - pad_x * 2 - gap * 3 - side_gap
    widths = key_widths(usable_w)
    row_h = (area_bottom - area_top - gap * 3) / 4

    key_boxes: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    for r, row in enumerate(ROWS):
        x = float(pad_x)
        y = area_top + r * (row_h + gap)
        for c, (kind, label) in enumerate(row):
            w = widths[c]
            box = (int(x), int(y), int(x + w), int(y + row_h))
            key_boxes[(r, c)] = box
            if kind == "func":
                fill = (183, 186, 192)
            elif kind == "tone":
                fill = (234, 234, 236)
            else:
                fill = (255, 255, 255)
            if highlight and (r, c) in highlight:
                fill = (210, 225, 255)
            # shadow
            round_rect(d, (box[0] + 1, box[1] + 3, box[2] + 1, box[3] + 3), 12, (140, 142, 148))
            round_rect(d, box, 12, fill)

            # label
            if len(label) >= 4 and label not in ("空格/EN",):
                f = font(28)
                l1, l2 = label[:2], label[2:]
                b1 = d.textbbox((0, 0), l1, font=f)
                b2 = d.textbbox((0, 0), l2, font=f)
                th = (b1[3] - b1[1]) + (b2[3] - b2[1]) + 2
                ty = box[1] + (box[3] - box[1] - th) / 2
                d.text((box[0] + (box[2] - box[0] - (b1[2] - b1[0])) / 2, ty), l1, fill=(10, 10, 10), font=f)
                d.text(
                    (box[0] + (box[2] - box[0] - (b2[2] - b2[0])) / 2, ty + (b1[3] - b1[1]) + 2),
                    l2,
                    fill=(10, 10, 10),
                    font=f,
                )
            else:
                fs = 26 if label in ("空格/EN", "換行", "123") else (40 if kind == "tone" else 32)
                f = font(fs)
                b = d.textbbox((0, 0), label, font=f)
                tw, th = b[2] - b[0], b[3] - b[1]
                d.text(
                    (box[0] + (box[2] - box[0] - tw) / 2, box[1] + (box[3] - box[1] - th) / 2 - 2),
                    label,
                    fill=(10, 10, 10),
                    font=f,
                )

            # next gap: after mid keys use side_gap before last col
            if c < 3:
                x += w + gap
            elif c == 3:
                x += w + side_gap
            else:
                x += w + gap

    # Callout bubble
    if callout:
        # Anchor above 。 key (2,4) or specified
        anchor = key_boxes.get((2, callout_anchor_col)) or key_boxes[(2, 4)]
        item_w = 72
        bw = len(callout) * item_w + 16
        bh = 72
        bx = max(12, min(anchor[0] + (anchor[2] - anchor[0]) // 2 - bw // 2, W - bw - 12))
        by = max(top + cand_h + 4, anchor[1] - bh - 14)
        round_rect(d, (bx, by, bx + bw, by + bh), 14, (250, 250, 252), outline=(180, 180, 185), width=2)
        # selected index 2
        sel = min(2, len(callout) - 1)
        for i, t in enumerate(callout):
            ix = bx + 8 + i * item_w
            if i == sel:
                round_rect(d, (ix, by + 8, ix + item_w - 4, by + bh - 8), 10, (0, 122, 255))
                color = (255, 255, 255)
            else:
                color = (10, 10, 10)
            f = font(34)
            b = d.textbbox((0, 0), t, font=f)
            d.text(
                (ix + (item_w - 4 - (b[2] - b[0])) / 2, by + (bh - (b[3] - b[1])) / 2 - 2),
                t,
                fill=color,
                font=f,
            )
        # finger hint near key (small circle)
        fx = (anchor[0] + anchor[2]) // 2
        fy = (anchor[1] + anchor[3]) // 2
        d.ellipse((fx - 18, fy - 18, fx + 18, fy + 18), fill=(60, 60, 60, 180) if False else (70, 70, 75))
        d.ellipse((fx - 10, fy - 22, fx + 22, fy + 10), outline=(40, 40, 40), width=3)

    return key_boxes


def screenshot_01() -> Image.Image:
    """Messages + correct T9 keyboard — real device look."""
    im = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(im)
    draw_status_bar(im)

    # Nav bar
    d.text((W // 2 - 40, 110), "信息", fill=(0, 0, 0), font=font(40))
    d.text((40, 118), "‹ 返回", fill=(0, 122, 255), font=font(34))

    # Conversation
    bubble = (0, 122, 255)
    round_rect(d, (W - 520, 220, W - 40, 320), 28, bubble)
    d.text((W - 490, 248), "晚上一起吃飯？", fill=(255, 255, 255), font=font(36))

    round_rect(d, (40, 360, 560, 460), 28, (229, 229, 234))
    d.text((70, 388), "好啊，幾點？", fill=(0, 0, 0), font=font(36))

    # Compose field
    compose_top = 1680
    d.rectangle((0, compose_top, W, 1780), fill=(242, 242, 247))
    round_rect(d, (100, compose_top + 18, W - 100, compose_top + 88), 22, (255, 255, 255), outline=(200, 200, 205), width=2)
    d.text((120, compose_top + 34), "你好", fill=(0, 0, 0), font=font(36))
    d.text((W - 86, compose_top + 30), "↑", fill=(0, 122, 255), font=font(40))

    # Globe / mic placeholders
    d.ellipse((30, compose_top + 28, 86, compose_top + 84), outline=(160, 160, 165), width=3)

    kb_top = 1780
    draw_keyboard(im, kb_top, H - 20, show_candidates=["你好", "您好", "你號", "你豪", "擬好"])
    draw_home_indicator(im)
    # Tiny app attribution — no big marketing frame
    draw_app_icon(im, (36, 100), 56)
    return im


def screenshot_02() -> Image.Image:
    """Fuzzy + in-place slide — still real device keyboard UI."""
    im = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(im)
    draw_status_bar(im)

    # Notes-like host app
    d.text((W // 2 - 50, 110), "備忘錄", fill=(0, 0, 0), font=font(40))
    round_rect(d, (40, 200, W - 40, 520), 24, (255, 255, 255))
    d.text((70, 240), "今天開會要討論專案進度", fill=(0, 0, 0), font=font(38))
    d.text((70, 300), "以及下週的時程安排。", fill=(0, 0, 0), font=font(38))
    # caret line
    d.rectangle((70, 370, 74, 410), fill=(0, 122, 255))

    # Small floating tip cards (subtle, like iOS tip, not poster)
    round_rect(d, (60, 560, W - 60, 720), 20, (255, 255, 255))
    draw_app_icon(im, (84, 592), 64)
    d.text((170, 590), "臨近鍵容錯已開啟", fill=(0, 0, 0), font=font(36))
    d.text((170, 645), "打到旁邊的鍵也能找到正確字", fill=(110, 110, 115), font=font(28))

    round_rect(d, (60, 750, W - 60, 900), 20, (255, 255, 255))
    d.text((90, 780), "長按標點後，手指在原地左右滑即可選字", fill=(0, 0, 0), font=font(30))
    d.text((90, 835), "不必滑到目標符號上", fill=(110, 110, 115), font=font(28))

    kb_top = 980
    # Neighbor highlight around center keys of row0/1
    highlight = {(0, 1), (0, 2), (1, 1), (1, 2)}
    draw_keyboard(
        im,
        kb_top,
        H - 20,
        highlight=highlight,
        callout=["，", "？", "！", "、", "…", "：", "；"],
        callout_anchor_col=4,
        show_candidates=["專案", "專家", "轉接", "傳簡"],
    )
    draw_home_indicator(im)
    return im


def screenshot_03() -> Image.Image:
    """Sponsor tab — real SwiftUI form look."""
    im = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(im)
    draw_status_bar(im)

    d.text((W // 2 - 50, 110), "贊助", fill=(0, 0, 0), font=font(40))

    # Tab bar preview at bottom later; main form
    y = 200
    # Card 1
    round_rect(d, (40, y, W - 40, y + 220), 24, (255, 255, 255))
    draw_app_icon(im, (70, y + 40), 88)
    d.text((180, y + 45), "單次贊助解鎖", fill=(0, 0, 0), font=font(40))
    d.text((180, y + 105), "非訂閱 · 買斷支持開發", fill=(110, 110, 115), font=font(30))
    d.text((180, y + 155), "NT$30", fill=(0, 122, 255), font=font(36))

    y = 460
    round_rect(d, (40, y, W - 40, y + 320), 24, (255, 255, 255))
    d.text((70, y + 36), "解鎖內容", fill=(110, 110, 115), font=font(28))
    for i, line in enumerate(["啟用 LLM 聯想候選", "可關閉臨近鍵容錯（預設仍開啟）", "感謝支持 Jo一個T9注音"]):
        d.ellipse((70, y + 100 + i * 70, 90, y + 120 + i * 70), fill=(52, 199, 89))
        d.text((110, y + 90 + i * 70), line, fill=(0, 0, 0), font=font(34))

    y = 820
    round_rect(d, (40, y, W - 40, y + 120), 24, (0, 122, 255))
    t = "贊助解鎖"
    f = font(40)
    b = d.textbbox((0, 0), t, font=f)
    d.text(((W - (b[2] - b[0])) / 2, y + 36), t, fill=(255, 255, 255), font=f)

    y = 980
    round_rect(d, (40, y, W - 40, y + 90), 24, (255, 255, 255))
    d.text((70, y + 28), "還原購買", fill=(0, 122, 255), font=font(34))

    # Keyboard peek with LLM candidates — shows benefit in context
    kb_top = 1200
    d.text((50, 1120), "解鎖後，上屏可出現 LLM 聯想", fill=(110, 110, 115), font=font(28))
    draw_keyboard(
        im,
        kb_top,
        H - 20,
        show_candidates=["好的", "可以", "謝謝", "沒問題", "收到"],
        llm_candidates=["好的", "可以", "謝謝", "沒問題", "收到"],
    )
    draw_home_indicator(im)

    # Tab bar overlay above home indicator area? keyboard already fills — skip tab bar
    return im


def export(im: Image.Image, stem: str):
    OUT.mkdir(parents=True, exist_ok=True)
    ART.mkdir(parents=True, exist_ok=True)
    framed = phone_frame(im)
    p1 = OUT / f"{stem}-1290x2796.png"
    framed.save(p1, "PNG", optimize=True)
    framed.save(ART / f"{stem}-1290x2796.png", "PNG", optimize=True)
    im65 = framed.resize((1284, 2778), Image.Resampling.LANCZOS)
    p2 = OUT / f"{stem}-1284x2778.png"
    im65.save(p2, "PNG", optimize=True)
    print("wrote", p1, p2)


def phone_frame(screen: Image.Image) -> Image.Image:
    """Physical iPhone-style bezel on a studio background (ASC still 1290×2796)."""
    bg = Image.new("RGB", (W, H), (228, 230, 235))
    d = ImageDraw.Draw(bg)
    for i in range(40):
        c = 228 - i
        d.rectangle((i * 2, i * 2, W - 1 - i * 2, H - 1 - i * 2), outline=(c, c + 2, c + 5))

    margin = 48
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (margin + 18, margin + 28, W - margin + 18, H - margin + 28),
        radius=90,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    bg = Image.alpha_composite(bg.convert("RGBA"), shadow).convert("RGB")
    d = ImageDraw.Draw(bg)

    device = (margin, margin, W - margin, H - margin)
    d.rounded_rectangle(device, radius=92, fill=(28, 28, 30))
    d.rounded_rectangle((margin - 6, 520, margin + 2, 620), radius=3, fill=(60, 60, 62))
    d.rounded_rectangle((margin - 6, 680, margin + 2, 820), radius=3, fill=(60, 60, 62))
    d.rounded_rectangle((margin - 6, 860, margin + 2, 1000), radius=3, fill=(60, 60, 62))
    d.rounded_rectangle((W - margin - 2, 740, W - margin + 6, 980), radius=3, fill=(60, 60, 62))

    inset = 14
    screen_box = (margin + inset, margin + inset, W - margin - inset, H - margin - inset)
    sw = screen_box[2] - screen_box[0]
    sh = screen_box[3] - screen_box[1]
    content = screen.resize((sw, sh), Image.Resampling.LANCZOS)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), radius=72, fill=255)
    rounded = Image.new("RGB", (sw, sh), (0, 0, 0))
    rounded.paste(content, (0, 0))
    bg.paste(rounded, (screen_box[0], screen_box[1]), mask)
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle(device, radius=92, outline=(70, 70, 75), width=3)
    return bg


def main():
    export(screenshot_01(), "01-keyboard")
    export(screenshot_02(), "02-fuzzy-slide")
    export(screenshot_03(), "03-sponsor-llm")


if __name__ == "__main__":
    main()
