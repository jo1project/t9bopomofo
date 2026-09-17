#!/usr/bin/env python3
"""Reference tests for T9 encoding / fuzzy / clear-on-symbol (mirrors Swift engine)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DICT = ROOT / "Resources" / "chewing"
DICT_FILES = ("taiwan_phrases.dict.yaml", "chewing_base.dict.yaml")

# Mirrors T9KeyMap.tokenToKey (ASCII letters kept for literal-spelled loanwords
# like "Dcard" / "PTT"; zhuyin symbols for real syllables).
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
    "ㄅ": "1", "ㄉ": "1", "ㄚ": "1",
    "ㄍ": "2", "ㄐ": "2", "ㄞ": "2",
    "ㄓ": "3", "ㄗ": "3", "ㄢ": "3", "ㄦ": "3",
    "ㄆ": "4", "ㄊ": "4", "ㄛ": "4",
    "ㄎ": "5", "ㄑ": "5", "ㄟ": "5",
    "ㄔ": "6", "ㄘ": "6", "ㄣ": "6", "ㄧ": "6",
    "ㄇ": "7", "ㄋ": "7", "ㄜ": "7",
    "ㄏ": "8", "ㄒ": "8", "ㄠ": "8", "ㄡ": "8",
    "ㄕ": "9", "ㄙ": "9", "ㄤ": "9", "ㄨ": "9",
    "ㄈ": "0", "ㄌ": "0", "ㄝ": "0",
    "ㄖ": "v", "ㄥ": "v", "ㄩ": "v",
}

TONE_MARKS = {"ˊ": "w", "ˇ": "x", "ˋ": "y"}
BOPOMOFO_BLOCK = range(0x3105, 0x3130)

NEIGHBORS = {
    "1": list("24"), "2": list("135"), "3": list("26"),
    "4": list("157"), "5": list("2468"), "6": list("359"),
    "7": list("480"), "8": list("579v"), "9": list("68v"),
    "0": list("7v"), "v": list("890"),
}


def encode_syllable(raw: str) -> tuple[str, str | None]:
    chars = list(raw.strip())
    if not chars:
        return "", None

    tone: str | None = None
    if chars and chars[-1] in TONE_MARKS:
        tone = TONE_MARKS[chars[-1]]
        chars.pop()
    elif chars and chars[-1] == "˙":
        chars.pop()  # neutral tone: no anchor

    if tone is None and all(ord(c) in BOPOMOFO_BLOCK for c in chars):
        tone = "q"  # bare zhuyin syllable = tone 1

    digits = "".join(TOKEN_TO_KEY[c] for c in chars if c in TOKEN_TO_KEY)
    return digits, tone


def encode_reading(reading: str) -> str:
    parts = reading.strip().split(" ")
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
            try:
                w = int(float(t))
            except ValueError:
                w = 1000
        t9 = encode_reading(reading)
        if t9:
            out.append((word, reading, t9, w))
    return out


def load_all() -> list[tuple[str, str, str, int]]:
    entries: list[tuple[str, str, str, int]] = []
    for name in DICT_FILES:
        entries.extend(parse_dict(DICT / name))
    return entries


def test_encode_samples():
    # 早 ㄗㄠˇ → z(3) + ao(8) = 38, tone 3 → x
    assert encode_syllable("ㄗㄠˇ") == ("38", "x"), encode_syllable("ㄗㄠˇ")
    # 餐 ㄘㄢ (no mark = tone1) → c(6) + an(3) = 63, tone q
    assert encode_syllable("ㄘㄢ") == ("63", "q"), encode_syllable("ㄘㄢ")
    # 拉 ㄌㄚ → l(0) + a(1) = 01, tone q
    assert encode_syllable("ㄌㄚ") == ("01", "q"), encode_syllable("ㄌㄚ")
    # 亞 ㄧㄚˋ → i(6) + a(1) = 61, tone 4 → y
    assert encode_syllable("ㄧㄚˋ") == ("61", "y"), encode_syllable("ㄧㄚˋ")
    # Literal ASCII spelling (loanwords) passes through unchanged, no tone.
    assert encode_syllable("card") == ("61v1", None), encode_syllable("card")
    print("encode_samples OK")


def test_dict_contains_targets():
    entries = load_all()
    by_word: dict[str, list[tuple[str, str, int]]] = {}
    for w, r, t9, weight in entries:
        by_word.setdefault(w, []).append((r, t9, weight))
    assert "早餐" in by_word, "missing 早餐"
    assert "拉亞" in by_word, "missing 拉亞"
    breakfast = encode_reading("ㄗㄠˇ ㄘㄢ")
    laya = encode_reading("ㄌㄚ ㄧㄚˋ")
    assert any(t9 == breakfast for _, t9, _ in by_word["早餐"]), by_word["早餐"]
    assert any(t9 == laya for _, t9, _ in by_word["拉亞"]), by_word["拉亞"]
    print("dict targets OK", breakfast, laya)


def test_fuzzy_neighbor_and_missing():
    entries = parse_dict(DICT / "taiwan_phrases.dict.yaml")
    laya = encode_reading("ㄌㄚ ㄧㄚˋ")  # 0161
    neigh = list(laya)
    neigh[0] = NEIGHBORS[neigh[0]][0]
    exact = {t9 for _, _, t9, _ in entries}
    assert laya in exact
    # missing key: drop one digit from correct code — fuzzy should recover via insertion probe
    missing = laya[:2] + laya[3:]
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
    reading = "ㄗㄠˇ ㄘㄢ ㄧㄠˋ ㄅㄨˋ ㄧㄠˋ ㄔ ㄌㄚ ㄧㄚˋ"
    t9 = encode_reading(reading)
    hits = [e for e in entries if e[0] == target]
    assert hits, "phrase missing from taiwan_phrases"
    assert hits[0][2] == t9, (hits[0][2], t9)
    print("success_phrase OK", t9)


def test_bushixing_vs_buxing():
    """不是不行 vs 不是不幸 share T9; tone-2 on last syllable must prefer 行."""
    entries = load_all()
    digits = encode_reading("ㄅㄨˊ ㄕˋ ㄅㄨˋ ㄒㄧㄥˊ")
    digits_xing4 = encode_reading("ㄅㄨˊ ㄕˋ ㄅㄨˊ ㄒㄧㄥˋ")
    assert digits == digits_xing4, (digits, digits_xing4)

    by_word = {w: (r, t9, wt) for w, r, t9, wt in entries if w in ("不是不行", "不是不幸", "不行", "不幸")}
    assert "不是不行" in by_word, by_word.keys()
    assert "不行" in by_word

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

    def tones_of(reading: str) -> str:
        out = ""
        for part in reading.split(" "):
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
    best_xing = max((s for s, w, _ in cands if "行" in w), default=-1e9)
    best_xing4 = max((s for s, w, _ in cands if "幸" in w), default=-1e9)
    assert best_xing > best_xing4, (best_xing, best_xing4, top)
    print("bushixing OK", digits, "top", top[:3])


def test_haoxiang_beats_haolashi():
    """88869 must rank 好像 above a fake multi-segment chop path."""
    entries = load_all()
    digits = encode_reading("ㄏㄠˇ ㄒㄧㄤˋ")
    assert digits == "88869"

    scored = []
    for w, r, t9, wt in entries:
        if t9 == digits:
            scored.append((wt + 20_000 + 15_000, w))
    scored.append((9900 + 30 * 3 - 8_000 * 2, "號臘食"))
    scored.sort(reverse=True)
    assert scored[0][1] == "好像", scored[:5]
    print("haoxiang OK", scored[:3])


def test_you_beats_rao():
    """有 you3 must beat 又/右 you4 on 68; third tone makes it decisive."""
    entries = load_all()
    digits = encode_reading("ㄧㄡˇ")
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
        for part in reading.split(" "):
            _, t = encode_syllable(part)
            out += t or "-"
        return out

    cands = []
    for w, r, t9, wt in entries:
        if t9 != digits:
            continue
        cands.append((score(wt, tones_of(r), ""), w, r))
    cands.sort(reverse=True)
    assert cands[0][1] == "有", cands[:8]

    cands3 = []
    for w, r, t9, wt in entries:
        if t9 != digits:
            continue
        cands3.append((score(wt, tones_of(r), "x"), w, r))
    cands3.sort(reverse=True)
    assert cands3[0][1] == "有", cands3[:8]
    you4 = [c for c in cands3 if c[1] in ("又", "右")]
    assert you4 and you4[0][0] < cands3[0][0]
    print("you_beats_you4 OK", cands[:3], "with tone", cands3[:3])


def test_danshi_beats_chop():
    """但是 (a real phrase) must outrank a 但+事/但+試 chop of two common single chars.

    libchewing single-char weights (word.csv) are on a much bigger scale than
    phrase weights (tsi.csv) — mirrors InputEngine's proportional segPenalty
    (path.weight * segCount * 0.75) instead of the old flat -200.
    """
    entries = load_all()
    digits = encode_reading("ㄉㄢˋ ㄕˋ")
    assert digits == "139"

    best_weight: dict[str, int] = {}
    for w, r, t9, wt in entries:
        if t9 == digits:
            best_weight[w] = max(wt, best_weight.get(w, 0))
    assert "但是" in best_weight, "但是 missing from dict"
    phrase_score = best_weight["但是"]

    def entries_for(t9: str) -> list[tuple[str, int]]:
        return [(w, wt) for w, r, t, wt in entries if t == t9]

    best_chop = -1.0
    for split in range(1, len(digits)):
        left, right = digits[:split], digits[split:]
        for _, lw in entries_for(left):
            for _, rw in entries_for(right):
                chop_weight = min(lw, rw)
                chop_score = chop_weight - chop_weight * 1 * 0.75
                best_chop = max(best_chop, chop_score)

    assert best_chop >= 0, "no chop candidates found"
    assert phrase_score > best_chop, (phrase_score, best_chop)
    print("danshi_beats_chop OK", phrase_score, ">", best_chop)


def tone_score_by_position(tone_marks, tones: str, syllable_lengths: list[int]) -> float:
    """Mirrors InputEngine.toneScore: match each (digits-at-press, tone) mark to the
    candidate's own syllable boundary at that digit count, not by press order."""
    if not tone_marks:
        return 0.0
    tone_chars = list(tones)
    if len(tone_chars) != len(syllable_lengths):
        return 0.0
    boundary_for_digits: dict[int, str] = {}
    boundary = 0
    for length, t in zip(syllable_lengths, tone_chars):
        boundary += length
        boundary_for_digits[boundary] = t
    bonus = 0.0
    for at_digits, tone in tone_marks:
        entry_tone = boundary_for_digits.get(at_digits)
        if entry_tone is None:
            bonus -= 500
            continue
        if entry_tone == "-":
            continue
        bonus += 12_000 if tone == entry_tone else -18_000
    return bonus


