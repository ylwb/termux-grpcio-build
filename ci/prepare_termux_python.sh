#!/usr/bin/env bash
set -euo pipefail

# Prepare a minimal *target-side* Python layout for cross-building grpcio.
#
# GitHub runner host Python is only used for Cython / build tooling.
# This script creates a target layout so the build step can point CFLAGS /
# LD at the intended aarch64 Termux-style Python environment later.
#
# This is intentionally not a full CPython bootstrap.

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

# Provide a tiny python-config style helper for later source-ing.
cat > "$PYTHON_TARGET/bin/python-config" <<EOF
#!/usr/bin/env bash
# Minimal python-config stub for cross-build scaffolding.
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

echo "[termux-python] minimal target Python layout ready at $PYTHON_TARGET"
