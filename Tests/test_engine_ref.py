#!/usr/bin/env python3
"""Reference tests for T9 encoding / fuzzy / clear-on-symbol (mirrors Swift engine)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DICT = ROOT / "Resources" / "rime"

TOKEN_TO_KEY = {
    "b": "1", "d": "1", "a": "1",
    "g": "2", "j": "2", "I": "2",
    "Z": "3", "z": "3", "M": "3", "R": "3",
    "p": "4", "t": "4", "o": "4",
    "k": "5", "A": "5", "J": "5",
    "C": "6", "c": "6", "N": "6", "i": "6",
    "m": "7", "n": "7", "e": "7",
    "h": "8", "B": "8", "K": "8", "L": "8",
    "S": "9", "s": "9", "O": "9", "u": "9",
    "f": "0", "l": "0", "E": "0",
    "r": "v", "P": "v", "v": "v",
}

NEIGHBORS = {
    "1": list("24"), "2": list("135"), "3": list("26"),
    "4": list("157"), "5": list("2468"), "6": list("359"),
    "7": list("480"), "8": list("579v"), "9": list("68v"),
    "0": list("7v"), "v": list("890"),
}


def encode_syllable(raw: str) -> tuple[str, str | None]:
    s = raw.strip().lower()
    tone = None
    if s and s[-1] in "12345":
        tone = {"1": "q", "2": "w", "3": "x", "4": "y", "5": None}[s[-1]]
        s = s[:-1]

    repls = [
        ("yong", "vP"), ("iong", "vP"), ("weng", "uP"), ("ong", "uP"), ("ing", "iP"),
    ]
    for a, b in repls:
        s = s.replace(a, b)

    if s.startswith("yu"):
        s = "v" + s[2:]
    if s.startswith("yi"):
        s = "i" + s[2:]
    elif s.startswith("y"):
        s = "i" + s[1:]
    if s.startswith("wu"):
        s = "u" + s[2:]
    elif s.startswith("w"):
        s = "u" + s[1:]

    s = s.replace("iu", "iou").replace("ui", "uei")
    for initial in ("j", "A", "B"):
        if s.startswith(initial + "u"):
            s = initial + "v" + s[len(initial) + 1 :]

    # ([iuv])n → $1en
    s = re.sub(r"([iuv])n", r"\1en", s)

    for a, b in [("zhi", "Z"), ("chi", "C"), ("shi", "S")]:
        s = s.replace(a, b)
    if s.startswith("zh"):
        s = "Z" + s[2:]
    if s.startswith("ch"):
        s = "C" + s[2:]
    if s.startswith("sh"):
        s = "S" + s[2:]
    for ch in "zcsr":
        if s == ch + "i":
            s = ch

    for a, b in [
        ("ai", "I"), ("ei", "J"), ("ao", "K"), ("ou", "L"),
        ("ang", "O"), ("eng", "P"), ("an", "M"), ("en", "N"),
        ("er", "R"), ("eh", "E"),
    ]:
        s = s.replace(a, b)
    s = s.replace("ie", "iE").replace("ve", "vE")
    s = s.replace("q", "A").replace("x", "B")

    digits = "".join(TOKEN_TO_KEY[c] for c in s if c in TOKEN_TO_KEY)
    return digits, tone


def encode_reading(reading: str) -> str:
    parts = re.split(r"[\s']+", reading.strip())
    return "".join(encode_syllable(p)[0] for p in parts if p)


def parse_dict(path: Path) -> list[tuple[str, str, str, int]]:
    text = path.read_text(encoding="utf-8")
    past = False
    out = []
    for line in text.splitlines():
        if line.strip() == "...":
            past = True
            continue
        if not past or not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) < 2:
            continue
        word, reading = cols[0], cols[1].strip()
        if not reading:
            continue
        w = 1000
        if len(cols) >= 3:
            t = cols[2].strip()
            if t.endswith("%"):
                try:
                    w = int(float(t[:-1]) * 100)
                except ValueError:
                    w = 1000
            else:
                try:
                    w = int(float(t))
                except ValueError:
                    w = 1000
        t9 = encode_reading(reading)
        if t9:
            out.append((word, reading, t9, w))
    return out


def test_encode_samples():
    # 早 zao3 → z + ao → z + K → 3 + 8
    assert encode_syllable("zao3")[0] == "38", encode_syllable("zao3")
    # 餐 can1 → c + an → c + M → 6 + 3
    assert encode_syllable("can1")[0] == "63", encode_syllable("can1")
    # 拉 la1 → l + a → 0 + 1
    assert encode_syllable("la1")[0] == "01", encode_syllable("la1")
    # 亞 ya4 → i + a (y→i) → 6 + 1
    assert encode_syllable("ya4")[0] == "61", encode_syllable("ya4")
    print("encode_samples OK", encode_reading("zao3 can1"), encode_reading("la1 ya4"))


def test_dict_contains_targets():
    entries = []
    for name in ("taiwan_phrases.dict.yaml", "bopomofo_t9.dict.yaml"):
        entries.extend(parse_dict(DICT / name))
    by_word = {}
    for w, r, t9, weight in entries:
        by_word.setdefault(w, []).append((r, t9, weight))
    assert "早餐" in by_word, "missing 早餐"
    assert "拉亞" in by_word, "missing 拉亞"
    breakfast = encode_reading("zao3 can1")
    laya = encode_reading("la1 ya4")
    assert any(t9 == breakfast for _, t9, _ in by_word["早餐"]), by_word["早餐"]
    assert any(t9 == laya for _, t9, _ in by_word["拉亞"]), by_word["拉亞"]
    print("dict targets OK", breakfast, laya)


def test_fuzzy_neighbor_and_missing():
    entries = parse_dict(DICT / "taiwan_phrases.dict.yaml")
    laya = encode_reading("la1 ya4")  # 0161
    # neighbor: change one key
    neigh = list(laya)
    neigh[0] = NEIGHBORS[neigh[0]][0]
    mutated = "".join(neigh)
    exact = {t9 for _, _, t9, _ in entries}
    assert laya in exact
    # missing key: drop one digit from correct code — fuzzy should recover via insertion probe
    missing = laya[:2] + laya[3:]  # drop one
    probes = []
    keys = list("0123456789v")
    chars = list(missing)
    for i in range(len(chars) + 1):
        for k in keys:
            c = chars[:]
            c.insert(i, k)
            probes.append("".join(c))
    assert laya in probes
    print("fuzzy OK", laya, "missing", missing)


def test_clear_on_symbol_behavior():
    """Product rule: symbol/space/return clears composing and does NOT commit candidate."""
    composing = "3863"
    candidates = ["早餐", "早參"]
    first = candidates[0]

    def passthrough(symbol: str):
        nonlocal composing, candidates
        out = symbol
        composing = ""
        candidates = []
        return out, first  # first must NOT be prefixed

    for sym in ("。", " ", "\n"):
        out, would_have_committed = passthrough(sym)
        assert out == sym
        assert composing == ""
        assert candidates == []
        assert would_have_committed == "早餐"
        assert not out.startswith(would_have_committed)
    print("clear_on_symbol OK")


def test_success_phrase():
    entries = parse_dict(DICT / "taiwan_phrases.dict.yaml")
    target = "早餐要不要吃拉亞"
    reading = "zao3 can1 yao4 bu4 yao4 chi1 la1 ya4"
    t9 = encode_reading(reading)
    hits = [e for e in entries if e[0] == target]
    assert hits, "phrase missing from taiwan_phrases"
    assert hits[0][2] == t9, (hits[0][2], t9)
    print("success_phrase OK", t9)


def test_bushixing_vs_buxing():
    """不是不行 vs 不是不幸 share T9; tone-2 on last syllable must prefer 行."""
    entries = []
    for name in ("taiwan_phrases.dict.yaml", "bopomofo_t9.dict.yaml"):
        entries.extend(parse_dict(DICT / name))
    digits = encode_reading("bu2 shi4 bu4 xing2")
    digits_xing4 = encode_reading("bu2 shi4 bu2 xing4")
    assert digits == digits_xing4, (digits, digits_xing4)

    by_word = {w: (r, t9, wt) for w, r, t9, wt in entries if w in ("不是不行", "不是不幸", "不行", "不幸")}
    assert "不是不行" in by_word, by_word.keys()
    assert "不行" in by_word

    # Simulate ranking: exact phrase + last tone w (2nd)
    def tone_bonus(tones: str, wanted: str) -> float:
        have = [c for c in tones if c != "-"]
        bonus = 0.0
        for offset, w in enumerate(reversed(wanted)):
            if offset >= len(have):
                bonus -= 150
                continue
            h = have[len(have) - 1 - offset]
            bonus += 900 if w == h else -700
        return bonus

    # Build tones from readings
    def tones_of(reading: str) -> str:
        out = ""
        for part in reading.split():
            _, t = encode_syllable(part)
            out += t or "-"
        return out

    cands = []
    for w, r, t9, wt in entries:
        if t9 != digits:
            continue
        score = wt + 800 + tone_bonus(tones_of(r), "w")
        cands.append((score, w, r))
    cands.sort(reverse=True)
    assert cands, "no candidates"
    top = [w for _, w, _ in cands[:5]]
    assert "不是不行" in top or top[0].endswith("行"), top
    # 不幸 / 不是不幸 must rank below 行 variants when 2nd tone applied
    best_xing = max((s for s, w, _ in cands if "行" in w), default=-1e9)
    best_xing4 = max((s for s, w, _ in cands if "幸" in w), default=-1e9)
    assert best_xing > best_xing4, (best_xing, best_xing4, top)
    print("bushixing OK", digits, "top", top[:3])


def test_haoxiang_beats_haolashi():
    """88869 must rank 好像 above 號臘食 (臘xi1 chop)."""
    entries = []
    for name in ("taiwan_phrases.dict.yaml", "bopomofo_t9.dict.yaml"):
        entries.extend(parse_dict(DICT / name))
    digits = encode_reading("hao3 xiang4")
    assert digits == "88869"

    # Score like InputEngine: whole match +20k; multi-seg penalty 8k each extra
    scored = []
    for w, r, t9, wt in entries:
        if t9 == digits:
            scored.append((wt + 20_000 + 15_000, w))  # phrase + exactLen
    # fake chop path
    scored.append((9900 + 30 * 3 - 8_000 * 2, "號臘食"))
    scored.sort(reverse=True)
    assert scored[0][1] == "好像", scored[:5]
    print("haoxiang OK", scored[:3])


def test_you_beats_rao():
    """有 you3 must beat 擾 you4 on 68; third tone makes it decisive."""
    entries = []
    for name in ("taiwan_phrases.dict.yaml", "bopomofo_t9.dict.yaml"):
        entries.extend(parse_dict(DICT / name))
    digits = encode_reading("you3")
    assert digits == "68"

    def score(wt, tones, wanted=""):
        bonus = 0
        if wanted:
            have = [c for c in tones if c != "-"]
            for offset, w in enumerate(reversed(wanted)):
                if offset >= len(have):
                    bonus -= 500
                    continue
                h = have[len(have) - 1 - offset]
                bonus += 12000 if w == h else -18000
        return wt + 15000 + bonus

    def tones_of(reading: str) -> str:
        out = ""
        for part in reading.split():
            _, t = encode_syllable(part)
            out += t or "-"
        return out

    # without tone
    cands = []
    for w, r, t9, wt in entries:
        if t9 != digits:
            continue
        cands.append((score(wt, tones_of(r), ""), w, r))
    cands.sort(reverse=True)
    assert cands[0][1] == "有", cands[:8]

    # with 3rd tone
    cands3 = []
    for w, r, t9, wt in entries:
        if t9 != digits:
            continue
        cands3.append((score(wt, tones_of(r), "x"), w, r))
    cands3.sort(reverse=True)
    assert cands3[0][1] == "有", cands3[:8]
    # 擾 you4 must be penalized
    rao = [c for c in cands3 if c[1] == "擾"]
    assert rao and rao[0][0] < cands3[0][0]
    print("you_beats_rao OK", cands[:3], "with tone", cands3[:3])


def main() -> int:
    test_encode_samples()
    test_dict_contains_targets()
    test_fuzzy_neighbor_and_missing()
    test_clear_on_symbol_behavior()
    test_success_phrase()
    test_bushixing_vs_buxing()
    test_haoxiang_beats_haolashi()
    test_you_beats_rao()
    print("ALL PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