def test_jietu_tone_position_alignment():
    """截圖 (jié tú, "screenshot") vs a 接/皆/街 + 圖 chop — the report's second case.

    User types 截's 3 digits ("260"), presses 2nd tone right away (intending it for
    截, not the 圖 that follows), then types 圖's 2 digits ("49") with no further tone
    press (圖 is unambiguously 2nd tone already). The old toneScore compared typed
    tones against a candidate's tones *from the right* (last press vs last syllable),
    so with only one tone typed it always landed on 圖 — which is 2nd tone in every
    candidate regardless of which 260-homophone (接/皆/街/截) was chosen. Tone scoring
    then couldn't tell 截 apart from its much higher-weight tone-1 homophones at all,
    so raw weight decided it and a chop of 接+圖 (weight 19429) buried 截+圖 (1253).
    """
    entries = load_all()
    jie_reading, tu_reading = "ㄐㄧㄝˊ", "ㄊㄨˊ"
    assert encode_reading(jie_reading) == "260"
    assert encode_reading(tu_reading) == "49"

    def weight_of(word: str, reading: str) -> int:
        hits = [wt for w, r, t9, wt in entries if w == word and r == reading]
        assert hits, f"{word} ({reading}) missing from dict"
        return max(hits)

    jie2_w = weight_of("截", jie_reading)   # 2nd tone, low weight
    tu_w = weight_of("圖", tu_reading)
    jie1_w = max(weight_of(w, "ㄐㄧㄝ") for w in ("接", "皆", "街"))  # 1st tone, high weight
    assert jie1_w > jie2_w, "sanity: this is exactly why the chop used to win on raw weight"

    tone_marks = [(3, "w")]  # pressed 2nd tone right after 截's 3 digits; none for 圖
    syllable_lengths = [3, 2]  # 截/接 (3 digits) + 圖 (2 digits)

    def score(first_weight: int, first_tone: str) -> float:
        min_w = min(first_weight, tu_w)
        seg_penalty = min_w * 1 * 0.75  # same proportional segPenalty as danshi_beats_chop
        tone_bonus = tone_score_by_position(tone_marks, first_tone + "w", syllable_lengths)
        return (min_w - seg_penalty) + tone_bonus

    jie2_score = score(jie2_w, "w")   # 截 + 圖
    jie1_score = score(jie1_w, "q")   # 接/皆/街 + 圖
    assert jie2_score > jie1_score, (jie2_score, jie1_score)
    print("jietu_tone_position_alignment OK", jie2_score, ">", jie1_score)


