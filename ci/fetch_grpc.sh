#!/usr/bin/env bash
set -euo pipefail

# Fetch the grpc source tree.
#
# For now, this downloads a tag tarball rather than checking out the full
# repository, which is faster and avoids the 25+ minute full C++ build.
# Later this can be swapped for a `git sparse-checkout` when we need only
# the python extension sources.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SRC_DIR="$BUILD_DIR/grpc"
GRPC_VERSION="${GRPC_VERSION:-v1.81.1}"
TARBALL_URL="https://github.com/grpc/grpc/archive/refs/tags/${GRPC_VERSION}.tar.gz"
TARBALL_PATH="$BUILD_DIR/grpc-source.tar.gz"

mkdir -p "$SRC_DIR"

if [ -f "$SRC_DIR/.fetched" ]; then
  echo "[fetch-grpc] already fetched, skipping download"
  exit 0
fi

echo "[fetch-grpc] downloading ${TARBALL_URL}"
curl -fsSL --retry 3 --retry-delay 5 -o "$TARBALL_PATH" "$TARBALL_URL"

echo "[fetch-grpc] extracting"
tar -xzf "$TARBALL_PATH" -C "$BUILD_DIR"
mv "$BUILD_DIR/grpc-${GRPC_VERSION}" "$SRC_DIR" 2>/dev/null || true

touch "$SRC_DIR/.fetched"
echo "[fetch-grpc] grpc source ready at $SRC_DIR"
