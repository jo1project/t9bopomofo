#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Resources/rime"
mkdir -p "$OUT"
if [[ ! -f "$OUT/zh-hant-t-essay-bgw.gram" ]]; then
  echo "Downloading grammar model..."
  curl -fL -o "$OUT/zh-hant-t-essay-bgw.gram" \
    "https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram"
fi
if [[ ! -f "$OUT/essay.txt" ]]; then
  echo "Downloading essay.txt..."
  curl -fL -o "$OUT/essay.txt" \
    "https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt"
fi
ls -lh "$OUT/zh-hant-t-essay-bgw.gram" "$OUT/essay.txt"
