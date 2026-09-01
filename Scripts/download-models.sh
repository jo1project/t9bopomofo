#!/usr/bin/env bash
# Download essay / grammar / rime-prelude files needed by librime.
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

PRELUDE_BASE="https://raw.githubusercontent.com/rime/rime-prelude/master"
for f in key_bindings.yaml punctuation.yaml symbols.yaml; do
  if [[ ! -f "$OUT/$f" ]]; then
    echo "Downloading prelude $f ..."
    curl -fL -o "$OUT/$f" "${PRELUDE_BASE}/$f"
  fi
done

ls -lh "$OUT/essay.txt" "$OUT/zh-hant-t-essay-bgw.gram" \
  "$OUT/key_bindings.yaml" "$OUT/punctuation.yaml" "$OUT/symbols.yaml"
echo "Done."