def test_fullcoverage_survives_tone_press():
    """業 (ㄧㄝˋ, digits "60") must stay in T9SortFilter's "full coverage" bucket
    after the user presses the 4th-tone key — mirrors the T9SortFilter.sort fix.

    item.coverage is always in T9-digit-only units (every InputEngine caller sets
    it that way). The old code compared it against `(digits+tones).count` instead
    of `digits.count`, so pressing any tone key made every legitimately full-length
    candidate's coverage look "too short" (demoted out of the full bucket) while
    FuzzyMatcher's "missing key" guesses — one digit *longer* than what was typed,
    by design — coincidentally satisfied the same broken comparison and jumped to
    the front. Typing 業 (digits "60") + 4th tone showed 遺業/一夜/... (all digits
    "660", a FuzzyMatcher missing-key guess for "60") instead of 業 itself.
    """
    entries = load_all()
    digits, tones = "60", "y"

    ye_hits = [(w, wt) for w, r, t9, wt in entries if t9 == digits and w == "業"]
    assert ye_hits, "業 missing at digits 60"
    ye_weight = max(wt for _, wt in ye_hits)

    yiye_hits = [(w, wt) for w, r, t9, wt in entries if t9 == "660" and w == "遺業"]
    assert yiye_hits, "遺業 missing at digits 660 (expected FuzzyMatcher missing-key neighbor)"

    digits_count = len(digits)
    combined_len = len(digits + tones)  # 3

    ye_coverage = 2       # 業's own t9 length — what every real caller sets
    yiye_coverage = 3     # 遺業's t9 length, one digit longer (FuzzyMatcher "missing key")

    # Old (buggy) rule: cov >= combined_len
    assert not (ye_coverage >= combined_len), "sanity: this is exactly why 業 got demoted"
    assert yiye_coverage >= combined_len, "sanity: this is exactly why 遺業 got promoted"

    # Fixed rule: cov == digits_count
    assert ye_coverage == digits_count, "業 must be full-coverage after the fix"
    assert yiye_coverage != digits_count, "遺業 (missing-key guess) must NOT be full-coverage"
    print("fullcoverage_survives_tone_press OK", ye_weight)


