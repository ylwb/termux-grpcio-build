#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/build"

echo "=== grpcio build report (B-phase) ==="
echo "workspace: $ROOT_DIR"
echo

echo "--- dist listing ---"
ls -lh "$DIST_DIR" 2>/dev/null || true
echo

echo "--- build-info.txt ---"
cat "$DIST_DIR/build-info.txt" 2>/dev/null || true
echo

echo "--- NDK info ---"
if [ -n "${ANDROID_NDK_HOME:-}" ]; then
  echo "ANDROID_NDK_HOME=${ANDROID_NDK_HOME}"
  echo "ndk-build version: $(ndk-build -v 2>/dev/null || true)"
elif [ -n "${NDK_HOME:-}" ]; then
  echo "NDK_HOME=${NDK_HOME}"
else
  echo "(no NDK env found)"
fi
echo

echo "--- clang version ---"
CLANG_BIN="$(find "${ANDROID_NDK_HOME:-${NDK_HOME:-}}" -name "aarch64-linux-android34-clang" 2>/dev/null | head -n 1 || true)"
if [ -n "$CLANG_BIN" ]; then
  "$CLANG_BIN" --version 2>/dev/null || true
else
  echo "(clang binary not found in NDK tree)"
fi
echo

echo "--- grpc source ---"
if [ -d "$BUILD_DIR/grpc" ]; then
  echo "grpc source: $BUILD_DIR/grpc"
  ls "$BUILD_DIR/grpc/" | head -n 20
else
  echo "(grpc source not found)"
fi
echo

echo "--- end build report ---"
