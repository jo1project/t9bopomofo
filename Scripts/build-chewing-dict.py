#!/usr/bin/env python3
"""Rebuild Resources/chewing/chewing_base.dict.yaml from libchewing-data.

Downloads word.csv (single chars) + tsi.csv (phrases) from the libchewing-data
repo and converts them to the app's `word<TAB>reading<TAB>weight` format.
Each CSV row is already `word,freq,bopomofo` with space-separated per-syllable
zhuyin (tone mark suffixed, tone1 = no mark) — that reading format is used as-is.
"""
from __future__ import annotations

import csv
import datetime
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Resources" / "chewing" / "chewing_base.dict.yaml"

# Pin a commit for reproducible builds; bump manually to pick up upstream updates.
REF = "c44e81aef24b06f1509f19e1be54c99812d0c43f"
BASE = f"https://raw.githubusercontent.com/chewing/libchewing-data/{REF}/dict/chewing"
SOURCES = ["word.csv", "tsi.csv"]


def fetch_rows(name: str) -> list[tuple[str, str, str]]:
    url = f"{BASE}/{name}"
    with urllib.request.urlopen(url) as resp:
        text = resp.read().decode("utf-8")
    rows = []
    for row in csv.reader(text.splitlines()):
        if not row or row[0].startswith("#"):
            continue
        if len(row) != 3:
            continue
        word, freq, reading = row
        rows.append((word, freq, reading))
    return rows


def main() -> None:
    all_rows: list[tuple[str, str, str]] = []
    for name in SOURCES:
        rows = fetch_rows(name)
        print(f"{name}: {len(rows)} rows")
        all_rows.extend(rows)

    today = datetime.date.today().isoformat()
    with OUT.open("w", encoding="utf-8") as f:
        f.write("# Chewing dictionary\n")
        f.write("# encoding: utf-8\n")
        f.write(f"# Generated from libchewing-data@{REF[:12]} (word.csv + tsi.csv)\n")
        f.write("#\n\n---\n")
        f.write("name: chewing_base\n")
        f.write(f'version: "{today}"\n')
        f.write("...\n\n")
        for word, freq, reading in all_rows:
            f.write(f"{word}\t{reading}\t{freq}\n")

    print(f"Wrote {len(all_rows)} rows to {OUT}")


if __name__ == "__main__":
    main()
