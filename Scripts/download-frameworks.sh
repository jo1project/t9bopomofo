#!/usr/bin/env bash
# Download prebuilt librime xcframeworks with lua + octagram (Hamster-compatible).
# Source: fulanto/LibrimeKit (fork of imfuxiao) — builds lotem/librime-octagram into librime.a
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Frameworks"
VER="${LIBRIMEKIT_VERSION:-2.9.0}"
REPO="${LIBRIMEKIT_REPO:-fulanto/LibrimeKit}"
URL="https://github.com/${REPO}/releases/download/${VER}/Frameworks.tgz"

find_device_librime() {
  # Prefer the device slice; '*ios-arm64*' also matches ios-arm64_*simulator*.
  local root="$1"
  if [[ -d "$root/ios-arm64" ]]; then
    find "$root/ios-arm64" -name '*.a' | head -1
    return
  fi
  find "$root" -path '*/ios-arm64/*.a' ! -path '*simulator*' | head -1
}

MARKER="$OUT/.librimekit_version"
has_octagram() {
  local lib="$1"
  [[ -n "$lib" && -f "$lib" ]] || return 1
  # Prefer archive member names (reliable on macOS + Linux); fall back to strings.
  ar -t "$lib" 2>/dev/null | grep -Eqi 'octagram|grammar_module|gram_db' && return 0
  strings "$lib" 2>/dev/null | grep -Eq 'rime_require_module_octagram|octagram\.o' && return 0
  return 1
}

if [[ -d "$OUT/librime.xcframework" && -f "$MARKER" ]] && grep -qx "$REPO@$VER" "$MARKER"; then
  LIB="$(find_device_librime "$OUT/librime.xcframework")"
  if has_octagram "$LIB"; then
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

LIB="$(find_device_librime "$OUT/librime.xcframework" || true)"
if ! has_octagram "$LIB"; then
  echo "ERROR: downloaded librime lacks octagram module (lib=$LIB)" >&2
  ar -t "$LIB" 2>/dev/null | head -40 >&2 || true
  ls -la "$OUT/librime.xcframework" >&2 || true
  exit 1
fi

echo "$REPO@$VER" > "$MARKER"
ls "$OUT"
echo "Done (octagram present in $(basename "$(dirname "$LIB")")/$(basename "$LIB"))."