def test_chi_reachable_with_tone():
    """吃 (ㄔ, tone1) must not be silently dropped by a pre-tone-scoring truncation.

    Key 6 covers ㄔㄘㄣㄧ, so digit "6" alone has 670+ same-digit homophones
    (mostly totally unrelated ㄧ-reading chars like 一/衣/億/益). A cap applied
    before tone scoring (the old prefixSpans/nBest `.prefix(6)` / `.prefix(4)`)
    drops 吃 outright since it isn't top-6 by raw weight — and once dropped,
    no tone key press can bring it back. This checks 吃 survives an *unbounded*
    exact() lookup, and that pressing tone1 promotes it above nearby-weight
    wrong-tone homophones (益/溢), matching InputEngine's toneScore formula.
    """
    entries = load_all()
    digits = encode_reading("ㄔ")
    assert digits == "6"

    same_digit = [(w, r, wt) for w, r, t9, wt in entries if t9 == digits]
    words = {w for w, r, wt in same_digit}
    assert "吃" in words, "吃 missing from unbounded digit-6 lookup (regression!)"

    def tone_score(entry_tone: str, wanted: str, weight: int) -> float:
        if entry_tone == "-":
            return float(weight)
        return float(weight) + (12_000 if entry_tone == wanted else -18_000)

    best = {}
    for w, r, wt in same_digit:
        if w not in best or wt > best[w][1]:
            _, t = encode_syllable(r)
            best[w] = (t or "-", wt)

    chi_tone, chi_wt = best["吃"]
    chi_score = tone_score(chi_tone, "q", chi_wt)
    for w in ("益", "溢"):
        assert w in best, f"{w} missing (expected as a nearby-weight wrong-tone neighbor)"
        t, wt = best[w]
        assert tone_score(t, "q", wt) < chi_score, (w, t, wt, tone_score(t, "q", wt), chi_score)
    print("chi_reachable_with_tone OK", chi_score)


def main() -> int:
    test_encode_samples()
    test_dict_contains_targets()
    test_fuzzy_neighbor_and_missing()
    test_clear_on_symbol_behavior()
    test_success_phrase()
    test_bushixing_vs_buxing()
    test_haoxiang_beats_haolashi()
    test_you_beats_rao()
    test_danshi_beats_chop()
    test_jietu_tone_position_alignment()
    test_fullcoverage_survives_tone_press()
    test_chi_reachable_with_tone()
    print("ALL PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
