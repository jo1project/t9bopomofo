#!/usr/bin/env bash
# Download prebuilt librime xcframeworks (Hamster / LibrimeKit).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Frameworks"
VER="${LIBRIMEKIT_VERSION:-v0.1.0}"
URL="https://github.com/amorphobia/LibrimeKit/releases/download/${VER}/Frameworks.tgz"

if [[ -d "$OUT/librime.xcframework" ]]; then
  echo "Frameworks already present at $OUT"
  exit 0
fi

mkdir -p "$OUT"
TMP="$(mktemp -d)"
echo "Downloading $URL ..."
curl -fL -o "$TMP/Frameworks.tgz" "$URL"
tar -xzf "$TMP/Frameworks.tgz" -C "$TMP"
# tarball root is Frameworks/
if [[ -d "$TMP/Frameworks" ]]; then
  cp -a "$TMP/Frameworks/." "$OUT/"
else
  cp -a "$TMP/." "$OUT/"
fi
rm -rf "$TMP"
ls "$OUT"
echo "Done."
