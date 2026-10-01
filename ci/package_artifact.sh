#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/build"
mkdir -p "$DIST_DIR"

if [ -f "$BUILD_DIR/grpcio-out/cygrpc_stub.so" ]; then
  cp "$BUILD_DIR/grpcio-out/cygrpc_stub.so" "$DIST_DIR/"
fi

if [ -f "$BUILD_DIR/smoke-out/libsmoke_ext.so" ]; then
  cp "$BUILD_DIR/smoke-out/libsmoke_ext.so" "$DIST_DIR/" 2>/dev/null || true
fi

cat > "$DIST_DIR/build-info.txt" <<INFO
pipeline=termux-grpcio-build-b
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
arch=aarch64-linux-android
target=termux
artifact=cygrpc_stub.so
note=B-phase packaging
INFO

echo "[package-artifact] dist ready:"
ls -lh "$DIST_DIR"
