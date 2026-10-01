#!/usr/bin/env bash
set -euo pipefail

# Prepare a *minimal* target-side Python layout for cross-building a C extension.
#
# We do NOT bootstrap CPython here.  We only stage the header / library
# layout that `setup.py` will later look at when building the extension
# for Termux / Android aarch64.
#
# For the smoke test this is deliberately tiny: just enough so that
# `build_smoke_ext.sh` has something to point CFLAGS at.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
PYTHON_ROOT="$BUILD_DIR/python-target-aarch64"

mkdir -p "$PYTHON_ROOT/include" "$PYTHON_ROOT/lib"

# Write a stub python-config so a future build step can source it.
cat > "$PYTHON_ROOT/python-target.env" <<EOF
TARGET_PYTHON_VERSION=${TARGET_PYTHON_VERSION:-3.12}
TARGET_PYTHON_ABI=cp${TARGET_PYTHON_VERSION:-3.12}
TARGET_PYTHON_PLATFORM=termux-aarch64
PYTHON_TARGET=$PYTHON_ROOT
EOF

echo "[python-target] minimal target-python layout ready at $PYTHON_ROOT"
