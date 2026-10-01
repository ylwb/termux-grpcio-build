#!/usr/bin/env bash
set -euo pipefail

# Package the smoke-test shared library plus metadata into dist/.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
OUT_DIR="$BUILD_DIR/smoke-out"
mkdir -p "$DIST_DIR"

cp "$OUT_DIR/libsmoke_ext.so" "$DIST_DIR/"

cat > "$DIST_DIR/build-info.txt" <<EOF
pipeline=termux-aarch64-smoke
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
arch=aarch64-linux-android
target=android
artifact=libsmoke_ext.so
note=smoke test for NDK cross-compile pipeline, not grpcio
EOF

echo "[package] dist ready:"
ls -lh "$DIST_DIR"
