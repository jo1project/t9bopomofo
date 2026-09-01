#!/usr/bin/env bash
# Download prebuilt librime xcframeworks with lua + octagram (Hamster-compatible).
# Source: fulanto/LibrimeKit (fork of imfuxiao) — builds lotem/librime-octagram into librime.a
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Frameworks"
VER="${LIBRIMEKIT_VERSION:-2.9.0}"
REPO="${LIBRIMEKIT_REPO:-fulanto/LibrimeKit}"
URL="https://github.com/${REPO}/releases/download/${VER}/Frameworks.tgz"

MARKER="$OUT/.librimekit_version"
if [[ -d "$OUT/librime.xcframework" && -f "$MARKER" ]] && grep -qx "$REPO@$VER" "$MARKER"; then
  # Confirm octagram is present
  LIB="$(find "$OUT/librime.xcframework" -path '*ios-arm64*' -name '*.a' | head -1)"
  if [[ -n "$LIB" ]] && strings "$LIB" 2>/dev/null | grep -q 'rime_require_module_octagram'; then
    echo "Frameworks already present ($REPO@$VER, octagram OK)"
    exit 0
  fi
fi

rm -rf "$OUT"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
echo "Downloading $URL ..."
curl -fL -o "$TMP/Frameworks.tgz" "$URL"
tar -xzf "$TMP/Frameworks.tgz" -C "$TMP"
if [[ -d "$TMP/Frameworks" ]]; then
  cp -a "$TMP/Frameworks/." "$OUT/"
else
  cp -a "$TMP/." "$OUT/"
fi
# Boost headers not needed for linking
rm -rf "$OUT/Headers"
rm -rf "$TMP"

LIB="$(find "$OUT/librime.xcframework" -path '*ios-arm64*' -name '*.a' | head -1 || true)"
if [[ -z "$LIB" ]] || ! strings "$LIB" 2>/dev/null | grep -q 'rime_require_module_octagram'; then
  echo "ERROR: downloaded librime lacks octagram module" >&2
  exit 1
fi

echo "$REPO@$VER" > "$MARKER"
ls "$OUT"
echo "Done (octagram present)."
