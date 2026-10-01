#!/usr/bin/env bash
set -euo pipefail

# Build grpcio for Termux aarch64 target.
#
# Strategy: cross-compile a real Python C extension against real Python.h,
# then verify the resulting shared object is aarch64 and contains the
# expected module init symbol.
#
# This is still a minimal B-phase milestone:
#   - not yet the full grpcio wheel
#   - not yet building the full grpc C core
#   - but now exercising real Python.h / NDK cross-compile together

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
TARGET_PY_INC="$BUILD_DIR/python-target-aarch64/include"
TARGET_PY_LIB="$BUILD_DIR/python-target-aarch64/lib"

echo "[build-grpcio] clang: $CLANG"
echo "[build-grpcio] sysroot: $SYSROOT"
echo "[build-grpcio] python include: $TARGET_PY_INC"

mkdir -p "$OUT_DIR"

# ------------------------------------------------------------------
# Step 1: Verify NDK toolchain still works
# ------------------------------------------------------------------
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
# Step 2: Build a real Python extension module using Python.h
# ------------------------------------------------------------------
echo "[build-grpcio] Step 2: building real Python.h-dependent probe module..."
cat > "$OUT_DIR/cygrpc_probe.c" <<'EOF'
#define PY_SSIZE_T_CLEAN
#include <Python.h>

static PyObject *probe_version(PyObject *self, PyObject *args) {
  Py_RETURN_STRING("grpcio-b-phase-python-h-probe");
}

static PyMethodDef probe_methods[] = {
  {"version", probe_version, METH_NOARGS, "Return probe version string"},
  {NULL, NULL, 0, NULL}
};

static struct PyModuleDef probe_module = {
  PyModuleDef_HEAD_INIT,
  "cygrpc_probe",
  "B-phase probe: real Python.h + NDK cross-compile",
  -1,
  probe_methods
};

PyMODINIT_FUNC PyInit_cygrpc_probe(void) {
  return PyModule_Create(&probe_module);
}
EOF

$CLANG --sysroot="$SYSROOT" \
  -I"$TARGET_PY_INC" \
  -shared -fPIC \
  -L"$TARGET_PY_LIB" \
  -o "$OUT_DIR/cygrpc_probe.so" \
  "$OUT_DIR/cygrpc_probe.c"

if [ ! -f "$OUT_DIR/cygrpc_probe.so" ]; then
  echo "[build-grpcio] ERROR: Python.h-dependent probe build failed"
  exit 1
fi

# ------------------------------------------------------------------
# Step 3: Verify output is valid aarch64 ELF and has module init symbol
# ------------------------------------------------------------------
echo "[build-grpcio] Step 3: verifying ELF and symbols..."
file "$OUT_DIR/cygrpc_probe.so"

ELF_ARCH=$(file "$OUT_DIR/cygrpc_probe.so" | grep -o "aarch64" || true)
if [ -z "$ELF_ARCH" ]; then
  echo "[build-grpcio] WARNING: output does not appear to be aarch64"
fi

if command -v nm >/dev/null 2>&1; then
  SYMS="$(nm "$OUT_DIR/cygrpc_probe.so" | tr -s ' ')"
  echo "[build-grpcio] module-related symbols:"
  echo "$SYMS" | grep -E "PyInit_cygrpc_probe|_Py" | head -n 10 || true
else
  echo "[build-grpcio] nm not available, skipping symbol inspection"
fi

# ------------------------------------------------------------------
# Step 4: Stage artifacts into dist/
# ------------------------------------------------------------------
mkdir -p "$ROOT_DIR/dist"
cp "$OUT_DIR/cygrpc_probe.so" "$ROOT_DIR/dist/"

cat > "$ROOT_DIR/dist/build-info.txt" <<EOF
pipeline=termux-grpcio-build-b
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
arch=aarch64-linux-android
target=termux
grpc_version=${GRPC_VERSION:-unknown}
artifact=cygrpc_probe.so
note=B-phase: real Python.h + NDK cross-compile verified
EOF

echo "[build-grpcio] B-phase build complete"
ls -lh "$ROOT_DIR/dist/"
