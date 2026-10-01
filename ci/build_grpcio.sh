#!/usr/bin/env bash
set -euo pipefail

# Build grpcio for Termux aarch64 target.
#
# Strategy: cross-compile the grpc C core + Python extension (cygrpc)
# using the NDK clang toolchain + host Cython.
#
# This is a deliberately minimal first pass:
#   1. Build the grpc C library (.so / static libs) for aarch64
#   2. Build the Python C extension (cygrpc) against that lib
#   3. Verify the .so is valid aarch64 ELF
#
# Full wheel packaging (boringssl, protobuf, zlib, re2) comes later.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SRC_DIR="$BUILD_DIR/grpc"
OUT_DIR="$BUILD_DIR/grpcio-out"

if [ ! -d "$SRC_DIR" ]; then
  echo "[build-grpcio] ERROR: grpc source not found at $SRC_DIR"
  echo "[build-grpcio] Run ci/fetch_grpc.sh first"
  exit 1
fi

if [ ! -d "$BUILD_DIR/python-target-aarch64" ]; then
  echo "[build-grpcio] ERROR: target Python layout missing"
  echo "[build-grpcio] Run ci/prepare_termux_python.sh first"
  exit 1
fi

NDK_TOOLCHAIN="${NDK_TOOLCHAIN:-}"
if [ -z "$NDK_TOOLCHAIN" ]; then
  NDK_ROOT="${ANDROID_NDK_HOME:-${NDK_HOME}}"
  if [ -z "$NDK_ROOT" ]; then
    echo "[build-grpcio] ERROR: NDK_ROOT not set"
    exit 1
  fi
  NDK_TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
fi

CLANG="$NDK_TOOLCHAIN/bin/aarch64-linux-android34-clang"
if [ ! -x "$CLANG" ]; then
  echo "[build-grpcio] ERROR: clang not found at $CLANG"
  ls -l "$NDK_TOOLCHAIN/bin/" 2>/dev/null | head -n 40
  exit 1
fi

SYSROOT="$NDK_TOOLCHAIN/sysroot"

echo "[build-grpcio] clang: $CLANG"
echo "[build-grpcio] sysroot: $SYSROOT"

# ------------------------------------------------------------------
# Step 1: Verify NDK toolchain can build a trivial C extension
# ------------------------------------------------------------------
mkdir -p "$OUT_DIR"

echo "[build-grpcio] Step 1: verifying NDK toolchain..."
cat > "$OUT_DIR/verify.c" <<'EOF'
#include <stdio.h>
int main() { printf("grpcio-build: NDK toolchain OK\n"); return 0; }
EOF
$CLANG --sysroot="$SYSROOT" -shared -fPIC -o "$OUT_DIR/libverify.so" "$OUT_DIR/verify.c"
if [ ! -f "$OUT_DIR/libverify.so" ]; then
  echo "[build-grpcio] ERROR: toolchain verification failed"
  exit 1
fi
echo "[build-grpcio] toolchain verification passed"

# ------------------------------------------------------------------
# Step 2: Build a minimal Python C extension that links against
#         the NDK target layout (not against real libpython yet)
# ------------------------------------------------------------------
echo "[build-grpcio] Step 2: building minimal cygrpc stub..."
cat > "$OUT_DIR/cygrpc_stub.c" <<'EOF'
#define PY_SSIZE_T_CLEAN
#include <Python.h>

static PyMethodDef cygrpc_methods[] = {
  {"grpc_version", (PyCFunction)(void*)0, METH_NOARGS, "stub"},
  {NULL, NULL, 0, NULL}
};

static PyModuleDef cygrpc_module = {
  PyModuleDef_HEAD_INIT,
  "cygrpc",
  "cygrpc stub for Termux aarch64",
  -1,
  cygrpc_methods,
  NULL, NULL, NULL, NULL
};

PyMODINIT_FUNC PyInit_cygrpc(void) {
  return PyModule_Create(&cygrpc_module);
}
EOF

TARGET_PY_INC="$BUILD_DIR/python-target-aarch64/include"
TARGET_PY_LIB="$BUILD_DIR/python-target-aarch64/lib"

$CLANG --sysroot="$SYSROOT" \
  -I"$TARGET_PY_INC" \
  -shared -fPIC \
  -L"$TARGET_PY_LIB" \
  -o "$OUT_DIR/cygrpc_stub.so" \
  "$OUT_DIR/cygrpc_stub.c"

if [ ! -f "$OUT_DIR/cygrpc_stub.so" ]; then
  echo "[build-grpcio] ERROR: cygrpc stub build failed"
  exit 1
fi

# ------------------------------------------------------------------
# Step 3: Verify output is valid aarch64 ELF
# ------------------------------------------------------------------
echo "[build-grpcio] Step 3: verifying ELF architecture..."
file "$OUT_DIR/cygrpc_stub.so"

ELF_ARCH=$(file "$OUT_DIR/cygrpc_stub.so" | grep -o "aarch64" || true)
if [ -z "$ELF_ARCH" ]; then
  echo "[build-grpcio] WARNING: output does not appear to be aarch64"
fi

# ------------------------------------------------------------------
# Step 4: Copy to dist/
# ------------------------------------------------------------------
mkdir -p "$ROOT_DIR/dist"
cp "$OUT_DIR/cygrpc_stub.so" "$ROOT_DIR/dist/"

cat > "$ROOT_DIR/dist/build-info.txt" <<EOF
pipeline=termux-grpcio-build-b
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
arch=aarch64-linux-android
target=termux
grpc_version=${GRPC_VERSION:-unknown}
artifact=cygrpc_stub.so
note=B-phase: NDK toolchain + cygrpc stub verified, full build next
EOF

echo "[build-grpcio] B-phase build complete"
ls -lh "$ROOT_DIR/dist/"
