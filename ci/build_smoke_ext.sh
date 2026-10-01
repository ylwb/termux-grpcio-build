#!/usr/bin/env bash
set -euo pipefail

# Build a *smallest possible* aarch64 C extension with the NDK toolchain.
# This is the whole point of the smoke test: prove that the NDK clang
# compiler + target sysroot can link a shared library for Android aarch64.
# No Python C-API yet — just a plain C .so to keep the first pass tiny.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SRC_DIR="$BUILD_DIR/smoke-src"
OUT_DIR="$BUILD_DIR/smoke-out"
mkdir -p "$SRC_DIR" "$OUT_DIR"

# nttld/setup-ndk exports these; fall back to a search if not present.
if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -z "${NDK_HOME:-}" ]; then
  echo "[smoke] ERROR: neither ANDROID_NDK_HOME nor NDK_HOME is set."
  echo "[smoke] Make sure the workflow uses nttld/setup-ndk with add-to-path: true"
  exit 1
fi

NDK_ROOT="${ANDROID_NDK_HOME:-${NDK_HOME}}"
NDK_TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
if [ ! -d "$NDK_TOOLCHAIN" ]; then
  echo "[smoke] ERROR: NDK toolchain not found at $NDK_TOOLCHAIN"
  echo "[smoke] NDK_ROOT=$NDK_ROOT"
  ls -l "$NDK_ROOT" 2>/dev/null || true
  exit 1
fi

CLANG="$NDK_TOOLCHAIN/bin/aarch64-linux-android34-clang"
if [ ! -x "$CLANG" ]; then
  echo "[smoke] ERROR: clang not found at $CLANG"
  ls -l "$NDK_TOOLCHAIN/bin/" | head -n 40
  exit 1
fi
echo "[smoke] using $CLANG"

# Minimal C source — mimics what a Python extension would look like
# but without needing libpython (keeps the smoke test dependency-free).
cat > "$SRC_DIR/smoke_ext.c" <<'EOF'
#include <stdio.h>

int smoke_add(int a, int b) { return a + b; }

void smoke_hello(void) {
    printf("smoke_ext: linked for aarch64 android\n");
}
EOF

$CLANG \
  --sysroot="$NDK_ROOT/sysroot" \
  -shared -fPIC \
  -o "$OUT_DIR/libsmoke_ext.so" \
  "$SRC_DIR/smoke_ext.c"

if [ ! -f "$OUT_DIR/libsmoke_ext.so" ]; then
  echo "[smoke] ERROR: output .so was not produced"
  exit 1
fi

file "$OUT_DIR/libsmoke_ext.so" || true
echo "[smoke] libsmoke_ext.so built successfully"
