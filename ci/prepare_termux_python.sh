#!/usr/bin/env bash
set -euo pipefail

# Prepare a *target-side* Python layout for cross-building grpcio.
#
# Downloads CPython public headers from GitHub (reliable across all version
# tags) so that a cross-compiled extension can actually use Python.h.
#
# This still does NOT build the full CPython interpreter for the target; it
# is a practical middle step between "no headers" and "full CPython bootstrap".

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
TARGET_PYTHON_VERSION="${PYTHON_VERSION:-${TARGET_PYTHON_VERSION:-3.12}}"
PYTHON_TARGET="$BUILD_DIR/python-target-aarch64"

mkdir -p "$PYTHON_TARGET/include" "$PYTHON_TARGET/lib" "$PYTHON_TARGET/bin"

cat > "$PYTHON_TARGET/python-target.env" <<EOF
TARGET_PYTHON_VERSION=${TARGET_PYTHON_VERSION}
TARGET_PYTHON_ABI=cp${TARGET_PYTHON_VERSION}
TARGET_PYTHON_PLATFORM=termux-aarch64
PYTHON_TARGET=${PYTHON_TARGET}
EOF

# Determine full CPython patch version
case "$TARGET_PYTHON_VERSION" in
  3.13) CPYTHON_FULL_VERSION="3.13.3" ;;
  3.12) CPYTHON_FULL_VERSION="3.12.7" ;;
  3.11) CPYTHON_FULL_VERSION="3.11.9" ;;
  3.10) CPYTHON_FULL_VERSION="3.10.14" ;;
  *)
    CPYTHON_FULL_VERSION="${TARGET_PYTHON_VERSION}0"
    echo "[termux-python] WARNING: using guessed full version ${CPYTHON_FULL_VERSION}"
    ;;
esac

echo "[termux-python] targeting CPython ${CPYTHON_FULL_VERSION}"

if [ -f "$PYTHON_TARGET/include/Python.h" ]; then
  echo "[termux-python] Python.h already present, skipping download"
else
  # Use GitHub CPython source tarball - always available for any tag
  CPYTHON_TAG="v${CPYTHON_FULL_VERSION}"
  CPYTHON_TARBALL="$BUILD_DIR/cpython-${CPYTHON_TAG}.tar.gz"
  CPYTHON_URL="https://github.com/python/cpython/archive/refs/tags/${CPYTHON_TAG}.tar.gz"

  echo "[termux-python] downloading ${CPYTHON_URL}"
  if [ ! -f "$CPYTHON_TARBALL" ]; then
    curl -fsSL --retry 3 --retry-delay 5 -o "$CPYTHON_TARBALL" "$CPYTHON_URL"
  fi

  echo "[termux-python] extracting headers only"
  # GitHub tarball top-level dir is cpython-<version> (no 'v')
  CPYTHON_SRC_DIR="$BUILD_DIR/cpython-${CPYTHON_FULL_VERSION}"
  if [ ! -d "$CPYTHON_SRC_DIR" ]; then
    tar -xzf "$CPYTHON_TARBALL" -C "$BUILD_DIR"
    # The extracted dir name matches the tag without 'v'
    if [ -d "$BUILD_DIR/cpython-${CPYTHON_TAG}" ]; then
      mv "$BUILD_DIR/cpython-${CPYTHON_TAG}" "$CPYTHON_SRC_DIR"
    fi
  fi

  if [ ! -d "$CPYTHON_SRC_DIR/Include" ]; then
    echo "[termux-python] ERROR: ${CPYTHON_SRC_DIR}/Include not found"
    ls "$CPYTHON_SRC_DIR/" 2>/dev/null | head -n 30
    exit 1
  fi

  # Copy headers into our target layout
  cp -rf "$CPYTHON_SRC_DIR/Include/"* "$PYTHON_TARGET/include/"

  # Verify
  if [ ! -f "$PYTHON_TARGET/include/Python.h" ]; then
    echo "[termux-python] ERROR: Python.h not found after copy"
    exit 1
  fi

  echo "[termux-python] headers staged at $PYTHON_TARGET/include"
fi

# Provide a python-config style helper for later source-ing
cat > "$PYTHON_TARGET/bin/python-config" <<EOF
#!/usr/bin/env bash
# Minimal python-config helper for cross-build scaffolding.
set -euo pipefail
case "\${1:-}" in
  --includes)
    echo "-I\$($PYTHON_TARGET/include)"
    ;;
  --ldflags)
    echo "-L\$($PYTHON_TARGET/lib)"
    ;;
  --prefix)
    echo "$PYTHON_TARGET"
    ;;
  --cflags)
    echo "-I\$($PYTHON_TARGET/include)"
    ;;
  *)
    echo "unsupported flag: \${1:-}" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$PYTHON_TARGET/bin/python-config"

echo "[termux-python] target Python layout ready with real headers"
