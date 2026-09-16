#!/bin/sh
set -euo pipefail

echo "==> Xcode Cloud post-clone: tools + xcodegen"

brew install xcodegen || true

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Generate the Xcode project (not committed; Xcode Cloud needs it after clone)
xcodegen generate

echo "==> post-clone done"
ls -la T9Bopomofo.xcodeproj || true
